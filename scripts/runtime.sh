#!/bin/bash
# a320 timing body: runtime.sh <jv> <draws> <tag> <rounds> <rev>
R=<cluster-dir>
JV=$1; DRAWS=$2; TAG=$3; ROUNDS=$4; rev=$5
export JULIA_PKG_OFFLINE=true JULIA_PKG_SERVER= JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export JULIA_DEPOT_PATH=$R/a320-depot-$JV:$R/shared-depot:
export A320_HARNESS=$R/a320-code/benchmark
JL=<julia-root>/julia-$JV/bin/julia
echo "host $(hostname) cpu $(lscpu | grep 'Model name' | sed 's/.*: *//') job ${JOB_ID} load $(cat /proc/loadavg)"
out=$R/a320-out/$TAG/$rev-$JV; mkdir -p $out
# warm the compile cache once (not timed), then the timed run
$JL --startup-file=no --project=$R/a320-envs/$rev-$JV -e 'using ProximalSolvers' 2>&1 | tail -2
$JL --startup-file=no --project=$R/a320-envs/$rev-$JV $R/a320-code/probes/time320.jl $out/run $DRAWS $ROUNDS > $out/stdout.log 2> $out/stderr.log
echo "exit $? $(date -u +%FT%TZ) load $(cat /proc/loadavg)" | tee $out/exit.txt
