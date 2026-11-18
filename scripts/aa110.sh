#!/bin/bash
# #110 A/A campaign (see PREREGISTRATION-aa110.md): master against itself, two independent installations
# per Julia version, 10 paired fresh-process repetitions, one exclusive node, 1 Julia + 1 BLAS thread.
#   aa110.sh <run root> <julia-1.10 binary> <julia-1.13 binary>
# <run root> holds ps-H, ps-A, ps-B (clean clones at PSREV) and PREREGISTRATION-aa110.md.
# Writes env-<v>-<s>/, depot-<v>-<s>/, setup-<v>-<s>.log, out/. Not restartable: refuses if out/ exists.
set -euo pipefail
ROOT="$1"; JL110="$2"; JL113="$3"
PSREV=a0a064778acb34d0535408a31ab2f09ae657e4aa
PBREV=a19c59aa723d085d5d7cf5242895bda16eb77214
CASES='cd/*/cd/*-f64/call,cd/*/cd/*-f32/call,gradient/*/*/acc-*/call,gradient/*/*/dense-f64/call,gradient/*/*/warm-dense-f64/call'
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
OUT="$ROOT/out"; H="$ROOT/ps-H"
echo "RESTART_COUNT=${RESTART_COUNT:-0}"
if [ -e "$OUT" ]; then echo "refusing: $OUT exists (restart or rerun); preserve it" >&2; exit 4; fi
mkdir -p "$OUT"
jl() { case $1 in j110) echo "$JL110" ;; j113) echo "$JL113" ;; esac; }
node_info() {
  { echo "== $1"; hostname; date -Is; cat /proc/loadavg
    squeue -h -w "$(hostname -s)" -o "%i %u %j %C" 2>&1 || true; } >> "$OUT/node.txt"
}
{ hostname; date -Is; lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Socket|MHz';
  echo "JOB_ID=${JOB_ID:-}";
  sha256sum "$ROOT/PREREGISTRATION-aa110.md";
  "$JL110" --version; "$JL113" --version; python3 --version; } > "$OUT/node.txt" 2>&1
for d in ps-H ps-A ps-B; do
  [ "$(git -C "$ROOT/$d" rev-parse HEAD)" = "$PSREV" ] || { echo "$d HEAD mismatch" >&2; exit 5; }
  [ -z "$(git -C "$ROOT/$d" status --porcelain)" ] || { echo "$d tree dirty" >&2; exit 5; }
  echo "$d $(git -C "$ROOT/$d" rev-parse HEAD) clean" >> "$OUT/node.txt"
done
node_info start
cd "$H"
# Independent installations: own checkout, own environment, own depot (download + precompile each).
for V in j110 j113; do
  for S in A B; do
    export JULIA_DEPOT_PATH="$ROOT/depot-$V-$S"
    J=$(jl $V)
    "$J" --startup-file=no benchmark/setup.jl "$ROOT/ps-$S" "$ROOT/env-$V-$S" pinned > "$ROOT/setup-$V-$S.log" 2>&1
    "$J" --startup-file=no --project="$ROOT/env-$V-$S" -e 'using ProximalSolvers, ProximalBase, InteractiveUtils; versioninfo(verbose=false); println(pathof(ProximalSolvers)); println(pathof(ProximalBase))' > "$OUT/versioninfo-$V-$S.txt" 2>&1
    PS_SUITE=extended PS_LIST=true PS_CASES="$CASES" "$J" --startup-file=no --project="$ROOT/env-$V-$S" benchmark/run.jl > "$OUT/list-$V-$S.txt" 2>&1
  done
done
node_info after-setup
for rep in $(seq 1 10); do
  if [ $((rep % 2)) -eq 1 ]; then vorder="j110 j113"; sorder="A B"; else vorder="j113 j110"; sorder="B A"; fi
  for V in $vorder; do
    for S in $sorder; do
      export JULIA_DEPOT_PATH="$ROOT/depot-$V-$S"
      J=$(jl $V); code=0; t0=$(date +%s.%N)
      PS_SUITE=extended PS_CASES="$CASES" PS_REPETITION=$rep PS_OUTPUT="$OUT/$V-$S" \
        PS_EXPECTED_PACKAGE_ROOT="$ROOT/ps-$S" PS_EXPECTED_PACKAGE_REVISION=$PSREV PS_EXPECTED_PROXIMALBASE_REV=$PBREV \
        "$J" --startup-file=no --project="$ROOT/env-$V-$S" benchmark/run.jl > "$OUT/run-$V-$S-rep$rep.log" 2>&1 || code=$?
      echo "$V $S rep $rep exit $code wall $(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}') load $(cut -d' ' -f1-3 /proc/loadavg)" >> "$OUT/exit-codes.txt"
      [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || exit "$code"
    done
  done
done
node_info after-timing
# Untimed work receipts (local.jl timings discarded): counters read from returned results.
mkdir -p "$OUT/work"
for V in j110 j113; do
  for S in A B; do
    export JULIA_DEPOT_PATH="$ROOT/depot-$V-$S"
    J=$(jl $V)
    for rep in $(seq 1 10); do
      code=0
      "$J" --startup-file=no --project="$ROOT/env-$V-$S" benchmark/local.jl "$CASES" --rep $rep \
        --samples 3 --min 3 --seconds 0.001 --save "$OUT/work/$V-$S-rep$rep.tsv" > "$OUT/work/$V-$S-rep$rep.log" 2>&1 || code=$?
      echo "work $V $S rep $rep exit $code" >> "$OUT/exit-codes.txt"
    done
  done
done
# Installation identity: checksums of compiled package images per depot.
for V in j110 j113; do
  for S in A B; do
    ( cd "$ROOT/depot-$V-$S" && find compiled -type f -print0 | sort -z | xargs -0 sha256sum ) > "$OUT/compiled-$V-$S.sha256" 2>&1 || true
  done
done
for V in j110 j113; do
  for S in A B; do
    python3 benchmark/validate.py "$OUT/$V-$S" "$OUT/validation-$V-$S.json" --expected-runs 10 > "$OUT/validate-$V-$S.log" 2>&1 || echo "validate $V-$S exit $?" >> "$OUT/exit-codes.txt"
  done
done
node_info end
echo done > "$OUT/DONE"
