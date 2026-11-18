#!/bin/bash
# usage: run_paired.sh TAG "julia-args" SIDES ROUNDS [WL]   (runs solve + visit harness, pinned to core 2, records uptime)
TAG=$1; JA=$2; SIDES=$3; ROUNDS=$4; WL=${5:-W1,W3}
D=<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator; PROJ=$D/..
uptime > $D/out/$TAG.load
X1_SIDES="$SIDES" X1_WL="$WL" systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 taskset -c 2 julia $JA --startup-file=no --project=$PROJ $D/probes/paired.jl $D/out/$TAG-solve.tsv $ROUNDS > $D/out/$TAG-solve.log 2>&1
X1_SIDES="$SIDES" systemd-run --user --scope -q -p MemoryMax=10G -p MemorySwapMax=0 taskset -c 2 julia $JA --startup-file=no --project=$PROJ $D/probes/visit.jl $D/out/$TAG-visit.tsv $ROUNDS > $D/out/$TAG-visit.log 2>&1
uptime >> $D/out/$TAG.load
python3 $D/probes/summarize.py $D/out/$TAG-solve.tsv $D/out/$TAG-visit.tsv > $D/out/$TAG.summary.txt
cat $D/out/$TAG.load
