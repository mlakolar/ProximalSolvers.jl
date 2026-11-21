# Accelerated proximal gradient

## Scope

`AccProxGradDescent` supports dense `Vector{Float32}` and `Vector{Float64}` coefficients and the matrices in [IN-10](@ref) for the least-squares penalties in the [support matrix](../support.md). It uses the common least-squares image model, gradient engine, options and results. It also accepts a raw `LogisticLoss(y, X)` with `NormL1` on a dense `Vector{Float64}` under [IN-09](@ref), with the line search of [APG-08](@ref). It has no metric, tuple, owner or generic smooth-loss path.

## Problem

Minimize `s‖Xx - response‖²/2 + g(x)` with `NormL1` or `ElasticNet` with optional weights under [IN-03](@ref), `NormLinf`, `NormL2` ([IN-11](@ref)) or `GroupNormL2`. The constrained variants use `IndBox` (including `IndBallLinf`) or four-coefficient `IndBallL2` under [IN-08](@ref). The penalty prox is described in [PGD-01](@ref). For a raw `LogisticLoss(y, X)` the smooth term is the summed logistic loss of [IN-09](@ref) and the penalty is `NormL1` (optional weights); [APG-08](@ref) gives its line search.

## Notation

`s` denotes the loss scale; constructor `α` and `β` are backtracking factors. Here `y` is the extrapolated coefficient point, `x_previous` is the preceding accepted point and `k` counts momentum steps since initialization or restart. The preserved proof in [APG-06](@ref) uses its original `α` for the loss scale `s`; it does not denote the constructor factor in that proof.

## Preconditions and refusals

### [APG-02 Method factors and dimension limits](@id APG-02)

**Statement.** The defaults are `AccProxGradDescent(β=0.5, α=0.9, preconditioner=:none)`. Require `0 < β < 1` and `0 < α ≤ 1`; the factors are validated as given and after promotion, and then again in the iterate type before state creation (`T(β) < 1` and `T(α) > 0` must survive rounding). `preconditioner=:diagonal` is deferred and rejected.

For one response the error bounds require `max(n, p) + 4 < 1/(4 eps(T))` and `n*p + 3 < 1/(4 eps(Float64))`. This refuses `max(n, p) ≥ 2,097,148` for Float32. Oversize problems are refused before the caller's iterate changes. The matrix-response dimension rule is [APG-07](@ref). Input shape, scale and ownership conditions are [IN-01](@ref).

**Applies to.** AccProxGradDescent; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl: AccProxGradDescent, _check_method, _check_bound_size, solve!`.

**Tests.** test/accelerated_pgd.jl: constructor/method settings, norm budgets and unsupported-input preflight.

**Sources.** `docs/src/developer/implementation-notes.md:L320`, `docs/src/developer/implementation-notes.md:L346`, `docs/src/developer/implementation-notes.md:L352`, `docs/src/developer/implementation-notes.md:L418`, `docs/src/numerics.md:L1045`, `docs/src/choosing-solver.md:L193`, `docs/src/choosing-solver.md:L224`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`.

## Algorithm

### [APG-01 Extrapolation, cached images and trial sequence](@id APG-01)

**Statement.** The method follows the accelerated proximal-gradient construction in Parikh and Boyd, *Proximal Algorithms*, §4.3, with momentum `k/(k+3)`. It is a FISTA-family method; this is not the textbook FISTA recurrence.

Form `y = x + k/(k+3) * (x - x_previous)` from the two accepted iterates, then take a gradient and proximal step from `y`. The first iteration has no momentum. Before each iteration use `L ← α L`, allowing the step to grow again; `α = 1` keeps this estimate from decreasing. A rejected trial uses `L ← L/β`; a `β` near one makes growth slow. Initial curvature is [PGD-02](@ref).

The image `X y` is formed by the same linear combination of cached `X x` and `X x_previous`, without a new product. Form `y` before saving `x_previous ← x`, then make trials; the saved point is the last accepted point if a trial throws. Each trial uses `value_and_prox!` and a fresh image of its candidate. The unweighted lasso level follows [IN-02](@ref). Nonzero trial displacements are accepted only by [APG-06](@ref); a point equal to `y` entrywise is accepted when its value is finite. The shared engine then applies [STOP-01](@ref).

