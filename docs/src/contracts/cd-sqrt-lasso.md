# Square-root lasso coordinate descent

This loss has its own coordinate step and duality certificate. Its ordinary scheduling
comes from [scalar CD](@ref CD-02), while input and ownership rules also apply through
[IN-01](@ref), [CDS-01](@ref) and [RES-01](@ref).

## [CDQ-01 Objective, normalization and supported calls](@id CDQ-01)

**Statement.**

`CDSolver` with `SqrtLeastSquaresLoss(y, X)` and an unweighted `NormL1(lambda)` solves
`P(beta) = norm(y - X*beta) + lambda * norm(beta, 1)`, with no `1/sqrt(n)` factor.
`X::Matrix{T}`, `y::Vector{T}` and the dense `Vector{T}` or one-dimensional
`SparseIterate{T}` coefficient use one `T`, either `Float32` or `Float64`.
`lambda` must be positive, finite and representable in `T`; another `Real` scalar type
is accepted when representable.
Use `f = SqrtLeastSquaresLoss(y, X)` and `g = NormL1(lambda)` in
`solve!(x, f, g, CDSolver(...))` with the supported scalar coefficient storage.

The normalized objective `norm(y - X*beta)/sqrt(n) + lambda_n * norm(beta, 1)` has the
same minimizers at `lambda = sqrt(n) * lambda_n`, and its values are `P/sqrt(n)`.
ProximalBase can express the normalized loss as `Scaled(f, inv(sqrt(n)))`; the solver
accepts the equivalent unscaled problem with the transformed level, as specified below.
The scaled-lasso coefficient estimate at level `lambda_0` uses the same transformation.
[CDQ-06](@ref) specifies its noise estimate `norm(y - X*beta)/sqrt(n)` when the
residual is nonzero, what a square-root certificate proves for the joint objective,
and why an exact-fit certificate does not supply a positive noise-scale minimizer.
There is no separate scaled-lasso solver; the
[scaled-lasso tutorial](../examples/problems/scaled_lasso.md) shows the computation.

Before copying the iterate or using the RNG, `ArgumentError` refuses a weighted
`NormL1` even with all weights one, an `ElasticNet`, a `SqrNormL2`, a `BlockIterate`, or
`Scaled(SqrtLeastSquaresLoss, alpha)`. For positive finite `alpha`, use the unscaled
loss with level `lambda/alpha` instead. `lambda = 0` is refused; `LeastSquaresLoss`
has the same unpenalized minimizers. `ProximalGradientDescent` and
`AccProxGradDescent` are refused because ProximalBase
provides no gradient for this loss and, for `X != 0`, it is nondifferentiable at
`y = X*beta`.

The order, momentum and pass limits are those of scalar CD, with loss scale `s = 1`.
For `relative = true` and `y != 0`, the threshold is `tol * norm(y)` and a coordinate
change is scaled by `norm(X[:, k])`; otherwise the threshold is absolute `tol` and
changes are unscaled. A change-based stop must also pass [the certificate](@ref CDQ-03)
to report convergence; otherwise [the bounded fallback](@ref CDQ-05) can run.

**Applies to.** Unscaled square-root loss, positive unweighted L1 penalty, scalar CD iterates.

**Code.** `src/solve.jl`: square-root preflight; `src/cd/sqrtlasso.jl`: `SqrtLSModel`.

**Tests.** `test/sqrt_lasso.jl`: input refusals, scalar levels of other types, and analytic cases; `test/scaled_lasso.jl`. The ridge addition explicitly retains the `SqrNormL2` refusal for square-root loss.

