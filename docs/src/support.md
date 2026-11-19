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

| Problem | `CDSolver` on a `Vector` | `CDSolver` on a `SparseIterate` | `CDSolver` on a `BlockIterate` | `CDSolver` on a `Matrix` | `ProximalGradientDescent` on a `Vector` | `AccProxGradDescent` on a `Vector` | Tutorial |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Lasso: `LeastSquaresLoss`, `NormL1` | Float32, Float64 | Float32, Float64 | — | — | Float32 (a), Float64 | Float32 (a, b), Float64 (b) | [Lasso](examples/problems/lasso.md) |
| Weighted lasso: `LeastSquaresLoss`, `NormL1(lambda, w)` | Float32, Float64 (f) | Float32, Float64 (f) | — | — | Float32 (a, f), Float64 (f) | Float32 (a, b, f), Float64 (b, f) | [Weighted lasso](examples/problems/weighted_lasso.md) |
| Elastic net: `ElasticNet` | Float32, Float64 (c) | Float32, Float64 (c) | — | — | Float32 (a), Float64 | Float32 (a, b), Float64 (b) | [Elastic net](examples/problems/elastic_net.md) |
| Group lasso: `GroupNormL2` | — | — | Float32, Float64 (d) | — | Float32 (a, h), Float64 (h) | Float32 (a, b, h), Float64 (b, h) | [Group lasso](examples/problems/group_lasso.md) |
| Multi-response group lasso: `LeastSquaresLoss` with a matrix response, `GroupNormL2` on the rows of the coefficients | — | — | Float32, Float64 (g) | Float32, Float64 (g) | — | — | [Multi-task group lasso](examples/problems/multitask_group_lasso.md) |
| Square-root lasso: `SqrtLeastSquaresLoss`, `NormL1` | Float32, Float64 (e) | Float32, Float64 (e) | — | — | — | — | [Square-root lasso](examples/problems/square_root_lasso.md) |
| ℓ∞-penalized least squares: `LeastSquaresLoss`, `NormLinf` | — | — | — | — | Float32 (a), Float64 | Float32 (a, b), Float64 (b) | [ℓ∞ penalty](examples/problems/linf_regularized_regression.md) |

`NormL1` and `ElasticNet` are unweighted where they appear in the table, except in the weighted-lasso row,
where `NormL1(lambda, w)` has one weight per coefficient. `GroupNormL2` takes its group
weights, the default `sqrt(|G_k|)` or explicit finite nonnegative weights (see
[Group lasso with coordinate descent](@ref)). The lasso, weighted lasso, elastic net and group lasso rows use
`LeastSquaresLoss` or one positive finite scalar multiple of it, and the square-root lasso
row uses the unscaled `SqrtLeastSquaresLoss`. The multi-response row uses the same loss with a matrix
response `Y` and `Matrix` coefficients (see [Multi-response group lasso with coordinate descent](@ref)). The design is a dense `Matrix`. For `CDSolver`, `converged = true` is the test on the change of the
coefficients over a pass and not a certificate of optimality, except for the square-root
lasso (note e).

- **(a)** `ProximalGradientDescent` and `AccProxGradDescent` accept `Float32` data, and the
  tests check the returned point against `BigFloat` or `Float64` references with
  `Float32`-sized tolerances, and (except for the weighted lasso, see (f)) do not require
  `converged = true`, because a `Float32` solve can end without it: with `ftol = 0`, `ProximalGradientDescent` can stop at
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

**Updating the matrix.** A pull request that adds or removes support for a combination
changes its cell and its tutorial link in the same pull request, together with the test
that backs the new cell. A pull request that adds a problem adds a row, a tutorial under
`examples/problems/` (or registers the path of its example) and its entry in the registry
in `docs/make.jl`.

### Statistical applications

These tutorials apply rows of the matrix to statistical problems and add no solver support.

