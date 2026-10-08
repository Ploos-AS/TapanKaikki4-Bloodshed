# M3 pre-main failure triage

## Reproduction

At commit `42971b53bd1f7e952246b177a1a4fe67ddc23472`, the `Amiga M3 playable baseline` workflow run [37324909646](https://github.com/Ploos-AS/TapanKaikki4-Bloodshed/actions/runs/37324909646) fails in `Execute playable-baseline gate inside AROS guest`.

The FS-UAE A1200/AROS guest starts, SYS:save is writable, and standalone Bebbo C++, SDL, SDL_image and SDL_mixer probes pass. The full TK4 object-set probe writes `M3_BEFORE_OBJECT_FULL=1` but does not write `m3-tk4-objects-main.txt`; the real game does not reach `main()`. Stack is confirmed at 262144 bytes and Fast RAM at 8192 KiB. Exit 124 is the harness timeout, **not** evidence of a program exit code.

## Isolation plan

1. Preserve the failing baseline as a mandatory gate. Do not classify green diagnostic workflows as a playable pass.
2. Compare the object-prefix and leave-one-out artifacts from the same commit. Find the smallest failing set; verify its failure twice under the same FS-UAE image and timeout.
3. For each candidate, compare ELF/HUNK sections, relocation count and types, linked image size, and symbol layout; use the existing GNU ld versus vlink diagnostic workflows. Treat correlation as a hypothesis until a controlled change restores the marker.
4. Re-run a positive-control probe immediately before and after the failing probe, and capture the Amiga shell return code and FS-UAE guest log. Distinguish guest hang, loader rejection, memory exhaustion, and a crash before C++ main.
5. Apply the smallest source/linker fix and require both the object-full marker and real-game `main()` marker before validating splash, menu and game-loop markers.
6. After automated AROS passes, qualify on real Kickstart/Workbench locally; do not redistribute copyrighted Kickstart images.

## Acceptance criteria

- `OBJECT_FULL_MAIN=yes` and `MAIN_STARTED=yes` on the same build.
- `SPLASH_OK=yes`, `APP_INIT_OK=yes`, `MENU_MODE_OK=yes`, `GAME_LOOP_ENTERED=yes`.
- No return to Startup-Sequence before the game-loop gate.
- Test artifacts retain logs, HUNK diagnostics and the exact build SHA.
- Audio quality, controls and gameplay interaction remain separate follow-up gates.

The project remains GPL-2.0-only per upstream licensing.

## Evidence update — 2026-10-08, commit 9f7acc4

- [Prefix run 37702906530](https://github.com/Ploos-AS/TapanKaikki4-Bloodshed/actions/runs/37702906530): 57/58 prefixes did **not link**; only prefix 058 (all 58 objects) linked, and `MAIN=no` with guest boot/before evidence present. `FIRST_FAILURE=058` does **not** identify `texts.cpp` as causal: it is simply the last file in the first linkable prefix.
- [Leave-one-out run 37702906440](https://github.com/Ploos-AS/TapanKaikki4-Bloodshed/actions/runs/37702906440): 2/58 exclusions linked (CGameApp.cpp and CSplash.cpp), and both failed before main. `MAIN_REACHED_PROBES=0`; remaining 56 exclusions were linker failures and yield no runtime evidence.
- [Linker comparison 37702906457](https://github.com/Ploos-AS/TapanKaikki4-Bloodshed/actions/runs/37702906457): GNU ld links the full object set (`GNU_LINK_RC=0`) but `GNU_MAIN=no`; old/new vlink variants return link error 1, so they cannot be compared at runtime yet.

**Interpretation:** Existing prefix/drop results cannot isolate the offending translation unit because almost every reduced set has unresolved dependencies. The next experiment must retain dependency closure (or supply controlled stubs), and distinguish successful linking from runtime success. Avoid claiming a specific object is defective from the prefix ordering.
