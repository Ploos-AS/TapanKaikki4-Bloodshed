#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-guest}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

if [[ ! -f "$NATIVE_DIR/tk4" ]]; then
  echo "ERROR: build-amiga/tk4 missing; run the Amiga cross-build first" >&2
  exit 1
fi

iso="$(ci/fs-uae/fetch-aros-system.sh "$SYSTEM_DIR" | tail -n 1)"
root_extract="$OUT_DIR/system-root"
rm -rf "$root_extract"
mkdir -p "$root_extract"
7z x -y -o"$root_extract" "$iso" >/dev/null

startup="$(find "$root_extract" -type f -ipath '*/s/startup-sequence' -print -quit)"
if [[ -z "$startup" ]]; then
  echo "ERROR: AROS system ISO does not contain S/Startup-Sequence" >&2
  find "$root_extract" -maxdepth 3 -type f | sort > "$OUT_DIR/system-files.txt"
  exit 1
fi

aros_root="$(dirname "$(dirname "$startup")")"
cp "$NATIVE_DIR/tk4" "$aros_root/tk4"
rm -rf "$aros_root/data" "$aros_root/save"
cp -a data "$aros_root/data"
mkdir -p "$aros_root/save"
cp "$startup" "$startup.tk4-original"

cat > "$startup" <<'EOF'
SYS:C/Echo "M2_GUEST_STARTED=1" >SYS:tk4-m2-started.txt
SYS:C/Which tk4 >SYS:tk4-m2-which.txt
SYS:C/If EXISTS SYS:data/default.ini
SYS:C/Echo "M2_DATA_PRESENT=1" >SYS:tk4-m2-data.txt
SYS:C/EndIf
SYS:C/Echo "M2_BEFORE_TK4=1" >SYS:tk4-m2-before.txt
SYS:tk4
SYS:C/Echo $RC >SYS:tk4-m2-rc.txt
SYS:C/Echo "M2_AFTER_TK4=1" >SYS:tk4-m2-after.txt
SYS:C/Execute SYS:S/Startup-Sequence.tk4-original
EOF

rm -f "$aros_root"/tk4-m2-{started,which,data,before,rc,after}.txt

config="$OUT_DIR/aros-guest.fs-uae"
sed "s|@AROS_ROOT@|$PWD/$aros_root|" ci/fs-uae/aros-guest.fs-uae > "$config"
fs-uae --version > "$OUT_DIR/fs-uae-version.txt" 2>&1 || true

set +e
timeout 45s xvfb-run -a fs-uae "$config" > "$OUT_DIR/fs-uae.log" 2>&1
fsuae_rc=$?
set -e

started="$aros_root/tk4-m2-started.txt"
which_out="$aros_root/tk4-m2-which.txt"
data_present="$aros_root/tk4-m2-data.txt"
before="$aros_root/tk4-m2-before.txt"
after="$aros_root/tk4-m2-after.txt"
guest_rc="$aros_root/tk4-m2-rc.txt"

status=FAIL
observation=guest_result_missing

if [[ -f "$started" && -f "$which_out" && -f "$data_present" && -f "$before" && ! -f "$after" ]]; then
  status=PASS
  observation=tk4_launched_and_remained_active_until_harness_timeout
elif [[ -f "$after" ]]; then
  observation=tk4_returned_to_startup_sequence
elif [[ -f "$before" ]]; then
  observation=tk4_launch_attempted_but_runtime_state_unclear
fi

{
  echo "STATUS=$status"
  echo "GATE=M2_AROS_GUEST_RUNTIME"
  echo "MODEL=A1200"
  echo "KICKSTART=internal"
  echo "AROS_ROOT=$aros_root"
  echo "FS_UAE_EXIT=$fsuae_rc"
  echo "OBSERVATION=$observation"
  echo "DATA_PRESENT=$([[ -f "$data_present" ]] && echo yes || echo no)"
  echo "RETURNED=$([[ -f "$after" ]] && echo yes || echo no)"
  if [[ -f "$which_out" ]]; then
    tr -d '\r' < "$which_out" | sed 's/^/GUEST_WHICH=/'
  fi
  if [[ -f "$guest_rc" ]]; then
    tr -d '\r' < "$guest_rc" | sed 's/^/GUEST_RC=/'
  fi
} | tee "$OUT_DIR/result.txt"

[[ "$status" == PASS ]]
