#!/bin/bash
# Run the whole comparison: pre-run every command once (discarded), then the
# `wall` and `iterations` experiments with ReBench. Results go to results/.
# usage: driver/compare.sh [BENCHMARK]   (BENCHMARK limits the run to one)
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
SB="${SB:-/home/atila/coding/d/snakebite/bin/sb}"
export PATH="$HOME/.local/share/rebench-venv/bin:$HOME/.local/bin:$(dirname "$SB"):$PATH"
# ReBench starts commands with an empty environment; driver/run reads this.
echo "export PATH='$PATH' HOME='$HOME'" >.awfy-env
bench="$1"
wall_filter=(); iter_filter=()
if [ -n "$bench" ]; then
    wall_filter=("s:wall:$bench"); iter_filter=("s:iterations:$bench")
fi
mkdir -p results results/sb-manual
unset AWFY_LOG
driver/prewarm.py compare.conf wall results/prewarm.tsv 3600 "${wall_filter[@]}"
rm -f results/wall.log
echo "export AWFY_LOG='$root/results/wall.log'" >>.awfy-env
rebench -D -c -df results/wall.data \
    compare.conf wall "${wall_filter[@]}"
echo "export PATH='$PATH' HOME='$HOME'" >.awfy-env
rebench -D -c -df results/iterations.data compare.conf iterations "${iter_filter[@]}"
