#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:05:00
#SBATCH --job-name=ps95-hybrid-v2-review
#SBATCH --output=review-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load gcc/13.3.0 parallel/20240522
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=1
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261026-ps95-hybrid-v2/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
parallel --jobs 2 --link --halt soon,fail=1 --joblog review-workers.tsv 'srun --exclusive --exact -N1 -n1 -c1 --mem=4G bash review-source/benchmark/slope/hybrid/optimized/review_worker.sh {1} {2}' ::: 1.13.2 1.10.12 ::: review-env review-env110
printf 'REVIEW_CHECKS_COMPLETE\n'