**Sources.** `docs/src/numerics.md:L661`, `docs/src/numerics.md:L663`, `docs/src/support.md:L285`, `docs/src/support.md:L287`, `docs/src/support.md:L291`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L138`, `README.md:L65`, `README.md:L96`, `docs/src/support.md:L130`.

The later ridge scope is tested by [the explicit square-root refusal at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/test/sqrt_lasso.jl#L966-L974).

## [CDQ-02 Coordinate minimization and range rules](@id CDQ-02)

**Statement.**

For the unsmoothed step (`delta = 0`), with `a = ‖X_k‖²`, `b = X_kᵀr`, the centre `c = old + b/a` and `d` the distance of `r` from the span of
`X_k`, the objective along coordinate `k` is `√(a (z − c)² + d²) + λ|z|`. Its minimizer is 0 for `λ ≥ √a`
and `shrink(c, λ d/√(a (a − λ²)))` otherwise; the step uses the level `T(lambda)`. It forms `a`, `b` and
`‖r‖²` in one pass over the column and the residual, and `d² = ‖r‖² − b²/a`; where that is below
`‖r‖²/16` it forms `d` again as the norm of `r − (b/a) X_k`, because the subtraction loses accuracy there.
Where `a` is below `n floatmin(T)/eps(T)`, or `‖r‖²` or that recomputed `d²` is below it or not finite (a
column whose squares can underflow, a residual whose squares underflow or overflow, and `r = 0`), the step
is formed in `Float64` from the column and the residual scaled by powers of two. In that scaling a small
entry can underflow or lose bits, which changes `√a`, `b/√a` and `d` by absolute amounts of at most
`3n 2^-1074` times `‖X_k‖` or `‖r‖` (to first order); the error bound of the step, derived in the source, covers this (a
tiny `d` can become 0). Where `d/√(a (a − λ²))` or its product with `λ` is outside the normal range of
`T`, the threshold is formed in `Float64` without that product. At every visit, before any of these
branches, a residual with an entry that is not finite is refused with an `ArgumentError`, and so are a
column whose squared norm is 0 but which is not zero and a column whose squared norm is not finite; the
coordinate and the residual are then unchanged.

During [the fallback](@ref CDQ-05), a positive smoothing level `delta` replaces the
coordinate objective by `√(a (z − c)² + d² + delta²) + λ|z|`. This is the same
one-coordinate problem with an appended response entry `delta` and a zero design
entry. The quantities `a` and `b` stay the same, while `‖r‖²` and the recomputed
`d²` gain `delta²`. The effective `delta` is a value of `T`, stored in `Float64`;
its square is rounded in `T`. The appended-row interpretation extends the step's
rounding bound to `n + 1` rows and residual `(r, delta)`.

Both sums include the rounded `delta²` before the clean-sum range tests. If its
square overflows in `T`, the step takes the power-of-two-scaled `Float64` route.
If the exact square is below `floatmin(T)`, it is at most `eps(T)/n` relative to
a sum that passes the clean-sum test; the fast path may lose the smoothing by
that amount. Rounding that square contributes at most
`nextfloat(zero(T))/2`, the usual allowance for an underflowing square.
The clean-sum threshold still counts `n` terms rather than `n + 1`; the total
underflow allowance changes from `eps(T)^2/2` to at most
`(n + 1)/n * eps(T)^2/2 <= eps(T)^2`, a second-order term covered by the
step bound's existing `3.6u` margin.

In the scaled route, the residual scale uses `max(maximum(abs, r), delta)`, the
scaled `delta` contributes its square to the residual norm, and the recomputed
distance is the `hypot` of the difference norm and that scaled `delta`. Thus
`r = 0` with positive `delta` gives `b = 0` and `d = delta` instead of the
unsmoothed return of `old`. The extra `Float64` `hypot` rounding is covered by
the distance allowance: its derivation uses `(3γ_n + 4u)‖r‖`, below the bound's
`(16γ_n + 13u)‖r‖`. The certificate and objective-decrease test always use the
original unsmoothed objective, so their validity does not depend on how accurately
a smoothed step minimizes its coordinate objective. At `delta = 0`, every step
branch is bit for bit the pre-fallback implementation.

**Applies to.** Each square-root CD coordinate visit, with the supplied level converted to `T`; smoothing is private to the fallback stages.

**Code.** `src/cd/sqrtlasso.jl`: coordinate step, `_sqrt_threshold64` and its rounding-bound derivation.

**Tests.** `test/sqrt_lasso.jl`: one-column step cases, random steps against the derived bound, nonfinite-residual preflight; 300 smoothed steps per precision against the BigFloat appended-row problem, large/tiny smoothing, overflowed squares, subnormal residuals, zero residuals and tiny columns; 1,200 unsmoothed comparisons per precision against frozen pre-fallback code, with all six branch counters exercised and zero bitwise mismatches.

**Sources.** `docs/src/numerics.md:L668`, `docs/src/numerics.md:L670`, `docstring:src/cd/solver.jl:L138`. Smoothing and preservation of the unsmoothed step were added after that baseline in [f573224f, source and rounding derivation](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L150-L312) and [the corresponding step tests](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/test/sqrt_lasso.jl#L393-L582).

## [CDQ-03 Outward-bounded duality certificate](@id CDQ-03)

**Statement.**

For `P* > 0`, `converged = true` is reported only when a certificate proves
`(P(beta) - P*)/P* <= 1e-4`; `gap` then holds the proved upper bound, rounded up
to `T`. At the exact-data special case `y = 0` and `beta = 0`, the result instead
certifies `P = P* = 0` with `gap = 0`. The residual-direction check below can
certify a point directly. [CDQ-05](@ref) can also certify the returned point with
a valid dual bound obtained at another point during the fallback.

Acceptance compares the internal Float64 ratio with `prevfloat(1e-4)`; the
reported `gap` is then rounded upward to `T`. For Float32, that final conversion
can put the stored value just above the decimal target even though the accepted
internal bound proves the stated `1e-4` objective target. The target should not
be inferred by comparing an outward-rounded Float32 `gap` with a Float64 literal.

At an unsmoothed full pass whose largest change is below the threshold, the residual `r̂ = y − Xβ` is recomputed in
`Float64` over the nonzero coefficients, with the row magnitudes `|y_i| + Σ_k |X_ik β_k|`. The dual
point is `θ = t r̂/‖r̂‖` with `t ≤ min(1, λ/max_k |X_kᵀr̂|/‖r̂‖)`, where the maximum is replaced by an upper
bound and `t` is rounded down, so that `‖θ‖ ≤ 1` and `‖Xᵀθ‖∞ ≤ λ` hold exactly; weak duality then gives
`P* ≥ θᵀy`. The gap `P − θᵀy` is bounded by a sum of terms that are nonnegative in exact arithmetic,
`(1 − t)‖r̂‖ + Σ_k (λ|β_k| − t β_k X_kᵀr̂/‖r̂‖)` plus `(1 + t)` times a bound on the error of `r̂`, without
a difference of `θᵀy` and `P`. Each computed term carries a relative and an absolute rounding allowance,
and the operations after the passes over the data round outward. The run is certified when the resulting
upper bound of `(P − P*)/P*` (with a lower bound of `θᵀy` as denominator), rounded up, is at most
`prevfloat(1e-4)`, and that bound is reported in `gap`. The check is undefined if the recomputed residual
`r̂` is 0 in every entry with a nonzero coefficient (the direction is undefined; this is the usual
outcome at an exact fit `y = Xβ`, and `r̂` can also round to 0 where `y − Xβ` is not 0), if the sum
of squares of `r̂` is below `n 2^-969` or not finite, if a required intermediate value is not finite,
or if the penalty level cannot be bracketed. An exact fit whose `r̂` is not 0
goes through the bound like any other point, and a certificate there is valid. The check also replaces the cached
residual by `r̂` rounded to `T` when every entry is representable in `T`, and `minimum` is evaluated from
it at a stop of the check. A check costs one pass over `X` and one over its columns with nonzero
coefficients. The proof of the allowance is a comment in `src/cd/sqrtlasso.jl`.

The rounding of `r̂` in `Float64` is of the order of `eps(Float64)` times the row magnitudes
`|y_i| + Σ_k |X_ik β_k|` (larger than `eps(Float64) ‖Xβ‖` where terms of a row cancel). Where these
magnitudes dwarf the residual, for example where the fitted values do, that rounding enters the bound,
and a point that is optimal can fail to be certified.

The same evaluation stores outward primal bounds `P_lo(beta) <= P(beta) <=
P_up(beta)` before rejecting a zero recomputed residual or an out-of-range
residual sum of squares. These bounds are used by [CDQ-05](@ref), including at
exact fits where this point cannot supply a residual direction. To specify their
construction, let `sr` be the computed sum of squared `r̂` entries, `nb` the
number of nonzero coefficients, `sb` their computed sum of absolute values,
`epsilon = eps(Float64)`, `eta = nextfloat(0.0)` and `psi = (n + 1)*epsilon`.
Let `E_up` be the residual-error norm bound already used above, and let `lo` and
`hi` bracket the supplied penalty level used by the objective. With `up` and
`down` denoting `nextfloat` and `prevfloat` of the `Float64` round-to-nearest
result, the stored bounds are formed as follows:

```text
N_up = up(sqrt(up(up(sr*(1 + psi)) + n*eta)))
N_lo = sr >= n*2^-969 ? down(sqrt(down(sr*(1 - psi)))) : 0
S_up = up(sb*(1 + nb*epsilon))
S_lo = down(sb*(1 - nb*epsilon))
P_up = up(up(N_up + E_up) + up(hi*S_up))
P_lo = down(max(0, down(N_lo - E_up)) + down(lo*S_lo))
```

The proof uses `‖r̂‖² <= sr*(1 + psi) + n*eta`,
`‖y − Xβ‖ <= ‖r̂‖ + E_up`, the corresponding lower norm bound where
`sr >= n*2^-969`, and `lo*S_lo <= lambda*‖beta‖₁ <= hi*S_up` with
the displayed outward rounding. Thus the primal upper bound does not require
the residual-squares range restriction of the residual-direction certificate;
below that range the lower residual norm contribution is zero. The proof requires
finite residual and row-magnitude square sums and coefficient sum, together with
level brackets. When an aggregate is nonfinite or brackets are unavailable,
`P_up` is `Inf` or `NaN`, and the fallback does not use that point's bounds.
It also explicitly requires both initial primal bounds to be finite.
The stored dual bound is the check's finite positive `D_lo <= P*`, or `NaN`
when it was not formed or is not positive. At `y = 0`, `beta = 0`, the
exact-data special case stores `P_up = P_lo = 0` and no dual lower bound.

**Applies to.** The residual-direction check at an unsmoothed full-pass change stop, and the original-objective bounds recomputed before and after fallback stages.

**Code.** `src/cd/sqrtlasso.jl`: `_certify!`, `_stop_check!` and the proof comment for the rounding allowance.

**Tests.** `test/sqrt_lasso.jl`: independent BigFloat certificates, perturbed optima, extreme scales, exact-data special cases and fits dwarfing the residual; fallback decrease checks in BigFloat, reset of the stored bounds at the zero-response zero point, and nonfinite primal-bound cases.

**Sources.** `docs/src/numerics.md:L686`, `docs/src/numerics.md:L688`, `docs/src/numerics.md:L706`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L155`, `docs/src/index.md:L9`, `README.md:L96`. The later stored-primal-bound construction is [Step 7 and `_certify!` at f573224f](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L469-L576); [the target and upward result conversion](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L336-L372) distinguish the internal decision from its reported precision. These current-source qualifications are separate from the original baseline provenance.

