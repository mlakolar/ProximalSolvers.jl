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
