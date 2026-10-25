#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --job-name=slope-checks-20261025T0850Z
#SBATCH --output=validation-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/depot:"
tar -xf base-ext.tar -C base
tar -xf source-validation.tar -C source
/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=source/benchmark/slope source/benchmark/slope/checks.jl > checks-final.log 2>&1
printf 'SLOPE_FINAL_CHECKS_COMPLETE\n'
