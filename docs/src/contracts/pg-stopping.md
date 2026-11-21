# PGD and APG stopping

## Scope

This is the stopping contract for `ProximalGradientDescent` and `AccProxGradDescent` on their supported least-squares problems. See the [support matrix](../support.md). Coordinate descent has its own stopping contract.

## Problem

The shared engine minimizes `F(x) = f(x) + g(x)`, with `f(x) = s‖Xx - y‖²/2`. The penalty determines the stationarity residual below.

## Notation

`T` is the coefficient type, `s` is the loss scale, `x` is the accepted iterate, `x_previous` is the preceding accepted iterate, and `L` is the accepted inverse step. In the retained proof of [STOP-13](@ref), `s` has this same meaning. APG uses `y` for its extrapolated point in algorithm formulas; the response is identified explicitly where needed. `τ` and `S` are defined in [STOP-04](@ref).

## Preconditions and refusals

Input acceptance is specified by [IN-01](@ref). Option validation and reporting are specified by [PGD-04](@ref) and [PGD-05](@ref). A refused stationarity check clears stopping flags; it is not an exception.

## Algorithm

### [STOP-01 A proposed stop is checked at the accepted point](@id STOP-01)

**Statement.** The iterate, objective and gradient/proximal-residual tests combine by **OR**: any one can propose a stop. A proposal counts only if the applicable stationarity check passes at the accepted iterate. Otherwise `x_converged`, `f_converged` and `grad_converged` are all cleared, `converged=false`, and the solve continues unless another exit applies. The residual fields continue to report their diagnostics. The exact-stall rule in [STOP-10](@ref) applies before this proposal is checked.

`converged=true` therefore records a computed working-precision check. It is not an exact-arithmetic certificate, a bound on distance to a minimizer, or a promise of a specified number of correct coefficient digits. PGD and APG use the same acceptance policy; their iteration residuals differ. Independent KKT or duality-gap evaluation is needed to assess a returned point.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** test/stopping_scale.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L56`, `docs/src/numerics.md:L62`, `docs/src/numerics.md:L67`, `docs/src/numerics.md:L80`, `docs/src/numerics.md:L86`, `docs/src/numerics.md:L109`, `docs/src/numerics.md:L123`, `docstring:src/types.jl:L16`, `docs/src/choosing-solver.md:L167`, `docs/src/concepts.md:L64`, `docs/src/getting-started.md:L92`, `docs/src/working-with-results.md:L29`, `docs/src/working-with-results.md:L46`, `README.md:L52`.

## Stopping

### [STOP-02 The three proposal tests](@id STOP-02)

**Statement.** The iterate test is `norm(x - x_previous) < xtol * max(norm(x), 1)`. For `norm(x) < 1`, its threshold is absolute. Its strict inequality and the exact-stall exclusion are intentional.

For `ftol > 0`, the objective test holds if either `abs(F - F_previous) / abs(F) < ftol` or `abs(F - F_previous) < eps(abs(F) + abs(F_previous))`. The quotient is evaluated as a diagnostic in Float64, is `0` when the objectives are equal (including both zero), and is `Inf` when `F = 0 ≠ F_previous`. There is no absolute term in the denominator. The second test holds for equal finite-sum objectives and, when both values are normal and their absolute-value sum is finite, permits a difference of about two units in the last place. If that sum overflows, `eps` is `NaN` and this second test does not hold. Neither form establishes accuracy by itself.

For the gradient test, let `r` be the iteration's gradient/proximal residual, `m` the largest such residual so far, `N = max(‖∇f‖∞, ‖q‖∞)` with `q` the residual of the proximal step, and `ρ = (L * ‖x‖∞) * eps(T)`, the rounding resolution of `L x`. Form `L * ‖x‖∞` first to avoid premature underflow of `L * eps(T)`. If the first product overflows to `Inf`, the resolution comparison rejects both normalizers. APG uses `∇f` and the proximal step at its extrapolated point. The test is

```
(r < gradtol * m  and  ρ < m)   or   (r < gradtol * N  and  ρ < N).
```

The comparisons use the floating-point products `gradtol * m` and `gradtol * N`; neither normalizer has an absolute term. A zero residual passes only against a positive product, so it does not pass when `m = N = 0` or the relevant product underflows to zero. A scale no larger than `ρ` decides nothing. The running maximum is updated even on an exact-stall iteration.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, f_residual, gradient_converged!, _gradient_test`.

**Tests.** test/stopping_scale.jl covers the resolution with tiny `L` and large `x` in Float32 and Float64. See also test/core_regressions.jl and test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L201`, `docs/src/numerics.md:L207`, `docs/src/numerics.md:L211`, `docs/src/numerics.md:L260`, `docs/src/numerics.md:L261`, `docs/src/numerics.md:L262`, `docs/src/numerics.md:L263`, `docs/src/numerics.md:L264`, `docs/src/numerics.md:L265`, `docs/src/numerics.md:L266`, `docs/src/numerics.md:L267`, `docs/src/numerics.md:L268`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L85`, `docstring:src/types.jl:L94`, `docstring:src/types.jl:L109`, `docstring:src/types.jl:L123`.

