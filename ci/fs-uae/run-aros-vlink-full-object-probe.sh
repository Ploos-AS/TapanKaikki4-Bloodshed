#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-build/fs-uae/aros-m3-vlink-full}"
SYS=build/fs-uae/aros-system
mkdir -p "$OUT"
chmod +x ci/fs-uae/fetch-aros-system.sh
iso="$(ci/fs-uae/fetch-aros-system.sh "$SYS" | tail -n1)"
base="$OUT/base"; rm -rf "$base"; mkdir -p "$base"; 7z x -y -o"$base" "$iso" >/dev/null
startup="$(find "$base" -type f -ipath '*/s/startup-sequence' -print -quit)"
root="$(dirname "$(dirname "$startup")")"; rel="${root#"$base"/}"
cp build-amiga-vlink-full/report.txt "$OUT/result.txt"
echo "GATE=M3_GNU_VLINK_FULL_OBJECT_RUNTIME" >>"$OUT/result.txt"
for linker in gnu vlink; do
  bin="full-$linker"
  if [ ! -f "build-amiga-vlink-full/$bin" ]; then echo "${linker^^}_RUNTIME=not-linked" >>"$OUT/result.txt"; continue; fi
  rd="$OUT/$linker"; tree="$rd/tree"; rm -rf "$rd"; mkdir -p "$rd"; cp -a "$base" "$tree"
  if [ "$root" = "$base" ]; then rr="$tree"; else rr="$tree/$rel"; fi
  cp "build-amiga-vlink-full/$bin" "$rr/$bin"; mkdir -p "$rr/save"
  cat >"$rr/S/Startup-Sequence" <<EOF
SYS:C/Stack 262144
SYS:C/Echo BEFORE >SYS:${linker}-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:${linker}-rc.txt
SYS:C/Echo AFTER >SYS:${linker}-after.txt
EOF
  cfg="$rd/guest.fs-uae"; sed "s|@AROS_ROOT@|$PWD/$rr|" ci/fs-uae/aros-guest.fs-uae >"$cfg"
  set +e; timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$cfg" >"$rd/fs-uae.log" 2>&1; erc=$?; set -e
  main=no; returned=no; [ -f "$rr/save/m3-tk4-objects-main.txt" ] && main=yes; [ -f "$rr/${linker}-after.txt" ] && returned=yes
  printf "%s_MAIN=%s\n%s_RETURNED=%s\n%s_FS_UAE_EXIT=%s\n" "${linker^^}" "$main" "${linker^^}" "$returned" "${linker^^}" "$erc" >>"$OUT/result.txt"
done
cat "$OUT/result.txt"
