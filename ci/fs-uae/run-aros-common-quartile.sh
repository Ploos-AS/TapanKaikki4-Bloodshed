#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-common-quartile}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
MANIFEST="$NATIVE_DIR/tk4-common-object-manifest.tsv"
mkdir -p "$OUT_DIR"

probes=(
  "common-q1:tk4-common-q1-probe:m3-common-q1-main.txt:quartile-1"
  "common-q2:tk4-common-q2-probe:m3-common-q2-main.txt:quartile-2"
  "common-q3:tk4-common-q3-probe:m3-common-q3-main.txt:quartile-3"
  "common-q4:tk4-common-q4-probe:m3-common-q4-main.txt:quartile-4"
  "common-whole:tk4-common-whole-probe:m3-common-whole-main.txt:whole-archive"
)

[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }
while IFS=$'\t' read -r id member bin marker; do
  [[ -n "$id" && -n "$member" && -n "$bin" && -n "$marker" ]] || continue
  probes+=("common-obj-${id}:${bin}:${marker}:${member}")
done < "$MANIFEST"

for spec in "${probes[@]}"; do
  IFS=: read -r name bin marker label <<<"$spec"
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

probe_root() {
  local tree="$1"
  if [[ -n "$rel_root" ]]; then
    printf '%s/%s\n' "$tree" "$rel_root"
  else
    printf '%s\n' "$tree"
  fi
}

cleanup_emulator() {
  pkill -TERM -f 'fs-uae' 2>/dev/null || true
  sleep 1
  pkill -KILL -f 'fs-uae' 2>/dev/null || true
}

run_probe() {
  local name="$1" bin="$2" marker="$3" label="$4"
  local run_dir="$OUT_DIR/$name"
  local tree="$run_dir/system-tree"
  rm -rf "$run_dir"
  mkdir -p "$run_dir"
  cp -a "$base/." "$tree/"

  local root
  root="$(probe_root "$tree")"
  local startup="$root/S/Startup-Sequence"
  cp "$NATIVE_DIR/$bin" "$root/$bin"
  mkdir -p "$root/save"
  cp "$startup" "$startup.original"

  cat > "$startup" <<EOF
SYS:C/Echo "COMMON_ARCHIVE_GUEST_STARTED=1" >SYS:common-archive-started.txt
SYS:C/Stack 262144
SYS:C/Which $bin >SYS:common-archive-which.txt
SYS:C/Echo "COMMON_ARCHIVE_BEFORE=1" >SYS:common-archive-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:common-archive-rc.txt
SYS:C/Echo "COMMON_ARCHIVE_AFTER=1" >SYS:common-archive-after.txt
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
  [[ -f "$root/common-archive-after.txt" ]] && returned=yes
  {
    echo "PROBE=$name"
    echo "LABEL=$label"
    echo "BINARY=$bin"
    echo "FS_UAE_EXIT=$rc"
    echo "MAIN=$main"
    echo "RETURNED=$returned"
    [[ -f "$root/common-archive-rc.txt" ]] && tr -d '\r' < "$root/common-archive-rc.txt" | sed 's/^/GUEST_RC=/'
    [[ -f "$root/common-archive-which.txt" ]] && tr -d '\r' < "$root/common-archive-which.txt" | sed 's/^/WHICH=/'
  } | tee "$run_dir/result.txt"
}

for spec in "${probes[@]}"; do
  IFS=: read -r name bin marker label <<<"$spec"
  run_probe "$name" "$bin" "$marker" "$label"
done

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_COMMON_OBJECT_ISOLATION"
  failing=0
  for spec in "${probes[@]}"; do
    IFS=: read -r name bin marker label <<<"$spec"
    tree="$OUT_DIR/$name/system-tree"
    root="$(probe_root "$tree")"
    main=no
    returned=no
    [[ -f "$root/save/$marker" ]] && main=yes
    [[ -f "$root/common-archive-after.txt" ]] && returned=yes
    key="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
    echo "${key}_LABEL=$label"
    echo "${key}_MAIN=$main"
    echo "${key}_RETURNED=$returned"
    if [[ "$name" == common-obj-* && "$main" != yes ]]; then
      echo "CULPRIT=$label"
      failing=$((failing + 1))
    fi
  done
  echo "CULPRIT_COUNT=$failing"
} | tee "$OUT_DIR/result.txt"

exit 0
