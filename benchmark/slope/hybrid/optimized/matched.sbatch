#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=00:45:00
#SBATCH --job-name=ps95-hybrid-v2-matched
#SBATCH --output=matched-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load gcc/13.3.0 parallel/20240522
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export MATCH_LIBRARY="$PWD/libslope_plain.so" MATCH_ALLOC_LIBRARY="$PWD/libslope_alloc.so"
parallel --jobs 4 --halt soon,fail=1 --joblog workers.tsv 'srun --exclusive --exact -N1 -n1 -c1 --mem=4G /home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/run.jl main worker-{}.tsv {} 4 > worker-{}.log 2>&1' ::: 1 2 3 4
python3 source/benchmark/slope/hybrid/optimized/summarize.py --input . --output summary.json
printf 'MATCHED_COMPLETE\n'
