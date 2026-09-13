# Toolchain file for classic AmigaOS/m68k using the Bebbo GCC toolchain.
#
# Usage:
#   cmake -S . -B build-amiga \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/amiga-toolchain.cmake \
#     -DTK4_AMIGA=ON
#
# Override AMIGA_TOOLCHAIN_PREFIX if the compiler binaries use a different
# prefix or are installed outside PATH.

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR m68k)

set(AMIGA_TOOLCHAIN_PREFIX "m68k-amigaos" CACHE STRING "Amiga GCC target prefix")

set(CMAKE_C_COMPILER   "${AMIGA_TOOLCHAIN_PREFIX}-gcc")
set(CMAKE_CXX_COMPILER "${AMIGA_TOOLCHAIN_PREFIX}-g++")
set(CMAKE_AR           "${AMIGA_TOOLCHAIN_PREFIX}-ar")
set(CMAKE_RANLIB       "${AMIGA_TOOLCHAIN_PREFIX}-ranlib")

# M0 baseline: AmigaOS 3.1-class system, 68020 CPU, no mandatory FPU.
set(CMAKE_C_FLAGS_INIT   "-m68020 -msoft-float")
set(CMAKE_CXX_FLAGS_INIT "-m68020 -msoft-float")

# Do not try to execute test binaries on the build host.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
