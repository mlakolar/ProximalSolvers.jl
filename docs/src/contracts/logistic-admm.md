# ADMM for sparse logistic regression

`LogisticADMM` solves the sparse logistic regression of [IN-09](@ref) by the alternating direction method of
multipliers on the predictor split `t = X b`. Each iteration approximately solves a lasso subproblem in the
coefficients with the scalar coordinate step of [CD-01](@ref), solves one scalar logistic proximal problem per
observation, and updates the dual.
The input gate is that of [IN-09](@ref); the clauses below specify the solver, its subproblems, its stopping test,
its result and its failure boundary. It is a solver of its own, not a method of the consensus `ADMMSolver` of
[ADM-01](@ref): its predictor and dual have one entry per observation.

The ideal iteration, with exact minimizations in exact arithmetic, is scaled two-block ADMM for `min ℓ(t) + g(b)`
subject to `t = X b`, with `ℓ(t) = Σᵢ {log(1 + e^{tᵢ}) - yᵢtᵢ}`, the penalty `g` and the scaled dual `u`:

```math
\begin{aligned}
b^{k+1} &= \arg\min_b\ g(b)+\tfrac{\rho}{2}\|Xb-t^k+u^k\|_2^2,\\
t^{k+1} &= \arg\min_t\ \ell(t)+\tfrac{\rho}{2}\|t-Xb^{k+1}-u^k\|_2^2,\\
u^{k+1} &= u^k+Xb^{k+1}-t^{k+1}.
\end{aligned}
```

The computed iteration replaces the first minimization by a coordinate-descent run within a pass budget, which can
stop before the minimizer ([LA-02](@ref)), and the second by computed scalar roots ([LA-03](@ref)).

## [LA-01 Inputs, result and stop reasons](@id LA-01)

**Statement.**

`LogisticADMM(; ρ = 0.25, maxiter = 10_000, tol = 1e-7, abstol = 1e-8, reltol = 1e-6, abstol_dual = abstol, inner)`
is passed to `solve!(b, LogisticLoss(y, X), g, method; t = nothing, u = nothing)` with ProximalBase's raw
`LogisticLoss(y, X)`, a penalty `g` that is `NormL1(lambda)` or `NormL1(lambda, w)`, and a dense `Vector{Float64}`
start `b`. It minimizes the summed logistic objective and penalty of [IN-09](@ref) and [PN-01](@ref). The level
`lambda` is converted to `Float64` once, the penalty weights are used as supplied, and ProximalBase's
`kkt_violation` receives that converted penalty.

The constructor refuses, with an `ArgumentError`: a `ρ` whose conversion to `Float64` is not finite or lies outside
`[1e-10, 1e10]` (so `ρ = 1e-11`, `1e11`, `0`, a negative value, `NaN` and `Inf` are refused); a negative `maxiter`;
a `tol`, `abstol`, `reltol` or `abstol_dual` that is not finite and nonnegative, or that is positive but rounds to
zero in `Float64`; a keyword `inner` that is not a `CDSolver`; an `inner` that is not in cyclic order
(`order = :cyclic`); and an `inner` with `maxpasses = 0`, with which the coefficient step could not move. A keyword
`ρ`, `tol`, `abstol`, `reltol` or `abstol_dual` that is not a `Real`, or a `maxiter` that is not an `Integer`,
raises a `TypeError` from the keyword signature. The positional constructor
`LogisticADMM(ρ, maxiter, tol, abstol, reltol, abstol_dual, inner)` takes `Real` values, an `Integer` `maxiter` and a
`CDSolver`; other argument types raise a `MethodError`. The default `inner` is
`CDSolver(order = :cyclic, momentum = false, relative = false, tol = 1e-8, maxpasses = 1000)`; [LA-02](@ref) uses
its `maxpasses` and `tol`, not its `relative`, `momentum` or `rng`. The range of `ρ` bounds the exact width of the
bracket of the scalar root by `1/ρ ≤ 1e10` ([LA-03](@ref)) and the dual `u = w/ρ` by `1e10 |w|`. The default `ρ = 1/4` is the
bound on the curvature `σ(1 - σ)` of the loss of one observation. `ρ` is a tuning parameter: the iteration count
depends on it, and the method is not presumed to be faster than `ProximalGradientDescent` or `ProxNewton`.

