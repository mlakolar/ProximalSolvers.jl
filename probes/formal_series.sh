#!/usr/bin/env bash
# #307 formal series: the unchanged #318 harness, the arms of OUT/arms.tsv rotating per repetition.
#   SHARED_DEPOT=... formal_series.sh JULIA HARNESS_ROOT OUT REPS
# Rep r starts with arm (r-1) mod k, so each arm runs first equally often when REPS is a multiple of k.
set -euo pipefail
JULIA=$1; HARNESS=$2; OUT=$3; REPS=$4
: "${SHARED_DEPOT:?set SHARED_DEPOT}"
mapfile -t ARMS < "$OUT/arms.tsv"; k=${#ARMS[@]}
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
echo "start $(date -u +%FT%TZ) loadavg $(cat /proc/loadavg)" >> "$OUT/formal-load.log"
for rep in $(seq 1 "$REPS"); do
  for j in $(seq 0 $((k - 1))); do
    IFS=$'\t' read -r l d rev pbrev env depot <<< "${ARMS[$(( (rep - 1 + j) % k ))]}"
    echo "rep $rep arm $l loadavg $(cat /proc/loadavg)" >> "$OUT/formal-load.log"
    code=0
    JULIA_DEPOT_PATH="$depot:$SHARED_DEPOT" PS_SUITE=extended PS_GROUPS=cd,gradient PS_REPETITION="$rep" \
      PS_OUTPUT="$OUT/formal-$l" PS_EXPECTED_PACKAGE_ROOT="$d" PS_EXPECTED_PACKAGE_REVISION="$rev" \
      PS_EXPECTED_PROXIMALBASE_REV="$pbrev" \
      "$JULIA" --startup-file=no --project="$env" "$HARNESS/benchmark/run.jl" > "$OUT/formal-run-$l-rep$rep.log" 2>&1 || code=$?
    echo "rep $rep arm $l exit $code" >> "$OUT/formal-load.log"
    [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || { echo "run.jl exit $code (arm $l rep $rep)" >&2; exit "$code"; }
  done
done
for line in "${ARMS[@]}"; do
  l=${line%%$'\t'*}
  python3 "$HARNESS/benchmark/validate.py" "$OUT/formal-$l" "$OUT/formal-validation-$l.json" --expected-runs "$REPS" \
    > "$OUT/formal-validate-$l.log" 2>&1 || echo "validate $l failed" >> "$OUT/formal-load.log"
done
echo "end $(date -u +%FT%TZ) loadavg $(cat /proc/loadavg)" >> "$OUT/formal-load.log"
