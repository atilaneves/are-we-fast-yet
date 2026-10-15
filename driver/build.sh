#!/bin/bash
# Build the native and wasm executors that the comparison needs.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/benchmarks/C++"
CXX=clang++ OPT='-O3 -flto' ./build.sh
# wasi-sdk is not installed; /usr/share/wasi-sysroot and clang are.
clang++ --target=wasm32-wasip1 --sysroot=/usr/share/wasi-sysroot \
    -O3 -flto -ffp-contract=off -std=c++17 \
    src/harness.cpp src/deltablue.cpp src/memory/object_tracker.cpp \
    src/richards.cpp wasi/throw_abort.cpp -o harness.wasm
cd "$root/benchmarks/D"
./build.sh
# D-symgc: the D-gc build (ldc2 -O3) with the symgc 0.0.9 sources compiled in.
# It is selected at run time by --DRT-gcopt=gc:sdcq (see driver/README.md).
symgc="$(ls -d "$HOME"/.dub/packages/symgc/0.0.9/symgc/source)"
symgc_files=$(cd "$symgc" && find . -name '*.d' ! -path './core/sys/windows/*' \
    ! -path './d/sync/win32/*' | sed "s|^\.|$symgc|")
# shellcheck disable=SC2086
ldc2 -O3 --d-version=Symgc_druntime_hooks -Isrc "-I$symgc" src/*.d src/som/*.d \
    $symgc_files -of=harness-symgc -od=build-symgc
# ant is not installed; this does what build.xml's jar target does.
cd "$root/benchmarks/Java"
rm -rf build
mkdir build
javac -d build $(find src -name "*.java")
jar cf benchmarks.jar -C build .