**Applies to.** AccProxGradDescent; supported dense least-squares and logistic ([APG-08](@ref)) problems.

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl: initial_state, update_state!, _prox_grad_step!`.

**Tests.** test/accelerated_pgd.jl: momentum, backtracking rejection, restart and image caches.

**Sources.** `docs/src/developer/implementation-notes.md:L320`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L7`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L9`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L21`, `docs/src/choosing-solver.md:L193`, `docs/src/choosing-solver.md:L224`.

### [APG-03 Restart and failure boundary](@id APG-03)

**Statement.** If an extrapolated step raises the computed objective, repeat it once without momentum from `y = x_previous`, copy the cached image of that point, and reset `k` to zero. The next iteration then extrapolates with `1/4`. An accepted step that used momentum does not increase the computed objective. A first or restarted step without momentum can increase it through rounding, invoking the common objective-increase exit unless `allow_f_increases=true`.

A nonfinite value or gradient at the extrapolated point is treated the same way: restart when momentum was used, otherwise fail. A nonfinite trial value is rejected, raising `L` through `next_curvature` rather than immediately accepting or silently ending. If `L/β` cannot increase finitely, the search errors; [RES-01](@ref) specifies restoration of the last accepted iterate and rethrow. A trial with a nonfinite value is never accepted.

**Applies to.** AccProxGradDescent; supported dense least-squares and logistic ([APG-08](@ref)) problems.

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl: update_state!, _prox_grad_step!; src/solve.jl: _solve_gradient!`.

**Tests.** test/accelerated_pgd.jl: nonfinite extrapolated values, nonfinite trials, curvature overflow and step-error rollback.

**Sources.** `docs/src/developer/implementation-notes.md:L320`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L21`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L36`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`, `docs/src/numerics.md:L1045`.

## Stopping

### [APG-05 Iteration residual versus accepted-point check](@id APG-05)

**Statement.** The iteration's gradient/proximal residual is `L ‖x-y‖∞`, measured from the extrapolated point. It is a stopping quantity, not an independent KKT residual at accepted `x`. The common proposal tests and exact-stall rule use [STOP-02](@ref) and [STOP-10](@ref); proposed stops are checked at `x` under [STOP-03](@ref)–[STOP-07](@ref). The additional accepted-point gradient and its count are [STOP-08](@ref).

**Applies to.** AccProxGradDescent.

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl: g_residual, gradient_converged!; src/utils.jl: _gradient_at_x!`.

**Tests.** test/accelerated_pgd.jl: proposed stop clearing and gradient counts. test/norml2_pgd.jl checks that the `NormL2` stationarity test forms the gradient at the accepted point.

**Sources.** `docs/src/numerics.md:L62`, `docs/src/developer/implementation-notes.md:L320`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`, `docs/src/choosing-solver.md:L224`.

## Postconditions

### [APG-04 Trial and oracle counts](@id APG-04)

**Statement.** `backtrack_steps` counts every APG trial, including accepted trials. Let `C` count stationarity checks that evaluate the gradient at accepted `x`, and `C_prox` count additional proximal evaluations by the generic check. On a completed solve,

```
grad_calls = iterations + restarts + C
prox_calls = backtrack_steps + C_prox
f_calls = 1 + grad_calls + backtrack_steps - C
```

For a dedicated KKT check, including the `NormL2` check of [STOP-17](@ref), `C_prox = 0`, so `backtrack_steps == prox_calls` and the last identity is equivalently `f_calls = 1 + grad_calls + prox_calls - C`. A generic check can add a proximal call without a trial or function call; its guards and counting are [STOP-07](@ref) and [STOP-08](@ref). These counters describe the existing implementation; errors do not transactionally restore them.

