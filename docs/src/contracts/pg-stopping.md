# PGD and APG stopping

## Scope

This is the stopping contract for `ProximalGradientDescent` and `AccProxGradDescent` on their supported least-squares problems. See the [support matrix](../support.md). Coordinate descent has its own stopping contract.

## Problem

The shared engine minimizes `F(x) = f(x) + g(x)`, with `f(x) = s‖Xx - y‖²/2`. The penalty determines the stationarity residual below.

## Notation

`T` is the coefficient type, `s` is the loss scale, `x` is the accepted iterate, `x_previous` is the preceding accepted iterate, and `L` is the accepted inverse step. In the retained proof of [STOP-13](@ref), `s` has this same meaning. APG uses `y` for its extrapolated point in algorithm formulas; the response is identified explicitly where needed. `τ` and `S` are defined in [STOP-04](@ref); the coordinatewise thresholds of least squares with `NormL1` or `ElasticNet` are defined in [STOP-21](@ref).

## Preconditions and refusals

Input acceptance is specified by [IN-01](@ref). Option validation and reporting are specified by [PGD-04](@ref) and [PGD-05](@ref). A refused stationarity check clears stopping flags; it is not an exception.

## Algorithm

### [STOP-01 A proposed stop is checked at the accepted point](@id STOP-01)

**Statement.** The iterate, objective and gradient/proximal-residual tests combine by **OR**: any one can propose a stop. A proposal counts only if the applicable stationarity check passes at the accepted iterate. Otherwise `x_converged`, `f_converged` and `grad_converged` are all cleared, `converged=false`, and the solve continues unless another exit applies. The residual fields continue to report their diagnostics. The exact-stall rule in [STOP-10](@ref) applies before this proposal is checked.

`converged=true` therefore records a computed working-precision check. It is not an exact-arithmetic certificate, a bound on distance to a minimizer, or a promise of a specified number of correct coefficient digits. PGD and APG use the same acceptance policy; their iteration residuals differ. Independent KKT or duality-gap evaluation is needed to assess a returned point.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** test/stopping_scale.jl; test/stopping_coordinatewise.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

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

### [STOP-21 Coordinatewise stationarity for least squares with `NormL1` or `ElasticNet`](@id STOP-21)

**Statement.** **What a kept stop establishes.** For least squares with `NormL1` or `ElasticNet` on a dense vector, a kept stop says that every coordinate passed the comparison of its computed KKT score in the rule below: below its computed threshold, or at most `0` where its scale is an exact zero. In exact arithmetic, for the exact scores and thresholds, that is approximate coordinatewise KKT stationarity relative to the smooth part `Φ` of the objective: no single coordinate can lower `F` by more than `τ²Φ(x)`. It is not a bound on the error of the objective or of the coefficients. An ill-conditioned or rank-deficient problem can pass with a meaningful error; with `H = sXᵀX + λ2 I` positive definite, the relative objective error is below `τ² tr(H)/λ_min(H)` in exact arithmetic, a bound that is large when `H` is ill-conditioned. An exact or near-exact fit can return `converged = false` at an accurate point, and in `Float32` the rounding of the gradient can prevent the check from passing at an accurate point.

**Problem and scores.** The objective is `F(x) = (s/2)‖Xx - y‖² + Σᵢ cᵢ|xᵢ| + (λ2/2)‖x‖²`, with the loss scale `s` (`s = 1` for a raw loss) and the working penalty `gT` of [IN-02](@ref) and [IN-03](@ref): `cᵢ = T(λ)` for `NormL1(λ)` and `T(λ) wᵢ` rounded in `T` for `NormL1(λ, w)`, `cᵢ = T(λ1)` or `T(λ1) wᵢ` for `ElasticNet`, `λ2 = T(λ2)` for `ElasticNet` and `0` for `NormL1`. The score of coordinate `i` is ProximalBase's signed `Gᵢ = kkt_violation(gT, ∇f(x), x, i)`: `|∇fᵢ| - cᵢ` at `xᵢ = 0`, negative when `|∇fᵢ| < cᵢ`, and `|∇fᵢ + λ2 xᵢ + cᵢ sign(xᵢ)|` otherwise. A zero weight gives `cᵢ = 0`, so a zero-weight coordinate is scored by its full `|∇fᵢ|` at zero and `|∇fᵢ + λ2 xᵢ|` elsewhere. `∇f(x)` is the gradient that PGD holds and that APG forms at the accepted point ([STOP-08](@ref)).

**Thresholds.** With `τ = T(max(gradtol, 64 eps(T)))`, `a = Float64(s)`, `nᵢ = ‖Xᵢ‖` (the column norm) and `Φ = f(x) + (λ2/2)‖x‖²`, where `f(x)` is the loss value that ProximalBase computed at the accepted point ([FP-01](@ref)), the threshold of coordinate `i` is `tᵢ = T(τ hᵢ ρ)`, with `hᵢ = √(a nᵢ² + λ2)` and `ρ = √(2Φ)`. In exact arithmetic `τ hᵢ ρ = τ √(2μᵢΦ)` with `μᵢ = s nᵢ² + λ2`.

**Rule.** A proposed stop is kept when every coordinate passes, in one pass that ends at the first failure:

1. **Exact zero scales.** (A) When `λ2 = 0` and column `i` is identically zero, coordinate `i` passes when `Gᵢ` is finite and at most `0`. A zero column gives a computed `∇fᵢ = ±0` for a finite residual, so `Gᵢ = -cᵢ` at `xᵢ = 0` and `cᵢ` elsewhere: it passes when `xᵢ = 0` or `cᵢ = 0`. (B) When `x = 0` and `y = 0` elementwise, every coordinate passes when its score is finite and at most `0`; there `F(0) = 0` is the minimum and the computed gradient is `0`. Case A is decided by the class of the column, stored by the column pass, and case B by testing `x` and `y` for zeros when the computed `ρ` is `0`; neither is inferred from a computed threshold of `0`.
2. **Every other coordinate** passes when `Gᵢ` is finite, `tᵢ` is finite and at least `floatmin(T)`, and `Gᵢ < tᵢ`.