- [Change-point detection](examples/problems/change_point_detection.md): 1D total-variation denoising, rewritten as a lasso on a step design (lasso row, `CDSolver` on a `Vector`, Float64).
- [Gaussian graph: neighborhood selection](examples/problems/nodewise_gaussian_graph.md): the graph of a Gaussian vector from one lasso regression per variable (lasso row, `CDSolver` on a `Vector`, Float64).
- [Categorical factor selection](examples/problems/categorical_group_selection.md): reference-coded factors selected as complete blocks, with an unpenalized intercept handled by centering (group lasso row, `CDSolver` on a `BlockIterate`, Float64).
- [Sparse additive regression](examples/problems/sparse_additive_regression.md): an additive model with one spline block per predictor, fitted as a group lasso (group lasso row, `CDSolver` on a `BlockIterate`, Float64).
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

with `ElasticNet(lambda1, lambda2)`. `ProximalGradientDescent` and `AccProxGradDescent` also solve the
ℓ∞-penalized problem (below). In the normal range, `CDSolver` takes the coordinate step of a visit from
ProximalBase's `prox_block` of the penalty; out of range, the step of a visit with `lambda2 = 0` is the lasso's
range-safe form and a visit with `lambda2 > 0` is refused (see [the numerical guide](numerics.md)). Its `converged` is the change test, not a KKT
certificate.

