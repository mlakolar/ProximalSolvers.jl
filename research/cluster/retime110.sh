#!/bin/bash
# Focused re-timing on Julia 1.10.12: ordinary designs only, 101 samples, 12 rotated rounds.
R=<run root>; B=$R/bundle311; OUT=$R/out-retime-1.10.12; mkdir -p $OUT
export JULIA_DEPOT_PATH=$R/depot-1.10.12 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 PROBLEM='^(core|lasso|explore)'
JL=${JULIA_1_10_12:?path to the Julia 1.10.12 binary}
{ hostname; lscpu | grep "Model name"; date -Is; squeue -h -w $(hostname -s) -o "%i %u %C"; } > $OUT/env.txt
LABS=(M C50 CW10 CW20 M2); : > $OUT/timing.tsv
for r in $(seq 1 12); do for i in 0 1 2 3 4; do
  lab=${LABS[$(( (i + r) % 5 ))]}; t=$lab; [ $lab = M2 ] && t=M
  (cd $B/trees/$t && taskset -c $(taskset -pc $$ | awk -F': ' '{print $2}' | cut -d, -f1 | cut -d- -f1) $JL --startup-file=no --project=. $B/probes/time311f.jl $lab 101 2>>$OUT/timing.err | sed "s/^/$r\t/") >> $OUT/timing.tsv
done; done
squeue -h -w $(hostname -s) -o "%i %u %C" >> $OUT/env.txt; echo done > $OUT/DONE
