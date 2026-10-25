#!/bin/bash
#SBATCH --job-name=ps92-diagonal-20261026
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3
#SBATCH --mem=12G
#SBATCH --time=00:40:00
#SBATCH --output=slurm-%j.out
set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
export JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_PKG_PRECOMPILE_AUTO=0
JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
"$JULIA" --startup-file=no setup.jl
if [[ "${PS92_SKIP_TESTS:-0}" != 1 ]]; then
  "$JULIA" --startup-file=no --project=env-candidate candidate/test/runtests.jl > tests.log 2>&1
fi
"$JULIA" --startup-file=no "${PS92_HARNESS:-candidate/benchmark/diagonal}/run.jl" env-baseline env-candidate results.csv 10
