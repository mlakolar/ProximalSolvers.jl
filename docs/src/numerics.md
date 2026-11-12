# Numerical behavior

This page explains what a successful solve does **and does not** promise.
You can start using the package without understanding its internal algorithm
code.

## What does converged mean?

- **Coordinate descent (CD):** the change during a full pass has fallen
  below the effective `tol`. With `relative=true` this threshold is
  scaled by a response-dependent quantity; the reported effective
  tolerance can differ from the value passed to the constructor.
- **Proximal gradient descent (PGD):** the algorithm applies multiple
  stopping tests for relative coefficient change, objective change and
  a gradient/proximal residual. These combine by **OR**: passing one can
  stop the algorithm, even if the others remain large.
- **Accelerated proximal gradient (APG):** the same three tests and the
  same objective-increase stop as PGD. Its gradient/proximal residual is
  `L ‖x - y‖∞`, measured from the extrapolated point `y` rather than from
  the previous iterate, so it is a stopping quantity, not a KKT residual at `x`.

Neither `converged=true` is a certificate of mathematical optimality.
**On the small tutorial examples, default PGD typically produces only about
3–4 correct digits even if it reports `converged=true`.** This is not
a bound or expected accuracy on arbitrary problems. Tighten tolerances
for results you intend to report, then compute the
[independent KKT residual](sparsity-and-kkt.md). The
[Concepts](concepts.md) and [Getting started](getting-started.md)
pages display that residual next to the default-PGD convergence flag.
PGD's printed `|g(x)|` label is an internal stopping residual, **not**
the value of the user's L1 penalty.

## Working precision: Float32 and Float64

A supported solve uses a single floating-point working type
`T = Float32` or `T = Float64` for the design matrix `X`, response
vector `y`, and coefficient iterate. `CDSolver` accepts either a
dense `Vector{T}` or a one-dimensional `SparseIterate` of `T`;
`ProximalGradientDescent` and `AccProxGradDescent` accept only a dense `Vector{T}`.
Mixed-precision arrays, such as `Float32` coefficients with a
`Float64` design, are rejected. This is stricter than ProximalBase
function dispatch, which may permit some heterogeneous calls without
guaranteeing their numerical behavior.

**Scalar-parameter exception.** The loss scale in
`Scaled(LeastSquaresLoss(...), s)` and the `NormL1` penalty level
`lambda` may be finite real scalars of a different type, including
a `Float64` literal for a `Float32` solve. The solver checks that
they are representable in `T` without overflow or loss of a
nonzero parameter to zero. This convenience does **not** enable a
general mixed-precision model or guarantee that every intermediate
operation uses `T`. Prefer explicit native scalars:

```julia
T = Float32
s = one(T) / T(n)
lambda = T(0.1)
f = s * LeastSquaresLoss(y, X)
g = NormL1(lambda)
```

All supplied `X`, `y` and coefficient entries must be finite.
Finite inputs do not guarantee finite intermediate arithmetic. The
ProximalBase mathematical kernels use selective overflow/underflow
recovery for some representable results, but ProximalSolvers does not
promise end-to-end recovery of every failed matrix product, curvature,
step or objective. Unrecoverable numerical failures are handled as
described below; a successful kernel recovery does not imply the
solver can continue in every extreme-range case.

`Float32` has less precision and may stagnate earlier than `Float64`.
Some solver tolerances, residual reports and other scalar diagnostics
are stored as `Float64` even when the iterate is `Float32`;
this is bookkeeping, **not** higher-precision optimization or an
accuracy certificate. In particular, a tolerance tighter than the
working precision does not guarantee corresponding coefficient
accuracy. Assess the returned result with an
[independent KKT residual](sparsity-and-kkt.md), rather than relying
only on `converged`.

## Results and failures

- CD on dense coefficients calculates on private storage, avoiding a
  partially written dense result if a numerical failure occurs.
- CD on a `SparseIterate` uses a **private copy** and commits the final
  set of active coordinates only after finite completion. This means
  the original coefficient storage is unchanged if the numerical
  solve fails. A pass can remove zeros from the active list and
  change the order of stored coordinates. The RNG can still advance.
- PGD uses in-place dense arrays, and restores the **last accepted**
  iterate if a numerical step fails. Its counters and other internals
  are not transactional.
- APG does the same. Its backtracking raises an error, after which the last
  accepted iterate is restored, when the next curvature estimate `L/β` is not a
  finite increase; a trial whose objective is not finite is never accepted.
  An extrapolated point whose objective or gradient is not finite restarts the
  momentum. Its line search compares the exact least-squares Taylor remainder,
  computed from cached images `X y` and `X x`, with `L ‖x - y‖² / 2`, so it does
  not subtract nearly equal objective values.
- Reaching a pass or iteration limit is not convergence. CD can return
  a finite nonconverged solution with a warning.

Gap certificates are not implemented: `gap=NaN` is a placeholder.
For more precise treatment of exceptional arithmetic, compaction,
momentum, callbacks and test provenance, consult the
[technical contract notes](developer/implementation-notes.md).

Continue with [Results and troubleshooting](working-with-results.md)
or the [Glossary](glossary.md).

