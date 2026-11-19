# Proximal gradient iteration

## Scope

`ProximalGradientDescent` uses dense `Vector{Float32}` or `Vector{Float64}` coefficients for the supported least-squares problems and penalties in the [support matrix](../support.md). PGD and APG share `_solve_gradient!`, stopping, reporting and result types; their iteration algorithms differ.

## Problem

Minimize `F(x) = s‖Xx - y‖²/2 + g(x)`. The supported penalties are `NormL1` (with optional weights), `ElasticNet`, `NormLinf`, `GroupNormL2`, unweighted `NormL1Nonneg` and `IndNonnegative()`. `NormL1Nonneg` and `IndNonnegative()` enforce `x ≥ 0` under [IN-07](@ref). PGD also accepts `IndBox` (including `IndBallLinf`) and four-coefficient `IndBallL2` under [IN-08](@ref).

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

**Statement.** PGD keeps the native least-squares image buffers and uses ProximalBase's value and gradient oracles. It forms the image before value and gradient, takes scalar steps, and uses fused `value_and_prox!` for each penalty step. Unweighted lasso levels follow [IN-02](@ref).

At an iteration it saves the last accepted point, objective components and gradient; multiplies `L` by the line search's `α`; then repeats the following trial until [LS-01](@ref) accepts it:

1. Form the gradient-step point `xhat = x_previous - ∇f(x_previous)/L`.
2. Apply `value_and_prox!` with step `1/L` into the caller's iterate.
3. Form the trial's least-squares image and value.
4. Apply the line-search decision, refreshing the gradient when its mode requires it.

The accepted point's gradient is refreshed if the line search did not already update it, including a zero-step exit in gradient mode. The gradient engine then checks the accepted objective for finiteness, assesses stopping, traces/calls back, and checks limits and separate exits in that order.

The prox is soft thresholding for `NormL1`, with entry level `λ wⱼ` for weights; soft thresholding followed by the ridge weight for `ElasticNet`; the point minus its projection onto the ℓ1 ball of radius `λ/L` for `NormLinf` (a common clipping level); and block soft thresholding for `GroupNormL2`, scaling a block `v_G` by `max(0, 1 - γ λ wₖ/‖v_G‖₂)` at step `γ`, with a zero block left zero. The working-precision conventions for these oracles are [FP-01](@ref).

For unweighted `NormL1Nonneg(λ)`, the prox is componentwise `max(v - λ/L, 0)`. For `IndNonnegative()`, ProximalBase projects componentwise with `max(v, 0)`. Both operators enforce nonnegativity at each step. The feasible-start and input requirements are [IN-07](@ref), and the dedicated constrained stationarity check is [STOP-16](@ref).

For the box and ball indicators in [IN-08](@ref), the proximal step projects onto the corresponding set using ProximalBase. The generic stationarity check is [STOP-07](@ref).

For a raw `LogisticLoss` with `NormL1`, the same sequence forms the logistic image and value; [IN-09](@ref) specifies the inputs and the oracles.

**Applies to.** ProximalGradientDescent; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/solvers/proximal_gradient_descent.jl: initial_state, update_state!; src/solve.jl: _solve_gradient!`.

**Tests.** test/minimal_core_characterization.jl: PGD LS image and recorded-trial testsets; test/core_regressions.jl: gradient/image refresh; test/nonnegative_lasso.jl and test/nonnegative_least_squares.jl: constrained solutions and feasibility in both precisions; test/logistic_pgd.jl: the logistic value and gradient and its solves.

**Sources.** `docs/src/developer/implementation-notes.md:L286`, `docstring:src/solvers/proximal_gradient_descent.jl:L5`, `docstring:src/solvers/proximal_gradient_descent.jl:L18`, `docs/src/numerics.md:L928`. The later nonnegative-lasso addition is documented in [upstream `fd45a427`, PGD docstring](https://github.com/mlakolar/ProximalSolvers.jl/blob/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8/src/solvers/proximal_gradient_descent.jl#L5-L18).

### [PGD-02 Initial curvature scale](@id PGD-02)

**Statement.** Before the first iteration, the inverse step is the `T`-rounded `min(1, s ‖X‖_F²)`, using an upper bound for `‖X‖_F`. A positive result that rounds below `floatmin(T)` is raised to that value. If the product is at least one, or `X = 0`, the start is `1`.

When the positive Frobenius bound is below one, it exceeds the spectral curvature `s ‖X‖₂²` by the factor `‖X‖_F² / ‖X‖₂²`, at most the rank of `X`, up to rounding and the floor. A positive bound far below one therefore starts below one; a bound at least one starts at one. For example, `X = I(256)/16` with `s = 1` has curvature `1/256` and starts at `1`. The line search multiplies this estimate by its decrease factor (default `0.9`) before each iteration and raises it on rejected trials. Historical extreme-scale measurements are retained in [ORACLE-01](@ref).

PGD obtains the same initialization through a column-wise scan, with the Frobenius-bound calculation when required; APG uses the shared bound machinery directly. For a raw `LogisticLoss`, PGD uses the factor `¼` in place of `s` ([IN-09](@ref)). This is an initial estimate, not a change to the subsequent acceptance tests. A finite starting loss is required; penalty overflow at a finite starting point follows [RES-01](@ref).

**Applies to.** PGD and APG; dense Vector{T}; T = Float32 or Float64.

**Code.** `src/solvers/proximal_gradient_descent.jl: _scanned_initial_curvature; src/solvers/image_models.jl: _initial_curvature, _frobenius_upper`.

**Tests.** test/initial_curvature.jl: initial scale, floor, wide-scale and zero-design testsets; test/logistic_pgd.jl: the start `min(1, ¼‖X‖_F²)` for a logistic loss.

**Sources.** `docstring:src/solvers/proximal_gradient_descent.jl:L5`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L21`, `docs/src/numerics.md:L168`, `docs/src/numerics.md:L833`.

## Stopping

The complete shared policy is [STOP-01](@ref), including the three OR-combined proposals, the independent check of the accepted point and the separate objective-increase and stagnation exits.

## Postconditions

### [PGD-04 Trace, callback and limit sequencing](@id PGD-04)

**Statement.** `store_trace` stores an entry for every completed iteration; display and callback invocation are sampled by `print_every`. When storing, a callback receives the trace; otherwise it receives the current trace state. A callback returning `true` stops the solve. `extended_trace` requests the additional diagnostic data. These options use the existing engine and do not introduce a separate logging framework.

Call and time limits are checked after a complete iteration, including any proposed-stop check and callback. A zero call limit is unlimited; counts can overshoot a positive limit by the work of one iteration. `maxiter` caps completed iterations, and `iteration_converged` means `iterations == maxiter`, not successful convergence. The Float32 stagnation check follows tracing and any callback due at that iteration; it does not change cadence.

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

The shared image engine and scalar APIs are retained. The historical support wording above was retired under [#416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416) and remains only as provenance; no numerical restoration is inferred.
