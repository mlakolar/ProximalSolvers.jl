# Diagonal gradient-solver benchmark

`run.jl BASELINE_ENV CANDIDATE_ENV OUTPUT_CSV 10` keeps two Julia workers
alive, warms all paths, then interleaves baseline, candidate `:none`, and
candidate `:diagonal` in alternating orders. Calls run sequentially with one
BLAS thread. Timings include ordinary `solve!` initialization and metric setup;
compilation and explicit pre-call GC are excluded. The workers use the same
ProximalBase revision.

The fixed seed is 92026. All designs have 600 observations and 80 columns,
with mild column correlation. Scaled designs multiply columns by factors
from 1 to 1000. The weighted ℓ1 penalty scales with column curvature, so the
underlying problem in standardized coordinates stays comparable. The cases
are well-scaled least squares, scaled least squares, and scaled logistic loss.
Each solver gets at most 6000 iterations and a relative duality-gap target
of 1e-5, checked every ten iterations.

The harness requires exact equality of baseline/default coefficients, gaps,
objectives, iteration counts, and backtracking counts, and requires every
diagonal solve to reach the target. `summarize.py RESULTS_CSV` checks all 180
rows and reports paired runtime ratios. When scalar runs reach the iteration
cap, their runtime is a lower bound on time to the target; the reported ratio
is not an equal-accuracy speedup.

For Discovery, stage the chosen baseline and candidate sources in separate
directories, plus the pinned dependency in `ProximalBase.jl`, copy `setup.jl`
and `discovery.sbatch` to the run root, and run:

```sh
sbatch --parsable discovery.sbatch
python3 candidate/benchmark/diagonal/summarize.py results.csv
```

The batch script runs the complete test suite before the comparison. The
allocation uses three CPUs and 12 GB of RAM; Distributed keeps the baseline
and candidate loaded in separate processes while the controller alternates
the measurements.

After a harness-only failure, `PS92_SKIP_TESTS=1` reuses completed tests;
`PS92_HARNESS` can select a separately staged harness revision. Solver sources
and dependency environments must be unchanged when reusing those tests.
