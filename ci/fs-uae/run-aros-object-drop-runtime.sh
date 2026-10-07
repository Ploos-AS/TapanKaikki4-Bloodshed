#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-build/fs-uae/aros-m3-drop}"
SYS="build/fs-uae/aros-system"
mkdir -p "$OUT"

chmod +x ci/fs-uae/fetch-aros-system.sh
iso="$(ci/fs-uae/fetch-aros-system.sh "$SYS" | tail -n1)"
base="$OUT/base"
rm -rf "$base"
mkdir -p "$base"
7z x -y -o"$base" "$iso" >/dev/null

startup="$(find "$base" -type f -ipath '*/s/startup-sequence' -print -quit)"
root="$(dirname "$(dirname "$startup")")"
rel="${root#"$base"/}"

echo "STATUS=DIAGNOSTIC" >"$OUT/result.txt"
echo "GATE=M3_LEAVE_ONE_OUT_RUNTIME" >>"$OUT/result.txt"
linked=0
main_reached=0
pre_main_failures=0

while IFS=$'\t' read -r id rc obj; do
  if [ "$rc" != 0 ]; then
    printf "DROP_%s LINKED=no OBJECT=%s\n" "$id" "$obj" | tee -a "$OUT/result.txt"
    continue
  fi
  linked=$((linked + 1))
  bin="drop-$id-probe"
  rd="$OUT/drop-$id"
  tree="$rd/tree"
  mkdir -p "$rd"
  cp -a "$base" "$tree"
  if [ "$root" = "$base" ]; then
    rr="$tree"
  else
    rr="$tree/$rel"
  fi
  cp "build-amiga-drop/$bin" "$rr/$bin"
  mkdir -p "$rr/save"
  cat >"$rr/S/Startup-Sequence" <<EOF
SYS:C/Echo GUEST_STARTED >SYS:drop-guest-started.txt
SYS:C/Stack 262144
SYS:C/Echo BEFORE >SYS:drop-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:drop-rc.txt
SYS:C/Echo AFTER >SYS:drop-after.txt
EOF
  cfg="$rd/guest.fs-uae"
  sed "s|@AROS_ROOT@|$PWD/$rr|" ci/fs-uae/aros-guest.fs-uae >"$cfg"
  set +e
  timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$cfg" >"$rd/fs-uae.log" 2>&1
  erc=$?
  set -e
  guest_started=no
  before=no
  main=no
  returned=no
  [ -f "$rr/drop-guest-started.txt" ] && guest_started=yes
  [ -f "$rr/drop-before.txt" ] && before=yes
  [ -f "$rr/save/m3-tk4-objects-main.txt" ] && main=yes
  [ -f "$rr/drop-after.txt" ] && returned=yes
  if [ "$guest_started" = yes ] && [ "$before" = yes ]; then
    if [ "$main" = yes ]; then main_reached=$((main_reached + 1)); else pre_main_failures=$((pre_main_failures + 1)); fi
  fi
  printf "DROP_%s GUEST_STARTED=%s BEFORE=%s MAIN=%s RETURNED=%s FS_UAE_EXIT=%s OBJECT=%s\n" "$id" "$guest_started" "$before" "$main" "$returned" "$erc" "$obj" | tee -a "$OUT/result.txt"
done < build-amiga-drop/manifest.tsv

if grep -q "GUEST_STARTED=no" "$OUT/result.txt"; then
  echo "INFRA_STATUS=FAIL_GUEST_NOT_STARTED" | tee -a "$OUT/result.txt"
  exit 1
fi

printf "LINKED_PROBES=%s\nMAIN_REACHED_PROBES=%s\nPRE_MAIN_FAILURE_PROBES=%s\n" "$linked" "$main_reached" "$pre_main_failures" | tee -a "$OUT/result.txt"
