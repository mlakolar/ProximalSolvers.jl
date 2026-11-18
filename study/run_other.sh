#!/bin/bash
# full PGD/APG and square-root sweeps; four single-threaded processes
WT=<WT>
RUN=$(cd "$(dirname "$0")/.." && pwd)
V=${1:-release}
export JULIA_DEPOT_PATH="$WT/.codex-orchestrator/depot-$V:$HOME/.julia:"
export OPENBLAS_NUM_THREADS=1
OUT=$RUN/evidence/sweep-$V; mkdir -p $OUT
cd $RUN/study
uptime > $OUT/other.meta; git -C $WT rev-parse HEAD >> $OUT/other.meta; julia +$V --version >> $OUT/other.meta
for T in Float64 Float32; do
  julia +$V --startup-file=no --project=$WT grad.jl $OUT/grad_$T.tsv $T > $OUT/grad_$T.log 2>&1 &
  julia +$V --startup-file=no --project=$WT sqrt.jl $OUT/sqrt_$T.tsv $T > $OUT/sqrt_$T.log 2>&1 &
done
wait
echo "exit $? $(date -u +%FT%TZ)" >> $OUT/other.meta