| Input | Supported |
| --- | --- |
| Design matrix `X` | Nonempty, finite, dense `Matrix{Float32}` or `Matrix{Float64}` |
| Response `y` | Finite vector with the same element type and `length(y) == size(X,1)` |
| Coefficients `beta` | Same-type dense vector for CD, PGD or APG; alternatively, one-dimensional ProximalBase `SparseIterate` for CD only |
| Loss | `LeastSquaresLoss` or one finite positive scalar multiple of it; for `CDSolver` on a dense vector or a `SparseIterate`, also ProximalBase's `SqrtLeastSquaresLoss` (unscaled; see below) |
| Penalty | With the least-squares loss, `NormL1(lambda)` or `NormL1(lambda, w)` with nonnegative finite `lambda` and, for `w`, a `Vector{T}` of finite nonnegative weights (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`); an unweighted `NormL1(lambda)` with positive `lambda` with `SqrtLeastSquaresLoss`; unweighted `ElasticNet(lambda1, lambda2)` with nonnegative finite levels (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`, with the least-squares loss; with CD and `lambda2 > 0`, a coordinate step outside the normal range is refused, see [the numerical guide](numerics.md)); `NormLinf(lambda)` with a nonnegative finite `lambda` representable in `T` (PGD and APG on a dense vector, least-squares loss only; refused by `CDSolver`) |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`) |
| Group lasso | `CDSolver` with a ProximalBase `BlockIterate{Float32}` or `BlockIterate{Float64}` as the coefficients and a `GroupNormL2{Float32}` or `GroupNormL2{Float64}` penalty, and `ProximalGradientDescent` or `AccProxGradDescent` with a dense `Vector{T}` and a `GroupNormL2{T}` penalty, on the same dense least-squares loss (see below) |
| Multi-response group lasso | `CDSolver` only, with `X::Matrix{T}`, `Y::Matrix{T}`, `Matrix{T}` coefficients (or a `BlockIterate{T}` over their entries) and a `GroupNormL2` whose groups are the rows of the coefficients, on the least-squares loss (see below) |

### [Weighted lasso](@id weighted-lasso-support)

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\sum_j w_j|\beta_j|,
~~~

with `NormL1(lambda, w)`. `solve!(x, f, g, method)` accepts it for `CDSolver` (a dense vector
or a `SparseIterate`), `ProximalGradientDescent` and `AccProxGradDescent`, with the least-squares loss above (a weighted
`NormL1` with `SqrtLeastSquaresLoss` is refused, see below), when

- `w` is a `Vector{T}` with the element type `T` of the data and the coefficients, and one entry per
  coefficient. A `Vector` of the other precision, a view, a range or another array type is refused
  (`collect(T, vec(w))` converts, taking `w` in linear order);
- every weight is finite and nonnegative (an infinite weight is refused);
- the level `lambda` is accepted as above and `T(lambda)` is zero or a normal number of `T` (a level that
  is subnormal in `T` is refused with weights, though an unweighted `NormL1` accepts it), and the coefficient
  `c_j = T(lambda) * w_j` of every entry, the product rounded in `T`, is finite and, where `T(lambda)` and `w_j` are
  both positive, a normal number of `T`. A coefficient that overflows, underflows to zero or is subnormal is
  refused, with the entry `j` named. The rule is on the rounded `c_j`: an exact product slightly below
  `floatmin(T)` that rounds up to `floatmin(T)` is accepted. A zero level or a zero weight gives the
  coefficient 0, which is accepted;
- `x` does not alias `w`, as for `X` and `y`.

These checks run before `x` is copied or written and before the random number generator is
used. A zero weight leaves its coefficient unpenalized: it is not fixed at 0. With CD, a column of
`X` that is zero gets the coefficient 0, also where its weight is zero.

Where `c_j` is used, and where it is not. The checks above, the stopping check of PGD and APG (it scores entry `j` with `c_j` and takes the largest `c_j` as the level `λ` of its scale; see [the stationarity check](@ref "The stationarity check of a stop")), and the coordinate step of CD where it forms its threshold without the product `s * a` use the checked `c_j`. ProximalBase's proximal steps (the proximal step of PGD and APG, and the step of CD where it calls ProximalBase's `prox_block`) form their thresholds from `lambda` and `w_j` in ProximalBase's working type, not from `c_j`. These thresholds and those formed from `c_j` can differ by rounding and, for a `lambda` that is not of type `T`, by the error of converting the level to `T`. When CD takes each step is described in [numerical behavior](numerics.md); the error of `c_j` relative to `lambda * w_j` is described in the [implementation notes](developer/implementation-notes.md). CD's
`converged` remains the change test. A scaled penalty such as `Scaled(NormL1(lambda, w), a)`, and `ElasticNet` with
weights, are refused. [The weighted-lasso tutorial](examples/problems/weighted_lasso.md) solves an adaptive lasso with a zero
weight with all three solvers.

### ℓ∞ penalty with PGD and APG

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_\infty,\qquad \|\beta\|_\infty=\max_j|\beta_j|,
~~~

with `NormLinf(lambda)`, `s = 1` for a raw `LeastSquaresLoss` and the loss scale of one positive `Scaled(LeastSquaresLoss)`
otherwise (`s = 1/n` for the normalized convention). `solve!(x, f, g, ProximalGradientDescent())` and
`solve!(x, f, g, AccProxGradDescent())` accept it when `x` is a dense `Vector{T}`, `X` and `y` are as above with the same `T`,
and `lambda` is finite, nonnegative and representable in `T` without overflow or underflow of a nonzero value; a negative or `NaN`
level cannot be constructed (ProximalBase refuses it), and the other refusals leave `x` unchanged. A wrapper such as
`Scaled(NormLinf(lambda), c)` is refused with the other unsupported penalties. `CDSolver` refuses
`NormLinf` for a dense `Vector`, a `SparseIterate` and a `BlockIterate`, before it changes `x` or draws from its random number
generator: this `CDSolver` needs a separable penalty for its coordinate oracle.
The proximal operator is ProximalBase's. In exact arithmetic, 0 is a minimizer exactly when `lambda ≥ ‖∇f(0)‖₁ = s‖Xᵀy‖₁` (not the lasso's
`‖∇f(0)‖∞`). A proposed stop is verified by [the generic check](numerics.md#The-generic-stationarity-check). For an example with both solvers, see
[the ℓ∞ tutorial](examples/problems/linf_regularized_regression.md).

### Group lasso with coordinate descent

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\sum_k w_k\|\beta_{G_k}\|_2,
~~~

with the groups `G_k` of a `GroupNormL2(lambda, groups)` or
`GroupNormL2(lambda, groups, w)`; the default weights are `w_k = sqrt(|G_k|)`.
`solve!(x, f, g, CDSolver(...))` accepts this problem when

- `x` is a `BlockIterate{T}` and the data, the loss and the scale are as above, with
  `T` equal to `Float32` or `Float64`;
- `g` is a `GroupNormL2` whose element type is `Float32` or `Float64`. A `Float64`
  penalty on `Float32` data is accepted. The level `lambda` and every weight must be
  finite, nonnegative and representable in `T` without overflow, and a nonzero value
  must not round to zero;
- the groups of `g` and of `x` are the same, group by group, in the same order and with
  the same ordered members, otherwise `solve!` throws a `DimensionMismatch`. A
  `BlockIterate` is a nonempty partition of `1:p` into disjoint groups, so there are no
  unpenalized coefficients outside the groups; `BlockIterate(T, p, g)` builds one with
  the groups of `g`;
- the solver does not use momentum: `momentum = true` is refused with an
  `ArgumentError`, and `nothing` or `false` both give plain block coordinate descent.

The coordinates of the solver are the groups: a pass visits whole groups, `passes`
counts passes, and the active coordinates of the iterate are group numbers. All
refusals of these inputs (receiver, momentum, penalty, weights, layout, aliasing of
`x` with `X` or `y`, nonfinite values) throw before `x` is copied or the random number
generator is used. [Numerical behavior](numerics.md) lists the refusals that depend on
the values of `X` and describes the curvature and the stopping statistic of a group.

### Group lasso with proximal gradient descent

`solve!(x, f, g, ProximalGradientDescent(), options)` and `solve!(x, f, g, AccProxGradDescent(), options)` minimize the
same group lasso when `x` is a dense `Vector{T}` (`T` equal to `Float32` or `Float64`), the data, the loss and the scale
are as above (for `AccProxGradDescent`, with the size bounds of (b)), and

- `g` is a `GroupNormL2{T}`: its level and weights have the element type of the data (convert with
  `GroupNormL2(T(lambda), groups, T.(w))`; unlike `CDSolver` on a `BlockIterate`, a `Float64` penalty with
  `Float32` data is refused);
- the groups of `g` partition `1:p` and match the layout stored in the penalty at construction: an index above `p` is
  refused with a `DimensionMismatch`, and an empty group, an index in two groups or in no group, and a change of
  `g.groups` after construction where it disagrees with that layout (ProximalBase's extent and free-coordinate
  logic use the arrays stored at construction) with an `ArgumentError`;
- the level and the weights pass the rules of the [weighted lasso](@ref weighted-lasso-support), with one coefficient
  `c_k = T(lambda) * w_k` per group in place of one per entry (a zero weight leaves its group unpenalized);
- `x` does not alias `X`, `y` or the weights.

These checks run before `x` is written. The proximal step is ProximalBase's block soft threshold. A proposed
stop counts only if ProximalBase's group KKT residual is below `max(gradtol, 64 eps(T)) * S` (for
`AccProxGradDescent`, the check forms `∇f(x)` once per proposed stop and counts it in `grad_calls`), with
`S = max(max_k c_k, max_k ‖[∇f(0)]_{G_k}‖₂)` (see [the stationarity check](@ref "The stationarity check of a stop")).
`test/group_pgd.jl` checks `Float32` and `Float64` solves against references computed from the data in `BigFloat`.
Both `ProximalGradientDescent` and `AccProxGradDescent` run: the closed form on designs with block-orthogonal columns
(raw and `1/n`-scaled loss, default weights and weights with a zero), a correlated design (also against `CDSolver` on a
`BlockIterate`), singleton groups with unit weights against `NormL1(lambda)`, a zero weight, `lambda = 0` against the
least-squares fit, a level above the smallest level with a zero solution, a huge `xtol` or `ftol` that must not stop at a point
that fails the check, and the stop check just below and just above its threshold. Only `ProximalGradientDescent` runs the
contiguous, permuted and single-group layouts given as ranges or as vectors, a group of zero columns, and a `Float64` loss scale
of `1e-300`. Singleton groups with unit weights have the stop scale of `NormL1(lambda)` where no entry of `∇f(0)` has a
subnormal square.

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

The solver works from the original `X` and `Y`, without a Kronecker design or a response flattened into a
vector. It keeps an `n × K` residual and `O(p K)` further storage, and a visit to row `j` costs `O(n K)`. `solve!(B, f, g, CDSolver(...))` accepts this problem when

- `B`, `X` and `Y` are `Matrix{T}` with `T` equal to `Float32` or `Float64`, with `size(B) == (p, K)`, finite
  entries and positive sizes, and `B` shares no memory with `X`, `Y`, the penalty weights `g.w` or the scratch
  array that the loss writes when it is evaluated (a `DimensionMismatch` for a wrong shape, an `ArgumentError`
  for the others);
- `f` is `LeastSquaresLoss(Y, X)` or one positive scalar multiple of it, with the loss scales of the lasso above;
- `g` is a `GroupNormL2` whose element type is `Float32` or `Float64`, with a level and weights as for the group
  lasso above, and its groups are the rows of `B` in order: `g.groups[j] == j:p:p*K` for each `j`, otherwise `solve!`
  throws a `DimensionMismatch`. The groups index the entries of `vec(B)`, not the columns of `X`;
- the solver does not use momentum: `momentum = true` is refused with an `ArgumentError`.

A `BlockIterate` over `vec(B)` with the same groups and the same loss is accepted as well; the iterate is then the
`BlockIterate`, as for the group lasso. `B` is written only after a completed run with a finite objective, and
`minimizer` is `B` itself; a refusal, or a run that fails numerically, leaves `B` unchanged. The refusals of the
inputs above throw before `B` is copied or the random number generator is used. A column of `X` whose squared norm
is not finite or is below `floatmin(T)` (a column of zeros is not refused), or whose step is outside the normal
range of the arithmetic type, is refused with an `ArgumentError` that names the row, before the first pass and
the first random draw, when `maxpasses > 0`. A column of zeros sets its row to 0 at a visit
where the level and the weight are positive and leaves the row as it is where either is zero; with
`maxpasses = 0` no row is visited, the column checks are not made and `B` keeps its values. As for the other CD
problems, `converged` reports the change test and is not a KKT certificate: with `relative = true` and a positive
response scale `sqrt(s * sum(abs2, Y))`, the change of row `j` is the norm of its displacement times
`sqrt(s * a_j)`, with `a_j` the squared norm of column `j` of `X`. To check a fit, form `G = s * X' * (X * B - Y)`
for the loss scale `s` and test, for each row, `norm(G[j, :] + lambda * w[j] * B[j, :] / norm(B[j, :]))` where
the row is not zero and `norm(G[j, :]) <= lambda * w[j]` where it is; with positive weights, `B = 0` is the solution
at `lambda >= s * maximum(norm((X' * Y)[j, :]) / w[j] for j in 1:p)`. There is no intercept: center the columns of `X`
and `Y` first. `ProximalGradientDescent` and `AccProxGradDescent`, a `NormL1` or `ElasticNet` penalty, the
square-root loss, and a vector response with a `Matrix` coefficient are refused with an `ArgumentError`.

