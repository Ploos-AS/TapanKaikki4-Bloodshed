#!/usr/bin/env bash
set -euo pipefail
REAL_VLINK=/opt/amiga/bin/vlink
LOG=${TK4_VLINK_WRAPPER_LOG:-/tmp/tk4-vlink-wrapper.log}
args=()
skip_next=0
printf 'RAW:' >>"$LOG"; printf ' %q' "$@" >>"$LOG"; printf '\n' >>"$LOG"
for arg in "$@"; do
  if [ "$skip_next" -eq 1 ]; then
    skip_next=0
    if [ "$arg" = "libm020" ]; then
      continue
    fi
    args+=("-fl" "$arg")
    continue
  fi
  case "$arg" in
    '-('|'-)') continue ;;
    -fl) skip_next=1 ;;
    */libnix/lib/ncrt0.o)
      stripped="${TK4_VLINK_STRIPPED_NCRT0:-/tmp/tk4-vlink-ncrt0.o}"
      /opt/amiga/bin/m68k-amigaos-objcopy --remove-section=.stab --remove-section=.stabstr "$arg" "$stripped"
      args+=("$stripped")
      ;;
    *) args+=("$arg") ;;
  esac
done
if [ "$skip_next" -eq 1 ]; then args+=("-fl"); fi
printf 'EXEC:' >>"$LOG"; printf ' %q' "${args[@]}" >>"$LOG"; printf '\n' >>"$LOG"
exec "$REAL_VLINK" "${args[@]}"
