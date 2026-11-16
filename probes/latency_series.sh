#!/usr/bin/env bash
# #307 first-call latency: ROUNDS interleaved rounds over the arms of OUT/arms.tsv (rotating order);
# in each round every arm runs the 12 (solver, T, order) fresh-process children once. Round 1 also
# times precompilation (REPS_PRE) and records provenance.
#   SHARED_DEPOT=... latency_series.sh JULIA PROBES_DIR OUT ROUNDS [REPS_PRE]
set -euo pipefail
JULIA=$1; PROBES=$2; OUT=$3; ROUNDS=$4; PRE=${5:-3}
: "${SHARED_DEPOT:?set SHARED_DEPOT}"
mapfile -t ARMS < "$OUT/arms.tsv"; k=${#ARMS[@]}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
for r in $(seq 1 "$ROUNDS"); do
  for j in $(seq 0 $((k - 1))); do
    IFS=$'\t' read -r l d rev pbrev env depot <<< "${ARMS[$(( (r - 1 + j) % k ))]}"
    if [ "$r" -eq 1 ]; then opts="REPS_PRE=$PRE META=1"; else opts="REPS_PRE=0 META=0"; fi
    JULIA_DEPOT_PATH="$depot:$SHARED_DEPOT" "$JULIA" --startup-file=no --project="$env" \
      "$PROBES/latency_driver.jl" "$l" REPS=1 REPS_LOAD=1 REP0=$((r - 1)) $opts \
      >> "$OUT/latency-$l.csv" 2>> "$OUT/latency-$l.err"
  done
done
