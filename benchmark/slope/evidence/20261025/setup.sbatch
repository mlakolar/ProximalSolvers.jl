#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:20:00
#SBATCH --job-name=slope-setup-20261025T0850Z
#SBATCH --output=setup-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
export JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_DEPOT_PATH="$PWD/depot:/home1/mkolar/juliaPkg/depot:"
export JULIA=/home1/mkolar/juliaPkg/julia-1.13.2/bin/julia
"$JULIA" --startup-file=no --project=source/benchmark/slope -e 'using Pkg; Pkg.develop([PackageSpec(path=abspath("base")),PackageSpec(path=abspath("source"))]); Pkg.instantiate(); Pkg.status()'
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/checks.jl > checks.log 2>&1
"$JULIA" --startup-file=no --project=source/benchmark/slope source/benchmark/slope/run.jl --canary --seeds 1 --rounds 1 --out canary > canary.log 2>&1
printf 'SLOPE_SETUP_AND_CANARY_COMPLETE\n'
