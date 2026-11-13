# Numerical behavior

This page explains what a successful solve does **and does not** promise.
You can start using the package without understanding its internal algorithm
code.

## What does converged mean?

- **Coordinate descent (CD):** the change during a full pass has fallen
  below the effective `tol`. With `relative=true` this threshold is
  scaled by a response-dependent quantity, `sqrt(s * sum(abs2, y))`, formed
  so that the sum of squares and its product with the loss scale `s` may
  leave the range of the working type; the reported effective
  tolerance can differ from the value passed to the constructor. When
  relative scaling is active (`relative=true` and a positive response scale),
  each coordinate change is also multiplied by `sqrt(s * a)` for the squared
  norm `a` of its column, formed from the two square roots where the product
  `s * a` is zero or subnormal; where it overflows the scale is infinite and a
  nonzero change is then refused with an `ArgumentError` (that overflow is
  issue #294). With `relative=false`, or with `y = 0`, the coordinate scale is
  not used. If the computed `sqrt(s) * norm(y)`, after
  rounding to the working type, is not a normal floating-point number, the
  solve is refused with an `ArgumentError` before the first pass (rescale, or
  use `relative=false`, which can still end in the `nonfinite objective`
  refusal described below); a value within a rounding error of the limits can
  fall on either side. `y = 0` uses the absolute threshold. `tol` times a
  normal scale can be subnormal or 0; the test `change < threshold` cannot hold
  for a threshold of 0, so such a run cannot converge by it and ends at
  `maxpasses` with a warning, unless an independent numerical failure (for
  example a non-finite coordinate step) stops it first with an error.
- **Proximal gradient descent (PGD):** the algorithm applies multiple
  stopping tests for relative coefficient change, objective change and
  a gradient/proximal residual. These combine by **OR**: passing one can
  stop the algorithm, even if the others remain large. `ftol = 0` switches
  the objective-change test off (see [Strict accuracy](#Strict-accuracy)).
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
| `x_converged` | `norm(x - x') < xtol * max(norm(x), 1)`; with `ftol = 0`, `false` when `x == x'` elementwise |
| `f_converged` | with `ftol > 0`: `abs(F - F') / (abs(F) + ftol) < ftol`, **or** `abs(F - F') < eps(abs(F) + abs(F'))` (this form holds when `F == F'` and the sum is finite, and in the ordinary range, where `F` and `F'` are normal floating-point numbers and the sum is finite, it is about two units in the last place of `F`); with `ftol = 0`: `false` |
| `grad_converged` | the gradient/proximal residual test with `gradtol` holds; with `ftol = 0`, `false` when `x == x'` elementwise |
| `converged` | at least one of `x_converged`, `f_converged` and `grad_converged` |
| `f_increased` | `F > F'` |
| `iteration_converged` | `iterations == maxiter` |

So an objective-increase stop reports `f_increased=true` together with
`converged=false`, unless one of the three tests also held at that
iteration. Two other combinations are possible and not contradictory:

- With `ftol > 0`, in the ordinary range (`F` and `F'` normal floating-point
  numbers, `abs(F) + abs(F')` finite), an increase smaller than about two units
  in the last place of `F` passes the objective test, so the result reports
  `converged=true` **and** `f_increased=true`. With `ftol = 0` the objective
  test is off, so an increase of any size reports `converged=false` unless the
  `x` or the gradient test held.
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

### Strict accuracy

With `ftol > 0`, including the default `1e-6`, the objective-change test
also holds when two successive computed objectives are equal or, in the
ordinary range (both normal floating-point numbers, `abs(F) + abs(F')` finite),
differ by about two units in the last place. That can happen well before the point is
accurate to the working precision. `ProximalOptions(ftol = 0)` switches the
objective-change test off for `ProximalGradientDescent` and
`AccProxGradDescent`: `f_converged` is `false` at every iteration. The
objective-increase stop and the iteration limit are unchanged. So are the `x`
and gradient tests, except that under `ftol = 0` an iteration whose accepted
iterate equals the previous one elementwise sets neither `x_converged` nor
`grad_converged` (see "An exact stall" below).
`ftol` must be finite and nonnegative; a positive `ftol` that rounds to `0` in
`Float64` is refused, so that a tiny positive value does not silently switch
the test off.

This combination is a **test configuration**, not a general recipe:

```julia
ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true,
                xtol = 1e-300, gradtol = 1e-11)
```

On the package's benchmark cases (Float64 PGD and APG, Float32 APG, with 10
input draws each, on Julia 1.10 and 1.13 and two CPU models) it met the
independently computed targets of a relative duality gap of `1e-8` in Float64
and `1e-5` in Float32. It is **not** a guarantee of accuracy on other problems,
and `converged=true` is still not a certificate: check the returned point
independently, for example with the bound below. With this configuration
Float32 PGD reached its floating-point fixed point and met the independent
`1e-5` target on the benchmark cases (in these probes, with `maxiter = 10000`;
10 input draws each, on Julia 1.10 and 1.13, one CPU model), but it ran to
`maxiter` with `converged=false`. At an iteration whose accepted iterate is
unchanged, the computed `x` and gradient tests can hold (the computed gradient
residual can be exactly `0`), but under `ftol = 0` the exact-stall rule (see
"An exact stall" below) does not count them; between such iterations the
iterate can still move. Its run time therefore measures the iteration limit.
The computed residual is not an accuracy measure: the `1e-5` target was
checked with the independent duality gap.

- **`allow_f_increases = true`.** With the objective test off, a computed
  increase of `F` still ends the solve under the default
  `allow_f_increases=false`, and reports `converged=false` unless the `x` or
  gradient test held. Near a minimizer such increases can be at the level of
  rounding (see above). In the benchmark probes, switching off the objective
  tests alone ended most solves at an increase, and the configuration above,
  which met the targets in those probes, enables increases.
- **`xtol` is not an accuracy criterion for PGD.** PGD's step is scaled by
  `1/L`, where `L` is the inverse step size, so the test
  `norm(x - x') < xtol * max(norm(x), 1)` bounds the proximal-gradient residual
  by about `L * xtol * max(norm(x), 1)`, which depends on `L`, on the scale of
  `x` and on the penalty level `λ`, not on an accuracy target. In the benchmark
  probes with `xtol = 1e-14`, one Float64 PGD draw (on Julia 1.10) missed the
  target, and it ended on the `x` test. `xtol = 1e-300` lets that test hold
  only for steps of norm below `1e-300 * max(norm(x), 1)`, which still includes
  a nonzero step that small (for example `x = [1e-310]` after
  `x_previous = [0.0]`). In the benchmark probes with these tolerances, all
  Float64 solves ended on the gradient test.
- **An exact stall under `ftol = 0`.** An iteration whose accepted iterate
  equals the previous one elementwise (by value) is no progress, not
  convergence: it sets neither `x_converged` nor `grad_converged`, and the
  solve continues, subject to the other tests, the limits and, with
  `allow_f_increases=false`, the objective-increase stop. With `ftol > 0` such
  an iteration passes the `x` test. A stall can end when the step size `1/L`
  or, for APG, the extrapolated point changes from one iteration to the next;
  they need not change (for example with a zero step or `α = 1`). A solve that
  stays at an unchanged iterate until `maxiter` ends with `converged=false` and
  `iteration_converged=true`; that reports no progress, not that the point is
  wrong (for `x = 0` with a penalty level at or above `norm(∇f(0), Inf)`, the
  point is the solution). For `AccProxGradDescent`, an extrapolated point `y`
  equal to `x` while `x` differs from the previous iterate is not a stall: its
  residual `L * maximum(abs, x - y)` is `0`, so the gradient test holds when
  `gradtol > 0`.

**A check of a lasso solution.** Let `f(x) = s‖y - Xx‖²/2` with `s > 0` and
`g(x) = λ‖x‖₁` with `λ > 0` (an unweighted `NormL1`), let `F = f + g`, and let
`G` be the element of `∇f(x) + λ ∂‖x‖₁` of smallest infinity norm, which is the
[independent KKT residual](sparsity-and-kkt.md). Put `k = norm(G, Inf) / λ`.
With the dual point `θ = κ s (y - Xx)`, where
`κ = min(1, λ / norm(∇f(x), Inf))` and `κ = 1` when `∇f(x) = 0`, and
`D(θ) = ⟨θ, y⟩ - ‖θ‖²/(2s)`, the relative duality gap satisfies

~~~math
\frac{F(x) - D(\theta)}{F(x)} \le 2k + k^2
~~~

**in exact arithmetic**, for `s > 0`, `λ > 0` and `F(x) > 0`. This follows from
`F(x) - D(θ) = (1-κ)² f(x) + (1-κ) λ‖x‖₁ + κ⟨G, x⟩`, `1 - κ ≤ k` and
`F ≥ max(f, λ‖x‖₁)`. Evaluating `k` in `Float64` from the returned `x` is an
independent numerical check, **not** a rigorous floating-point certificate: the
rounding errors of that evaluation are not bounded here.

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
nonzero parameter to zero. After that check, CD, PGD and APG use the
loss scale as supplied, combined with `T` by Julia's promotion (CD
converts a scale to `T` when that promotion is not a concrete
floating-point type, such as a custom `Real` without promotion rules): a
`Float64` scale in a `Float32` solve keeps its `Float64` value (also
where that value is subnormal in `Float32`). In CD, the coordinate step,
the two stopping scales and the reported objective are formed from that
value and rounded to `T` where they enter the iterate, the tolerance or
the result; an `Int`, `Rational{Int}`, `Irrational`, `Bool` or `Float16`
scale is used there as `T(s)`. A `BigFloat`, `BigInt` or
`Rational{BigInt}` loss scale makes the scalar arithmetic of CD that involves
it (the step coefficient, the products of the loss scale in the two
stopping scales, and the reported objective's product) `BigFloat`, at the
precision current when the solve runs; the square roots of the stopping
scales on their normal-range branch are formed in `T`. It allocates
and is slow, and is not a fast path. This convenience does **not**
enable a general mixed-precision model or guarantee that every
intermediate operation uses `T`. Prefer explicit native scalars. Writing
`one(T) / T(n)` chooses a native `T` scale: `n` is converted to `T` and the
division is done in `T`, so the value can differ from the `Float64` `1/n`. The
solve uses that value, and the products with the loss scale are formed in `T`:

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
solver can continue in every extreme-range case. For example, CD forms
its reported objective from the sum of the squared residuals in the working
type, times the loss scale: where that sum or product overflows, CD refuses
the finished solve with a `nonfinite objective` error and leaves the starting
point unchanged; where it underflows, the loss part of the reported minimum
can be 0.

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
  So a rejected trial with a step `d̂ = x - x'` is decided again by the
  computed curvature of the step, `c = m α ‖fl(X d̂)‖²/‖d̂‖²`, from one
  matrix-vector product `X d̂`, with `m = 1` while the search uses function
  values and `m = 2` once it uses gradients (TFOCS's gradient test is
  `2α ‖X d‖² ≤ L ‖d‖²`). The trial is accepted when `L ≥ c`, and the
  search keeps its mode; otherwise it retries with
  `L ← min(Lexact, max(c, L/β))` when `c` is finite, and with TFOCS's
  `L ← min(Lexact, max(L̂, L/β))` when it is not. `c` is a computed value
  with no rounding certificate: when `L` is within rounding of the curvature
  along `d̂`, the decision can go either way, and a step nearly in the null
  space of `X` can have a computed `c` with a large relative error. For
  Float32 data the two squared norms are accumulated in Float64, where the
  square of a finite Float32 is exact, and two allowances are added to
  `‖fl(X d̂)‖` before squaring: `2√n p floatmin(Float32)` for underflow of
  the results, and `√n floatmin(Float32) ‖d̂‖₁` for subnormal entries of `X`
  that a thread flushing subnormals to zero (the calling thread or a BLAS
  thread) drops from the product. They assume that flushing affects only
  subnormal operands and results; they are not a bound on the total error of
  the product, and give no certificate. The curvature value compared with
  `L`, in Float64, is then positive when finite, so a product lost to
  underflow or flushing does not make it zero; the estimate used for a retry
  is that value rounded to Float32, which may round to Inf. TFOCS's update is
  kept when an entry of `fl(X d̂)` overflowed, when the calling thread
  flushes subnormals to zero (`set_zero_subnormals(true)`), and when `d̂` has
  a subnormal entry, which a flushing thread could drop. At ordinary scales
  the allowances are negligible: with round-to-nearest they leave the
  computed norm `w = ‖fl(X d̂)‖` unchanged when their sum is below
  `eps(w)/2`. For Float64 data, over- or
  underflow of `‖fl(X d̂)‖²` or `‖d̂‖²` can make `c` infinite or NaN, which
  keeps TFOCS's update, or spuriously zero, which accepts the trial: with
  extreme scalings, `‖fl(X d̂)‖²` can underflow (or `‖d̂‖²` overflow), so `c`
  can be zero although the true curvature is large. In the
  package's probes (seeded Float32 and Float64 designs, including `p > n`,
  near-duplicate columns, column scales over `10^±3`, residuals orthogonal
  to the range of `X` and warm starts at the optimum), no accepted step
  increased the objective by more than `64 eps(T) |F|`, evaluated in higher
  precision; this is a measurement, not a guarantee. A rejection is not
  checked, and keeps TFOCS's update, when the trial value is not finite,
  when the computed `‖d̂‖²` is zero (the zero-step exit, which includes a
  tiny nonzero step whose square underflows), when `L̂` is NaN, or when a
  gradient estimate comes from a gradient with a nonfinite entry. Each
  checked rejection costs one product `X d̂`. Accepted trials are not
  checked: a trial that a rounding-decided `L̂` accepts below the curvature
  stays accepted. The `Lexact` exit (a finite-valued trial at `L ≥ Lexact`
  is accepted) and the zero-step exit are kept. A search that keeps
  rejecting until `next_curvature` finds no finite increase of `L`, or until
  TFOCS's update gives a nonfinite `L`, ends in an error with the last
  accepted iterate restored; that can happen when the curvature along the
  steps is above `floatmax(T)`, unless TFOCS's estimate, `Lexact` or a zero
  step accepts a trial.
  With `ftol > 0` and `allow_f_increases = false`, a solve whose inflated
  `L` used to make the step round to zero, so that the coefficient test
  reported `converged = true`, can instead reach the rounding regime of
  the objective and end on an objective-increase stop
  (`f_increased = true`); see "Why rounding triggers it" in
  [PGD stops when the computed objective increases](@ref). Under `ftol = 0`
  with the settings of [Strict accuracy](@ref), a Float32 solve can reach its
  floating-point fixed point and, by the exact-stall rule there, run to
  `maxiter` with `converged = false`.
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