### Square-root lasso with coordinate descent

~~~math
\min_\beta\quad P(\beta) = \|y-X\beta\|_2+\lambda\|\beta\|_1
~~~

with ProximalBase's [`SqrtLeastSquaresLoss(y, X)`](https://mlakolar.github.io/ProximalBase.jl/dev/)
(the loss is unnormalized) and `NormL1(lambda)`. `solve!(x, f, g, CDSolver(...))` accepts this problem
when `x` is a dense `Vector{T}` or a one-dimensional `SparseIterate{T}`, `X` and `y` are as above, and
`lambda` is positive, finite and representable in `T`. The normalized objective
`‖y − Xβ‖₂/√n + λₙ‖β‖₁` (`Scaled(f, inv(sqrt(n)))` in ProximalBase) has the same minimizers as `P` at
`lambda = sqrt(n) * λₙ`, and its values are those of `P` divided by `√n`. The [scaled lasso](glossary.md) at
the level `λ₀` has as its coefficient estimate a minimizer of `P` at `lambda = sqrt(n) * λ₀`, and as its noise
estimate `norm(y - X*beta)/sqrt(n)` when `y ≠ X*beta`; the package provides no separate scaled-lasso method,
and [the scaled-lasso tutorial](examples/problems/scaled_lasso.md) shows the computation.
Refused with an `ArgumentError`, before `x` is
copied or the random number generator is used: `Scaled(SqrtLeastSquaresLoss, alpha)` (for a positive
finite `alpha`, use the unscaled loss at the level `lambda/alpha`), `lambda = 0` (use `LeastSquaresLoss`,
which has the same minimizers), a weighted `NormL1` (also with all weights equal to one), an `ElasticNet`,
a `BlockIterate`, and `ProximalGradientDescent` or `AccProxGradDescent` (ProximalBase provides no gradient
for this loss; for `X ≠ 0` it is not differentiable where `y = X*beta`).

