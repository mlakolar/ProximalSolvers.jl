#!/bin/bash
# full CD least-squares sweeps, Julia release; four single-threaded processes
WT=<WT>
RUN=$(cd "$(dirname "$0")/.." && pwd)
V=${1:-release}
export JULIA_DEPOT_PATH="$WT/.codex-orchestrator/depot-$V:$HOME/.julia:"
export OPENBLAS_NUM_THREADS=1
OUT=$RUN/evidence/sweep-$V; mkdir -p $OUT
cd $RUN/study
uptime > $OUT/cd.meta; git -C $WT rev-parse HEAD >> $OUT/cd.meta; julia +$V --version >> $OUT/cd.meta
for fam in scalar group; do for T in Float64 Float32; do
  julia +$V --startup-file=no --project=$WT cd_ls.jl $OUT/cd_${fam}_$T.tsv $fam $T > $OUT/cd_${fam}_$T.log 2>&1 &
done; done
wait
echo "exit $? $(date -u +%FT%TZ)" >> $OUT/cd.meta
