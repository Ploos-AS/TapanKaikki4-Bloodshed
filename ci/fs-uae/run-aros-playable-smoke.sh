#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-build/fs-uae/aros-m3}"
SYSTEM_DIR="build/fs-uae/aros-system"
NATIVE_DIR="build-amiga"
mkdir -p "$OUT_DIR"

bins=(
  tk4
  loader-probe
  cxx-init-probe
  sdl-startup-probe
  link-sdl-probe
  link-image-probe
  link-mixer-probe
  link-full-probe
)
for bin in "${bins[@]}"; do
  if [[ ! -f "$NATIVE_DIR/$bin" ]]; then
    echo "ERROR: $NATIVE_DIR/$bin missing" >&2
    exit 1
  fi
done

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
for bin in "${bins[@]}"; do
  cp "$NATIVE_DIR/$bin" "$aros_root/$bin"
done
rm -rf "$aros_root/data" "$aros_root/save"
cp -a data "$aros_root/data"
mkdir -p "$aros_root/save"
cp "$startup" "$startup.tk4-m3-original"

cat > "$startup" <<'EOF'
SYS:C/Echo "M3_GUEST_STARTED=1" >SYS:tk4-m3-started.txt
SYS:C/Echo "M3_SAVE_WRITABLE=1" >SYS:save/m3-guest-save-writable.txt
SYS:C/Stack 262144
SYS:C/Echo $RC >SYS:tk4-m3-stack-rc.txt
SYS:C/Stack >SYS:tk4-m3-stack-value.txt

SYS:C/Which loader-probe >SYS:tk4-m3-loader-which.txt
SYS:loader-probe
SYS:C/Echo $RC >SYS:tk4-m3-loader-rc.txt

SYS:C/Which cxx-init-probe >SYS:tk4-m3-cxx-which.txt
SYS:cxx-init-probe
SYS:C/Echo $RC >SYS:tk4-m3-cxx-rc.txt

SYS:C/Which sdl-startup-probe >SYS:tk4-m3-sdl-which.txt
SYS:sdl-startup-probe
SYS:C/Echo $RC >SYS:tk4-m3-sdl-rc.txt

SYS:C/Which link-sdl-probe >SYS:tk4-m3-link-sdl-which.txt
SYS:link-sdl-probe
SYS:C/Echo $RC >SYS:tk4-m3-link-sdl-rc.txt
SYS:C/Rename SYS:save/m3-link-main.txt SYS:save/m3-link-sdl-main.txt
SYS:C/Rename SYS:save/m3-link-sdl.txt SYS:save/m3-link-sdl-ok.txt

SYS:C/Which link-image-probe >SYS:tk4-m3-link-image-which.txt
SYS:link-image-probe
SYS:C/Echo $RC >SYS:tk4-m3-link-image-rc.txt
SYS:C/Rename SYS:save/m3-link-main.txt SYS:save/m3-link-image-main.txt
SYS:C/Rename SYS:save/m3-link-sdl.txt SYS:save/m3-link-image-sdl.txt
SYS:C/Rename SYS:save/m3-link-image.txt SYS:save/m3-link-image-ok.txt

SYS:C/Which link-mixer-probe >SYS:tk4-m3-link-mixer-which.txt
SYS:link-mixer-probe
SYS:C/Echo $RC >SYS:tk4-m3-link-mixer-rc.txt
SYS:C/Rename SYS:save/m3-link-main.txt SYS:save/m3-link-mixer-main.txt
SYS:C/Rename SYS:save/m3-link-sdl.txt SYS:save/m3-link-mixer-sdl.txt
SYS:C/Rename SYS:save/m3-link-mixer.txt SYS:save/m3-link-mixer-ok.txt

SYS:C/Which link-full-probe >SYS:tk4-m3-link-full-which.txt
SYS:link-full-probe
SYS:C/Echo $RC >SYS:tk4-m3-link-full-rc.txt
SYS:C/Rename SYS:save/m3-link-main.txt SYS:save/m3-link-full-main.txt
SYS:C/Rename SYS:save/m3-link-sdl.txt SYS:save/m3-link-full-sdl.txt
SYS:C/Rename SYS:save/m3-link-image.txt SYS:save/m3-link-full-image.txt
SYS:C/Rename SYS:save/m3-link-mixer.txt SYS:save/m3-link-full-mixer.txt

