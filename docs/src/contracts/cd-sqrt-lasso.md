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

The normalized objective `norm(y - X*beta)/sqrt(n) + lambda_n * norm(beta, 1)` has the
same minimizers at `lambda = sqrt(n) * lambda_n`, and its values are `P/sqrt(n)`.
ProximalBase can express the normalized loss as `Scaled(f, inv(sqrt(n)))`; the solver
accepts the equivalent unscaled problem with the transformed level, as specified below.
The scaled-lasso coefficient estimate at level `lambda_0` uses the same transformation,
and its noise estimate is `norm(y - X*beta)/sqrt(n)` when `y != X*beta`. There is no
separate scaled-lasso solver; the [scaled-lasso tutorial](../examples/problems/scaled_lasso.md)
shows that computation.

Before copying the iterate or using the RNG, `ArgumentError` refuses a weighted
`NormL1` even with all weights one, an `ElasticNet`, a `BlockIterate`, or
`Scaled(SqrtLeastSquaresLoss, alpha)`. For positive finite `alpha`, use the unscaled
loss with level `lambda/alpha` instead. `lambda = 0` is refused; `LeastSquaresLoss`
has the same unpenalized minimizers. `ProximalGradientDescent` and
`AccProxGradDescent` are refused because ProximalBase
provides no gradient for this loss and, for `X != 0`, it is nondifferentiable at
`y = X*beta`.

The order, momentum and pass limits are those of scalar CD, with loss scale `s = 1`.
For `relative = true` and `y != 0`, the threshold is `tol * norm(y)` and a coordinate
change is scaled by `norm(X[:, k])`; otherwise the threshold is absolute `tol` and
changes are unscaled. A change-based stop must also pass [the certificate](@ref CDQ-03).

**Applies to.** Unscaled square-root loss, positive unweighted L1 penalty, scalar CD iterates.

**Code.** `src/solve.jl`: square-root preflight; `src/cd/sqrtlasso.jl`: `SqrtLSModel`.

**Tests.** `test/sqrt_lasso.jl`: input refusals, scalar levels of other types, and analytic cases; `test/scaled_lasso.jl`.

**Sources.** `docs/src/numerics.md:L661`, `docs/src/numerics.md:L663`, `docs/src/support.md:L285`, `docs/src/support.md:L287`, `docs/src/support.md:L291`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L138`, `README.md:L65`, `README.md:L96`, `docs/src/support.md:L130`.

## [CDQ-02 Coordinate minimization and range rules](@id CDQ-02)

**Statement.**

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

**Applies to.** Each square-root CD coordinate visit, with the supplied level converted to `T`.

**Code.** `src/cd/sqrtlasso.jl`: coordinate step, `_sqrt_threshold64` and its rounding-bound derivation.

**Tests.** `test/sqrt_lasso.jl`: one-column step cases, random steps against the derived bound, nonfinite-residual preflight.

**Sources.** `docs/src/numerics.md:L668`, `docs/src/numerics.md:L670`, `docstring:src/cd/solver.jl:L138`.

## [CDQ-03 Outward-bounded duality certificate](@id CDQ-03)

**Statement.**

`converged = true` is reported only when the certificate proves
`(P(beta) - P*)/P* <= 1e-4`; `gap` then holds the proved upper bound, rounded up.

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

The rounding of `r̂` in `Float64` is of the order of `eps(Float64)` times the row magnitudes
`|y_i| + Σ_k |X_ik β_k|` (larger than `eps(Float64) ‖Xβ‖` where terms of a row cancel). Where these
magnitudes dwarf the residual, for example where the fitted values do, that rounding enters the bound,
and a point that is optimal can fail to be certified.

**Applies to.** A square-root CD full pass whose largest change is below the effective threshold.

**Code.** `src/cd/sqrtlasso.jl`: `_certify!`, `_stop_check!` and the proof comment for the rounding allowance.

**Tests.** `test/sqrt_lasso.jl`: independent BigFloat certificates, perturbed optima, extreme scales, exact-data special cases and fits dwarfing the residual.

**Sources.** `docs/src/numerics.md:L686`, `docs/src/numerics.md:L688`, `docs/src/numerics.md:L706`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L155`, `docs/src/index.md:L9`, `README.md:L96`.

## [CDQ-04 Tightening, uncertified stops and result flags](@id CDQ-04)

**Statement.**

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

With `tol = 0`, or a threshold below the changes produced by rounding, the change test
does not pass, the certificate does not run, and the solve ends at `maxpasses` with
the pass-limit warning. At a stop of the certificate check, `minimum` is evaluated
from its recomputed residual when every entry is representable in `T`, as specified
in [CDQ-03](@ref). The [square-root tutorial](../examples/problems/square_root_lasso.md)
checks a seeded problem independently and includes two exact-fit examples.

**Applies to.** Square-root CD after a full-pass change stop, including exact-fit and zero-response limitations.

**Code.** `src/cd/sqrtlasso.jl`: `_stop_check!`, `_above_floor`; `src/cd/solver.jl`: warning/result paths.

**Tests.** `test/sqrt_lasso.jl`: "stop check: certified, tightened, uncertified", "overflowed threshold: no retry, in both loops", zero-response, pass-limit and warning cases.

**Sources.** `docs/src/numerics.md:L711`, `docs/src/numerics.md:L713`, `docs/src/support.md:L307`, `docstring:src/cd/solver.jl:L155`.