### [STOP-03 Scalar and weighted lasso residuals](@id STOP-03)

**Statement.** For `NormL1(λ0)`, the residual is the least-infinity-norm element of `∇f(x) + λ ∂‖x‖₁`, with the working level `λ` from [IN-02](@ref). The entry score is `max(|∇fᵢ| - λ, 0)` at `xᵢ = 0` and `|∇fᵢ + λ sign(xᵢ)|` elsewhere. The full-point call is ProximalBase's `kkt_violation` with the working penalty used for the objective. With `NormL1(λ0, w)`, the call is `kkt_violation(NormL1(T(λ0), w), ∇f(x), x)`. Entry `i` uses `cᵢ = T(λ0) wᵢ`, multiplied and rounded in `T`. Its score is `max(|∇fᵢ| - cᵢ, 0)` at zero and `|∇fᵢ + cᵢ sign(xᵢ)|` elsewhere. The `Vector{T}` weights are used as supplied.

The scale is `S = max(λ, λmax)`, where `λ = T(λ0)` without weights and `λ = maxᵢ cᵢ` with weights, and `λmax` is the computed `s‖Xᵀy‖∞`. The equality `maxᵢ cᵢ = T(λ0) * maximum(w)` uses monotonicity of rounding. Unit weights reproduce the unweighted coefficients and scale. All-zero weights remove the penalty and give the least-squares scale `S = λmax`; with zero response as well, the zero-scale rule in [STOP-04](@ref) applies.

For [IN-10](@ref), use the unweighted scores above at every entry of `B`
with `∇f(B) = s Xᵀ(XB − Y)`. Take the largest score over all entries, with
`λmax` the largest absolute entry of the computed `s XᵀY`. Both quantities
use the working arithmetic of the vector test. This is the entrywise maximum
over the full matrix.

For a raw `LogisticLoss`, `∇f` is the logistic gradient and `λmax = ‖Xᵀ(½ - y)‖∞`, the norm of its value at zero ([IN-09](@ref)).

**Entry thresholds with weights.** With `NormL1(λ0, w)` a proposed stop must also hold entry by entry. Let `sᵢ` be ProximalBase's signed entry score `kkt_violation(NormL1(T(λ0), w), ∇f(x), x, i)`: `|∇fᵢ| - cᵢ` at `xᵢ = 0`, which can be negative, and `|∇fᵢ + cᵢ sign(xᵢ)|` elsewhere. The maximum of these scores and zero is the full-point residual above. Each `sᵢ` must be strictly below `τ max(cᵢ, λmax)`, computed in `T`, and that threshold must be at least `floatmin(T)`. A negative score passes any threshold that passes the guard, so clipping at zero does not change the decision.

Each entry threshold is at most `τ S`, so the full-point comparison of [STOP-04](@ref) is necessary, and it is made first. The entries are then compared one by one, stopping at the first failure, only when the full-point comparison passes and the largest coefficient `λ = T(λ0) * maximum(w)` exceeds the computed `λmax`. Otherwise every entry threshold equals `τ S` and the full-point comparison decides alone. A weight vector of ones with `T(λ0) > λmax` takes the entry pass when the full-point comparison passes, but its thresholds all equal `τ S` and its decision is that of `NormL1(λ0)`.

