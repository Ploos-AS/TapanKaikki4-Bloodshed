#!/usr/bin/env bash
set -euo pipefail

rm -rf build-amiga-tu-base build-amiga-tu-out
mkdir build-amiga-tu-base build-amiga-tu-out

docker run --rm -v "$PWD:/work" -w /work ozzyboshi/bebbo-amiga-gcc:latest bash -lc '
set -euxo pipefail
if ! command -v cmake >/dev/null 2>&1; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y cmake; fi
cd build-amiga-tu-base
cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/amiga-toolchain.cmake -DTK4_AMIGA=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-m68020 -msoft-float -noixemul" \
  -DSDL_INCLUDE_DIR=/opt/amiga/m68k-amigaos/include/SDL -DSDL_LIBRARY=/opt/amiga/m68k-amigaos/lib/libSDL.a \
  -DSDL_IMAGE_INCLUDE_DIR=/opt/amiga/SDL_image-pack/include/SDL -DSDL_IMAGE_LIBRARY=/opt/amiga/SDL_image-pack/lib/libSDL_image.a \
  -DSDL_MIXER_INCLUDE_DIR=/opt/amiga/SDL_mixer/include -DSDL_MIXER_LIBRARY=/opt/amiga/SDL_mixer/lib/libSDL_mixer.a
cmake --build . --target tk4-common -- -j2
cd ..
CXX=/opt/amiga/bin/m68k-amigaos-g++; AR=/opt/amiga/bin/m68k-amigaos-ar
BASE="-m68020 -msoft-float -noixemul"
INC="-Isrc -Isrc/common -I/opt/amiga/m68k-amigaos/include/SDL -I/opt/amiga/SDL_image-pack/include/SDL -I/opt/amiga/SDL_mixer/include"
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
: > build-amiga-tu-out/manifest.tsv
steam_member="$($AR t build-amiga-tu-base/libtk4-common.a | grep "CSteam.cpp.obj" | head -n1)"
steamio_member="$($AR t build-amiga-tu-base/libtk4-common.a | grep "CSteamIO.cpp.obj" | head -n1)"
test -n "$steam_member"; test -n "$steamio_member"
cp build-amiga-tu-base/libtk4-common.a build-amiga-tu-out/libtk4-common-nosteam.a
$AR d build-amiga-tu-out/libtk4-common-nosteam.a "$steam_member" "$steamio_member"
cat > build-amiga-tu-out/csteam-ctor-float.cpp <<"EOF"
#include "CSteam.h"
CSteam::CSteam(float aX,float aY,int aAngle,int aSpeed) { iX=aX; iY=aY; iAngle=aAngle; iSpeed=aSpeed; }
EOF
cat > build-amiga-tu-out/csteam-ctor-file.cpp <<"EOF"
#include "CSteam.h"
CSteam::CSteam(FILE *fptr, int aVersion) { ReadFromFile(fptr, aVersion); }
EOF
cat > build-amiga-tu-out/csteam-method-stubs.cpp <<"EOF"
#include "CSteam.h"
void CSteam::ReadFromFile(FILE *, int) {}
void CSteam::WriteToFile(FILE *) {}
EOF
for src in csteam-ctor-float csteam-ctor-file csteam-method-stubs; do
  $CXX $BASE $INC -c "build-amiga-tu-out/${src}.cpp" -o "build-amiga-tu-out/${src}.obj"
done
for variant in empty float file both; do
  one="build-amiga-tu-out/lib-csteam-bisect-${variant}.a"
  case "$variant" in
    empty) $AR rcs "$one" build-amiga-tu-out/csteam-method-stubs.obj ;;
    float) $AR rcs "$one" build-amiga-tu-out/csteam-ctor-float.obj build-amiga-tu-out/csteam-method-stubs.obj ;;
    file) $AR rcs "$one" build-amiga-tu-out/csteam-ctor-file.obj build-amiga-tu-out/csteam-method-stubs.obj ;;
    both) $AR rcs "$one" build-amiga-tu-out/csteam-ctor-float.obj build-amiga-tu-out/csteam-ctor-file.obj build-amiga-tu-out/csteam-method-stubs.obj ;;
  esac
  marker="m3-tu-csteam-bisect-${variant}-main.txt"
  mainobj="build-amiga-tu-out/csteam-bisect-${variant}-main.o"
  bin="build-amiga-tu-out/csteam-bisect-${variant}-probe"
  $CXX $BASE -DPROBE_MARKER=\"SYS:save/${marker}\" -DPROBE_LABEL=\"TU_CSTEAM_BISECT_${variant}_MAIN=1\\n\" -c ci/fs-uae/tk4-object-probe.cpp -o "$mainobj"
  $CXX $BASE "$mainobj" -Wl,--whole-archive "$one" -Wl,--no-whole-archive build-amiga-tu-out/libtk4-common-nosteam.a $LIBS -Wl,-Map="build-amiga-tu-out/csteam-bisect-${variant}.map" -o "$bin"
  printf "csteam-bisect\t%s\t%s\n" "$variant" "$marker" >> build-amiga-tu-out/manifest.tsv
done
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-tu-*
