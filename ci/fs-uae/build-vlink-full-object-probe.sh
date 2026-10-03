#!/usr/bin/env bash
set -euo pipefail
rm -rf build-amiga-vlink-full
mkdir -p build-amiga-vlink-full
docker run --rm -v "$PWD:/work" -w /work ozzyboshi/bebbo-amiga-gcc:latest bash -lc '
set -euxo pipefail
if ! command -v cmake >/dev/null 2>&1; then apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y cmake; fi
mkdir -p build-amiga-vlink-full/base build-amiga-vlink-full/bin-old build-amiga-vlink-full/bin-new build-amiga-vlink-full/modern-vlink/src
cd build-amiga-vlink-full/base
cmake ../.. -DCMAKE_TOOLCHAIN_FILE=../../cmake/amiga-toolchain.cmake -DTK4_AMIGA=ON -DCMAKE_BUILD_TYPE=Release  -DSDL_INCLUDE_DIR=/opt/amiga/m68k-amigaos/include/SDL -DSDL_LIBRARY=/opt/amiga/m68k-amigaos/lib/libSDL.a  -DSDL_IMAGE_INCLUDE_DIR=/opt/amiga/SDL_image-pack/include/SDL -DSDL_IMAGE_LIBRARY=/opt/amiga/SDL_image-pack/lib/libSDL_image.a  -DSDL_MIXER_INCLUDE_DIR=/opt/amiga/SDL_mixer/include -DSDL_MIXER_LIBRARY=/opt/amiga/SDL_mixer/lib/libSDL_mixer.a
cmake --build . -- -j2
cd ../..
CXX=/opt/amiga/bin/m68k-amigaos-g++
BASE="-m68020 -msoft-float -noixemul"
LIBS="/opt/amiga/SDL_image-pack/lib/libSDL_image.a /opt/amiga/SDL_mixer/lib/libSDL_mixer.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
mkdir -p build-amiga-vlink-full/sdl-mixer-repack
( cd build-amiga-vlink-full/sdl-mixer-repack && /opt/amiga/bin/m68k-amigaos-ar x /opt/amiga/SDL_mixer/lib/libSDL_mixer.a )
/opt/amiga/bin/m68k-amigaos-ar rcs build-amiga-vlink-full/libSDL_mixer-repacked.a build-amiga-vlink-full/sdl-mixer-repack/*.o
LIBS_REPACK="/opt/amiga/SDL_image-pack/lib/libSDL_image.a $PWD/build-amiga-vlink-full/libSDL_mixer-repacked.a /opt/amiga/m68k-amigaos/lib/libSDL.a /opt/amiga/SDL_image-pack/lib/libjpeg.a /opt/amiga/SDL_image-pack/lib/libpng.a /opt/amiga/zlib-package/lib/libz.a -lpthread"
mapfile -t OBJS < <(find build-amiga-vlink-full/base/CMakeFiles/tk4.dir -type f -name "*.obj" ! -path "*/main.cpp.obj" | sort)
$CXX $BASE -c ci/fs-uae/tk4-object-probe.cpp -o build-amiga-vlink-full/main.o
cp ci/fs-uae/vlink-ld-wrapper.sh build-amiga-vlink-full/bin-old/ld
cp ci/fs-uae/vlink-ld-wrapper.sh build-amiga-vlink-full/bin-new/ld
chmod +x build-amiga-vlink-full/bin-old/ld build-amiga-vlink-full/bin-new/ld
git clone --depth=1 https://github.com/siemens-mobile-hacks/vlink.git build-amiga-vlink-full/modern-vlink/src
mkdir -p build-amiga-vlink-full/modern-vlink/src/objects
make -C build-amiga-vlink-full/modern-vlink/src
NEW_VLINK="$PWD/build-amiga-vlink-full/modern-vlink/src/vlink"
"$NEW_VLINK" -h | grep -q -- "-broken-debug"
"$NEW_VLINK" -v > build-amiga-vlink-full/modern-vlink-version.txt 2>&1 || true
git -C build-amiga-vlink-full/modern-vlink/src rev-parse HEAD > build-amiga-vlink-full/modern-vlink-commit.txt
: > build-amiga-vlink-full/report.txt
set +e
$CXX $BASE build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS -o build-amiga-vlink-full/full-gnu 2>build-amiga-vlink-full/gnu-link.txt
gnu_rc=$?
TK4_VLINK_WRAPPER_LOG="$PWD/build-amiga-vlink-full/vlink-old-wrapper.txt" TK4_VLINK_BIN=/opt/amiga/bin/vlink TK4_VLINK_BROKEN_DEBUG=0 $CXX $BASE -B"$PWD/build-amiga-vlink-full/bin-old/" build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS -o build-amiga-vlink-full/full-vlink-old 2>build-amiga-vlink-full/vlink-old-link.txt
vlink_old_rc=$?
TK4_VLINK_WRAPPER_LOG="$PWD/build-amiga-vlink-full/vlink-new-wrapper.txt" TK4_VLINK_BIN="$NEW_VLINK" TK4_VLINK_BROKEN_DEBUG=1 $CXX $BASE -B"$PWD/build-amiga-vlink-full/bin-new/" build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS -o build-amiga-vlink-full/full-vlink-new 2>build-amiga-vlink-full/vlink-new-link.txt
vlink_new_rc=$?
TK4_VLINK_WRAPPER_LOG="$PWD/build-amiga-vlink-full/vlink-new-repack-wrapper.txt" TK4_VLINK_BIN="$NEW_VLINK" TK4_VLINK_BROKEN_DEBUG=1 TK4_VLINK_TRACE_ACRYPT=1 $CXX $BASE -B"$PWD/build-amiga-vlink-full/bin-new/" build-amiga-vlink-full/main.o "${OBJS[@]}" build-amiga-vlink-full/base/libtk4-common.a $LIBS_REPACK -o build-amiga-vlink-full/full-vlink-new-repack 2>build-amiga-vlink-full/vlink-new-repack-link.txt
vlink_new_repack_rc=$?
echo "=== vlink stderr ==="
cat build-amiga-vlink-full/vlink-old-link.txt || true
cat build-amiga-vlink-full/vlink-new-link.txt || true
cat build-amiga-vlink-full/vlink-new-repack-link.txt || true
echo "=== vlink wrapper argv ==="
cat build-amiga-vlink-full/vlink-old-wrapper.txt || true
cat build-amiga-vlink-full/vlink-new-wrapper.txt || true
cat build-amiga-vlink-full/vlink-new-repack-wrapper.txt || true
set -e
printf "OBJECT_COUNT=%s\nGNU_LINK_RC=%s\nVLINK_OLD_LINK_RC=%s\nVLINK_NEW_LINK_RC=%s\nVLINK_NEW_REPACK_LINK_RC=%s\n" "${#OBJS[@]}" "$gnu_rc" "$vlink_old_rc" "$vlink_new_rc" "$vlink_new_repack_rc" >> build-amiga-vlink-full/report.txt
[ "$gnu_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-gnu
[ "$vlink_old_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-vlink-old
[ "$vlink_new_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-vlink-new
[ "$vlink_new_repack_rc" -eq 0 ] || rm -f build-amiga-vlink-full/full-vlink-new-repack
'
sudo chown -R "$(id -u):$(id -g)" build-amiga-vlink-full
