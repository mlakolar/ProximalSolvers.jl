#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --job-name=ps95-hybrid-v2-calibrate
#SBATCH --output=calibrate-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export MATCH_LIBRARY="$PWD/libslope_plain.so" MATCH_ALLOC_LIBRARY="$PWD/libslope_alloc.so"
module load gcc/13.3.0
JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
"$JULIA" --startup-file=no --check-bounds=yes --project=env source/test/slope_hybrid.jl > unit-final.log 2>&1
"$JULIA" --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/run.jl canary canary-final.tsv > canary-final.log 2>&1
"$JULIA" --startup-file=no --check-bounds=yes --project=env -e 'include("source/test/examples.jl");include("source/test/aqua.jl")' > examples-aqua-final.log 2>&1
python3 source/scripts/check_naming.py source
printf 'CALIBRATION_COMPLETE\n'