For this loss, `converged = true` means that a duality certificate proved
`(P(beta) − P*)/P* ≤ 1e-4`, with `P*` the minimum, and `gap` then holds that proved bound. A run that
stops without a certificate reports `converged = false` and `gap = NaN`, with its own warning: at an exact
fit (`y = X*beta`) with a positive penalty, coordinate descent can stop at a point that minimizes every
coordinate but not `P`. [`CDSolver`](@ref) describes the stopping rule, and
[Numerical behavior](numerics.md) the step and the certificate.
[The square-root lasso tutorial](examples/problems/square_root_lasso.md) solves a seeded problem, checks it
independently from the data, and shows two exact fits.

The three numerical arrays use one common `T` (`Float32` or
`Float64`); mixed-element-type `X`, `y` and coefficient arrays
are not supported. The penalty levels must be finite, nonnegative and
representable in `T` without overflow or rounding a nonzero scalar
to zero; it may be supplied in a different scalar type, including
a representable `Float64` literal in a `Float32` problem.

The scale `s` of `Scaled(LeastSquaresLoss(...), s)` multiplies the loss by a fixed number (for example
`s = 1/n`); it does not make the problem the [scaled lasso](glossary.md), which estimates a noise level.
The loss scale is supported as

- a positive finite `Float32` or `Float64` that converts to a finite nonzero
  number of `T` (a value that is subnormal in `T` is accepted, and a `Float64`
  scale in a `Float32` problem is accepted), or
