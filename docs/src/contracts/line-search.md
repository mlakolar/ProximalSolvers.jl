# Backtracking line search

## Scope

`LineSearches.BackTracking` is the supported PGD line search for the least-squares image model. APG has its own [certified bound test](apg.md); it does not use the TFOCS acceptance rule on this page.

## Problem

A PGD trial applies the penalty prox after a least-squares gradient step of length `1/L`. The line search chooses the accepted inverse step.

## Notation

`s` is the loss scale; `α` and `β` are line-search settings. `d = x - x_previous` is the trial displacement. `d̂` is the displacement used by the rejection check, possibly scaled under [LS-06](@ref). `L̂` is TFOCS's local estimate and `c` is the separate computed directional curvature. `n` and `p` are design rows and columns.

## Preconditions and refusals

### [LS-01 Settings and shared ownership](@id LS-01)

**Statement.** `BackTracking(; α = 0.9, β = 0.5, Lexact = Inf)` holds settings only and can be shared between solves; bookkeeping is in the solver state. Its validating constructors require `0 < α ≤ 1`, `0 < β < 1` and `Lexact > 0`, both before and after conversion. The numerical retry and failure rules below apply after construction.

**Applies to.** LineSearches.BackTracking with ProximalGradientDescent.

**Code.** `src/line_searches.jl: BackTracking`.

**Tests.** test/core_contracts.jl; test/minimal_core_characterization.jl.

**Sources.** `docstring:src/line_searches.jl:L16`, `docstring:src/line_searches.jl:L18`, `docstring:src/line_searches.jl:L91`, `docs/src/developer/implementation-notes.md:L418`.

## Algorithm

### [LS-02 TFOCS trial and retry policy](@id LS-02)

**Statement.** Each iteration starts with `L ← α L`. TFOCS's local estimate `L̂` uses function values until they are too close for the floating-point comparison, then gradients. A finite trial is accepted when that estimate is no larger than `L`, or when `L ≥ Lexact`. Ordinary rejected trials retry with `L ← min(Lexact, max(L̂, L/β))`, except when the separate rejection check in [LS-03](@ref) accepts or replaces `L̂`.

A nonfinite trial image or loss value supplies no estimate and is never accepted. The search retries with `L ← L/β`, beyond `Lexact` if necessary. The zero-step exit accepts a finite-value trial whose computed displacement norm squared is zero, including a nonzero step lost by squaring; in gradient mode it refreshes the gradient so that a previous rejected trial cannot leave a stale one.

Accepted trials are not checked again. In particular, a rounding-decided estimate that accepts below the true curvature remains accepted, as do the finite-value `Lexact` and zero-step exits.

**Applies to.** ProximalGradientDescent with BackTracking.

**Code.** `src/line_searches.jl: backtrack!, has_updated_gradient; src/solvers/proximal_gradient_descent.jl: update_state!`.

**Tests.** test/minimal_core_characterization.jl: recorded trials, both modes and zero-step refresh; test/core_regressions.jl: checked rejection testsets.

**Sources.** `docstring:src/line_searches.jl:L18`, `docstring:src/line_searches.jl:L26`, `docs/src/numerics.md:L928`, `docs/src/developer/implementation-notes.md:L286`.

### [LS-03 Rechecking a rejected least-squares trial](@id LS-03)

**Statement.** When eligible, a rejected trial is decided again from one product `X d̂`, using `c = m s ‖fl(X d̂)‖² / ‖d̂‖²`. Here `m = 1` for a function-value estimate and `m = 2` for a gradient estimate, matching TFOCS's gradient test `2s ‖X d‖² ≤ L ‖d‖²`.

If `L ≥ c` in the comparison precision, accept and keep the current estimate mode. Otherwise, replace `L̂` only when the returned curvature in the working type is finite; if not, retain TFOCS's estimate. For Float32, the Float64 comparison value and the returned Float32 retry value are distinct, as specified in [LS-04](@ref).

Do not run this check for a nonfinite trial value, the zero-step exit, a `NaN` local estimate, or a gradient-mode estimate formed from a gradient with a nonfinite entry. Every checked rejection costs one matrix-vector product. This check reduces inflated local estimates caused by subtracting nearby values or gradients; it provides no rounding certificate. A decision near directional curvature can go either way, and a direction nearly in the null space of `X` can have a large relative curvature error.

**Applies to.** ProximalGradientDescent with BackTracking.

**Code.** `src/solvers/proximal_gradient_descent.jl: LineSearches.check_rejection!, _step_curvature; src/line_searches.jl: backtrack!`.

**Tests.** test/core_regressions.jl: PGD checked rejections and nonfinite-gradient/tiny-step cases.

**Sources.** `docstring:src/line_searches.jl:L26`, `docs/src/numerics.md:L928`, `docstring:src/solvers/proximal_gradient_descent.jl:L18`.

## Stopping

A line-search acceptance is an iteration decision. Convergence, exact stalls and stagnation are separately specified by [STOP-01](@ref), [STOP-10](@ref) and [STOP-11](@ref). An inflated `L` can make a step round to zero without establishing stationarity; the stationarity check can refuse its proposal, followed later by a limit or an objective-increase exit.

