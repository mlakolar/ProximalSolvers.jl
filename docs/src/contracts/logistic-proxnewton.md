# Proximal Newton for sparse logistic regression

`ProxNewton` solves the sparse logistic regression of [IN-09](@ref) by proximal Newton
steps. Each step minimizes a weighted least-squares model of the loss with the scalar
coordinate step of [CD-01](@ref) and then searches along the result on the true
objective. The input gate is that of [IN-09](@ref); the clauses below specify the
solver, its models, budgets, search, result and failure boundary.

## [PN-01 Inputs, result and stop reasons](@id PN-01)

**Statement.**

`ProxNewton(; inner, maxiter = 100, tol = 1e-7)` is passed to `solve!` with ProximalBase's raw
`LogisticLoss(y, X)`, a `NormL1(lambda)` or `NormL1(lambda, w)` penalty and a dense
`Vector{Float64}` start. It minimizes the summed logistic objective and penalty in [IN-09](@ref),
starting at the supplied coefficients. A column of ones with penalty weight zero supplies an unpenalized intercept. The level `lambda` is converted to `Float64` once,
and the penalty weights are used as supplied; ProximalBase's `kkt_violation` receives
that converted penalty.

The inputs and the order of refusals are those of [IN-09](@ref), with `ProxNewton` in the place of
`ProximalGradientDescent`, except that the first check is the loss: any loss other than a
raw `LogisticLoss` or one `Scaled` wrapper of it is refused with an `ArgumentError` that names `ProxNewton`
and the least-squares solvers. A `Scaled(LogisticLoss)` is refused as in [IN-09](@ref). The refusal of a
nonbinary response names `ProxNewton`. `CDSolver` refuses the logistic loss with an
`ArgumentError` that names `ProximalGradientDescent`, `AccProxGradDescent` and `ProxNewton`. Keywords of `solve!` and positional
options after the solver are refused as for the other solvers. All refusals precede any write to the
coefficients.

The constructor is validated. It refuses an `inner` that is not a `CDSolver` in cyclic order
(`order = :cyclic`), a negative `maxiter`, and a `tol` that is not finite and nonnegative or that
is positive but rounds to zero in `Float64`. `inner = CDSolver(order = :cyclic, momentum = false, relative = false,
tol = 1e-11, maxpasses = 2000)` is the default. The fields of `inner` that [PN-03](@ref) names are used; its
`relative`, `momentum` and `rng` settings are not.

The start must have a finite predictor `X * b`, a finite objective, a finite gradient and a finite KKT score;
otherwise `solve!` raises an `ArgumentError` ("start from a point where f is finite", or the gradient or score
variant) before any write. The solve is private: the accepted point, the trial points and the models are buffers of
the solve, and the caller's coefficients are written once, at a normal return ([PN-05](@ref)).

`solve!` returns a `ProxNewtonResults` whose `minimizer` is the caller's vector, with

| Field | Meaning |
|:--|:--|
| `minimum` | the objective `F` at the returned point, the loss from ProximalBase plus the penalty |
| `kkt` | the largest ProximalBase KKT score of the original problem at the returned point, from a gradient formed at that point |
| `tolerance` | the `tol` of the solver |
| `iterations` | the accepted outer iterations |
| `passes` | all coordinate passes of the inner solves, including those of a model whose step the search then rejected |
| `converged` | `isfinite(kkt) && kkt <= tolerance` |
| `stop_reason` | `:converged`, `:maxiter` or `:stalled` |

The accessors `minimizer`, `minimum`, `iterations` and `converged` read the fields of the same name. At each
accepted point, including the start, the solver tests convergence first: `kkt <= tol` gives
`:converged`, also for `maxiter = 0` and with no pass budget, so a stationary start returns with
`iterations = 0` and `passes = 0`. Otherwise `iterations == maxiter` gives `:maxiter`. Otherwise an iteration is
attempted; if no model gives an accepted step the solve ends with `:stalled`. A stalled or exhausted solve returns the last
accepted point with `converged = false`. No warning is logged for any stop.

**Applies to.** `ProxNewton` with a raw `LogisticLoss{Float64}` and `NormL1` on a dense `Vector{Float64}`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `ProxNewton`, `ProxNewtonResults`, `solve!`, `_solve_newton!`, `_pn_workspace`; `src/solve.jl`: `_check_newton_problem`, `_check_logistic_problem`, `_logistic_method_error`.

**Tests.** `test/logistic_proxnewton.jl`: the constructor and its refusals; the result fields, accessors and display against the independent objective and scores; a zero iteration budget at a stationary and a nonstationary start, and a zero pass budget at a nonstationary start giving exactly `:stalled`; budgets of iterations and of passes; the refusals above with the coefficients unchanged, including the text that names `ProxNewton`.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) (scope) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-02 The weighted and the fixed least-squares model](@id PN-02)

