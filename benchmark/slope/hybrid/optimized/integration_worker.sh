#!/bin/bash
set -euo pipefail
version=$1
environment=$2
mode=$3
JULIA=/home1/mkolar/juliaPkg/julia-$version/bin/julia
"$JULIA" --startup-file=no integration-source/benchmark/slope/hybrid/optimized/integration_setup.jl "$version" > integration-setup-$version.log 2>&1
if [[ "$mode" == full ]]; then
  "$JULIA" --startup-file=no --check-bounds=yes --project="$environment" integration-source/test/runtests.jl > integration-tests-$version.log 2>&1
  "$JULIA" --startup-file=no --project="$environment" integration-source/benchmark/slope/hybrid/optimized/integration_replay.jl > integration-replay.log 2>&1
  python3 integration-source/benchmark/slope/hybrid/optimized/summarize.py --check > integration-integrity.log
  python3 integration-source/benchmark/diagonal/summarize.py integration-source/benchmark/diagonal/evidence/discovery-20261026.csv >> integration-integrity.log
  python3 integration-source/scripts/check_naming.py integration-source >> integration-integrity.log
else
  "$JULIA" --startup-file=no --check-bounds=yes --project="$environment" integration-source/test/slope_hybrid.jl > integration-tests-$version.log 2>&1
fi
