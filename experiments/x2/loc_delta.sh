#!/bin/bash
# usage: loc_delta.sh TREE  -> per-file executable totals and per-function diff vs BASE
R=<RUN>
B=<WORK>/ps-353
T=$1; E=$R/experiments/x2
FILES="src/blocks.jl src/solvers/image_models.jl src/solvers/accelerated_proximal_gradient_descent.jl src/solvers/proximal_gradient_descent.jl src/cd/sqrtlasso.jl src/cd/leastsquares.jl"
for f in $FILES; do
  a=$(cd $B && python3 $R/tools/count_loc.py $f | head -1)
  b=$(cd $T && python3 $R/tools/count_loc.py $f | head -1)
  echo "$f | base: $a | new: $b"
done
for f in $FILES; do
  (cd $B && python3 $R/tools/count_loc.py $f | sed 's/^ *\([0-9]*\) *L[0-9]* */\1 /') > $E/.loc_b.txt
  (cd $T && python3 $R/tools/count_loc.py $f | sed 's/^ *\([0-9]*\) *L[0-9]* */\1 /') > $E/.loc_n.txt
  diff $E/.loc_b.txt $E/.loc_n.txt | grep '^[<>]' | sed "s|^|$f |"
done
rm -f $E/.loc_b.txt $E/.loc_n.txt