## [CDQ-04 Tightening, uncertified stops and result flags](@id CDQ-04)

**Statement.**

At an unsmoothed full-pass change stop, a check that does not certify can divide
the threshold by 100 and continue. It does so at most twice in that run, only
when the certificate is defined, the full pass changed something, and
`tolerance/100` is finite, positive, strictly below `tolerance` and at least the
roundoff floor in the threshold's units. A threshold that overflowed to `Inf`
is not lowered and spends no tightening. With `relative = true` and `y != 0`,
the floor is `16 eps(T) norm(y)` and changes are scaled by `norm(X[:, k])`.
With an absolute threshold (`relative = false`, or `y = 0`), the floor is
`16 eps(T)` times the largest `abs(beta[k])` at the check, and no tightening
is allowed at `beta = 0`.

Otherwise the unsmoothed run makes an **uncertified stop**: the certificate is
undefined, the full pass changed nothing, the two tightenings were used, or the
threshold cannot be lowered. This is the entry point for [CDQ-05](@ref), rather
than an immediate final result when that fallback can run. Each fallback stage
starts with the original solver `tol` and a reset tightening count; its final
unsmoothed stage can therefore make up to two new tightenings. A positive
smoothing stage ends at its first full-pass change stop without running this
check inside the stage.

With `relative = true`, `y != 0` and the default `tol = 1e-7`, Float32 data get
no tightening because `1e-9` is below `16 eps(Float32)`. With `y = 0`, both the
threshold and floor are absolute and tightening can occur. At `y = 0` from a
nonzero start, `P* = 0`, so no relative bound can be certified unless `beta`
reaches zero. CD can approach zero without reaching it and stop uncertified;
the fallback can then reach zero and certify `gap = 0`, but need not do so.

