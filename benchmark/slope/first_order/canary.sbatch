#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=00:10:00
#SBATCH --job-name=slope-first-canary2-20261025T1030Z
#SBATCH --output=canary2-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
export SLOPE_CONTROL_LIBRARY="$PWD/libslope_control.so"
module load eigen/3.4.0
g++ --version > compiler.txt
test "$(git -C libslope-source rev-parse HEAD)" = a9899cbf3677ea63236d54dc18626ad3a5aeddc6
cmake -S libslope-source -B native-build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DBUILD_JULIA_BINDINGS=OFF -DUSE_OPENMP=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_CXX_FLAGS=-fvisibility=hidden > configure.log 2>&1
cmake --build native-build --parallel 2 > build2.log 2>&1
g++ -O3 -DNDEBUG -std=c++17 -fPIC -shared -fopenmp -Ilibslope-source/include \
    -fvisibility=hidden -Wl,-Bsymbolic source/benchmark/slope/first_order/bridge.cpp \
    native-build/src/libslope.a -o "$SLOPE_CONTROL_LIBRARY" > bridge-build2.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/first_order/checks.jl > checks2.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/first_order/run.jl --canary --seeds 0 --rounds 1 --profiles --out canary > canary.log 2>&1
printf 'FIRST_ORDER_CANARY_COMPLETE\n'
