# Supported problems

This page describes **the current GitHub development master branch**, not
the wider feature set in historical releases.

## What works today?

The supported objective is a lasso (CD also solves a group lasso on a `BlockIterate`, below):

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_1,
~~~

where `s=1` for raw `LeastSquaresLoss` or `s=1/n` for the
usual normalized convention. `CDSolver`, `ProximalGradientDescent` and `AccProxGradDescent` also solve the
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
| Loss | `LeastSquaresLoss` or one finite positive scalar multiple of it |
| Penalty | Unweighted `NormL1(lambda)` with nonnegative finite `lambda` (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`); unweighted `ElasticNet(lambda1, lambda2)` with nonnegative finite levels (CD, PGD and APG on a dense vector, and CD on a `SparseIterate`; with CD and `lambda2 > 0`, a coordinate step outside the normal range is refused, see [the numerical guide](numerics.md)) |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`) |
| Group lasso | `CDSolver` only, with a ProximalBase `BlockIterate{Float32}` or `BlockIterate{Float64}` as the coefficients and a `GroupNormL2{Float32}` or `GroupNormL2{Float64}` penalty, on the same dense least-squares loss (see below) |

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
| Weighted `NormL1`, group penalties other than `GroupNormL2` with `CDSolver` on a `BlockIterate`, weighted `ElasticNet`, `Scaled(ElasticNet)`, generalized penalty combinations | Deferred |
| Penalty paths, screening and dual-gap certificates | Deferred |
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
The reported `gap=NaN` and CD's `kkt_checks=0` are placeholders, not
computed certificates.

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

