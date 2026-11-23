# Proximal gradient iteration

## Scope

`ProximalGradientDescent` uses dense Float32 or Float64 vectors for the vector-response problems in the [support matrix](../support.md). PGD and APG share `_solve_gradient!`, stopping and results, including for the matrix lasso in [IN-10](@ref). Graphical-lasso PGD also uses `_solve_gradient!`, with the step and stopping rules in [PGD-07](@ref) and [PGD-08](@ref).

## Problem

Minimize `F(x) = s‖Xx - y‖²/2 + g(x)`. The supported penalties are `NormL1` and `ElasticNet` (each with optional weights, [IN-03](@ref)), `NormLinf`, `NormL2` ([IN-11](@ref)), `GroupNormL2`, unweighted `NormL1Nonneg` and `IndNonnegative()`. `NormL1Nonneg` and `IndNonnegative()` enforce `x ≥ 0` under [IN-07](@ref). PGD also accepts `IndBox` (including `IndBallLinf`) and four-coefficient `IndBallL2` under [IN-08](@ref), and, on the opt-in route of [IN-12](@ref), `IndBallL1` with the trials of [PGD-09](@ref).

## Notation

`s` denotes the loss scale. `L` is inverse step size, and `α` and `β` are line-search settings. The retained source uses `α_f` or `model.α` for `s`. See [working precision](working-precision.md).

## Preconditions and refusals

### [PGD-05 Construction and supported settings](@id PGD-05)

**Statement.** `ProximalGradientDescent()` uses `LineSearches.BackTracking()`. `normalized=true`, `debias>0`, `preconditioner!=:none` and custom line searches are not implemented and are rejected. The compatibility keywords at their defaults are accepted and not stored; their complete unsupported-feature policy is [DEF-01](@ref).

