# Supported problems

This page describes **the current GitHub development master branch**, not
the wider feature set in historical releases.

## What works today?

The supported objective is a lasso:

~~~math
\min_\beta\quad \frac{s}{2}\|y-X\beta\|_2^2+\lambda\|\beta\|_1,
~~~

where `s=1` for raw `LeastSquaresLoss` or `s=1/n` for the
usual normalized convention.

| Input | Supported |
| --- | --- |
| Design matrix `X` | Nonempty, finite, dense `Matrix{Float32}` or `Matrix{Float64}` |
| Response `y` | Finite vector with the same element type and `length(y) == size(X,1)` |
| Coefficients `beta` | Same-type dense vector for CD, PGD or APG; alternatively, one-dimensional ProximalBase `SparseIterate` for CD only |
| Loss | `LeastSquaresLoss` or one finite positive scalar multiple of it |
| Penalty | Unweighted `NormL1(lambda)` with nonnegative finite `lambda` |
| Solvers | `CDSolver`, `ProximalGradientDescent`, `AccProxGradDescent` (APG also needs `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 2 < 1/(4 eps(Float64))`) |

The three numerical arrays use one common `T` (`Float32` or
`Float64`); mixed-element-type `X`, `y` and coefficient arrays
are not supported. The finite loss scale and penalty level must be
representable in `T` without overflow or rounding a nonzero scalar
to zero. They may be supplied in a different scalar type, including
a representable `Float64` literal in a `Float32` problem; this
narrow convenience does not imply mixed-precision array support or
a guarantee about every intermediate arithmetic type.

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
| Weighted or group penalties, generalized penalty combinations | Deferred |
| Penalty paths, screening and dual-gap certificates | Deferred |
| ADMM, Newton, monotone or active-set accelerated gradient, primal-dual, SLOPE, graphical models | Deferred |
| Generic workspaces, refitting, reweighting | Deferred |
| PGD or APG with `SparseIterate` coefficients | Deferred |
| CD `anderson>0`, `gaptol>0`, `gapsafe=true` | Rejected; not implemented |
| PGD `normalized=true`, `debias>0`, `preconditioner != :none` | Rejected; not implemented |
| APG `preconditioner != :none` | Rejected; not implemented |

Some rejected keywords remain accepted by *constructors* only to
provide informative errors and compatibility with historical signatures.
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

