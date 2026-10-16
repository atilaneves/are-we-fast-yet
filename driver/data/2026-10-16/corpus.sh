#!/bin/bash
# usage: corpus.sh BEFORE_BENCH AFTER_BENCH OUTDIR
# Runs bin/bench -b bytecode on every build/bench-corpus.sh project, before then after,
# pinned to one core; one log per project and build.
before=$1; after=$2; out=$3
mkdir -p "$out"
cd /home/atila/coding/d/snakebite
projects=$(sed -n '/^benchmarks=(/,/^)/p' build/bench-corpus.sh | grep -v '^\s*#' | grep -oE '[A-Za-z0-9_.-]+@[A-Za-z0-9_.+-]+')
for p in $projects; do
  for v in before after; do
    eval b=\$$v
    taskset -c 25 timeout 1800 "$b" "$p" -b bytecode -w 1 -r 3 > "$out/$p.$v.txt" 2>&1
    echo "$p $v exit $?" >> "$out/status.txt"
  done
done
echo DONE >> "$out/status.txt"
