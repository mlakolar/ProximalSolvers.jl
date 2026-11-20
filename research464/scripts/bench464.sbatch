#!/bin/bash
#SBATCH <account and queue options>
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --time=05:00:00
#SBATCH --job-name=pb-20261120-issue464-bench
#SBATCH --comment=pb-20261120-issue464/bench
#SBATCH --open-mode=append
#SBATCH --output=<scratch>/pb-20261120-issue464/bench/slurm-%j.out
# #464 timing: master (base) vs the per-entry prototype v1 (proto), master vs the smallest-coefficient prototype v3
# (v3), and master vs a second copy of master (base2, A/A), on one exclusive node, one Julia thread, one BLAS thread,
# all processes pinned to one core. Six pairs of each, alternating which side runs first. Then the check-cost probe,
# twice, on base.
set -u
P=<scratch>/pb-20261120-issue464
OUT=$P/bench/run-$SLURM_JOB_ID
mkdir -p $OUT
echo "job $SLURM_JOB_ID node $(hostname) restart ${SLURM_RESTART_COUNT:-0} start $(date -Is)"
lscpu | grep -E "Model name|^CPU\(s\)|Thread|Socket|NUMA node\(s\)"
squeue -h -w "$(hostname)" -o "%i %u %j %C" > $OUT/cotenants-start.txt
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_OFFLINE=true BENCH_REPS=40
JL=$HOME/julia/julia-1.13.4/bin/julia
run() {   # tag label slot
  local tag=$1
  ( cd $OUT && JULIA_DEPOT_PATH=$P/$tag/depot-1.13.4:$P/shared-depot: taskset -c 3 $JL --startup-file=no \
      --project=$P/$tag/pkg $P/$tag/pkg/research464/bench464.jl $2 $3 $OUT/bench.tsv ) > $OUT/log-$2-$3.txt 2>&1
  echo "$(date -Is) $2 $3 exit $?"
}
# warm the compile caches of all three trees (not recorded)
for t in base-113 proto-113 v3-113 base2-113; do
  ( cd $OUT && JULIA_DEPOT_PATH=$P/$t/depot-1.13.4:$P/shared-depot: BENCH_REPS=1 $JL --startup-file=no \
      --project=$P/$t/pkg $P/$t/pkg/research464/bench464.jl warm-$t 0 $OUT/warm.tsv ) > $OUT/log-warm-$t.txt 2>&1
done
for k in 1 2 3 4 5 6; do
  if (( k % 2 )); then run base-113 AB-base $k; run proto-113 AB-proto $k; else run proto-113 AB-proto $k; run base-113 AB-base $k; fi
  if (( k % 2 )); then run v3-113 AB3-v3 $k; run base-113 AB3-base $k; else run base-113 AB3-base $k; run v3-113 AB3-v3 $k; fi
  if (( k % 2 )); then run base2-113 AA-base2 $k; run base-113 AA-base $k; else run base-113 AA-base $k; run base2-113 AA-base2 $k; fi
done
for k in 1 2; do
  ( cd $OUT && JULIA_DEPOT_PATH=$P/base-113/depot-1.13.4:$P/shared-depot: taskset -c 3 $JL --startup-file=no \
      --project=$P/base-113/pkg $P/base-113/pkg/research464/probe464.jl $OUT/probe-$k.tsv ) > $OUT/log-probe-$k.txt 2>&1
  echo "$(date -Is) probe $k exit $?"
done
squeue -h -w "$(hostname)" -o "%i %u %j %C" > $OUT/cotenants-end.txt
echo "end $(date -Is)"
