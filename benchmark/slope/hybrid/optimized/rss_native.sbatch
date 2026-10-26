#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:05:00
#SBATCH --job-name=ps95-hybrid-v2-rss-native
#SBATCH --output=rss-native-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
module load gcc/13.3.0 parallel/20240522
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export MATCH_LIBRARY="$PWD/libslope_plain.so" MATCH_ALLOC_LIBRARY="$PWD/libslope_alloc.so"
test -f rss-validation-v1.tsv || cp rss-validation.tsv rss-validation-v1.tsv
export MATCH_NATIVE_TOL=1e-10 MATCH_RSS_NATIVE_PREFIX=rss-tight
parallel --jobs 2 --halt soon,fail=1 --joblog rss-native-workers.tsv 'srun --exclusive --exact -N1 -n1 -c1 --mem=4G python3 source/benchmark/slope/hybrid/optimized/measure_rss.py rss-tight-{}-libslope.time /home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/rss.jl {} libslope rss-tight-{}-libslope.ser > rss-tight-{}-libslope.log 2>&1' ::: 1 20 169 171
/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/verify_rss.jl > rss-validation-tight.log 2>&1
python3 source/benchmark/slope/hybrid/optimized/summarize.py --input . --output summary.json
python3 source/benchmark/slope/hybrid/optimized/summarize.py --input . --output summary.json --check
python3 source/benchmark/slope/hybrid/optimized/report.py --input . --output RESULTS.md
printf 'RSS_NATIVE_COMPLETE\n'
