#!/bin/bash
# usage: bench.sh out.tsv name=binary ...   (3 invocations, 20 iterations, median of iterations 3-20 in ms)
out=$1; shift
B="DeltaBlue:12000 Richards:100 Json:100 CD:250 Havlak:1500 Bounce:1500 List:1500 Mandelbrot:500 NBody:250000 Permute:1000 Queens:1000 Sieve:3000 Storage:1000 Towers:600"
: > $out
for inv in 1 2 3; do for b in $B; do name=${b%%:*}; arg=${b##*:}; for e in "$@"; do ex=${e%%=*}; bin=${e#*=}
  $bin $name 20 $arg | grep -o 'runtime: [0-9]*us' | grep -o '[0-9]*' | tail -n +3 | sort -n | awk -v e=$ex -v b=$name -v i=$inv '{a[NR]=$1} END{m=(NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2; printf "%s\t%s\t%d\t%.1f\n",e,b,i,m/1000}' >> $out
done; done; done
