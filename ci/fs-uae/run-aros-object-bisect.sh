#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-bisect}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

for bin in tk4-object-half-a-probe tk4-object-half-b-probe; do
  [[ -f "$NATIVE_DIR/$bin" ]] || { echo "ERROR: missing $NATIVE_DIR/$bin" >&2; exit 1; }
done

iso="$(ci/fs-uae/fetch-aros-system.sh "$SYSTEM_DIR" | tail -n 1)"
base="$OUT_DIR/base-root"
rm -rf "$base"
mkdir -p "$base"
7z x -y -o"$base" "$iso" >/dev/null
base_startup="$(find "$base" -type f -ipath '*/s/startup-sequence' -print -quit)"
[[ -n "$base_startup" ]] || { echo "ERROR: no AROS Startup-Sequence" >&2; exit 1; }
base_root="$(dirname "$(dirname "$base_startup")")"
rel_root="${base_root#$base/}"

cleanup_emulator() {
  local config="$1"
  pkill -TERM -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -TERM -f "Xvfb.*$PWD" 2>/dev/null || true
  sleep 1
  pkill -KILL -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -KILL -f "Xvfb.*$PWD" 2>/dev/null || true
}

run_probe() {
  local key="$1"
  local bin="$2"
  local marker="$3"
  local run_dir="$OUT_DIR/$key"
  local tree="$run_dir/system-tree"
  rm -rf "$run_dir"
  mkdir -p "$run_dir"
  cp -a "$base" "$tree"

  local root="$tree/$rel_root"
  local startup="$root/S/Startup-Sequence"
  cp "$NATIVE_DIR/$bin" "$root/$bin"
  mkdir -p "$root/save"
  cp "$startup" "$startup.original"

  cat > "$startup" <<EOF
SYS:C/Echo "BISECT_GUEST_STARTED=1" >SYS:bisect-started.txt
SYS:C/Stack 262144
SYS:C/Which $bin >SYS:bisect-which.txt
SYS:C/Echo "BISECT_BEFORE=1" >SYS:bisect-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:bisect-rc.txt
SYS:C/Echo "BISECT_AFTER=1" >SYS:bisect-after.txt
EOF

  local config="$run_dir/aros-guest.fs-uae"
  sed "s|@AROS_ROOT@|$PWD/$root|" ci/fs-uae/aros-guest.fs-uae > "$config"
  set +e
  timeout --signal=TERM --kill-after=5s 30s xvfb-run -a fs-uae "$config" > "$run_dir/fs-uae.log" 2>&1
  local rc=$?
  cleanup_emulator "$config"
  set -e

  local result="$run_dir/result.txt"
  {
    echo "KEY=$key"
    echo "BINARY=$bin"
    echo "FS_UAE_EXIT=$rc"
    echo "GUEST_STARTED=$([[ -f "$root/bisect-started.txt" ]] && echo yes || echo no)"
    echo "BEFORE=$([[ -f "$root/bisect-before.txt" ]] && echo yes || echo no)"
    echo "MAIN=$([[ -f "$root/save/$marker" ]] && echo yes || echo no)"
    echo "RETURNED=$([[ -f "$root/bisect-after.txt" ]] && echo yes || echo no)"
    [[ -f "$root/bisect-rc.txt" ]] && tr -d '\r' < "$root/bisect-rc.txt" | sed 's/^/GUEST_RC=/'
    [[ -f "$root/bisect-which.txt" ]] && tr -d '\r' < "$root/bisect-which.txt" | sed 's/^/WHICH=/'
  } | tee "$result"
}

run_probe half-a tk4-object-half-a-probe m3-tk4-half-a-main.txt
run_probe half-b tk4-object-half-b-probe m3-tk4-half-b-main.txt

a_main=no; b_main=no; a_returned=no; b_returned=no
[[ -f "$OUT_DIR/half-a/system-tree/$rel_root/save/m3-tk4-half-a-main.txt" ]] && a_main=yes
[[ -f "$OUT_DIR/half-b/system-tree/$rel_root/save/m3-tk4-half-b-main.txt" ]] && b_main=yes
[[ -f "$OUT_DIR/half-a/system-tree/$rel_root/bisect-after.txt" ]] && a_returned=yes
[[ -f "$OUT_DIR/half-b/system-tree/$rel_root/bisect-after.txt" ]] && b_returned=yes

observation=both_halves_reached_main
if [[ "$a_main" == no && "$b_main" == yes ]]; then
  observation=pre_main_failure_in_half_a
elif [[ "$a_main" == yes && "$b_main" == no ]]; then
  observation=pre_main_failure_in_half_b
elif [[ "$a_main" == no && "$b_main" == no ]]; then
  observation=both_halves_reproduce_pre_main_failure
fi

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_OBJECT_HALF_BISECTION"
  echo "OBSERVATION=$observation"
  echo "HALF_A_MAIN=$a_main"
  echo "HALF_A_RETURNED=$a_returned"
  echo "HALF_B_MAIN=$b_main"
  echo "HALF_B_RETURNED=$b_returned"
} | tee "$OUT_DIR/result.txt"

# This is a diagnostic gate: keep M3 red until the real game reaches its runtime gate.
exit 1
