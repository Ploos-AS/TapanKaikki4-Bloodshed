#!/usr/bin/env bash
set -euo pipefail
REAL_VLINK=/opt/amiga/bin/vlink
LOG=${TK4_VLINK_WRAPPER_LOG:-/tmp/tk4-vlink-wrapper.log}
args=()
printf 'RAW:' >>"$LOG"; printf ' %q' "$@" >>"$LOG"; printf '\n' >>"$LOG"
for arg in "$@"; do
  case "$arg" in
    '-('|'-)') continue ;;
    -lm020)
      lib="$(find /opt/amiga -type f -name libm020.a -print -quit)"
      if [ -z "$lib" ]; then echo "vlink wrapper: libm020.a not found" >&2; exit 66; fi
      args+=("$lib")
      ;;
    *) args+=("$arg") ;;
  esac
done
printf 'EXEC:' >>"$LOG"; printf ' %q' "${args[@]}" >>"$LOG"; printf '\n' >>"$LOG"
exec "$REAL_VLINK" "${args[@]}"