**Statement.**

At an accepted point with predictor `η = X b` and observation derivative `d = σ(η) - y` (from ProximalBase, which
evaluates it without cancellation in the saturated tails), a model is a least-squares problem in the step
whose gradient at `b` is the gradient `Xᵀd` of the loss. There are two models, a weighted one and a fixed one that is
conditional on the first (below), and each is solved with the scalar `LSModel` of [CD-01](@ref).

*Weighted model.* Row `i` has the root `s = q / (1 + q²)` with `q = exp(-|ηᵢ| / 2)`, which is
`√(σ(ηᵢ)σ(-ηᵢ))` in exact arithmetic. The design is `A[i, :] = s X[i, :]` and the response is
`r[i] = s ηᵢ - dᵢ / s`, so that, in exact arithmetic, `Aᵀ(A b - r) = Xᵀd` and `AᵀA = Xᵀ diag(s²) X`, with the loss scale 1.
A row is replaced when `|dᵢ| > s 2²⁶` (`2²⁶ = 1/√eps(Float64)`; the comparison is on the product `s 2²⁶`, which cannot
overflow, not on the ratio `dᵢ/s`): it takes the fixed row root `1/2`, which keeps its tangent
(`r[i] = ηᵢ/2 - 2dᵢ`) and gives it the curvature `1/4` of the global bound. Only the unsafe row is replaced. A row
whose root and derivative are both zero is a zero row (`s = 0` and `r[i] = 0`). Examples for `yᵢ = 0`: `η = -150` has
`s = e⁻⁷⁵` and a derivative of order `e⁻¹⁵⁰`, a small ratio, so the row keeps its small curvature; `η = 800` has
`d = 1`, the ratio exceeds the bound, and the row takes `s = 1/2`; `η = -2000` gives `s = 0` and `d = 0`, a zero row. A
saturated row on the side of its label keeps its small root even where the square of that root underflows.

*Fixed model (conditional).* It is formed and solved in an iteration only when the weighted model is unavailable or gives
no accepted step ([PN-03](@ref) for its budget). It is the `LSModel` with loss scale `1/4`, the borrowed `X` and the response `η - 4d`. In exact arithmetic its
gradient at `b` is `Xᵀd` and its Hessian is `XᵀX/4`, which bounds that of the loss, so that
`f(b + Δ) ≤ f(b) + ∇f(b)ᵀΔ + ‖XΔ‖²/8` for every `Δ`.

A model whose design or response has a nonfinite entry is unavailable for that iteration. The adaptive
model is also unavailable when a nonzero column has every squared entry round to zero in Float64.
The construction checks the square of the largest magnitude in the column. Since rounded
nonnegative squares are monotone, a zero result for a positive maximum means every square
rounded to zero, which [CD-04](@ref) would refuse. For example, an adaptive column with one
entry `exp(-400)` and all other entries zero triggers this fallback. An all-zero column remains
eligible under the flat-column step in [CD-01](@ref).

The weighted model keeps one `n × p` design with vectors of length `n` and `p`. The fixed model
borrows `X`. The inner solver refreshes the residual and curvature caches before its first run
for a model, from the observation derivative `d` and not from the stored coefficients, and carries that state
through refinements (the cache refresh of [PN-03](@ref)). The fixed model follows
an unavailable weighted model or one that gives no accepted step, within the remaining pass
budget. Both forms use coordinate operations on the model's design columns.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_adaptive_model!`, `_pn_fixed_response!`.

**Tests.** `test/logistic_proxnewton.jl`: the gradient and Hessian identities of both models and the majorization inequality against BigFloat references from the raw data; rows at `η = 800`, `-150`, `-800` and `-2000` and at both labels (the guarded ratio, the fixed row and the zero row); a start with logits `0, ±400, 800`; an adaptive column with zero squared entries taking the fixed fallback; the seeded problems solved with both models.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-03 The inner solve: cyclic coordinate descent, tolerances and the pass budget](@id PN-03)

**Statement.**

Each inner solve runs the scalar coordinate step of [CD-01](@ref) in cyclic order, without momentum, on a private
`SparseIterate` loaded from the accepted point. The loader zeroes and drops the stored entries and then writes the nonzero entries in
index order, so the solve and its order of passes depend on the accepted point alone. The solve uses the model's
`LSModel` and the penalty with its level converted to `Float64`; it calls the private pass loop of CD, not the public
`solve!` of `CDSolver`, so it repeats none of its validation and logs none of its warnings.

*Tolerances.* The change test is absolute, in the units of the coefficients: a run stops after a full pass in
which every coordinate changed by less than the threshold `δ`. The first run of each model in an iteration has
`δ = inner.tol`; `0` turns the test off, so that each run spends all of its passes. The solver's `tol` is a different
quantity: an absolute bound on the largest KKT score of the original problem, in the units of the gradient of the
summed loss ([PN-05](@ref)). `inner.relative` is not used.

