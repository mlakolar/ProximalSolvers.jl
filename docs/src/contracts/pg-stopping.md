# [PGD and APG stopping](@id STOP-01)

This relocation checkpoint preserves baseline text before normalization.

<!-- Baseline: docs/src/numerics.md:L56-L335; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

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
`max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λ` the ℓ1 level of the penalty (for `GroupNormL2`, the group residual and scale; for `NormLinf`, the residual and scale of the generic check; see [The stationarity check of a stop](@ref "The stationarity check of a stop")); it is a working-precision residual, not an exact-arithmetic
certificate, and it does not bound the distance to a minimizer. The
default `gradtol = 1e-5` is not a specified number of correct digits.
Tighten tolerances for results you intend to report, then compute the
[independent KKT residual](sparsity-and-kkt.md). The
[Concepts](concepts.md) and [Getting started](getting-started.md)
pages display that residual next to the default-PGD convergence flag.
PGD's printed `|g(x)|` label is an internal stopping residual, **not**
the value of the user's L1 penalty.

What the stopping tests imply and their measured limits (products that underflow or cancel, a
cached residual of coordinate descent that is stale after a start far above the solution scale,
Float32, `ftol = 0`) are on the page [Limits of the stopping tests](stopping-limits.md).

### The stationarity check of a stop

PGD and APG verify a proposed stop; this section is the check for `NormL1`, `ElasticNet` and, with PGD,
`GroupNormL2` (the **Groups** item below), and other penalties use [the generic stationarity check](@ref "The generic stationarity check"). At an iteration at which the `x`, `f` or
gradient test holds (under `ftol = 0`, after the exact-stall rule below), the
solver computes the minimal-norm KKT residual `G` at the accepted iterate `x`.
For `NormL1(λ)` it is the element of `∇f(x) + λ ∂‖x‖₁` of least infinity
norm, that is `max(|∇fᵢ| - λ, 0)` where `xᵢ = 0` and `|∇fᵢ + λ sign(xᵢ)|`
elsewhere, with `λ = T(λ0)`, the penalty level converted to the coefficient type `T`. For
`NormL1(λ0, w)` the coefficient of entry `i` is `cᵢ = T(λ0) wᵢ`, formed in `T` (the weights are a
`Vector{T}`), so that `G` is `max(|∇fᵢ| - cᵢ, 0)` where `xᵢ = 0` and `|∇fᵢ + cᵢ sign(xᵢ)|` elsewhere; a zero
weight gives the coefficient 0 and the score `|∇fᵢ|`. For
`ElasticNet(λ1, λ2)` (PGD and APG) it is the element of
`∇f(x) + λ2 x + λ1 ∂‖x‖₁` of least infinity norm: `max(|∇fᵢ| - λ1, 0)` where
`xᵢ = 0` and `|∇fᵢ + λ2 xᵢ + λ1 sign(xᵢ)|` elsewhere, with the levels `T(λ1)` and `T(λ2)`. The solver
computes `‖G‖∞` with ProximalBase's `kkt_violation(NormL1(T(λ0)), ∇f(x), x)`, `kkt_violation(NormL1(T(λ0), w), ∇f(x), x)` or
`kkt_violation(ElasticNet(T(λ1), T(λ2)), ∇f(x), x)`, passing the converted levels. An infinite entry of `x`
gives a non-finite residual (`Inf`, or `NaN` when a `NaN` is read), so the stop does not count. Below,
`λ` is the ℓ1 level of the penalty (`λ` of `NormL1(λ)`, the largest coefficient `maxᵢ cᵢ = T(λ0) * maximum(w)` of
`NormL1(λ0, w)`, `λ1` of `ElasticNet`). The stop counts only if

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
- **Weights.** For `NormL1(λ0, w)`, `S = max(maxᵢ cᵢ, λmax)`; rounding is monotone, so the
  largest coefficient is `T(λ0) * maximum(w)`. For `w` all ones the coefficients and `S` are those of
  `NormL1(λ0)`. With all weights 0 the penalty vanishes, `S = λmax` and the check is that of least squares;
  with `y = 0` as well, `S` is 0 and no stop counts, as above. A zero-weight coordinate is scored with its
  full gradient `|∇fᵢ|`, so a stop at a point where that gradient is at least `τ S` is not accepted, also
  where `λ0` is large. A proposed stop adds two scans of `w` to the pass of `kkt_violation` (one for the
  maximum, one in the construction of `NormL1(T(λ0), w)`) and forms no array. Each `cᵢ` is a coefficient
  that `solve!` has checked: finite and, where `T(λ0)` and `wᵢ` are both positive, a normal number of `T`
  (a zero or subnormal product of positive factors is refused, and so is a subnormal `T(λ0)`); a zero level or weight gives
  `cᵢ = 0`. As above, a stop is refused where `τ S` is below `floatmin(T)`.