Solvers, options and `BackTracking` each have a validating inner constructor. Settings are checked as given and after conversion, so `solve!` does not revalidate constructed settings; APG separately checks its two factors in the iterate precision before constructing state. Construct `ProximalOptions(...)` to configure the shared stopping rules in [STOP-01](@ref). Its compatibility gap keywords do not request a PGD/APG certificate: a positive `gaptol` is refused, `gapevery` must be positive but has no effect, and neither is stored. Float64 storage of some tolerances and diagnostics does not increase native Float32 coefficient accuracy.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/solvers/proximal_gradient_descent.jl: ProximalGradientDescent; src/types.jl: ProximalOptions`.

**Tests.** test/core_contracts.jl; test/accelerated_pgd.jl: constructor and method settings.

**Sources.** `docstring:src/solvers/proximal_gradient_descent.jl:L18`, `docs/src/developer/implementation-notes.md:L418`, `docstring:src/types.jl:L174`.

## Algorithm

### [PGD-01 Image, loss, gradient and proximal iteration order](@id PGD-01)

**Statement.** PGD keeps the native least-squares image buffers and uses ProximalBase's value and gradient oracles. It forms the image before value and gradient, takes scalar steps, and calls `value_and_prox!` for each penalty step, except on the ℓ1-ball route, whose trials are [PGD-09](@ref). Unweighted lasso levels follow [IN-02](@ref).

At an iteration it saves the last accepted point, objective components and gradient; multiplies `L` by the line search's `α`; then repeats the following trial until [LS-01](@ref) accepts it:

1. Form the gradient-step point `xhat = x_previous - ∇f(x_previous)/L`.
2. Apply `value_and_prox!` with step `1/L` into the caller's iterate.
3. Form the trial's least-squares image and value.
4. Apply the line-search decision, refreshing the gradient when its mode requires it.

The accepted point's gradient is refreshed if the line search did not already update it, including a zero-step exit in gradient mode. The gradient engine then checks the accepted objective for finiteness, assesses stopping, traces/calls back, and checks limits and separate exits in that order.

The prox is soft thresholding for `NormL1`, with entry level `λ wⱼ` for weights; soft thresholding followed by the ridge weight for `ElasticNet`; the point minus its projection onto the ℓ1 ball of radius `λ/L` for `NormLinf` (a common clipping level); and block soft thresholding for `GroupNormL2`, scaling a block `v_G` by `max(0, 1 - γ λ wₖ/‖v_G‖₂)` at step `γ`, with a zero block left zero. For `NormL2(λ)`, the exact-arithmetic formula at step `γ` is zero when `‖v‖₂ ≤ γ λ` and `(1 - γ λ/‖v‖₂) v` otherwise. The solver delegates the evaluation to ProximalBase, which can round the cutoff comparison. The working-precision conventions for these oracles are [FP-01](@ref). The level of `NormL2` is the working level of [IN-02](@ref), and its stop check is [STOP-17](@ref).

For unweighted `NormL1Nonneg(λ)`, the prox is componentwise `max(v - λ/L, 0)`. For `IndNonnegative()`, ProximalBase projects componentwise with `max(v, 0)`. Both operators enforce nonnegativity at each step. The feasible-start and input requirements are [IN-07](@ref), and the dedicated constrained stationarity check is [STOP-16](@ref).

For the box and ball indicators in [IN-08](@ref), the proximal step projects onto the corresponding set using ProximalBase. The generic stationarity check is [STOP-07](@ref).

For matrix-response entrywise lasso, the same sequence carries coefficient,
gradient and displacement buffers of size `p × K` and predictor and residual
buffers of size `n × K`. The predictor is `XB`, and ProximalBase uses it to form
`sXᵀ(XB − Y)`. The scalar proximal step applies the working level to every
entry. The image, step and stopping norms use the corresponding entrywise
array reductions.

For a raw `LogisticLoss` with `NormL1`, the same sequence forms the logistic image and value; [IN-09](@ref) specifies the inputs and the oracles.

**Applies to.** ProximalGradientDescent; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/solvers/proximal_gradient_descent.jl: initial_state, update_state!; src/line_searches.jl: search!; src/utils.jl: LineSearches.trial!; src/solve.jl: _solve_gradient!`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks matrix buffer shapes, values, gradients and traces. test/minimal_core_characterization.jl: PGD LS image and recorded-trial testsets; test/core_regressions.jl: gradient/image refresh; test/norml2_pgd.jl: PGD and APG solutions against the orthogonal closed form; test/nonnegative_lasso.jl and test/nonnegative_least_squares.jl: constrained solutions and feasibility in both precisions; test/logistic_pgd.jl: the logistic value and gradient and its solves.

