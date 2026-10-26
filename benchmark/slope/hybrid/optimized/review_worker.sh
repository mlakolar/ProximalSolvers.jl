#!/bin/bash
set -euo pipefail
version=$1
environment=$2
JULIA=/home1/mkolar/juliaPkg/julia-$version/bin/julia
"$JULIA" --startup-file=no review-source/benchmark/slope/hybrid/optimized/review_setup.jl "$version" > review-setup-$version.log 2>&1
"$JULIA" --startup-file=no --check-bounds=yes --project="$environment" review-source/test/slope_hybrid.jl > review-tests-$version.log 2>&1
