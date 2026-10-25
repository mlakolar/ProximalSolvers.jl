#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:06:00
#SBATCH --job-name=slope-extract-main-20261025T1210Z
#SBATCH --output=main-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-selection/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
module load parallel/20240522
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
parallel --jobs 2 --halt now,fail=1 --joblog workers.tsv \
  'srun --exclusive --exact -N1 -n1 -c1 "$JULIA" --startup-file=no --project=combined-env harness/run.jl {} results > process-{}.log 2>&1' ::: 1 2 3
