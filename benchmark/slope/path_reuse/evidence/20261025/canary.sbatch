#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --job-name=slope-reuse-canary-20261025T0930Z
#SBATCH --output=canary-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/path_reuse/checks.jl > checks.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/path_reuse/run.jl --canary --seeds 1 --rounds 1 --out canary > canary.log 2>&1
printf 'PATH_REUSE_CANARY_COMPLETE\n'