*Budget.* `inner.maxpasses = B` is the budget of coordinate passes of one outer iteration, shared by the weighted
model, its refinements and the fixed model. For `B > 1` the weighted model, whose runs and refinements together
may use `B - ⌈B/4⌉` passes, leaves the rest for the fixed model, which may use whatever the weighted model did not
spend; for `B = 1` the weighted model has the single pass. A model with no passes left makes no run and gives no direction.
With `B = 0` no direction exists, and the iteration is stalled unless the point is already stationary.

*Cache refresh.* Before the first run of a model, the private residual of the `LSModel` is the model response minus
its weighted predictor at the accepted point, which in exact arithmetic is `-dᵢ/sᵢ` for row `i` of the weighted model
(`0` for a zero root `sᵢ = 0`, whose represented derivative is zero, so no division is made) and `-4dᵢ` for the fixed
model, and the curvature cache is cleared. The solver sets these values from the observation derivative `d` of
[PN-02](@ref), and does not subtract the images of the stored coefficients from the response (the `initialize!` of
[CD-01](@ref)): where those images are large and cancel, a small response can be rounded away and the cache loses a
representable gradient; [CD-05](@ref) describes this mechanism for the CD initializer. For example, at `η = 0` with `y = 0`, `d = 1/2` and `s = 1/2`, the residual is `-1` for the
weighted model and `-2` for the fixed model, and with `y = 1` the signs reverse. Refinements continue with the
maintained residual. The solve from `b = (2⁶⁰, -2⁶⁰, 0)` with `X = [1 1 -1; 1 1 1]`, `y = (0, 1)` and the
penalty `0.5` on the third coefficient only has the predictor zero and a score of `1/2`; seeded this way both models
move the third coefficient to `1`, and a residual formed from the stored images would be zero. This initialization
belongs to `ProxNewton`'s inner solve only: `CDSolver` keeps its own, and `ProximalGradientDescent` has no such cache.

*Forcing target and refinement.* At an accepted point with score `ρ = kkt`, a run meets the target when the
surrogate KKT score at its candidate is at most `max(0.1 tol, min(1/4, √ρ) ρ)`. The surrogate gradient is the original
gradient plus the curvature action of the model on the displacement, `∇f(b) + scale · Mᵀ(M (cand - b))` with `M = A`
and `scale = 1` for the weighted model and `M = X` and `scale = 1/4` for the fixed model. The calculation is
independent of the residual maintained by coordinate descent. The score is ProximalBase's
point-aware `kkt_violation` of that gradient at the candidate; it is not the score of the original problem, which
[PN-04](@ref) takes from the logistic gradient at a trial. While the target is missed, the threshold `δ` is divided by ten and
the run continues from the candidate, at most four times and within the allowance. The candidate is the point of the
last run whether or not the target was met.

