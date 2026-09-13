#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-enemybase-size}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

probes=(
  "enemybase:tk4-enemybase-probe:m3-enemybase-main.txt"
  "enemybase-ctor:tk4-enemybase-ctor-probe:m3-enemybase-ctor-main.txt"
  "enemybase-accessors:tk4-enemybase-accessors-probe:m3-enemybase-accessors-main.txt"
  "enemybase-ctor-stage0:tk4-enemybase-ctor-stage0-probe:m3-enemybase-ctor-stage0-main.txt"
  "enemybase-ctor-stage1:tk4-enemybase-ctor-stage1-probe:m3-enemybase-ctor-stage1-main.txt"
  "enemybase-ctor-stage2:tk4-enemybase-ctor-stage2-probe:m3-enemybase-ctor-stage2-main.txt"
  "enemybase-ctor-stage3:tk4-enemybase-ctor-stage3-probe:m3-enemybase-ctor-stage3-main.txt"
  "enemybase-ctor-stage4:tk4-enemybase-ctor-stage4-probe:m3-enemybase-ctor-stage4-main.txt"
  "enemybase-ctor-nortti:tk4-enemybase-ctor-nortti-probe:m3-enemybase-ctor-nortti-main.txt"
  "enemybase-ctor-noexceptions:tk4-enemybase-ctor-noexceptions-probe:m3-enemybase-ctor-noexceptions-main.txt"
  "enemybase-ctor-both:tk4-enemybase-ctor-both-probe:m3-enemybase-ctor-both-main.txt"
  "vtable-0:tk4-vtable-0-probe:m3-vtable-0-main.txt"
  "vtable-1:tk4-vtable-1-probe:m3-vtable-1-main.txt"
  "vtable-2:tk4-vtable-2-probe:m3-vtable-2-main.txt"
  "vtable-3:tk4-vtable-3-probe:m3-vtable-3-main.txt"
  "vtable-4:tk4-vtable-4-probe:m3-vtable-4-main.txt"
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
  local config="$1"
  pkill -TERM -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -TERM -f "Xvfb.*$PWD" 2>/dev/null || true
  sleep 1
  pkill -KILL -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -KILL -f "Xvfb.*$PWD" 2>/dev/null || true
}

run_probe() {
  local name="$1" bin="$2" marker="$3"
  local run_dir="$OUT_DIR/$name"
  local tree="$run_dir/system-tree"
  rm -rf "$run_dir"
  mkdir -p "$tree"
  cp -a "$base/." "$tree/"
  local root
  root="$(probe_root "$tree")"
  local startup="$root/S/Startup-Sequence"
  [[ -f "$startup" ]] || { echo "ERROR: missing copied Startup-Sequence at $startup" >&2; exit 1; }
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
  cleanup_emulator "$config"
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
  echo "GATE=M3_ENEMYBASE_VTABLE_RTTI"
  for spec in "${probes[@]}"; do
    IFS=: read -r name bin marker <<<"$spec"
    tree="$OUT_DIR/$name/system-tree"
    root="$(probe_root "$tree")"
    key="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
    [[ -f "$root/save/$marker" ]] && main=yes || main=no
    [[ -f "$root/probe-after.txt" ]] && returned=yes || returned=no
    echo "${key}_MAIN=$main"
    echo "${key}_RETURNED=$returned"
  done
} | tee "$OUT_DIR/result.txt"
