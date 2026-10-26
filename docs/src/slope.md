# Screened SLOPE paths

[`SLOPEAPG`](@ref) solves single-response least squares with a sorted L1 penalty
using the existing accelerated proximal gradient solver. It reuses the preceding
path solution, screens columns with the sequential SLOPE strong rule, and repairs
excluded coordinates after checking the full problem. The sorted penalty couples
coefficient ranks, so ordinary coordinatewise lasso checks do not apply.

```julia
using ProximalBase, ProximalSolvers

# X and y are already prepared floating-point data; weights are nonincreasing.
f = (1 / length(y)) * LeastSquaresLoss(y, X)
g = SLOPE(weights)
method = SLOPEAPG(; maxiter=10_000, tol=1e-7)
top = lambda_max(f, g, zeros(size(X, 2)))
factors = top .* exp.(range(0, log(0.1); length=20))
path = solve_path(f, g, factors, method)
fit = solve!(zeros(size(X, 2)), f, g, method)
```

The objective at level `k` is
`‖y - X*x‖²/(2n) + factors[k]*sum(weights .* sort(abs.(x); rev=true))`
for the normalized loss above. An unscaled `LeastSquaresLoss` instead uses
`‖y - X*x‖²/2`. The scalar `lambda_max` is an optimization threshold; it does
not choose statistically calibrated weights. It returns zero for a zero null
gradient and can return infinity when all penalty weights are zero. Supply an
explicit positive grid in those cases.

Use matching floating-point types for the loss data and coefficient vector.
For Float32 data, also use a Float32 loss scale, for example
`(1f0 / length(y)) * LeastSquaresLoss(y, X)`, so that the underlying APG scalar
state has the coefficient type. Mixed-precision scalar promotion is not provided
by this driver.

Centering, standardization, intercept recovery, noise estimation and statistical
weight calibration belong to the model layer. HighDimensionalModels uses this
engine for its SLOPE estimator and adds these model operations.

## Opt-in cluster hybrid

Select `SLOPEHybrid(; maxiter=10_000, tol=1e-7)` explicitly to interleave PG
steps with nonzero-cluster coordinate sweeps. The existing APG choice remains
available and unchanged. Both methods share screening, working-set repairs,
the full residual criterion and the result types described below.

The hybrid reuses storage for cluster membership, ranks and scratch across sweeps and path
levels. It caches at most 32 signed cluster columns rather than constructing a
full dense collapsed design. PG steps can split clusters and activate zeros.
By default, up to ten CD sweeps follow each PG step. A bounded initial hybrid
trial reserves at least half of the remaining iteration budget for APG. If the
reduced full fixed-point residual fails to decrease by 20% for two cycles, or
a cluster block is invalid or increases the objective, that reduced solve
switches permanently to APG. These safeguards use numerical progress rather
than an estimate of predictor correlation. See [`SLOPEHybrid`](@ref).

For this option, `maxiter` counts PG/APG steps and complete CD sweeps, summed
over repairs. These units have different costs; compare matched-accuracy time,
allocation and certificate results rather than raw iterations. Convergence
still requires the full problem check. Benchmark results and retained failures
are recorded under `benchmark/slope/hybrid/optimized/`.

## Accuracy and retained failures

A level converges only if the full proximal fixed-point residual
`norm(x - prox_g(x - gradient(f,x)), Inf)` is at most
`tol * max(1, norm(gradient(f,zero(x)), Inf))`, in the supplied loss units.
This tests the zero cluster as well as the nonzero clusters. A reduced fit alone
cannot certify convergence. Violations trigger a larger working set and a refit;
`screening=false` disables screening while keeping the full check.

For `SLOPEAPG`, `maxiter` limits APG iterations across repairs at each level.
For `SLOPEHybrid`, it limits the combined steps and sweeps described above. Failed
levels remain in `path.solutions` with `converged=false`, their residuals and
iteration counts. Later levels receive their own checks. Saved coefficient
vectors are independent snapshots; an optional starting vector `x` is updated
in place to the last solution. For a single fit, `fit.minimizer` aliases its
input vector. Check convergence flags before using a returned path.

## Sparse and implicit designs

The engine accepts dense coefficient vectors and dense, sparse or implicit
least-squares matrices. Matrix multiplication and `X[:, E]` must be efficient;
column restriction should preserve an implicit representation. The full working
set reuses `X`. Non-strided designs reuse certificate buffers and a restricted
loss across path levels, without constructing a full dense design. The caller
validates its matrix storage; the driver validates vector inputs, weights and
finite null-gradient products without scanning an implicit matrix entry by entry.

The extraction and its Discovery comparison are recorded under
`benchmark/slope/extraction`. Earlier comparisons with SLOPE.jl and libslope
remain separate experiments with their own protocols and limitations.