The inputs and the order of refusals are those of [IN-09](@ref), with `LogisticADMM` in the place of
`ProximalGradientDescent`, except that the first check is the loss: any loss other than a raw `LogisticLoss` or
one `Scaled` wrapper of it is refused with an `ArgumentError` that names `LogisticADMM` and the least-squares
solvers. A `Scaled(LogisticLoss)` is refused as in [IN-09](@ref). The refusal of a nonbinary response names
`LogisticADMM`. Keywords of `solve!` other than `t` and `u` and positional arguments after the solver are refused
as for the other solvers. After that gate, `LogisticADMM` adds a check on memory ranges to the alias rule of
[IN-09](@ref): coefficients `b` whose memory range overlaps that of `X`, `y`, the scratch `f.tmp` of the loss or the
penalty weights are refused with an `ArgumentError`, also where `Base.mightalias` reports no alias (an offset
`unsafe_wrap` of the storage of `X`, for example). Then the start: a nonfinite predictor `X * b`, objective, gradient
or KKT score at `b` raises an `ArgumentError` ("start from a point where f is finite", or the gradient or score
variant). Then a supplied `t` and `u`, each in turn: it must be a `Vector{Float64}` (otherwise an `ArgumentError`)
with one entry per row of `X` (otherwise a `DimensionMismatch`), its memory must not overlap that of `b`, `X`, `y`,
`f.tmp`, the penalty weights or the other supplied vector (by `Base.mightalias` or by overlapping memory ranges, an
`ArgumentError`), and its entries must be finite (an `ArgumentError`). Last, each with an `ArgumentError`: a supplied
`u` whose product `ρ * u` is not finite; a supplied `u` for which the difference `t - u` of the starting predictor
and `u`, formed directly in `Float64`, is not finite; and a working response `t - w/ρ` that is not finite. All
refusals precede any write to `b`, `t` and `u`.

`ADMMSolver` refuses a `LogisticLoss` or a `Scaled` one, for every `z`, with an `ArgumentError` that names
`LogisticADMM`. The refusal follows its keyword and option checks and precedes the check of `z` and any write to `z`
or to a supplied `u`. `AccProxGradDescent` and `CDSolver` refuse the loss with an `ArgumentError` that names
`ProximalGradientDescent`, `ProxNewton` and `LogisticADMM`.

*State.* The start is `t⁰ = t` when `t` is given and `X * b` otherwise, and `u⁰ = u` when `u` is given and
`(σ(t⁰) - y)/ρ` otherwise, with `σ(t) - y` formed as in [LA-03](@ref). The solve holds the dual as `w = ρ u` and
reports `u = w/ρ`; the default initial `w` lies in `[-1, 1]`, and a later computed `w` can leave that interval by
rounding ([LA-03](@ref)). With the default dual, an exact minimizer `b` of the same objective, with `t⁰ = X b`, is a
fixed point of the ideal iteration. A computed solution of another solver, or a minimizer for another level, is not
such a point, and the iteration can move from it. `u` is the scaled dual of the `ρ` it was computed with: a restart
with another `ρ` passes `u * ρ_old / ρ_new`. The start `b` warm-starts the first coefficient step and sets the
default `t⁰`.

`solve!` returns a `LogisticADMMResults` whose `minimizer` is the caller's vector, with

