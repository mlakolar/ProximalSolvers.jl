#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --job-name=slope-first-canary-20261025T1030Z
#SBATCH --output=canary-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
export SLOPE_CONTROL_LIBRARY="$PWD/libslope_control.so"
module load eigen/3.4.0
ARTIFACT=/home1/mkolar/juliaPkg/depot/artifacts/d3968329a951c94c2b058a91de51296467d6b823
g++ --version > compiler.txt
g++ -O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp -I"$ARTIFACT/include" \
    source/benchmark/slope/first_order/bridge.cpp "$ARTIFACT/lib/libslope.a" -o "$SLOPE_CONTROL_LIBRARY" > build.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/first_order/checks.jl > checks.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/first_order/run.jl --canary --seeds 0 --rounds 1 --profiles --out canary > canary.log 2>&1
printf 'FIRST_ORDER_CANARY_COMPLETE\n'
