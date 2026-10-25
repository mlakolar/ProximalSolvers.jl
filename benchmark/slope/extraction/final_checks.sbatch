#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=debug
#SBATCH --constraint=epyc-7313
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=00:02:00
#SBATCH --job-name=slope-extract-final-20261025T1210Z
#SBATCH --output=final-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot-final:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-compare/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-selection/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
for version in 1.13.2 1.10.12; do
  if [ "$version" = 1.13.2 ]; then environment=env335; else environment=env110335; fi
  /home1/mkolar/juliaPkg/julia-$version/bin/julia --startup-file=no --project="$environment" source335/test/slope.jl > "tests-final-$version.log" 2>&1
done