| Field | Meaning |
|:--|:--|
| `minimum` | the objective `F` at the returned point, the loss from ProximalBase plus the penalty |
| `kkt` | the largest ProximalBase KKT score of the original problem at the returned point, from a gradient formed at that point |
| `tolerance` | the `tol` of the solver |
| `iterations` | the completed iterations |
| `passes` | all coordinate passes of the coefficient steps ([LA-02](@ref)), including those of an iteration discarded by `:prox_failed` |
| `root_iterations` | all steps of the scalar roots ([LA-03](@ref)), counted in the same way |
| `r_norm`, `s_norm`, `eps_pri`, `eps_dual` | the residuals and thresholds of [LA-04](@ref) at the last completed iteration; `NaN` when no iteration completed |
| `inner_kkt`, `inner_met` | the score of the coefficient step of the last completed iteration and whether it met its forcing target ([LA-02](@ref)); `NaN` and `false` when no iteration completed |
| `dual_kkt` | `kkt_violation(g, ρ Xᵀu, b)` at the returned `b` and `u`, from a fresh product: the score of `0 ∈ ∂g(b) + ρ Xᵀu`; `Inf` where `ρ Xᵀu` overflows |
| `predictor_residual` | the largest entry of `abs.(σ.(t) .- y .- ρ .* u)` at the returned `t` and `u`: the residual of `∇ℓ(t) = ρ u` |
| `t`, `u` | the returned predictor and dual, each the caller's vector when one was passed (left with its entries when no iteration completed) and a new vector otherwise |
| `ρ` | the `ρ` of the solver |
| `converged` | whether the stop reason is `:converged` |
| `stop_reason` | `:converged`, `:maxiter`, `:stalled` or `:prox_failed` |

The accessors `minimizer`, `minimum`, `iterations` and `converged` read the fields of the same name. After each
completed iteration the solver tests convergence first ([LA-04](@ref)), giving `:converged`. Otherwise, when the
iteration left `b`, `t` and the working dual `w` unchanged in every bit (`isequal` on each vector), the solve ends
with `:stalled`; the test is on `w`, so the reported `u = w/ρ` can differ from a supplied `u` whose product `ρ u`
rounded (a subnormal `u`, for example).
Otherwise, when `iterations == maxiter`, it ends with `:maxiter`. An iteration in which a scalar root fails is
discarded and the solve ends with `:prox_failed` and the last completed iteration ([LA-05](@ref)). `maxiter = 0`
makes no iteration: the result has the objective and KKT score of the start, `NaN` residuals, `:maxiter` and
`converged = false`, also at a stationary start. No warning is logged for any stop.

**Applies to.** `LogisticADMM` with a raw `LogisticLoss{Float64}` and `NormL1` on a dense `Vector{Float64}`; the
logistic refusal of `ADMMSolver`.

**Code.** `src/solvers/logistic_admm.jl`: `LogisticADMM`, `LogisticADMMResults`, `solve!`, `_la_workspace`,
`_check_la_vector`, `_solve_logistic_admm!`; `src/solve.jl`: `_check_admm_logistic_problem`, `_check_logistic_problem`,
`_logistic_solver_name`, `_logistic_method_error`; `src/solvers/admm.jl`: the logistic refusal in `solve!`.

**Tests.** `test/logistic_admm.jl`: the constructor and its refusals, including `ρ` at and outside `1e-10` and
`1e10`, a keyword `inner` that is not a `CDSolver`, and the `TypeError` and `MethodError` of other argument types;
the workspace at the start with the default and with a supplied `t` and `u`; the result fields, accessors and
display; `maxiter = 0` at a nonstationary start and at a minimizer, `maxiter = 1`, a spent budget; two stalled solves
with a positive score, one with a subnormal supplied `u`; the refusals with `b`, `t`, `u`, `X` and `y` unchanged,
including the text that names `LogisticADMM`, coefficients wrapped at an offset in the storage of `X`, `y`, `f.tmp`
and the weights, the overlap of `t` and `u` with each other and with the other arrays, a supplied `t - u` that
overflows only when formed directly, and the refusals of `ADMMSolver` on a `Vector` and a `Matrix` with the raw and
the scaled loss and a supplied `u` that is left unchanged. `test/logistic_pgd.jl` and
`test/logistic_proxnewton.jl` match the refusal texts of `ADMMSolver`, `AccProxGradDescent` and `CDSolver`.

