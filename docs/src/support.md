# Supported problems

This page describes **the current GitHub development master branch**, not
the wider feature set in historical releases.

## Problem × solver matrix

The table lists the combinations of problem, solver, iterate and element type with verified
support: `solve!` accepts the combination, and a test under `test/` checks the returned point
against an independent reference for each element type listed. An entry "Float32, Float64"
means both; a letter refers to a limit in the notes below the table. A dash means that
`solve!` refuses the combination with an `ArgumentError`. A combination that is not marked
as supported in the table is not verified; the sections below give the exact input rules, and
[What is not supported yet?](@ref "What is not supported yet?") lists what is deferred.

| Problem | `CDSolver` on a `Vector` | `CDSolver` on a `SparseIterate` | `CDSolver` on a `BlockIterate` | `CDSolver` on a `Matrix` | `ProximalGradientDescent` on a `Vector` | `ProximalGradientDescent` on a `Matrix` | `AccProxGradDescent` on a `Vector` | `ADMMSolver` on a `Vector` | `ADMMSolver` on a `Matrix` | Tutorial |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lasso: `LeastSquaresLoss`, `NormL1` | Float32, Float64 | Float32, Float64 | — | — | Float32 (a), Float64 | — | Float32 (a, b), Float64 (b) | Float64 (l) | — | [Lasso](examples/problems/lasso.md) |
| Weighted lasso: `LeastSquaresLoss`, `NormL1(lambda, w)` | Float32, Float64 (f) | Float32, Float64 (f) | — | — | Float32 (a, f), Float64 (f) | — | Float32 (a, b, f), Float64 (b, f) | — | — | [Weighted lasso](examples/problems/weighted_lasso.md), [solver comparison](examples/comparisons/weighted_lasso_solvers.md) |
| Nonnegative least squares: `LeastSquaresLoss`, `IndNonnegative()` | — | — | — | — | Float32 (a, i), Float64 (i) | — | — | — | — | [Nonnegative least squares](examples/problems/nonnegative_least_squares.md) |
| Nonnegative lasso: `LeastSquaresLoss`, unweighted `NormL1Nonneg` | — | — | — | — | Float32 (a, i), Float64 (i) | — | — | — | — | [Nonnegative sparse regression](examples/problems/nonnegative_lasso.md) |
| Elastic net: `ElasticNet` | Float32, Float64 (c) | Float32, Float64 (c) | — | — | Float32 (a), Float64 | — | Float32 (a, b), Float64 (b) | — | — | [Elastic net](examples/problems/elastic_net.md) |
| Ridge: `LeastSquaresLoss`, uncentered `SqrNormL2` | Float32, Float64 (j) | Float32, Float64 (j) | — | — | — | — | — | — | — | [Ridge with coordinate descent](examples/problems/elastic_net.md#Ridge-with-coordinate-descent) |
| Group lasso: `GroupNormL2` | — | — | Float32, Float64 (d) | — | Float32 (a, h), Float64 (h) | — | Float32 (a, b, h), Float64 (b, h) | — | — | [Group lasso](examples/problems/group_lasso.md) |
| Multi-response group lasso: `LeastSquaresLoss` with a matrix response, `GroupNormL2` on the rows of the coefficients | — | — | Float32, Float64 (g) | Float32, Float64 (g) | — | — | — | — | — | [Multi-task group lasso](examples/problems/multitask_group_lasso.md) |
| Square-root lasso: `SqrtLeastSquaresLoss`, `NormL1` | Float32, Float64 (e) | Float32, Float64 (e) | — | — | — | — | — | — | — | [Square-root lasso](examples/problems/square_root_lasso.md) |
| Box- and ball-constrained least squares: `LeastSquaresLoss`, `IndBox`, `IndBallLinf`, or four-coefficient `IndBallL2` ([IN-08](@ref)) | — | — | — | — | Float32, Float64 | — | Float32, Float64 | — | — | [Constrained least squares](examples/problems/constrained_least_squares.md) |
| ℓ∞-penalized least squares: `LeastSquaresLoss`, `NormLinf` | — | — | — | — | Float32 (a), Float64 | — | Float32 (a, b), Float64 (b) | — | — | [ℓ∞ penalty](examples/problems/linf_regularized_regression.md) |
| Sparse signal denoising: centered `SqrNormL2`, unweighted `NormL1` | — | — | — | — | — | — | — | Float32, Float64 | — | [Sparse signal denoising](examples/problems/sparse_signal_denoising.md) |
| Graphical lasso: `LogDetLoss`, `NormL1(λ₀, Λ)` with symmetric `Matrix` weights | — | — | — | — | — | Float32, Float64, zero diagonal (m) | — | — | Float32, Float64, full weights (k) | [Graphical lasso](examples/problems/graphical_lasso.md), [solver comparison](examples/comparisons/graphical_lasso_solvers.md) |
| Sparse logistic regression: raw `LogisticLoss` with a binary response, `NormL1` or `NormL1(lambda, w)` | — | — | — | — | Float64 (n) | — | — | — | — | [Sparse logistic regression](examples/problems/logistic_regression.md) |

`ElasticNet` is unweighted where it appears in the table. `NormL1` is unweighted except in three rows: in the
weighted-lasso and sparse logistic regression rows, `NormL1(lambda, w)` has one weight per coefficient, and in the graphical-lasso row,
`NormL1(λ₀, Λ)` has a symmetric weight matrix. ADMM permits nonnegative diagonal
weights ([ADM-04](@ref)). PGD requires a zero diagonal ([PGD-06](@ref)). `GroupNormL2` takes its group
weights, the default `sqrt(|G_k|)` or explicit finite nonnegative weights (see
[Group lasso with coordinate descent](@ref)). The lasso, weighted lasso, elastic net and group lasso rows use
`LeastSquaresLoss` or one positive finite scalar multiple of it, and the square-root lasso
row uses the unscaled `SqrtLeastSquaresLoss`. The multi-response row uses the same loss with a matrix
response `Y` and `Matrix` coefficients (see [Multi-response group lasso with coordinate descent](@ref)). Regression designs use a dense `Matrix`. For `CDSolver`, `converged = true` is the test on the change of the
coefficients over a pass and not a certificate of optimality, except for the square-root
lasso (note e).

Ridge uses the same least-squares loss and supported positive scaling; its
CD-only input rules are specified in [IN-01](@ref). Nonnegative least squares and nonnegative lasso also use
that loss and scaling. Their PGD feasibility rules are specified in [IN-07](@ref).

- **(a)** `ProximalGradientDescent` and `AccProxGradDescent` accept `Float32` data, and the
  tests check the returned point against `BigFloat` or `Float64` references with
  `Float32`-sized tolerances. Except for the weighted lasso (see (f)), selected
  nonnegative-lasso checks (see (i)), and the ℓ∞ reference fixtures in `test/linf.jl`,
  the tests do not require `converged = true`, because a `Float32` solve can end without it: with `ftol = 0`, `ProximalGradientDescent` can stop at
  numerical stagnation with `stagnated = true` and `converged = false`, and with the default
  options a `Float32` solve can end on the objective-increase exit with `converged = false`. Assess the
  returned point with an independent residual; see [Numerical behavior](numerics.md).
- **(b)** `AccProxGradDescent` also needs `max(n, p) + 4 < 1/(4 eps(T))` and
  `n p + 3 < 1/(4 eps(Float64))` (see "What works today?" below).
- **(c)** The elastic net is accepted for the least-squares loss with an unweighted
  `ElasticNet(lambda1, lambda2)`. For `CDSolver`, at a visit to a column with a finite
  positive squared norm `a`, where the loss scale times `a`, or its reciprocal, is below
  `floatmin` of the type that combines the scale with the working type, a visit with
  `lambda2 = 0` takes the lasso's range-safe step and a visit with `lambda2 > 0` is refused
  with an `ArgumentError`. A flat column (all entries 0) sets its coordinate to 0. See
  [Numerical behavior](numerics.md).
- **(d)** `CDSolver` on a `BlockIterate` refuses `momentum = true`, and accepts a `Float64`
  penalty with `Float32` data (tested). The groups of the penalty and of the iterate must be the same, in
  the same order.
- **(e)** The square-root lasso needs the unscaled `SqrtLeastSquaresLoss` and `lambda > 0`.
  `converged = true` means that a duality certificate proved a relative gap of at most
  `1e-4`; a run without a certificate reports `converged = false`, and `Float32` runs can end
  uncertified.
- **(f)** The weighted lasso needs `w` to be a `Vector{T}` of finite nonnegative entries, with the
  level and the products `T(lambda) * w[j]` in the range that
  [Weighted lasso](@ref weighted-lasso-support) states; `solve!` refuses other input with an
  `ArgumentError`. A zero weight leaves its coordinate unpenalized. The tests check every cell
  against `BigFloat` references computed from the data. For `ProximalGradientDescent` and
  `AccProxGradDescent` they pass `allow_f_increases = true` and require `converged = true`; with
  the default options a `Float32` solve can end on the objective-increase exit, as in (a).
- **(g)** The multi-response group lasso needs `X` and `Y` to be `Matrix{T}`, the coefficients to be a `Matrix{T}` or
  a `BlockIterate{T}` over `vec(B)` with the row groups of `B`, and `momentum` other than `true`
  ([the rules](@ref "Multi-response group lasso with coordinate descent")). The tests check the `Matrix` and the
  `BlockIterate` coefficients against an independent KKT residual and objective computed from `X` and `Y`.
- **(h)** `ProximalGradientDescent` and `AccProxGradDescent` with `GroupNormL2` need a `GroupNormL2{T}` of the element type of the data
  whose groups partition `1:p`, with the level and coefficients in the range that
  [Group lasso with proximal gradient descent](@ref) states.
- **(j)** With uncentered `SqrNormL2(lambda)`, the penalty is `(lambda / 2) * sum(abs2, beta)`.
  Construct it with `SqrNormL2(lambda)` to select the `Nothing` center type used by the coordinate prox.
  The level must be finite, nonnegative and representable in the coefficient type without overflow
  or rounding a nonzero value to zero. For a finite positive squared column norm, the step outside
  the normal range in (c) is refused at a positive level and is unpenalized at level zero.
  A flat column sets its coordinate to zero. Centered penalties, even with an
  all-zero center, are refused; so are `SqrNormL2` with PGD, APG, block or matrix
  coefficients, or square-root loss. See [supported calls](@ref IN-01),
  [scalar levels](@ref IN-02) and [coordinate range rules](@ref CD-04).
- **(k)** Matrix ADMM needs an exactly symmetric `Matrix{T}` start whose Cholesky
  factorization succeeds in `T`, `LogDetLoss(S)` with weight one and `NormL1(λ₀, Λ)` with finite,
  nonnegative, exactly symmetric full `Matrix{T}` weights, a fixed `ρ`, a stored `α`
  equal to 1 and `adaptive = false` ([ADM-04](@ref) lists all conditions). The tests check
  each element type against analytic optima and a seeded problem with an independently computed
  objective and KKT scores, and, on those fixtures, a candidate dual matrix that must pass a
  Cholesky check, with its gap compared against a roundoff allowance. See
  [Graphical lasso with consensus ADMM](@ref).
- **(l)** `ADMMSolver` solves the lasso only with the raw `LeastSquaresLoss(y, X)`, an unweighted
  `NormL1(n * lambda)` for the normalized lasso, a `Vector{Float64}` iterate, a `Matrix{Float64}`
  design, a `Vector{Float64}` response and a tall or square design (`n ≥ p`). A `Float32` or mixed
  type, a scaled loss, a weighted penalty and a wide design (`n < p`) are refused with an
  `ArgumentError`. The tests and the lasso tutorials check the returned point against an
  independent objective and KKT violation. See [Lasso with consensus ADMM](@ref) and [ADM-05](@ref).
- **(m)** Matrix PGD requires zero-diagonal weights and starts from a dense
  symmetric positive-definite matrix. It uses bounded
  backtracking and a normalized KKT check. The [matrix PGD contract](@ref PGD-06) gives
  the input and option rules. The [solver comparison](examples/comparisons/graphical_lasso_solvers.md)
  fits the same estimator with ADMM and PGD.
- **(n)** Sparse logistic regression needs `X::Matrix{Float64}`, a response `y::Vector{Float64}`
  whose entries are 0 or 1, a `Vector{Float64}` coefficient and a raw `LogisticLoss(y, X)`
  without observation weights or offset ([IN-09](@ref); see also [Sparse logistic regression with proximal gradient descent](@ref)).
  The tests check the returned point against an objective, gradient and KKT residual computed
  from the data in `BigFloat`.

### Statistical applications

These tutorials apply rows of the matrix to statistical problems and add no solver support.

- [Robust sparse regression](examples/problems/robust_sparse_regression.md): sparse response contamination fitted as a weighted lasso on `[X I]`, with separate penalties for predictors and observation corrections (weighted lasso row, `CDSolver` on a `Vector`, Float64).
- [Scaled lasso](examples/problems/scaled_lasso.md): the coefficients and the noise level of Sun and Zhang (2012) from one square-root lasso solve, `σ̂ = ‖y − Xβ̂‖₂/√n` (square-root lasso row, `CDSolver` on a `Vector`, Float64).
- [Change-point detection](examples/problems/change_point_detection.md): 1D total-variation denoising, rewritten as a lasso on a step design (lasso row, `CDSolver` on a `Vector`, Float64).
- [Stability selection with repeated lasso fits](examples/problems/stability_selection.md) compares a full-data lasso fit with selection frequencies from repeated half-samples (`CDSolver` on a dense `Vector`, Float64).
- [Gaussian graph: neighborhood selection](examples/problems/nodewise_gaussian_graph.md): the graph of a Gaussian vector from one lasso regression per variable (lasso row, `CDSolver` on a `Vector`, Float64).
- [Categorical factor selection](examples/problems/categorical_group_selection.md): reference-coded factors selected as complete blocks, with an unpenalized intercept handled by centering (group lasso row, `CDSolver` on a `BlockIterate`, Float64).
- [Sparse additive regression](examples/problems/sparse_additive_regression.md): an additive model with one spline block per predictor, fitted as a group lasso (group lasso row, `CDSolver` on a `BlockIterate`, Float64).
- [Sparse deconvolution and event recovery](examples/problems/sparse_deconvolution.md): signed sparse events from blurred observations using a dense causal convolution design (lasso row, `CDSolver` on a `Vector`, Float64).
- [Multi-task group lasso](examples/problems/multitask_group_lasso.md): several regression tasks on one design with a shared set of predictors, the row-sparse penalty `λ √K Σⱼ ‖B[j, :]‖₂` on the coefficient matrix `B` (multi-response group lasso row, `CDSolver` on a `Matrix`, Float64).

## What works today?

The supported objective is a lasso (CD also solves a group lasso on a `BlockIterate` and a
square-root lasso, and PGD and APG a group lasso on a dense vector, below):

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_1,
~~~

where `s=1` for raw `LeastSquaresLoss` or `s=1/n` for the
usual normalized convention; all three solvers also accept per-coordinate weights
(`NormL1(lambda, w)`, see [Weighted lasso](@ref weighted-lasso-support)). `CDSolver`, `ProximalGradientDescent` and `AccProxGradDescent` also solve the
elastic net

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda_1\|\beta\|_1+\frac{\lambda_2}{2}\|\beta\|_2^2,
~~~

with `ElasticNet(lambda1, lambda2)`. `CDSolver` also accepts uncentered
`SqrNormL2(lambda)` for ridge, the elastic-net objective with the L1 level set to
zero. Its supported storage and center type are specified in [IN-01](@ref).
`ProximalGradientDescent` and `AccProxGradDescent` also solve the
ℓ∞-penalized problem (below). PGD additionally supports nonnegative coefficients
with `IndNonnegative()` or unweighted `NormL1Nonneg`. See [the nonnegative input rules](@ref IN-07).
CD's numerical step restrictions and its change-test
meaning of `converged` are specified in [the scalar CD contract](@ref CD-01).

| Input | Supported |
| --- | --- |
| Design matrix `X` | Nonempty, finite, dense `Matrix{Float32}` or `Matrix{Float64}` |
| Response `y` | Finite vector with the same element type and `length(y) == size(X,1)`; for `LogisticLoss`, a `Vector{Float64}` whose entries are 0 or 1 |
| Coefficients `beta` | Same-type dense vector for CD, PGD or APG; alternatively, one-dimensional ProximalBase `SparseIterate` for CD only |
| Loss | `LeastSquaresLoss` or one finite positive scalar multiple of it; for `CDSolver` on a dense vector or a `SparseIterate`, also ProximalBase's `SqrtLeastSquaresLoss` (unscaled; see below); for `ProximalGradientDescent` on a `Vector{Float64}`, also the raw `LogisticLoss` with `NormL1` (see below) |
| Penalty | With the least-squares loss, `NormL1(lambda)` or `NormL1(lambda, w)` with nonnegative finite `lambda` and, for `w`, a `Vector{T}` of finite nonnegative weights (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`); an unweighted `NormL1(lambda)` with positive `lambda` with `SqrtLeastSquaresLoss`; unweighted `ElasticNet(lambda1, lambda2)` with nonnegative finite levels (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`, with the least-squares loss; with CD and `lambda2 > 0`, a coordinate step outside the normal range is refused, see [the numerical guide](numerics.md)); `NormLinf(lambda)` with a nonnegative finite `lambda` representable in `T` (PGD and APG on a dense vector, least-squares loss only; refused by `CDSolver`); with `LogisticLoss`, `NormL1(lambda)` or `NormL1(lambda, w)` for `ProximalGradientDescent` on a `Vector{Float64}` ([IN-09](@ref)) |
| Ridge penalty | Uncentered `SqrNormL2(lambda)` with the least-squares loss and `CDSolver` on a dense vector or a one-dimensional `SparseIterate` (note j above) |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`) |
| Group lasso | `CDSolver` with a ProximalBase `BlockIterate{Float32}` or `BlockIterate{Float64}` as the coefficients and a `GroupNormL2{Float32}` or `GroupNormL2{Float64}` penalty, and `ProximalGradientDescent` or `AccProxGradDescent` with a dense `Vector{T}` and a `GroupNormL2{T}` penalty, on the same dense least-squares loss (see below) |
| Nonnegative least squares and lasso | `ProximalGradientDescent` only, with `IndNonnegative()` or unweighted `NormL1Nonneg(lambda)`, dense same-type least-squares data and a feasible nonnegative `Vector{T}` start; see note (i) |
| Multi-response group lasso | `CDSolver` only, with `X::Matrix{T}`, `Y::Matrix{T}`, `Matrix{T}` coefficients (or a `BlockIterate{T}` over their entries) and a `GroupNormL2` whose groups are the rows of the coefficients, on the least-squares loss (see below) |

### Lasso with consensus ADMM

~~~math
\min_\beta\quad \frac12\|y-X\beta\|_2^2+n\lambda\|\beta\|_1,
~~~

which is the normalized lasso with `s = 1/n`, multiplied by `n`. Use the raw `LeastSquaresLoss(y, X)`
without a scale and `NormL1(n * lambda)`; the reported `minimum` is `n` times the normalized
objective. The iterate, design and response are `Vector{Float64}`, `Matrix{Float64}` and
`Vector{Float64}`, with `n ≥ p`. A wide design is refused with an `ArgumentError` and is not part of
the supported surface; its support is a follow-up that depends on ProximalBase.

The proximal step of the loss uses an SVD of `X` that the loss object caches on its first call. The
solver reuses that cache for every iteration and for later solves with the same loss, which must
therefore be used by one solve at a time. The first call is expensive and the later ones are cheap,
so compare the time to a given accuracy with and without the setup, as the
[solver comparison](examples/comparisons/lasso_solvers.md) does. `converged = true` reports the
ADMM residual tests, with a stationarity check when both residuals are zero; it is not an optimality
certificate. See [ADM-05](@ref) for the exact rules and the
[lasso tutorial](examples/problems/lasso.md#Consensus-ADMM) for an independently checked fit.

### Sparse signal denoising with consensus ADMM

Use `SqrNormL2(λ, c)` and unweighted `NormL1(τ)` with `ADMMSolver` to fit a
sparse vector to measurements `c`. The measurements, coefficients and optional
scaled dual use a common `Float32` or `Float64` dense vector type. The
[denoising tutorial](examples/problems/sparse_signal_denoising.md) checks its
fit against soft thresholding. See [ADM-01](@ref) for the exact input rules
and [ADM-02](@ref) for the residual tests and limits.

### Graphical lasso with consensus ADMM

~~~math
\min_{\Theta=\Theta^\top\succ0}\quad -\log\det\Theta+\operatorname{tr}(S\Theta)+\lambda_0\sum_{i,j}\Lambda_{ij}|\Theta_{ij}|,
~~~

where `S` is typically a sample covariance. Use `LogDetLoss(S)` and `NormL1(λ₀, Λ)`, where `Λ`
is a finite, nonnegative, exactly symmetric `Matrix` with diagonal weights permitted. Run `ADMMSolver` on
a dense, exactly symmetric `Matrix` start whose Cholesky factorization succeeds, such as the
identity. The data, weights, start and optional scaled dual share one `Float32` or `Float64`
element type. The penalty runs over the full matrix, so each off-diagonal pair counts twice.
On positive-definite `Θ`, the diagonal penalty is linear because `Θ[i,i] > 0`.
An equivalent formulation adds `λ₀ * Λ[i,i]` to each covariance diagonal entry
and uses a separate weight matrix with its diagonal set to zero. The shifted
covariance must be finite and exactly symmetric. Forming the shift in working
precision can round the effective weight and the sum.

Use a fixed `ρ`, an `α` stored as 1 by the `ADMMSolver` constructor and `adaptive = false`.
On a normal return the matrix is exactly symmetric and passes a Cholesky factorization in its
element type. `converged = true` reports
the ADMM residual tests, with a stationarity check when both residuals are zero; it is not an
optimality certificate. See [ADM-04](@ref) for the exact input, Cholesky and stopping
rules. The [graphical-lasso tutorial](examples/problems/graphical_lasso.md) checks a
fit independently with its objective and KKT conditions and, when its stored dual matrix passes
an exact box check and a Cholesky test, reports a numerical estimate of the duality gap.

### Graphical lasso with proximal gradient

Use the same `LogDetLoss` and zero-diagonal `NormL1` weights with
`ProximalGradientDescent()`. Each committed iterate passes Cholesky in its
element type, and the convergence flag requires a normalized KKT check. See
[PGD-06](@ref) and the [solver comparison](examples/comparisons/graphical_lasso_solvers.md).

### [Weighted lasso](@id weighted-lasso-support)

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\sum_j w_j|\beta_j|,
~~~

Use `NormL1(lambda, w)` with one finite nonnegative `Vector{T}` weight per
coefficient and data of the same element type. A zero weight leaves that
coefficient unpenalized. The accepted levels, rounded products, alias checks and
preflight behavior are specified in [the weighted-input contract](@ref IN-03).

CD, PGD and APG accept this penalty for least squares; weighted square-root
lasso, weighted elastic net and wrapped penalties remain unsupported.
[The weighted-lasso example](examples/problems/weighted_lasso.md) demonstrates
an adaptive fit with a zero weight, and [the solver comparison](examples/comparisons/weighted_lasso_solvers.md)
checks four solver configurations against one common accuracy target. The relationship between checked weights
and proximal thresholds is described in [working precision](@ref FP-01).

### ℓ∞ penalty with PGD and APG

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_\infty,\qquad \|\beta\|_\infty=\max_j|\beta_j|,
~~~

Use `NormLinf(lambda)` with PGD or APG, a dense coefficient vector and a finite
nonnegative level satisfying [the input rules](@ref IN-01). `CDSolver` refuses
this nonseparable penalty, and a `Scaled` penalty wrapper is unsupported.

In exact arithmetic, zero is a minimizer exactly when
`lambda >= s * norm(X' * y, 1)`. A stopping proposal is checked by
[the generic proximal-gradient rule](@ref STOP-01). See the
[ℓ∞ tutorial](examples/problems/linf_regularized_regression.md) for both solvers.

### Group lasso with coordinate descent

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\sum_k w_k\|\beta_{G_k}\|_2,
~~~

Use `GroupNormL2(lambda, groups)` or `GroupNormL2(lambda, groups, w)`;
default weights are `sqrt(length(group))`. CD requires a `BlockIterate` with
identical groups, in the same order, covering all coefficients. `BlockIterate(T,
p, g)` constructs matching storage. Both data precisions are supported, and
CD can accept a Float64 group penalty with Float32 data.

Set `momentum=false` or leave it as `nothing`; `momentum=true` is refused.
A pass visits groups, and `converged` reports a group-change test. The complete
parameter, layout, curvature and transaction rules are in
[the group CD contract](@ref CDG-01).

### Group lasso with proximal gradient descent

PGD and APG solve the same group objective on a dense `Vector{T}` with a
`GroupNormL2{T}` penalty: its level and weights must use the data's element type.
Use `GroupNormL2(T(lambda), groups, T.(w))` when converting a penalty.

The groups must partition `1:p` and agree with the penalty's stored layout;
construct a new penalty rather than modifying that layout in place. A zero
weight leaves its group unpenalized. Weight ranges and alias restrictions are
specified in [the group input contract](@ref IN-04), and proposed stops must
pass [the group stationarity check](@ref STOP-01).

### Multi-response group lasso with coordinate descent

~~~math
\min_B\quad \frac{s}{2}\|Y-XB\|_F^2+\lambda\sum_{j=1}^p w_j\|B_{j,:}\|_2,
~~~

for `X` of size `n × p`, a response `Y` of size `n × K` and coefficients `B` of size `p × K`; row `j` of `B` is the
group `j`, and the default weights are `w_j = sqrt(K)`. The call is

```julia
groups = [collect(j:p:p*K) for j in 1:p]    # row j of the column-major B
f = (1/n) * LeastSquaresLoss(Y, X)
g = GroupNormL2(lambda, groups)
B = zeros(Float64, p, K)
r = solve!(B, f, g, CDSolver(order = :cyclic, momentum = false))
r.minimizer === B
```

The design, response and coefficient matrices use the same `Float32` or
`Float64` element type. Groups index the rows through `vec(B)`, exactly as in
the code above, and momentum is unsupported. A `BlockIterate` over those same
entries and groups is also accepted.

The returned minimizer shares the supplied coefficients; copy them to keep an
older fit. A completed finite CD run commits its result, while a numerical
failure leaves the caller's coefficients unchanged. The precise shape, alias,
range and mutation rules are in [the multi-response contract](@ref CDM-01).

Here `converged` reports the row-change test, so check row-group KKT conditions
independently. There is no intercept: center the columns of `X` and `Y` for a
centered model. PGD, APG, scalar penalties and square-root loss are unsupported
for this matrix-response interface.

### Square-root lasso with coordinate descent

~~~math
\min_\beta\quad P(\beta) = \|y-X\beta\|_2+\lambda\|\beta\|_1
~~~

Use ProximalBase's `SqrtLeastSquaresLoss(y, X)` with an unweighted
`NormL1(lambda)`, where `lambda > 0`, and CD on a dense vector or one-dimensional
`SparseIterate`. The normalized objective
`norm(y-X*beta)/sqrt(n) + lambda_n*norm(beta,1)` has the same minimizers at
`lambda = sqrt(n)*lambda_n` in this unnormalized interface.

Weighted penalties, elastic net, scaled square-root losses and gradient solvers
are not supported here. The [square-root contract](@ref CDQ-01) gives the exact
input rules, scaling equivalences and certificate semantics.

A successful convergence flag proves a relative objective error of at most
`1e-4` when the minimum is positive. The certificate bound is rounded upward to
the working type `T` for `gap`, so its stored Float32 value can be slightly above
`1e-4`. After an uncertified change-test stop, a
bounded smoothing fallback can run within `maxpasses`; it can certify the stopped
point or return a point with a proved lower objective. Exact fits can be
coordinatewise minima without minimizing the whole objective, and the fallback
does not guarantee recovery. A final uncertified result has `converged=false`,
`gap=NaN` and its own warning. See the [certificate](@ref CDQ-03) and [bounded recovery rules](@ref CDQ-05).

[The worked square-root example](examples/problems/square_root_lasso.md) checks
a seeded problem independently and shows three exact fits: two that the fallback
certifies and one that it does not.
The [scaled-lasso example](examples/problems/scaled_lasso.md) explains the
related noise estimate; there is no separate scaled-lasso solver.

The data and coefficients use one common `Float32` or `Float64` element type.
Finite nonnegative penalty levels can be supplied in another scalar type when
they satisfy [the scalar-parameter rules](@ref IN-02).

A supported positive loss scale multiplies the objective by a fixed number;
it does not estimate a noise level. Use native floating-point scales when
possible, and consult [the exact loss-scale rules](@ref IN-02) for integer and
other scalar types. Mixed-element-type data arrays are unsupported.

Do not mutate data during a solve or alias coefficients with inputs or penalty
weights. Save `copy(beta)` when retaining fits. See [the alias rules](@ref IN-05)
and [result and failure semantics](@ref RES-01).

For an executable complete example, see [Getting started](getting-started.md).
For using sparse **coefficients**, see the
[sparsity tutorial](sparsity-and-kkt.md). The design matrix still must be
dense, even when the coefficients use `SparseIterate`.

### Sparse logistic regression with proximal gradient descent

~~~math
\min_b\quad \sum_{i=1}^n \{\log(1+e^{\eta_i})-y_i\eta_i\}+\lambda\sum_j w_j|b_j|,\qquad \eta=Xb,
~~~

with `w_j = 1` for the unweighted `NormL1(lambda)`. With a first column of ones in `X`
and `w = [0.0; ones(size(X, 2) - 1)]`, the first coefficient is an unpenalized intercept
and the penalty is `lambda` times the ℓ₁ norm of the other coefficients.

Use ProximalBase's `LogisticLoss(y, X)` with `NormL1(lambda)` or `NormL1(lambda, w)` and
`ProximalGradientDescent` on a `Vector{Float64}`. The design is a dense `Matrix{Float64}`,
the response a `Vector{Float64}` of zeros and ones, and the loss has no observation weights
or offset. The loss is the sum over the observations; for the mean negative log likelihood
plus `λ‖b‖₁`, pass the level `n * λ`. For an intercept, put a column of ones in `X` and give
it the penalty weight zero.

`AccProxGradDescent`, `CDSolver`, a `Scaled` logistic loss, observation weights or an
offset, `Float32` data, sparse designs and other penalties are refused before any write. The exact
input rules, the curvature factor of the line search and the stopping scale are in
[the logistic input contract](@ref IN-09). The [tutorial](examples/problems/logistic_regression.md)
fits seeded data and checks its objective and KKT residual from the data.

### Nonnegative lasso with proximal gradient descent

**(i)** With dense least-squares data and a feasible nonnegative starting vector,
use `IndNonnegative()` or `NormL1Nonneg(0)` for nonnegative least squares.
Use unweighted `NormL1Nonneg(lambda)` with a positive level for nonnegative
lasso. These combinations are available with PGD. See [the input contract](@ref IN-07)
for refusals and [the constrained stationarity check](@ref STOP-16) for how PGD
checks a stopping proposal at positive and zero coefficients.

The [NNLS walkthrough](examples/problems/nonnegative_least_squares.md) compares
the two objectives on a common mixture. The [nonnegative sparse-regression
walkthrough](examples/problems/nonnegative_lasso.md) compares constrained and
ordinary lasso.

## What is not supported yet?

The current development core intentionally excludes the following:

| Feature | Current status |
| --- | --- |
| Sparse design matrices; sparse or view-based dense coefficients | Deferred |
| Generalized losses other than the raw `LogisticLoss` with `NormL1` and `ProximalGradientDescent` in [IN-09](@ref); automatic intercept handling and offsets (a column of ones can be supplied as an unpenalized coordinate, with penalty weight zero, under the input rules of a weighted `NormL1`); matrix responses other than least squares with `CDSolver`, a row-group `GroupNormL2` and a `Matrix` or `BlockIterate` coefficient | Deferred |
| `LogisticLoss` with `AccProxGradDescent`, `CDSolver` or `ADMMSolver`, with observation weights or an offset, `Scaled(LogisticLoss)`, `Float32` data, a sparse design or a penalty other than `NormL1` | Refused with an `ArgumentError` (deferred) |
| Group penalties other than `GroupNormL2` with `CDSolver` on a `BlockIterate`, weighted `ElasticNet`, `Scaled` penalties (including `Scaled(NormL1)` and `Scaled(ElasticNet)`), generalized penalty combinations | Deferred |
| Observation weights; infinite penalty weights; penalty weight storage or types outside the solver's contract, including graphical-lasso weights outside [ADM-04](@ref) or [PGD-06](@ref) | Deferred; each solver's contract lists the weights it accepts |
| Penalty paths and screening; dual-gap certificates other than the one of the square-root lasso with `CDSolver` | Deferred |
| Weighted square-root lasso, `Scaled(SqrtLeastSquaresLoss)`, `SqrtLeastSquaresLoss` with an `ElasticNet` or a `BlockIterate`, or with PGD or APG | Refused with an `ArgumentError` (weights and `Scaled` deferred) |
| Newton, monotone or active-set accelerated gradient, primal-dual, SLOPE; graphical lasso (log-determinant estimation of a precision matrix) with QUIC or other solvers outside [ADM-04](@ref) and [PGD-06](@ref) | Deferred |
| ADMM with other functions or storage than the supported problems ([ADM-01](@ref), [ADM-05](@ref), [ADM-04](@ref)), product spaces, general linear constraints, custom norms, or over-relaxation or the adaptive penalty on a `Matrix` | Deferred |
| ADMM with `LeastSquaresLoss` and a wide design (`n < p`), `Float32` or mixed types, a scaled loss or a weighted penalty | Refused with an `ArgumentError`; wide designs are an upstream follow-up |
| Generic workspaces, refitting, reweighting | Deferred |
| PGD or APG with `SparseIterate` coefficients | Deferred |
| PGD or APG with `BlockIterate` coefficients or a matrix response, and matrix coefficients outside [PGD-06](@ref) | Deferred; refused with an `ArgumentError` |
| `CDSolver` with `NormLinf`; `Scaled(NormLinf)`; `NormLinf` with a loss other than least squares | Refused with an `ArgumentError` (this `CDSolver` needs a separable penalty; the others deferred) |
| `NormL0` with `solve!` | The [ℓ₀ sparse-regression tutorial](examples/problems/l0_sparse_regression.md) runs its own IHT routine with the ProximalBase prox. |
| Momentum (`momentum = true`) with a `BlockIterate` | Rejected; not implemented |
| Group lasso with a sparse design, mixed-element-type arrays or a loss other than least squares | Deferred |
| CD `anderson>0`, `gaptol>0`, `gapsafe=true` | Rejected; not implemented |
| `ProximalOptions(gaptol>0)` | Rejected when the options are constructed; not implemented |
| PGD `normalized=true`, `debias>0`, `preconditioner != :none` | Rejected; not implemented |
| APG `preconditioner != :none` | Rejected; not implemented |

Some historical keywords remain in signatures only at their defaults;
their presence does not mean the feature is implemented. See
[unsupported features and compatibility keywords](@ref DEF-01).
`kkt_checks=0` and an unavailable `gap` are placeholders, with the certified
square-root exception described in [the result contract](@ref RES-01).

## About previous versions

Historical releases and archival branches can expose different features.
Their context is preserved in [the history page](contracts/history.md);
this guide does not provide a migration procedure for every old algorithm.
Use [Getting started](getting-started.md) for the documented development version.

See [Numerical behavior](numerics.md) for stopping and precision.
Detailed implementation, failure transaction and internal algorithm
contracts are preserved under
[Contributor implementation notes](developer/implementation-notes.md).