SYS:C/Which tk4 >SYS:tk4-m3-which.txt
SYS:C/Echo "M3_BEFORE_TK4=1" >SYS:tk4-m3-before.txt
SYS:tk4
SYS:C/Echo $RC >SYS:tk4-m3-rc.txt
SYS:C/Echo "M3_AFTER_TK4=1" >SYS:tk4-m3-after.txt
SYS:C/Execute SYS:S/Startup-Sequence.tk4-m3-original
EOF

rm -f "$aros_root"/tk4-m3-*.txt
rm -f "$aros_root/save"/m3-*.txt

config="$OUT_DIR/aros-guest.fs-uae"
sed "s|@AROS_ROOT@|$PWD/$aros_root|" ci/fs-uae/aros-guest.fs-uae > "$config"
fs-uae --version > "$OUT_DIR/fs-uae-version.txt" 2>&1 || true

set +e
timeout 45s xvfb-run -a fs-uae "$config" > "$OUT_DIR/fs-uae.log" 2>&1
fsuae_rc=$?
set -e

started="$aros_root/tk4-m3-started.txt"
save_writable="$aros_root/save/m3-guest-save-writable.txt"
loader_probe="$aros_root/save/m3-loader-probe.txt"
cxx_ctor="$aros_root/save/m3-cxx-ctor.txt"
cxx_main="$aros_root/save/m3-cxx-main.txt"
sdl_main="$aros_root/save/m3-sdl-main.txt"
sdl_init="$aros_root/save/m3-sdl-init.txt"
link_sdl_main="$aros_root/save/m3-link-sdl-main.txt"
link_sdl_ok="$aros_root/save/m3-link-sdl-ok.txt"
link_image_main="$aros_root/save/m3-link-image-main.txt"
link_image_ok="$aros_root/save/m3-link-image-ok.txt"
link_mixer_main="$aros_root/save/m3-link-mixer-main.txt"
link_mixer_ok="$aros_root/save/m3-link-mixer-ok.txt"
link_full_main="$aros_root/save/m3-link-full-main.txt"
link_full_image="$aros_root/save/m3-link-full-image.txt"
link_full_mixer="$aros_root/save/m3-link-full-mixer.txt"
before="$aros_root/tk4-m3-before.txt"
after="$aros_root/tk4-m3-after.txt"
main_started="$aros_root/save/m3-main-started.txt"
splash_ok="$aros_root/save/m3-splash-ok.txt"
app_ok="$aros_root/save/m3-app-ok.txt"
menu_ok="$aros_root/save/m3-menu-mode-ok.txt"
loop_ok="$aros_root/save/m3-loop-entered.txt"

status=FAIL
observation=guest_result_missing
if [[ -f "$started" && -f "$save_writable" && -f "$loader_probe" && -f "$cxx_ctor" && -f "$cxx_main" && -f "$sdl_main" && -f "$sdl_init" && -f "$link_sdl_ok" && -f "$link_image_ok" && -f "$link_mixer_ok" && -f "$link_full_image" && -f "$link_full_mixer" && -f "$main_started" && -f "$splash_ok" && -f "$app_ok" && -f "$menu_ok" && -f "$loop_ok" && ! -f "$after" ]]; then
  status=PASS
  observation=tk4_reached_splash_app_menu_and_game_loop
elif [[ ! -f "$save_writable" ]]; then
  observation=guest_could_not_write_sys_save_preflight
elif [[ ! -f "$loader_probe" ]]; then
  observation=minimal_bebbo_loader_probe_did_not_reach_main
elif [[ ! -f "$cxx_ctor" ]]; then
  observation=cxx_runtime_failed_before_static_constructor
elif [[ ! -f "$cxx_main" ]]; then
  observation=cxx_static_constructor_ran_but_main_not_reached
elif [[ ! -f "$sdl_main" ]]; then
  observation=sdl_linked_program_failed_before_main
elif [[ ! -f "$sdl_init" ]]; then
  observation=sdl_program_reached_main_but_sdl_init_failed
elif [[ ! -f "$link_sdl_main" ]]; then
  observation=tk4_shaped_sdl_link_failed_before_main
elif [[ ! -f "$link_sdl_ok" ]]; then
  observation=tk4_shaped_sdl_probe_failed_after_main
elif [[ ! -f "$link_image_main" ]]; then
  observation=sdl_image_link_introduced_pre_main_failure
elif [[ ! -f "$link_image_ok" ]]; then
  observation=sdl_image_initialization_failed
elif [[ ! -f "$link_mixer_main" ]]; then
  observation=sdl_mixer_link_introduced_pre_main_failure
elif [[ ! -f "$link_mixer_ok" ]]; then
  observation=sdl_mixer_initialization_failed