- **Groups.** For `GroupNormL2(λ0, groups, w)` with `ProximalGradientDescent` or `AccProxGradDescent` (a `GroupNormL2{T}` whose groups
  partition `1:p`), the coefficient of group `k` is `cₖ = T(λ0) wₖ` rounded in `T`, and `‖G‖∞` is replaced by
  ProximalBase's group residual `kkt_violation(g, ∇f(x), x) = max(0, maxₖ scoreₖ)`, with
  `scoreₖ = ‖∇_G f + cₖ x_G/‖x_G‖₂‖₂` at a group with a nonzero entry and `‖∇_G f‖₂ - cₖ` at a zero group
  (a zero weight gives the score `‖∇_G f‖₂`). The scale is `S = max(maxₖ cₖ, Λ)` with
  `Λ = maxₖ ‖[∇f(0)]_{Gₖ}‖₂ = α maxₖ ‖[Xᵀy]_{Gₖ}‖₂`, the group counterpart of `λmax` (`x = 0` is a minimizer iff
  `‖[∇f(0)]_{Gₖ}‖₂ ≤ cₖ` for every `k`); each group norm is LinearAlgebra's `norm`, which scales the block before
  squaring where the square of its largest magnitude underflows to 0, so squaring the entries does not make `Λ` underflow to 0 at a scale
  such as `α = 1e-300` (tested). It does not recover an entry of `α Xᵀy` that the product itself rounds to 0 or to a
  subnormal number. `τ`, the threshold and the guards are those above. For singleton groups
  with unit weights `S` is the `S` of `NormL1(λ0)`, while the iterates and the residuals of the two penalties
  can differ by rounding (the scales agree where no entry of `∇f(0)` has a subnormal square). As for `NormL1`, a stop that counts says that the computed residual is below the computed
  threshold, not that the residual in exact arithmetic is.
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

### The generic stationarity check

A penalty without a dedicated check (today `NormLinf`) uses one check that needs only the penalty's proximal
operator, so a new proximable penalty needs no convergence code of its own. At the accepted `x`, with `t = 1/L`
(the accepted curvature), the solver forms `p = prox_{t g}(x - t ∇f(x))` with the same ProximalBase
`value_and_prox!` as the iterations, and the residual `r = ‖x - p‖∞ / t`, the ∞-norm of the proximal-gradient
mapping. A proposed stop counts only if

~~~
r < max(gradtol, 64 eps(T)) * S,     S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞),
~~~

with the threshold formed in `T`. It is refused when `t` is not finite and positive, when `S` or `r` is not finite,
when the threshold is below `floatmin(T)` (so a solve with `S = 0`, as for `X = 0` or at `x = 0` when `y = 0`, does not report
convergence), when the threshold does not exceed `ρ = L eps(T) ‖x‖∞` (the rounding resolution of the gradient test),
or when `t` times the threshold is below `floatmin(T)/eps(T)` (a step that subnormal rounding can lose at `x = 0`).
Each proposed stop with a finite positive `t` costs one proximal evaluation, counted in `prox_calls`, and for APG one gradient at `x`, counted
in `grad_calls`, before the call limits are compared.

A small accepted `L` makes `t` large and `r` a weaker measure of stationarity than with the true curvature; a
penalty with curvature of its own far above `L` is the extreme case. `converged = true` is a working-precision
indication, not a certificate, and it does not bound the distance to a minimizer.

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