Without the entry pass, one coefficient far above `λmax` (a large weight, or one that excludes a column) would set `S` for every entry, and a free or lightly penalized entry could pass with a derivative of order `τ maxᵢ cᵢ` ([#464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464)). The entry scale `max(cᵢ, λmax)` contains `cᵢ` because near a stationary point a nonzero entry has `|∇fᵢ|` close to `cᵢ`, so its score combines two terms of size about `cᵢ`. It contains `λmax` as the gradient scale of the unweighted rule. In exact arithmetic, a common positive factor on loss and penalty scales every entry threshold and every score alike. In working precision, rounding and the normal-threshold guard can change the outcome, as in [STOP-04](@ref).

A zero-weight coordinate has `cᵢ = 0`, is unpenalized and is scored by its full `|∇fᵢ|`, even with a large `λ0`. It is held to `τ λmax`, the threshold of the unpenalized problem. When the computed `λmax` is zero, its threshold is zero (`NaN` if `τ` is infinite), which fails the guard. No stop then passes, as with all-zero weights ([STOP-04](@ref)), although `x = 0` may be the minimizer. Each coefficient must already satisfy [IN-01](@ref): it is finite and normal when both factors are positive; a zero level or weight gives zero. An infinite coefficient iterate gives a nonfinite residual (`Inf`, or `NaN` if a `NaN` is read), which cannot pass.

**Applies to.** PGD and APG; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks full-matrix scores, the zero-solution threshold and independent accepted-point residuals. `test/core_regressions.jl`, “Working ℓ₁ levels”, checks stopping flags and residuals against explicit working-level controls. See also `test/stopping_scale.jl`, `test/weighted_lasso.jl` and `test/logistic_pgd.jl` (the logistic scale `‖Xᵀ(½ - y)‖∞` and independent KKT scores). `test/entry_thresholds.jl` checks the entry thresholds. Its fixtures are the #464 least-squares and logistic cases against analytic minimizers; zero columns, excluded columns, free and tiny weights; an active entry with a coefficient far above `λmax`; ill-conditioned designs; zero weights with `∇f(0)` approximately zero in the free entry or `y = 0`; and ordinary-weight controls on which the single threshold decides. Converged trajectory solves are checked entry by entry against a BigFloat residual; the zero-response solve with positive weights is checked against its exact minimizer `x = 0` instead. The rule is checked at fixed points against its definition, including points where the single threshold accepts and the entry thresholds reject.

**Sources.** `docs/src/numerics.md:L86`, `docs/src/numerics.md:L145`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L23`.

### [STOP-16 Nonnegative-lasso residual and scale](@id STOP-16)

**Statement.** For unweighted `NormL1Nonneg(λ0)`, PGD checks the accepted point with ProximalBase's full-point `kkt_violation` using the working penalty from [IN-02](@ref). For `IndNonnegative()`, PGD uses `NormL1Nonneg(zero(T))` for the check because both penalties have the same value and normal cone on the feasible set. With `λ` the level of that penalty, the entry score is `abs(∇f(x)[j] + λ)` when `x[j] > 0`, and `max(-(∇f(x)[j] + λ), 0)` when `x[j] == 0`. The residual is the maximum entry score. An infeasible point has residual `Inf` and cannot pass. A positive derivative at a zero coordinate can satisfy constrained stationarity.

The scale is `S = max(λ, λmax)`, where `λmax` is the computed symmetric magnitude `s‖Xᵀy‖∞`. This is not the one-sided penalty level at which zero solves the constrained problem. Apply the computed threshold, tolerance floor, strict comparison and scale guards of [STOP-04](@ref). Passing records a computed residual check, with the working-precision limitations of [STOP-12](@ref).

**Applies to.** ProximalGradientDescent with unweighted `NormL1Nonneg` or `IndNonnegative()`; dense Vector{T}; T = Float32 or Float64. The feasible-start requirement and unsupported combinations are specified in [IN-07](@ref).

**Code.** `src/utils.jl`: dedicated `_stationary!`, `_converted_penalty`, `_l1_level`, `_scale_norm` and `_lambda_max!`.

**Tests.** `test/core_regressions.jl`, “Working ℓ₁ levels”, checks stopping flags and residuals with subnormal and ordinary levels in both precisions. `test/nonnegative_lasso.jl` checks zero and positive starts, inactive-coordinate KKT, correlated designs, independent residuals and objectives, and refusals. `test/nonnegative_least_squares.jl` checks both precisions against independent gradients and objectives, including a positive derivative at a positive coefficient that must veto an objective-change stopping proposal.

**Sources.** Current-source addition after the historical migration baseline: upstream `fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8`, [`src/utils.jl` dedicated check and constrained-residual rule](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L141-L156), [level conversion](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L232-L233), and [`test/nonnegative_lasso.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/test/nonnegative_lasso.jl#L12-L67).

### [STOP-04 Threshold arithmetic and scale guards](@id STOP-04)

**Statement.** For a dedicated KKT check, form `τ = T(max(gradtol, 64 eps(T)))` and `threshold = τ * S` in `T`. The stop passes precisely when `S` is finite, `threshold ≥ floatmin(T)`, the computed residual is finite, and that residual is **strictly below** `threshold`. The scale and residual are penalty-specific ([STOP-03](@ref), [STOP-05](@ref), [STOP-06](@ref), [STOP-16](@ref)).

The threshold need not be finite: a huge `gradtol` can make conversion or multiplication produce `Inf`, and a finite residual then passes. Dividing the residual by `S` and comparing with the unrounded tolerance is the exact-arithmetic interpretation, not an additional floating-point guarantee. A `gradtol` below `64 eps(T)`, including `gradtol = 0`, uses that floor.

Common positive rescaling of loss and penalty preserves the normalized inequality in exact arithmetic. In working precision the rounded quantities and the normal-threshold guard can change the outcome even when the scales remain representable. For Float32 `X = [1]`, response `y = [1]`, `x = 0` and default `gradtol`, `s = λ = 1` passes while `s = λ = 1f-35` does not: the latter threshold is below `floatmin(Float32)`.

With weights, the entry thresholds of [STOP-03](@ref) and [STOP-05](@ref) must also hold, under the same strict comparison and normal-threshold guard. If both `λ` and `λmax` are zero, or the threshold is below `floatmin(T)`, no stop passes; the solve reaches `maxiter` unless another exit intervenes. For the unweighted lasso, starting at `x = 0` with `λ ≥ λmax` gives `G = 0` and stops at the first proposal when `S > 0` and the normal-threshold guard holds. Under `ftol = 0`, the unchanged iterate makes no proposal and can instead run to `maxiter` with `converged=false`.

**Applies to.** PGD and APG; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks accepted stops and the zero-scale guard. test/stopping_scale.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L86`, `docs/src/numerics.md:L105`, `docs/src/numerics.md:L109`, `docs/src/numerics.md:L123`, `docs/src/numerics.md:L127`, `docs/src/numerics.md:L135`, `docs/src/numerics.md:L137`, `docs/src/numerics.md:L142`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L23`, `docs/src/choosing-solver.md:L167`. The later NormL1Nonneg dispatch uses the same guards in [upstream `fd45a427`, `_stationary!`](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L141-L156).

### [STOP-05 Group residual and group scale](@id STOP-05)

**Statement.** For `GroupNormL2{T}(λ0, groups, w)` whose groups partition `1:p`, let `cₖ = T(λ0) wₖ` rounded in `T`. The residual is ProximalBase's `kkt_violation(g, ∇f(x), x) = max(0, maxₖ scoreₖ)`. A group with any nonzero entry has score `‖∇_G f + cₖ x_G/‖x_G‖₂‖₂`; a zero group has score `‖∇_G f‖₂ - cₖ`. A zero weight gives `‖∇_G f‖₂`.

Use `S = max(maxₖ cₖ, Λ)`, where `Λ = maxₖ ‖[∇f(0)]_{Gₖ}‖₂`, the computed group counterpart of `s maxₖ ‖[Xᵀy]_{Gₖ}‖₂`. In exact arithmetic zero is a minimizer iff each group norm of `∇f(0)` is no larger than its own coefficient. The guards and computed threshold are [STOP-04](@ref). As for weighted `NormL1` ([STOP-03](@ref)), each group must also have its score strictly below `τ max(cₖ, Λ)`, computed in `T`, a threshold of at least `floatmin(T)`. The score is ProximalBase's `kkt_violation(g, ∇f(x), x, i)` for an entry `i` of the group; it is signed at a zero group. The groups are compared one by one only when `maxₖ cₖ > Λ`, after the full-point comparison. A zero-weight group is held to `τ Λ`.

Each group norm is LinearAlgebra's `norm`: it scales a block before squaring when squaring its largest magnitude underflows to zero. This prevents the squaring operation alone from losing `Λ`, as tested at a scale `s = 1e-300`; it cannot recover an entry of `s Xᵀy` already rounded to zero or a subnormal value. Singleton groups with unit weights have the unweighted lasso's scale where no entry of `∇f(0)` has a subnormal square. The two penalties' iterates and residuals can still differ through rounding. Passing bounds the computed residual, not the exact residual.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** test/group_pgd.jl: group-check threshold and state.λmax testsets. test/entry_thresholds.jl: the #464 analogue with singleton groups, and an excluded group on an orthogonal design against the block soft threshold.

**Sources.** `docs/src/numerics.md:L155`, `docstring:src/types.jl:L23`, `docs/src/support.md:L222`.

### [STOP-06 Elastic-net residual and ridge-independent scale](@id STOP-06)

**Statement.** For `ElasticNet(λ1, λ2)`, use the least-infinity-norm element of `∇f(x) + T(λ2)x + T(λ1)∂‖x‖₁`: `max(|∇fᵢ| - T(λ1), 0)` at zero and `|∇fᵢ + T(λ2)xᵢ + T(λ1)sign(xᵢ)|` elsewhere. ProximalBase's `kkt_violation(ElasticNet(T(λ1), T(λ2)), ∇f(x), x)` receives both levels converted once to `T`.

The scale is `S = max(T(λ1), λmax)` and contains neither `λ2` nor `λ2‖x‖∞`. In exact arithmetic the problem is the lasso at level `λ1` on `X̃ = [√s X; √λ2 I]`, `ỹ = [√s y; 0]`: its squared-error loss is `s‖Xx-y‖²/2 + λ2‖x‖²/2`, its gradient adds `λ2 x`, and its `λ̃max = s‖Xᵀy‖∞`. This explains the same scale covariance under a common positive factor on `s`, `λ1` and `λ2`.

With `ElasticNet(0, λ2)` and zero response, computed `S = 0` refuses all stops even though zero is the ridge solution; the solve can run to `maxiter` with `converged=false`, as `NormL1(0)` does at zero response unless another exit applies. The relevant zero is the *computed* scale. For `X = reshape(Float32[2^24, 1, -2^24, -1], 4, 1)` and `y = ones(Float32, 4)`, the exact `Xᵀy = 0` need not give a computed `λmax = 0`: summation in that order can produce `λmax = 1`, because `2^24 + 1` rounds to `2^24`. The resulting check can pass at a point whose exact-data residual is not small relative to computed `S`.

Initialization can accept finite `f(x0)` with `g(x0)` overflowing in `T` (for example the ridge term `(λ2/2)‖x0‖²` above `floatmax(T)`); the common start and rollback policy is [RES-01](@ref). This KKT check is not the change test used by `CDSolver` on a dense vector or a one-dimensional `SparseIterate`.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** test/elasticnet.jl: residual conversion, stopping honesty, ridge zero-scale and overflowing-start testsets.

**Sources.** `docs/src/numerics.md:L86`, `docs/src/numerics.md:L168`, `docstring:src/types.jl:L23`, `docs/src/developer/implementation-notes.md:L286`, `README.md:L79`.

### [STOP-07 Generic proximal-gradient stationarity check](@id STOP-07)

**Statement.** For a supported penalty without a dedicated KKT check (currently `NormLinf`, `IndBox` including `IndBallLinf`, and `IndBallL2`), use the accepted inverse step `L`, `t = 1/L`, and

```
p = prox_{t g}(x - t ∇f(x))
r = ‖x - p‖∞ / t
S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞)
```

The proximal evaluation uses the iterations' ProximalBase `value_and_prox!`. Form the threshold in `T` as in [STOP-04](@ref), and require finite `S` and `r`, a threshold at least `floatmin(T)`, and `r < threshold`. In addition, `t` must be finite and positive; `threshold` must strictly exceed `ρ = L eps(T) ‖x‖∞`; and `t * threshold` must be at least `floatmin(T)/eps(T)`. The last guard excludes a step that subnormal rounding can lose at zero. A zero scale, for example `X = 0` or `x = 0` with zero response, cannot pass.

A small accepted `L` makes `t` large and this mapping a weaker stationarity measure than one formed with true curvature; a penalty whose own curvature is far above `L` is an extreme case. Passing remains a working-precision indication, with no coefficient-distance certificate. The check requires only the penalty's prox; that does not itself authorize an unsupported penalty.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** test/linf.jl: boundary, guards, counters, buffers and tiny-curvature testsets.

**Sources.** `docs/src/numerics.md:L226`, `docs/src/numerics.md:L228`, `docs/src/numerics.md:L234`, `docs/src/numerics.md:L238`, `docs/src/numerics.md:L245`, `docstring:src/types.jl:L75`, `docs/src/working-with-results.md:L46`.

### [STOP-08 Work and counters for a proposed stop](@id STOP-08)

**Statement.** Checks run only when a proposal survives the exact-stall rule. PGD already holds `∇f(x)`. APG holds the gradient at its extrapolated point and computes `∇f(x)` from cached `A x`, using the same gradient oracle and preallocated `xhat` and `dz` buffers. Those buffers are overwritten before their next iteration use. This adds one transposed product per APG check that reaches this evaluation, counted in `grad_calls` and not in `f_calls`. A generic check with invalid `t` returns before computing `λmax`, this gradient or the prox.

`λmax` is computed once per solve at the first check that reaches that stage, by one product of `Xᵀ` with the loss's zero-point vector (`Xᵀy` for least squares, `Xᵀ(½ - y)` for the logistic loss of [IN-09](@ref)), and stored in state field `λmax`; that product is not counted. Weighted lasso adds two scans of `w` to the KKT pass: one maximum scan and one scan in construction of the penalty with converted level. When the largest coefficient exceeds `λmax` (`Λ` for groups), a check that passes the full-point comparison adds one more traversal of the entries (of the groups for `GroupNormL2`) with ProximalBase's per-entry score, ending at the first failed comparison ([STOP-03](@ref), [STOP-05](@ref)). It creates no coefficient array. With groups given as vectors of `Int` indices or as ranges it allocates nothing. Other accepted group layouts (abstractly typed containers, or non-`Int` index types) can allocate in ProximalBase's group scorer during this pass, including some for which the full-point group residual allocates nothing.

Each generic check with finite positive `t` adds one proximal evaluation, counted in `prox_calls`; APG additionally counts its gradient at `x`. These costs accrue before call limits are tested. The generic check restores its scratch `delta_x` to `x - x_previous` before the remaining diagnostics read it.

The dedicated nonnegative-penalty check [STOP-16](@ref) uses PGD's held gradient and does not add a proximal evaluation.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: _lambda_max!, _gradient_at_x!, _stationary!`.

**Tests.** test/stopping_scale.jl; test/weighted_lasso.jl; test/linf.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L145`, `docs/src/numerics.md:L194`, `docs/src/numerics.md:L238`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L23`, `docstring:src/types.jl:L75`. The later NormL1Nonneg check follows [upstream `fd45a427`, `_stationary!`](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L141-L156).

### [STOP-09 Objective increases and simultaneous result flags](@id STOP-09)

**Statement.** With `F = f(x) + g(x)` and `allow_f_increases=false`, the first iteration with computed `F > F_previous` ends the solve. This exit is not a convergence test. With `allow_f_increases=true`, it is removed, while `f_increased` still reports the final iteration's comparison.

At any exit the flags describe that same iteration:

| Field | Meaning |
| --- | --- |
| `x_converged`, `f_converged`, `grad_converged` | Their proposal tests in [STOP-02](@ref) held, subject to [STOP-10](@ref), and the stationarity check passed. |
| `converged` | The OR of those three flags. |
| `f_increased` | `F > F_previous`. |
| `iteration_converged` | `iterations == maxiter`; a limit flag, not success. |
| `stagnated` | The condition in [STOP-11](@ref); it can coincide with a call limit, iteration limit or callback stop. |

An increase normally exits with `converged=false`; it can coexist with `converged=true` if a proposal and its check pass at that iteration. In particular, with `ftol > 0`, an increase smaller than about two ulps in the ordinary finite-sum range can pass the objective test. With `ftol = 0`, only the iterate or gradient proposal can produce convergence at an increase. A successful proposal on the last allowed iteration sets both `converged=true` and `iteration_converged=true`. An increase exit on that iteration also sets the latter flag.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment; src/solve.jl: _solve_gradient!`.

**Tests.** test/stopping_scale.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L249`, `docs/src/numerics.md:L251`, `docs/src/numerics.md:L257`, `docs/src/numerics.md:L260`, `docs/src/numerics.md:L261`, `docs/src/numerics.md:L262`, `docs/src/numerics.md:L263`, `docs/src/numerics.md:L264`, `docs/src/numerics.md:L265`, `docs/src/numerics.md:L266`, `docs/src/numerics.md:L267`, `docs/src/numerics.md:L268`, `docs/src/numerics.md:L270`, `docs/src/numerics.md:L274`, `docs/src/numerics.md:L282`, `docs/src/numerics.md:L287`, `docstring:src/types.jl:L140`.

### [STOP-10 Disabling the objective test and recognizing an exact stall](@id STOP-10)

**Statement.** `ftol` is finite and nonnegative; `-0.0` is stored as `0.0`. A positive value that rounds to zero in Float64 is refused. `ProximalOptions(ftol=0)` turns off both objective-test forms and makes `f_converged=false` at every iteration; the reported `f_residual` is still computed. It does not disable objective-increase or limit exits, and the remaining proposals still require stationarity checks.

Only under `ftol = 0`, an accepted iterate equal to the previous iterate entrywise by value (`-0.0 == 0.0`) sets neither `x_converged` nor `grad_converged`. A difference in any entry is assessed normally, even if its norm rounds to zero. With `ftol > 0`, an unchanged iterate can propose an iterate stop, which is then checked.

A stall can end if `1/L` changes, or for APG if the extrapolated point changes. Neither must change, for example at a zero step or with APG `α = 1`. A permanently unchanged point with no separate exit reaches `maxiter` with `converged=false` and `iteration_converged=true`; this reports no progress, not that the point is wrong. Zero with an unweighted lasso level at least `norm(∇f(0), Inf)` is an example of a solution that can remain unchanged.

For APG, an extrapolated point equal to the accepted point while the accepted point differs from its predecessor is **not** a stall. Its iteration residual `L * maximum(abs, x - y)` is zero. The gradient proposal then holds when `0 < gradtol * N` and `ρ < N`, or `0 < gradtol * m` and `ρ < m`, after which stationarity is checked.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/types.jl: ProximalOptions; src/utils.jl: convergence_assessment, _unchanged`.

**Tests.** test/stopping_scale.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L310`, `docs/src/numerics.md:L312`, `docs/src/numerics.md:L374`, `docstring:src/types.jl:L94`, `docstring:src/types.jl:L109`, `docstring:src/types.jl:L123`.

### [STOP-11 Float32 PGD stagnation exit](@id STOP-11)

**Statement.** Under `ftol = 0`, `ProximalGradientDescent` on `Float32`
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

**Applies to.** ProximalGradientDescent; Vector{Float32}; ftol = 0.

**Code.** `src/solvers/proximal_gradient_descent.jl: _stagnated; src/solve.jl: _solve_gradient!`.

**Tests.** test/core_regressions.jl: PGD stagnation testsets.

**Sources.** `docs/src/numerics.md:L393`, `docstring:src/types.jl:L123`, `docstring:src/types.jl:L140`, `docstring:src/types.jl:L335`.

## Postconditions

The flags above have their final-iteration meanings even when another exit also applies. Minimizer ownership, failure mutation and result fields are specified by [RES-01](@ref); trace and limit sequencing are [PGD-04](@ref).

## Floating-point rules

### [STOP-14 Computed objective changes near a minimizer](@id STOP-14)

**Statement.** An accepted step with the default `Lexact = Inf` has the non-increase property in exact arithmetic described by the baseline line-search analysis. The computed objective can rise through rounding. Near a minimizer the true per-step change can be smaller than evaluation error, so the sign of the computed change is controlled by rounding.

At tolerances near or beyond working precision, success versus an objective-increase exit can depend on the starting point, CPU vector width, BLAS kernel and compilation (including coverage instrumentation), even when point accuracy is similar. The tests encounter this especially in Float32. An objective proposal may be refused by stationarity, followed by an increase exit before the residual reaches its bound. Check the returned point independently in either case; the historical measurements are in [strict-accuracy evidence](evidence/strict-accuracy-config.md).

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment; src/line_searches.jl: backtrack!`.

**Tests.** test/core_regressions.jl; test/accelerated_pgd.jl.

**Sources.** `docs/src/numerics.md:L217`, `docs/src/numerics.md:L291`, `docstring:src/types.jl:L140`.

## Known limits

### [STOP-12 Accuracy interpretation and strict-option examples](@id STOP-12)

**Statement.** Defaults `maxiter=200`, `ftol=1e-6`, `xtol=1e-8` and `gradtol=1e-5` are exploratory settings. Tightening them does not establish a specified error, and reducing `gradtol` below the floor in [STOP-04](@ref) does not tighten that computed check. The residual uses rounded gradient products: underflow or cancellation can make a nonstationary point pass. A coordinate on a much smaller gradient scale than `λmax` can remain inaccurate even when the global relative residual is small. In particular `λmax = ‖∇f(0)‖∞` is measured at zero. When a free coordinate is far from zero at the solution, as an intercept is with an uncentered (offset) response, its entry of `∇f(0)` can make `λmax`, and so every threshold, much larger than the gradients near the solution. `converged = true` can then be reported with a materially wrong objective. The entry thresholds of [STOP-03](@ref) do not change this; measured cases are in the [entry-threshold evidence](@ref evidence-entry-thresholds-464). Centering the response can help when the inflated entry belongs to an intercept. A smaller `gradtol` can help while it stays above the floor `64 eps(T)`. Neither is a general remedy. The defect is tracked in [#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487). See [working precision](working-precision.md) and [stopping evidence](evidence/stopping-audit-352.md).

For PGD, `xtol` bounds a step scaled by `1/L`; the implied proximal-gradient residual is roughly `L * xtol * max(norm(x), 1)`, depending on curvature, coefficient scale and penalty level. Even `xtol = 1e-300` can accept a nonzero step, such as from `[0.0]` to `[1e-310]`. It is not an accuracy target.

The historical configuration below is a **test configuration**, not a general recipe. Its measurements, including the fact that they predate the stationarity check, are retained in [strict-accuracy evidence](evidence/strict-accuracy-config.md).

```julia
ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true,
                xtol = 1e-300, gradtol = 1e-11)
```

With the objective test disabled, the default objective-increase exit still applies unless `allow_f_increases=true`. Neither the option combination nor a stagnation flag provides an accuracy certificate.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** Existing stopping and numerical-regression tests; historical measurements are evidence, not a new test requirement.

**Sources.** `docs/src/numerics.md:L67`, `docs/src/numerics.md:L80`, `docs/src/numerics.md:L186`, `docs/src/numerics.md:L329`, `docs/src/numerics.md:L331`, `docs/src/numerics.md:L336`, `docs/src/numerics.md:L356`, `docs/src/numerics.md:L363`, `docs/src/choosing-solver.md:L120`, `docs/src/choosing-solver.md:L167`, `docstring:src/solvers/proximal_gradient_descent.jl:L30`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`, `docs/src/working-with-results.md:L29`, `docs/src/working-with-results.md:L46`, `README.md:L52`.

### [STOP-13 Independent lasso gap bound](@id STOP-13)

**Statement.** **A check of a lasso solution.** Let `f(x) = s‖y - Xx‖²/2` with `s > 0` and
`g(x) = λ‖x‖₁` with `λ > 0` (an unweighted `NormL1`), let `F = f + g`, and let
`G` be the element of `∇f(x) + λ ∂‖x‖₁` of smallest infinity norm, which is the
[independent KKT residual](../learn/02-optimality-kkt.md). Put `k = norm(G, Inf) / λ`.
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

**Applies to.** Unweighted NormL1; positive loss scale s, positive λ, and positive objective F(x).

**Code.** `Analytic statement; no new solver certificate is implemented`.

**Tests.** No implementation change; the stated exact-arithmetic derivation is retained for independent numerical checks.

**Sources.** `docs/src/numerics.md:L423`, `docs/src/numerics.md:L431`, `docs/src/numerics.md:L435`.

### [STOP-15 An accurate fixed point may remain unreported](@id STOP-15)

**Statement.** Under `ftol = 0`, an unchanged accepted iterate proposes no stop, so no stationarity check is requested there. The solve can reach `maxiter` or a stagnation exit with `converged=false` even when the exact KKT residual is below the bound. This is intentional retained behavior. Evaluate the returned point independently; with `ftol > 0`, the unchanged iterate can propose a stop and the stationarity check decides.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment; src/solvers/proximal_gradient_descent.jl: _stagnated`.

**Tests.** test/core_regressions.jl: exact optimum and strict stagnation cases; test/accelerated_pgd.jl: unchanged iterate under ftol = 0.

**Sources.** `docs/src/stopping-limits.md:L397`, `docs/src/stopping-limits.md:L399`, `docs/src/stopping-limits.md:L427`, `docs/src/numerics.md:L928`.

## Tests

The clause-level references identify existing tests; this relocation adds no solver behavior or test obligation. Important suites are `test/stopping_scale.jl`, `test/weighted_lasso.jl`, `test/nonnegative_lasso.jl`, `test/elasticnet.jl`, `test/group_pgd.jl`, `test/linf.jl`, `test/core_regressions.jl` and `test/accelerated_pgd.jl`.

## Retired historical wording

### [Retired: normalized-inequality shorthand](@id STOP-UNRECONCILED)

**Retired by [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).** The baseline quotations below remain verbatim as **non-normative historical evidence**, not current stopping guarantees. The authoritative dedicated KKT rule is [STOP-04](@ref): form `τ = T(max(gradtol, 64 eps(T)))` and `threshold = τ * S` in the working type, require a finite scale and residual, `threshold ≥ floatmin(T)`, and compare `residual < threshold` strictly. The product may round or overflow to `Inf`. No separately divided, unrounded normalized inequality is checked or guaranteed. The generic mapping check has the additional guards of [STOP-07](@ref). This reconciliation changes no numerical behavior.

From `README.md`, baseline lines 57–58:

> correct digits.** It guarantees only that the computed, normalized residual `‖G‖∞ / max(λ, λmax)` is below
> `max(gradtol, 64eps(T))`, with the threshold formed in `T`; it does not

From `docs/src/working-with-results.md`, baseline lines 33–36:

> working-precision value. `converged = true` guarantees only that the computed,
> normalized KKT residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64eps(T))` (the
> threshold is formed in `T`, where it can round or overflow; see
> [the stationarity check](../numerics.md)). It is not

From `src/types.jl`, baseline lines 60–64:

> precision the conversion to `T` and the product can round, or overflow to `Inf` for a huge
> `gradtol`, in which case a finite residual passes against the infinite threshold.
> `converged = true` guarantees only that the computed, normalized KKT residual
> `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))`, in that sense. It is not an exact-arithmetic
> certificate, it does not bound the distance to a minimizer, and it does not guarantee

From `src/solvers/proximal_gradient_descent.jl`, baseline lines 37–40:

> [`ProximalOptions`](@ref) applies instead. For `NormL1`, `ElasticNet` and `GroupNormL2`, `converged=true` guarantees
> only that the computed, normalized KKT
> residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the threshold is formed in
> `T`, which can round or overflow; see [`ProximalOptions`](@ref)); it is not an

