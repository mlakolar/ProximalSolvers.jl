#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=00:20:00
#SBATCH --job-name=slope-first-main-20261025T1030Z
#SBATCH --output=main-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
export SLOPE_CONTROL_LIBRARY="$PWD/libslope_control.so"
module load parallel/20240522
mkdir -p main
parallel --jobs 4 --halt soon,fail=1 --joblog main-workers.tsv \
 'srun --exclusive --exact -N1 -n1 -c1 --mem=3500M "$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/first_order/run.jl --shard {1} --shards 4 --profiles --out main > main-{1}.log 2>&1' ::: 1 2 3 4
printf 'FIRST_ORDER_MAIN_COMPLETE\n'
