#!/usr/bin/env bash
#SBATCH --open-mode=append
set -euo pipefail
root=$1
cd "$root"
export JULIA_DEPOT_PATH="$root/depot:$HOME/.julia:" JULIA_LOAD_PATH='@:@stdlib' JULIA_PKG_OFFLINE=true
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
out="$root/results/$SLURM_JOB_ID"
mkdir -p "$out"
echo "job $SLURM_JOB_ID attempt ${SLURM_RESTART_COUNT:-0}"
for version in 1.10.13 1.13.4; do
  [[ ! -f "$out/$version.tsv" ]] || continue
  srun --exact -N1 -n1 -c1 --mem=4G --cpu-bind=cores "$HOME/julia/julia-$version/bin/julia" \
    --threads=1 --startup-file=no --project="$root/env/$version" preflight.jl > "$out/$version.tsv.tmp"
  mv "$out/$version.tsv.tmp" "$out/$version.tsv"
done