The other zero, underflowed and nonfinite thresholds refuse the stop. (C) A computed `Φ = 0` at a point other than `x = 0, y = 0` gives `tᵢ = 0` for each coordinate outside case A: a computed residual can round to `0` at a point that does not fit the stored data exactly. (D) A nonzero column whose `Float64` sum of squares is below `floatmin(Float64)` (only `Float64` data, with entries below about `1.5e-154` in magnitude) refuses, with or without a ridge term; so does a threshold whose `Float64` product rounds to `0` or below `floatmin(T)` in `T`, or to `Inf`, and a nonfinite `nᵢ`, `Φ` or `τ`. In particular a `gradtol` whose conversion `T(gradtol)` is `Inf` (`Float32` and `gradtol > floatmax(Float32)`), or whose product with `hᵢ ρ` overflows, refuses at every coordinate outside cases A and B; the acceptance of an infinite threshold in [STOP-04](@ref) does not apply. No absolute floor or replacement scale is used.

**Arithmetic.** At the first check of a solve one pass over the columns forms `Float64` sums of squares, which are exact for `Float32` entries, classifies each column as zero, underflowed (case D) or ordinary, and forms `hᵢ = hypot(√a nᵢ, √λ2)`; a column whose sum overflows (for example with an entry above about `1.3e154`) has its norm recomputed in the scaled form `m √Σ(Xⱼᵢ/m)²`, `m = maxⱼ |Xⱼᵢ|`. The same pass scans `y` for zeros. At each check `ρ = √2 √f(x)`, combined for `λ2 > 0` with `√λ2 ‖x‖` by `hypot`, where `‖x‖` is a `Float64` sum of squares, recomputed in scaled form when it overflows. Neither `μᵢΦ`, `2Φ` nor `λ2‖x‖²` is formed: `hᵢ` is finite when `√a nᵢ` is, and `ρ` when `f(x)` and `√λ2 ‖x‖` are. The product `(τ hᵢ) ρ` can still overflow where the threshold would be representable, when `τ > 1` or a factor is near `floatmax(Float64)`; that refuses (D). The product is formed in `Float64` and rounded once to `T`: a score up to half a unit in the last place of `T` above the `Float64` product can pass, unlike the threshold of [STOP-04](@ref), which is a product rounded in `T`.

**Meaning.** In exact arithmetic `t ↦ F(x + t eᵢ)` is `μᵢ`-strongly convex, and `max(Gᵢ, 0)` is its least-norm subgradient at `t = 0`, so the decrease of `F` available from coordinate `i` alone is at most `max(Gᵢ, 0)²/(2μᵢ)`, below `τ²Φ` when `Gᵢ < τ√(2μᵢΦ)`. For `λ2 = 0` and `cᵢ = 0` the test is `|Xᵢᵀr| < τ ‖Xᵢ‖ ‖r‖`, `r = Xx - y`: the cosine of column `i` and the residual. `ElasticNet` is the lasso with the same coefficients on `[√s X; √λ2 I]` and `[√s y; 0]`, and `hᵢ ρ` is the same product for the augmented column and residual. When `λ_min(H) > 0`, `‖G‖₂² < 2τ²Φ tr(H)` and, since `Φ ≤ F`, `(F(x) - F*)/F(x) < τ² tr(H)/λ_min(H)`. These bounds do not change when a free intercept absorbs an offset of `y`, or under a common positive scaling of `(y, c)` or of `(s, c, λ2)`, and for `λ2 = 0` the test of a coordinate does not change when its column and its coefficient are rescaled together. Without strong convexity (`p > n`, or nearly collinear columns) a small score does not bound the objective error.

**Exact fits.** When `F* = 0` (a consistent system with `λ2 = 0` and no penalty at the minimizer, for example `NormL1(0)` on data with `y` in the range of `X`), `hᵢ ρ` tends to `0` at the minimizer. Near it the computed residual is rounding error, which is not orthogonal to the columns, so the check generally does not pass, and a computed residual of `0` refuses (C). The solve then ends by another exit, `maxiter` or an objective increase, and its point is assessed independently. For example `X = ones(5, 1)`, `y = fill(1e160, 5)`, `NormL1(0)`: the residual is parallel to the column and every proposal is refused. An exact fit with `x = 0` and `y = 0` is case B and passes.

**`gradtol`.** `gradtol` scales every threshold outside cases A and B in proportion, and a value below `64 eps(T)` (including `0`) uses that floor, `1.42e-14` in `Float64` and `7.63e-6` in `Float32`. In `Float32` the default `gradtol = 1e-5` is 1.3 times the floor, and near a good fit `τ hᵢ ρ` can be close to the rounding error of the computed gradient, so an accurate `Float32` solve can end by the objective-increase exit or `maxiter` without passing.

