#!/usr/bin/env bash
set -euo pipefail
rm -rf build-amiga-vlink-full
mkdir -p build-amiga-vlink-full
docker run --rm -v "$PWD:/work" -w /work ozzyboshi/bebbo-amiga-gcc:latest bash -lc '
set -euxo pipefail
if ! command -v cmake >/dev/null 2>&1; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y cmake; fi
mkdir -p build-amiga-vlink-full/base build-amiga-vlink-full/bin
cd build-amiga-vlink-full/base
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=../../cmake/amiga-toolchain.cmake -DTK4_AMIGA=ON -DCMAKE_BUILD_TYPE=Release  -DSDL_INCLUDE_DIR=/opt/amiga/m68k-amigaos/include/SDL -DSDL_LIBRARY=/opt/amiga/m68k-amigaos/lib/libSDL.a  -DSDL_IMAGE_INCLUDE_DIR=/opt/amiga/SDL_image-pack/include/SDL -DSDL_IMAGE_LIBRARY=/opt/amiga/SDL_image-pack/lib/libSDL_image.a  -DSDL_MIXER_INCLUDE_DIR=/opt/amiga/SDL_mixer/include -DSDL_MIXER_LIBRARY=/opt/amiga/SDL_mixer/lib/libSDL_mixer.a
cmake --build . -- -j2
cd ../..
CXX=/opt/amiga/bin/m68k-amigaos-g++
BASE="-m68020 -msoft-float -noixemul"
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
mapfile -t OBJS < <(find build-amiga-vlink-full/base/CMakeFiles/tk4.dir -type f -name "*.obj" ! -path "*/main.cpp.obj" | sort)
$CXX $BASE -c ci/fs-uae/tk4-object-probe.cpp -o build-amiga-vlink-full/main.o
ln -sf /opt/amiga/bin/vlink build-amiga-vlink-full/bin/ld
: > build-amiga-vlink-full/report.txt
set +e
$CXX $BASE build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS -o build-amiga-vlink-full/full-gnu 2>build-amiga-vlink-full/gnu-link.txt
gnu_rc=$?
$CXX $BASE -B"$PWD/build-amiga-vlink-full/bin/" build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS -o build-amiga-vlink-full/full-vlink 2>build-amiga-vlink-full/vlink-link.txt
vlink_rc=$?
set -e
printf "OBJECT_COUNT=%s\nGNU_LINK_RC=%s\nVLINK_LINK_RC=%s\n" "${#OBJS[@]}" "$gnu_rc" "$vlink_rc" >> build-amiga-vlink-full/report.txt
[ "$gnu_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-gnu
[ "$vlink_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-vlink
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-vlink-full
