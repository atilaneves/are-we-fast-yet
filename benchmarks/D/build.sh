#!/bin/bash
set -e # make script fail on first error
SCRIPT_PATH="$(dirname "$0")"
source "$SCRIPT_PATH/../script.inc"

if [ -z "$OPT" ]; then
  OPT='-O3'
fi

if [ -z "$DC" ]; then
  DC=ldc2
fi

if [ "$1" = "style" ]; then
  exit 0
fi

pushd "$SCRIPT_PATH" > /dev/null

INFO Build D Benchmarks with $DC and $OPT
$DC $OPT -Isrc src/*.d src/som/*.d -of=harness -od=build
popd > /dev/null