**Applies to.** Completed AccProxGradDescent solves.

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl: _prox_grad_step!; src/utils.jl: _gradient_at_x!, _stationary!`.

**Tests.** test/accelerated_pgd.jl: image-cache counters and trace/limits; test/linf.jl: one extra prox for a proposed stop; test/norml2_pgd.jl: `backtrack_steps == prox_calls` with a dedicated `NormL2` check.

**Sources.** `docs/src/developer/implementation-notes.md:L320`, `docs/src/numerics.md:L194`, `docs/src/numerics.md:L238`, `docstring:src/types.jl:L75`.

Result identity, trace/callback ownership, limit ordering and mutation rules are [PGD-04](@ref) and [RES-01](@ref).

## Floating-point rules

### [APG-06 Certified least-squares bound](@id APG-06)

**Statement.** A nonzero displacement is accepted only when the least-squares bound, with relative slack `4eps(T)` on `√L`, is certified for the stored trial and extrapolated points under the assumptions below. Use the cached-image difference first, then a fresh product when the bounds are inconclusive; reject a still-inconclusive trial. This avoids subtracting nearly equal objective values. It is a certificate for this line-search inequality, not a solver optimality certificate.

The baseline proof below uses one response. [APG-07](@ref) gives the matrix-response dimensions and error bounds. In this proof `α` is the loss scale `s`, and all dimensions, rounding assumptions, underflow terms and exponent arithmetic are part of the stated conditions. Its final validation paragraph is historical empirical evidence, not an additional guarantee.

**Applies to.** AccProxGradDescent least-squares line-search trials under the stated arithmetic and size assumptions; for a logistic loss, the same test with `s = ¼` ([APG-08](@ref)).

**Code.** `src/solvers/image_models.jl: _bound_certified!, _frobenius_upper, _root_scale; src/solvers/accelerated_proximal_gradient_descent.jl: _check_bound_size`.

**Tests.** The matrix validation is in [APG-07](@ref). test/accelerated_pgd.jl: certified backtracking against BigFloat, subnormal norms, wide scales, nonfinite inputs and fresh-product reference. test/norml2_pgd.jl checks the bound in BigFloat for an accepted nonzero trial after backtracking with `NormL2`.

**Sources.** `docs/src/developer/implementation-notes.md:L344`, `docs/src/developer/implementation-notes.md:L346`, `docs/src/developer/implementation-notes.md:L352`, `docs/src/developer/implementation-notes.md:L361`, `docs/src/developer/implementation-notes.md:L375`, `docs/src/developer/implementation-notes.md:L394`, `docs/src/developer/implementation-notes.md:L401`, `docs/src/developer/implementation-notes.md:L406`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L21`, `docs/src/numerics.md:L1045`.

#### Preserved proof sketch

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

### [APG-07 Matrix-response Frobenius certificate](@id APG-07)

**Statement.** For `K` responses, the certified bound in [APG-06](@ref) uses
Frobenius norms for coefficients, images and displacements. The test uses
`q = nK` image entries, `r = pK` coefficient entries, and `p` terms per
product entry. It requires `max(q,r) + 4 < 1/(4 eps(T))` and
`np + 3 < 1/(4 eps(Float64))`. Before creating a state, it compares the
existing array lengths against the limits with the additive margins
subtracted. This avoids overflowing integer products or sums. The range
conditions coincide with the vector conditions at `K = 1`.

**Applies to.** APG under [IN-10](@ref) and the arithmetic and product
assumptions in [APG-06](@ref).

