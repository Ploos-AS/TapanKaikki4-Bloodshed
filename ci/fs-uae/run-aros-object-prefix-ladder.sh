#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="${1:-build/fs-uae/aros-m3-prefix}"
NATIVE_DIR=build-amiga-prefix-out
MANIFEST="$NATIVE_DIR/manifest.tsv"
SYSTEM_DIR=build/fs-uae/aros-system
mkdir -p "$OUT_DIR"
iso="$(ci/fs-uae/fetch-aros-system.sh "$SYSTEM_DIR" | tail -n 1)"
base="$OUT_DIR/base-root"; rm -rf "$base"; mkdir -p "$base"; 7z x -y -o"$base" "$iso" >/dev/null
base_startup="$(find "$base" -type f -ipath '*/s/startup-sequence' -print -quit)"
base_root="$(dirname "$(dirname "$base_startup")")"
if [[ "$base_root" == "$base" ]]; then rel_root=""; else rel_root="${base_root#"$base"/}"; fi
: > "$OUT_DIR/result.txt"
echo "STATUS=DIAGNOSTIC" >> "$OUT_DIR/result.txt"
echo "GATE=M3_CUMULATIVE_OBJECT_PREFIX_RUNTIME" >> "$OUT_DIR/result.txt"
first_failure=none
while IFS=$'\t' read -r id count last_obj; do
  bin="prefix-$id-probe"; run_dir="$OUT_DIR/prefix-$id"; tree="$run_dir/system-tree"
  rm -rf "$run_dir"; mkdir -p "$run_dir"; cp -a "$base/." "$tree/"
  [[ -n "$rel_root" ]] && root="$tree/$rel_root" || root="$tree"
  startup="$root/S/Startup-Sequence"; cp "$NATIVE_DIR/$bin" "$root/$bin"; mkdir -p "$root/save"
  cat > "$startup" <<EOF
SYS:C/Stack 262144
SYS:C/Echo "PREFIX_BEFORE=1" >SYS:prefix-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:prefix-rc.txt
SYS:C/Echo "PREFIX_AFTER=1" >SYS:prefix-after.txt
EOF
  config="$run_dir/aros-guest.fs-uae"; sed "s|@AROS_ROOT@|$PWD/$root|" ci/fs-uae/aros-guest.fs-uae > "$config"
  set +e; timeout --signal=TERM --kill-after=5s 20s xvfb-run -a fs-uae "$config" >"$run_dir/fs-uae.log" 2>&1; rc=$?; set -e
  main=no; returned=no
  [[ -f "$root/save/m3-prefix-main.txt" ]] && main=yes
  [[ -f "$root/prefix-after.txt" ]] && returned=yes
  printf "PREFIX_%s_COUNT=%s MAIN=%s RETURNED=%s LAST=%s FS_UAE_EXIT=%s\n" "$id" "$count" "$main" "$returned" "$last_obj" "$rc" | tee -a "$OUT_DIR/result.txt"
  if [[ "$main" != yes && "$first_failure" == none ]]; then first_failure="$id"; fi
done < "$MANIFEST"
echo "FIRST_FAILURE=$first_failure" | tee -a "$OUT_DIR/result.txt"
