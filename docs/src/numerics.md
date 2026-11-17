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
  `s * a` is zero, subnormal or overflowing for a finite `a`; a nonzero change
  times an infinite scale (a computed scale that overflows the working type) is
  refused with an `ArgumentError`. The coordinate step forms its threshold
  `lambda / (s * a)` without the product or its reciprocal where either is
  outside the normal range, and a column whose squared norm is not finite is
  refused with an `ArgumentError` that names the curvature. For an `ElasticNet`,
  in the normal range the step of a visit is ProximalBase's `prox_block`. At a visit to a column
  with a finite positive `a` where `s * a` or its reciprocal is below `floatmin` of the type that
  combines `s` with the working type, the step with `lambda2 = 0` is the lasso's, and with
  `lambda2 > 0` the visit is refused with an `ArgumentError` that names the coordinate, during the
  pass: the iterate passed to `solve!` is unchanged, and a borrowed RNG may have advanced.
  A visit to a flat column (all entries 0) sets its coordinate to 0 at the levels that `solve!`
  accepts, and a visit to a column that is not flat whose `a` underflows to 0 is refused with an
  `ArgumentError` about the curvature, as for the lasso. With `maxpasses = 0` no coordinate is visited. With
  `relative=false`, or with `y = 0`, the coordinate scale is
  not used. If the computed `sqrt(s) * norm(y)`, after
  rounding to the working type, is not a normal floating-point number, the
  solve is refused with an `ArgumentError` before the first pass (rescale, or
  use `relative=false`, which can still end in the `nonfinite objective`
  refusal described below); a value within a rounding error of the limits can
  fall on either side. `y = 0` uses the absolute threshold. `tol` times a
  normal scale can be subnormal or 0; the test `change < threshold` cannot hold
  for a threshold of 0, so such a run cannot converge by it and ends at
  `maxpasses` with a warning, unless an independent numerical failure (for
  example a non-finite coordinate step) stops it first with an error. Once the
  active passes since the last full pass have together visited 20 times as many
  coordinates as a full pass, the next pass is a full pass even when the active
  changes have not fallen below the threshold. Float32 rounding of the
  coefficients can also keep the largest change of every full pass at or above
  the effective threshold (the reported `tolerance`, against which the change is
  compared after the scaling described above when relative scaling is active);
  the run then ends at `maxpasses` without converging, with the warning. A
  threshold well above that rounding level avoids this; Float64 data has a much
  lower rounding level.
  For a group lasso on a `BlockIterate`, the change is that of a whole group; see
  [Group lasso on a BlockIterate](@ref "Group lasso on a BlockIterate").
