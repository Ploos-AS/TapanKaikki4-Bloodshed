# Toolchain file for classic AmigaOS/m68k using the Bebbo GCC toolchain.
#
# Usage:
#   mkdir build-amiga && cd build-amiga
#   cmake .. \
#     -DCMAKE_TOOLCHAIN_FILE=../cmake/amiga-toolchain.cmake \
#     -DTK4_AMIGA=ON

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR m68k)

set(AMIGA_TOOLCHAIN_PREFIX "m68k-amigaos" CACHE STRING "Amiga GCC target prefix")
set(AMIGA_TOOLCHAIN_BIN "/opt/amiga/bin" CACHE PATH "Directory containing the Bebbo cross tools")

# Use absolute tool paths. Older CMake versions (including the 3.10 shipped in
# the qualification image) do not reliably carry a bare CMAKE_AR/CMAKE_RANLIB
# name into nested try_compile projects.
set(CMAKE_C_COMPILER   "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-gcc" CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-g++" CACHE FILEPATH "" FORCE)
set(CMAKE_AR           "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-ar" CACHE FILEPATH "" FORCE)
set(CMAKE_RANLIB       "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-ranlib" CACHE FILEPATH "" FORCE)
set(CMAKE_NM           "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-nm" CACHE FILEPATH "" FORCE)
set(CMAKE_OBJCOPY      "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-objcopy" CACHE FILEPATH "" FORCE)
set(CMAKE_OBJDUMP      "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-objdump" CACHE FILEPATH "" FORCE)
set(CMAKE_STRIP        "${AMIGA_TOOLCHAIN_BIN}/${AMIGA_TOOLCHAIN_PREFIX}-strip" CACHE FILEPATH "" FORCE)

# M1 baseline: AmigaOS 3.1-class system, 68020 CPU, no mandatory FPU.
# -noixemul matches the static Bebbo/AmigaPorts model used by the SDL libs in
# the qualification image and avoids an ixemul.library runtime dependency.
set(CMAKE_C_FLAGS_INIT   "-m68020 -msoft-float -noixemul")
set(CMAKE_CXX_FLAGS_INIT "-m68020 -msoft-float -noixemul")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-noixemul")

# Let CMake verify the real cross linker. It only builds the probe; it does not
# attempt to execute the resulting Amiga program on the Linux host.
