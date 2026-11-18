#!/bin/bash
# Final X1 timing matrix (#353). Sides: base0/base1 = master dac9f4b twice (A/A), x1a = bit-identical prototype,
# x1d = in-range-threshold prototype (same arithmetic as x1b). Pinned to one P-core; BLAS 1 thread.
set -u
RUN=<RUN>
T=$RUN/experiments/timing; cd <WORK>/ps-353
export X1_SIDES="base0=ps-353,base1=ps-353,x1a=ps-353-x1a,x1d=ps-353-x1d"
for ch in lts release; do
  uptime > $T/x1-final-$ch.load
  X1_WL="W1,W3" taskset -c 2 julia +$ch --project=. $T/x1_paired.jl $T/x1-final-solve-$ch.tsv 15 > $T/x1-final-solve-$ch.log 2>&1
  taskset -c 2 julia +$ch --project=. $T/x1_visit.jl $T/x1-final-visit-$ch.tsv 15 > $T/x1-final-visit-$ch.log 2>&1
  uptime >> $T/x1-final-$ch.load
done
# Julia 1.10 with an AVX2 code target (the default target of 1.10 on this CPU is goldmont, without AVX)
taskset -c 2 julia +lts -C alderlake --project=. $T/x1_visit.jl $T/x1-final-visit-lts-alderlake.tsv 15 > $T/x1-final-visit-lts-alderlake.log 2>&1
X1_WL="W1,W3" taskset -c 2 julia +lts -C alderlake --project=. $T/x1_paired.jl $T/x1-final-solve-lts-alderlake.tsv 15 > $T/x1-final-solve-lts-alderlake.log 2>&1
echo done > $T/x1-final.done
