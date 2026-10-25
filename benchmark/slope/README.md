# SLOPE solver evaluation (#57)

Benchmark-only comparison of current PG/APG with SLOPE.jl 1.3.1 (libslope).
No public solver, runtime dependency or penalty API is added.

## Protocol fixed before measurements

The objective is `||y-X*beta||²/(2n) + alpha*sum(lambda .* sort(abs(beta),rev=true))`.
Use no intercept, centering or scaling in either implementation. Dense designs
have `(n,p)=(200,500)` or `(1000,2000)`, AR(1) correlation 0 or 0.9, and 10 or
100 nonzero true coefficients. Coefficients are Gaussian with scale 2 and noise
has standard deviation 1. Seeds 1--5, three randomized complete timing blocks,
and linear weights (2 to 0.5) or BH weights (q=0.1) give 240 blocks.

Each block has PG, APG and SLOPE.jl at alpha/alpha_max=0.3 and 0.05 separately,
plus a 12-point descending log path from alpha_max to 0.05alpha_max. That is
2,160 solver calls and 10,080 requested returned points. A whole path is one
timing unit; it is valid only if every requested point is returned and certified.
Each method warm-starts its own path. Package momentum and step state restart
at each level; libslope uses its native path state. A failed package level ends
its path, and remaining requested levels are explicitly retained as not returned.

## Accuracy and fairness

The SLOPE dual norm is the maximum ratio of cumulative sorted magnitudes to
cumulative lambda. Applied to X'y/n it gives alpha_max. For theta=(y-X*beta)/n,
scale theta into `J_lambda^D(X'theta)<=alpha`. The dual objective is
`y'theta-n||theta||²/2`; its gap bounds objective error. The target is gap divided
by max(1,abs(primal)) <=1e-6. Certificates and alpha_max are local benchmark
helpers, not new package interfaces. Final validation uses fresh buffers and
direct products, without reusing solver residuals. Orthogonal closed-form
solutions, l1/linfinity special cases, zero thresholds, and library scaling
check the implementation. Proximal fixed-point residuals are also reported.

PG/APG use production initial_state/update_state! code and optimized loss-image
caching, checking the external certificate initially and every ten iterations.
SLOPE.jl uses internal tol=1e-9, max_it=20,000, explicit alpha and lambda vectors,
and disables deviance and cluster-count path truncation. Its public SlopeFit
does not expose iterations or convergence status: unavailable counts are -1,
and external validation determines success. The stricter library tolerance can
cost it extra time; this is conservative when assessing its advantage.

Package calls have a ten-second soft time budget across the entire single fit
or path, and at most 20,000 iterations per level. SLOPE.jl exposes an iteration
cap but no time cap; its calls have the same max_it=20,000 and the whole worker
has the Slurm wall limit. These caps are not equivalent work budgets. Failures
remain visible; do not infer mathematical nonconvergence from a capped call.

Compile every solver/weight path before timing. Times include workspace setup,
initialization, output construction and scheduled certificates; exclude data
generation, GC and final validation. Julia allocations are recorded, but exclude
native C++ allocation, so do not compare them as total-memory measures. Separate
single-fit and whole-path paired ratios; do not sum repeated path timings over
the returned-point table. Coefficient, prediction and objective agreement are
diagnostics; coefficient equality is not required on nonunique problems.

## Decision gate

Recommend a **benchmark-only hybrid cluster-coordinate prototype** if SLOPE.jl
certifies at least 99% of requested calls and is at least 3x faster than APG
(median paired whole-call time) in at least two prespecified dimension/correlation
strata, with the advantage present on both single fits and paths. Check fresh
seeds 6--7 in those strata before recommending the prototype. Retain failures
and report both-valid, library-only, APG-only and unresolved outcomes. A faster
external implementation motivates investigation of its method; it does not
establish the speed or maintenance value of a native Julia implementation.

If the gate fails, retain the comparison and identify whether package APG or an
optional external adapter is sufficient. BH generation uses SLOPE.jl's benchmark
dependency; no normal-quantile dependency is added to ProximalBase or the runtime.

## Recreate on Discovery

Use Julia 1.13.2 and one Julia/BLAS/OpenMP thread per worker. Develop this checkout
and the recorded ProximalBase source into this directory's environment, then
instantiate the pinned SLOPE version. Run within a Slurm allocation:

```sh
julia --startup-file=no --project=benchmark/slope benchmark/slope/checks.jl
julia --startup-file=no --project=benchmark/slope benchmark/slope/run.jl \
  --shard 1 --shards 4 --out results
# Repeat shards 2--4 via GNU Parallel with exclusive single-CPU srun steps.
```

Run identity: `20261025T0850Z-ps-slope`. Exact source revisions, environment,
launchers and outcomes are recorded in the lightweight project run registry.

## Accuracy-control amendment

The strict-library main grid passed every target but did not meet the prototype
gate. Because a negative conclusion could be biased by libslope's stricter
internal tolerance, a separately recorded control fixes its internal tolerance
at 1e-6 (`--library-tol 1e-6`), reruns the same grid and applies the same external
certificate and decision gate. All original results remain intact. No instance
selects its fastest tolerance, and invalid results are retained. Fresh seeds
6--7 use this fixed control setting, two timing blocks, and the complete grid.
This control was specified after viewing the strict main results and before
viewing any control/fresh-seed measurements. It is not a prespecified
confirmation of the strict-tolerance comparison. Package settings are unchanged.

## Results and decision (2026-10-25)