- **Proximal gradient descent (PGD):** the algorithm applies multiple
  stopping tests for relative coefficient change, objective change and
  a gradient/proximal residual. These combine by **OR**: any one of them
  can propose a stop, even if the others remain large, and a proposed stop
  counts only if the [stationarity check of a stop](@ref "The stationarity check of a stop") passes. `ftol = 0`
  switches the objective-change test off (see [Strict accuracy](#Strict-accuracy)).
- **Accelerated proximal gradient (APG):** the same three tests and the
  same objective-increase stop as PGD. Its gradient/proximal residual is
  `L ‖x - y‖∞`, measured from the extrapolated point `y` rather than from
  the previous iterate, so it is a stopping quantity, not a KKT residual at `x`.

Neither `converged=true` is a certificate of mathematical optimality. For
PGD and APG it means that a test proposed a stop and that the computed
KKT residual `‖G‖∞` at the returned point is below
`max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λ` the ℓ1 level of the penalty (see [The stationarity check of a stop](@ref "The stationarity check of a stop")); it is a working-precision residual, not an exact-arithmetic
certificate, and it does not bound the distance to a minimizer. The
default `gradtol = 1e-5` is not a specified number of correct digits.
Tighten tolerances for results you intend to report, then compute the
[independent KKT residual](sparsity-and-kkt.md). The
[Concepts](concepts.md) and [Getting started](getting-started.md)
pages display that residual next to the default-PGD convergence flag.
PGD's printed `|g(x)|` label is an internal stopping residual, **not**
the value of the user's L1 penalty.

### The stationarity check of a stop

PGD and APG verify a proposed stop. At an iteration at which the `x`, `f` or
gradient test holds (under `ftol = 0`, after the exact-stall rule below), the
solver computes the minimal-norm KKT residual `G` at the accepted iterate `x`.
For `NormL1(λ)` it is the element of `∇f(x) + λ ∂‖x‖₁` of least infinity
norm, that is `max(|∇fᵢ| - λ, 0)` where `xᵢ = 0` and `|∇fᵢ + λ sign(xᵢ)|`
elsewhere, with `λ = T(λ0)`, the penalty level converted to the coefficient type `T`. For
`ElasticNet(λ1, λ2)` (PGD and APG) it is the element of
`∇f(x) + λ2 x + λ1 ∂‖x‖₁` of least infinity norm: `max(|∇fᵢ| - λ1, 0)` where
`xᵢ = 0` and `|∇fᵢ + λ2 xᵢ + λ1 sign(xᵢ)|` elsewhere, with the levels `T(λ1)` and `T(λ2)`. The solver
computes `‖G‖∞` with ProximalBase's `kkt_violation(NormL1(T(λ0)), ∇f(x), x)` or
`kkt_violation(ElasticNet(T(λ1), T(λ2)), ∇f(x), x)`, passing the converted levels. An infinite entry of `x`
gives a non-finite residual (`Inf`, or `NaN` when a `NaN` is read), so the stop does not count. Below,
`λ` is the ℓ1 level of the penalty (`λ` of `NormL1`, `λ1` of `ElasticNet`). The stop counts only if

~~~
‖G‖∞ < max(gradtol, 64 eps(T)) * max(λ, λmax),    λmax = α ‖Xᵀy‖∞,
~~~

where `T` is the element type of the coefficients and `α` is the loss scale (1 for
a plain `LeastSquaresLoss`). The code forms `τ = T(max(gradtol, 64 eps(T)))` and the
threshold `τ * S` in `T`; the normalized form `‖G‖∞ / S < max(gradtol, 64 eps(T))` is the
exact-arithmetic reading. In working precision the conversion to `T` and the product can
round, or overflow to `Inf` for a huge `gradtol`, and a finite residual then passes against
the infinite threshold.
The check also requires that `S = max(λ, λmax)` is finite, that the product
`max(gradtol, 64 eps(T)) * S`, formed in `T`, is at least `floatmin(T)`, and that `‖G‖∞`
is finite. It does not require that product to be finite: for a huge `gradtol` it can
be `Inf`, and a finite residual then passes. Otherwise `x_converged`, `f_converged` and `grad_converged` are
all reported `false`, so `converged=false`, and the solve continues. The
`f_residual`, `x_residual` and `g_residual` fields still report the quantities
of the tests. What `converged=true` therefore says about the returned `x`:

- The computed residual, from the gradient that the solver forms in working
  precision, is below the bound. It is not an exact-arithmetic certificate,
  because that gradient carries rounding error, and it bounds the KKT
  residual, not the distance to a minimizer.
- The normalized inequality `‖G‖∞ / max(λ, λmax) < max(gradtol, 64 eps(T))` does
  not change when the loss and the penalty are multiplied by the same positive
  factor, in exact arithmetic (the bound `τ S` itself scales with the factor).
  In working precision the outcome can change: the quantities are rounded, and
  the requirement that `τ S` is at least `floatmin(T)` can refuse a stop at a
  scale where `α`, `λ`, `S` and `τ S` are all representable. For example, for
  `Float32` data `X = [1]`, `y = [1]` at `x = 0` with the default `gradtol`, `α = λ = 1` passes and
  `α = λ = 1f-35` does not, because `τ S` is below `floatmin(Float32)`.
- The factor `64 eps(T)` is a floor on the relative residual. A `gradtol` below
  it, including `gradtol = 0`, gives the bound `64 eps(T) max(λ, λmax)`.
- The exit at `x = 0` with `λ ≥ λmax` has `G = 0`. A solve that starts at
  `x = 0` with such a `λ` stops at the first iteration when a test proposes a
  stop there, `S > 0` and `τ S ≥ floatmin(T)`. Under `ftol = 0` an unchanged
  iterate proposes nothing (see "An exact stall" below), so such a solve
  continues, and can end at `maxiter` with `converged=false`.
- Where `λ` and `λmax` are both 0 (for example `y = 0` and `λ = 0`), or where
  the bound is below `floatmin(T)`, no stop passes. The solve then ends at
  `maxiter` unless another exit applies.
- **The elastic net.** `ElasticNet(λ1, λ2)` on the loss `α/2 ‖Xb - y‖²` is the lasso with
  level `λ1` on the augmented data `X̃ = [√α X; √λ2 I]`, `ỹ = [√α y; 0]`: its loss
  `½‖X̃b - ỹ‖²` equals `α/2 ‖Xb - y‖² + (λ2/2)‖b‖²`, its gradient is `∇f(x) + λ2 x`, and its
  `λ̃max = ‖X̃ᵀỹ‖∞ = α‖Xᵀy‖∞` is the `λmax` above. The check with `S = max(λ1, λmax)` is therefore
  the lasso check on those data, and has the same properties: it is covariant under a common
  positive factor on `α`, `λ1` and `λ2` (in exact arithmetic), and it refuses every stop where the
  computed `S = max(T(λ1), λmax)` is 0, with `λmax` as the solver computes it. The scale does not
  contain `λ2` or `λ2‖x‖∞`. With `λ1 = 0` and `y = 0`, the computed `S` is 0 although `x = 0` is the
  ridge solution: no stop counts, and the solve runs to `maxiter` with `converged=false`, as
  `NormL1(0)` does for `y = 0` (unless another exit applies). An exact `Xᵀy = 0` need not give a computed
  `λmax = 0`: in `Float32`, `X = reshape(Float32[2^24, 1, -2^24, -1], 4, 1)` with `y = ones(Float32, 4)` has `Xᵀy = 0`,
  but `2^24 + 1` rounds to `2^24` when the terms are summed in that order, so the computed `λmax` can be 1,
  and the check then works with that rounded value; a stop can then count at a point whose residual for the
  exact data is not small relative to the computed `S`.
  A start `x0` with a finite `f(x0)` is accepted even if `g(x0)` overflows in `T` (for example a ridge term
  `(λ2/2)‖x0‖²` above `floatmax(T)`). An error raised in the step of an iteration (its line search, or the
  check that the accepted objective is finite) restores the last accepted iterate and is rethrown, as for `NormL1`. On a dense `Vector` or a one-dimensional `SparseIterate`, `CDSolver`
  accepts an `ElasticNet` and stops by its change test, as for `NormL1`; this check is not applied there.
- The check bounds the residual relative to `max(λ, λmax)`. A coordinate whose
  gradient is on a scale far below `λmax` can stay inaccurate when the check
  passes: for `X = diag(1e6, 1)`, `y = [1e6, 1]`, `λ = 0` from a cold start with
  the default options, a review run reported convergence after 9 or 10
  iterations with an independent relative KKT residual of a few `1e-6`, while the
  coefficient of the flat column was almost 1 off. `converged=true` is not a
  guarantee of coefficient accuracy.

The check runs only at an iteration at which a test proposes a stop. PGD uses
the gradient `∇f(x)` that it holds. APG holds `∇f(y)` at the extrapolated point,
so it forms `∇f(x)` from its cached product `A x` with the same gradient oracle,
in preallocated buffers: one transposed product per check, counted in
`grad_calls` (and not in `f_calls`). `λmax` is computed once per solve, at the
first check, with one product `Xᵀy` that is not counted.

The gradient test itself has no absolute term. With `r` the gradient/proximal
residual of the iteration, `m` the largest `r` so far in the solve,
`N = max(‖∇f‖∞, ‖s‖∞)`, with `s` the residual of the proximal step (for APG
`∇f(y)` and the step from `y`), and `ρ = L eps(T) ‖x‖∞`, the rounding
resolution of `L x`, the test holds when

~~~
(r < gradtol * m  and  ρ < m)   or   (r < gradtol * N  and  ρ < N).
~~~

The comparisons use the floating-point products `gradtol * m` and `gradtol * N`.
A residual of 0 holds only against a product that is positive: against `m = N = 0`
it does not hold, and neither when a product underflows to 0. A scale below `ρ`
decides nothing. The objective test is `abs(F - F') / abs(F) < ftol` (see the table
below) or the flat form, with no absolute term in the denominator.

With the default options, a solve with `ftol > 0` can stop later than before:
an objective change below `ftol`, or a flat objective, does not count as
convergence while `‖G‖∞` is above the bound, and the solve
can end at `maxiter` with `converged=false`. A `Float32` solve with the default options
can end on the objective-increase exit below, with `converged=false` and
`f_increased=true`, where it used to stop on the objective test: the objective
test proposes the stop, the check refuses it, and the computed objective then
increases by rounding before the residual reaches the bound.

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
| `x_converged` | `norm(x - x') < xtol * max(norm(x), 1)` **and** the [stationarity check](@ref "The stationarity check of a stop") passes; with `ftol = 0`, `false` when `x == x'` elementwise |
| `f_converged` | with `ftol > 0`: `abs(F - F') / abs(F) < ftol` (the quotient is `0` for `F == F'` and `Inf` for `F = 0 ≠ F'`), **or** `abs(F - F') < eps(abs(F) + abs(F'))` (this form holds when `F == F'` and the sum is finite, and in the ordinary range, where `F` and `F'` are normal floating-point numbers and the sum is finite, it is about two units in the last place of `F`), **and** the stationarity check passes; with `ftol = 0`: `false` |
| `grad_converged` | the gradient/proximal residual test with `gradtol` holds (see above) **and** the stationarity check passes; with `ftol = 0`, `false` when `x == x'` elementwise |
| `converged` | at least one of `x_converged`, `f_converged` and `grad_converged`, which are `false` together when the check fails |
| `f_increased` | `F > F'` |
| `iteration_converged` | `iterations == maxiter` |
| `stagnated` | `true` when the stagnation condition of `ProximalGradientDescent` on `Float32` data with `ftol = 0` holds at that iteration (see [Strict accuracy](#Strict-accuracy)); `false` for `AccProxGradDescent`, for `Float64` data and with `ftol > 0`. It can be `true` together with `call_limit_reached`, with `iteration_converged`, or at an iteration at which the callback returned `true` |

So an objective-increase stop reports `f_increased=true` together with
`converged=false`, unless one of the three tests also held at that
iteration. Two other combinations are possible and not contradictory:

- With `ftol > 0`, in the ordinary range (`F` and `F'` normal floating-point
  numbers, `abs(F) + abs(F')` finite), an increase smaller than about two units
  in the last place of `F` passes the objective test. The result then reports
  `converged=true` **and** `f_increased=true` if the stationarity check also
  passes, and `converged=false` with `f_increased=true` if it does not. With
  `ftol = 0` the objective test is off, so an increase of any size reports
  `converged=false` unless the `x` or the gradient test held and the check
  passed.
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
differ by about two units in the last place. That can happen before the point is
accurate to the working precision, and the [stationarity check of a stop](@ref "The stationarity check of a stop")
then decides whether the solve stops. `ProximalOptions(ftol = 0)` switches the
objective-change test off for `ProximalGradientDescent` and
`AccProxGradDescent`: `f_converged` is `false` at every iteration. The
objective-increase stop and the iteration limit are unchanged. So are the `x`
and gradient tests, except that under `ftol = 0` an iteration whose accepted
iterate equals the previous one elementwise sets neither `x_converged` nor
`grad_converged` (see "An exact stall" below). The stationarity check applies
to the remaining tests under `ftol = 0` as well.
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
10 input draws each, on Julia 1.10 and 1.13, one CPU model). With the stagnation
stop (see "A stagnation stop" below), such a solve ends, before `maxiter` on those
cases, at an iteration that meets its condition, with `stagnated=true` and
`converged=false`. At an iteration whose accepted iterate is unchanged, the
computed `x` and gradient tests can hold (the computed gradient residual can be
`0`), but under `ftol = 0` the exact-stall rule (see "An exact stall" below) does
not count them; between such iterations the iterate can still move. The computed
residual is not an accuracy measure: the `1e-5` target was checked with the
independent duality gap.
These probes were made before the stationarity check of a stop was added
(see [The stationarity check of a stop](@ref "The stationarity check of a stop")); they are not repeated here for the current code.

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
  an iteration proposes a stop through the `x` test, and the stationarity
  check decides. A stall can end when the step size `1/L`
  or, for APG, the extrapolated point changes from one iteration to the next;
  they need not change (for example with a zero step or `α = 1`). A solve that
  stays at an unchanged iterate until `maxiter`, with no iteration that meets the
  condition of the next item, ends with `converged=false` and
  `iteration_converged=true`; that reports no progress, not that the point is
  wrong (for `x = 0` with a penalty level at or above `norm(∇f(0), Inf)`, the
  point is the solution). For `AccProxGradDescent`, an extrapolated point `y`
  equal to `x` while `x` differs from the previous iterate is not a stall: its
  residual `L * maximum(abs, x - y)` is `0`, so the gradient test holds when
  `0 < gradtol * N` and `ρ < N`, or `0 < gradtol * m` and `ρ < m` (see
  [The stationarity check of a stop](@ref "The stationarity check of a stop")),
  and the stationarity check then decides.
- **A stagnation stop.** Under `ftol = 0`, `ProximalGradientDescent` on `Float32`
  data stops after an iteration in which both of these hold: the accepted
  iterate equals the previous one elementwise, and the last rejection of that
  iteration's line search was decided by the computed curvature of the rejected
  step, which was finite and replaced the line search's curvature estimate `L̂`
  (the retry's `L` is then `min(Lexact, max(c, L / β))` for the rejected trial's
  `L`, so it need not equal the curvature `c`). The solve ends with
  `stagnated=true` and `converged=false`; `x_converged`, `f_converged` and
  `grad_converged` are `false`, and `iteration_converged` is
  `iterations == maxiter`. The stagnation check comes after tracing and after any
  callback call that is due at that iteration under `print_every`; it does not
  change the callback cadence, and a callback that returns `true` there can
  still stop the solve itself. A rejection that is not checked
  (a trial value that is not finite, a NaN estimate, a gradient estimate from a
  gradient with a nonfinite entry) or whose computed curvature is not finite does
  not count. A later rejection of the same iteration replaces an earlier one, and
  nothing carries over from an earlier iteration. An iteration whose first trial
  is already a zero step has no rejection and does not trigger the stagnation
  stop (other stops, such as a callback or a limit, still apply); this happens,
  for example, while `L` is so large that the first trial step rounds to a zero
  step, and at `x = 0` with a penalty level at or above `norm(∇f(0), Inf)`. An
  iteration whose accepted iterate differs from the previous one in any entry
  does not trigger it either, so a solve that keeps moving by rounding error,
  with no unchanged iterate, is ended by another stop or by `maxiter`.
  `stagnated=true` is **not** a convergence or accuracy certificate: the point
  can be inaccurate (a nearly interpolating problem with a small penalty level
  can stall with a duality gap above the `1e-5` target), and the iterate could
  still move at a later iteration if the solve continued. For `Float64` data, for
  `AccProxGradDescent` and with `ftol > 0`, `stagnated` is `false`.

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

## Group lasso on a BlockIterate

`CDSolver` accepts a `BlockIterate{T}` with a `GroupNormL2` penalty (see
[Supported problems](support.md)); the coordinates of the solver are the groups. The pass
schedule, `tol`, `relative`, `maxpasses`, the borrowed random number generator, the
not-converged warning and the result type are those of the lasso. The result has
`kkt_checks = 0` and `gap = NaN`, placeholders and not computed certificates, and
`minimizer === x`. A random order permutes the groups.

### The group step

For a group `k` that is not flat (see below), with entries `G` and the current residual
`r`, the solver uses a number `ℓ_k > 0`, computed as described below, that is meant to
bound the largest eigenvalue of `X[:, G]' * X[:, G]` from above.
A visit forms the trial point `u = x[G] + X[:, G]' * r / ℓ_k` in `T`, replaces the block
by the proximal point of the penalty at `u` with the step `1 / (s ℓ_k)`, `s` the loss
scale, and updates the residual for each entry of the block that changed. The change of
the visit is the 2-norm `‖Δ_G‖₂` of the displacement of the block. A flat group has
`ℓ_k = 0` and takes the proximal point at the step `Inf` instead, without a trial point
(see below). A group whose block does not change is not written, which keeps an inactive
group inactive. A trial point or displacement that is not finite stops the solve with an
`ArgumentError` that names the group, and the iterate of the caller is unchanged; a change
or stopping scale that is not finite is refused as for the lasso.

**The zero-group screen.** When the block of a nonflat group is identically zero (whether
or not the group is active), the visit first forms the correlations `b = X[:, G]' * r` and,
if the two guards below allow, passes them to ProximalBase's `prox_block!` for the group
with the step `1 / s`. If the result is entirely zero, the visit ends with no change:
nothing is written to the iterate or the residual, and a deferred `ℓ_k` is not computed. A
zero block that the screen returns as zero forms no trial point, so it is not refused where
the trial point `b / ℓ_k` of the full step would overflow. In exact arithmetic, the full
step gives a zero block, for any `ℓ_k > 0`, exactly when the norm of `b` is at most
`λ w_k / s`, and the screen tests the same inequality. The guarantee is one-sided: where
the screen returns zero, the positive excess of the norm of `b` over the threshold
`λ w_k / s` is confined to a rounding band around the equality (a screened zero can also be
far inside the zero ball, for example `b = 0`). A nonzero screen result does not imply a
nonzero full step: `b / ℓ_k` can underflow, so the full step can return zero where the
screen does not. Two guards restrict the screen to cases where an entirely zero result is
meant to come from the threshold test, up to such a rounding band:

- the reciprocal `1 / s` formed in the type `S` of the scale must be a finite positive normal
  number of `S`; it is `Inf`, 0 or subnormal otherwise;
- either every correlation `b_i` is zero, or the largest `|b_i|` of the group is at least a
  floor, `2^53 floatmin(T)`, which is far above the underflow range of `T`. Otherwise
  ProximalBase's shrinkage of a very small correlation could round every entry of the result
  to zero although the norm of `b` exceeds the threshold, and a zero result would not certify
  the zero block.

Outside the guards, the screen is bypassed and the visit takes the full step, with the
curvature computed if it is still deferred.

### The curvature bound

`ℓ_k` is a bound on the stored values of `X` in `T`, formed as follows. The preparation
runs after the residual is set, before the first pass and any draw from the random number
generator, and only when `maxpasses > 0`; with `maxpasses = 0` it is skipped and the
preparation refusals below do not occur (the refusals of the inputs, the response scale
and the final objective still apply). The preparation computes and checks `ℓ_k` for a flat
group, for an ordinary one-column group and for a group that is not deferred; for a
deferred group it checks only the bounds below, and `ℓ_k` stays `NaN` until the first visit
that needs it.

- **Flat group.** If every entry of `X[:, G]` is exactly 0, `ℓ_k = 0`, set during the
  preparation. The visit takes the minimizer of the penalty alone: a zero block when the
  level and the weight are positive, and the block unchanged when one of them is 0. Its
  stopping scale is 0.
- **Group of one column**, with `n` the number of rows and `n eps(T) ≤ 1/8`. `ℓ_k` is
  computed during the preparation as the next floating-point number above
  `a (1 + 2 n eps(T))`, where `a` is the sum of squares of the column accumulated in `T`.
  The factor is a margin for the rounding of `a`, so `ℓ_k` is larger than the squared norm
  by a relative amount of about `2 n eps(T)`; the scalar lasso step uses `a` itself. The
  two sums are accumulated differently, so they can differ by rounding even before the
  margin.
- **Any other group**, and a group of one column with `n eps(T) > 1/8` (the *Gram route*).
  The Gram matrix `Ĝ` of the columns is formed in `Float64` from a copy of the columns
  (for `Float32` data too). With `t` the trace of `Ĝ`, `m` the size of the group and `d`
  the largest diagonal entry, the bound in `Float64` is the next number above
  `max(μ, d) + 4 (n + m²) eps(Float64) t`, rounded up to `T`, where `μ` is the largest
  eigenvalue of `Ĝ`: all eigenvalues of `Ĝ` are computed and the largest is taken, for a
  group of `m ≥ 2` columns. For a group of one column on this route, `μ` is the diagonal
  entry `Ĝ[1, 1]`, with no eigenvalue computation and no eigenvalue model. The error terms
  that the margin covers are the rounding of `Ĝ`, products that underflow, and, for
  `m ≥ 2`, the eigenvalue computation. The first two follow from standard bounds and
  assume IEEE gradual underflow (subnormal numbers are not flushed to zero); the third
  assumes that the computed eigenvalues are exact eigenvalues of a nearby matrix, within a
  multiple of `eps(Float64)` times the trace, a model of the eigenvalue routine and not a
  proved bound for every input.

**Lazy computation.** The eigenvalue computation is the expensive part, and a group that
stays at zero may never need it. During the preparation, a group on the Gram route gets
cheap bounds, formed in `Float64` from the sums of squares `q_c` of its columns (`n m`
operations, no products between columns): with `t` the sum and `d` the largest of the
`q_c`, a lower bound `lo = d (1 − 2 n eps(Float64)) − 2 n η` and an upper bound `hi = 4 t`
on the curvature that the rule above would store (`η` the smallest positive `Float64`; the
bounds assume gradual underflow, and the upper one the eigenvalue model, for groups of two
or more columns). Under that model, the four conditions below exclude the refusals; a
deferred group can still be refused during a pass through an eigenvalue routine that
throws, or through a violation of the model. The curvature is left uncomputed (`NaN` in the model) only if the type `S` of the scale is `Float32` or
`Float64`, `4 (n + m²) eps(Float64) ≤ 1/16`, `t` is finite, and all of these hold:

1. `lo ≥ 2 m floatmin(Float64)`, so that the trace underflow refusal is not made;
2. `lo ≥ 2 floatmin(T)`, so that the curvature underflow refusal is not made;
3. `hi ≤ floatmax(T) / 2`, so that no overflow refusal is made;
4. `s lo ≥ 2 floatmin(S)` and `s hi ≤ 1 / (2 floatmin(S))`, so that the step band check
   does not refuse.

The curvature is then computed, once per solve, at the first visit that needs it: a visit
whose block is nonzero, or whose block is zero and which the screen above does not remove,
and the band check is made there. A deferred group that stays at zero and is screened out
at each visit never computes its curvature. If any condition fails or the bounds do not
apply, the group is not deferred: the curvature and the band are computed during the
preparation, as for the other groups, and refuse as below, so such a group may already have
a curvature when it is screened. A one-column group with `n eps(T) > 1/8` is on the Gram
route and can be deferred. The bounds do not decide an eigenvalue routine that throws, or a
largest eigenvalue that is not finite: these surface during the preparation for a group
that is not deferred, and at the lazy computation, during a pass, for a deferred group.
How much the lazy computation saves depends on how many groups fail the screen; see
[Cost of the lazy curvature](choosing-solver.md#Cost-of-the-lazy-curvature).

The step of a nonflat group also needs `s ℓ_k` and its reciprocal to be at least the
smallest normal number of the type `S` that combines `s` with `T`. This band check is made
where the curvature is computed: during the preparation, or at the lazy computation. It cannot fail when `S` is wider than `T`, for example `Float32`
data with a `Float64` loss scale, because the scale then converts to a finite nonzero
`Float32` and the curvature is a normal `Float32` number; it can fail only when `S` is `T`
itself. The scale need not have the data type: `Float64` data `X = fill(2.0^-500, 1, 1)`
with the `Float32` scale `nextfloat(0f0)` has `ℓ_k` about `2^-1000`, a normal `Float64`
number, and `s ℓ_k` is below the smallest normal `Float64` number.

**When the refusals happen.** The refusals below throw an `ArgumentError` that names the
group, and they leave `x` unchanged. Those that are predictable, because the curvature is
computed during the preparation or the four conditions above hold, happen before the first
pass, and the random number generator is unused. A curvature computed lazily is computed
in the same way, and an exception of the eigenvalue routine (which is not caught), a
largest eigenvalue that is not finite, or a curvature or step refusal at that point (which
the four conditions are meant to exclude) happens during a pass: `x` is still unchanged,
but a random order may already have drawn from the generator.

| Category | Condition | Message contains |
| --- | --- | --- |
| Curvature underflow | the sum of squares of the column of a group of one column with `n eps(T) ≤ 1/8` is below `floatmin(T)`, the trace of `Ĝ` is below `m` times `floatmin(Float64)`, or `ℓ_k` is below `floatmin(T)` | `underflows` |
| Curvature overflow | the sum of squares of that column, `Ĝ`, its trace or its largest eigenvalue is not finite, or `ℓ_k` is infinite in `T` | `overflows` |
| Step | `s ℓ_k` or its reciprocal is outside the normal range | `step of group` |

A group whose curvature bound is subnormal in `T` is refused here, where the scalar
lasso accepts a subnormal squared norm of a column. Before these, `solve!` refuses a
receiver that is not a `BlockIterate{Float32}` or `BlockIterate{Float64}`,
`momentum = true`, a penalty that is not a `GroupNormL2{Float32}` or `GroupNormL2{Float64}`,
a level or weight that is not finite, nonnegative and representable in `T` (messages
`penalty lambda` and `group weight`), and groups of `x` and of the penalty that differ in
number, order or membership (`DimensionMismatch`); these input refusals also apply with
`maxpasses = 0`. No fallback rule replaces a refused curvature.

### The stopping statistic

With `relative = true` and a positive response scale, the change of a visit is
`‖Δ_G‖₂ √(s ℓ_k)`, formed by the range-safe rule that the lasso uses for `√(s a)`, and it
is compared with `tol` times the response scale of the lasso. For a group of one column
this is the lasso statistic up to the margin and rounding noted above. A flat group has
scale 0, so its change is 0. With `relative = false`, or for `y = 0`, the change is
`‖Δ_G‖₂` itself. A pass reports the largest change among the groups it visited, and a
full pass whose largest change is below the threshold ends the solve with
`converged = true`.

`converged = true` reports that change test only. It is not a certificate of optimality:
compute the group KKT conditions from the data, as in
[Example 6](examples/06_group_cd_lasso.md), where for `∇ = s Xᵀ(Xβ − y)` a nonzero group
needs `∇[G] + λ w β[G] / ‖β[G]‖ = 0` and a zero group needs `‖∇[G]‖ ≤ λ w`.

The pass schedule is that of the lasso with groups as the coordinates. A full pass
visits every group and an active pass visits the active groups; after each pass the
groups whose block is entirely zero become inactive. The forced full pass counts group
visits: once the active passes since the last full pass have together visited 20 times as
many groups as there are groups, the next pass is a full pass, whatever the changes.

### Result and failure

The solve runs on a private copy of `x`. A finite completed run, including one that
ends at `maxpasses` with the warning, replaces `x` by one same-layout copy of the final
state; a refusal or numerical error before that leaves the values, the active groups and
their order of `x` unchanged, though a random order may already have drawn from the
generator. The entries of the groups that are inactive at the end are zero; their sign is
not specified. After a solve, take `activecoordinates(x)` again, as for a `SparseIterate`.

## Working precision: Float32 and Float64

A supported solve uses a single floating-point working type
`T = Float32` or `T = Float64` for the design matrix `X`, response
vector `y`, and coefficient iterate. `CDSolver` accepts either a
dense `Vector{T}`, a one-dimensional `SparseIterate` of `T`, or, for the group lasso, a
`BlockIterate{T}`;
`ProximalGradientDescent` and `AccProxGradDescent` accept only a dense `Vector{T}`.
Mixed-precision arrays, such as `Float32` coefficients with a
`Float64` design, are rejected. This is stricter than ProximalBase
function dispatch, which may permit some heterogeneous calls without
guaranteeing their numerical behavior.

**Scalar-parameter exception.** The `NormL1` penalty level `lambda` may be a
finite nonnegative real scalar of a different type, including a `Float64`
literal for a `Float32` solve, and the loss scale in
`Scaled(LeastSquaresLoss(...), s)` is supported in two forms: a positive
finite `Float32` or `Float64`, or a positive fixed-width integer or `Bool`
that `T` represents exactly (`2^24` but not `2^24 + 1` for `Float32` data;
`2^53` but not `2^53 + 1` for `Float64` data). The solver checks that a
penalty level, and a `Float32` or `Float64` loss scale, are representable in `T`
without overflow or loss of a nonzero parameter to zero (a value that is
subnormal in `T` is accepted). A loss scale of any other type (`BigInt`,
`BigFloat`, `Rational`, `Float16`, `Irrational` or another `Real`) or an integer
that `T` rounds is refused with an `ArgumentError` before any solver writes to
the coefficients. **This is an intentional narrowing of the supported API:**
those scales were accepted before the loss value and gradient came from
ProximalBase's oracles (a `BigFloat`, `BigInt` or `Rational{BigInt}` scale made
CD's scalar arithmetic `BigFloat`; an `Int`, `Rational{Int}`, `Irrational`,
`Bool` or `Float16` scale was used there as `T(s)`). Convert the scale
explicitly where the conversion is finite, positive and representable in `T`,
for example `Float64(s) * LeastSquaresLoss(y, X)`; the error message suggests it
when it passes that rule. After the check, CD, PGD and APG use the loss scale as
supplied, combined with `T` by Julia's promotion: a `Float64` scale in a
`Float32` solve keeps its `Float64` value (also where that value is subnormal in
`Float32`). In CD, the coordinate step and the two stopping scales are formed
from that value and rounded to `T` where they enter the iterate or the
tolerance; an integer or `Bool` scale is used there as `T(s)`. The loss part of
CD's reported objective is formed by ProximalBase from the loss as supplied: it
converts an integer or `Bool` scale to `Float64`, forms the product in the
promoted type of the scale and `T`, and rounds the result to `T`. For an integer
or `Bool` scale the check makes `T(s)` and `Float64(s)` both equal `s`, so CD's
step and stopping computations and the objective use the same real scale. The
arithmetic precision can differ: for `Float32` data and the scale `3`, CD's step
and stopping arithmetic is in `Float32` and the objective's product is in
`Float64`; for `Float64` data both are in `Float64`. This convenience does **not**
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
solver can continue in every extreme-range case.

All three solvers take the least-squares value from ProximalBase's oracles
(`value_from_predictor` and `value_and_gradient_from_predictor!` for PGD and APG,
`value_from_residual` for CD), and PGD and APG take the coefficient gradient from
`value_and_gradient_from_predictor!`. ProximalSolvers forms CD's coordinate
correlations and updates and the `λmax` product of the stationarity check, and
keeps the image `X x` (PGD, APG), the residual (CD), the steps, the line searches
and the stopping rules. The exact
accuracy and range statements are those of the section "Least squares at a
predictor or residual that the caller holds" of the
[ProximalBase guide to the smooth functions](https://github.com/mlakolar/ProximalBase.jl/blob/a19c59aa723d085d5d7cf5242895bda16eb77214/docs/src/smooth.md); they are not restated here.
What changes for the solvers:

- CD takes the loss part of its objective from `value_from_residual` of its
  cached residual. ProximalBase recomputes exceptional values under the
  conditions its guide states (the "Value and rounding" section of the guide
  linked above); before, CD refused the finished solve where the sum of squares
  overflowed. The recovery holds for finite data and a value representable with
  ProximalBase's margin; near the overflow threshold its result can be `Inf` (the
  "Range" statement of the guide gives the conditions). CD returns an objective only when the loss plus the penalty is
  finite. Otherwise the finished solve is refused with a `nonfinite objective`
  `ArgumentError` and the starting point is unchanged; the sum can be non-finite
  where the recovered loss is finite, for example through an overflowing penalty
  value. Where the loss is below `floatmin(T)`, the
  guide's bound for the loss is `(n + 8) eps(T) |v|` plus
  `2 nextfloat(zero(T))`, with `n` the number of rows of `X` and `v` the exact
  value at the cached residual, so the reported loss part can be 0 or a small
  subnormal number.
- PGD and APG take the value at a start and at each trial from
  `value_from_predictor` (PGD's start and its gradient refreshes use
  `value_and_gradient_from_predictor!`, and so does APG's stationarity check). A
  start or trial whose value ProximalBase recovers, under the conditions of its
  guide, is evaluated finitely where the sum of squares overflows in `T`; before,
  the sum of squares was formed in `T` without that recovery.
- The gradient is `α` times the rounded product `Xᵀd` with `d = z - y` for the
  image `z = X x`. An `Xᵀd` that overflows or underflows before the scaling is not
  recovered, also where `α` would bring the exact gradient into range.
- Where `z - y` overflows with finite entries, `value_from_predictor` recovers the
  value, while `value_and_gradient_from_predictor!` returns a non-finite value
  and non-finite gradient entries. In PGD a trial is evaluated by the former and
  the gradient at an accepted trial by the latter, so an iterate accepted on a
  finite value can hold a non-finite gradient; this combination is not covered
  by a test.

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
  With `ftol > 0`, a solve whose inflated `L` makes the step round to zero proposes a stop
  through the coefficient test (with `ftol = 0` an unchanged iterate proposes nothing, as
  at the base). It used to report `converged = true` there;
  the [stationarity check of a stop](@ref "The stationarity check of a stop") now refuses the stop unless the
  iterate meets the bound, and the solve continues. With `ftol > 0` and
  `allow_f_increases = false` it can then reach the rounding regime of
  the objective and end on an objective-increase stop
  (`f_increased = true`); see "Why rounding triggers it" in
  [PGD stops when the computed objective increases](@ref). Under `ftol = 0`
  with the settings of [Strict accuracy](@ref), a Float32 solve can reach its
  floating-point fixed point and end at the stagnation stop there, with
  `stagnated = true` and `converged = false`; without an iteration that meets
  its condition, the exact-stall rule applies and the solve can run to
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

