#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3-tu}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga-tu-out"
MANIFEST="$NATIVE_DIR/manifest.tsv"
mkdir -p "$OUT_DIR"

[[ -f "$MANIFEST" ]] || { echo "ERROR: missing $MANIFEST" >&2; exit 1; }

probes=()
while IFS=$'\t' read -r cls variant marker; do
  [[ -n "$cls" && -n "$variant" && -n "$marker" ]] || continue
  bin="${cls}-${variant}-probe"
  [[ -f "$NATIVE_DIR/$bin" ]] || { echo "ERROR: missing $NATIVE_DIR/$bin" >&2; exit 1; }
  probes+=("${cls}:${variant}:${bin}:${marker}")
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
  local cls="$1" variant="$2" bin="$3" marker="$4"
  local name="${cls}-${variant}"
  local run_dir="$OUT_DIR/$name" tree="$run_dir/system-tree"
  rm -rf "$run_dir"; mkdir -p "$run_dir"; cp -a "$base/." "$tree/"
  local root startup config rc main=no returned=no
  root="$(probe_root "$tree")"; startup="$root/S/Startup-Sequence"
  cp "$NATIVE_DIR/$bin" "$root/$bin"; mkdir -p "$root/save"; cp "$startup" "$startup.original"
  cat > "$startup" <<EOF
SYS:C/Echo "TU_GUEST_STARTED=1" >SYS:tu-started.txt
SYS:C/Stack 262144
SYS:C/Which $bin >SYS:tu-which.txt
SYS:C/Echo "TU_BEFORE=1" >SYS:tu-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:tu-rc.txt
SYS:C/Echo "TU_AFTER=1" >SYS:tu-after.txt
EOF
  config="$run_dir/aros-guest.fs-uae"
  sed "s|@AROS_ROOT@|$PWD/$root|" ci/fs-uae/aros-guest.fs-uae > "$config"
  set +e
  timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$config" > "$run_dir/fs-uae.log" 2>&1
  rc=$?; cleanup_emulator "$config"; set -e
  [[ -f "$root/save/$marker" ]] && main=yes
  [[ -f "$root/tu-after.txt" ]] && returned=yes
  {
    echo "CLASS=$cls"; echo "VARIANT=$variant"; echo "FS_UAE_EXIT=$rc"
    echo "MAIN=$main"; echo "RETURNED=$returned"
    [[ -f "$root/tu-rc.txt" ]] && tr -d '\r' < "$root/tu-rc.txt" | sed 's/^/GUEST_RC=/'
  } | tee "$run_dir/result.txt"
}

for spec in "${probes[@]}"; do IFS=: read -r cls variant bin marker <<<"$spec"; run_probe "$cls" "$variant" "$bin" "$marker"; done

{
  echo "STATUS=DIAGNOSTIC"
  echo "GATE=M3_TU_LAYOUT_PERTURBATION_RUNTIME"
  first_failure=none
  for spec in "${probes[@]}"; do
    IFS=: read -r cls variant bin marker <<<"$spec"
    result="$OUT_DIR/${cls}-${variant}/result.txt"
    main="$(sed -n 's/^MAIN=//p' "$result")"
    returned="$(sed -n 's/^RETURNED=//p' "$result")"
    key="$(printf '%s_%s' "$cls" "$variant" | tr '[:lower:]-' '[:upper:]_')"
    echo "${key}_MAIN=$main"; echo "${key}_RETURNED=$returned"
    [[ "$main" == yes ]] || { [[ "$first_failure" != none ]] || first_failure="${cls}-${variant}"; }
  done
  echo "FIRST_FAILURE=$first_failure"
} | tee "$OUT_DIR/result.txt"
