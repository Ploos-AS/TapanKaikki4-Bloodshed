#!/usr/bin/env bash
set -euo pipefail
REAL_VLINK=${TK4_VLINK_BIN:-/opt/amiga/bin/vlink}
LOG=${TK4_VLINK_WRAPPER_LOG:-/tmp/tk4-vlink-wrapper.log}
args=()
if [ "${TK4_VLINK_BROKEN_DEBUG:-0}" = "1" ]; then
  args+=("-broken-debug")
fi
skip_next=0
printf 'LINKER=%q\n' "$REAL_VLINK" >>"$LOG"
"$REAL_VLINK" -v >>"$LOG" 2>&1 || true
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
    *) args+=("$arg") ;;
  esac
done
if [ "$skip_next" -eq 1 ]; then args+=("-fl"); fi
printf 'EXEC:' >>"$LOG"; printf ' %q' "${args[@]}" >>"$LOG"; printf '\n' >>"$LOG"
exec "$REAL_VLINK" "${args[@]}"
