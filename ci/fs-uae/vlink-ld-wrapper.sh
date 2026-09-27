#!/usr/bin/env bash
set -euo pipefail
REAL_VLINK=/opt/amiga/bin/vlink
LOG=${TK4_VLINK_WRAPPER_LOG:-/tmp/tk4-vlink-wrapper.log}
STRIP_DIR=${TK4_VLINK_STRIP_DIR:-/tmp/tk4-vlink-stripped}
mkdir -p "$STRIP_DIR"
args=()
skip_next=0
idx=0
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
    *.o|*.obj)
      if [ -f "$arg" ]; then
        idx=$((idx + 1))
        stripped="$STRIP_DIR/$(printf '%04d' "$idx")-$(basename "$arg")"
        /opt/amiga/bin/m68k-amigaos-objcopy --remove-section=.stab --remove-section=.stabstr "$arg" "$stripped"
        args+=("$stripped")
      else
        args+=("$arg")
      fi
      ;;
    *) args+=("$arg") ;;
  esac
done
if [ "$skip_next" -eq 1 ]; then args+=("-fl"); fi
printf 'EXEC:' >>"$LOG"; printf ' %q' "${args[@]}" >>"$LOG"; printf '\n' >>"$LOG"
exec "$REAL_VLINK" "${args[@]}"
