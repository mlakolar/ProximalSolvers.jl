#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:15:00
#SBATCH --job-name=ps95-hybrid-v2-canary
#SBATCH --output=canary-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 JULIA_NUM_PRECOMPILE_TASKS=1
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025-cd82-sparse/depot:/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export MATCH_LIBRARY="$PWD/libslope_plain.so" MATCH_ALLOC_LIBRARY="$PWD/libslope_alloc.so"
module load gcc/13.3.0 eigen/3.4.0
JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
"$JULIA" --startup-file=no setup.jl > setup.log 2>&1
NATIVE=/home1/mkolar/juliaPkg/runs/20261025T1030Z-ps-slope-first-order
test "$(git -C "$NATIVE/libslope-source" rev-parse HEAD)" = a9899cbf3677ea63236d54dc18626ad3a5aeddc6
g++ -O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp -fvisibility=hidden -Wl,-Bsymbolic -I"$NATIVE/libslope-source/include" source/benchmark/slope/hybrid/optimized/bridge.cpp "$NATIVE/native-build/src/libslope.a" -o libslope_plain.so > build-plain.log 2>&1
g++ -O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp -fvisibility=hidden -Wl,-Bsymbolic -DCOUNT_ALLOCATIONS -Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc,--wrap=free -I"$NATIVE/libslope-source/include" source/benchmark/slope/hybrid/optimized/bridge.cpp "$NATIVE/native-build/src/libslope.a" -o libslope_alloc.so > build-alloc.log 2>&1
"$JULIA" --startup-file=no --check-bounds=yes --project=env source/test/slope_hybrid.jl > unit.log 2>&1
"$JULIA" --startup-file=no --project=env source/benchmark/slope/hybrid/optimized/run.jl canary canary.tsv > pilot.log 2>&1
"$JULIA" --startup-file=no --check-bounds=yes --project=env source/test/runtests.jl > full-tests.log 2>&1
printf 'CANARY_AND_TESTS_COMPLETE\n'
