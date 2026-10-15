#!/bin/bash
# Run the whole comparison: pre-run every command once (discarded), then the
# `wall` and `iterations` experiments with ReBench. Results go to results/.
# usage: driver/compare.sh [BENCHMARK]   (BENCHMARK limits the run to one)
# Environment (all optional):
#   EXECUTORS="D-symgc sb-symgc"  run only these executors
#   RESULTS=DIR                   write the data to DIR (default: results)
#   SUITES=wall                   skip the iterations suite
# To pin a run to one core: taskset -c 15 driver/compare.sh
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
out="${RESULTS:-results}"
for e in $EXECUTORS; do
    wall_filter+=("e:$e"); iter_filter+=("e:$e")
done
export EXECUTORS
mkdir -p "$out" results/sb-manual
unset AWFY_LOG
driver/prewarm.py compare.conf wall "$out/prewarm.tsv" 3600 "${wall_filter[@]}"
rm -f "$out/wall.log"
echo "export AWFY_LOG='$root/$out/wall.log'" >>.awfy-env
rebench -D -c -df "$out/wall.data" \
    compare.conf wall "${wall_filter[@]}"
[ "${SUITES:-}" = wall ] && exit 0
echo "export PATH='$PATH' HOME='$HOME'" >.awfy-env
rebench -D -c -df "$out/iterations.data" compare.conf iterations "${iter_filter[@]}"
