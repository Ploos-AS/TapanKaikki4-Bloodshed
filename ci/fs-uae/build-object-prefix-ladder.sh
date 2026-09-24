#!/usr/bin/env bash
set -euo pipefail

rm -rf build-amiga-prefix-base build-amiga-prefix-out
mkdir build-amiga-prefix-base build-amiga-prefix-out

docker run --rm -v "$PWD:/work" -w /work ozzyboshi/bebbo-amiga-gcc:latest bash -lc '
set -euxo pipefail
if ! command -v cmake >/dev/null 2>&1; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y cmake; fi
cd build-amiga-prefix-base
cmake .. -DCMAKE_TOOLCHAIN_FILE=../cmake/amiga-toolchain.cmake -DTK4_AMIGA=ON -DCMAKE_BUILD_TYPE=Release \
  -DSDL_INCLUDE_DIR=/opt/amiga/m68k-amigaos/include/SDL -DSDL_LIBRARY=/opt/amiga/m68k-amigaos/lib/libSDL.a \
  -DSDL_IMAGE_INCLUDE_DIR=/opt/amiga/SDL_image-pack/include/SDL -DSDL_IMAGE_LIBRARY=/opt/amiga/SDL_image-pack/lib/libSDL_image.a \
  -DSDL_MIXER_INCLUDE_DIR=/opt/amiga/SDL_mixer/include -DSDL_MIXER_LIBRARY=/opt/amiga/SDL_mixer/lib/libSDL_mixer.a
cmake --build . -- -j2
cd ..
CXX=/opt/amiga/bin/m68k-amigaos-g++
BASE="-m68020 -msoft-float -noixemul"
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
mapfile -t OBJS < <(find build-amiga-prefix-base/CMakeFiles/tk4.dir -type f -name "*.obj" ! -path "*/main.cpp.obj" | sort)
$CXX $BASE -DPROBE_MARKER=\"SYS:save/m3-prefix-main.txt\" -DPROBE_LABEL=\"PREFIX_MAIN=1\\n\" -c ci/fs-uae/tk4-object-probe.cpp -o build-amiga-prefix-out/main.o
: > build-amiga-prefix-out/manifest.tsv
for n in $(seq 1 "${#OBJS[@]}"); do
  id=$(printf "%03d" "$n")
  prefix=("${OBJS[@]:0:$n}")
  bin="build-amiga-prefix-out/prefix-$id-probe"
  $CXX $BASE build-amiga-prefix-out/main.o "${prefix[@]}" build-amiga-prefix-base/libtk4-common.a $LIBS -Wl,-Map="$bin.map" -o "$bin"
  printf "%s\\t%s\\t%s\\n" "$id" "$n" "${OBJS[$((n-1))]}" >> build-amiga-prefix-out/manifest.tsv
done
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-prefix-*