At an exact fit with a positive penalty, a point can minimize every coordinate
without minimizing the whole objective. Its residual-direction certificate is
usually undefined because the recomputed residual is zero; that also happens
at an exact-fit optimum. The fallback can certify the stopped point with a dual
bound from another point or return a point with a proved lower objective, under
[CDQ-05](@ref). It does not guarantee recovery: a final uncertified point can
still be a nonoptimal exact fit. The tutorial includes two exact fits that the
fallback certifies and a noiseless, underdetermined small-penalty case that it
does not.

A run ending at an uncertified stop or after an uncertified fallback reports
`converged = false`, `gap = NaN`
and the warning `coordinate descent stopped without a duality certificate`.
An uncertified stop at the last allowed pass has no fallback budget and uses
this warning. A fallback that reaches `maxpasses` also uses this warning, so
`passes == maxpasses` alone does not distinguish it from an ordinary pass-limit
exit. By contrast, with `tol = 0`, or with a threshold below every change that
rounding permits, the strict change test never passes: no certificate or fallback
runs, and the solve reaches `maxpasses` with the pass-limit warning. A failed
certificate followed by a retry and then a pass-limit exit likewise supplies
no terminal uncertified stop and does not trigger the fallback.

At a certificate stop or completed fallback, `minimum` is evaluated from the
residual recomputed at the returned point, when every entry is representable in
`T`. [CDQ-05](@ref) specifies which point and change statistics are returned,
pass accounting and failure recovery. The pre-fallback final-stop assertions
are retained as historical evidence in [EVIDENCE-SQRT-406](@ref).

