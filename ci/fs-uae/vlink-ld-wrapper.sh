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
      lib="$(find /opt/amiga -type f -name libm020.a -print -quit)"
      if [ -z "$lib" ]; then echo "vlink wrapper: libm020.a not found" >&2; exit 66; fi
      args+=("$lib")
      continue
    fi
    args+=("-fl" "$arg")
    continue
  fi
  case "$arg" in
    '-('|'-)') continue ;;
    -fl) skip_next=1 ;;
    -lm020)
      lib="$(find /opt/amiga -type f -name libm020.a -print -quit)"
      if [ -z "$lib" ]; then echo "vlink wrapper: libm020.a not found" >&2; exit 66; fi
      args+=("$lib")
      ;;
    *) args+=("$arg") ;;
  esac
done
if [ "$skip_next" -eq 1 ]; then args+=("-fl"); fi
printf 'EXEC:' >>"$LOG"; printf ' %q' "${args[@]}" >>"$LOG"; printf '\n' >>"$LOG"
exec "$REAL_VLINK" "${args[@]}"
