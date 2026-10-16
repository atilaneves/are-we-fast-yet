#!/bin/bash
B=/home/atila/coding/d/snakebite/.worktrees/compare-before/bin/bench
A=/home/atila/coding/d/snakebite/.worktrees/compare-after/bin/bench
out=/tmp/claude-1000/compare/corpus3
for r in 1 2 3; do
 for p in msgpack-d@1.0.5 sumtype@1.3.0; do
  for v in before after; do
   if [ $v = before ]; then b=$B; w=compare-before; else b=$A; w=compare-after; fi
   cd /home/atila/coding/d/snakebite/.worktrees/$w
   taskset -c 25 timeout 1800 "$b" "$p" -b bytecode -w 1 -r 5 > "$out/$p.$v.$r.txt" 2>&1
   echo "$p $v $r exit $?" >> "$out/status.txt"
  done
 done
done
echo DONE >> "$out/status.txt"
