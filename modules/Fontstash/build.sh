#!/bin/bash
# Builds fontstash (with stb_truetype) as a plain static library, without the
# sokol glue the sokol-jai version comes with. Run on each platform:
#   ./build.sh linux | macos | wasm
set -e
cd "$(dirname "$0")"
case "$1" in
    linux) cc -c -O2 -fPIC source/fontstash.c -o fontstash.o && mkdir -p linux && ar rcs linux/fontstash.a fontstash.o ;;
    macos) cc -c -O2 -arch arm64 -arch x86_64 source/fontstash.c -o fontstash.o && mkdir -p macos && ar rcs macos/fontstash.a fontstash.o ;;
    wasm)  emcc -c -O2 -sMEMORY64 source/fontstash.c -o fontstash.o && mkdir -p wasm && emar rcs wasm/fontstash.a fontstash.o ;;
    *) echo "usage: $0 linux|macos|wasm"; exit 1 ;;
esac
rm fontstash.o
