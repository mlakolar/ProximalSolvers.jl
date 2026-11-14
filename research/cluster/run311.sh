#!/bin/bash
# #311 cluster run for ONE Julia version. Usage: run311.sh JULIA_BIN RUNROOT OUTDIR
#   RUNROOT holds trees/{M,C50,CW,E} (M = master eb3332f, C50 = forced full pass after 50 active
#   passes, CW10/CW20 = after 10/20 full passes' worth of active visits, E = switchable exploration build)
#   and probes/. Each tree gets its own depot-shared env via Pkg.instantiate.
set -uo pipefail   # no -e: a failing step must not cancel the later ones
JL=$1; ROOT=$2; OUT=$3
mkdir -p "$OUT"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
P=$ROOT/probes
V=$($JL --startup-file=no -e 'print(VERSION)')
{ echo "julia $V"; echo "host $(hostname)"; lscpu | grep "Model name"; grep -q avx512f /proc/cpuinfo && echo "avx512f yes" || echo "avx512f no"; date -Is; } > "$OUT/env.txt"
for t in M C50 CW10 CW20 E; do
  (cd "$ROOT/trees/$t" && $JL --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate(); using ProximalSolvers' ) >> "$OUT/instantiate.log" 2>&1
  git -C "$ROOT/trees/$t" rev-parse HEAD >> "$OUT/env.txt" 2>/dev/null || echo "$t $(cat $ROOT/trees/$t/REVISION)" >> "$OUT/env.txt"
done
filt() { grep -v '^WARNING: Method definition\|incremental compilation' || true; }

# 1. reproducer: master, both candidates; without and with coverage
for t in M C50 CW10 CW20; do
  for cov in none user; do
    (cd "$ROOT/trees/$t" && $JL --startup-file=no --project=. --code-coverage=$cov "$P/repro311.jl" 2>&1 | filt) > "$OUT/repro_${t}_cov-${cov}.txt"
  done
done
(cd "$ROOT/trees/E" && $JL --startup-file=no --project=. --code-coverage=user "$P/repro311.jl" master 50 w10 w20 2>&1 | filt) > "$OUT/repro_E_cov-user.txt"

# 2. diagnosis of the stalled run (master, coverage)
(cd "$ROOT/trees/M" && $JL --startup-file=no --project=. --code-coverage=user "$P/diag311.jl" 2>&1 | filt) > "$OUT/diag_M_cov-user.txt"

# 3. seed scan (exploration build), with and without coverage
for cov in none user; do
  (cd "$ROOT/trees/E" && $JL --startup-file=no --project=. --code-coverage=$cov "$P/seeds311.jl" 500 master 50 w10 w20 2>&1 | filt) > "$OUT/seeds_E_cov-${cov}.txt"
done

# 4. allocations
for t in M C50 CW10 CW20; do
  (cd "$ROOT/trees/$t" && $JL --startup-file=no --project=. "$P/alloc311.jl" 2>&1) > "$OUT/alloc_${t}.txt"
done

# 5. paired timing: fresh process per (tree, round), rotating order; M2 = master again (A/A)
: > "$OUT/timing.tsv"
LABS=(M C50 CW10 CW20 M2)
for r in 1 2 3 4 5 6 7 8 9 10; do
  for i in 0 1 2 3 4; do
    lab=${LABS[$(( (i + r) % 5 ))]}
    t=$lab; [ "$lab" = M2 ] && t=M
    (cd "$ROOT/trees/$t" && $JL --startup-file=no --project=. "$P/time311.jl" "$lab" 15 2>>"$OUT/timing.err" | sed "s/^/$r\t/") >> "$OUT/timing.tsv"
  done
done

# 6. deterministic work counts + BigFloat KKT (exploration build)
(cd "$ROOT/trees/E" && KS=master,50,w10,w20 $JL --startup-file=no --project=. "$P/counts311.jl" "$OUT/counts.tsv" 2>&1 | filt) > "$OUT/counts.log"
echo done > "$OUT/DONE"