<!-- Baseline: docs/src/numerics.md:L356-L440; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

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


<!-- Baseline: src/types.jl:L11-L180; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

    ProximalOptions(; maxiter=200, ftol=1e-6, xtol=1e-8, gradtol=1e-5,
      allow_f_increases=false, store_trace=false, show_trace=false,
      extended_trace=false, print_every=1, callback=nothing, time_limit=Inf,
      f_calls_limit=0, grad_calls_limit=0, prox_calls_limit=0, gaptol=0, gapevery=10)

Options for proximal gradient descent (PGD); `AccProxGradDescent` uses the
same options and tests. The defaults prioritize an
exploratory solve rather than a guaranteed number of accurate digits.
PGD stops when **any** of the iterate-change (`xtol`), objective-change
(`ftol`), or gradient/proximal-residual (`gradtol`) criteria proposes a stop and
the stationarity check below passes.

**The stationarity check.** At an iteration at which one of the three tests
holds, the solver computes the minimal-norm KKT residual `G` at the accepted
iterate `x`: the element of `∇f(x) + λ ∂‖x‖₁` of least infinity norm for
`NormL1(λ)`, and the element of `∇f(x) + λ2 x + λ1 ∂‖x‖₁` of least infinity norm for
`ElasticNet(λ1, λ2)` (`ProximalGradientDescent` and `AccProxGradDescent`). For `NormL1(λ, w)` with weights `w`
it is the element of `∇f(x) + ∂(λ Σⱼ wⱼ |xⱼ|)` of least infinity norm, with the coefficient `T(λ) wⱼ` of entry `j`
(`T` the element type; `w` is a `Vector{T}`); a zero weight gives the coefficient 0, so its entry is unpenalized
and its score is `|∇fⱼ(x)|`. Below, `λ` is the ℓ1 level of the
penalty (`λ` of `NormL1(λ)`, the largest coefficient `T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet`);
`λ2` does not enter the bound. For `GroupNormL2(λ, groups, w)` (`ProximalGradientDescent` and `AccProxGradDescent`), `‖G‖∞` below stands for
ProximalBase's group residual `max(0, maxₖ scoreₖ)`, with `scoreₖ = ‖∇_G f(x) + cₖ x_G/‖x_G‖₂‖₂` at a group with a
nonzero entry and `‖∇_G f(x)‖₂ - cₖ` at a zero group (`cₖ = T(λ) wₖ` rounded in `T`), `λ` for the largest coefficient
`T(λ) * maximum(w)` and `λmax` for `maxₖ α‖[Xᵀy]_{Gₖ}‖₂`, the largest group norm of `∇f(0)`. The stop counts only if
`‖G‖∞ < max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `T` the element type and, for `NormL1` and `ElasticNet`,
`λmax = α‖Xᵀy‖∞` for the loss scale `α` (1 for a plain `LeastSquaresLoss`). The check
also requires that `S = max(λ, λmax)` is finite, that the product
`max(gradtol, 64 eps(T)) * S`, formed in `T`, is at least `floatmin(T)`, and that `‖G‖∞` is
finite; it does not require that product to be finite (for a huge `gradtol` it can be
`Inf`). Otherwise
`x_converged`, `f_converged` and `grad_converged` are all `false`, and the solve
continues. With `y = 0` and `λ = 0` both `λ` and `λmax` are 0, and nothing
converges. This holds when the computed `S = max(λ, λmax)` is 0, with `λmax` as the solver
computes it: for example `ElasticNet(0, λ2)` with `y = 0`,
where the ridge solution is `x = 0` but the solve runs to `maxiter` with `converged=false`, unless another
exit applies. An exact `Xᵀy = 0` need not give a computed `λmax = 0` (rounding), and the
check then uses the rounded `λmax`. `ElasticNet(λ1, λ2)` on the loss `½α‖Xb - y‖²` is the lasso with level `λ1` on the data
`X̃ = [√α X; √λ2 I]`, `ỹ = [√α y; 0]`, whose gradient is `∇f(x) + λ2 x` and whose `λmax` is the
`λmax` above: the check is that of the lasso on those data. For a dense `Vector` or a
one-dimensional `SparseIterate`, the coordinate descent solver accepts an unweighted `NormL1` or `ElasticNet`;
it stops by its change test, not by this check (see [`CDSolver`](@ref)).
A start `x0` with a finite `f(x0)` is accepted even if `g(x0)` overflows in `T` (for example a ridge
term `(λ2/2)‖x0‖²` above `floatmax(T)`). An error raised in the step of an iteration (its line search, or the
check that the accepted objective is finite) restores the last accepted iterate and is rethrown, as for `NormL1`. `converged=true` means that a test proposed a stop and that
the computed (working-precision) KKT residual `‖G‖∞` at the returned `x` is
below that bound. The code forms `τ = T(max(gradtol, 64 eps(T)))` and the threshold
`τ * max(λ, λmax)` in `T`, and compares `‖G‖∞` with it. The normalized form
`‖G‖∞ / max(λ, λmax) < max(gradtol, 64 eps(T))` is the exact-arithmetic reading: in working
precision the conversion to `T` and the product can round, or overflow to `Inf` for a huge
`gradtol`, in which case a finite residual passes against the infinite threshold.
`converged = true` guarantees only that the computed, normalized KKT residual
`‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))`, in that sense. It is not an exact-arithmetic
certificate, it does not bound the distance to a minimizer, and it does not guarantee
coefficient accuracy on ill-conditioned designs (see the
[stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)).
The check uses the solver's working-precision products, so a gradient product that underflows or
cancels can pass it at a point that is not stationary (see
[the limits of the stopping tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/)).
A `gradtol` below `64 eps(T)`, including
`0`, gives the bound `64 eps(T) max(λ, λmax)`. For `AccProxGradDescent` the check
forms `∇f(x)` from the cached image `A x` at each iteration at which a stop is
proposed, and counts that evaluation in `grad_calls`.

**The generic check (`NormLinf(λ)`).** A penalty without a dedicated check above uses the proximal-gradient
mapping at the accepted `x`: with `t = 1/L` (the accepted curvature), `r = ‖x - prox_{t g}(x - t ∇f(x))‖∞ / t`,
computed with the same ProximalBase `value_and_prox!` as the iterations. The stop counts only if
`r < max(gradtol, 64 eps(T)) * S` with `S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞)`; it is refused when `t` is not finite and
positive, when `S` or `r` is not finite, when that threshold is below `floatmin(T)` (so with `S = 0`, as for `X = 0` or at `x = 0` when `y = 0`, no stop counts), when it
does not exceed `ρ = L eps(T) ‖x‖∞`, or when `t` times it is below `floatmin(T)/eps(T)`. Each proposed stop with a finite positive `t` costs one
proximal evaluation, counted in `prox_calls` (and for `AccProxGradDescent` one gradient, counted in `grad_calls`). A small
accepted `L` makes `t` large and `r` a weaker measure of stationarity. `converged = true` is then a working-precision
indication, not a certificate.

The gradient test holds when `r < gradtol * m` or `r < gradtol * N`, with `r` the
gradient/proximal residual of the iteration, `m` the largest `r` so far in the
solve and `N` the larger of the gradient's and the proximal step's infinity
norms, each only against a scale that exceeds `ρ = L eps(T) ‖x‖∞`, the rounding
resolution of `L x`. No absolute term is added to `m` or `N`. The comparisons use the
floating-point products `gradtol * m` and `gradtol * N`: a residual of 0 holds only against
a positive product, so it does not hold against `m = N = 0` or against a product that
underflows to 0.

`ftol` must be finite and nonnegative. With `ftol > 0`, including the default,
the objective test holds when `|F - F'| / |F| < ftol` or
`|F - F'| < eps(|F| + |F'|)`, where `F = f(x) + g(x)` is the computed objective and
`F'` the previous one. The quotient is `0` when `F == F'` and `Inf` when
`F = 0 ≠ F'`. The second form holds when `F == F'` and `|F| + |F'|` is finite,
so a flat computed objective proposes a stop through the objective test, which is
not evidence of an accurate point (the stationarity check decides); in the ordinary
range, where `F` and `F'` are normal
floating-point numbers and `|F| + |F'|` is finite, it is about two units in the last
place of `F`. (If `|F| + |F'|`
overflows, `eps` is `NaN` and the second form does not hold.) `ftol = 0` switches
the objective test off: `f_converged` is `false` at every iteration. A positive
`ftol` that rounds to 0 in `Float64` is refused, so that a tiny value does not
mean "off", and `-0.0` is stored as `0.0`.

