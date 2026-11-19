# [Square-root lasso coordinate descent](@id CDQ-01)

<!-- Migration source: docs/src/numerics.md:L661-L729 -->

## Square-root lasso

`CDSolver` with `SqrtLeastSquaresLoss` (see [Supported problems](../support.md)) uses the pass schedule,
momentum and change test of the lasso with the loss scale `s = 1`: with `relative=true` and `y ≠ 0` the
threshold is `tol * norm(y)`, and a change is multiplied by `norm(X[:, k])`; with `relative=false`, or
`y = 0`, the threshold is the absolute `tol` and a change is not scaled.

### The coordinate step

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

### The certificate

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

### Tightening and the uncertified stop

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

<!-- Migration source: docs/src/support.md:L285-L315 -->

### Square-root lasso with coordinate descent

~~~math
\min_\beta\quad P(\beta) = \|y-X\beta\|_2+\lambda\|\beta\|_1
~~~

with ProximalBase's [`SqrtLeastSquaresLoss(y, X)`](https://mlakolar.github.io/ProximalBase.jl/dev/)
(the loss is unnormalized) and `NormL1(lambda)`. `solve!(x, f, g, CDSolver(...))` accepts this problem
when `x` is a dense `Vector{T}` or a one-dimensional `SparseIterate{T}`, `X` and `y` are as above, and
`lambda` is positive, finite and representable in `T`. The normalized objective
`‖y − Xβ‖₂/√n + λₙ‖β‖₁` (`Scaled(f, inv(sqrt(n)))` in ProximalBase) has the same minimizers as `P` at
`lambda = sqrt(n) * λₙ`, and its values are those of `P` divided by `√n`. The [scaled lasso](../glossary.md) at
the level `λ₀` has as its coefficient estimate a minimizer of `P` at `lambda = sqrt(n) * λ₀`, and as its noise
estimate `norm(y - X*beta)/sqrt(n)` when `y ≠ X*beta`; the package provides no separate scaled-lasso method,
and [the scaled-lasso tutorial](../examples/problems/scaled_lasso.md) shows the computation.
Refused with an `ArgumentError`, before `x` is
copied or the random number generator is used: `Scaled(SqrtLeastSquaresLoss, alpha)` (for a positive
finite `alpha`, use the unscaled loss at the level `lambda/alpha`), `lambda = 0` (use `LeastSquaresLoss`,
which has the same minimizers), a weighted `NormL1` (also with all weights equal to one), an `ElasticNet`,
a `BlockIterate`, and `ProximalGradientDescent` or `AccProxGradDescent` (ProximalBase provides no gradient
for this loss; for `X ≠ 0` it is not differentiable where `y = X*beta`).

For this loss, `converged = true` means that a duality certificate proved
`(P(beta) − P*)/P* ≤ 1e-4`, with `P*` the minimum, and `gap` then holds that proved bound. A run that
stops without a certificate reports `converged = false` and `gap = NaN`, with its own warning: at an exact
fit (`y = X*beta`) with a positive penalty, coordinate descent can stop at a point that minimizes every
coordinate but not `P`. [`CDSolver`](@ref) describes the stopping rule, and
[Numerical behavior](../numerics.md) the step and the certificate.
[The square-root lasso tutorial](../examples/problems/square_root_lasso.md) solves a seeded problem, checks it
independently from the data, and shows two exact fits.

<!-- Migration source: src/cd/solver.jl:L138-L178 -->

**Square-root lasso.** With `T` equal to `Float32` or `Float64`, `X::Matrix{T}`, `y::Vector{T}`,
ProximalBase's `f = SqrtLeastSquaresLoss(y, X)` and `g = NormL1(lambda)`, the call
`solve!(x, f, g, CDSolver(...))` minimizes `P(beta) = norm(y - X*beta) + lambda * norm(beta, 1)`,
without a `1/sqrt(n)` factor, for a dense `Vector{T}` or a one-dimensional `SparseIterate{T}` `x`.
The normalized objective `norm(y - X*beta)/sqrt(n) + lambda_n * norm(beta, 1)` has the same
minimizers at `lambda = sqrt(n) * lambda_n`, and its values are those of `P` divided by `sqrt(n)`; a
scaled-lasso noise estimate is then `norm(y - X*beta)/sqrt(n)` at the solution. `lambda` must be
positive (at `lambda = 0`, use `LeastSquaresLoss`, which has the same minimizers), finite and
representable in `T`; it may be given in another `Real` type. A weighted `NormL1`, an `ElasticNet`,
`Scaled(SqrtLeastSquaresLoss, alpha)` (for a positive finite `alpha`, use the unscaled loss at the
level `lambda/alpha`), a `BlockIterate`, and `ProximalGradientDescent` or `AccProxGradDescent`
(ProximalBase provides no gradient for this loss; for `X != 0` it is not differentiable where
`y = X*beta`) are refused with an `ArgumentError` before `x` changes. A visit computes the minimizer
of `P` over its coordinate, up to rounding: a soft threshold at the least-squares centre with a threshold
that depends on the residual. The order, momentum, the change threshold and `maxpasses` are as for least
squares.

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