- a positive fixed-width integer (`Int`, `UInt8` and the other `Base.BitInteger`
  types) or `Bool` that `T` represents exactly: `2^24` for `Float32` data, not
  `2^24 + 1`, and `2^53` for `Float64` data, not `2^53 + 1`.

A scale of any other type (`BigInt`, `BigFloat`, `Rational`, `Float16`,
`Irrational` or another `Real`), and an integer that `T` would round, is
refused with an `ArgumentError` before `solve!` writes to the coefficients.
**This narrows the API:** such scales were accepted before the loss value and
gradient were taken from ProximalBase's least-squares oracles. Convert the
scale explicitly, for example `Float64(s) * LeastSquaresLoss(y, X)`, where
`Float64(s)` is finite, positive and representable in `T` as above; the
error message suggests this conversion when it passes that rule and, for an
integer scale, only when `Float64(s)` equals `s`; for other types it notes that
the conversion may round `s`.
The solvers use the supplied scale combined with `T` by Julia's promotion:
a `Float64` scale in a `Float32` problem keeps its `Float64` value, also
where that value is subnormal in `Float32`. The arrays and the coefficients
stay in `T`, so this does not imply mixed-precision array support or a
guarantee about every intermediate arithmetic type.

The data must not be modified while a solve is running. The coefficient
vector (or the supported CD `SparseIterate`) is mutated in place, so do
not alias it to `X` or `y`. To retain a result, save `copy(beta)`.
See [Numerical behavior](numerics.md) for numerical recovery limits,
solver stopping and diagnostics.