**Applies to.** Unsmoothed square-root CD stopping, including the initial solve, the fallback's final unsmoothed stage, exact fits, zero responses, final warnings and pass limits.

**Code.** `src/cd/sqrtlasso.jl`: `_stop_check!`, `_above_floor`, `_fallback!`; `src/cd/solver.jl`: strict change test and warning/result paths.

**Tests.** `test/sqrt_lasso.jl`: "stop check: certified, tightened, uncertified", "overflowed threshold: no retry, in both loops", zero-response, zero-tolerance, pass-limit, last-allowed-pass and fallback warning cases. For an overflowed effective threshold, each entered stage ends after one full pass, giving at most one initial plus nine fallback passes when the default budget is available.

**Sources.** `docs/src/numerics.md:L711`, `docs/src/numerics.md:L713`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L155`. The fallback superseding the immediate final-stop wording is [f573224f](https://github.com/mlakolar/ProximalSolvers.jl/commit/f573224f70058be24b81378ab2d6e1c752eb93e8), with the [current upstream explanation at ef8c9aae](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/docs/src/numerics.md#L711-L782). Historical assertions retain their original source IDs in [EVIDENCE-SQRT-406](@ref).

## [CDQ-05 Bounded fallback after an uncertified stop](@id CDQ-05)

**Statement.**

The fallback runs only after the initial unsmoothed CD run ends in the terminal
uncertified stop defined by [CDQ-04](@ref). It continues on the private working
iterate from that stopped point `x0`. A solve that simply exhausts `maxpasses`
does not trigger it. Let `base` be the passes used at the stop. All fallback
stages share one additional budget

```text
B = min(maxpasses - base, max(2000, 20*base)).
```

No stage runs when `B <= 0`. Otherwise the certificate is evaluated again at
`x0`, and fallback entry also requires finite `P0 = P_up(x0)` and
`L0 = P_lo(x0)`, `P0 > 0`, and finite `T(P0)`. There is no separate requirement
that `T(P0)` be positive: conversion can round a positive bound to zero. The
bounds and their range limits are in [CDQ-03](@ref). For example, an overflowing
Float64 primal upper bound skips the fallback even if the original objective
can still be evaluated finitely; a finite Float64 bound above the Float32
range also skips it for Float32 data.

### Stages and continuation

Stages 1 through 8 use the smoothed coordinate step in [CDQ-02](@ref), followed,
if the budget and earlier return rules allow, by stage 9 with zero smoothing.
Each stage uses the caller's order, momentum choice, RNG, `tol` and `relative`,
starts a fresh momentum history, resets its tightening count and starts with
the original solver threshold rather than a tightened threshold from the
preceding run. The stages continue from the preceding stage's point; they do
not restart from `x0`.

A Float64 continuation value `delta` starts at `P0`. Each of the first eight
stages uses `Float64(T(delta))` as its effective smoothing level and its square
rounded in `T`. After an evaluated stage that does not end the fallback,
`delta = min(delta/5, Fbest)`, where `Fbest` is the least finite primal upper
bound found at `x0` or any evaluated stage. `Fbest` controls the next smoothing
level; it does not save an earlier iterate for return. While the effective
smoothing level is positive, the stage ends at its first full pass satisfying
the change test, without an in-stage certificate, or at the remaining budget.
If conversion rounds the effective level to zero, the ordinary unsmoothed
stop check runs instead. Stage 9 always uses that unsmoothed check and its
possible tightenings.

After each stage, smoothing is cleared and the certificate's original-objective
bounds are recomputed at the stage point `beta`. No smoothed objective value is
used for certification or the decrease test. Let `D` be the largest finite
positive dual lower bound found at `x0` or any evaluated stage, or zero before
one is found. Every such bound satisfies `D <= P*`, even when obtained at a
different point from the one eventually returned.

### Ordered return rules

For a positive objective bound, define
`ratio(P, D) = up(up(P - D)/D)` when `D > 0`, and `Inf` otherwise, with the
outward Float64 rounding from [CDQ-03](@ref). The exact-data case `P = 0` has
ratio zero: the certificate produces that bound only for `y = 0`, `beta = 0`,
where `P = P* = 0`. After each stage, the first applicable rule ends the fallback:

1. Return `x0` certified if `ratio(P0, D) <= prevfloat(1e-4)`.
2. Otherwise return the current stage point `beta` certified if its `P_up` is
   finite, `P_up(beta) < L0`, and
   `ratio(P_up(beta), D) <= prevfloat(1e-4)`.
3. Otherwise, after stage 9 or at the shared budget, return `beta` uncertified
   if `P_up(beta)` is finite and strictly below `L0`; return `x0` uncertified
   if that decrease test fails.

If none applies and budget remains before stage 9, continue to the next stage.
In particular, a changed returned point always has the proved strict decrease
`P(beta) <= P_up(beta) < P_lo(x0) <= P(x0)`. Returning `x0` first can preserve
an exact-fit optimum whose own residual direction is undefined while certifying
it with a stage's dual bound. A zero point reached from a zero response is
returned certified with `gap = 0` when it satisfies the strict decrease test
against `L0 > 0`.

For a positive optimum, a certified fallback ratio bounds
`(P - P*)/P*` at the returned point because `0 < D <= P*`. The ratio is rounded
up to `T` in the result. The fallback recomputes its ratio even when stage 9's
own stop certificate passed. When `D` is that stage's own dual bound, the
fallback's `(P_up - D)/D` is at least the stage's own certificate ratio. A
point whose own check passes only within a margin of order
`(P_up - P_lo)/D` can consequently be returned uncertified. A passing internal
stage flag alone never bypasses the ordered return rules.

### Refusals, results and ownership

An `ArgumentError` thrown during a stage, including a refused nonfinite step
or stopping scale, ends the fallback with `x0`, uncertified. It counts all
completed passes of that stage and the refused pass itself. Any other exception
is rethrown after the smoothing fields have been cleared. This recovery rule
applies to errors inside the stage run; it does not swallow a later failure of
the final objective check.

When `x0` is returned, its copied coefficient state is restored, its residual
is reinitialized and recomputed by the certificate, and `maxchange` and
`tolerance` are restored to the values at the initial stop. When the current
stage point is returned, those two statistics describe the last stage. In both
cases, `passes` includes the initial passes and every fallback pass, active and
full, including a refused pass under the recovery rule, and is at most
`maxpasses`. `kkt_checks = 0` remains a compatibility sentinel; it is not the
number of certificates or stages. The borrowed RNG continues advancing through
the fallback and is not restored when `x0` is returned.

A certified result has `converged = true` and the proved `gap`; otherwise it
has `converged = false`, `gap = NaN` and the uncertified warning described in
[CDQ-04](@ref). `minimum` evaluates the original objective from the certificate's
recomputed residual at the returned point when that residual is representable
in `T`. A finite completed result then commits under [CDS-03](@ref), including
an uncertified `x0` restored after a caught stage refusal. If that final objective
is nonfinite, `ArgumentError` still propagates before the caller is changed;
the warning can already have been emitted. [CDS-04](@ref) and [RES-03](@ref)
specify that outer transaction boundary.

The budget and proved-decrease rule do not guarantee recovery at exact fits.
The result can remain uncertified at `x0` or at a lower-objective point that is
not optimal. A nonoptimal exact fit can therefore still have `converged = false`;
check such a point by other means. The measured recovery rates and hard cases
reported with this change are preserved as observations in
[EVIDENCE-SQRT-406](@ref), not as guaranteed rates.

**Applies to.** Square-root lasso CD on dense vectors or one-dimensional `SparseIterate` owners after a terminal uncertified stop. The shared model hook is a no-op for models without a certificate.

**Code.** `src/cd/sqrtlasso.jl`: `_fallback!`, `_fallback_ratio`, `_certify!` and `_stop_check!`; `src/cd/solver.jl`: `_run_cd!`, `_cd_plain!`, `_cd_momentum!` and finite-objective completion; `src/cd/models.jl`: default no-op fallback.

**Tests.** `test/sqrt_lasso.jl` section E checks the #155 improved-point and #156 kept-point fixtures, the hard noiseless `40 × 120` problem near `1e-3 lambda_max`, objective comparisons in BigFloat, the bounded pass total, a fallback reaching `maxpasses`, zero budget at the last allowed pass, stage-step refusals, zero-response recovery and primal bounds outside the Float64/Float32 ranges. Both precisions cover cyclic dense solves and random owner solves with momentum; refused-stage cases cover dense and owner wrappers. The existing zero-tolerance test verifies that an ordinary pass-limit exit has no fallback.

**Sources.** This clause was introduced after the frozen documentation baseline: [f573224f, fallback implementation and proof](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L578-L665), [its run and commit boundary](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/solver.jl#L567-L593), [stage and result tests](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/test/sqrt_lasso.jl#L1038-L1197), and [the integrated upstream numerical explanation at ef8c9aae](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/docs/src/numerics.md#L735-L782).

## [CDQ-06 Scaled-lasso profile and exact-fit interpretation](@id CDQ-06)

**Statement.**

For `lambda = sqrt(n)*lambda_0`, the scaled-lasso joint objective is

```math
L(\beta, \sigma) = \frac{\|y-X\beta\|_2^2}{2n\sigma}
  + \frac{\sigma}{2} + \lambda_0\|\beta\|_1,
