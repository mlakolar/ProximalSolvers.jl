# [Square-root fallback: historical assertions and evaluation](@id EVIDENCE-SQRT-406)

**Statement.**

The bounded square-root-lasso fallback was introduced by
[PR #406 / issue #155, commit f573224f](https://github.com/mlakolar/ProximalSolvers.jl/commit/f573224f70058be24b81378ab2d6e1c752eb93e8),
retained in the integrated upstream revision
[ef8c9aae](https://github.com/mlakolar/ProximalSolvers.jl/commit/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7).
The current rules are [CDQ-02](@ref) through [CDQ-06](@ref). This page keeps
superseded final-stop descriptions from the original documentation baseline and
the evaluation reported with the later change. Historical assertions below are
not current solver guarantees or newly executed measurements.

Before the fallback, an undefined residual-direction certificate at an exact fit
ended the solve uncertified. The current algorithm can use a dual lower bound
from a stage point to certify the original stopped point, or return a changed
point with a proved strict objective decrease. Consequently, the old assertions
about the final status of the two exact-fit tutorial fixtures describe the old
implementation. The old example-index descriptions are preserved in
[EVIDENCE-EXAMPLES-01](@ref); the integrated tutorials now show two successful
fallback fixtures and an uncertified hard case. A certified exact-fit square-root
point still has no conditional positive scaled-lasso noise-scale minimizer,
as specified in [CDQ-06](@ref).

**Applies to.** The frozen pre-fallback documentation at `a6293e6ff7e654a87babbc5de2314205be13d6c5`, and the synthetic evaluation reported with f573224f. These populations and revisions are historical evidence.

**Code.** Historical source/docstring blocks below; current `src/cd/sqrtlasso.jl`, `examples/problems/square_root_lasso.jl` and `examples/problems/scaled_lasso.jl` at ef8c9aae.

**Tests.** Original block text is preserved verbatim below, except the relative-link target adjustments recorded with the support and stopping excerpts. The later implementation tests are listed under [CDQ-05](@ref) and [CDQ-06](@ref). The evaluation percentages below are reported observations, not new test results or promised recovery rates.

**Sources.** `docs/src/numerics.md:L670`, `docs/src/numerics.md:L688`, `docs/src/stopping-limits.md:L35`, `docs/src/numerics.md:L713`, `docstring:src/cd/solver.jl:L155`, `docstring:src/cd/solver.jl:L219`, `docs/src/support.md:L307`, `docs/src/working-with-results.md:L91`. Later material comes from [the immutable upstream numerical explanation](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/docs/src/numerics.md#L774-L782) and [the #155 evaluation record](https://github.com/mlakolar/ProximalSolvers.jl/issues/155#issuecomment-6995966493). These new sources are separate from the original block inventory.

## Evaluation reported with the fallback

The #155 evaluation used synthetic problems in Float32 and Float64. It reported:

- Certification in 82% of the runs on noiseless, near-exact and adversarial
  exact-fit starts, and in 39 of 43 stops at a near-optimal point.
- Certification in 22 of 160 runs on realistic designs at a quarter of the
  theoretical penalty level.
- No certifications in 20 runs on equicorrelated designs with correlation 0.7.
- No certifications in 16 noiseless runs with `p > n` at `1e-3 lambda_max`;
  every one of those runs used its fallback budget in the first stage.
- Exhaustion of the fallback budget in 38% of the runs that reached it.

These measurements do not guarantee recovery for other designs, levels, starts
or precisions. In particular, an uncertified returned point may still be a
nonoptimal exact fit. The square-root counts in [AUDIT-04](@ref) are a different,
earlier population measured at the stop check before this fallback.

## Original baseline excerpts

The following text describes the implementation before f573224f. Its statements
about immediate final uncertified returns are superseded by [CDQ-04](@ref) and
[CDQ-05](@ref), while its unchanged certificate, normalization and result facts
are retained in the canonical clauses. The original CDResults description is
also retained because the updated description adds fallback pass accounting.

### Historical numerical guidance: tightening and final stops

A check that does not certify divides the threshold by 100 and the run continues, at most twice per solve
and while `tolerance/100` is finite, positive, below `tolerance` (a threshold that overflowed to `Inf`
is not lowered) and at least a floor in the units of the threshold: `16 eps(T)
norm(y)` for a relative threshold (`relative=true` and `y ≠ 0`, where a change is scaled by
`norm(X[:, k])`), and `16 eps(T)` times the largest `|β_k|` at the check for an absolute one
(`relative=false`, or `y = 0`), with no tightening at `β = 0`. The run stops with `converged = false`,
`gap = NaN` and the warning `coordinate descent stopped without a duality certificate` when the
certificate is not defined (above), when the full pass changed nothing, or when no tightening is left.
With `relative=true`, `y ≠ 0` and the default `tol = 1e-7`, `Float32` data get no tightening, because
`1e-9` is below `16 eps(Float32)`; with `y = 0` the threshold and its floor are absolute, and a tightening
can occur. With `y = 0` and a nonzero start, `P* = 0`, so no relative bound can be certified unless `β`
reaches 0; coordinate descent can approach 0 without reaching it and then stops uncertified. At an exact
fit with a positive penalty, coordinate descent can stop at a point that minimizes `P` along every
coordinate but not overall; such a run, and one that stops at the minimizer at an exact fit, are
reported uncertified where the recomputed residual is 0, which is the usual outcome. An uncertified stop at the last allowed
pass gets the uncertified warning, and `passes == maxpasses` alone does not tell it apart from the limit.

### Historical CDSolver stopping description

A full pass whose largest change is below the threshold runs a duality certificate: a dual point along
the residual `y - X*beta`, recomputed in `Float64`, with a proved bound on the rounding of each computed
term. `converged = true` only when it proves `(P(beta) - P*)/P* <= 1e-4`, `P*` the minimum, and `gap`
then holds that bound, rounded up; its denominator is a lower bound of `P*` from the dual point. When
the certificate does not pass, the change threshold (the reported `tolerance`) is divided by 100 and the
run continues, at most twice per solve, where `tolerance/100` is finite, positive and below `tolerance`
(an effective threshold that overflowed to `Inf` is not lowered), and not below a floor in the units of
the threshold: with a
relative threshold (`relative=true` and `y != 0`), `16 eps(T)` times `norm(y)`; with an absolute one
(`relative=false`, or `y = 0`), `16 eps(T)` times the largest `abs(beta[k])` at the check, and no
tightening at `beta = 0`. Otherwise the run stops with `converged = false`, `gap = NaN` and a warning that
differs from the `maxpasses` warning. This happens where the recomputed residual is 0 with a nonzero
coefficient, so that the dual direction is undefined: the usual outcome at an exact fit (`y = X*beta`)
with a positive penalty, where a coordinatewise minimum need not be a minimum (the residual can also
round to 0 where `y - X*beta` is not 0, and an exact fit whose recomputed residual is not 0 can be
certified, validly); after a full pass that changed nothing; with `y = 0` and a nonzero start, where `P* = 0`, so that no relative bound
can be certified unless `beta` reaches 0, and coordinate descent can approach 0 without reaching it; and
when the threshold cannot be lowered further, for example where the rounding of the recomputed residual
is not small against the residual itself (as where the fitted values dwarf it), or for `Float32` data
at the default `tol` with a relative threshold, where `tol/100` is below that floor. With `tol = 0`, or
a threshold below the changes that rounding produces, the change test does not pass, the certificate
does not run, and the run ends at `maxpasses` with that warning. At a stop of the certificate,
`minimum` is evaluated from the residual that it recomputed, when every entry of it is representable
in `T`.

### Historical CDResults description

Result sharing the caller's vector or `SparseIterate` as minimizer, with minimum,
passes, converged, maxchange and tolerance. The compatibility field `kkt_checks = 0` is a
sentinel. `gap` is `NaN` except after a certified square-root lasso run (see [`CDSolver`](@ref)),
where `converged = true` and `gap` is the certified upper bound on `(P - P*)/P*`. For the
least-squares lasso and elastic net and the group lasso, `converged` reports the change test and
`gap` is `NaN`.

### Historical support guidance

Only the relative targets `numerics.md` and `examples/problems/square_root_lasso.md` have been adjusted to `../../numerics.md` and `../../examples/problems/square_root_lasso.md`.

For this loss, `converged = true` means that a duality certificate proved
`(P(beta) − P*)/P* ≤ 1e-4`, with `P*` the minimum, and `gap` then holds that proved bound. A run that
stops without a certificate reports `converged = false` and `gap = NaN`, with its own warning: at an exact
fit (`y = X*beta`) with a positive penalty, coordinate descent can stop at a point that minimizes every
coordinate but not `P`. [`CDSolver`](@ref) describes the stopping rule, and
[Numerical behavior](../../numerics.md) the step and the certificate.
[The square-root lasso tutorial](../../examples/problems/square_root_lasso.md) solves a seeded problem, checks it
independently from the data, and shows two exact fits.

### Historical results troubleshooting row

| Symptom | Historical interpretation |
| --- | --- |
| Square-root lasso: `converged = false` with a warning about a missing duality certificate | The certificate did not pass, for example at an exact fit (`y = X*beta`), where coordinate descent can stop at a coordinatewise minimum that is not a minimum; see [`CDSolver`](@ref) and [an example](@ref sqrt-lasso-exact-fit) |

The unsmoothed coordinate arithmetic below remains bit for bit the current zero-smoothing step. Its scope now excludes positive-smoothing stages. The certificate excerpt describes the residual-direction check at the current point; the fallback can also certify a returned point using another point's dual bound. The stopping overview predates that additional path.

### Historical unsmoothed coordinate rule

With `a = ‖X_k‖²`, `b = X_kᵀr`, the centre `c = old + b/a` and `d` the distance of `r` from the span of
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

### Historical residual-direction certificate description

At a full pass whose largest change is below the threshold, the residual `r̂ = y − Xβ` is recomputed in
`Float64` over the nonzero coefficients, with the row magnitudes `|y_i| + Σ_k |X_ik β_k|`. The dual
point is `θ = t r̂/‖r̂‖` with `t ≤ min(1, λ/max_k |X_kᵀr̂|/‖r̂‖)`, where the maximum is replaced by an upper
bound and `t` is rounded down, so that `‖θ‖ ≤ 1` and `‖Xᵀθ‖∞ ≤ λ` hold exactly; weak duality then gives
`P* ≥ θᵀy`. The gap `P − θᵀy` is bounded by a sum of terms that are nonnegative in exact arithmetic,
`(1 − t)‖r̂‖ + Σ_k (λ|β_k| − t β_k X_kᵀr̂/‖r̂‖)` plus `(1 + t)` times a bound on the error of `r̂`, without
a difference of `θᵀy` and `P`. Each computed term carries a relative and an absolute rounding allowance,
and the operations after the passes over the data round outward. The run is certified when the resulting
upper bound of `(P − P*)/P*` (with a lower bound of `θᵀy` as denominator), rounded up, is at most
`1e-4`, and that bound is reported in `gap`. Not certified: a recomputed residual `r̂` that is 0 in every
entry with a nonzero coefficient (the direction is undefined; this is the usual outcome at an exact fit
`y = Xβ`, and `r̂` can also round to 0 where `y − Xβ` is not 0), a sum of squares of `r̂` below
`n 2^-969` or not finite, and an intermediate value that is not finite. An exact fit whose `r̂` is not 0
goes through the bound like any other point, and a certificate there is valid. The check also replaces the cached
residual by `r̂` rounded to `T` when every entry is representable in `T`, and `minimum` is evaluated from
it at a stop of the check. A check costs one pass over `X` and one over its columns with nonzero
coefficients. The proof of the allowance is a comment in `src/cd/sqrtlasso.jl`.

### Historical stopping overview

Only the relative target `sparsity-and-kkt.md` has been adjusted to `../../sparsity-and-kkt.md`.

Of the problems audited, only the square-root lasso carries a certificate, and that
certificate has the assumptions stated in [The certificate](@ref "The certificate") and
[Tightening and the uncertified stop](@ref "Tightening and the uncertified stop"). For the
other solvers `converged = true` reports that the criterion of its row was met. Check the
returned point with the [independent KKT residual](../../sparsity-and-kkt.md) when the result
matters.