**Work.** The column data occupy one `Float64` per column in the state, allocated when the state is created; the column pass (`O(np)`) and the scan of `y` (`O(n)`) run once per solve, at the first check. The check computes no `λmax` (the state's `λmax` stays `-1`) and no `Xᵀy`. Each check is `O(p)` beyond the gradient: the pass over the coordinates, `‖x‖` when `λ2 > 0`, the zero test of `x` when `ρ` is `0` and `y = 0` and, for `NormL1(λ, w)`, the scan of the weights by the constructor of the converted penalty. It forms no product with `X` other than APG's gradient at `x` ([STOP-08](@ref)) and changes no counter other than that gradient's `grad_calls`; after the first check of a solve it allocates nothing.

**Applies to.** PGD and APG; least squares, raw or with one positive scale ([IN-02](@ref)), with `NormL1(λ)`, `NormL1(λ, w)`, `ElasticNet(λ1, λ2)` or `ElasticNet(λ1, λ2, w)`, including all-zero weights and zero levels; dense `Vector{T}`; `T = Float32` or `Float64`. The logistic loss and the matrix response use [STOP-03](@ref), `GroupNormL2` [STOP-05](@ref), `NormL2` [STOP-17](@ref), `NormL1Nonneg` and `IndNonnegative()` [STOP-16](@ref), and the other penalties [STOP-07](@ref).

**Code.** `src/utils.jl`: the coordinatewise `_stationary!`, `_coordinates_pass`, `_coordinate_threshold`, `_ridge_level`, `_root_twice_smooth`, `_norm2_64`, `_CoordinateScales`, `_coordinate_scales`, `_filled_scales!`, `_scaled_column_norm`; `src/solvers/proximal_gradient_descent.jl` and `src/solvers/accelerated_proximal_gradient_descent.jl`: the state field `scales`.

**Tests.** `test/stopping_coordinatewise.jl`: cases A and B at the check and through `solve!` (zero response, a zero column with `xᵢ = 0` and with `cᵢ = 0`, `X = 0`), the refusals C and D (an exact fit, a near-exact consistent fit, a column of entries `1e-170`, a tiny loss scale, an infinite `τ`, nonfinite gradient entries), a large range (residual `1e159`, a column of `1e160`), the #400 offset fixture against a BigFloat active-set reference, a centered control, a tiny intercept weight and a rescaled column, the ridge term of a zero-weight `ElasticNet` coordinate, the counters, allocations, the threshold against a BigFloat recomputation, the strict comparison, the loss value after a rejected trial, and the problems that keep the `λmax`-based checks. `test/stopping_scale.jl`, `test/entry_thresholds.jl`, `test/weighted_lasso.jl`, `test/elasticnet.jl` and `test/weighted_elasticnet.jl` check converged solves against this rule on independent BigFloat scores; `test/initial_curvature.jl`, `test/core_regressions.jl` and `test/accelerated_pgd.jl` check exact fits for accurate returns without convergence.

**Sources.** [Issue #487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487), rule B of the [round-2 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/487#issuecomment-7060542089), and the approved plan of [pull request #521](https://github.com/mlakolar/ProximalSolvers.jl/pull/521#issuecomment-7067050786). Measurements: [coordinatewise-scale evidence](@ref evidence-coordinatewise-scale-487).

### [STOP-03 Scalar and weighted lasso residuals](@id STOP-03)

**Statement.** For `NormL1(λ0)`, the residual is the least-infinity-norm element of `∇f(x) + λ ∂‖x‖₁`, with the working level `λ` from [IN-02](@ref). The entry score is `max(|∇fᵢ| - λ, 0)` at `xᵢ = 0` and `|∇fᵢ + λ sign(xᵢ)|` elsewhere. The full-point call is ProximalBase's `kkt_violation` with the working penalty used for the objective. With `NormL1(λ0, w)`, the call is `kkt_violation(NormL1(T(λ0), w), ∇f(x), x)`. Entry `i` uses `cᵢ = T(λ0) wᵢ`, multiplied and rounded in `T`. Its score is `max(|∇fᵢ| - cᵢ, 0)` at zero and `|∇fᵢ + cᵢ sign(xᵢ)|` elsewhere. The `Vector{T}` weights are used as supplied.

For least squares on a dense vector these signed entry scores are judged by the coordinatewise thresholds of [STOP-21](@ref), which hold the rule for that case; the scale and the entry thresholds below apply to the matrix response of [IN-10](@ref) and to the logistic loss of [IN-09](@ref).

The scale is `S = max(λ, λmax)`, where `λ = T(λ0)` without weights and `λ = maxᵢ cᵢ` with weights, and `λmax` is the computed `s‖Xᵀy‖∞`. The equality `maxᵢ cᵢ = T(λ0) * maximum(w)` uses monotonicity of rounding. Unit weights reproduce the unweighted coefficients and scale. All-zero weights remove the penalty and give the scale `S = λmax`; a computed `λmax = 0` then falls under the zero-scale rule in [STOP-04](@ref).

For [IN-10](@ref), use the unweighted scores above at every entry of `B`
with `∇f(B) = s Xᵀ(XB − Y)`. Take the largest score over all entries, with
`λmax` the largest absolute entry of the computed `s XᵀY`. Both quantities
use the working arithmetic of the vector test. This is the entrywise maximum
over the full matrix.

For a raw `LogisticLoss` with PGD or APG, `∇f` is the logistic gradient and `λmax = ‖Xᵀ(½ - y)‖∞`, the norm of its value at zero ([IN-09](@ref)).

**Entry thresholds with weights.** With `NormL1(λ0, w)` a proposed stop must also hold entry by entry. Let `sᵢ` be ProximalBase's signed entry score `kkt_violation(NormL1(T(λ0), w), ∇f(x), x, i)`: `|∇fᵢ| - cᵢ` at `xᵢ = 0`, which can be negative, and `|∇fᵢ + cᵢ sign(xᵢ)|` elsewhere. The maximum of these scores and zero is the full-point residual above. Each `sᵢ` must be strictly below `τ max(cᵢ, λmax)`, computed in `T`, and that threshold must be at least `floatmin(T)`. A negative score passes any threshold that passes the guard, so clipping at zero does not change the decision.

Each entry threshold is at most `τ S`, so the full-point comparison of [STOP-04](@ref) is necessary, and it is made first. The entries are then compared one by one, stopping at the first failure, only when the full-point comparison passes and the largest coefficient `λ = T(λ0) * maximum(w)` exceeds the computed `λmax`. Otherwise every entry threshold equals `τ S` and the full-point comparison decides alone. A weight vector of ones with `T(λ0) > λmax` takes the entry pass when the full-point comparison passes, but its thresholds all equal `τ S` and its decision is that of `NormL1(λ0)`.

Without the entry pass, one coefficient far above `λmax` (a large weight, or one that excludes a column) would set `S` for every entry, and a free or lightly penalized entry could pass with a derivative of order `τ maxᵢ cᵢ` ([#464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464)). The entry thresholds still contain `λmax`, which a free intercept can inflate ([STOP-12](@ref)). The entry scale `max(cᵢ, λmax)` contains `cᵢ` because near a stationary point a nonzero entry has `|∇fᵢ|` close to `cᵢ`, so its score combines two terms of size about `cᵢ`. It contains `λmax` as the gradient scale of the unweighted rule. In exact arithmetic, a common positive factor on loss and penalty scales every entry threshold and every score alike. In working precision, rounding and the normal-threshold guard can change the outcome, as in [STOP-04](@ref).

A zero-weight coordinate has `cᵢ = 0`, is unpenalized and is scored by its full `|∇fᵢ|`, even with a large `λ0`. It is held to `τ λmax`, the threshold of the unpenalized problem. When the computed `λmax` is zero, its threshold is zero (`NaN` if `τ` is infinite), which fails the guard. No stop then passes, as with all-zero weights ([STOP-04](@ref)), although `x = 0` may be the minimizer. Each coefficient must already satisfy [IN-01](@ref): it is finite and normal when both factors are positive; a zero level or weight gives zero. An infinite coefficient iterate gives a nonfinite residual (`Inf`, or `NaN` if a `NaN` is read), which cannot pass.

**Applies to.** PGD and APG; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks full-matrix scores, the zero-solution threshold and independent accepted-point residuals. `test/logistic_pgd.jl` checks the logistic scale `‖Xᵀ(½ - y)‖∞` and independent KKT scores, and `test/entry_thresholds.jl` the logistic entry thresholds on the #464 fixture against its analytic minimizer and on a free intercept with an excluded or all-zero column. `test/stopping_coordinatewise.jl` checks that the logistic and matrix-response checks still compute `λmax`. The least-squares fixtures of `test/entry_thresholds.jl`, `test/weighted_lasso.jl`, `test/stopping_scale.jl` and `test/core_regressions.jl` (“Working ℓ₁ levels”) check the entry scores under [STOP-21](@ref).

**Sources.** `docs/src/numerics.md:L86`, `docs/src/numerics.md:L145`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L23`.

### [STOP-16 Nonnegative-lasso residual and scale](@id STOP-16)

**Statement.** For unweighted `NormL1Nonneg(λ0)`, PGD checks the accepted point with ProximalBase's full-point `kkt_violation` using the working penalty from [IN-02](@ref). For `IndNonnegative()`, PGD uses `NormL1Nonneg(zero(T))` for the check because both penalties have the same value and normal cone on the feasible set. With `λ` the level of that penalty, the entry score is `abs(∇f(x)[j] + λ)` when `x[j] > 0`, and `max(-(∇f(x)[j] + λ), 0)` when `x[j] == 0`. The residual is the maximum entry score. An infeasible point has residual `Inf` and cannot pass. A positive derivative at a zero coordinate can satisfy constrained stationarity.

The scale is `S = max(λ, λmax)`, where `λmax` is the computed symmetric magnitude `s‖Xᵀy‖∞`. This is not the one-sided penalty level at which zero solves the constrained problem. Apply the computed threshold, tolerance floor, strict comparison and scale guards of [STOP-04](@ref). Passing records a computed residual check, with the working-precision limitations of [STOP-12](@ref).

**Applies to.** ProximalGradientDescent with unweighted `NormL1Nonneg` or `IndNonnegative()`; dense Vector{T}; T = Float32 or Float64. The feasible-start requirement and unsupported combinations are specified in [IN-07](@ref).

**Code.** `src/utils.jl`: dedicated `_stationary!`, `_converted_penalty`, `_l1_level`, `_scale_norm` and `_lambda_max!`.

**Tests.** `test/core_regressions.jl`, “Working ℓ₁ levels”, checks stopping flags and residuals with subnormal and ordinary levels in both precisions. `test/nonnegative_lasso.jl` checks zero and positive starts, inactive-coordinate KKT, correlated designs, independent residuals and objectives, and refusals. `test/nonnegative_least_squares.jl` checks both precisions against independent gradients and objectives, including a positive derivative at a positive coefficient that must veto an objective-change stopping proposal.

**Sources.** Current-source addition after the historical migration baseline: upstream `fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8`, [`src/utils.jl` dedicated check and constrained-residual rule](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L141-L156), [level conversion](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/utils.jl#L232-L233), and [`test/nonnegative_lasso.jl`](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/test/nonnegative_lasso.jl#L12-L67).

### [STOP-17 Euclidean-norm residual and scale](@id STOP-17)

**Statement.** For `NormL2(λ0)`, PGD and APG check the accepted point with ProximalBase's full-point `kkt_violation(g, ∇f(x), x)`, using the working penalty `g` of level `λ = T(λ0)` from [IN-02](@ref). The score computes in working precision the minimum 2-norm over the elements of `∇f(x) + λ ∂‖x‖₂`. In exact arithmetic the residual is `max(‖∇f(x)‖₂ - λ, 0)` at zero and `‖∇f(x) + λ x/‖x‖₂‖₂` elsewhere.

The scale is `S = max(λ, ‖∇f(0)‖₂)`. Form the product `Xᵀy`, then scale that
vector by `s` as in [FP-03](@ref) before computing its norm with LinearAlgebra's
`norm`. The norm is cached as `λmax` under [STOP-08](@ref). In exact arithmetic
zero is a minimizer exactly when `‖∇f(0)‖₂ ≤ λ`. Apply the threshold and
guards of [STOP-04](@ref) to the residual and scale. A nonfinite computed norm
of the gradient at zero vetoes the stop, even when that gradient has finite entries.

The check uses the gradient already held (PGD) or the one APG forms at `x`, and makes no proximal evaluation, so it adds no `prox_calls`. The one-group `GroupNormL2` of [IN-11](@ref) has the same residual and scale in exact arithmetic.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64; `NormL2` under [IN-11](@ref).

**Code.** `src/utils.jl`: dedicated `_stationary!`, `_scale_norm`, `_lambda_max!`, `_converted_penalty`, `_l1_level`.

**Tests.** `test/norml2_pgd.jl` independently evaluates the residuals at returned points and checks a direct pass and veto at zero, the cached scale, and the call counts. `test/stopping_scale.jl` checks the shared threshold arithmetic.

**Sources.** [Issue #457](https://github.com/mlakolar/ProximalSolvers.jl/issues/457) and [pull request #494](https://github.com/mlakolar/ProximalSolvers.jl/pull/494).

### [STOP-04 Threshold arithmetic and scale guards](@id STOP-04)

**Statement.** This clause is the threshold rule of the `λmax`-based checks ([STOP-03](@ref), [STOP-05](@ref), [STOP-06](@ref), [STOP-16](@ref), [STOP-17](@ref)). Least squares with `NormL1` or `ElasticNet` on a dense vector uses the coordinatewise thresholds of [STOP-21](@ref) instead: they share `τ` but are formed in `Float64` with one rounding to `T`, and an infinite threshold refuses there.

For a `λmax`-based check, form `τ = T(max(gradtol, 64 eps(T)))` and `threshold = τ * S` in `T`. The full-point check requires finite `S`, `threshold ≥ floatmin(T)`, and a finite computed residual **strictly below** `threshold`. The scale and residual are penalty-specific ([STOP-03](@ref), [STOP-05](@ref), [STOP-06](@ref), [STOP-16](@ref), [STOP-17](@ref)).

A large `gradtol` can make conversion or multiplication produce an infinite threshold, which passes the full-point check when `S` and the residual are finite. Dividing the residual by `S` and comparing with the unrounded tolerance is the exact-arithmetic interpretation, not an additional floating-point guarantee. A `gradtol` below `64 eps(T)`, including `gradtol = 0`, uses that floor.

Common positive rescaling of loss and penalty preserves the normalized inequality in exact arithmetic. In working precision the rounded quantities and the normal-threshold guard can change the outcome even when the scales remain representable. For Float32 `X = [1]`, response `y = [1]`, `x = 0` and default `gradtol`, `s = λ = 1` passes while `s = λ = 1f-35` does not: the latter threshold is below `floatmin(Float32)`. (For this least-squares example the coordinatewise threshold of [STOP-21](@ref), `τ s`, gives the same two outcomes.)

With weights, the entry or group thresholds of [STOP-03](@ref), [STOP-05](@ref) and [STOP-06](@ref) must also hold, under the same strict comparison and normal-threshold guard. If both `λ` and `λmax` are zero, or the threshold is below `floatmin(T)`, no stop passes; the solve reaches `maxiter` unless another exit intervenes. For the unweighted lasso, starting at `x = 0` with `λ ≥ λmax` gives `G = 0` and stops at the first proposal when `S > 0` and the normal-threshold guard holds; for least squares the same start passes [STOP-21](@ref) when its thresholds are normal or `y = 0`. Under `ftol = 0`, the unchanged iterate makes no proposal and can instead run to `maxiter` with `converged=false`.

**Applies to.** PGD and APG; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks accepted stops and the zero-scale guard. `test/stopping_coordinatewise.jl` checks the infinite-threshold refusal of [STOP-21](@ref) against this clause's acceptance. test/stopping_scale.jl; test/core_regressions.jl; test/accelerated_pgd.jl.

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

With `ElasticNet(λ1, λ2, w)`, pass the working penalty from [IN-03](@ref) to
ProximalBase's `kkt_violation` at the accepted point. For each entry, with
`cᵢ = T(λ1) * wᵢ` rounded in `T`, the mathematical score is `|∇fᵢ| - cᵢ`
at zero and `|∇fᵢ + T(λ2)xᵢ + cᵢ sign(xᵢ)|` elsewhere. A zero-weight entry
still includes the ridge derivative in its score.

PGD and APG accept `ElasticNet` only for least squares on a dense vector, and
there a proposed stop is decided by the coordinatewise check of [STOP-21](@ref)
with these signed entry scores. Each entry is held to its own threshold
`T(τ √(s‖Xᵢ‖² + λ2) √(2Φ))`, `Φ = f(x) + (λ2/2)‖x‖²`. In exact arithmetic the
problem is the lasso at level `λ1` on `X̃ = [√s X; √λ2 I]`, `ỹ = [√s y; 0]`, whose
squared-error loss is `s‖Xx-y‖²/2 + λ2‖x‖²/2` and whose gradient adds `λ2 x`; the
threshold is the same product for the augmented column and residual. With
`ElasticNet(0, λ2)` and zero response the check keeps the stop at `x = 0` (case B
of [STOP-21](@ref)).

The `λmax`-based scale `S = max(maxᵢ cᵢ, λmax)` (`S = max(T(λ1), λmax)` without
weights), which contains neither `λ2` nor `λ2‖x‖∞`, with the entry thresholds
`τ * max(cᵢ, λmax)` when `maxᵢ cᵢ > λmax` and the guards of [STOP-04](@ref), is the
check of a state built without the column data of [STOP-21](@ref); `solve!` does
not build such a state for `ElasticNet`.

Initialization can accept finite `f(x0)` with `g(x0)` overflowing in `T` (for example the ridge term `(λ2/2)‖x0‖²` above `floatmax(T)`); the common start and rollback policy is [RES-01](@ref). This KKT check is not the change test used by `CDSolver` on a dense vector or a one-dimensional `SparseIterate`.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!, _entry_thresholds_hold`.

**Tests.** `test/elasticnet.jl` checks residual conversion, stopping honesty, the ridge solutions at zero response and overflowing starts; converged solves are checked against the rule of [STOP-21](@ref) on independent scores. `test/weighted_elasticnet.jl` checks prescribed-point and public PGD/APG results in Float32 and Float64 with independent BigFloat residuals, the coordinatewise decisions at fixed points (two of which differ from the earlier entry thresholds), zero response, and the entry-threshold helper of the `λmax`-based check. `test/stopping_coordinatewise.jl` checks the ridge term in the score of a zero-weight coordinate.

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

For the `λmax`-based checks, `λmax` is computed once per solve at the first check that reaches that stage, by one product of `Xᵀ` with the loss's zero-point vector (`Xᵀy` for least squares, `Xᵀ(½ - y)` for the logistic loss of [IN-09](@ref)), and stored in state field `λmax`; that product is not counted. The coordinatewise check of least squares with `NormL1` or `ElasticNet` ([STOP-21](@ref)) computes no `λmax` and no `Xᵀy`: at its first check it makes one uncounted pass over the columns of `X` (a `Float64` sum of squares per column, into a state buffer of `p` `Float64` values allocated with the state) and one scan of `y`, and each check is then `O(p)` beyond the gradient. Weighted lasso adds two scans of `w` to the KKT pass: one maximum scan and one scan in construction of the penalty with converted level. When the largest coefficient exceeds `λmax` (`Λ` for groups), a check that passes the full-point comparison adds one more traversal of the entries (of the groups for `GroupNormL2`) with ProximalBase's per-entry score, ending at the first failed comparison ([STOP-03](@ref), [STOP-05](@ref)). It creates no coefficient array. With groups given as vectors of `Int` indices or as ranges it allocates nothing. Other accepted group layouts (abstractly typed containers, or non-`Int` index types) can allocate in ProximalBase's group scorer during this pass, including some for which the full-point group residual allocates nothing.

The coordinatewise check scores each coordinate with ProximalBase's per-entry score in one traversal that ends at the first failure; weighted elastic net reuses its native working penalty, and weighted lasso adds the weight scan of the constructor of its converted penalty. It creates no coefficient array ([STOP-21](@ref)).

Each generic check with finite positive `t` adds one proximal evaluation, counted in `prox_calls`; APG additionally counts its gradient at `x`. These costs accrue before call limits are tested. The generic check restores its scratch `delta_x` to `x - x_previous` before the remaining diagnostics read it.

The dedicated nonnegative-penalty check [STOP-16](@ref) and the Euclidean-norm check [STOP-17](@ref) add no proximal evaluation.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: _lambda_max!, _gradient_at_x!, _stationary!, _filled_scales!`.

**Tests.** test/stopping_scale.jl; test/stopping_coordinatewise.jl (the counters of a coordinatewise check, no `λmax`, no allocation after the first check); test/weighted_lasso.jl; test/weighted_elasticnet.jl; test/linf.jl; test/accelerated_pgd.jl; test/norml2_pgd.jl: no added proximal call and the cached scale.

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

### [STOP-18 Exit classes and the evidence each carries](@id STOP-18)

**Statement.** Every return is classified by its final-iteration flags together with the supplied `allow_f_increases` option, which the result does not store. When several conditions apply at that iteration, each flag keeps its own meaning ([STOP-09](@ref)). The first matching row below names the return's class for reporting; the order does not rank the evidence.

| Class | Result fields | Evidence about the returned point |
| --- | --- | --- |
| Computed stationarity convergence | `converged = true` | A proposal passed the computed stationarity check of [STOP-01](@ref) to [STOP-07](@ref) or [STOP-21](@ref). The comparison uses the computed residual and threshold, so it establishes no exact residual bound ([STOP-12](@ref)) and no accuracy target. For least squares with `NormL1` or `ElasticNet`, [STOP-21](@ref) states what the coordinatewise check means in exact arithmetic. |
| Float32 PGD stagnation | `stagnated = true` | An unchanged accepted iterate after the qualifying rejection of [STOP-11](@ref), under `ftol = 0`. The point is not checked. |
| Objective increase | `f_increased = true` with `allow_f_increases = false` | A computed objective rise ended the solve ([STOP-09](@ref)). The flag records only the sign of the comparison; the result has no count of units in the last place. The relative size of the last change is `f_residual` ([RES-02](@ref)), and a stored trace holds both objective values once at least two iterations have completed. With `allow_f_increases = true`, `f_increased` describes only the last comparison; read the remaining rows. |
| Iteration limit | `iteration_converged = true` | The budget `maxiter` was used. |
| Call limit | `call_limit_reached = true` | A positive call limit was reached ([PGD-04](@ref)). |
| Callback or time limit | none of the fields above is set, `f_increased` excepted when `allow_f_increases = true`, and `iterations < maxiter` | A callback returned `true`, the time limit elapsed, or both. The result has no dedicated field for either cause. |

No class carries independently verified target accuracy. PGD and APG compute no duality gap: `gap` is `NaN`, and a positive `gaptol` is refused ([PGD-05](@ref)). Only square-root-lasso CD returns a bounded gap ([CDQ-03](@ref)). Elsewhere an accuracy target must be evaluated outside the solver, for example by [STOP-13](@ref). A return in any row except the first can still be accurate to the stationarity bound; [STOP-15](@ref) describes one such case.

**Applies to.** PGD and APG on the regression routes; dense Vector{T} and the matrices in [IN-10](@ref); T = Float32 or Float64. Graphical-lasso PGD reports through [PGD-08](@ref).

**Code.** `src/solve.jl: _solve_gradient!`; `src/types.jl: OptimizationResults`.

**Tests.** No new test: the clause reads the flags already specified by [STOP-09](@ref), [STOP-11](@ref), [PGD-04](@ref) and [RES-02](@ref) and changes no behavior. `test/core_regressions.jl`, `test/accelerated_pgd.jl` and `test/minimal_core_characterization.jl` cover the individual flags. That the result has no dedicated field for a callback or time-limit stop follows from the result constructor, which records neither cause.

**Sources.** [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320), Stage 1 of the maintainer's 0.7 plan; current source `src/solve.jl` at `1a9f196b`.

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

**Statement.** Defaults `maxiter=200`, `ftol=1e-6`, `xtol=1e-8` and `gradtol=1e-5` are exploratory settings. Tightening them does not establish a specified error, and reducing `gradtol` below the floor in [STOP-04](@ref) does not tighten that computed check. The residual uses rounded gradient products: underflow or cancellation can make a nonstationary point pass. The checks that use the reference scale `λmax = ‖∇f(0)‖∞` (the logistic loss and the matrix response with `NormL1`, [STOP-03](@ref); `GroupNormL2`, [STOP-05](@ref); `NormL1Nonneg` and `IndNonnegative()`, [STOP-16](@ref); `NormL2`, [STOP-17](@ref)) have this limit: a coordinate on a much smaller gradient scale than `λmax` can remain inaccurate even when the global relative residual is small. `λmax` is measured at zero. When a free coordinate is far from zero at the solution, as an intercept is with an uncentered (offset) response, its entry of `∇f(0)` can make `λmax`, and so every threshold, much larger than the gradients near the solution. `converged = true` can then be reported with a materially wrong objective. The entry thresholds of [STOP-03](@ref) do not change this; measured cases are in the [entry-threshold evidence](@ref evidence-entry-thresholds-464). Centering the response can help when the inflated entry belongs to an intercept. A smaller `gradtol` can help while it stays above the floor `64 eps(T)`. Neither is a general remedy. For least squares with `NormL1` or `ElasticNet` on a dense vector, the coordinatewise check of [STOP-21](@ref) replaces that scale ([#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487)); its own limits (ill-conditioning, exact fits, `Float32`) are stated there. See [working precision](working-precision.md) and [stopping evidence](evidence/stopping-audit-352.md).

For PGD, `xtol` bounds a step scaled by `1/L`; the implied proximal-gradient residual is roughly `L * xtol * max(norm(x), 1)`, depending on curvature, coefficient scale and penalty level. Even `xtol = 1e-300` can accept a nonzero step, such as from `[0.0]` to `[1e-310]`. It is not an accuracy target.

The historical configuration below is a **test configuration**, not a general recipe. Its measurements, including the fact that they predate the stationarity check, are retained in [strict-accuracy evidence](evidence/strict-accuracy-config.md).

```julia
ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true,
                xtol = 1e-300, gradtol = 1e-11)
```

With the objective test disabled, the default objective-increase exit still applies unless `allow_f_increases=true`. Neither the option combination nor a stagnation flag provides an accuracy certificate.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: convergence_assessment, _stationary!`.

**Tests.** Existing stopping and numerical-regression tests; `test/stopping_coordinatewise.jl` checks the offset fixture of #400 and #487 under [STOP-21](@ref). Historical measurements are evidence, not a new test requirement.

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

### [STOP-19 The gap ceiling for a lasso check when the exact residual meets the threshold](@id STOP-19)

**Retired by [#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487).** Least squares with unweighted `NormL1` on a dense vector is now checked by the coordinatewise rule of [STOP-21](@ref), whose thresholds are not `τ max(λ, λmax)`, so the hypothesis below is not the check of any vector route. What a kept least-squares stop means is stated in [STOP-21](@ref); [STOP-13](@ref) remains the independent gap check. The text below is preserved as historical provenance.

**Statement.** Take the problem of [STOP-13](@ref): unweighted `NormL1(λ)`, `s > 0`, `λ > 0` and `F(x) > 0`. Let `τ` and the scale `S = max(λ, λmax)` be those of [STOP-03](@ref) and [STOP-04](@ref), with `λmax` the computed value. A passed check compares only the computed residual with the rounded threshold, and [STOP-12](@ref) allows a pass at a nonstationary point. The ceiling below needs the separate hypothesis that the exact residual satisfies `‖G‖∞ ≤ τ S`. Under that hypothesis, put

```
a = τ S / λ = τ max(1, λmax / λ),   B = 2a + a².
```

Then `k = ‖G‖∞ / λ ≤ a` in [STOP-13](@ref), and in exact arithmetic the relative duality gap at its dual point is at most `2k + k² ≤ B`. The pointwise bound `2k + k²` can be zero, for example at the zero minimizer with `λ ≥ λmax`; the ceiling `B` is the bound obtained from the stated exact-residual hypothesis.

`B` is at least `2τ + τ²`. At the Float32 floor `τ = 64 eps(Float32) ≈ 7.63e-6`, `B` is `1.53e-5` for `λ ≥ λmax`, `1.02e-4` for `λ = 0.15 λmax` and `7.6e-4` for `λ = 0.02 λmax`. Since [STOP-04](@ref) does not let `gradtol` go below the floor, the ceiling of a Float32 check exceeds `1e-5` at every penalty level and `gradtol`. At the Float64 floor (`τ ≈ 1.42e-14`), `B` at `λ = 0.02 λmax` is `1.4e-12`. The ceiling certifies a relative gap `ε` exactly when `τ ≤ (λ/S) ε / (1 + √(1 + ε))`, approximately `ε λ / (2S)` for small `ε`.

`B` is an upper bound, and gaps observed at Float32 stops are usually smaller ([Float32 stopping evidence](@ref evidence-float32-stopping-320)). The clause does not bound the difference between the computed and exact residuals, and it does not apply to weighted, group, elastic-net or constrained penalties.

**Applies to.** PGD and APG with unweighted `NormL1`; dense Vector{T}; T = Float32 or Float64; positive `s`, `λ` and `F(x)`.

**Code.** Analytic consequence of [STOP-04](@ref) and [STOP-13](@ref); no implementation.

**Tests.** No test: the statement is an exact-arithmetic consequence of two specified clauses. The [evidence page](@ref evidence-float32-stopping-320) records a numerical check of the [STOP-13](@ref) inequality on archived records; it does not test the residual hypothesis.

**Sources.** [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320): the Phase 0 report and the archive `archive/issue-320-evidence` at `fb8fb87d`.

### [STOP-20 Benchmark targets and harness options are not library contracts](@id STOP-20)

**Statement.** The benchmark harness's accuracy targets and options are measurement settings specified in `benchmark/HARNESS.md`. For the current-core lasso cases, the target is an independent relative duality gap of `1e-5` for Float32 or `1e-8` for Float64, evaluated in Float64 on the rounded inputs. The ordinary PGD and APG cases, and the #320 harness profile, use `benchmark_options(residual = true)`: `maxiter = 10_000`, `ftol = 1e-15`, `xtol = 1e-14`, `gradtol = 1e-11` and `allow_f_increases = false`. The Float64 `acc-` cases use `accuracy_options()` instead: `ftol = 0`, `gradtol = 1e-10` and `allow_f_increases = true`. None of these settings are the library defaults of [STOP-12](@ref), and the solvers promise none of the targets.

A `target_missed` record says only that a valid independent gap exceeded the finite target. It does not name the exit, and it can carry `converged = true`, which bounds no gap ([STOP-21](@ref)). Float32 stops depend on objective rounding ([STOP-14](@ref)), so a change that alters rounding without changing any stopping rule can move individual Float32 records between `ok` and `target_missed`. Evidence for or against such a change compares counts over draws and records each return's class from [STOP-18](@ref). A future solver claim of target accuracy needs its own clause and certificate.

**Applies to.** Benchmark records of the current-core PGD and APG lasso cases and the #320 harness profile; T = Float32 or Float64. Historical records such as `gradient/lasso/pg/R/call`, which use `ProximalOptions()` and no target, are outside it.

**Code.** `benchmark/cases.jl: benchmark_options, accuracy_options, CORE_TARGETS`; `benchmark/run.jl: certificate_status`.

**Tests.** No test: the clause separates measurement settings from solver contracts and changes no behavior.

**Sources.** [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320) and its [Phase 0 report](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343); `benchmark/HARNESS.md`, section "Float32 PGD and APG against the `1e-5` target".

## Tests

The clause-level references identify existing tests; this relocation adds no solver behavior or test obligation. Important suites are `test/stopping_scale.jl`, `test/stopping_coordinatewise.jl`, `test/weighted_lasso.jl`, `test/nonnegative_lasso.jl`, `test/elasticnet.jl`, `test/group_pgd.jl`, `test/linf.jl`, `test/norml2_pgd.jl`, `test/core_regressions.jl` and `test/accelerated_pgd.jl`.

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

[#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487): least squares with `NormL1` or `ElasticNet` (with or without weights) on a dense vector is checked by the coordinatewise rule of [STOP-21](@ref), which replaces the scale `max(maxᵢ cᵢ, λmax)` and the #464 entry thresholds for these problems and computes no `λmax`. Exact zero scales (a zero column with `λ2 = 0`, and `x = 0` with `y = 0`) pass when the score is at most `0`, so zero-response solves started at `x = 0`, which refused each proposed stop before, now stop there; other zero, underflowed and nonfinite thresholds refuse, including an infinite threshold that [STOP-04](@ref) accepts, and exact and near-exact fits generally return `converged = false`. [STOP-03](@ref), [STOP-04](@ref), [STOP-06](@ref) and [STOP-08](@ref) are scoped to the `λmax`-based checks, the [STOP-12](@ref) offset limitation is retired for these problems and kept for the others, and [STOP-19](@ref) is retired. The [STOP-06](@ref) example of a computed `λmax` that cancellation leaves at `1` described the `λmax`-based elastic-net check, which `solve!` no longer reaches. Measurements: [coordinatewise-scale evidence](evidence/coordinatewise-scale-487.md).

[#320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320), Stage 1: [STOP-18](@ref) classifies returns by their flags, [STOP-19](@ref) states the lasso gap ceiling that holds when the exact residual meets the check's threshold, and [STOP-20](@ref) separates benchmark settings from library contracts. No solver behavior changes. Measurements: [Float32 stopping evidence](evidence/float32-stopping-320.md).

[#464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464): weighted `NormL1` holds each entry to `τ max(cᵢ, λmax)` when its largest coefficient exceeds `λmax` ([STOP-03](@ref)), and `GroupNormL2` holds each group to `τ max(cₖ, Λ)` when its largest coefficient exceeds `Λ` ([STOP-05](@ref)); see also [STOP-04](@ref) and [STOP-08](@ref). Otherwise the decisions are unchanged. The offset-response limitation is stated in [STOP-12](@ref). Measurements: [entry-threshold evidence](evidence/entry-thresholds-464.md).

This migration consolidates the baseline stopping specifications without changing solver logic. Historical strict-configuration results remain separate from the current contract. The historical normalized-residual and group-support formulations were retired under [#416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416); the original quotations and anchor remain available for provenance.