**Sources.** [Issue #448](https://github.com/mlakolar/ProximalSolvers.jl/issues/448) (formulation, scope and
acceptance) and [pull request #507](https://github.com/mlakolar/ProximalSolvers.jl/pull/507) (plan and implementation).

## [LA-02 The coefficient step and its inner accuracy](@id LA-02)

**Statement.**

The coefficient step approximately minimizes `g(b) + (ρ/2) ‖X b - resp‖²` with the response `resp = t - w/ρ` formed
from the predictor and dual of the last completed iteration; within its pass budget it can stop before the minimizer. It runs the scalar coordinate step of [CD-01](@ref) in cyclic
order, without momentum, on the `LSModel` with response `resp`, the borrowed `X` and the loss scale `ρ`, and with the
penalty with its level converted to `Float64`. It calls the private pass loop of CD, not the public `solve!` of
`CDSolver`, so it repeats none of its validation and logs none of its warnings. The iterate is a private
`SparseIterate`, loaded once from the start (the nonzero entries in index order) and carried from one iteration to
the next, so that each step starts from the coefficients of the last completed iteration.

*Seeding.* Before each step the residual of the model is set to `resp - X b`, with the image `X b` formed by a
matrix-vector product after the previous step (or at the start); the response alone changes between iterations, so
the curvature cache of the model, the squared norms of the columns of `X`, is kept from one step to the next.

*Tolerances and budget.* The change test is absolute, in the units of the coefficients: a run stops after a full pass
in which every coordinate changed by less than the threshold `δ`. The first run of each step has `δ = inner.tol`;
`0` turns the test off, so that the run spends its passes. `inner.maxpasses` is the budget of coordinate passes of
the step of one iteration, shared by its run and its refinements. `inner.relative` is not used.

*Inner score and forcing target.* After each run the score of the step is ProximalBase's `kkt_violation` of
`q = ρ Xᵀ(X b - resp)` at the run's coefficients `b`, with `X b` from a fresh product; it does not use the residual
maintained by coordinate descent, and it is `NaN` when `q` has a nonfinite entry. The forcing target is
`max(0.1 tol, 0.1 kkt)`, with `kkt` the score of the original problem at the coefficients of the last completed
iteration. While the target is missed, `δ` is divided by ten and the run continues from its coefficients, at most four
times and within the budget. The coefficients of the last run are the result of the step whether or not the target
was met; `inner_kkt` and `inner_met` report its score and the comparison. The target does not decide the stop of the
solve ([LA-04](@ref)): the score is formed from `resp`, whose rounding grows with `max |t|` and `max |w|/ρ`, so its
computed value can stay above a target that the score of the original problem at the same point meets.

Every pass of every run is counted in `passes`, also in an iteration that a failed root discards.

**Applies to.** `LogisticADMM`.

**Code.** `src/solvers/logistic_admm.jl`: `_la_beta_step!`, `_la_workspace`; `src/solvers/logistic_proxnewton.jl`:
`_pn_load!`; `src/cd/solver.jl`: `_cd!`, `_CDState`, `_copy_dense!`.

**Tests.** `test/logistic_admm.jl`: the score of a step against a `BigFloat` evaluation of the subproblem's KKT score
from the data, the maintained residual against `resp - X b`, the forcing target met from a cold start, and a target
missed with a single pass of budget, with the pass counted; the seeded problems, whose returned points are checked
against the independent objective and KKT score.

**Sources.** [Issue #448](https://github.com/mlakolar/ProximalSolvers.jl/issues/448) and
[pull request #507](https://github.com/mlakolar/ProximalSolvers.jl/pull/507).

## [LA-03 The scalar logistic proximal root and the dual update](@id LA-03)

**Statement.**

After the coefficient step, for each observation `i`, `v = (X b)ᵢ + wᵢ/ρ` and the predictor is the root of

```math
h(s) = \sigma(s) - y_i + \rho\,(s - v),\qquad h'(s) = \sigma(s)\{1-\sigma(s)\} + \rho > 0 .
```

*Residual.* `σ(s) - y` is formed from `e = exp(-|s|)`: for `y = 0`, `1/(1 + e)` at `s ≥ 0` and `e/(1 + e)` at
`s < 0`; for `y = 1`, `-e/(1 + e)` at `s ≥ 0` and `-1/(1 + e)` at `s < 0`. No exponential overflows. For `y = 0` and
`s < 0` the value `e/(1 + e)` is positive while `exp(-|s|)` is positive (`s` above about `-745.13`), and subnormal for
`s` below about `-708.40` until `exp(-|s|)` underflows to `0`; at `s = -720` it is about `2.0e-313`. The formula
`1/(1 + exp(-s))` gives `0` once `exp(-s)` overflows, for `s` below `-log(floatmax(Float64)) ≈ -709.78`.
`σ(1 - σ)` is `e/(1 + e)²`.

*Bracket.* `h` is increasing and `|σ - y| < 1`, so in exact arithmetic the root lies in `[v - 1/ρ, v]` for `y = 0`
and in `[v, v + 1/ρ]` for `y = 1`. For `y = 0`, `v = 0` and `ρ = 1` the root solves `s + σ(s) = 0`, about
`-0.40106`, inside `(-1, 0)`; for `y = 1` it is the mirror `+0.40106`. The working bracket has the far end `v ∓ 1/ρ`
rounded to `Float64` and clamped to `±floatmax(Float64)`. It can therefore be wider than `1/ρ` (for `v = 2⁸⁶`,
`y = 1` and `ρ = 1e-10` its width is `2³⁴ ≈ 1.7e10`), and it encloses the exact root only up to that rounding:
near `±floatmax` the exact root can lie outside it (for `y = 0` and `v = -floatmax(Float64)`, `h(v) > 0` puts the
root below `v`).

*Iteration.* The iteration starts at `s = v`. With the computed terms `r = σ(s) - y` and `q = ρ(s - v)`, the computed
`h = r + q` and the threshold `B = 4 eps(Float64) (|r| + |q|)`, each pass of the loop, in this order:

1. returns `s` when `|h| ≤ B`, which includes `h = 0`;
2. updates the bracket from the sign of `h`: `lo = s` when `h < 0`, otherwise `hi = s`;
3. returns the end of the bracket with the smaller computed `|h|` (evaluating `h` there when it was not evaluated)
   when no `Float64` lies strictly inside it;
4. fails when `cap` steps have been taken;
5. forms the Newton point `s - h/(σ(1 - σ) + ρ)` and returns `s` when that point rounds to `s`;
6. replaces the Newton point by the midpoint `lo/2 + hi/2` when it is not strictly inside `(lo, hi)`, or when this is
   the third step of a window of steps in which the bracket did not halve (a window starts at the first step and
   after each pass in which the width is at most half the width at the start of the window); it returns the better
   end of the bracket as in step 3 if that midpoint, after rounding, is not strictly inside;
7. moves to the new point, which counts as one step in `root_iterations`.

`B` is a threshold formed from the computed terms, not a bound on the error of the computed `h`: for `y = 0` and
`v = -746`, `exp(-746)` underflows to `0`, so `r`, `h` and `B` are `0` at `s = v` while the exact `h(v)` is positive,
and `v` is returned. Because tests 1 and 3 come before test 4, a root can still succeed in
the pass that reaches the cap. The stop of step 5 compares the Newton point with `s` before any replacement, so a
midpoint that replaced a Newton point is not returned in the pass that forms it; a later pass at that midpoint can
return it. For `y = 1`, `v = 40` and `ρ = 1` the bracket starts at `lo = 40`, the Newton point rounds to `40`, and the
answer is `40`; the root is `40 + 4.2e-18`, and a stop tested after the replacement would return the midpoint `40.5`.

*Step budget.* The budget is `cap = 3 (34 + 1074 + 2) = 3330` steps, sized as three steps for each halving of a
bracket of the exact width `1/ρ < 2³⁴` down to the smallest spacing `2⁻¹⁰⁷⁴` of `Float64`, with two halvings to
spare. It is a budget, not a proved bound on the steps of a successful root: the working bracket can start wider
than `1/ρ`, and a rounded midpoint can keep more than half of the width (between `1.0` and `nextfloat(1.0, 3)` the
midpoint rounds to `nextfloat(1.0, 2)`). A nonfinite `v` or a spent budget is a failed root ([LA-05](@ref)).

*Accuracy.* The accuracy is stated as a backward error. For a returned `s`, let `v'` be the argument for which `s` is
an exact root, `v' = s + (σ(s) - y)/ρ` in exact arithmetic. The tests check
`|v' - v| ≤ 32 eps(Float64) max(|v|, |s|)` on the arguments they cover; this is a tested bound, not a proved one.
These formulas and stopping rules do not establish a small error in units of the last place of `s`. For `y = 0`,
`v = 500` and `ρ = 0.001` the root is about `4.15e-17`, and the computed `h` is exactly `0` at `s = 0`, `1e-17` and
`1e-16`. The first Newton point there rounds to the end `lo = -500`, so the midpoint `0` replaces it; the next pass
returns that midpoint by test 1, with a backward error of about `0.09` units of `eps(Float64) · 500`.

*Dual update.* The dual is `w = ρ (v - s)`, from the same `v` as the root, so that `w = σ(t) - y` holds to the
accuracy of `h`; `predictor_residual` reports the largest difference at the returned point ([LA-01](@ref)). The
rounded update need not lie in `[-1, 1]`: for `y = 0`, `v = 2⁵⁵ + 8` and `ρ = 1/4` the root succeeds and `w = 2`.

**Applies to.** `LogisticADMM`.

**Code.** `src/solvers/logistic_admm.jl`: `_la_residual`, `_la_curvature`, `_la_scalar`, `_la_endpoint`, `_la_root`,
`_la_predictor_step!`, `_LA_ROOT_CAP`.

**Tests.** `test/logistic_admm.jl`: the residual and the curvature against `BigFloat` formulas, including the
subnormal value at `s = -720`; the worked examples above, the midpoint regression, the plateau (with its step count),
the subnormal residual at `v = -720` with `ρ = 1e-10` and its mirror, the zero threshold at `v = -746`, the working
bracket at `v = 2⁸⁶`, the rounded midpoint between `1.0` and `nextfloat(1.0, 3)`, the dual update at `v = 2⁵⁵ + 8`,
the side of the root; a nonfinite argument and a reduced cap giving a failure; a sweep over `v ∈ {±1e300, ±800, -720, -50, -1, 0, 1e-3, 3, 40, 500}`, `y ∈ {0, 1}` and
`ρ ∈ {1e-10, 1e-3, 1/4, 1, 1e3, 1e10}` against a 256-bit `BigFloat` bisection, with the backward error, the bracket
and the implied forward bound, and step counts below the budget; each root and dual of one iteration against
`_la_root` and `ρ (v - s)`.

**Sources.** [Issue #448](https://github.com/mlakolar/ProximalSolvers.jl/issues/448) and
[pull request #507](https://github.com/mlakolar/ProximalSolvers.jl/pull/507) (the prototype, its midpoint false root
and the backward-error statement).

## [LA-04 Residuals, stopping and certification](@id LA-04)

**Statement.**

With `b`, `t` and `w` from the last completed iteration and `b⁺`, `t⁺` and `w⁺` from the current one, the residuals
and thresholds are

```math
r=\|Xb^+-t^+\|_2,\quad s=\rho\|X^\top(t^+-t)\|_2,\quad
\epsilon_{\rm pri}=\sqrt n\,\text{abstol}+\text{reltol}\max(\|Xb^+\|_2,\|t^+\|_2),\quad
\epsilon_{\rm dual}=\sqrt p\,\text{abstol}_{\rm dual}+\text{reltol}\,\|X^\top w^+\|_2,
```

with `p = length(b)`, which counts an intercept column of `X`, and `w⁺ = ρ u⁺` the working dual. Each residual and
threshold is formed from a product of its own: `X b⁺` from the coefficient step, `Xᵀ(t⁺ - t)` and `Xᵀw⁺`. In exact
arithmetic `Xᵀw⁺` also equals `q - ρ Xᵀ(t⁺ - t)`, with `q` the vector of the last run of the coefficient step
([LA-02](@ref)); the rounding of those two terms can leave a nonzero value where the direct product is `0`, so the
threshold does not use that form.

After each completed iteration the solver forms the objective `F` at `b⁺`, from ProximalBase's
`value_and_gradient_from_predictor!` at `X b⁺` plus the penalty, and the KKT score `kkt = kkt_violation(g, G, b⁺)`
of the original problem from the gradient `G` that the same call forms. The iteration converges when
`r ≤ ε_pri`, `s ≤ ε_dual` and `kkt ≤ tol`; a residual or threshold that is not finite fails its test. The score of
the coefficient step does not enter the test. Small residuals with a score above `tol` cannot give `:converged`, and
neither can a score below `tol` with a residual above its threshold; such an iteration continues the solve or ends
it with `:stalled` or `:maxiter` ([LA-01](@ref)). With mismatched settings, such as a large `abstol` and a small `tol`,
the solve can run to `maxiter`.

*Products.* An iteration whose coefficient step makes `m` runs (`1 ≤ m ≤ 5`) forms `2m + 3` products with `X` or
`Xᵀ` of cost `O(np)`: `X b` and `Xᵀ(X b - resp)` per run, `Xᵀ(t⁺ - t)`, `Xᵀw⁺`, and the gradient `Xᵀd` in
ProximalBase's oracle. The start forms `X b` and `Xᵀd` and the return forms `Xᵀu` for `dual_kkt`. The coordinate passes are counted
separately in `passes`.

`converged = true` reports computed checks: the residual tests above, and the largest ProximalBase KKT score of the
original problem at the returned point, `max(0, |Gⱼ| - cⱼ)` at a zero coefficient and `|Gⱼ + cⱼ sign(bⱼ)|` elsewhere,
finite and at most `tol`. It is not an exact-arithmetic certificate, it does not bound the error of the coefficients,
and the gradient it uses is rounded. The scale of the score is that of the gradient of the summed loss; a mean-scale
level is passed as `n * λ` ([IN-09](@ref)). The problem need not have a minimizer ([IN-09](@ref), *Unattained
minima*); the solver does not detect that case. In exact arithmetic the score is 1-Lipschitz in the gradient and
`σ` is `1/4`-Lipschitz, so `|dual_kkt - kkt| ≤ maxⱼ ‖Xⱼ‖₂ (√n predictor_residual + r/4)` at the returned `b`, `t`
and `u`, with `r = ‖X b - t‖₂`.

**Applies to.** `LogisticADMM`.

**Code.** `src/solvers/logistic_admm.jl`: `_la_residuals!`, `_la_passes`, `_la_converged`, `_la_iterate!`,
`_solve_logistic_admm!`.

**Tests.** `test/logistic_admm.jl`: the returned points of the seeded problems (an intercept-only fit with its closed
form, an identifiable zero-penalty fit against a damped Newton reference in `BigFloat`, regularized fits with an
unpenalized intercept, a correlated design, `p > n`, a level above the slope threshold, penalty weights including
zero and very large ones, extreme logits at the start) against the independent objective and KKT score and against
`ProxNewton` at `tol = 1e-10` (objective within `1e-8 max(1, |F|)`), with the primal residual, both thresholds,
`dual_kkt` and `predictor_residual` recomputed from the returned `b`, `t` and `u` and the two-sided bound above;
agreement with `ProximalGradientDescent` and `ProxNewton` at matched KKT scores; a supplied `t` and `u`, a restart
from a result, a restart at another `ρ` with the rescaled dual, and one iteration from a `ProxNewton` solution with
the default dual; `ρ` from `1e-10` to `1e10`; a convergence whose last coefficient step missed its target; loose
residual tolerances with a tight `tol` and the converse; a supplied start whose reconstructed dual threshold would
pass a residual that the direct product fails, with the residual and threshold recomputed; the one-class sample.

**Sources.** [Issue #448](https://github.com/mlakolar/ProximalSolvers.jl/issues/448) (the residuals with their
dimensions and the uncertified case) and [pull request #507](https://github.com/mlakolar/ProximalSolvers.jl/pull/507).

## [LA-05 Mutation and failure boundary](@id LA-05)

**Statement.**

The solve computes on private buffers: the coefficients, their image, the predictor, the dual, their values in the
current iteration, the response and the gradients. At a normal return (`:converged`, `:maxiter`, `:stalled` or
`:prox_failed`) it writes the caller's `b` once, with the returned coefficients. A supplied `t` and `u` are written
then too, with the predictor and `u = w/ρ` of the last completed iteration, when an iteration completed; when none
completed they keep their entries and are the returned `t` and `u`. The result's diagnostics are formed from the
returned `b`, `t` and `u` before any of these writes. The borrowed `X`, `y`, the penalty weights and the scratch
`f.tmp` of the loss are not written.

A failed scalar root ([LA-03](@ref)), from a nonfinite `v` or the step cap, discards its iteration: the solve returns
the last completed iteration, or the start, with `:prox_failed` and `converged = false`. Its residuals, thresholds,
`inner_kkt` and `inner_met` are those of the last completed iteration; its `passes` and `root_iterations` include the
work of the discarded iteration.

An exception propagates and leaves the caller's `b`, `t` and `u` unchanged; so does a refusal. The exceptions include
an `ArgumentError` from [CD-04](@ref) in the coefficient step, such as a column curvature that underflows or overflows
or a coordinate step that is not finite, and an `ErrorException` when the objective or the KKT score of the original
problem at the coefficients of an iteration is not finite. `dual_kkt`, formed at the return from the reported `u`, is
reported when it is not finite, without an exception.

**Applies to.** `LogisticADMM`; the result and mutation rules of [RES-01](@ref) and [RES-03](@ref) refer here for it.

**Code.** `src/solvers/logistic_admm.jl`: `_la_iterate!`, `_solve_logistic_admm!`.

**Tests.** `test/logistic_admm.jl`: an iteration with a failed root (a reduced cap) leaves the completed state as it
was; a solve with a zero cap returns the start with `:prox_failed`, `NaN` residuals, the supplied `t` and `u`
unchanged and the passes counted; a solve whose roots fail in the fourth iteration returns the third, with its
coefficients, predictor, dual, objective, score, residuals, thresholds and inner score, and counts the work of the
discarded iteration; the diagnostics of a reported `u` that rounds `w/ρ` to `0`, and a `dual_kkt` of `Inf` at
`maxiter = 0`; a column curvature that underflows (with a supplied `t` and `u`) or overflows, a penalty that
overflows after an iteration (the `ErrorException`), and starts with a nonfinite predictor or gradient, with the
caller's arrays and the inputs unchanged.

**Sources.** [Issue #448](https://github.com/mlakolar/ProximalSolvers.jl/issues/448) and
[pull request #507](https://github.com/mlakolar/ProximalSolvers.jl/pull/507).
