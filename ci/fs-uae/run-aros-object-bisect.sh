#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-bisect}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

sizes=(512 1024 1536 1792 2048)
for kib in "${sizes[@]}"; do
  bin="tk4-hunk-${kib}-probe"
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
  local kib="$1"
  local bin="tk4-hunk-${kib}-probe"
  local marker="m3-hunk-${kib}-main.txt"
  local run_dir="$OUT_DIR/$kib"
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
  timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$config" > "$run_dir/fs-uae.log" 2>&1
  local rc=$?
  cleanup_emulator "$config"
  set -e

  {
    echo "SIZE_KIB=$kib"
    echo "BINARY=$bin"
    echo "FS_UAE_EXIT=$rc"
    echo "GUEST_STARTED=$([[ -f "$root/bisect-started.txt" ]] && echo yes || echo no)"
    echo "BEFORE=$([[ -f "$root/bisect-before.txt" ]] && echo yes || echo no)"
    echo "MAIN=$([[ -f "$root/save/$marker" ]] && echo yes || echo no)"
    echo "RETURNED=$([[ -f "$root/bisect-after.txt" ]] && echo yes || echo no)"
    [[ -f "$root/bisect-rc.txt" ]] && tr -d '\r' < "$root/bisect-rc.txt" | sed 's/^/GUEST_RC=/'
    [[ -f "$root/bisect-which.txt" ]] && tr -d '\r' < "$root/bisect-which.txt" | sed 's/^/WHICH=/'
  } | tee "$run_dir/result.txt"
}

for kib in "${sizes[@]}"; do
  run_probe "$kib"
done

first_failure=none
all_pass=yes
{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_HUNK_SIZE_BISECTION"
  for kib in "${sizes[@]}"; do
    root="$OUT_DIR/$kib/system-tree/$rel_root"
    main=no
    returned=no
    [[ -f "$root/save/m3-hunk-${kib}-main.txt" ]] && main=yes
    [[ -f "$root/bisect-after.txt" ]] && returned=yes
    echo "HUNK_${kib}_MAIN=$main"
    echo "HUNK_${kib}_RETURNED=$returned"
    if [[ "$main" != yes || "$returned" != yes ]]; then
      all_pass=no
      [[ "$first_failure" == none ]] && first_failure="$kib"
    fi
  done
  echo "FIRST_FAILURE_KIB=$first_failure"
  if [[ "$all_pass" == yes ]]; then
    echo "OBSERVATION=hunk_size_up_to_2048kib_reaches_main_and_returns"
  else
    echo "OBSERVATION=hunk_size_threshold_reproduces_pre_main_failure"
  fi
} | tee "$OUT_DIR/result.txt"

# Diagnostic workflow: intentional non-green result until M3 root cause is fixed.
exit 1