From `src/solvers/accelerated_proximal_gradient_descent.jl`, baseline lines 53–56:

> generic proximal-gradient check of [`ProximalOptions`](@ref) applies instead. For `NormL1`, `ElasticNet` and `GroupNormL2`, `converged = true` guarantees only that the
> computed, normalized KKT residual `‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the
> threshold is formed in `T`, which can round or overflow; see [`ProximalOptions`](@ref)). It is
> not an exact-arithmetic certificate and does not guarantee coefficient accuracy on

The older introductory limitation to PGD for group lasso is also **retired**: [IN-01](@ref) and [STOP-05](@ref) cover `GroupNormL2` with both PGD and APG. The original, internally inconsistent introductory wording is preserved here:

> PGD and APG verify a proposed stop; this section is the check for `NormL1`, `ElasticNet` and, with PGD,
> `GroupNormL2` (the **Groups** item below), and other penalties use [the generic stationarity check](@ref "The generic stationarity check"). At an iteration at which the `x`, `f` or

**Sources.** `README.md:L52`, `docs/src/working-with-results.md:L29`, `docstring:src/types.jl:L23`, `docstring:src/solvers/proximal_gradient_descent.jl:L30`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`, `docs/src/numerics.md:L86`.

## Change log

[#464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464): weighted `NormL1` holds each entry to `τ max(cᵢ, λmax)` when its largest coefficient exceeds `λmax` ([STOP-03](@ref)), and `GroupNormL2` holds each group to `τ max(cₖ, Λ)` when its largest coefficient exceeds `Λ` ([STOP-05](@ref)); see also [STOP-04](@ref) and [STOP-08](@ref). Otherwise the decisions are unchanged. The offset-response limitation is stated in [STOP-12](@ref). Measurements: [entry-threshold evidence](evidence/entry-thresholds-464.md).

This migration consolidates the baseline stopping specifications without changing solver logic. Historical strict-configuration results remain separate from the current contract. The historical normalized-residual and group-support formulations were retired under [#416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416); the original quotations and anchor remain available for provenance.
