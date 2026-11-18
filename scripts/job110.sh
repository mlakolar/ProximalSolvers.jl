#!/bin/bash
# #110 current-master baseline: 62-case extended catalog, 10 fresh-process repetitions,
# Julia 1.10 and 1.13 on one exclusive node, one Julia thread and one BLAS thread.
#   job110.sh <run root> <julia-1.10 binary> <julia-1.13 binary>
# <run root> holds ps/ (clean clone of ProximalSolvers.jl at PSREV). The job writes
# env-<tag>/, depot-<tag>/, setup-<tag>.log and out/ (records out/<tag>/, logs, node info).
# Repetition k runs both versions back to back, alternating which goes first.
# A rerun under the same job ID (requeue) refuses to start: the runner never overwrites
# a process prefix, and a partial series must be preserved, not completed.
set -euo pipefail
ROOT="$1"; JL110="$2"; JL113="$3"
PSREV=a0a064778acb34d0535408a31ab2f09ae657e4aa
PBREV=a19c59aa723d085d5d7cf5242895bda16eb77214
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
PS="$ROOT/ps"; OUT="$ROOT/out"
echo "RESTART_COUNT=${RESTART_COUNT:-0}"
if [ -e "$OUT" ]; then echo "refusing: $OUT exists (restart or rerun); preserve it" >&2; exit 4; fi
mkdir -p "$OUT"
node_info() {
  { echo "== $1"; hostname; date -Is; cat /proc/loadavg
    squeue -h -w "$(hostname -s)" -o "%i %u %j %C" 2>&1 || true; } >> "$OUT/node.txt"
}
{ hostname; date -Is; lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Socket|MHz' ;
  echo "JOB_ID=${JOB_ID:-}";
  echo "PS HEAD $(git -C "$PS" rev-parse HEAD) dirty=$(git -C "$PS" status --porcelain | wc -l)";
  $JL110 --version; $JL113 --version; python3 --version; } > "$OUT/node.txt" 2>&1
[ "$(git -C "$PS" rev-parse HEAD)" = "$PSREV" ] || { echo "PS HEAD mismatch" >&2; exit 5; }
[ -z "$(git -C "$PS" status --porcelain)" ] || { echo "PS tree dirty" >&2; exit 5; }
node_info start
cd "$PS"
for TAG in j110 j113; do
  case $TAG in j110) JL=$JL110 ;; j113) JL=$JL113 ;; esac
  export JULIA_DEPOT_PATH="$ROOT/depot-$TAG"
  $JL --startup-file=no benchmark/setup.jl "$PS" "$ROOT/env-$TAG" pinned > "$ROOT/setup-$TAG.log" 2>&1
  # load once so that every repetition starts from the same precompiled state
  $JL --startup-file=no --project="$ROOT/env-$TAG" -e 'using ProximalSolvers, ProximalBase' >> "$ROOT/setup-$TAG.log" 2>&1
  PS_SUITE=extended PS_LIST=true $JL --startup-file=no --project="$ROOT/env-$TAG" benchmark/run.jl > "$OUT/list-$TAG.txt" 2>&1
done
node_info after-setup
for rep in $(seq 1 10); do
  if [ $((rep % 2)) -eq 1 ]; then order="j110 j113"; else order="j113 j110"; fi
  for TAG in $order; do
    case $TAG in j110) JL=$JL110 ;; j113) JL=$JL113 ;; esac
    export JULIA_DEPOT_PATH="$ROOT/depot-$TAG"
    code=0
    s=$(date +%s.%N)
    PS_SUITE=extended PS_REPETITION=$rep PS_OUTPUT="$OUT/$TAG" \
      PS_EXPECTED_PACKAGE_ROOT="$PS" PS_EXPECTED_PACKAGE_REVISION=$PSREV PS_EXPECTED_PROXIMALBASE_REV=$PBREV \
      $JL --startup-file=no --project="$ROOT/env-$TAG" benchmark/run.jl > "$OUT/run-$TAG-rep$rep.log" 2>&1 || code=$?
    echo "$TAG rep $rep exit $code wall $(awk -v a="$s" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}') load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$OUT/exit-codes.txt"
    [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || exit "$code"
  done
done
node_info end
for TAG in j110 j113; do
  python3 benchmark/validate.py "$OUT/$TAG" "$OUT/validation-$TAG.json" --expected-runs 10 > "$OUT/validate-$TAG.log" 2>&1 || echo "validate $TAG exit $?" >> "$OUT/exit-codes.txt"
done
echo done > "$OUT/DONE"