With `ftol = 0` only, an iteration whose accepted iterate equals the previous one
elementwise (compared by value, so `-0.0 == 0.0`) is no progress: it sets neither
`x_converged` nor `grad_converged`, and the solve continues, subject to the other
tests, the limits and, with `allow_f_increases=false`, the objective-increase stop.
A solve whose iterate stays unchanged until `maxiter`, and does not stop as described
below, ends with `converged=false` and `iteration_converged=true`; the flags then report
no progress, not that the point is wrong. An iterate that differs from the previous
one in any entry is evaluated as usual, including when the norm of the difference
rounds to 0. With `ftol > 0`, an unchanged iterate proposes a stop through the `xtol` test,
and the stationarity check decides. For
`AccProxGradDescent`, an extrapolated point `y` equal to `x` while `x` differs from
the previous iterate is not a stall: its residual `L * maximum(abs, x - y)` is 0, so
the gradient test holds when `0 < gradtol * N` and `ρ < N`, or `0 < gradtol * m` and `ρ < m`.

With `ftol = 0`, `ProximalGradientDescent` on `Vector{Float32}` data also stops at an
iteration in which both of these hold: the accepted iterate equals the previous one
elementwise, and the last rejection of that iteration's line search was decided by the
computed curvature of the rejected step, which was finite and replaced the line search's
curvature estimate `L̂` (the retry's `L` is then `min(Lexact, max(c, L / β))` for the
rejected trial's `L`, so it need not equal the curvature `c`). A rejection that is not
checked (a trial value that is not finite, a NaN estimate, a gradient estimate from a
gradient with a nonfinite entry) or whose computed curvature is not finite does not count,
and neither does an iteration whose first trial is already a zero step (it has no
rejection). A later rejection of the same iteration replaces an earlier one, and nothing
carries over from an earlier iteration. The stagnation check comes after tracing and after
any callback call that is due at that iteration under `print_every`; it does not change
the callback cadence. The result then has
`stagnated=true` and `converged=false` (see [`OptimizationResults`](@ref)); this is not a
convergence or accuracy certificate. For `Float64` data, for `AccProxGradDescent` and with
`ftol > 0`, `stagnated` is `false` and the stopping behavior is as described above.

With `allow_f_increases=false` (the default), PGD also stops at the first
iteration whose computed objective `F = f(x) + g(x)`, in the working
precision, exceeds the previous iteration's `F'`. This stop is **not** a
convergence test. At the iteration where any stop occurs, the result
reports `f_increased = F > F'` and
`converged = x_converged || f_converged || grad_converged`, so an
objective-increase stop reports `converged=false` unless one of those
tests also held and the stationarity check passed. With `ftol > 0`, in the ordinary
range (`F` and `F'` normal floating-point numbers, `|F| + |F'|` finite), an
increase smaller than about two units in the last place of `F` passes the objective
test, and the result reports both `converged=true` and `f_increased=true` if the
stationarity check also passes, and `converged=false` with `f_increased=true` if it
does not. A `Float32` solve with the default options can therefore end on the
objective-increase stop, with `converged=false`, where it used to stop on the objective
test. With `ftol = 0`, `f_converged` is
`false`, so an increase of any size reports `converged=false` unless the `x` or
gradient test held and the check passed. Near a minimizer the computed
change in `F` is of the size of the rounding error of evaluating `F`, so
whether a strict-tolerance solve ends with `converged=true` or with an
objective-increase stop can depend on the last bits of its trajectory
(CPU, BLAS kernel, compilation) rather than on the accuracy of the point.
`allow_f_increases=true` removes this stop; `f_increased` then only reports
the comparison at the last iteration. `iteration_converged` is
`iterations == maxiter`, which also holds when a test succeeded at that
last iteration. See the
[numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
page, which also describes a strict-accuracy configuration with `ftol = 0`.

`maxiter` caps iterations; `store_trace`, `show_trace` and
`extended_trace` control reporting. `print_every` sets display/callback
cadence; a callback receives the trace when it is stored, otherwise the
current state. The result display labels an internal gradient/proximal
residual as `|g(x)|`: it is **not** the value of the supplied penalty.

Call/time limits are checked after complete iterations, so counts can exceed
limits by one iteration. A zero call limit means unlimited. Float32/Float64
iterate buffers retain native arithmetic; some scalar tolerances and diagnostics
are held in Float64, without increasing coefficient accuracy.
Gap certificates are not implemented: `gaptol` and `gapevery` are accepted
for compatibility but not stored, a positive `gaptol` is refused when the
options are constructed, and `gapevery` (which must be positive) has no effect.

<!-- Baseline: docs/src/choosing-solver.md:L120-L124; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

Defaults are useful for an **exploratory first run**, not for claiming
coefficient accuracy. With them, `converged=true` means that the computed
KKT residual `‖G‖∞` is below `max(gradtol, 64eps(T)) * max(λ, λmax)` (`λ` the ℓ1 level of the penalty), which
does not bound the coefficient error, shown here next to the KKT violation
on this two-coefficient problem:

<!-- Baseline: docs/src/choosing-solver.md:L167-L189; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

The default `maxiter=200`, `ftol=1e-6`, `xtol=1e-8`
and `gradtol=1e-5` target convenience, **not a specified number of
accurate digits**. Tighten them for results you intend to report, but do
not assume smaller tolerances guarantee a correspondingly smaller error:
`gradtol` below `64eps(T)` is not resolved by the check of a stop, and the
residual that is checked does not bound the coefficient error.
PGD's stopping tests combine by **OR**, so any one of them can propose a stop,
and a proposed stop counts only if the computed KKT residual `‖G‖∞` is below
`max(gradtol, 64eps(T)) * max(λ, λmax)`, with `λmax = α‖Xᵀy‖∞` and `λ` the ℓ1 level of the penalty
(`λ1` for an `ElasticNet`, whose residual includes the ridge term `λ2 x`; for a `GroupNormL2`, the group residual
and scale of [the stationarity check](@ref "The stationarity check of a stop"); a `NormLinf` penalty uses the
[generic check](numerics.md#The-generic-stationarity-check)). A solve
that the check keeps from stopping continues, and can end at `maxiter` with
`converged=false`. `ftol = 0` switches the objective-change test off, as
described under Strict accuracy in [Numerical behavior](numerics.md).
With these stricter tolerances and the default `allow_f_increases=false`, PGD on
this problem ended on the objective-increase stop with `converged=false` in a
test run on Julia 1.13.3; `allow_f_increases=true` lets it continue to a stop
that passes the check (see "Strict accuracy" in [Numerical behavior](numerics.md)).
The two results above report both coefficient error (possible here because
the analytic answer is known) and an independently computed
[KKT violation](sparsity-and-kkt.md). On other problems, evaluate the KKT
condition directly instead of trusting `converged` alone.

<!-- Baseline: docs/src/concepts.md:L64-L72; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

With the default options, `converged=true` for PGD means that a stopping test
proposed a stop and that the computed KKT residual is below
`max(gradtol, 64eps(T)) * max(λ, λmax)` (`λ` the ℓ1 level of the penalty): a working-precision check, not an exact
optimality certificate. The displayed coefficient error and KKT violation can still
be nonzero. **Tighten the tolerances and check optimality before reporting numerical
results.** This is an illustration, not an accuracy guarantee for other problems. Here
the KKT violation uses the analytic lasso conditions, independently of the solver's
stopping flag. See [Choosing a solver](choosing-solver.md) for a tighter PGD
configuration and [the KKT tutorial](sparsity-and-kkt.md) for the formula.

<!-- Baseline: docs/src/getting-started.md:L92-L99; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

With the defaults, `converged=true` means that a stopping test proposed a stop and
that the computed KKT residual is below `max(gradtol, 64eps(T)) * max(λ, λmax)` (`λ` the ℓ1 level of the penalty); the
coefficients can still differ from the analytic answer, as the displayed errors show,
and this is not a general guarantee. Tighten tolerances for results you plan to report
and verify an independent KKT residual. See
[Choosing a solver](choosing-solver.md) for tighter settings.
The solver's `converged` flag is a working-precision check of the KKT residual, not an
exact optimality certificate.

<!-- Baseline: docs/src/working-with-results.md:L29-L47; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

**Warning:** for PGD and APG, `converged=true` means that a stopping test
proposed a stop and that the computed KKT residual `‖G‖∞` at the returned point
is below `max(gradtol, 64eps(T)) * max(λ, λmax)`, with `λmax = α‖Xᵀy‖∞` and `λ` the ℓ1 level of the
penalty (`λ` of `NormL1(λ)`, the largest coefficient `T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet(λ1, λ2)`): a
working-precision value. `converged = true` guarantees only that the computed,
normalized KKT residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64eps(T))` (the
threshold is formed in `T`, where it can round or overflow; see
[the stationarity check](numerics.md)). It is not
an exact-arithmetic certificate, not a bound on the distance to a minimizer, and
does not guarantee coefficient accuracy on ill-conditioned designs (see
[the stationarity check](numerics.md)). For CD with least squares or the group lasso it
means that a stopping rule was satisfied. Neither certifies the output as optimal. For the lasso,
use the separate [numerical KKT check](sparsity-and-kkt.md). For CD with the square-root loss,
`converged=true` means that a duality certificate proved `(P − P*)/P* ≤ 1e-4`, and `gap` holds the
proved bound (see [`CDSolver`](@ref)). Otherwise a result's `gap=NaN` and CD's `kkt_checks=0` are
placeholders: neither is a computed certificate.

For PGD and APG with a `NormLinf` penalty, `converged=true` means that a stopping test proposed a stop and that the
[generic proximal-gradient check](numerics.md#The-generic-stationarity-check) passed: a working-precision indication, not a certificate.

<!-- Baseline: docs/src/working-with-results.md:L65-L77; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

The result display's `|g(x)|` refers to an **internal
gradient/proximal stopping residual**, **not** the value of your
penalty object, even if you named that object `g`. Likewise,
the displayed `|x - x'|` abbreviates a stopping diagnostic;
see the [API documentation](api.md) for precise definitions.
PGD can propose a stop when **any** of its stopping criteria is met, and the
stop counts only if the computed KKT residual `‖G‖∞` is below
`max(gradtol, 64eps(T)) * max(λ, λmax)`; `gradtol` below `64eps(T)` is
not resolved by that check. See [Numerical behavior](numerics.md).

Trace fields such as `dxx` describe relative iterate changes, and
`backtrack_steps` counts line-search trials. These are solver
diagnostics, not changes to the statistical model.

<!-- Baseline: README.md:L52-L63; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

**For PGD and APG, `converged=true` means that a stopping test proposed a stop and
that the computed KKT residual `‖G‖∞` at the returned point is below
`max(gradtol, 64eps(T)) * max(λ, λmax)` (`λmax = α‖Xᵀy‖∞`, and `λ` the ℓ1 level of the penalty: `λ` of `NormL1(λ)`, the largest
coefficient `T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet(λ1, λ2)`; the threshold is formed in `T`, where it can round or
overflow for a huge `gradtol`), not that the coefficients have a specified number of
correct digits.** It guarantees only that the computed, normalized residual `‖G‖∞ / max(λ, λmax)` is below
`max(gradtol, 64eps(T))`, with the threshold formed in `T`; it does not
guarantee coefficient accuracy on ill-conditioned designs. Use tighter options and independently check optimality for
results you plan to report. It is a working-precision residual, not an exact-arithmetic
certificate (see [the stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)). See the
[numerical guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/)
and [solver settings](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/).