## Postconditions

### [LS-09 Failure and restoration boundary](@id LS-09)

**Statement.** A search that keeps rejecting ends in an error when `next_curvature` cannot make `L/β` a finite strict increase, or when TFOCS's update yields a nonfinite `L`. The gradient engine restores the last accepted iterate and rethrows. Counters and other internal state are not transactional. A curvature along trial steps above `floatmax(T)` can cause this failure, unless TFOCS's estimate, `Lexact` or the zero-step exit accepts a trial first. Full ownership and exception semantics are [RES-01](@ref).

**Applies to.** ProximalGradientDescent with BackTracking.

**Code.** `src/line_searches.jl: next_curvature, backtrack!; src/solve.jl: _solve_gradient!`.

**Tests.** test/core_regressions.jl: checked rejection before unrepresentable curvature; test/minimal_core_characterization.jl: numerical failure restores accepted point.

**Sources.** `docs/src/numerics.md:L928`, `docs/src/developer/implementation-notes.md:L286`, `docstring:src/solvers/accelerated_proximal_gradient_descent.jl:L44`.

## Floating-point rules

### [LS-04 Float32 curvature check and flushing allowances](@id LS-04)

**Statement.** Accumulate the two squared norms in Float64, where the square of a finite Float32 is exact. Before squaring `w = ‖fl(X d̂)‖`, add `2√n p floatmin(Float32)` for underflow of product results and `√n floatmin(Float32) ‖d̂‖₁` for subnormal matrix entries that a flushing calling or BLAS thread can drop. These allowances assume flushing affects only subnormal operands and results. They bound those effects, not the full rounding error of the matrix-vector product, and give no certificate.

Compare the resulting curvature `c64` with `L` in Float64. It is positive when finite, so a product lost to underflow or flushing does not make it zero. The returned retry value is `cT = Float32(c64)`, used only after a rejection. It replaces `L̂` only when `cT` is finite; if a finite `c64` overflows in that conversion, TFOCS's estimate is retained. Under round-to-nearest, if the allowances sum to less than `eps(w)/2`, they leave the computed norm unchanged.

Keep TFOCS's estimate when a product entry overflows, when the calling thread flushes subnormals (`set_zero_subnormals(true)`), or when `d̂` has a nonzero subnormal entry that a flushing thread could lose. These cases do not accept through the curvature check. For a scaled displacement, `d̂` is the scaled vector; the undetected zero-rounding limitation is [LS-07](@ref).

**Applies to.** ProximalGradientDescent; Float32 data.

**Code.** `src/solvers/proximal_gradient_descent.jl: _step_curvature(::ProximalGradientDescentState{Float32}), _step_norms64`.

**Tests.** test/core_regressions.jl: Float32 computed curvature under over/underflow, BLAS flushing and overflowing-step testsets.

**Sources.** `docstring:src/line_searches.jl:L26`, `docs/src/numerics.md:L928`, `docs/src/numerics.md:L1036`.

### [LS-05 Float64 curvature range limitations](@id LS-05)

**Statement.** For Float64 data, the sums of squares remain in Float64. Over- or underflow in `‖fl(X d̂)‖²` or `‖d̂‖²` can make `c` infinite or `NaN`, retaining TFOCS's update, or spuriously zero, accepting a trial even when true curvature is large. This includes an underflowed numerator and an overflowed denominator.

Scaling in [LS-06](@ref) keeps the squared norm of the scaled displacement between one and about `16 * length(d̂)`; it does not prevent the product norm from overflowing or underflowing. Without scaling, the denominator may overflow for nonfinite step entries or in the narrow band where `norm(d)^2` is finite but the check's sum of squares is not. The historical probes of that band are retained in [the evidence](evidence/strict-accuracy-config.md#PGD-rejection-check-measurements).

**Applies to.** ProximalGradientDescent; Float64 data.

**Code.** `src/solvers/proximal_gradient_descent.jl: _step_curvature; src/line_searches.jl: backtrack!`.

**Tests.** test/core_regressions.jl: checked rejections and top-of-range steps.

**Sources.** `docstring:src/line_searches.jl:L26`, `docs/src/numerics.md:L928`, `docs/src/numerics.md:L1031`, `docs/src/numerics.md:L1032`.

### [LS-06 Scaling a displacement whose squared norm overflows](@id LS-06)

**Statement.** If the trial displacement has finite entries, its computed `norm(d)^2` is `Inf` in `T`, and `f(x)` is finite, decide the trial using `d̃ = σ d`, where

```
σ = 2^(-e)
e = min(exponent(max |dᵢ|), exponent(floatmax(T)) - 1).
```

The scale `σ` is normal, and the largest magnitude in `d̃` lies in `[1, 2)`, or `[2, 4)` when the original maximum has the largest exponent (1023 in Float64 and 127 in Float32). The overflow trigger is roughly a step magnitude of `1.3e154` in Float64 or `1.8e19` in Float32, and includes a norm itself above `floatmax(T)`.

