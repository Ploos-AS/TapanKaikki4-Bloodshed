# Classic Amiga port

This fork carries an experimental classic AmigaOS port of Tapan Kaikki 4: Bloodshed.

## M0 target

M0 establishes the porting foundation only. It does not claim a playable Amiga build yet.

Initial target:

- AmigaOS 3.1-class systems
- Motorola 68020 baseline
- no mandatory FPU (`-msoft-float`)
- Bebbo `m68k-amigaos-gcc/g++` toolchain
- SDL 1.2 based video/input path
- game executable first; editor is excluded from Amiga builds
- SDL_mixer and SDL_net remain dependencies for the first complete game link and may be made optional during later bring-up if necessary

The source project already uses SDL 1.x and software-oriented rendering, which gives the port a much better starting point than an OpenGL-only engine.

## Building the M0 configuration

With the Bebbo toolchain and Amiga SDL development libraries installed:

```sh
cmake -S . -B build-amiga \
  -DCMAKE_TOOLCHAIN_FILE=cmake/amiga-toolchain.cmake \
  -DTK4_AMIGA=ON
cmake --build build-amiga
```

The exact SDL library discovery/setup is expected to evolve during M1 as the cross-build environment is qualified.

## Files and directories

Unix builds use the existing installation data directory and `$HOME/.tapankaikki/` save directory.

Classic Amiga builds use paths relative to the executable through `PROGDIR:`:

- game data: `PROGDIR:data/`
- writable game state: `PROGDIR:save/`

M0 deliberately avoids making assumptions about a global Amiga installation layout.

## Out of scope for M0

- runtime qualification in FS-UAE or real hardware
- performance optimisation
- 68000 support
- editor port / GTK replacement
- packaging/install script
- joystick-specific Amiga tuning
- network qualification
- audio qualification

## Roadmap

### M1 — first cross-build

1. qualify the Bebbo GCC + SDL 1.2 cross environment
2. fix compile-time Amiga portability problems
3. produce an Amiga executable/HUNK
4. separate optional audio/network dependencies if they block bring-up

### M2 — first runtime

1. launch under FS-UAE on an AmigaOS 3.1 environment
2. reach splash/menu
3. verify keyboard/mouse input and software video mode
4. verify data/save path handling

### M3 — playable baseline

1. load a level
2. run a single-player game
3. qualify audio
4. qualify input/game controls
5. establish minimum practical CPU/RAM requirements

### Later

- multiplayer / SDL_net
- joystick/gamepad support
- 68030/040/060 optimisations
- possible 68000 feasibility study
- Amiga-friendly installer/package
