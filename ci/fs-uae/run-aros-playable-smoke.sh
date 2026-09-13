#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

if [[ ! -f "$NATIVE_DIR/tk4" ]]; then
  echo "ERROR: build-amiga/tk4 missing; run the Amiga cross-build first" >&2
  exit 1
fi

iso="$(ci/fs-uae/fetch-aros-system.sh "$SYSTEM_DIR" | tail -n 1)"
root_extract="$OUT_DIR/system-root"
rm -rf "$root_extract"
mkdir -p "$root_extract"
7z x -y -o"$root_extract" "$iso" >/dev/null

startup="$(find "$root_extract" -type f -ipath '*/s/startup-sequence' -print -quit)"
if [[ -z "$startup" ]]; then
  echo "ERROR: AROS system ISO does not contain S/Startup-Sequence" >&2
  exit 1
fi

aros_root="$(dirname "$(dirname "$startup")")"
cp "$NATIVE_DIR/tk4" "$aros_root/tk4"
rm -rf "$aros_root/data" "$aros_root/save"
cp -a data "$aros_root/data"
mkdir -p "$aros_root/save"
cp "$startup" "$startup.tk4-m3-original"

cat > "$startup" <<'EOF'
SYS:C/Echo "M3_GUEST_STARTED=1" >SYS:tk4-m3-started.txt
SYS:C/Which tk4 >SYS:tk4-m3-which.txt
SYS:C/Echo "M3_SAVE_WRITABLE=1" >SYS:save/m3-guest-save-writable.txt
SYS:C/Echo "M3_BEFORE_TK4=1" >SYS:tk4-m3-before.txt
SYS:tk4
SYS:C/Echo $RC >SYS:tk4-m3-rc.txt
SYS:C/Echo "M3_AFTER_TK4=1" >SYS:tk4-m3-after.txt
SYS:C/Execute SYS:S/Startup-Sequence.tk4-m3-original
EOF

rm -f "$aros_root"/tk4-m3-{started,which,before,rc,after}.txt
rm -f "$aros_root/save"/m3-*.txt

config="$OUT_DIR/aros-guest.fs-uae"
sed "s|@AROS_ROOT@|$PWD/$aros_root|" ci/fs-uae/aros-guest.fs-uae > "$config"
fs-uae --version > "$OUT_DIR/fs-uae-version.txt" 2>&1 || true

set +e
timeout 45s xvfb-run -a fs-uae "$config" > "$OUT_DIR/fs-uae.log" 2>&1
fsuae_rc=$?
set -e

started="$aros_root/tk4-m3-started.txt"
which_out="$aros_root/tk4-m3-which.txt"
save_writable="$aros_root/save/m3-guest-save-writable.txt"
before="$aros_root/tk4-m3-before.txt"
after="$aros_root/tk4-m3-after.txt"
main_started="$aros_root/save/m3-main-started.txt"
splash_ok="$aros_root/save/m3-splash-ok.txt"
app_ok="$aros_root/save/m3-app-ok.txt"
menu_ok="$aros_root/save/m3-menu-mode-ok.txt"
loop_ok="$aros_root/save/m3-loop-entered.txt"

status=FAIL
observation=guest_result_missing
if [[ -f "$started" && -f "$which_out" && -f "$save_writable" && -f "$before" && -f "$main_started" && -f "$splash_ok" && -f "$app_ok" && -f "$menu_ok" && -f "$loop_ok" && ! -f "$after" ]]; then
  status=PASS
  observation=tk4_reached_splash_app_menu_and_game_loop
elif [[ ! -f "$save_writable" ]]; then
  observation=guest_could_not_write_sys_save_preflight
elif [[ -f "$after" ]]; then
  observation=tk4_returned_to_startup_sequence
elif [[ -f "$loop_ok" ]]; then
  observation=tk4_reached_game_loop_but_harness_state_unclear
elif [[ -f "$menu_ok" ]]; then
  observation=tk4_reached_menu_mode_but_not_game_loop
elif [[ -f "$app_ok" ]]; then
  observation=tk4_constructed_app_but_not_menu_mode
elif [[ -f "$splash_ok" ]]; then
  observation=tk4_displayed_splash_but_app_init_did_not_complete
elif [[ -f "$main_started" ]]; then
  observation=tk4_entered_main_but_splash_did_not_complete
elif [[ -f "$before" ]]; then
  observation=tk4_launch_attempted_but_main_marker_missing
fi

{
  echo "STATUS=$status"
  echo "GATE=M3_AROS_PLAYABLE_BASELINE"
  echo "MODEL=A1200"
  echo "KICKSTART=internal"
  echo "FS_UAE_EXIT=$fsuae_rc"
  echo "OBSERVATION=$observation"
  echo "GUEST_STARTED=$([[ -f "$started" ]] && echo yes || echo no)"
  echo "SAVE_WRITABLE=$([[ -f "$save_writable" ]] && echo yes || echo no)"
  echo "MAIN_STARTED=$([[ -f "$main_started" ]] && echo yes || echo no)"
  echo "SPLASH_OK=$([[ -f "$splash_ok" ]] && echo yes || echo no)"
  echo "APP_INIT_OK=$([[ -f "$app_ok" ]] && echo yes || echo no)"
  echo "MENU_MODE_OK=$([[ -f "$menu_ok" ]] && echo yes || echo no)"
  echo "GAME_LOOP_ENTERED=$([[ -f "$loop_ok" ]] && echo yes || echo no)"
  echo "RETURNED=$([[ -f "$after" ]] && echo yes || echo no)"
  if [[ -f "$which_out" ]]; then
    tr -d '\r' < "$which_out" | sed 's/^/GUEST_WHICH=/'
  fi
} | tee "$OUT_DIR/result.txt"

[[ "$status" == PASS ]]
