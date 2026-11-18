#!/bin/bash
# usage: loc_delta.sh  -> executable lines per file, base vs the head worktree
S0=<STAGE0-RUN>
B=<WORK>/ProximalSolvers.jl-issue353-base
T=<WORK>/ProximalSolvers.jl-issue353
tb=0; tn=0
for f in src/blocks.jl src/solvers/image_models.jl src/solvers/accelerated_proximal_gradient_descent.jl src/solvers/proximal_gradient_descent.jl src/cd/sqrtlasso.jl src/cd/leastsquares.jl; do
  a=$(cd $B && python3 $S0/tools/count_loc.py $f | head -1); b=$(cd $T && python3 $S0/tools/count_loc.py $f | head -1)
  echo "$f | base: $a | head: $b"
done
