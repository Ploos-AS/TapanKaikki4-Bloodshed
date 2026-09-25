#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-build/fs-uae/aros-m3-drop}"; SYS=build/fs-uae/aros-system; mkdir -p "$OUT"
chmod +x ci/fs-uae/fetch-aros-system.sh
iso="$(ci/fs-uae/fetch-aros-system.sh "$SYS" | tail -n1)"; base="$OUT/base"; rm -rf "$base"; mkdir -p "$base"; 7z x -y -o"$base" "$iso" >/dev/null
startup="$(find "$base" -type f -ipath '*/s/startup-sequence' -print -quit)"; root="$(dirname "$(dirname "$startup")")"; rel="${root#"$base"/}"
echo "STATUS=DIAGNOSTIC" >"$OUT/result.txt"; echo "GATE=M3_LEAVE_ONE_OUT_RUNTIME" >>"$OUT/result.txt"
while IFS=$'\t' read -r id rc obj; do
 [ "$rc" = 0 ] || continue
 bin="drop-$id-probe"; rd="$OUT/drop-$id"; tree="$rd/tree"; mkdir -p "$rd"; cp -a "$base/." "$tree/"; [ "$root" = "$base" ] && rr="$tree" || rr="$tree/$rel"
 cp "build-amiga-drop/$bin" "$rr/$bin"; mkdir -p "$rr/save"
 cat >"$rr/S/Startup-Sequence" <<EOF
SYS:C/Stack 262144
SYS:C/Echo BEFORE >SYS:drop-before.txt
SYS:$bin
SYS:C/Echo \$RC >SYS:drop-rc.txt
SYS:C/Echo AFTER >SYS:drop-after.txt
EOF
 cfg="$rd/guest.fs-uae"; sed "s|@AROS_ROOT@|$PWD/$rr|" ci/fs-uae/aros-guest.fs-uae >"$cfg"
 set +e; timeout --signal=TERM --kill-after=5s 25s xvfb-run -a fs-uae "$cfg" >"$rd/fs-uae.log" 2>&1; erc=$?; set -e
 main=no; returned=no; [ -f "$rr/save/m3-tk4-objects-main.txt" ] && main=yes; [ -f "$rr/drop-after.txt" ] && returned=yes
 printf "DROP_%s MAIN=%s RETURNED=%s FS_UAE_EXIT=%s OBJECT=%s\n" "$id" "$main" "$returned" "$erc" "$obj" | tee -a "$OUT/result.txt"
done < build-amiga-drop/manifest.tsv