A finite candidate with a negative composite slope ([PN-04](@ref)) goes to the search even if the target was missed; the
target is a measure of the inner accuracy, not a permission. A candidate equal to the accepted point has slope zero and
gives no direction. Every pass of every run is counted in `passes`, also where the search rejects the result.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_direction!`, `_pn_seed_residual!`, `_pn_surrogate_residual!`, `_pn_load!`, `_pn_step!`, `_pn_forcing`; `src/cd/solver.jl`: `_cd!`, `_CDState`.

**Tests.** `test/logistic_proxnewton.jl`: the seeded residual of both models, with a zero root and reversed labels, and the public cancelling-warm-start regression with coefficient images of `2⁶⁰` (an accepted step, the reduced objective against the BigFloat reference and the computed KKT score), which runs the default solver; the private fixed-only step of the same start, through the test mode of `_pn_step!`, is checked separately; a zero root from a naturally saturated accepted workspace; the model gradient at a candidate against a BigFloat formula; the forcing target met by a run; no run without a pass budget; the loader; passes counted when every trial is rejected and the sharing of a budget of `8` passes (`6` and `2`) and of one pass; a zero change tolerance (each run spends its allowance); loose and tight values of `inner.tol` reaching the same fit; a cyclic `CDSolver` with its default settings.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-04 The composite slope and the objective search](@id PN-04)

**Statement.**

For the accepted point `b`, its gradient `G`, the candidate `u` and the coefficients `cⱼ`, the composite slope is the linearized loss change plus the full penalty change
from `b` to `u`, `G·(u - b) + Σⱼ cⱼ(|uⱼ| - |bⱼ|)`, formed by coordinate before the terms are
added. In exact arithmetic it is an upper bound on the directional derivative of `F` along `u - b`, with equality
unless a coordinate changes sign; for `bⱼ = 1` and `uⱼ = -2` its penalty term is `+cⱼ`, while the penalty's
directional derivative is `-3cⱼ`. The search uses it as the Armijo quantity below. Where `bⱼ` and `uⱼ` have the same sign (zero counts for either), the term is `(Gⱼ + cⱼ sign) (uⱼ - bⱼ)`
with the common sign; where they differ it is split at zero,
`(Gⱼ + sign(uⱼ) cⱼ) uⱼ - (Gⱼ + sign(bⱼ) cⱼ) bⱼ`. For `bⱼ = 1`, `uⱼ = 2` and `cⱼ = λ` the term is `(Gⱼ + λ)(2 - 1)`; for
`bⱼ = 1` and `uⱼ = -2` it is `(Gⱼ - λ)(-2) - (Gⱼ + λ)(1)`. The grouping keeps a coordinate at its
subgradient (`Gⱼ + cⱼ = 0`) exactly at zero slope, which a difference of the two large penalty totals does not. A
direction whose slope is not finite and negative is not searched.

The search tries the steps `t = 1, 1/2, …, 2⁻³⁹` (at most 40 trials) at `b + t (u - b)`. A trial whose predictor, objective, gradient
or score is not finite is ineligible. With `actual` the difference of the two computed finite objectives and
`required = 10⁻⁴ t · slope`, a trial is accepted when `actual < -8 eps(F)` and `actual ≤ required`, `F` being the
objective at the accepted point; or when `|actual| ≤ 8 eps(F)` and `|required| ≤ 8 eps(F)`, the near-tie band, and the
trial's ProximalBase KKT score of the original problem is strictly smaller than that of the accepted point. The second
rule uses the KKT score to decide near ties in the computed objective: with `F = 100`, changes of order `-10⁻¹⁵` and scores `4·10⁻⁸` at the
accepted point and `2·10⁻⁸` at the trial, the trial is accepted; with equal scores it is rejected. A step that
rounds to no displacement is not a success and ends the search, and so does the last trial. The first accepted
trial becomes the accepted point with its own objective, gradient and score, computed at that point. The near-tie rule can accept an increase of at most `8 eps(F)` in the computed objective.

If the weighted model gives no accepted step, the fixed model is tried within the remaining budget
([PN-03](@ref)); if it gives none either, the solve is `:stalled`.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_slope`, `_pn_accepts`, `_pn_search!`.

**Tests.** `test/logistic_proxnewton.jl`: the slope against the cases above, the upper-bound property at a sign change, against BigFloat formulas and at a stationary coordinate with large totals; the acceptance rule, including the tie example; the search accepting a model direction with a fresh objective, gradient and score, a displacement that rounds to nothing, and an ascent direction that fails every trial; the fixed model alone reaching the tolerance on seeded problems of three shapes.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-05 Convergence, mutation and failure boundary](@id PN-05)

**Statement.**

`converged = true` reports a computed result: the largest ProximalBase KKT score of the original problem at the
returned point, `max(0, |Gⱼ| - cⱼ)` at a zero coefficient and `|Gⱼ + cⱼ sign(bⱼ)|` elsewhere, with `G` a gradient formed at that point
by ProximalBase's fused logistic oracle, is finite and at most `tol`. It is not an exact-arithmetic certificate, it does not bound the
error of the coefficients, and the gradient it uses is rounded. The scale of the residual is that of the gradient
of the summed loss; a mean-scale level is passed as `n * λ` ([IN-09](@ref)). The problem need not have a minimizer
([IN-09](@ref), *Unattained minima*): for a one-class sample with an unpenalized intercept the
score can fall below `tol` at a finite point and `converged = true` can be reported. The solver does not detect that case.

The solve computes on private buffers and writes the caller's coefficients once, with the accepted point, at a normal return
(converged, `:maxiter` or `:stalled`). An exception from the inner solve or the logistic oracle propagates and leaves the
caller's coefficients unchanged; so does a refusal. The borrowed `X`, `y`, the penalty weights and the scratch of the
loss are never written. The adaptive column check and fallback are specified in [PN-02](@ref).
An error from [CD-04](@ref) that reaches the caller, such as a curvature that underflows
in the fixed model or overflows in a coordinate step, propagates as an `ArgumentError`.
A trial with a nonfinite quantity is ineligible under [PN-04](@ref).

**Applies to.** `ProxNewton`; the result and mutation rules of [RES-01](@ref) and [RES-03](@ref) refer here for it.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_solve_newton!`, `_pn_search!`.

**Tests.** `test/logistic_proxnewton.jl`: results against the independent objective and KKT scores for an intercept-only fit, an identifiable zero-penalty fit (a damped Newton reference), regularized fits with active and inactive coefficients, weights (unit, zero and very large) and seeded problems; agreement with `ProximalGradientDescent`; the one-class sample; rollback after a curvature that underflows or overflows and after a nonfinite start, with the inputs unchanged.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).
