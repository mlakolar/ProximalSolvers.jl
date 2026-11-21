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
`Vector{Float64}` start. It minimizes the objective of [IN-09](@ref),

```math
F(b)=\sum_{i=1}^n \{\log(1+e^{\eta_i})-y_i\eta_i\}+\sum_{j=1}^{p} c_j|b_j|,\qquad \eta=Xb,\quad c_j=\lambda w_j,
```

starting at the supplied coefficients, with the intercept convention of [IN-09](@ref) (a
column of ones with penalty weight zero). The level `lambda` is converted to `Float64` once,
and the penalty weights are used as supplied; ProximalBase's `kkt_violation` receives
that converted penalty.

The inputs and the order of refusals are those of [IN-09](@ref), with `ProxNewton` in the place of
`ProximalGradientDescent`, except that the first check is the loss: any loss other than a
raw `LogisticLoss` or one `Scaled` wrapper of it is refused with an `ArgumentError` that names `ProxNewton`
and the least-squares solvers. A `Scaled(LogisticLoss)` is refused as in [IN-09](@ref). The refusal of a
nonbinary response names `ProxNewton`. `AccProxGradDescent` and `CDSolver` refuse the logistic loss with an
`ArgumentError` that names `ProximalGradientDescent` and `ProxNewton`. Keywords of `solve!` and positional
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

**Tests.** `test/logistic_proxnewton.jl`: the constructor and its refusals; the result fields, accessors and display against the independent objective and scores; a zero iteration budget at a stationary and a nonstationary start; budgets of iterations and of passes; the refusals above with the coefficients unchanged, including the text that names `ProxNewton`.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) (scope) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-02 The weighted and the fixed least-squares model](@id PN-02)

**Statement.**

At an accepted point with predictor `η = X b` and observation derivative `d = σ(η) - y` (from ProximalBase, which
evaluates it without cancellation in the saturated tails), a model is a least-squares problem in the step
whose gradient at `b` is the gradient `Xᵀd` of the loss. Two models are formed, and each is solved with the scalar
`LSModel` of [CD-01](@ref).

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

*Fixed model.* The `LSModel` with loss scale `1/4`, the borrowed `X` and the response `η - 4d`. In exact arithmetic its
gradient at `b` is `Xᵀd` and its Hessian is `XᵀX/4`, which bounds that of the loss, so that
`f(b + Δ) ≤ f(b) + ∇f(b)ᵀΔ + ‖XΔ‖²/8` for every `Δ`.

A model whose design or response has a nonfinite entry is unavailable for that iteration. The weighted model keeps
one `n × p` design in addition to vectors of length `n` and `p`; the fixed model does not copy `X`. The residual and
curvature caches of a model are refreshed from its current data at the start of every inner solve
([PN-03](@ref)). The fixed model is used only after the weighted model gives no accepted step, within the remaining
pass budget of the iteration. Neither model forms or factorizes a coefficient Hessian.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_adaptive_model!`, `_pn_fixed_response!`.

**Tests.** `test/logistic_proxnewton.jl`: the gradient and Hessian identities of both models and the majorization inequality against BigFloat references from the raw data; rows at `η = 800`, `-150`, `-800` and `-2000` and at both labels (the guarded ratio, the fixed row and the zero row); a start with logits `0, ±400, 800`; the seeded problems solved with both models.

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

*Forcing target and refinement.* At an accepted point with score `ρ = kkt`, a run meets the target when the
score of the model's gradient at its candidate is at most `max(0.1 tol, min(1/4, √ρ) ρ)`. That gradient is the original
gradient plus the curvature action of the model on the displacement, `∇f(b) + scale · Mᵀ(M (cand - b))` with `M = A`
and `scale = 1` for the weighted model and `M = X` and `scale = 1/4` for the fixed model; it is not formed from the
model's own residual, which subtracts the working response a second time. The score is ProximalBase's
point-aware `kkt_violation` at the candidate. While the target is missed, the threshold `δ` is divided by ten and
the run continues from the candidate, at most four times and within the allowance. The candidate is the point of the
last run whether or not the target was met.

A finite candidate with a negative composite slope ([PN-04](@ref)) goes to the search even if the target was missed; the
target is a measure of the inner accuracy, not a permission. A candidate equal to the accepted point has slope zero and
gives no direction. Every pass of every run is counted in `passes`, also where the search rejects the result.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_direction!`, `_pn_surrogate_residual!`, `_pn_load!`, `_pn_step!`, `_pn_forcing`; `src/cd/solver.jl`: `_cd!`, `_CDState`.

