# Supported problems

This page describes **the current GitHub development master branch**, not
the wider feature set in historical releases.

## What works today?

The supported objective is a lasso (CD also solves a group lasso on a `BlockIterate` and a
square-root lasso, below):

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

with `ElasticNet(lambda1, lambda2)`. In the normal range, `CDSolver` takes the coordinate step of a visit from
ProximalBase's `prox_block` of the penalty; out of range, the step of a visit with `lambda2 = 0` is the lasso's
range-safe form and a visit with `lambda2 > 0` is refused (see [the numerical guide](numerics.md)). Its `converged` is the change test, not a KKT
certificate.

| Input | Supported |
| --- | --- |
| Design matrix `X` | Nonempty, finite, dense `Matrix{Float32}` or `Matrix{Float64}` |
| Response `y` | Finite vector with the same element type and `length(y) == size(X,1)` |
| Coefficients `beta` | Same-type dense vector for CD, PGD or APG; alternatively, one-dimensional ProximalBase `SparseIterate` for CD only |
| Loss | `LeastSquaresLoss` or one finite positive scalar multiple of it; for `CDSolver` on a dense vector or a `SparseIterate`, also ProximalBase's `SqrtLeastSquaresLoss` (unscaled; see below) |
| Penalty | With the least-squares loss, `NormL1(lambda)` or `NormL1(lambda, w)` with nonnegative finite `lambda` and, for `w`, a `Vector{T}` of finite nonnegative weights (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`); an unweighted `NormL1(lambda)` with positive `lambda` with `SqrtLeastSquaresLoss`; unweighted `ElasticNet(lambda1, lambda2)` with nonnegative finite levels (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`, with the least-squares loss; with CD and `lambda2 > 0`, a coordinate step outside the normal range is refused, see [the numerical guide](numerics.md)) |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`) |
| Group lasso | `CDSolver` only, with a ProximalBase `BlockIterate{Float32}` or `BlockIterate{Float64}` as the coefficients and a `GroupNormL2{Float32}` or `GroupNormL2{Float64}` penalty, on the same dense least-squares loss (see below) |

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
weights, are refused. [Example 8](examples/08_weighted_lasso.md) solves an adaptive lasso with a zero weight with all
three solvers.

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

### Square-root lasso with coordinate descent

~~~math
\min_\beta\quad P(\beta) = \|y-X\beta\|_2+\lambda\|\beta\|_1
~~~

with ProximalBase's [`SqrtLeastSquaresLoss(y, X)`](https://mlakolar.github.io/ProximalBase.jl/dev/)
(the loss is unnormalized) and `NormL1(lambda)`. `solve!(x, f, g, CDSolver(...))` accepts this problem
when `x` is a dense `Vector{T}` or a one-dimensional `SparseIterate{T}`, `X` and `y` are as above, and
`lambda` is positive, finite and representable in `T`. The normalized objective
`‖y − Xβ‖₂/√n + λₙ‖β‖₁` (`Scaled(f, inv(sqrt(n)))` in ProximalBase) has the same minimizers as `P` at
`lambda = sqrt(n) * λₙ`, and its values are those of `P` divided by `√n`; for the scaled lasso, the noise
estimate at the solution is `norm(y - X*beta)/sqrt(n)`. Refused with an `ArgumentError`, before `x` is
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
[The square-root lasso example](examples/09_square_root_lasso.md) solves a seeded problem, checks it
independently from the data, and shows two exact fits.

The three numerical arrays use one common `T` (`Float32` or
`Float64`); mixed-element-type `X`, `y` and coefficient arrays
are not supported. The penalty levels must be finite, nonnegative and
representable in `T` without overflow or rounding a nonzero scalar
to zero; it may be supplied in a different scalar type, including
a representable `Float64` literal in a `Float32` problem.

The loss scale of `Scaled(LeastSquaresLoss(...), s)` is supported as

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
error message suggests this conversion when it passes that rule.
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
| Generalized losses, matrix responses, intercepts/offsets | Deferred |
| Group penalties other than `GroupNormL2` with `CDSolver` on a `BlockIterate`, weighted `ElasticNet`, `Scaled` penalties (including `Scaled(NormL1)` and `Scaled(ElasticNet)`), generalized penalty combinations | Deferred |
| Observation weights; infinite penalty weights; penalty weights that are not a `Vector{T}` of the type of the data | Deferred; the penalty weights are refused with an `ArgumentError` |
| Penalty paths and screening; dual-gap certificates other than the one of the square-root lasso with `CDSolver` | Deferred |
| Weighted square-root lasso, `Scaled(SqrtLeastSquaresLoss)`, `SqrtLeastSquaresLoss` with an `ElasticNet` or a `BlockIterate`, or with PGD or APG | Refused with an `ArgumentError` (weights and `Scaled` deferred) |
| ADMM, Newton, monotone or active-set accelerated gradient, primal-dual, SLOPE, graphical models | Deferred |
| Generic workspaces, refitting, reweighting | Deferred |
| PGD or APG with `SparseIterate` coefficients | Deferred |
| PGD or APG with `BlockIterate` coefficients or a `GroupNormL2` penalty | Deferred; refused with an `ArgumentError` |
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

