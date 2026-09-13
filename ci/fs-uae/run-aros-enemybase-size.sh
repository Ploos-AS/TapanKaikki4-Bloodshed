#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-enemybase-size}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

probes=(
  "enemybase:tk4-enemybase-probe:m3-enemybase-main.txt"
  "pad-700k:tk4-pad-700k:m3-pad-700k-main.txt"
  "pad-850k:tk4-pad-850k:m3-pad-850k-main.txt"
  "pad-950k:tk4-pad-950k:m3-pad-950k-main.txt"
  "pad-1000k:tk4-pad-1000k:m3-pad-1000k-main.txt"
  "pad-1050k:tk4-pad-1050k:m3-pad-1050k-main.txt"
  "pad-1100k:tk4-pad-1100k:m3-pad-1100k-main.txt"
  "pad-1250k:tk4-pad-1250k:m3-pad-1250k-main.txt"
)

for spec in "${probes[@]}"; do
  IFS=: read -r name bin marker <<<"$spec"
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
if [[ "$base_root" == "$base" ]]; then rel_root=""; else rel_root="${base_root#"$base"/}"; fi

probe_root() {
  local tree="$1"
  if [[ -n "$rel_root" ]]; then printf '%s/%s\n' "$tree" "$rel_root"; else printf '%s\n' "$tree"; fi
}

cleanup_emulator() {
  pkill -TERM -f "fs-uae" 2>/dev/null || true
  sleep 1
  pkill -KILL -f "fs-uae" 2>/dev/null || true
}

run_probe() {
  local name="$1" bin="$2" marker="$3"
  local run_dir="$OUT_DIR/$name" tree="$run_dir/system-tree"
  rm -rf "$run_dir"; mkdir -p "$run_dir"; cp -a "$base/." "$tree/"
  local root; root="$(probe_root "$tree")"
  local startup="$root/S/Startup-Sequence"
  cp "$NATIVE_DIR/$bin" "$root/$bin"
  mkdir -p "$root/save"
  cat > "$startup" <<EOF
SYS:C/Echo "GUEST_STARTED=1" >SYS:probe-started.txt
SYS:C/Stack 262144
SYS:C/Which $bin >SYS:probe-which.txt
SYS:C/Echo "BEFORE=1" >SYS:probe-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:probe-rc.txt
SYS:C/Echo "AFTER=1" >SYS:probe-after.txt
EOF
  local config="$run_dir/aros-guest.fs-uae"
  sed "s|@AROS_ROOT@|$PWD/$root|" ci/fs-uae/aros-guest.fs-uae > "$config"
  set +e
  timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$config" > "$run_dir/fs-uae.log" 2>&1
  local rc=$?
  cleanup_emulator
  set -e
  local main=no returned=no
  [[ -f "$root/save/$marker" ]] && main=yes
  [[ -f "$root/probe-after.txt" ]] && returned=yes
  {
    echo "PROBE=$name"
    echo "BINARY=$bin"
    echo "FS_UAE_EXIT=$rc"
    echo "MAIN=$main"
    echo "RETURNED=$returned"
    [[ -f "$root/probe-rc.txt" ]] && tr -d '\r' < "$root/probe-rc.txt" | sed 's/^/GUEST_RC=/'
    [[ -f "$root/probe-which.txt" ]] && tr -d '\r' < "$root/probe-which.txt" | sed 's/^/WHICH=/'
  } | tee "$run_dir/result.txt"
}

for spec in "${probes[@]}"; do
  IFS=: read -r name bin marker <<<"$spec"
  run_probe "$name" "$bin" "$marker"
done

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_ENEMYBASE_SIZE"
  for spec in "${probes[@]}"; do
    IFS=: read -r name bin marker <<<"$spec"
    tree="$OUT_DIR/$name/system-tree"; root="$(probe_root "$tree")"
    key="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
    [[ -f "$root/save/$marker" ]] && main=yes || main=no
    [[ -f "$root/probe-after.txt" ]] && returned=yes || returned=no
    echo "${key}_MAIN=$main"
    echo "${key}_RETURNED=$returned"
  done
} | tee "$OUT_DIR/result.txt"
