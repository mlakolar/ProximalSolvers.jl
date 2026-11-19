# [Accelerated proximal gradient](@id APG-01)

This relocation checkpoint preserves baseline text before normalization.

<!-- Baseline: docs/src/developer/implementation-notes.md:L320-L416; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

APG (`AccProxGradDescent`) is the historical accelerated method narrowed to the
dense LS core: extrapolation `y = x + k/(k+3)(x - x_previous)`, `L ← αL` before each
iteration, backtracking `L ← L/β` until the LS bound test accepts the trial (see
"The APG bound test" below), and one restart from `y = x_previous` when an extrapolated step raises the computed
objective. `X y` is formed from `X x` and `X x_previous` without a product; a restart
copies `X x_previous`. Departures from `legacy/full`: no metric, tuple, owner or
generic smooth-loss path; β and α are validated and used in `T` (`T(β) < 1` and
`T(α) > 0` after rounding); the objective-scale bound that only guarded a nonfinite
value is dropped, so a nonfinite trial raises `L` through `next_curvature` (which
raises once `L/β` is not a finite increase) instead of failing at once; a trial is
accepted only when the bound is certified by rounding-error bounds ("The APG bound
test" below), where legacy compared rounded squares of cached-image differences with
an 8eps image allowance; a step with `x == y` entrywise is accepted with a
finite value, where legacy raised; a
nonfinite gradient at `y` is treated like a nonfinite value (restart, or failure
without momentum). Each step writes `x_previous ← x` after forming `y` and before the
first trial, so the shared engine's rollback restores the last accepted iterate.
`backtrack_steps` counts every trial, including the accepted one, so it equals
`prox_calls`. With `C` the number of stationarity checks of the solve (each evaluates
`∇f(x)` once, counted in `grad_calls` and not in `f_calls`), `grad_calls = iterations +
restarts + C` and `f_calls = 1 + grad_calls + prox_calls - C`. Its reported gradient residual
`L‖x - y‖∞` is a stopping quantity measured from `y`; it is not an independent KKT residual
at `x` (the check evaluates `∇f(x)` separately).

### The APG bound test

For least squares, `f(x) ≤ f(y) + ⟨∇f(y), d⟩ + L‖d‖²/2` (`d = x - y`) holds iff
`√α ‖X d‖ ≤ √L ‖d‖`. The target is that inequality relaxed by legacy's slack, `√α ‖X d‖
≤ (1 + 4eps) √L ‖d‖`, for the stored `x` and `y`, with `α` the loss scale as given. A
trial with `d ≠ 0` is accepted only when `_bound_certified!` (`src/solvers/image_models.jl`)
certifies the target; every other trial is rejected, so `L` grows.

*Assumptions.* IEEE arithmetic in `T` with gradual underflow, modelled as
`fl(a ∘ b) = (a ∘ b)(1 + δ) + η'` with `|δ| ≤ u = eps(T)/2` and `|η'| ≤ η/2`,
`η = nextfloat(zero(T))` (subnormal additions are exact); and a matrix-vector product that
evaluates each entry as a dot product of `p` multiplications and additions (or fused
multiply-adds) in some order. Then `|fl(X v) - X v| ≤ γ_p |X||v| + 2p η` componentwise,
`γₖ = k u/(1 - k u)`, so `‖fl(X v) - X v‖ ≤ γ_p ‖X‖_F ‖v‖ + 2p √n η`. `k u < 1/8` is required
for `k = max(n, p) + 4` in `T` and `k = n p + 3` in Float64 (`_check_bound_size`, before
mutation; for Float32 this refuses `max(n, p) ≥ 2,097,148`).

*Error bounds.* The cached `z_x` of a trial is a fresh product (bound above with `v = x`).
The cached `z_y` is a copy of a fresh product of `x_a` (first step, restart), or the
extrapolation `fl(z_a + ω(z_a - z_b))` of fresh products of `x_a` and `x_b` with
`y = fl(x_a + ω(x_a - x_b))` and computed `0 < ω ≤ 1`; three roundings per combination (one
an underflowing product) give `E_y = (2γ_p + 16u)‖X‖_F(‖x_a‖ + ‖x_b‖) + 8p√n η + 2√p ‖X‖_F η`,
covering both images, the image error of the rounded `y` and both combinations. `‖X‖_F`
enters as a proved upper bound (`_frobenius_upper`: squares summed in Float64, exactly
representable for Float32 data, in one pass when that is accurate and otherwise after an
exact scaling by the power of two `2^-e` of the maximum (`ldexp`), with `γ_{np+3}` and
underflow terms, rounding up the square root and the conversion), and each computed iterate norm is divided by `1 - γ_{p+4}`. The computed norms
of `Δz = z_x - z_y` and `d̂ = fl(x - y)` are within `γ_{n+4}` and `γ_{p+4}` of the norms of the
stored vectors (a one-pass sum is used only when finite and at least `4n floatmin(T)`; the
scaled two-pass form otherwise), and `‖d̂ - d‖ ≤ u ‖d‖`.

*Decision.* Cheap path: accept when `√α` times the upper bound `‖Δz‖/((1 - γ_{n+4})(1 - u)) + E_x + E_y`
is at most `(1 + 4eps)/(1 + κ) √L ‖d̂‖/((1 + γ_{p+4})(1 + u))`; reject when `√α` times the lower
bound `‖Δz‖/((1 + γ_{n+4})(1 + u)) - E_x - E_y` exceeds `(1 + 4eps)(1 + κ) √L ‖d̂‖/((1 - γ_{p+4})(1 - u))`.
Otherwise form `w = fl(X d̂)` in the residual buffer, with
`‖w - X d‖ ≤ (γ_p + 2u)‖X‖_F ‖d̂‖/((1 - γ_{p+4})(1 - u)) + 2p√n η`, accept when its upper bound passes,
and reject otherwise. `√α` (`_root_scale`) is formed from `α`'s significand and exponent
after `α` is rounded once to Float64 (exact for a Float32 or Float64 scale, for a `Bool` and
for an integer of magnitude at most `2^53`; a larger integer is rounded once); the exponent
is made even, the root of the significand is converted to `T`, and half the exponent is
carried as the `Int` exponent of an `_SE` value, so the range of `T` does not limit `√α`.
A scale outside the range of Float64 is not supported by `_root_scale`.
`κ = 32u` covers the roundings of `√L`, of `√α`'s conversion to `T`
and of the fixed number of `_SE` products and sums on each side; the dimension-dependent
errors enter through the factors above. These are conservative bounds: in Float32 the
cheap path is often inconclusive late in a solve and the fresh product decides, and for
data deep in the subnormal range, where the underflow terms can dominate the bounds, a
nonzero step may be rejected until `L` is far above the curvature, or the solve may fail
with rollback.

*Range.* The norms and the bound arithmetic are carried as a significand in `[1, 2)` of
type `T` and an integer binary exponent (`_SE`), so no partial product or sum of the bound,
no ratio of scale factors, and no subnormal norm is rounded to a scalar of `T`. The native
products, the extrapolation and the one-pass sums are evaluated in `T` and enter only
through the bounds above. Under the assumptions, a curvature above `floatmax(T)` is never
certified, so backtracking ends in `next_curvature`'s error and the engine's rollback.

*Edge cases.* `d̂ = 0` entrywise: accepted with a finite value (a stopping policy). A trial
with a nonfinite value or iterate norm is rejected before the test. A nonfinite `Δz` gives no
cheap decision; the fresh product decides. `L = 0` is rejected. Legacy's 8eps image allowance
and zero-`Δz` shortcut are not used.

*Validation.* These checks are samples, not a proof. `test/accelerated_pgd.jl` checks
against BigFloat references computed from `X`, `x` and `y` (the exact `X d`) that no accepted
trial violates the target, over random data with exponent spans of ±40 (Float32) and ±300
(Float64), subnormal-range data, large common offsets, extrapolated images with `ω` up to 1,
loss scales wider and narrower than `T`; that a global curvature bound `4α‖X‖_F²` is accepted
for normal-range data; that the fresh-product-only decision (an internal switch) is safe as
well; the underflow, narrower-scale and long-reduction cases found in review; and that
`_frobenius_upper` bounds `‖X‖_F`. On the 576 ordinary solves of the PR record 4.7% of trials
needed the fresh product; every solve is bit-identical to the fresh-product-only decision,
571 are bit-identical to `legacy/full`, and the 5 that differ (Float32) change the objective
by at most 2e-7 relative.

<!-- Baseline: src/solvers/accelerated_proximal_gradient_descent.jl:L7-L63; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

    AccProxGradDescent(; β = 0.5, α = 0.9, preconditioner = :none)

Accelerated proximal gradient descent (APG) for least squares with a `NormL1` (lasso, with optional weights),
`ElasticNet`, `NormLinf` or group lasso (`GroupNormL2`, see [`ProximalGradientDescent`](@ref)) penalty and a dense
`Vector{Float32}` or `Vector{Float64}` coefficient iterate (Parikh
and Boyd, *Proximal Algorithms*, §4.3). Iteration `k` (counted from the start or the last
restart) extrapolates `y = x + k/(k+3) (x - x')` from the last two accepted
iterates and takes a proximal gradient step from `y`: a gradient step for the
least-squares loss followed by the proximal operator of the penalty (soft thresholding for `NormL1`, at the level
`λ wⱼ` of entry `j` for `NormL1(λ, w)`, with the ridge weight after it for `ElasticNet`, for `GroupNormL2` ProximalBase's
block soft threshold, and for `NormLinf` the
point minus its projection onto the ℓ1 ball of radius `λ/L`). It is a FISTA-family method; its
momentum sequence `k/(k+3)` is not the textbook FISTA recurrence.

The step size `1/L` is found by backtracking on the least-squares bound
`f(x) ≤ f(y) + ⟨∇f(y), x - y⟩ + L/2 ‖x - y‖²`, which holds exactly when
`√α_f ‖X(x - y)‖ ≤ √L ‖x - y‖`. A trial is accepted only when that inequality, with
a relative slack of `4eps` on `√L`, is certified by conservative rounding-error
bounds (assuming IEEE arithmetic with gradual underflow): first from the difference
of cached products, and when that is inconclusive from a freshly computed `X(x - y)`;
a trial that is still inconclusive is rejected.
See [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).
A trial with `x == y` entrywise is accepted when its value is finite. A rejected trial sets
`L ← L/β`, `β ∈ (0, 1)`. Before each iteration `L ← α L`, `α ∈ (0, 1]`, so that the
step can grow again where the curvature is smaller; `α = 1` keeps `L` from
decreasing. The estimate before the first iteration is `min(1, α_f ‖X‖_F²)` for the loss scale
`α_f`, with `‖X‖_F` an upper bound, rounded to `T` and raised to `floatmin(T)` when it is positive and
rounds below that; it is `1` when that product is at least 1 or `X = 0`.

When an extrapolated step would increase the computed objective, the momentum is
restarted: the step is repeated from `y = x'` and `k` returns to zero, so the next
iteration extrapolates with `1/4`. An accepted step that used momentum therefore
never increases the computed objective. A step without momentum (the first
iteration, and a step repeated after a restart) can increase it through rounding of
the step and of the objective; as for [`ProximalGradientDescent`](@ref), that
stops the solve unless `allow_f_increases = true` in [`ProximalOptions`](@ref).

Backtracking raises an error when the next curvature estimate `L/β` is not a finite
increase of `L`; `solve!` then restores the last accepted iterate and rethrows. A
`β` close to one makes each rejected trial raise `L` only slightly. `preconditioner = :diagonal` is deferred and
rejected. Pass `ProximalOptions(...)` as the fifth argument to [`solve!`](@ref).
A stop that the `xtol`, `ftol` or `gradtol` test proposes counts only if the computed KKT
residual at the accepted `x` is below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, with
`λ` the ℓ1 level of the penalty (`λ` of `NormL1(λ)`, the largest coefficient
`T(λ) * maximum(w)` of `NormL1(λ, w)`, `λ1` of `ElasticNet`) and, for `NormL1` and `ElasticNet`, `λmax = α‖Xᵀy‖∞` (see [`ProximalOptions`](@ref)); for `GroupNormL2(λ, groups, w)` the residual is the
group KKT residual and `λmax = maxₖ α‖[Xᵀy]_{Gₖ}‖₂`, `λ = T(λ) * maximum(w)`; for `NormLinf` the
generic proximal-gradient check of [`ProximalOptions`](@ref) applies instead. For `NormL1`, `ElasticNet` and `GroupNormL2`, `converged = true` guarantees only that the
computed, normalized KKT residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the
threshold is formed in `T`, which can round or overflow; see [`ProximalOptions`](@ref)). It is
not an exact-arithmetic certificate and does not guarantee coefficient accuracy on
ill-conditioned designs (see the [stationarity check](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#The-stationarity-check-of-a-stop)). In `Float32`, a solve can report `converged = true` at a relative duality gap above `1e-5`, as in measurements on small benchmark designs (see
[the limits of the stopping tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/)). The check forms `∇f(x)` from the
cached image `A x` and counts that evaluation in `grad_calls`. The gradient-mapping residual
of the result, `L ‖x - y‖∞`, is measured from the extrapolated point `y`, not from `x`; check
KKT conditions independently before reporting numerical results.
See the [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/)
and [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).

<!-- Baseline: docs/src/choosing-solver.md:L193-L204; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

`AccProxGradDescent` takes the same inputs, `ProximalOptions` and result type
as PGD, up to a dimension limit that its line search needs (for Float32,
`max(n, p) < 2,097,148`; see [Numerical behavior](numerics.md)). Each step starts from the extrapolated point
`y = x + k/(k+3) (x - x_previous)`, where `k` counts iterations since the start
or the last restart, and the momentum is restarted when an extrapolated step
would increase the objective. On ill-conditioned problems this can need
fewer iterations than PGD; on well-conditioned ones it can need more. An
iteration evaluates the gradient at `y` and then backtracks; a restart adds a
second gradient evaluation and line search in that iteration. Compare the two at
the same independently measured accuracy, as in
[the solver comparison](examples/comparisons/lasso_solvers.md), before
choosing one for speed.

<!-- Baseline: docs/src/choosing-solver.md:L224-L230; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

The constructor keywords are the backtracking factor `β ∈ (0, 1)`, which
shrinks the step `1/L` after a rejected trial, and `α ∈ (0, 1]`, which lets the
step grow again before each iteration (`AccProxGradDescent(β=0.5, α=0.9)` by
default). APG uses PGD's stopping tests, so the remarks above about defaults,
the OR combination and the objective-change test apply unchanged; its
gradient-mapping residual is measured at the extrapolated point. See
[Numerical behavior](numerics.md).

