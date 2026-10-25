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

Centering, standardization, intercept recovery, noise estimation and statistical
weight calibration belong to the model layer. HighDimensionalModels uses this
engine for its SLOPE estimator and adds these model operations. The public engine
contains no cluster-coordinate hybrid updates.

## Accuracy and retained failures

A level converges only if the full proximal fixed-point residual
`norm(x - prox_g(x - gradient(f,x)), Inf)` is at most
`tol * max(1, norm(gradient(f,zero(x)), Inf))`, in the supplied loss units.
This tests the zero cluster as well as the nonzero clusters. A reduced fit alone
cannot certify convergence. Violations trigger a larger working set and a refit;
`screening=false` disables screening while keeping the full check.

`maxiter` limits the sum of APG iterations across repairs at each level. Failed
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
