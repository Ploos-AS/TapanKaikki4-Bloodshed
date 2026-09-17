#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-main-object-isolation}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga-main-objects"
MANIFEST="$NATIVE_DIR/manifest.tsv"
mkdir -p "$OUT_DIR"

[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }
probes=()
while IFS=$'\t' read -r id member bin marker; do
  [[ -n "$id" && -n "$member" && -n "$bin" && -n "$marker" ]] || continue
  probes+=("src-obj-${id}:${bin}:${marker}:${member}")
done < "$MANIFEST"

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
  if [[ -n "$rel_root" ]]; then printf '%s/%s\n' "$1" "$rel_root"; else printf '%s\n' "$1"; fi
}

run_probe() {
  local name="$1" bin="$2" marker="$3" label="$4"
  local run_dir="$OUT_DIR/$name" tree="$OUT_DIR/$name/system-tree"
  rm -rf "$run_dir"; mkdir -p "$run_dir"; cp -a "$base/." "$tree/"
  local root; root="$(probe_root "$tree")"
  cp "$NATIVE_DIR/$bin" "$root/$bin"
  mkdir -p "$root/save"
  cat > "$root/S/Startup-Sequence" <<EOF
SYS:C/Echo "MAIN_OBJECT_GUEST_STARTED=1" >SYS:main-object-started.txt
SYS:C/Stack 262144
SYS:C/Echo "MAIN_OBJECT_BEFORE=1" >SYS:main-object-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:main-object-rc.txt
SYS:C/Echo "MAIN_OBJECT_AFTER=1" >SYS:main-object-after.txt
EOF
  local config="$run_dir/aros-guest.fs-uae"
  sed "s|@AROS_ROOT@|$PWD/$root|" ci/fs-uae/aros-guest.fs-uae > "$config"
  set +e
  timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$config" > "$run_dir/fs-uae.log" 2>&1
  local rc=$?
  set -e
  local main=no returned=no
  [[ -f "$root/save/$marker" ]] && main=yes
  [[ -f "$root/main-object-after.txt" ]] && returned=yes
  {
    echo "PROBE=$name"; echo "LABEL=$label"; echo "FS_UAE_EXIT=$rc"
    echo "MAIN=$main"; echo "RETURNED=$returned"
    [[ -f "$root/main-object-rc.txt" ]] && tr -d '\r' < "$root/main-object-rc.txt" | sed 's/^/GUEST_RC=/'
  } | tee "$run_dir/result.txt"
}

for spec in "${probes[@]}"; do IFS=: read -r name bin marker label <<<"$spec"; run_probe "$name" "$bin" "$marker" "$label"; done

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_MAIN_OBJECT_ISOLATION"
  failing=0
  for spec in "${probes[@]}"; do
    IFS=: read -r name bin marker label <<<"$spec"
    root="$(probe_root "$OUT_DIR/$name/system-tree")"
    main=no; returned=no
    [[ -f "$root/save/$marker" ]] && main=yes
    [[ -f "$root/main-object-after.txt" ]] && returned=yes
    echo "OBJECT=$label MAIN=$main RETURNED=$returned"
    if [[ "$main" != yes ]]; then echo "CULPRIT=$label"; failing=$((failing + 1)); fi
  done
  echo "CULPRIT_COUNT=$failing"
} | tee "$OUT_DIR/result.txt"

exit 0
