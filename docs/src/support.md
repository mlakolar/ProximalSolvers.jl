# Supported problems

This page describes **the current GitHub development master branch**, not
the wider feature set in historical releases.

## What works today?

The supported objectives are a least-squares lasso and a centered squared norm with L1 penalty:

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_1,
~~~

where `s=1` for raw `LeastSquaresLoss` or `s=1/n` for the
usual normalized convention. Additionally, `SqrNormL2(α, y)` supports
`α‖β-y‖²/2 + λ‖β‖₁` without constructing an identity design matrix.
The centered squared norm currently requires an explicitly supplied finite
`Vector{T}` center and a positive, finite, representable `α`;
`SqrNormL2(α)` without a center is deferred.

| Input | Supported |
| --- | --- |
| Design matrix `X` | For `LeastSquaresLoss`: nonempty, finite, dense `Matrix{Float32}` or `Matrix{Float64}`; no design matrix for `SqrNormL2` |
| Response `y` | Finite `Vector{T}`; match `size(X,1)` for least squares, `length(β)` for centered squared norm |
| Coefficients `beta` | Same-type dense vector for CD, PGD or APG; alternatively, one-dimensional ProximalBase `SparseIterate` for CD only |
| Loss | `LeastSquaresLoss`, one finite positive scalar multiple of it, or centered `SqrNormL2(α, y)` with `α > 0` |
| Penalty | Unweighted `NormL1(lambda)` with nonnegative finite `lambda` |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`) |

For least squares, the three numerical arrays use one common `T` (`Float32` or
`Float64`); mixed-element-type `X`, `y` and coefficient arrays
are not supported. The penalty level must be finite, nonnegative and
representable in `T` without overflow or rounding a nonzero scalar
to zero; it may be supplied in a different scalar type, including
a representable `Float64` literal in a `Float32` problem.

The loss scale of `Scaled(LeastSquaresLoss(...), s)`, and similarly the
positive level of `SqrNormL2(α, y)`, is supported as

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

The data and any squared-norm center must not be modified while a solve is
running. The coefficient
vector (or the supported CD `SparseIterate`) is mutated in place, so do
not alias it to `X` or `y`. To retain a result, save `copy(beta)`.
See [Numerical behavior](numerics.md) for numerical recovery limits,
solver stopping and diagnostics.

For an executable complete example, see [Getting started](getting-started.md).
The [sparse covariance soft-thresholding example](examples/06_sparse_covariance_soft_thresholding.md)
uses `SqrNormL2` directly on off-diagonal entries without allocating an identity
design. It is a teaching example, not a generic covariance solver, and does
not enforce positive semidefiniteness.
For using sparse **coefficients**, see the
[sparsity tutorial](sparsity-and-kkt.md). The design matrix still must be
dense, even when the coefficients use `SparseIterate`.

## What is not supported yet?

The current development core intentionally excludes the following:

| Feature | Current status |
| --- | --- |
| Sparse design matrices; sparse or view-based dense coefficients | Deferred |
| Generalized losses, matrix responses, intercepts/offsets | Deferred |
| Weighted or group penalties, generalized penalty combinations | Deferred |
| Penalty paths, screening and dual-gap certificates | Deferred |
| ADMM, Newton, monotone or active-set accelerated gradient, primal-dual, SLOPE, graphical models | Deferred |
| Generic workspaces, refitting, reweighting | Deferred |
| PGD or APG with `SparseIterate` coefficients | Deferred |
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