\qquad \sigma > 0.
```

For a fixed coefficient point with nonzero residual `r = y - X*beta`, its
conditional minimizer is `sigma_hat = norm(r)/sqrt(n) > 0`:
`L(beta, sigma) - L(beta, sigma_hat) = (sigma - sigma_hat)^2/(2sigma) >= 0`.
At that scale, `L(beta, sigma_hat) = P(beta)/sqrt(n)`. Therefore an actual
square-root-lasso minimizer with nonzero residual gives a scaled-lasso minimizer
at this scale. The package implements this through square-root CD and the
profile calculation, without a separate scaled-lasso solver; the square-root
input refusals, including weighted penalties, still apply.

The joint infimum over `beta` and `sigma > 0` is `P*/sqrt(n)`, including when
it is approached at an exact fit as `sigma` decreases to zero. For `y != 0`
and positive `lambda`, `P* > 0`: a zero objective would require both `beta = 0`
and `y - X*beta = 0`. A certified square-root result with nonzero residual
therefore also proves
`(L(beta, sigma_hat) - inf L)/inf L <= 1e-4` in exact arithmetic at the
profiled scale, and the reported `gap` is an outward upper bound on that
relative error. Its final conversion to Float32 can round it just above the
decimal target, as specified in [CDQ-03](@ref). Evaluation of the residual, scale and joint objective in
Float32 or Float64 introduces its own rounding, covered by the scaled-lasso
tests. The objective certificate does not bound the distance of `sigma_hat`
from an optimizing scale, coefficient recovery, or noise-variance estimation.

At an exact fit, `L(beta, sigma) = sigma/2 + lambda_0*norm(beta, 1)` decreases
strictly as `sigma` decreases and approaches `P(beta)/sqrt(n)` without attaining
it for any positive `sigma`. Thus even a certified square-root point at an
exact fit has no conditional positive noise-scale minimizer. It is not presented
with a `sigma_hat` or as a scaled-lasso solution. This statement concerns the
returned coefficient point; it does not settle whether another square-root
minimizer with a nonzero residual attains the joint minimum. A very small
nonzero residual is different: its conditional positive `sigma_hat` exists.

For `y = 0`, the zero point has `P = P* = 0`, so the solver's `gap = 0` is an
exact-optimality special case rather than a relative gap and supplies no positive
noise-scale minimizer. A run started at zero certifies it directly. From a
nonzero start the fallback can reach and certify zero, or end uncertified.
An uncertified returned point with nonzero residual still has a conditional
scale minimizer at that point, but no certificate for the joint optimization.

The updated exact-fit fixture `X = [1 2; 0 1]`, `y = (1, 0)`, `lambda = 0.1`
starts at zero, reaches `(1, 0)` and is certified by the fallback using another
point's dual bound. Its stored residual is zero, so the scaled-lasso tutorial
continues to demonstrate unattained conditional scale minimization even though
the square-root objective is now certified. The old statement that this fixture
was uncertified is retained in [EVIDENCE-EXAMPLES-01](@ref).

**Applies to.** Interpreting an accepted square-root CD result as a scaled-lasso coefficient/scale pair; the joint objective requires `sigma > 0`.

**Code.** `examples/problems/scaled_lasso.jl`: profiled scale, joint objective, independent stationarity checks and exact-fit example; the solver and certificate are [CDQ-01](@ref), [CDQ-03](@ref) and [CDQ-05](@ref).

**Tests.** `test/scaled_lasso.jl`: profiling identities and scale-rounding bounds, a residual separated from zero, exact fits and small nonzero residuals, the now-certified exact-fit fixture in both precisions, and a pass-limited uncertified result. `test/sqrt_lasso.jl` separately checks the fallback fixtures and zero-response outcomes.

**Sources.** The baseline normalization and tutorial link remain `docs/src/numerics.md:L663`, `README.md:L96`. The complete profile interpretation and changed exact-fit result are in the [scaled-lasso tutorial at ef8c9aae](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/examples/problems/scaled_lasso.jl#L8-L22), [its certificate and exact-fit discussion](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/examples/problems/scaled_lasso.jl#L134-L194), and [the updated tests at f573224f](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/test/scaled_lasso.jl#L299-L340). These later sources do not replace the frozen baseline inventory.
