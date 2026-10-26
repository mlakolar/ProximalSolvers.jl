#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=00:10:00
#SBATCH --job-name=ps95-hybrid-v2-rss
#SBATCH --output=rss-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load gcc/13.3.0 parallel/20240522
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export MATCH_LIBRARY="$PWD/libslope_plain.so" MATCH_ALLOC_LIBRARY="$PWD/libslope_alloc.so"
parallel --jobs 4 --halt soon,fail=1 --joblog rss-workers.tsv 'srun --exclusive --exact -N1 -n1 -c1 --mem=4G /usr/bin/time -f "%M\t%e\t%x" -o rss-{1}-{2}.time /home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/rss.jl {1} {2} rss-{1}-{2}.ser > rss-{1}-{2}.log 2>&1' ::: 1 20 169 171 ::: apg hybrid libslope
/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/verify_rss.jl > rss-validation.log 2>&1
printf 'RSS_COMPLETE\n'
