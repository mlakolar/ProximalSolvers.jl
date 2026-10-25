#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=00:15:00
#SBATCH --job-name=slope-confirm-20261025T0850Z
#SBATCH --output=confirm-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
module load parallel/20240522
mkdir -p confirmation
parallel --jobs 4 --halt soon,fail=1 --joblog confirmation-workers.tsv \
 'srun --exclusive --exact -N1 -n1 -c1 --mem=3500M "$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/run.jl --shard {1} --shards 4 --library-tol 1e-6 --seeds 6,7 --rounds 2 --out confirmation > confirmation-{1}.log 2>&1' ::: 1 2 3 4
printf 'SLOPE_CONFIRMATION_COMPLETE\n'
