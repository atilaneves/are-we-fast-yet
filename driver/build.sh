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
# ant is not installed; this does what build.xml's jar target does.
cd "$root/benchmarks/Java"
rm -rf build
mkdir build
javac -d build $(find src -name "*.java")
jar cf benchmarks.jar -C build .
