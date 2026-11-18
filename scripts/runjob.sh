#!/bin/bash
# a320 batch body: runjob.sh <jv> <mode> <draws> <tag> <designs|-> <rev>...   (run inside a batch job)
R=<cluster-dir>
JV=$1; MODE=$2; DRAWS=$3; TAG=$4; DESIGNS=$5; shift 5
export JULIA_PKG_OFFLINE=true JULIA_PKG_SERVER= JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export JULIA_DEPOT_PATH=$R/a320-depot-$JV:$R/shared-depot:
export A320_HARNESS=$R/a320-code/benchmark
export A320_BIG=${A320_BIG:-1}
JL=<julia-root>/julia-$JV/bin/julia
echo "host $(hostname) cpu $(lscpu | grep 'Model name' | sed 's/.*: *//') job ${JOB_ID}"
for rev in "$@"; do
  out=$R/a320-out/$TAG/$rev-$JV; mkdir -p $out
  extra=""; [ "$DESIGNS" != "-" ] && extra=$DESIGNS
  echo "== $rev $JV $MODE $DRAWS $(date -u +%FT%TZ)"
  $JL --startup-file=no --project=$R/a320-envs/$rev-$JV $R/a320-code/probes/probe320.jl $MODE $out/run $DRAWS $extra > $out/stdout.log 2> $out/stderr.log
  echo "exit $? $(date -u +%FT%TZ)" | tee $out/exit.txt
done
