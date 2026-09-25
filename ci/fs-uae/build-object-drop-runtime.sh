#!/usr/bin/env bash
set -euo pipefail
rm -rf build-amiga-drop
mkdir build-amiga-drop
docker run --rm -v "$PWD:/work" -w /work ozzyboshi/bebbo-amiga-gcc:latest bash -lc '
set -euxo pipefail
if ! command -v cmake >/dev/null 2>&1; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y cmake; fi
mkdir -p build-amiga-drop/base
cd build-amiga-drop/base
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=../../cmake/amiga-toolchain.cmake -DTK4_AMIGA=ON -DCMAKE_BUILD_TYPE=Release \
 -DSDL_INCLUDE_DIR=/opt/amiga/m68k-amigaos/include/SDL -DSDL_LIBRARY=/opt/amiga/m68k-amigaos/lib/libSDL.a \
 -DSDL_IMAGE_INCLUDE_DIR=/opt/amiga/SDL_image-pack/include/SDL -DSDL_IMAGE_LIBRARY=/opt/amiga/SDL_image-pack/lib/libSDL_image.a \
 -DSDL_MIXER_INCLUDE_DIR=/opt/amiga/SDL_mixer/include -DSDL_MIXER_LIBRARY=/opt/amiga/SDL_mixer/lib/libSDL_mixer.a
cmake --build . -- -j2
cd ../..
CXX=/opt/amiga/bin/m68k-amigaos-g++; BASE="-m68020 -msoft-float -noixemul"
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
mapfile -t OBJS < <(find build-amiga-drop/base/CMakeFiles/tk4.dir -type f -name "*.obj" ! -path "*/main.cpp.obj" | sort)
$CXX $BASE -c ci/fs-uae/tk4-object-probe.cpp -o build-amiga-drop/main.o
: > build-amiga-drop/manifest.tsv
for drop in "${!OBJS[@]}"; do
  KEEP=(); for i in "${!OBJS[@]}"; do [ "$i" -eq "$drop" ] || KEEP+=("${OBJS[$i]}"); done
  id=$(printf "%03d" "$drop"); bin="build-amiga-drop/drop-$id-probe"
  set +e; $CXX $BASE build-amiga-drop/main.o "${KEEP[@]}" build-amiga-drop/base/libtk4-common.a $LIBS -o "$bin" 2>"$bin.link.txt"; rc=$?; set -e
  [ "$rc" -eq 0 ] || rm -f "$bin"
  printf "%s\t%s\t%s\n" "$id" "$rc" "${OBJS[$drop]}" >> build-amiga-drop/manifest.tsv
done
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-drop
