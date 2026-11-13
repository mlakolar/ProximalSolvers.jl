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

### PGD stops when the computed objective increases

With the default `allow_f_increases=false` in `ProximalOptions`, PGD has
one more exit, which is not a convergence test: it stops at the first
iteration whose computed objective `F = f(x) + g(x)`, evaluated in the
working precision, is larger than the previous iteration's `F'`. Such a
stop does **not** mean the solve converged.

At the iteration where PGD stops, for whatever reason, the result's flags
are evaluated as follows:

| Field | Value at that iteration |
| --- | --- |
| `x_converged` | `norm(x - x') < xtol * max(norm(x), 1)` |
| `f_converged` | `abs(F - F') / (abs(F) + ftol) < ftol`, **or** `abs(F - F') < eps(abs(F) + abs(F'))` (about two units in the last place of `F`) |
| `grad_converged` | the gradient/proximal residual test with `gradtol` holds |
| `converged` | at least one of `x_converged`, `f_converged` and `grad_converged` |
| `f_increased` | `F > F'` |
| `iteration_converged` | `iterations == maxiter` |

So an objective-increase stop reports `f_increased=true` together with
`converged=false`, unless one of the three tests also held at that
iteration. Two other combinations are possible and not contradictory:

- An increase smaller than about two units in the last place of `F`
  passes the objective test, so the result reports `converged=true`
  **and** `f_increased=true`.
- A test that succeeds at the last allowed iteration reports
  `converged=true` **and** `iteration_converged=true`. An
  objective-increase stop at that iteration also has
  `iteration_converged=true`.

With `allow_f_increases=true` this exit is removed: the solve continues
until a test holds or a limit is reached, and `f_increased` only reports
the comparison at the last iteration.

**Why rounding triggers it.** For the supported least-squares lasso, with
the backtracking line search's default `Lexact = Inf`, an accepted step
does not increase the objective in exact arithmetic. A computed increase
comes from floating-point rounding. Near a minimizer, the true change in
`F` per step becomes smaller than the rounding error of evaluating `F`
in the working precision (which depends on the data; on a small test
problem of this package, a first-order bound is about 16 `eps(T)`
relative), so the sign of the computed change is decided by rounding.
At strict tolerances, whether a solve that has reached the neighborhood
of a minimizer ends with `converged=true` or with an objective-increase
stop can therefore depend on the last bits of the trajectory rather than
on the accuracy of the point. Those bits can change with the
starting point, the CPU and its vector width, the BLAS kernel, and how the
code is compiled (for example, with coverage instrumentation). It
matters mainly for tolerances near or beyond the working precision, and
the package's tests see it most often with `Float32`. In both directions, assess the returned point with the
[independent KKT residual](sparsity-and-kkt.md), not with `converged`
alone.

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
  Its backtracking line search decides each trial with TFOCS's local
  curvature estimate `L̂`, from function values and later from gradients
  (see `LineSearches.BackTracking`). Near a minimizer, rounding of
  `f(x) - q(x)` or of the difference of two gradients can inflate `L̂` by
  orders of magnitude, which would shrink the step until `x` stops moving.
  So a rejection of a trial with a step `d = x - x'` is checked with the
  least-squares bound that APG certifies (below):
  `√α ‖X d‖ ≤ (1 + 4eps) √L ‖d‖` while the search uses function values, and
  the same with `2α`, TFOCS's gradient test `2α ‖X d‖² ≤ L ‖d‖²`, once it
  uses gradients. The check uses the cached images `X x` and `X x'`, and a
  freshly computed `X d` when they leave the decision open or bound `U`
  (below) loosely, with APG's error bounds and assumptions. A rejection is
  not checked, and keeps TFOCS's update, when the trial value is not
  finite, when the computed `‖d̂‖²` is zero (the zero-step exit, which
  includes a tiny nonzero step whose square underflows), when `L̂` is NaN,
  when a gradient estimate comes from a gradient with a nonfinite entry, or
  on the size-limit branch below. A rejection that the bound refutes was
  decided by rounding or lies within the slack `(1 + 4eps)²` on `L`: the
  trial is accepted, and the search uses gradients for the rest of the
  solve. Otherwise the search retries with
  `L ← min(Lexact, max(min(L̂, U), L/β))`, where `U` is a certified upper
  bound on the `L` that the bound needs for that step. Unless the rounding
  or underflow terms of the bounds dominate (a step nearly in the null space
  of `X`, or deep-subnormal data), `U` is at most about 1.07 times
  `m α ‖X d‖²/‖d‖²`, with `m = 1` for function values and `m = 2` for
  gradients, so an `L̂` above `U` does not set `L`. Accepted trials
  are not checked: a trial that a rounding-decided `L̂` accepts below the
  curvature stays accepted. For a curvature above `floatmax(T)` the check
  certifies no `L`, and a search whose trials TFOCS's estimate also rejects
  ends in an error with the last accepted iterate restored; for data deep in
  the subnormal range, where the underflow terms can dominate the bounds, a
  step may need `L` far above the curvature, or the search may end in the
  same error. Problems with `max(n, p) + 4 ≥ 1/(4 eps(T))` or
  `n p + 3 ≥ 1/(4 eps(Float64))` are not refused (APG refuses them): their
  rejections are not checked, keep TFOCS's decision and do not get this
  protection.
  With `ftol > 0` and `allow_f_increases = false`, a solve whose inflated
  `L` used to make the step round to zero, so that the coefficient test
  reported `converged = true`, can instead reach the rounding regime of
  the objective and end on an objective-increase stop
  (`f_increased = true`); see "Why rounding triggers it" in
  [PGD stops when the computed objective increases](@ref).
- APG handles a failed step in the same way. Its backtracking raises an error, after which the last
  accepted iterate is restored, when the next curvature estimate `L/β` is not a
  finite increase; a trial whose objective is not finite is never accepted.
  An extrapolated point whose objective or gradient is not finite restarts the
  momentum when the step uses momentum; without momentum the step fails, with the
  same rollback. Its line search accepts a step only when the least-squares bound
  `√α ‖X(x - y)‖ ≤ (1 + 4eps) √L ‖x - y‖` is certified by conservative
  floating-point error bounds for the stored `x` and `y`, so it does not subtract
  nearly equal objective values and does not accept a step whose bound check is
  dominated by rounding. It first uses the difference of the cached images `X x`
  and `X y`, whose error is bounded through `‖X‖_F` and the iterate norms; when
  that bound leaves the decision open it computes `X(x - y)` afresh, one extra
  matrix-vector product whose error bound is a relative term proportional to the
  step plus an absolute underflow term, and rejects a step that is still undecided.
  The norms and the bound arithmetic are carried as significand and binary
  exponent, so they do not overflow or round to subnormal values in `T`; the native
  products and their underflow enter only through the bounds. A curvature above
  `floatmax(T)` is never certified, so backtracking then ends in its error with
  rollback. These bounds assume IEEE arithmetic with gradual underflow and a
  matrix-vector product evaluated as dot products; the native products and the
  extrapolation are computed in `T` and enter only through the bounds. The extra
  product is needed more often in Float32, where the bounds are wider relative to
  small late steps; for data deep in the subnormal range, where the underflow terms
  can dominate the bounds, a step may need `L` far above the curvature, or the solve
  may fail with rollback. APG also
  requires `max(n, p) + 4 < 1/(4 eps(T))` and `n p + 3 < 1/(4 eps(Float64))`; larger
  problems are refused before `x` is modified.
- Reaching a pass or iteration limit is not convergence. CD can return
  a finite nonconverged solution with a warning.

Gap certificates are not implemented: `gap=NaN` is a placeholder.
For more precise treatment of exceptional arithmetic, compaction,
momentum, callbacks and test provenance, consult the
[technical contract notes](developer/implementation-notes.md).

Continue with [Results and troubleshooting](working-with-results.md)
or the [Glossary](glossary.md).