**Defer a general native hybrid cluster-coordinate prototype.** The original
gate was not met in the strict reference, the tolerance control or the fresh
control stage. No dimension/correlation stratum had a 3x median advantage on
both single fits and paths. This does not rule out a useful path-specific method:
the larger correlated-design paths show a substantial, reproducible advantage
for libslope. The next lower-cost experiment should isolate APG path-state reuse
(especially its curvature estimate) before attributing that gap to cluster
coordinate updates or implementing another algorithm.

Every requested call and point met the common certificate:

| Stage | Library internal tol | Calls | Returned points |
|---|---:|---:|---:|
| strict reference, seeds 1--5 | 1e-9 | 2,160 / 2,160 | 10,080 / 10,080 |
| accuracy control, same grid | 1e-6 | 2,160 / 2,160 | 10,080 / 10,080 |
| fresh control, seeds 6--7 | 1e-6 | 576 / 576 | 2,688 / 2,688 |

These are **4,896 calls and 22,848 returned points**, excluding canary runs.
The main and tolerance-control grids are separate measurements of the same
instances, not independent replicates. Final numerical checks passed 85
assertions. Exact call/level identity sets, duplicate rejection, path validity
and byte-for-byte summary reproduction are checked by Python and CI.

Median paired **APG time / SLOPE.jl time** is below; above one favors libslope.
Single-fit rows pool alpha/alpha_max=0.3 and 0.05. Each stratum pools the two
weight shapes and signal sparsities. All pairs are valid, so no failures are
excluded from these medians. Main/control have 120 single pairs and 60 path
pairs per stratum; fresh control has 32 and 16, respectively.

| n,p | rho | strict single | strict path | control single | control path | fresh single | fresh path |
|---|---:|---:|---:|---:|---:|---:|---:|
| 200,500 | 0 | 0.688 | 1.172 | 0.746 | 1.231 | 0.732 | 1.285 |
| 200,500 | 0.9 | 0.577 | 0.518 | 0.849 | 0.916 | 0.884 | 1.226 |
| 1000,2000 | 0 | 1.107 | 2.352 | 1.322 | 2.805 | 1.214 | 2.647 |
| 1000,2000 | 0.9 | 0.954 | 2.963 | 2.173 | 6.358 | 1.725 | 5.365 |

For single fits, current APG is competitive: it is faster in the smaller
dimension and within about 1.2--2.2x of libslope in the larger tolerance-control
strata. Large-design paths are the clear exception. Package paths currently
restart momentum and the initial step at each level; libslope preserves its
native path state. Implementation language, interfaces and certificate schedules
also differ. This comparison does not isolate the effect of cluster-coordinate
updates. A native prototype has not been measured, and an external library's
speed is not a promise about a Julia implementation.

The largest APG coefficient difference from libslope was 0.00240 in the original
grid/control and 0.00157 on fresh seeds; relative objective differences were at
most 1.09e-7 and 1.53e-9, respectively. Prediction differences were also small
(relative to max(1,||y||), at most 2.73e-4 and 3.55e-5). These are achieved-gap
comparisons, not identical coefficient accuracy. The earlier standalone FISTA
pilot used different stopping and penalty scaling, so its approximately 14x
gap must not be interpreted as today's package APG gap.

The hybrid method remains a candidate for a later, focused path experiment.
It requires dynamic clusters and periodic proximal-gradient steps; simply
enabling ordinary coordinate updates for this nonseparable penalty is not
valid. See [Larsson et al. (2023)](https://proceedings.mlr.press/v206/larsson23a.html).
For an immediate path-heavy workload, the retained SLOPE.jl adapter is already
a useful benchmark option. No public solver or extension is added here.

## Retained evidence and recreation

[Evidence](evidence/20261025) includes all three grids, their summaries, the
clean final checks, the resolved environment and Slurm launchers. The lockfile
`environment.toml` contains the original development paths; rebind ProximalBase
and this checkout when recreating it elsewhere. ProximalBase is pinned at
`1f93b03`, SLOPE.jl is 1.3.1 and its backend is slope_jll 6.5.2+0. No registered
ProximalBase release was needed for this isolated benchmark environment.

```sh
# Numerical commands run inside a Discovery allocation, after environment setup.
julia --startup-file=no --project=benchmark/slope benchmark/slope/run.jl \
  --shard 1 --shards 4 --library-tol 1e-6 --out accuracy_control
julia --startup-file=no --project=benchmark/slope benchmark/slope/run.jl \
  --shard 1 --shards 4 --library-tol 1e-6 --seeds 6,7 --rounds 2 --out confirmation
# Repeat shards 2--4 as for the main grid.
python3 benchmark/slope/check_summary.py
python3 benchmark/slope/check_evidence.py
```

Discovery jobs: setup 13422767 failed before fitting because of a corrected
Random UUID (5s); setup/canary 13422769 completed (1m23s); main 13422780
(2m16s); tolerance control 13423094 (2m40s); fresh control 13423095 (48s); final
validation 13423109 (17s). Total allocated running time was **7m29s**, including
setup/recovery, peak four CPUs and 16GB, one Julia/BLAS/OpenMP thread per worker.
Main source is `bb69eb1`, control/fresh source `ef6ec58`, and final checks
`d3d0e5f`. The initial source assembly omitted the optional ProximalBase Test
extension: assertions passed despite its load warning. Final clean checks
restored that directory from the same pinned commit. Measured loss/solver code
did not change. The final helper also propagates a nondefault requested tolerance
to final validation; every measurement used the unchanged 1e-6 default.
