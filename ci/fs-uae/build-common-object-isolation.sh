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
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
ARCHIVE=build-amiga-tu-base/libtk4-common.a
: > build-amiga-tu-out/manifest.tsv
: > build-amiga-tu-out/object-report.txt

$AR t "$ARCHIVE" | grep "\.cpp\.obj$" | while read -r member; do
  variant="${member%.cpp.obj}"
  safe="$(printf "%s" "$variant" | tr "[:upper:]_" "[:lower:]-")"
  obj="build-amiga-tu-out/${safe}.obj"
  rest="build-amiga-tu-out/lib-${safe}-rest.a"
  marker="m3-object-${safe}-main.txt"
  mainobj="build-amiga-tu-out/object-${safe}-main.o"
  bin="build-amiga-tu-out/object-${safe}-probe"

  $AR p "$ARCHIVE" "$member" > "$obj"
  cp "$ARCHIVE" "$rest"
  $AR d "$rest" "$member"

  $CXX $BASE -DPROBE_MARKER=\"SYS:save/${marker}\" -DPROBE_LABEL=\"OBJECT_${safe}_MAIN=1\\n\" \
    -c ci/fs-uae/tk4-object-probe.cpp -o "$mainobj"
  $CXX $BASE "$mainobj" "$obj" "$rest" $LIBS \
    -Wl,-Map="build-amiga-tu-out/object-${safe}.map" -Wl,-t \
    -o "$bin" 2>"build-amiga-tu-out/object-${safe}.trace"

  printf "object\t%s\t%s\n" "$safe" "$marker" >> build-amiga-tu-out/manifest.tsv
  echo "=== ${member} ===" >> build-amiga-tu-out/object-report.txt
  stat -c "BYTES=%s" "$bin" >> build-amiga-tu-out/object-report.txt
  /opt/amiga/bin/m68k-amigaos-size -A "$bin" >> build-amiga-tu-out/object-report.txt || true
  rm -f "$rest"
done
cat build-amiga-tu-out/manifest.tsv
cat build-amiga-tu-out/object-report.txt
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-tu-*