**Code.** `src/solvers/accelerated_proximal_gradient_descent.jl` provides
`_check_bound_size`. `src/solvers/image_models.jl` provides `_bound_constants`,
`_image_error_bound` and `_bound_certified!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks the range boundary,
the dimensional error terms and the cached and fresh decisions against
a BigFloat calculation of the full least-squares majorization inequality.
It covers ordinary, mixed-magnitude, near-roundoff and subnormal inputs,
including a one-column comparison with the vector certificate.

**Sources.** [Issue #469](https://github.com/mlakolar/ProximalSolvers.jl/issues/469)
and the one-response proof in [APG-06](@ref).

#### Dimensional error bounds

Write `η = nextfloat(zero(T))`. Under the dot-product model in [APG-06](@ref),
for each output entry the relative product error is bounded by the corresponding
entry of `γ_p |X||B|` and the absolute underflow term is `2pη`.
For each column `k`, Cauchy–Schwarz gives
`‖|X||B[:,k]|‖₂ ≤ ‖X‖_F ‖B[:,k]‖₂`. Squaring and summing over columns gives
`‖|X||B|‖_F ≤ ‖X‖_F ‖B‖_F`. Thus the product relative error retains
`γ_p ‖X‖_F` per unit of coefficient Frobenius norm. The uniform absolute
error across `q` entries contributes `2p √q η`.

The same column inequality applies to the image of the coefficient
extrapolation error. Apply the three-rounding combination bound in
[APG-06](@ref) entrywise to the two images and to the two coefficient
matrices. The two fresh-image errors and the image extrapolation roundings
contribute the absolute allowance `8p√q η`. The coefficient combination
has absolute error at most `2η` per entry, and applying `X` to it
contributes at most `2√r ‖X‖_F η`. The relative bound remains
`(2γ_p + 16u) ‖X‖_F (‖B_a‖_F + ‖B_b‖_F)`.
Image norm reductions use `γ_{q+4}`, and the displacement and coefficient
norm reductions use `γ_{r+4}`. These substitutions in the existing
lower and upper bounds cover the matrix dimensions while leaving the
comparison slack and exponent arithmetic of [APG-06](@ref) in use.
Consequently the cached difference and fresh product certify the same
full majorization condition, since the exact quadratic remainder is
`s ‖X(B − B_y)‖_F²/2`. The rounding constants and size limits describe the
implementation and its proof.

### [APG-08 Logistic loss: the certified bound with curvature factor ¼](@id APG-08)

**Statement.** For a raw `LogisticLoss(y, X)` accepted by the gate of [IN-09](@ref), APG runs the iteration of [APG-01](@ref) with the line-search decision below. Extrapolation, momentum, restart, the backtracking factors, the counters and rollback are those of [APG-01](@ref) to [APG-04](@ref) and [RES-03](@ref). The value and the gradient come from ProximalBase's predictor oracles ([IN-09](@ref)): the gradient of a step is formed at the cached image of the extrapolated point, and the gradient at an accepted point only when a stop is proposed ([APG-05](@ref), [STOP-08](@ref)). The initial curvature is that of [PGD-02](@ref) with the factor `¼` in place of the loss scale, with its rules for a zero design and its floor; PGD and APG start from the same value up to the order of summation in the estimate of `‖X‖_F`. In this clause `y` is the extrapolated point, as in the notation above, and the response is not written.

*Line-search decision.* Let `x` be a trial from `y` at the curvature `L`, and `d = x - y`. A trial whose smooth value or iterate norm is not finite is rejected. A finite trial with `d = 0` entrywise is accepted. A finite trial with `d ≠ 0` is accepted when `½‖X d‖ ≤ (1 + 4eps(T)) √L ‖d‖` is certified for the stored `x` and `y` under the arithmetic and size assumptions of [APG-06](@ref), with `T = Float64`; this is the test of [APG-06](@ref) with `√s = ½`. A rejected trial replaces `L` by `L/β` through `next_curvature`; where `L/β` is not a finite increase of `L`, the search raises and the last accepted point is restored ([APG-03](@ref)). The accepted trial is the result of the line search. The restart of [APG-03](@ref) can still discard it, and the engine can end the solve if the composite objective at it is not finite ([RES-03](@ref)).

*Inequality in exact arithmetic.* With `σᵢ = σ((X b)ᵢ)`, `0 ⪯ ∇²f(b) = Xᵀ diag(σᵢ(1 - σᵢ)) X ⪯ ¼ XᵀX`, and Taylor's formula with integral remainder gives `f(x) ≤ f(y) + ⟨∇f(y), d⟩ + ⅛‖X d‖²`. Hence, if the image inequality `¼‖X d‖² ≤ (1 + 4eps(T))² L ‖d‖²` holds, then `f(x) ≤ f(y) + ⟨∇f(y), d⟩ + (L/2)(1 + 4eps(T))²‖d‖²`, the descent inequality relaxed in `L` by the factor `(1 + 4eps(T))²`. For least squares the remainder `f(x) - f(y) - ⟨∇f(y), d⟩` is `(s/2)‖X d‖²`, so the image inequality is equivalent to the correspondingly relaxed descent inequality. For the logistic loss the remainder is at most `⅛‖X d‖²`, and it is smaller when `X d ≠ 0`: the weights `σᵢ(1 - σᵢ)` equal `¼` only where a logit is zero, and a logit with `(X d)ᵢ ≠ 0` is zero at one point of the segment from `y` to `x` at most. The image inequality is sufficient for the descent inequality, not equivalent to it.

*What is certified.* The certificate of [APG-06](@ref) is sufficient for the image inequality at the stored points, under the assumptions and error bounds of that clause: it accepts only a certified trial and rejects an inconclusive one, so it can reject a trial for which the image inequality holds. The certificate does not cover the computed `f(y)` and `∇f(y)`, which come from the extrapolated image `z_y` (error `E_y` in [APG-06](@ref)) and from the roundings of ProximalBase's oracles, or the restart test of [APG-03](@ref), which compares computed objective values. The descent inequality above is a consequence in exact arithmetic, not a statement about the computed values.

*Conservatism.* The factor `¼` does not use the local weights, so where the logits are saturated the accepted `L` can be well above the local curvature, and the step `1/L` shorter than a test on the loss value would allow. In the following fixtures, `X = fill(2e154, n, 1)`, the penalty is `NormL1(0.0)` and the method is `AccProxGradDescent()` with its default factors (`β = 0.5`, `α = 0.9`).

- One row, response `[1.0]` or `[0.0]`, start `[0.0]`. The initial curvature is `1` ([PGD-02](@ref)) and is `0.9` after the decrease at the start of the first iteration. The first trial is `±1e154/L`, whose image is beyond `floatmax(Float64)`, so its value is `Inf`, and each rejected trial doubles `L`. A nonzero `d` needs `L ≥ ¼X²/(1 + 4eps)²`, about `1e308` and below `floatmax(Float64)`. The first iteration accepts `L = 0.9 · 2^1024`, about `1.6e308`, after 1025 trials. That value is above `floatmax(Float64)/2`, so one more rejected trial in a later iteration of the same solve raises the error of `next_curvature`. `ProximalGradientDescent` with `BackTracking(Lexact = 0.9)` accepts the first finite retry of the same fixture at `L = 1.8` (`test/logistic_pgd.jl`).
- Three rows, response `[1.0, 1.0, 0.0]`, and start `[0.0]`. Here `¼‖X‖_F²` is about `3e308`, above `floatmax(Float64)`, so no finite `L` is certified for a nonzero displacement; the first iteration's search raises the error of `next_curvature` and the start is restored ([APG-03](@ref), [APG-06](@ref), *Range*).
- The lower bound applies to a nonzero displacement. From the start `[1e-150]` with every response entry `1`, the Float64 gradient at the start is zero, the first trial equals `y`, and it is accepted at `L = 0.9`, for one row and for three.

*Nonfinite images.* The logistic value of an image with a nonfinite entry is `Inf` ([IN-09](@ref)), so a trial with a nonfinite image is rejected and `L` is raised where `L/β` is a finite increase, with the error and rollback of [APG-03](@ref) otherwise; a nonfinite value or gradient at the extrapolated point restarts the step or, without momentum, fails with rollback ([APG-03](@ref)). A point accepted by the line search has a finite image: each trial it accepts, a zero step included, is decided inside the finite-value branch of `_prox_grad_step!`, where a logistic value is finite only for a finite image. The gradient at the accepted point used by the stopping check ([STOP-08](@ref)) is formed from that image; for a nonfinite image the logistic `_value_and_gradient!` returns `Inf` without writing the gradient.

*Stopping.* A proposed stop is checked by [STOP-03](@ref) with the logistic gradient and the `λmax = ‖∇f(0)‖∞` of [IN-09](@ref). The difference `½ - response` that defines `∇f(0)` is formed in the image-length buffer, which APG writes before it reads it at each of its other uses.

**Applies to.** `AccProxGradDescent` with a raw `LogisticLoss{Float64}` (no observation weights or offset) and `NormL1`, with or without weights, on a dense `Vector{Float64}`, under the arithmetic and size assumptions of [APG-06](@ref) and the size limits of [APG-02](@ref).

**Code.** `src/solve.jl: _check_logistic_problem, _logistic_solver_name`; `src/solvers/image_models.jl: _LogisticImage, _image_model, _bound_certified!`; `src/solvers/accelerated_proximal_gradient_descent.jl: _prox_grad_step!`; `src/utils.jl: _zero_gradient!, _gradient_at_x!`.

**Tests.** `test/logistic_apg.jl` compares the decisions of `_bound_certified!` for the logistic image with those for least squares at `s = ¼`. It checks, in BigFloat from the stored data, the image inequality and the descent inequality at the final trial of each completed iteration of APG solves, with iterations whose completed `L` exceeds the decreased initial `L` (a rejected trial and a retry), iterations that use momentum and iterations that restart. It compares the initial curvature with PGD's, including a zero design and the floor. Regularized fits (`n > p`, `p > n`, unweighted and with random penalty weights) are checked by the BigFloat objective, the scores of each coordinate and the convexity bound `|F(a) - F(b)| ≤ max(KKT∞(a), KKT∞(b)) ‖a - b‖₁`, against a PGD solve and a tighter PGD reference, each converged and checked by its own independent BigFloat residual. An intercept-only model, an unpenalized fit against a damped Newton reference, strong or almost separated logits and a one-class sample with an unpenalized intercept (finite reporting; a reported stop is checked) have checks of their own. A reported stop is compared with the independent BigFloat residual, with a margin for the rounding of the solver's gradient estimated from the data. The file also covers rollback, the zero solution under `ftol = 0` ([STOP-10](@ref)), overflowed starts, trials and extrapolated points, the counter identities of [APG-04](@ref), allocations against the least-squares control and the refusals before any write. The shared gate, scale and stopping rules are tested in `test/logistic_pgd.jl` ([IN-09](@ref)).

**Sources.** [Issue #501](https://github.com/mlakolar/ProximalSolvers.jl/issues/501), [IN-09](@ref) and the proof in [APG-06](@ref).

## Known limits

The proof assumptions include IEEE arithmetic with gradual underflow and matrix-vector products evaluated as dot products. Native products and extrapolation still use `T`; exponent-separated bound arithmetic does not recover those products. Deep subnormal data can make the absolute error terms dominate, requiring a curvature far above the true curvature or ending in rollback. A curvature above `floatmax(T)` is not certified. Float32 more often needs the fresh-product decision late in a solve. For a logistic loss the factor `¼` ignores the local curvature, so steps can be shorter than the loss allows ([APG-08](@ref)). General coefficient-accuracy limitations are [STOP-12](@ref).

## Tests

`test/accelerated_pgd.jl` uses independent BigFloat references from raw data, rather than agreement with another solver alone. The preserved proof paragraph details the sampled conditions and their limits. `test/elasticnet.jl`, `test/group_pgd.jl` and `test/linf.jl` cover the supported penalties. `test/logistic_apg.jl` covers the logistic loss ([APG-08](@ref)).

## Retired historical wording

### [Retired: unqualified count identities](@id APG-UNRECONCILED)

**Retired by [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).** The quotation below is preserved verbatim as **non-normative historical provenance**. [APG-04](@ref) is the authoritative reporting contract: `prox_calls = backtrack_steps + C_prox`; the older equality holds only for dedicated KKT checks with `C_prox = 0`. With a generic stationarity check, an extra prox evaluation need not represent a line-search trial or objective call. The scoped gradient and objective identities in APG-04 already match the implementation; no counters are changed.

> `backtrack_steps` counts every trial, including the accepted one, so it equals
> `prox_calls`. With `C` the number of stationarity checks of the solve (each evaluates
> `∇f(x)` once, counted in `grad_calls` and not in `f_calls`), `grad_calls = iterations +
> restarts + C` and `f_calls = 1 + grad_calls + prox_calls - C`. Its reported gradient residual
> `L‖x - y‖∞` is a stopping quantity measured from `y`; it is not an independent KKT residual
> at `x` (the check evaluates `∇f(x)` separately).

**Sources.** `docs/src/developer/implementation-notes.md:L320`.

The retired normalized-KKT shorthand remains separately available as [historical evidence](@ref STOP-UNRECONCILED).

## Change log

Relative to `legacy/full`, the dense method removed metric, tuple, owner and generic smooth-loss paths; validates its factors in `T`; retries a nonfinite trial through finite curvature growth; replaces the old rounded-square/8eps cached-image allowance by the proof above; and accepts a finite-value point with `x == y`, where the legacy path raised. A nonfinite extrapolated gradient follows the same restart/failure path as a nonfinite value. These are baseline differences, not changes introduced by this migration.