elif [[ ! -f "$link_full_main" ]]; then
  observation=combined_image_mixer_link_introduced_pre_main_failure
elif [[ ! -f "$link_full_image" || ! -f "$link_full_mixer" ]]; then
  observation=combined_image_mixer_probe_failed_after_main
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
  observation=tk4_pre_main_failure_after_all_library_probes_pass
fi

{
  echo "STATUS=$status"
  echo "GATE=M3_AROS_PLAYABLE_BASELINE"
  echo "MODEL=A1200"
  echo "KICKSTART=internal"
  echo "FAST_MEMORY_KB=8192"
  echo "REQUESTED_STACK=262144"
  echo "FS_UAE_EXIT=$fsuae_rc"
  echo "OBSERVATION=$observation"
  echo "GUEST_STARTED=$([[ -f "$started" ]] && echo yes || echo no)"
  echo "SAVE_WRITABLE=$([[ -f "$save_writable" ]] && echo yes || echo no)"
  echo "LOADER_PROBE=$([[ -f "$loader_probe" ]] && echo yes || echo no)"
  echo "CXX_CTOR=$([[ -f "$cxx_ctor" ]] && echo yes || echo no)"
  echo "CXX_MAIN=$([[ -f "$cxx_main" ]] && echo yes || echo no)"
  echo "SDL_MAIN=$([[ -f "$sdl_main" ]] && echo yes || echo no)"
  echo "SDL_INIT=$([[ -f "$sdl_init" ]] && echo yes || echo no)"
  echo "LINK_SDL_MAIN=$([[ -f "$link_sdl_main" ]] && echo yes || echo no)"
  echo "LINK_SDL_OK=$([[ -f "$link_sdl_ok" ]] && echo yes || echo no)"
  echo "LINK_IMAGE_MAIN=$([[ -f "$link_image_main" ]] && echo yes || echo no)"
  echo "LINK_IMAGE_OK=$([[ -f "$link_image_ok" ]] && echo yes || echo no)"
  echo "LINK_MIXER_MAIN=$([[ -f "$link_mixer_main" ]] && echo yes || echo no)"
  echo "LINK_MIXER_OK=$([[ -f "$link_mixer_ok" ]] && echo yes || echo no)"
  echo "LINK_FULL_MAIN=$([[ -f "$link_full_main" ]] && echo yes || echo no)"
  echo "LINK_FULL_IMAGE=$([[ -f "$link_full_image" ]] && echo yes || echo no)"
  echo "LINK_FULL_MIXER=$([[ -f "$link_full_mixer" ]] && echo yes || echo no)"
  echo "MAIN_STARTED=$([[ -f "$main_started" ]] && echo yes || echo no)"
  echo "SPLASH_OK=$([[ -f "$splash_ok" ]] && echo yes || echo no)"
  echo "APP_INIT_OK=$([[ -f "$app_ok" ]] && echo yes || echo no)"
  echo "MENU_MODE_OK=$([[ -f "$menu_ok" ]] && echo yes || echo no)"
  echo "GAME_LOOP_ENTERED=$([[ -f "$loop_ok" ]] && echo yes || echo no)"
  echo "RETURNED=$([[ -f "$after" ]] && echo yes || echo no)"
  for kind in loader cxx sdl link-sdl link-image link-mixer link-full; do
    rcfile="$aros_root/tk4-m3-${kind}-rc.txt"
    whichfile="$aros_root/tk4-m3-${kind}-which.txt"
    label="$(printf '%s' "$kind" | tr '[:lower:]-' '[:upper:]_')"
    [[ -f "$rcfile" ]] && tr -d '\r' < "$rcfile" | sed "s/^/${label}_RC=/"
    [[ -f "$whichfile" ]] && tr -d '\r' < "$whichfile" | sed "s/^/${label}_WHICH=/"
  done
  [[ -f "$aros_root/tk4-m3-stack-rc.txt" ]] && tr -d '\r' < "$aros_root/tk4-m3-stack-rc.txt" | sed 's/^/STACK_RC=/'
  if [[ -f "$aros_root/tk4-m3-stack-value.txt" ]]; then
    echo "--- STACK_VALUE ---"
    tr -d '\r' < "$aros_root/tk4-m3-stack-value.txt"
  fi
  [[ -f "$aros_root/tk4-m3-which.txt" ]] && tr -d '\r' < "$aros_root/tk4-m3-which.txt" | sed 's/^/GUEST_WHICH=/'
} | tee "$OUT_DIR/result.txt"

[[ "$status" == PASS ]]
