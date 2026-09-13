#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-bisect}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

probes=(
  "types-core:tk4-types-core-probe:m3-types-core-main.txt"
  "types-weapons:tk4-types-weapons-probe:m3-types-weapons-main.txt"
  "types-bullets:tk4-types-bullets-probe:m3-types-bullets-main.txt"
  "types:tk4-types-probe:m3-types-main.txt"
  "common-whole:tk4-common-whole-probe:m3-common-whole-main.txt"
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
if [[ "$base_root" == "$base" ]]; then
  rel_root=""
else
  rel_root="${base_root#"$base"/}"
fi

cleanup_emulator() {
  local config="$1"
  pkill -TERM -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -TERM -f "Xvfb.*$PWD" 2>/dev/null || true
  sleep 1
  pkill -KILL -f "fs-uae.*$(printf '%q' "$config")" 2>/dev/null || true
  pkill -KILL -f "Xvfb.*$PWD" 2>/dev/null || true
}

probe_root() {
  local tree="$1"
  if [[ -n "$rel_root" ]]; then
    printf '%s/%s\n' "$tree" "$rel_root"
  else
    printf '%s\n' "$tree"
  fi
}

run_probe() {
  local name="$1"
  local bin="$2"
  local marker="$3"
  local run_dir="$OUT_DIR/$name"
  local tree="$run_dir/system-tree"
  rm -rf "$run_dir"
  mkdir -p "$run_dir"
  cp -a "$base/." "$tree/"

  local root
  root="$(probe_root "$tree")"
  local startup="$root/S/Startup-Sequence"
  [[ -f "$startup" ]] || { echo "ERROR: missing copied Startup-Sequence at $startup" >&2; exit 1; }
  cp "$NATIVE_DIR/$bin" "$root/$bin"
  mkdir -p "$root/save"
  cp "$startup" "$startup.original"

  cat > "$startup" <<EOF
SYS:C/Echo "OBJECT_GUEST_STARTED=1" >SYS:object-started.txt
SYS:C/Stack 262144
SYS:C/Which $bin >SYS:object-which.txt
SYS:C/Echo "OBJECT_BEFORE=1" >SYS:object-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:object-rc.txt
SYS:C/Echo "OBJECT_AFTER=1" >SYS:object-after.txt
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
  [[ -f "$root/object-after.txt" ]] && returned=yes
  {
    echo "PROBE=$name"
    echo "BINARY=$bin"
    echo "FS_UAE_EXIT=$rc"
    echo "GUEST_STARTED=$([[ -f "$root/object-started.txt" ]] && echo yes || echo no)"
    echo "BEFORE=$([[ -f "$root/object-before.txt" ]] && echo yes || echo no)"
    echo "MAIN=$main"
    echo "RETURNED=$returned"
    [[ -f "$root/object-rc.txt" ]] && tr -d '\r' < "$root/object-rc.txt" | sed 's/^/GUEST_RC=/'
    [[ -f "$root/object-which.txt" ]] && tr -d '\r' < "$root/object-which.txt" | sed 's/^/WHICH=/'
  } | tee "$run_dir/result.txt"
}

for spec in "${probes[@]}"; do
  IFS=: read -r name bin marker <<<"$spec"
  run_probe "$name" "$bin" "$marker"
done

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_OBJECT_ISOLATION"
  for spec in "${probes[@]}"; do
    IFS=: read -r name bin marker <<<"$spec"
    tree="$OUT_DIR/$name/system-tree"
    root="$(probe_root "$tree")"
    main=no
    returned=no
    [[ -f "$root/save/$marker" ]] && main=yes
    [[ -f "$root/object-after.txt" ]] && returned=yes
    key="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
    echo "${key}_MAIN=$main"
    echo "${key}_RETURNED=$returned"
  done
} | tee "$OUT_DIR/result.txt"

# Diagnostic workflow: runtime outcome is evidence, not a pass/fail gate.
exit 0
