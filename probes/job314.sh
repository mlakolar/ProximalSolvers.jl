#!/bin/bash
# #314: one job = one Julia version, one exclusive node, one Julia + one BLAS thread.
#   job314.sh <julia command> <tag> <run root> <task> [args]
# <run root> holds ps/ (clean PS tree at fad90d9), probes/, and receives env-<tag>/, out-<tag>-<task>/.
# tasks:
#   formal          setup.jl env (pinned) if missing; run.jl extended/gradient reps 1..10; validate; summarize;
#                   then probe314 harness 1:10 (5 timing rounds)
#   probe SET a:b k/K   probe314 on SET draws a:b, shard k/K (5 timing rounds)
set -euo pipefail
JL="$1"; TAG="$2"; ROOT="$3"; TASK="$4"; shift 4
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export JULIA_DEPOT_PATH="$ROOT/depot-$TAG"
PS="$ROOT/ps"; ENV="$ROOT/env-$TAG"
PSREV=fad90d93eb0abca3025ac5a07468b7ebe4c7e323
PBREV=c123d56ba1948e36a8fdbf183a9eea396a16e0d5
NAME="$TASK${1:+-$1}${3:+-${3/\//of}}"
OUT="$ROOT/out-$TAG-$NAME"; mkdir -p "$OUT"
{ hostname; date -Is; lscpu | grep -E 'Model name|^CPU\(s\)|Flags' | cut -c1-200; cat /proc/loadavg;
  $JL --version; git -C "$PS" rev-parse HEAD; git -C "$PS" status --porcelain | wc -l;
  echo "SLURM_JOB_ID=${SLURM_JOB_ID:-} SLURM_JOB_PARTITION=${SLURM_JOB_PARTITION:-} SLURM_NODELIST=${SLURM_NODELIST:-}"; } > "$OUT/node.txt" 2>&1
# environment: built once per tag by the formal job (or the first job), with a lock
(
  flock 9
  if [ ! -f "$ENV/Manifest.toml" ]; then
    $JL --startup-file=no "$PS/benchmark/setup.jl" "$PS" "$ENV" pinned > "$ROOT/setup-$TAG.log" 2>&1
  fi
) 9> "$ROOT/env-$TAG.lock"
J="$JL --startup-file=no --project=$ENV"
cd "$PS"
if [ "$TASK" = formal ]; then
  for rep in $(seq 1 10); do
    code=0
    PS_SUITE=extended PS_GROUPS=gradient PS_REPETITION=$rep PS_OUTPUT="$OUT/formal" \
      PS_EXPECTED_PACKAGE_REVISION=$PSREV PS_EXPECTED_PROXIMALBASE_REV=$PBREV \
      $J benchmark/run.jl > "$OUT/run-rep$rep.log" 2>&1 || code=$?
    echo "rep $rep exit $code" >> "$OUT/exit-codes.txt"
    [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || exit "$code"
  done
  python3 benchmark/validate.py "$OUT/formal" "$OUT/validation.json" --expected-runs 10 > "$OUT/validate.log" 2>&1 || echo "validate exit $?" >> "$OUT/exit-codes.txt"
  python3 benchmark/summarize.py "$OUT/formal" "$OUT/summary" --expected-runs 10 > "$OUT/summarize.log" 2>&1 || echo "summarize exit $?" >> "$OUT/exit-codes.txt"
  $J "$ROOT/probes/probe314.jl" "$PS" harness "$OUT/probe-harness.tsv" 1:10 1/1 5 > "$OUT/probe.log" 2>&1
else
  SET="$1"; DRAWS="$2"; SHARD="${3:-1/1}"
  $J "$ROOT/probes/probe314.jl" "$PS" "$SET" "$OUT/probe-$SET.tsv" "$DRAWS" "$SHARD" 5 > "$OUT/probe.log" 2>&1
fi
cat /proc/loadavg >> "$OUT/node.txt"; date -Is >> "$OUT/node.txt"
echo done > "$OUT/DONE"
