#!/bin/bash
# One Julia version, one exclusive node, one thread: diagnostics, real-code matrices,
# counterexample search and paired timing for #308.
#   job308.sh <julia command> <tag> <run root>
# <run root> holds base/ (master tree, with .codex-orchestrator/probes) and candB/ (candidate tree).
set -euo pipefail
JL="$1"; TAG="$2"; ROOT="$3"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export JULIA_DEPOT_PATH="$ROOT/depot-$TAG"
P="$ROOT/base/.codex-orchestrator/probes"
OUT="$ROOT/out-$TAG"; mkdir -p "$OUT"
cd "$ROOT/base"
{ hostname; lscpu | grep -E 'Model name|^CPU\(s\)'; cat /proc/loadavg; $JL --version; git -C "$ROOT/base" log --oneline -1; } > "$OUT/node.txt" 2>&1
$JL --startup-file=no "$P/setup308.jl" "$ROOT/env-base-$TAG" "$ROOT/base" > "$OUT/setup-base.log" 2>&1
$JL --startup-file=no "$P/setup308.jl" "$ROOT/env-cand-$TAG" "$ROOT/candB" > "$OUT/setup-cand.log" 2>&1
B="$JL --startup-file=no --project=$ROOT/env-base-$TAG"
C="$JL --startup-file=no --project=$ROOT/env-cand-$TAG"
# 1 per-iteration diagnostics of the unchanged solver (trajectories are identical under the candidate)
$B "$P/trace308.jl" "$OUT/trace" 1:10 > "$OUT/trace.log" 2>&1
# 2 real-code matrices: strict and harness settings, Float32 and Float64
for s in strict harness; do
  $B "$P/matrix308.jl" base 1:10 $s Float32 Float64 > "$OUT/matrix-base-$s.tsv" 2> "$OUT/matrix-base-$s.err"
  $C "$P/matrix308.jl" cand 1:10 $s Float32 Float64 > "$OUT/matrix-cand-$s.tsv" 2> "$OUT/matrix-cand-$s.err"
done
# 3 counterexample battery and randomized search (candidate flag read from the state)
$C "$P/cex308.jl" "$OUT/cex.tsv" 400 > "$OUT/cex.log" 2>&1
# 4 paired in-process timing with A/A copies
$C "$P/paired308.jl" "$ROOT/base/src" "$ROOT/candB/src" 15 1:10 strict-f32 strict-f64 harness-f32 harness-f64 > "$OUT/paired.tsv" 2> "$OUT/paired.err"
cat /proc/loadavg >> "$OUT/node.txt"
echo done > "$OUT/DONE"