For an executable complete example, see [Getting started](getting-started.md).
For using sparse **coefficients**, see the
[sparsity tutorial](sparsity-and-kkt.md). The design matrix still must be
dense, even when the coefficients use `SparseIterate`.

## What is not supported yet?

The current development core intentionally excludes the following:

| Feature | Current status |
| --- | --- |
| Sparse design matrices; sparse or view-based dense coefficients | Deferred |
| Generalized losses, intercepts/offsets; matrix responses other than least squares with `CDSolver`, a row-group `GroupNormL2` and a `Matrix` or `BlockIterate` coefficient | Deferred |
| Group penalties other than `GroupNormL2` with `CDSolver` on a `BlockIterate`, weighted `ElasticNet`, `Scaled` penalties (including `Scaled(NormL1)` and `Scaled(ElasticNet)`), generalized penalty combinations | Deferred |
| Observation weights; infinite penalty weights; penalty weights that are not a `Vector{T}` of the type of the data | Deferred; the penalty weights are refused with an `ArgumentError` |
| Penalty paths and screening; dual-gap certificates other than the one of the square-root lasso with `CDSolver` | Deferred |
| Weighted square-root lasso, `Scaled(SqrtLeastSquaresLoss)`, `SqrtLeastSquaresLoss` with an `ElasticNet` or a `BlockIterate`, or with PGD or APG | Refused with an `ArgumentError` (weights and `Scaled` deferred) |
| ADMM, Newton, monotone or active-set accelerated gradient, primal-dual, SLOPE, graphical lasso (log-determinant estimation of a precision matrix) | Deferred |
| Generic workspaces, refitting, reweighting | Deferred |
| PGD or APG with `SparseIterate` coefficients | Deferred |
| PGD or APG with `BlockIterate` or `Matrix` coefficients or a matrix response | Deferred; refused with an `ArgumentError` |
| `CDSolver` with `NormLinf`; `Scaled(NormLinf)`; `NormLinf` with a loss other than least squares | Refused with an `ArgumentError` (this `CDSolver` needs a separable penalty; the others deferred) |
| Momentum (`momentum = true`) with a `BlockIterate` | Rejected; not implemented |
| Group lasso with a sparse design, mixed-element-type arrays or a loss other than least squares | Deferred |
| CD `anderson>0`, `gaptol>0`, `gapsafe=true` | Rejected; not implemented |
| `ProximalOptions(gaptol>0)` | Rejected when the options are constructed; not implemented |
| PGD `normalized=true`, `debias>0`, `preconditioner != :none` | Rejected; not implemented |
| APG `preconditioner != :none` | Rejected; not implemented |

Some rejected keywords remain accepted by *constructors*, at their default
values only, to provide informative errors and compatibility with historical
signatures; the solvers and options do not store them.
Do not interpret their presence as available functionality.
CD's `kkt_checks=0` is a placeholder, and so is `gap=NaN`, except that a
certified square-root lasso run of `CDSolver` reports its certified bound in `gap`.

## About previous versions

The registered package and historical `legacy/full` branch may expose
features that this development branch intentionally does not. These
are different development stages; this documentation **does not provide
a migration procedure** for every historical algorithm. Consult
[Getting started](getting-started.md) for source installation.

See [Numerical behavior](numerics.md) for stopping and precision.
Detailed implementation, failure transaction and internal algorithm
contracts are preserved under
[Contributor implementation notes](developer/implementation-notes.md).