**Sources.** `docs/src/developer/implementation-notes.md:L286`, `docstring:src/solvers/proximal_gradient_descent.jl:L5`, `docstring:src/solvers/proximal_gradient_descent.jl:L18`, `docs/src/numerics.md:L928`. The later nonnegative-lasso addition is documented in [upstream `fd45a427`, PGD docstring](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/solvers/proximal_gradient_descent.jl#L5-L18).

### [PGD-02 Initial curvature scale](@id PGD-02)

**Statement.** Before the first iteration, the inverse step is the `T`-rounded `min(1, s ‖X‖_F²)`, using an upper bound for `‖X‖_F`. A positive result that rounds below `floatmin(T)` is raised to that value. If the product is at least one, or `X = 0`, the start is `1`.

For `B ↦ XB` in the Frobenius norm, each response column has the same
operator. Summing their squared norms gives the operator bound `‖X‖₂`,
attained by taking one column to be a right singular vector. The initial
curvature uses the same design Frobenius norm for any number of responses.

When the positive Frobenius bound is below one, it exceeds the spectral curvature `s ‖X‖₂²` by the factor `‖X‖_F² / ‖X‖₂²`, at most the rank of `X`, up to rounding and the floor. A positive bound far below one therefore starts below one; a bound at least one starts at one. For example, `X = I(256)/16` with `s = 1` has curvature `1/256` and starts at `1`. The line search multiplies this estimate by its decrease factor (default `0.9`) before each iteration and raises it on rejected trials. Historical extreme-scale measurements are retained in [ORACLE-01](@ref).

PGD obtains the same initialization through a column-wise scan, with the Frobenius-bound calculation when required; APG uses the shared bound machinery directly. For a raw `LogisticLoss`, the initial estimate of PGD uses the factor `¼` in place of `s` ([IN-09](@ref)), and that of APG the same factor ([APG-08](@ref)). This is an initial estimate only; the acceptance tests that follow are those of the line-search clauses of each solver. A finite starting loss is required; penalty overflow at a finite starting point follows [RES-01](@ref).

**Applies to.** PGD and APG; dense vectors and the matrices in [IN-10](@ref).

**Code.** `src/solvers/proximal_gradient_descent.jl: _scanned_initial_curvature; src/solvers/image_models.jl: _initial_curvature, _frobenius_upper`.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks the matrix and vector initial curvature for the same design. test/initial_curvature.jl: initial scale, floor, wide-scale and zero-design testsets; test/logistic_pgd.jl: the start `min(1, ¼‖X‖_F²)` for a logistic loss.

**Sources.** `docstring:src/solvers/proximal_gradient_descent.jl:L5`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L21`, `docs/src/numerics.md:L168`, `docs/src/numerics.md:L833`.

### [PGD-09 Trials on the ℓ1-ball route](@id PGD-09)

**Statement.** On the route of [IN-12](@ref), the iterations of PGD ([PGD-01](@ref)) and APG ([APG-01](@ref)) keep their order, and each trial from the gradient-step point `xhat` replaces the proximal step and the image and value of the trial as follows:

1. When an entry of `xhat` is not finite, the trial has `f(x) = Inf`, with no projection, no write to `x` and no `prox_calls` or `f_calls` count. It still counts as one of the 64 trials below, and the line search counts it in `backtrack_steps` (PGD's nonfinite branch, APG's count of every trial).
2. Otherwise ProximalBase's `prox!`, at step `1/L`, for a private `IndBallL1` that the solve builds with the radius of the caller's ball, writes the projection of `xhat` into the caller's `x`, counted in `prox_calls`, and the decision of `x` against the cap ([FP-05](@ref)) then replaces the route's cached decision.
3. For the code `:pass`, the image and loss value of `x` are formed, counted in `f_calls`, and the penalty value is `0`. For `:over` and `:unresolved`, the trial has `f(x) = Inf` and no loss value is formed.

A trial with `f(x) = Inf` takes the nonfinite branch of PGD's line search ([LS-02](@ref)) and, in APG, raises `L` through `next_curvature` ([APG-09](@ref)); the trials that pass the cap are decided by PGD's backtracking or APG's certified bound ([APG-06](@ref)) as for the other penalties. An accepted trial has a finite loss, so its decision passed the cap.

A search from one base point allows 64 trials: PGD's line search of an iteration, and each call of APG's step, so that the restart's repeated step counts its own trials. When 64 trials from one base point were not accepted, the route raises `ErrorException("line search failed: 64 trials from one base point were not accepted (…)")` at the start of the would-be 65th trial, after its gradient-step point has been formed in the scratch `xhat` and before any projection; `next_curvature` or PGD's curvature update can raise their own line-search error earlier. The gradient engine copies the last accepted iterate into `x` and rethrows ([RES-03](@ref)). No retry follows.

PGD checks the gradient at the accepted trial after the line search, as B1's step does: when that gradient has a nonfinite entry, the route raises `ErrorException("the gradient at the accepted trial has a nonfinite entry (…)")` inside the step, and the gradient engine copies the last accepted iterate into `x` and rethrows, before the stopping assessment, the trace and the callback of that iteration. Within its step, after the projection, APG forms no gradient at its accepted trial, so it has no such check; a later full check ([STOP-22](@ref)) can form a gradient at a witness equal to that point.

Ownership: within a completed step, only trials write `x`. A trial that projects into `x` replaces the cached decision right after the projection, and a trial with a nonfinite `xhat` writes neither, so after every completed trial the cached decision describes `x`; after a completed iteration that is the accepted iterate. A projection that throws can leave `x` written without the cache update; the rollback that follows copies `x_previous` into `x` and is followed by the rethrow, so no result is built from such a state. The full check of [STOP-22](@ref) writes the route's workspace and the two counters, not `x` or the cached decision. A callback may read the coefficients; these statements, and the report of [RES-04](@ref), assume that it leaves them and the borrowed data unchanged, since the solver does not detect a change made by a callback.

The state's initial penalty value is `0`, including for a start that passes the cap outside the ball, where the mathematical indicator is `Inf` (ProximalBase's indicator, which compares a rounded sum, can also be `0` there; the route does not evaluate it). The trace's `fg_x` (the “Function value” of the displayed trace), the callback's objective and the engine's objective comparisons therefore use the smooth loss.

**Applies to.** `ProximalGradientDescent` and `AccProxGradDescent` on the ℓ1-ball route.

**Code.** `src/solvers/l1ball.jl: LineSearches.trial!, LineSearches.search!, _prox_grad_step!, _NumericalL1Ball, _run_numerical_l1!`; `src/utils.jl: LineSearches.trial!, _trial_step!` (the trial of the other penalties); `src/line_searches.jl: search!`; `src/solvers/proximal_gradient_descent.jl: update_state!`; `src/solvers/accelerated_proximal_gradient_descent.jl: _prox_grad_step!`.

**Tests.** `test/l1ball_numerical.jl`: a callback recomputes the decision of `x` at every iteration of the small #508 fixtures, every accepted iterate passes the cap, and the last recomputed decision equals the report; a callback stop returns the iterate of its iteration bitwise; with a zero cap, a start inside the ball by just more than the rounding allowance and a far response, no trial from the start is accepted, and both methods raise the error of the 64-trial limit and restore the start bitwise, in both precisions (the test does not record the decision of each rejected trial); a `Float32` PGD trial accepted at `Lexact` whose gradient overflows raises the gradient error, restores the start bitwise, and no callback runs.

**Sources.** [The approved plan](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7073644919) and [the maintainer's decision I4](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7074272157); `trial_value!`, `step!` and `accelerated_trial!` of [B1 at d58b9099](https://github.com/mlakolar/ProximalSolvers.jl/blob/d58b9099c5837230212496766a721972b98d83f3/research/issue-515/b1.jl).

## Stopping

The complete shared policy is [STOP-01](@ref), including the three OR-combined proposals, the independent check of the accepted point and the separate objective-increase and stagnation exits.

## Postconditions

### [PGD-04 Trace, callback and limit sequencing](@id PGD-04)

**Statement.** `store_trace` stores an entry for every completed iteration; display and callback invocation are sampled by `print_every`. When storing, a callback receives the trace; otherwise it receives the current trace state. A callback returning `true` stops the solve. `extended_trace` requests the additional diagnostic data. These options use the existing engine and do not introduce a separate logging framework.

Call and time limits are checked after a complete iteration, including any proposed-stop check and callback. A zero call limit is unlimited; counts can overshoot a positive limit by the work of one iteration. `maxiter` caps completed iterations, and `iteration_converged` means `iterations == maxiter`, not successful convergence. The Float32 stagnation check follows tracing and any callback due at that iteration; it does not change cadence.

On the ℓ1-ball route ([IN-12](@ref)) the traced and called-back objective is the smooth loss, since the route's penalty value is `0` ([PGD-09](@ref)), and the full checks of [STOP-22](@ref) count in `grad_calls` and `prox_calls` before the limits are checked.

The displayed `|g(x)|` is an internal gradient/proximal stopping residual, not the user's penalty value. Displayed `|x - x'|` and trace `dxx` are iterate-change diagnostics, and `backtrack_steps` counts line-search trials subject to each method's zero-step and stationarity-check rules. They do not describe changes in the statistical model.

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/utils.jl: trace!; src/solve.jl: _solve_gradient!`.

**Tests.** test/minimal_core_characterization.jl: PGD limits, stopping flags, trace and callback ownership; test/accelerated_pgd.jl: trace, callbacks, limits, result identity and counters; test/core_regressions.jl: stagnation callbacks and limits.

**Sources.** `docs/src/developer/implementation-notes.md:L418`, `docstring:src/types.jl:L168`, `docstring:src/types.jl:L174`, `docs/src/working-with-results.md:L65`, `docs/src/working-with-results.md:L75`, `docs/src/numerics.md:L67`, `docs/src/numerics.md:L393`.

The returned minimizer aliases caller storage, and numerical-step rollback restores only the last accepted iterate, not every counter or internal buffer; the complete mutation contract is [RES-01](@ref).

## Floating-point rules

### [PGD-03 Native products and diagnostics](@id PGD-03)

**Statement.** The coefficient, residual and image buffers keep `T` arithmetic. ProximalBase evaluates the loss value and can recover a value whose intermediate squares leave the range of `T`; PGD does not recover an overflowing or underflowing image `X x` or gradient `s fl(Xᵀd)`. Finite inputs therefore do not imply finite intermediates. The explicit range-safe and residual qualifications are in [FP-01](@ref), [LS-04](@ref) and [STOP-04](@ref).

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/solvers/image_models.jl: _image!, _value!, _value_and_gradient!`.

**Tests.** test/core_regressions.jl: oracle values/gradients and native diagnostics.

**Sources.** `docs/src/developer/implementation-notes.md:L286`, `docstring:src/types.jl:L174`.

## Known limits

Native Float32 can stagnate before a requested accuracy is attained. The relevant exits and accuracy limitations are [STOP-11](@ref) and [STOP-12](@ref); line-search limitations are recorded in [LS-07](@ref) and [LS-08](@ref).

## Tests

Existing tests listed at each clause cover image order, fused prox, counts, constructors, callbacks and rollback. No numerical implementation or new test tier is introduced here.

## Retired historical wording

### [Retired: older penalty inventory](@id PGD-UNRECONCILED)

**Retired by [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).** The quotation below is preserved verbatim as **historical provenance**, not a current support restriction. The authoritative supported combinations are in [IN-01](@ref), consistent with current `src/solve.jl` dispatch and the `test/linf.jl` and `test/group_pgd.jl` suites: `NormLinf` and `GroupNormL2` are supported by both PGD and APG. The older inventory omitted these already-supported cases; no solver feature is added by retiring it.

> The penalty is validated once by `_check_penalty` in `_check_data`. For an `x` that is not a `BlockIterate`
> it accepts a `NormL1` for all solvers (with weights, `_check_l1_weights`: a `Vector{T}` of the length of `x`, finite and nonnegative entries,
> no alias with `x`, a level `T(λ0)` that is zero or normal, and the coefficients `T(λ0) wⱼ` finite and, for positive factors, normal) or an unweighted `ElasticNet` for all solvers and refuses any other
> penalty; a `BlockIterate` has its own method, for a `GroupNormL2`.

**Sources.** `docs/src/developer/implementation-notes.md:L286`.

## Change log

[#457](https://github.com/mlakolar/ProximalSolvers.jl/issues/457), Phase B: the opt-in ℓ1-ball route adds [PGD-09](@ref); the trial of the other penalties is unchanged.

The shared image engine and scalar APIs are retained. The historical support wording above was retired under [#416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416) and remains only as provenance; no numerical restoration is inferred.