**Tests.** `test/logistic_proxnewton.jl`: the model gradient at a candidate against a BigFloat formula; the forcing target met by a run; no run without a pass budget; the loader; passes counted when every trial is rejected and the sharing of a budget of `8` passes (`6` and `2`) and of one pass; a zero change tolerance (each run spends its allowance); loose and tight values of `inner.tol` reaching the same fit; a cyclic `CDSolver` with its default settings.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).

## [PN-04 The composite slope and the objective search](@id PN-04)

**Statement.**

For the accepted point `b`, its gradient `G`, the candidate `u` and the coefficients `cⱼ`, the composite slope is the first-order change of
`F` along the step from `b` to `u`, `G·(u - b) + Σⱼ cⱼ(|uⱼ| - |bⱼ|)`, formed by coordinate before the terms are
added. Where `bⱼ` and `uⱼ` have the same sign (zero counts for either), the term is `(Gⱼ + cⱼ sign) (uⱼ - bⱼ)`
with the common sign; where they differ it is split at zero,
`(Gⱼ + sign(uⱼ) cⱼ) uⱼ - (Gⱼ + sign(bⱼ) cⱼ) bⱼ`. For `bⱼ = 1`, `uⱼ = 2` and `cⱼ = λ` the term is `(Gⱼ + λ)(2 - 1)`; for
`bⱼ = 1` and `uⱼ = -2` it is `(Gⱼ - λ)(-2) - (Gⱼ + λ)(1)`. The grouping keeps a coordinate at its
subgradient (`Gⱼ + cⱼ = 0`) exactly at zero slope, which a difference of the two large penalty totals does not. A
direction whose slope is not finite and negative is not searched.

The search tries the steps `t = 1, 1/2, …, 2⁻³⁹` (at most 40 trials) at `b + t (u - b)`. A trial whose predictor, objective, gradient
or score is not finite is ineligible. With `actual` the difference of the two computed finite objectives and
`required = 10⁻⁴ t · slope`, a trial is accepted when `actual < -8 eps(F)` and `actual ≤ required`, `F` being the
objective at the accepted point; or when `|actual| ≤ 8 eps(F)` and `|required| ≤ 8 eps(F)`, the rounding of `F`, and the
trial's ProximalBase KKT score of the original problem is strictly smaller than that of the accepted point. The second
rule is for ties that the objective cannot decide: with `F = 100`, changes of order `-10⁻¹⁵` and scores `4·10⁻⁸` at the
accepted point and `2·10⁻⁸` at the trial, the trial is accepted; with equal scores it is rejected. A step that
rounds to no displacement is not a success and ends the search, and so does the last trial. The first accepted
trial becomes the accepted point with its own objective, gradient and score, computed at that point.

If the weighted model gives no accepted step, the fixed model is tried within the remaining budget
([PN-03](@ref)); if it gives none either, the solve is `:stalled`.

**Applies to.** `ProxNewton`.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_pn_slope`, `_pn_accepts`, `_pn_search!`.

**Tests.** `test/logistic_proxnewton.jl`: the slope against the cases above, against BigFloat formulas and at a stationary coordinate with large totals; the acceptance rule, including the tie example; the search accepting a model direction with a fresh objective, gradient and score, a displacement that rounds to nothing, and an ascent direction that fails every trial; the fixed model alone reaching the tolerance on seeded problems of three shapes.

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
loss are never written. Errors that the coordinate step of [CD-04](@ref) raises for the range of a model, for
example a curvature that underflows because every row of a column is saturated on the side of its label, or one that
overflows, are not handled or retried: they propagate as `ArgumentError`s. A numerical
failure inside a trial of the search (a nonfinite quantity) makes that trial ineligible and is not an exception.

**Applies to.** `ProxNewton`; the result and mutation rules of [RES-01](@ref) and [RES-03](@ref) refer here for it.

**Code.** `src/solvers/logistic_proxnewton.jl`: `_solve_newton!`, `_pn_search!`.

**Tests.** `test/logistic_proxnewton.jl`: results against the independent objective and KKT scores for an intercept-only fit, an identifiable zero-penalty fit (a damped Newton reference), regularized fits with active and inactive coefficients, weights (unit, zero and very large) and seeded problems; agreement with `ProximalGradientDescent`; the one-class sample; rollback after a curvature that underflows or overflows and after a nonfinite start, with the inputs unchanged.

**Sources.** [Issue #447](https://github.com/mlakolar/ProximalSolvers.jl/issues/447) and [pull request #496](https://github.com/mlakolar/ProximalSolvers.jl/pull/496).