Form `L̂` using `d̃`, function values multiplied by `σ²` through exponent shifts (without forming a possibly underflowing square), and the displacement-gradient products multiplied by `σ`. In exact arithmetic this is the unscaled estimate. The rejection check reads `d̃`; after acceptance the solver restores `delta_x = x - x_previous` for subsequent diagnostics.

Do not scale a nonfinite trial loss, a displacement with a nonfinite entry, or a squared displacement norm that is subnormal or underflows to zero. These retain their existing decisions.

**Applies to.** ProximalGradientDescent; Float32 or Float64.

**Code.** `src/line_searches.jl: _scale_overflowing_step!, backtrack!`.

**Tests.** test/core_regressions.jl: power-of-two scale invariance, restored delta_x and top-of-range steps; test/initial_curvature.jl: overflowing-step cases.

**Sources.** `docstring:src/line_searches.jl:L56`, `docs/src/numerics.md:L1004`, `docs/src/numerics.md:L1021`, `docs/src/numerics.md:L1022`.

## Known limits

### [LS-07 Limits of the overflow scaling](@id LS-07)

**Statement.** The scaled decision still contains rounding in `f` and `∇f`, underflow of a displacement entry, a scaled function value or `L̂`, and overflow in `⟨d̃, ∇f(x_previous)⟩` or `⟨∇f(x)-∇f(x_previous), d̃⟩` *before* multiplication by `σ`. It does not recover an infinite product or cancellation of opposite infinite terms. The unchanged formulas can produce finite, infinite or `NaN` estimates; for example, finite function values and a `+Inf` function-value product give `L̂ = L`, accepting without the rejection check. Overflow of `‖fl(X d̂)‖²` with a representable denominator remains subject to [LS-05](@ref).

In Float32, a nonzero subnormal entry in `d̃` makes the check retain TFOCS's update. An entry satisfying `|σ dᵢ| ≤ 2^-150` instead rounds to zero and is not detected: it disappears from the product and both norm sums. For example, `d = [2^70, 2^-80]` scales to `[1, 0]`; with `X = [0 1]`, `X d̃ = 0` while the exact `σ X d = 2^-150`. Thus a stored scaled product need not equal the exact scaled original product. The Float32 allowances are absolute, weigh more against a smaller product norm, and change `c` when it is of their order.

**Applies to.** ProximalGradientDescent; the final paragraph concerns Float32.

**Code.** `src/line_searches.jl: _scale_overflowing_step!, backtrack!; src/solvers/proximal_gradient_descent.jl: _step_curvature`.

**Tests.** test/core_regressions.jl: overflowing-step and subnormal tests.

**Sources.** `docstring:src/line_searches.jl:L56`, `docs/src/numerics.md:L1004`, `docs/src/numerics.md:L1021`, `docs/src/numerics.md:L1022`, `docs/src/numerics.md:L1024`, `docs/src/numerics.md:L1031`, `docs/src/numerics.md:L1032`, `docs/src/numerics.md:L1036`.

### [LS-08 Zero products and subnormal squared displacements](@id LS-08)

**Statement.** In gradient mode a zero gradient-difference product leaves `L̂ = 0` and accepts the trial. This covers Float64 `‖d̂‖² < 2/floatmax(Float64)` (about `1.1e-308`), where multiplying zero by the overflowing factor `2/‖d̂‖²` would instead create `NaN`.

This special case does not make subnormal estimates reliable or guarantee convergence: a solve can still return `converged=false` or fail its line search. A subnormal squared norm with a nonzero gradient product, or function-value rounding noise `f(x) > q` in the quadratic model, can give `L̂ = Inf`. If `sum(abs2, d̂)` underflows to zero while `norm(d̂)^2 > 0`, as can happen with every entry below about `1.57e-162`, the separate curvature is nonfinite and cannot replace that estimate.

**Applies to.** ProximalGradientDescent; Float64.

**Code.** `src/line_searches.jl: backtrack!; src/solvers/proximal_gradient_descent.jl: _step_curvature`.

**Tests.** test/core_regressions.jl: 1×1 and diagonal tiny-scale cases; test/stopping_scale.jl: strict small-scale PGD.

**Sources.** `docstring:src/line_searches.jl:L56`, `docstring:src/line_searches.jl:L79`, `docs/src/numerics.md:L897`.

## Tests

Existing characterization, regression and initial-curvature suites exercise both modes, rejection checks, counts, gradient refresh, range cases and rollback. Historical acceptance measurements are retained in [line-search evidence](evidence/strict-accuracy-config.md#PGD-rejection-check-measurements); they are not certificates.

## Unreconciled

None beyond the support and stopping-wording conflicts recorded in [PGD](pg-iteration.md#PGD-UNRECONCILED) and [stopping](pg-stopping.md#STOP-UNRECONCILED).

## Change log

The overflow-scaling migration retains the deferred underflow limitation recorded in [issue #317](https://github.com/mlakolar/ProximalSolvers.jl/issues/317). APG failure and certified-bound details are authoritative in [APG-03](@ref) and [APG-06](@ref).
