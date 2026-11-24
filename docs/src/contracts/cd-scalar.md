# Scalar coordinate descent

These clauses cover least-squares lasso, weighted lasso, elastic net with or without weights on its L1 term,
ridge with an uncentered `SqrNormL2` penalty, and, on a dense `Vector`, nonnegative
least squares and nonnegative lasso (`IndNonnegative()` and unweighted `NormL1Nonneg`).
Read the [input rules](@ref IN-01), [working precision](@ref FP-01), and
[result and failure rules](@ref RES-01) with them. Specialized storage and losses have
their own clauses: [SparseIterate](@ref CDS-01), [groups](@ref CDG-01),
[matrix responses](@ref CDM-01), and [square-root lasso](@ref CDQ-01).

## [CD-01 Problem and scalar coordinate update](@id CD-01)

**Statement.**

For a loss scale `s`, the objective is `(s/2) * sum(abs2, y - X*beta) + g(beta)`.
The public call is `solve!(beta, f, g, CDSolver())`.
`CDSolver` accepts matching `Float32` or `Float64` dense design/response data and
coefficients in a dense `Vector` or a one-dimensional `SparseIterate`. The penalty is
`NormL1(lambda)`, `NormL1(lambda, w)`, `ElasticNet(lambda1, lambda2)`,
`ElasticNet(lambda1, lambda2, w)` or an uncentered `SqrNormL2(lambda)`; for a dense `Vector` start only, also
`IndNonnegative()` or an unweighted `NormL1Nonneg(lambda)` under [IN-07](@ref).
The weights of `NormL1` are a `Vector{T}` of finite nonnegative entries. Input validation
checks `T(lambda)` and the rounded coefficient `T(lambda) * w[k]` to be zero or normal
numbers of `T`; a zero weight leaves its coordinate unpenalized. The weights of an
`ElasticNet` scale its L1 term `lambda1` only, with the same checks on `T(lambda1)` and
`T(lambda1) * w[k]`; the ridge term `lambda2` applies to every coordinate. The complete rules
are [IN-03](@ref). The private run, including the final objective, receives the working
penalty of that clause for a weighted `ElasticNet`, on a dense `Vector` and on a
`SparseIterate` alike.

For a finite positive column squared norm `a`, the step soft-thresholds the unpenalized
coordinate minimizer at `lambda / (s * a)` in the lasso case. In the normal step band,
ProximalBase's `prox_block` forms the threshold from the supplied level and weight in its
working type, so its threshold need not equal one formed from the already-rounded checked
coefficient. The [range rule](@ref CD-04) specifies the exceptional band and the
positive-ridge refusal. At every visit a flat column (all entries zero) sets its scalar
coordinate to zero for these accepted penalties, including a zero level or weight;
for `IndNonnegative()` and `NormL1Nonneg` the coordinate is set to `+0` (no sign bit).
A nonflat column whose squared norm underflows to zero is refused. With `maxpasses = 0`
no coordinate is visited.

For uncentered `SqrNormL2(lambda)`, `g(beta) = (lambda/2) * sum(abs2, beta)`:
this is the elastic-net objective with zero L1 level. Construct the penalty as
`SqrNormL2(lambda)`; the exact center-type and level checks are [IN-01](@ref)
and [IN-02](@ref). In the normal step band, the implementation calls
ProximalBase's `prox_block(g, c, k, gamma)` at `c = old + b/a`,
`b = dot(X[:, k], r)` and `gamma = inv(s*a)`. In exact arithmetic this ridge
prox is `c / (1 + gamma*lambda)`. The supplied penalty and scale participate
in the oracle's working precision; equivalence to `ElasticNet(0, lambda)` is
an objective equivalence, not a promise of bitwise-identical iterates.

For `IndNonnegative()` the step in the normal band is `prox_block(g, c, k, gamma)`, which is
`max(c, 0)`; for an unweighted `NormL1Nonneg(lambda)` it is the same call, in exact arithmetic
`max(c - gamma*lambda, 0)` with `gamma = inv(s*a)`. A start with a negative entry is refused
before any write ([IN-07](@ref)); momentum extrapolation can leave a negative intermediate
value, which the visit of that coordinate in the same pass projects, so the point returned
after a completed pass is nonnegative. `converged` is the change test of [CD-03](@ref) and
[RES-01](@ref), not a certificate of the constrained KKT conditions: the tests judge a solve by an
independently computed constrained KKT score and objective. The cached residual behind the
reported minimum is specified in [CD-05](@ref) and [CD-09](@ref), and the canonical input and
feasibility rule is [IN-07](@ref).

Ridge uses the same cached residual, pass schedule, optional momentum, stopping
scales and owner transaction as the other scalar least-squares penalties.
The ridge term does not replace the loss-column curvature in the change scale.
At a flat column, the chosen penalty minimizer is zero even for `lambda = 0`,
where the minimizer is nonunique. Nonflat zero/overflowed curvature and the
exceptional step band remain subject to [CD-04](@ref).

**Applies to.** `CDSolver`; vector response; dense `Vector{T}` or one-dimensional `SparseIterate{T}`; `T` is `Float32` or `Float64`.

**Code.** `src/cd/leastsquares.jl`: `coordinate_step!`, `_sqnorm!`; `src/cd/models.jl`: `_coordinate_minimizer`; `src/solve.jl`: input validation.

**Tests.** `test/cd_numerics.jl`, `test/cd_elasticnet.jl` (flat columns and range refusals), `test/weighted_lasso.jl`; `test/cd_nonnegative.jl` ("closed forms", "single coordinates", "correlated and p > n designs against a BigFloat reference and PGD", "flat columns", "orders") for the nonnegative penalties. The ridge testset "uncentered SqrNormL2 with normalized least squares" covers Float32/Float64 dense and warm-owner solves on ordinary, wide, correlated and flat-column designs, zero level, and a Float64 scale/level with Float32 data. It checks independent 256-bit normal-equation references, agreement within precision-based bounds with `ElasticNet(0, lambda)`, coefficient/objective agreement, result fields and flat-column zeros. `examples/problems/elastic_net.jl` also compares the normalized ridge solve with the normal-equation ridge reference.

**Sources.** `docs/src/choosing-solver.md:L83`, `docs/src/numerics.md:L9`, `docstring:src/cd/solver.jl:L6`, `README.md:L79`, `docs/src/support.md:L107`. The later ridge addition is [upstream #420 at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/commit/217cde72cad2b324e174012accc949da59c1bba5), with [coordinate and range methods](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/cd/leastsquares.jl#L77-L166), [flat-column minimization](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/cd/models.jl#L26-L34), and [ridge tests](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/test/cd_elasticnet.jl#L378-L441). These sources extend the frozen baseline support.

## [CD-02 Order, active passes and momentum](@id CD-02)

**Statement.**

`CDSolver()` uses `order = :random` and the historical default momentum behavior.
Random order borrows the supplied RNG, which advances when used; `rng = Xoshiro(seed)`
makes the random schedule repeatable. `order = :cyclic` supports `momentum = nothing`
or `false`, and rejects `momentum = true`. The deterministic tutorial configuration is
`CDSolver(order = :cyclic, momentum = false)`.

A full pass visits all coordinates and admits new active coordinates. Active passes
refine the active coordinates. With default stopping, only a full pass whose largest
change is strictly below the effective tolerance can converge. The explicit route uses
the same pass schedule and applies [CD-10](@ref) for stopping. Once the active passes since the last full pass
have together visited 20 times as many coordinates as a full pass, the next pass is full,
even if the active changes are still above the threshold. Random least-squares momentum
can extrapolate active passes and restart when the active set changes; residual refresh
is specified in [CD-05](@ref).

Every pass compacts zero coordinates from the private iterate, moving the last active
coordinate into the slot of a removed coordinate; the resulting order is not sorted.
Dense and owner solves from the same canonical state run the same arithmetic and RNG
schedule. A different slot order of the same active set can change the trajectory and
the final point. [CDS-02](@ref) specifies preservation of a caller's initial owner state.

`anderson = 0`, `gaptol = 0` and `gapsafe = false` are compatibility defaults only:
these features are not implemented or stored, and nondefault values are refused.

**Applies to.** Scalar least-squares `CDSolver`; square-root lasso uses this schedule with its additional certificate.

**Code.** `src/cd/solver.jl`: `_run_cd!`, `_pass!`; `src/cd/models.jl`: private state and active ordering.

**Tests.** `test/cd_numerics.jl` (forced full passes and cache refresh), `test/sparse_cd.jl` (state/order agreement).

**Sources.** `docs/src/numerics.md:L9`, `docs/src/developer/implementation-notes.md:L260`, `docstring:src/cd/solver.jl:L33`, `docstring:src/cd/solver.jl:L40`, `docstring:src/cd/solver.jl:L69`.

## [CD-03 Change test and its scale](@id CD-03)

**Statement.**

`tol` defaults to `1e-7`. It bounds the largest computed change in a full pass, not an
independent optimality residual. With `relative = true` and `y != 0`, the effective
threshold is `tol` times the response scale `sqrt(s * sum(abs2, y))`; the reported
`tolerance` can therefore differ from the constructor value. The sum of squares and its
product with `s` need not stay in the range of `T`: wider or exponent-separated
arithmetic forms the scale where needed. The computed `sqrt(s) * norm(y)`, rounded to
`T`, must be a normal number; otherwise an `ArgumentError` occurs before the first pass
and the starting point is unchanged. A value within a rounding error of a range
boundary can fall on either side. Rescale the data/loss or use `relative = false`;
an overflowing final objective remains a refusal (`nonfinite objective`) with either setting.

`relative = false`, or `y = 0`, uses the absolute threshold `tol` and no coordinate
scale. Otherwise a coordinate displacement is multiplied by `sqrt(s * a)`, where `a`
is its column's squared norm. Where `s * a` is zero, subnormal or overflowing for a
finite `a`, the two square roots are formed separately and multiplied. The computed
scale is still zero when the root is at most half the smallest subnormal number, and
infinite when the rounded scale overflows `T`. A nonzero displacement multiplied by an
infinite scale raises `ArgumentError` with `a coordinate step or its stopping scale is
not finite`; the caller's iterate is unchanged.

Multiplying `tol` by a normal response scale can produce a subnormal threshold or zero.
`change < threshold` cannot hold for a zero threshold, including `tol = 0`. With
default stopping the run ends at `maxpasses` with a warning unless a numerical
failure raises an error. Explicit stopping uses the threshold for scheduling under [CD-10](@ref).
Float32 rounding can keep every full pass's largest scaled change at or above the
threshold, also ending at `maxpasses`. A tolerance above that rounding level avoids
this particular stall; Float64 has a much lower rounding level. No bound on the KKT
residual or distance to a minimizer follows from the convergence flag.

This same change test applies to uncentered `SqrNormL2` ridge. The coordinate
scale remains `sqrt(s*a)` with the loss-column squared norm `a`, without adding
the ridge level. A reported convergence therefore supplies no independent ridge
stationarity or objective-gap certificate. [RES-01](@ref) specifies the unchanged
`passes`, `kkt_checks = 0` and `gap = NaN` interpretation for this addition.

**Applies to.** Scalar least-squares `CDSolver`; the specialized group and square-root clauses define their visit changes.

**Code.** `src/cd/leastsquares.jl`: `response_scale`, `_response_scale_exceptional`; `src/cd/solver.jl`: stopping comparisons.

**Tests.** `test/cd_numerics.jl` (response/coordinate scales, zero response, range boundaries); `test/stopping_scale.jl`.

**Sources.** `docs/src/choosing-solver.md:L51`, `docs/src/choosing-solver.md:L69`, `docs/src/numerics.md:L9`, `docstring:src/cd/solver.jl:L40`, `docstring:src/cd/solver.jl:L69`, `docstring:src/solvers/proximal_gradient_descent.jl:L343`. Ridge uses the same rule in [the upstream CDSolver guidance at 217cde72](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/cd/solver.jl#L36-L66) and [ProximalOptions clarification](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/types.jl#L55-L60).

## [CD-04 Range-safe scalar step and positive-ridge refusal](@id CD-04)

**Statement.**

The threshold arithmetic below applies to lasso and weighted lasso, to an
elastic net with zero ridge level, and, with the nonnegative forms stated further below,
to unweighted `NormL1Nonneg`. For an uncentered `SqrNormL2`, the ordinary
step remains ProximalBase's ridge prox in [CD-01](@ref). At a finite positive
column squared norm `a`, when `p = s*a` or its reciprocal falls below
`floatmin(S)`, `SqrNormL2(0)` takes the unpenalized center `c`, while a positive
ridge level is refused with `ArgumentError` naming the coordinate and explaining
that `SqrNormL2 with lambda > 0 has no range-safe step there`. This exceptional
method is defined for `S == T`; the existing wider-scale qualification below
still applies. The refusal occurs during a pass, before that coordinate and
residual are changed; the public caller remains unchanged even if an earlier
coordinate in the private pass moved. A borrowed RNG may already have advanced.

For the lasso (and, with the changes stated below, the weighted lasso and the elastic net
at zero ridge level), the coordinate step is the soft threshold of the centre `c = x_k + b / a` at
`τ = λ / (s * a)`, with `b` the inner product of the residual and the column. The formula
below and the statement that an infinite or NaN `c` stays nonfinite are specific to this signed
soft threshold; for the nonnegative penalties the latter holds for `+Inf` and NaN only. The
wider-scale and curvature rules below apply to the penalties with an exceptional method.
Form `p = s * a` and `γ = inv(p)` in `S`. If both are at least
`floatmin(S)`, use `prox_block(g, c, k, γ)`. For weighted `ElasticNet`,
`g` is the working penalty in [IN-03](@ref). Otherwise `_exceptional_step`
applies `shrink(c, min(τ,
floatmax(T)))`, with `τ` formed from `g.λ0` converted to `Float64` and from `s`
and `a` without `p` or `γ`: for `Float32` in `Float64`, where the product of two
`Float32` values is exact and the quotient is rounded to `Float64` and then to
`Float32` (the double rounding keeps it within one `Float32` ulp of the quotient
where that is below `floatmax`, not always the correctly rounded value), and for
`Float64` from significands and exponents (`_threshold`), with a relative error
below `3 * eps(Float64)` where `τ` is normal. For `τ` in
`[0, floatmax(T)]`, `shrink(c, τ)` is what PB's `NormL1` prox returns at the
level `τ` and the step 1. The cap at `floatmax(T)` leaves a finite `c` at 0, as
an infinite `τ` does, and keeps a `c` that is infinite or NaN non-finite, so
that `_visit!` refuses it; an infinite level in PB's prox would set that entry
to 0. In exact arithmetic a fixed point of `x = shrink(x + b / a′, λ / (s a′))`
satisfies `s b ∈ λ ∂|x|` for any positive `a′` used in both places, so a
curvature that is rounded or subnormal does not move the fixed point (whether
and how fast the iteration reaches it can change). For `λ > 0` the coefficient `γ` of the previous step was
0 where `p` overflows (the penalty was ignored) and infinite where `p` is below
`1 / floatmax(S)` (the threshold was infinite, which sets a finite centre to 0),
which broke that agreement; for `λ = 0` PB's prox keeps a zero threshold for any
`γ`. Where `p` or `γ` is below
`floatmin(S)` the step is the exceptional one, also for cases that were correct
before (a subnormal `p` with a finite reciprocal), and where `λ > 0` their bits
can differ from before.
`_exceptional_step` is written for `S == T`, for a `NormL1` whose weights are absent or a `Vector{T}`, and for an
`ElasticNet` whose weights are absent or a `Vector{T}` (at `λ2 = 0` the step of `NormL1(λ1)`, or with weights the weighted
`NormL1` step below at the level `λ1`; at `λ2 > 0`, a positive subnormal `λ2` included, it throws an `ArgumentError`, see
`CDSolver`). A weighted `ElasticNet` reaches it as the working penalty of [IN-03](@ref), whose levels are in `T`, and shares the
primitive that forms `cₖ` with the weighted `NormL1` method, which reads `wₖ` and not the whole weight vector. With
weights the `NormL1` method forms `cₖ = T(λ0) wₖ` in `T`, the coefficient that `solve!` has checked (finite and, where
`T(λ0)` and `wₖ` are both positive, a normal number of `T`), and calls the unweighted method at the level `cₖ`: `τ` is within
the bounds above of `cₖ / (s a)`, and within those bounds plus `|cₖ - λ0 wₖ| / (s a)` of `λ0 wₖ / (s a)`
(`cₖ` is 0 or a normal number of `T`, which `solve!` checks. `|cₖ - λ0 wₖ|` is at most `|T(λ0) - λ0| wₖ`, the conversion of the level (0
for a level of type `T`), plus the rounding of the product to nearest, at most `(eps(T)/2) cₖ`, also where the exact product is slightly below
`floatmin(T)` and rounds up to it. For a level converted by round-to-nearest (a `Float16`, `Float32`, `Float64` or `BigFloat`, or an
integer) `|T(λ0) - λ0| ≤ (eps(T)/2) T(λ0)`; a `Rational` level can have a larger conversion error, because Julia's
conversion of a `Rational` can round the numerator and the denominator before dividing, so only the actual error bounds it). A zero weight or level gives `τ = 0` and
`shrink(c, 0) = c`. Inside the band the step is PB's weighted `prox_block`, whose threshold is `γ λ0 wₖ` formed
in its own working type from `λ0` and `wₖ`, not from the rounded `cₖ` (for a level of type `T` the two are the same product up to rounding;
for another type they can differ by the conversion error above); the weighted step has no exponent-separated threshold of its own. A column of `X` that
is zero takes `_coordinate_minimizer`, PB's `prox_block(g, 0, k, floatmax(T))`, which is 0 for a weighted `NormL1`
or `ElasticNet` also at a zero weight, and with both levels zero. For a
finite `a`, an `S` wider than `T` keeps `p` inside the band: `solve!` requires a
loss scale that is representable in `T`, and `a` is finite in `T`, so
for `Float32` data with a `Float64` scale `p` is between about `1e-90` and
`1e77`. A scale of another type, or
a penalty without a method of `_exceptional_step` (an unweighted `NormL1Nonneg` or `IndNonnegative`, or a `NormL1` or `ElasticNet` with no weights or a `Vector{T}` of weights, has one), makes
the step throw an `ArgumentError`. A column whose `a` is not finite in `T` makes `coordinate_step!`
throw an `ArgumentError` that names the curvature, before the coordinate, the
residual or the curvature cache entry of that column changes, and `x` and an
owner are not changed.

For `S == T`, the exceptional methods for the nonnegative penalties are `max(c, 0)` for
`IndNonnegative()` and `max(c - min(τ, floatmax(T)), 0)` for an unweighted `NormL1Nonneg`,
where `τ` is formed exactly as for the lasso: from `Float64(g.λ0)`, the level converted to
`Float64`, and from `s` and `a`, so the bounds above hold against that converted level, as for
`NormL1`. The preconditions are those of `solve!`: the admitted level of [IN-07](@ref), a positive
finite `s` and a positive finite `a`. A finite `c` gives a finite nonnegative result, `+0` where the difference
is not positive. A `c` of `+Inf` stays `+Inf` and a NaN `c` stays NaN, which `_visit!` refuses;
a `c` of `-Inf` gives `+0`, unlike the signed soft threshold. At `λ = 0` the result is `max(c, 0)`.

The exceptional methods also include `SqrNormL2{<:Real, Nothing}` with the
zero-level and positive-level behavior above. A nonflat column whose squared
norm underflows to zero, or a column whose squared norm is nonfinite, is still
refused before the coordinate/residual/cache-entry writes; a positive ridge
level does not bypass those curvature gates. A genuinely flat column uses the
zero minimizer of [CD-01](@ref), including at zero ridge level.

**Applies to.** Lasso, weighted lasso, elastic net with or without weights, uncentered `SqrNormL2` ridge and, on a dense `Vector`, `IndNonnegative()` and unweighted `NormL1Nonneg` on scalar CD iterates.

**Code.** `src/cd/leastsquares.jl`: `_threshold`, `_exceptional_step`, `coordinate_step!`, `_sqnorm!`.

**Tests.** `test/cd_nonnegative.jl` ("the exceptional steps of IndNonnegative and NormL1Nonneg against BigFloat": BigFloat references `max(c - λ/(s a), 0)` at levels of type `T` (so the conversion to `Float64` is exact), with the bound on `τ` stated above and, where the quotient reaches `floatmax(T)`, a capped threshold within four floats below `floatmax(T)`, and the nonfinite centres; "one coordinate step with s a outside the band through solve!": an overflowing and a subnormal `s*a`). `test/cd_numerics.jl` (normal-band equivalence, threshold range and positive-ridge refusal for an overflowing scale-curvature product); `test/cd_elasticnet.jl` (off-band refusals and rollback), including "SqrNormL2 validation and exceptional coordinate steps": positive subnormal second-column curvature refuses the positive ridge level after the first private coordinate moves, preserving dense/owner entry state; zero level reaches the unpenalized solution, and a flat column is zeroed; `test/weighted_lasso.jl`; `test/weighted_elasticnet.jl` (the exceptional band of a weighted `ElasticNet`: a coefficient of `floatmin(T)` at a loss scale `floatmin(T)/4` gives threshold 4, a zero weight gives none, the smallest positive subnormal ridge level triggers refusal with the input preserved. Separate tests cover an overflowing scale-curvature product at zero ridge and rollback at ridge level 1 after a private update of the first coordinate).

**Sources.** `docs/src/choosing-solver.md:L83`, `docs/src/numerics.md:L9`, `docs/src/developer/implementation-notes.md:L7`, `docstring:src/cd/solver.jl:L6`, `README.md:L79`, `docs/src/support.md:L107`. The additional ridge method and its limits are [217cde72, `_exceptional_step`](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/src/cd/leastsquares.jl#L157-L166) and [the updated numerical guidance](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/docs/src/numerics.md#L18-L38).

## [CD-05 Cached-residual limitation](@id CD-05)

**Statement.**

The example is one form of a wider limit. For a least-squares loss, CD keeps the residual
`r = y − Xx` in a cache. `solve!` computes the cache from the start in working precision, and each
coordinate or group step then subtracts its own change from it. The steps read the cache, and the
change test reads the steps. In a solve without momentum, which includes every group-lasso solve,
the cache is not computed again from the coefficients. With momentum (the default for a vector
iterate with the random order) it is computed again before a full pass when an extrapolation has
moved it since it was last computed; the first pass of a solve is a full pass, and no such
computation precedes it.

The intermediate sums of `y − Σ X_k x_k` can be much larger than the residual itself, and their
rounding can then lose `y`; this happens where column images `X_k x_k` of the start are much larger
than `y`. In exact arithmetic a step changes the cache and `y − Xx` by the same amount, so an
error `e` of the cache is not removed by the steps that follow: until the cache is computed again,
the passes are those of the problem with the response `y + e`, and the change test can be met at a point that is not near a minimizer
of the problem that was posed. For `CDSolver` with a least-squares loss, `converged = true` reports
the change test as computed from the cached residual. It is not a certificate of stationarity, and
it does not say that the cache is close to `y − Xx` at the returned point.

The [cached-residual investigation](evidence/cached-residual-378.md) records the tested
starts, measured false stops, rejected remedies and practical guidance. Those
measurements do not give a generally safe warm-start size.

**Applies to.** Least-squares CD with scalar or group penalties; working-precision cached residuals.

**Code.** `src/cd/leastsquares.jl`: `_initialize!`, `coordinate_step!`; `src/cd/solver.jl`: momentum and full-pass refresh.

**Tests.** `test/cd_numerics.jl` (forced full-pass refresh), `test/sparse_cd.jl`; the historical campaign is linked from the evidence page.

**Sources.** `docs/src/stopping-limits.md:L209`, `docs/src/stopping-limits.md:L211`, `docs/src/stopping-limits.md:L220`, `docs/src/developer/implementation-notes.md:L260`.

## [CD-06 Exact-arithmetic interpretation of the change test](@id CD-06)

**Statement.**

Assume exact arithmetic, a full pass without extrapolation, exact minimization at each
scalar visit, and relative scaling (`relative = true`, `y ≠ 0`), so that the threshold is
`τ = tol √s ‖y‖` with `s` the loss scale. Let `X_k` be column `k` of `X`, `p` the number of
columns, `h_j` the change of coordinate `j` in the stopping pass, and `G_k` the minimal-norm
KKT residual of coordinate `k` at the end of the pass. Coordinate `k` is at its minimizer when it is
visited, and only the updates of the coordinates visited after it move its gradient, so

~~~
|G_k| ≤ s ‖X_k‖ Σ_{j visited after k} ‖X_j‖ |h_j| ≤ (p − 1) · tol · s ‖X_k‖ ‖y‖     (lasso and elastic net)
‖G_k‖ ≤ K · tol · s √ℓ_k ‖y‖                                                          (group lasso, K groups)
~~~

with `ℓ_k` the curvature bound of group `k`. The elastic net adds no cross term. The first
inequality holds for any visiting order. Momentum does not enter, because the stopping pass has
no extrapolation. For the group lasso the visit is a majorization step with
`0 ⪯ X_kᵀX_k ⪯ ℓ_k I`, not a block minimization: the residual of group `k` after its own step is
at most `√(s ℓ_k) τ`, and each group visited after it adds at most the same, which gives the
factor `K`.

With the absolute threshold (`relative = false`, or `y = 0`) the scale `‖y‖` drops out:

~~~
|G_k| ≤ s · tol · ‖X_k‖ Σ_{j visited after k} ‖X_j‖
‖G_k‖ ≤ s · tol · (ℓ_k + √ℓ_k Σ_{j visited after k} √ℓ_j)                            (group lasso)
~~~

The scalar bounds are not strict: both sides are 0 for `p = 1` and for a flat column. What remains
unguaranteed, and why the flag is not a KKT certificate:

The factors `p - 1` and `K`, the use of the scale `s ‖X_k‖ ‖y‖` instead of `λmax`,
rounding and range all limit the interpretation. The scale ratio can be unbounded
under cancellation. [Working-precision limits](@ref FP-01), the
[warm-start example](@ref CD-07), and the [stopping audit](evidence/stopping-audit-352.md)
give the corresponding examples and measurements. These bounds are not suboptimality
guarantees and the repository's benchmark accuracy target is not a convergence contract.

**Applies to.** The assumptions stated above; scalar lasso/elastic net and the stated group-majorization interpretation.

**Code.** `src/cd/leastsquares.jl`: scalar and group `coordinate_step!`; `src/cd/solver.jl`: full-pass change test.

**Tests.** `test/cd_numerics.jl`, `test/group_cd.jl` (first-pass stopping statistic and independently checked solutions). This is a preserved derivation, not a behavior change.

**Sources.** `docs/src/stopping-limits.md:L42`, `docs/src/stopping-limits.md:L44`, `docs/src/stopping-limits.md:L51`, `docs/src/stopping-limits.md:L56`, `docs/src/stopping-limits.md:L63`, `docs/src/stopping-limits.md:L65`, `docs/src/stopping-limits.md:L70`, `docs/src/stopping-limits.md:L73`, `docs/src/stopping-limits.md:L74`, `docs/src/stopping-limits.md:L76`, `docs/src/stopping-limits.md:L77`.

## [CD-07 A warm start far above the solution scale](@id CD-07)

**Statement.**

The start of `solve!` can place coefficients far above the scale of the solution. With
`X = ones(1, 2)`, `y = [1/64]`, `λ = 1/1024` and the start `[2.0^49, -2.0^49]`
(Float32: `2f0^20`):

```julia
using ProximalBase, ProximalSolvers

for (T, M) in ((Float64, 2.0^49), (Float32, 2f0^20))
  X = ones(T, 1, 2)
  y = T[1 / 64]
  λ = T(1 / 1024)
  start = T[M, -M]
  for solver in (CDSolver(order = :cyclic, momentum = false),
                 ProximalGradientDescent(), AccProxGradDescent())
    x = copy(start)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ), solver)
    println(T, " ", nameof(typeof(solver)), ": x == start is ", x == start,
            ", converged = ", r.converged)
  end
end
```

CD returns the start with `converged = true` after one pass. The exact KKT residual is 1.06 of
`max(λ, λmax)`, and `(F − F*)/F*` is `7.4e16` (`1.4e8` in Float32). PGD and APG also return the
start, at `maxiter` with `converged = false`. The mechanism for this example: the
residual is initialized as `y − Σ X_k x_k` in working precision, which loses `y` against the
coefficients `M`; each coordinate step is then smaller than half a unit in the last place of the
coefficient, so the new value equals the old one; and a full pass with no change satisfies `0 < tol`.

The [stopping audit](evidence/stopping-audit-352.md) records related rank-deficient
designs, and [CD-05](@ref) explains the wider cached-residual limitation. Evaluate
optimality independently from the returned coefficients; the change flag alone does
not detect this example.

**Applies to.** The supplied Float64 and Float32 example; no general safe-start bound is claimed.

**Code.** `src/cd/leastsquares.jl`: residual initialization and coordinate steps; `src/cd/solver.jl`: full-pass stop.

**Tests.** The preserved example above is a documented limitation. Existing numerical fixtures are unchanged.

**Sources.** `docs/src/stopping-limits.md:L170`, `docs/src/stopping-limits.md:L172`, `docs/src/stopping-limits.md:L176`, `docs/src/stopping-limits.md:L194`.


## [CD-08 Detailed stopping-scale arithmetic](@id CD-08)

**Statement.**

Let `S` be the stored loss-scale type described in [IN-01](@ref).
The following branch rules supplement the meaning of the change test in [CD-03](@ref).

The response
scale `sqrt(s * sum(abs2, y))` is formed in one of three ways, with the sum
in `T`. Let it be clean if it is finite and at least `4 length(y) floatmin(T)`
(the bound of `_se_norm_onepass`), `p = s * sum(abs2, y)` in `S` and
`q = T(p)`. If the sum is clean and `q` is a normal number of `T`, the scale
is `sqrt(q)`. Else, if `S` is wider than `T`, the sum is clean, `p` is a
normal number of `S` and `T(sqrt(p))` is a normal number of `T`, the scale is
`T(sqrt(p))`. Otherwise the scale is `sqrt(s) * norm(y)` carried as exponent
and significand with the helpers of `src/solvers/image_models.jl` (`_SE`,
`_root_scale`, `_se_norm`), in `Float64` for `Float32` data and in `T`
otherwise, rounded once to `T`. The sums of squares of that last form are
`@simd`, so its value can differ in the last bits between CPUs. For `y = 0`
that value is 0, which selects the absolute stopping threshold. If the
rounded value is not a normal number of `T`, `response_scale` throws an
`ArgumentError` from `_run_cd!`, before momentum or any shuffle, so that `x`,
an owner and the RNG are unchanged; a value within a rounding error of
`floatmin(T)` or `floatmax(T)` can fall on either side. `relative=false` is
the alternative, and it can still end in the nonfinite-objective refusal below.
The threshold `tol * scale` is formed in `T` and can still be subnormal or 0.
The test `change < threshold` cannot hold for a threshold of 0, so that run
cannot converge by it and reaches `maxpasses`, unless an independent
numerical failure (for example a non-finite coordinate step) stops it first.

`_root_scale`
rounds the scale once to `Float64` (exact for a `Float32` or `Float64` scale, for a `Bool`
and for an integer of magnitude at most `2^53`; a larger integer is rounded once) and
takes its significand and exponent there; a scale outside the range of `Float64` is not
supported by `_root_scale`.

The coordinate scale, with `a` the squared norm of the column, `p = s * a`
in `S` and `q = T(p)`, is `sqrt(q)` where `q` is a normal number of `T`;
otherwise `T(sqrt(p))` where `p` is not below `floatmin(S)` and is finite or `a`
is infinite; otherwise (`p` zero or subnormal in `S`, or infinite for a finite
`a`) `T(sqrt(s) * sqrt(S(a)))`, formed in `S` from the two roots, so the
rounded product `p` does not enter it. That last form is 0 for `a = 0` and 0
where its value is at most half of `nextfloat(zero(T))`, and its rounding to `T`
is infinite where the value overflows. For `S == T` the first two forms have the
same value where `p` is normal. The second form is infinite where `a` is infinite
and where `S` is wider than `T` and the rounded root of `p` overflows `T`. Where
`scaled` holds in `_tolerances` (`relative=true` and a positive response scale),
`_visit!` multiplies a nonzero change by the coordinate scale and refuses an
infinite product with `ArgumentError("a coordinate step or its stopping scale
is not finite")`, and `x` and an owner are not changed (the solve works on a
private copy). With `relative=false` or `y = 0` the coordinate
scale is not used.

`X`, `y`, the residual, the
curvature cache and the iterate stay in `T`. A scale of type `T`, a
`Float32` scale on `Float64` data, or a fixed-width integer or `Bool` scale
(accepted only where `T` represents it exactly) gives `S = T` and the arithmetic
of `T` in CD's step and stopping computations; a `Float64` scale on `Float32`
data gives `S = Float64`. `S` does not describe the reported objective's
product, which ProximalBase forms (see above). This accepted
wider-scalar behavior is a narrow compatibility exception, not a generic
mixed-precision guarantee.

**Applies to.** The scalar least-squares CD model and the shared stopping-scale helpers.

**Code.** `src/cd/leastsquares.jl`: `response_scale`, `_response_scale_exceptional`, coordinate scaling; `src/solvers/image_models.jl`: `_SE`, `_root_scale`, `_se_norm`, `_se_norm_onepass`.

**Tests.** `test/cd_numerics.jl`: response/coordinate scales over their ranges, native and wider scalar cases, boundary refusals and zero response.

**Sources.** `docs/src/choosing-solver.md:L51`, `docs/src/choosing-solver.md:L69`, `docs/src/numerics.md:L9`, `docs/src/developer/implementation-notes.md:L7`.

## [CD-09 Objective from the cached residual](@id CD-09)

**Statement.**

The loss part of the reported objective is
`ProximalBase.value_from_residual(f, r)` of the cached residual, with the
original loss `f` passed to `loss_value`. `LSModel` stores the residual. Default
scalar least-squares CD evaluates the objective once at return. [CD-10](@ref)
specifies the explicit cadence. ProximalBase forms the sum of squares and its product
with the scale, and recomputes exceptional values under the conditions that its
guide states ("Least squares at a predictor or residual that the caller holds",
"Value and rounding"). The
finished solve is refused with a nonfinite-objective error where the loss plus
the penalty, in `_run_cd!`, is not finite; the loss itself can be `Inf` near the
overflow threshold, where the guide does not decide between a finite value and
`Inf`. Where the value is below `floatmin(T)` the guide's bound for the loss is
`(n + 8) eps(T) |v|` plus `2 nextfloat(zero(T))` (`v` the exact value at the
cached residual), so the loss part of the reported minimum can be 0. For an
integer or `Bool` scale ProximalBase converts the scale to `Float64` and forms
the product in the promoted type of that scale and `T` before rounding to `T`,
while CD's step and stopping arithmetic uses `T(s)`. For an integer or `Bool`
scale the check in `src/solve.jl` makes the two real scales equal; the arithmetic
precision can differ (Float32 data and the scale `3`: `Float32` in CD, `Float64`
in the objective's product), and for `Float64` data both are `Float64`.

**Applies to.** Least-squares CD result construction, including accepted integer and Bool loss scales.

**Code.** `src/cd/leastsquares.jl`: `loss_value`; `src/cd/solver.jl`: `_run_cd!`; ProximalBase `value_from_residual`.

**Tests.** `test/cd_numerics.jl`: oracle residual values, reported objective boundaries, underflow and nonfinite-objective refusals.

**Sources.** `docs/src/developer/implementation-notes.md:L7`.

## [CD-10 Explicit stopping after completed coordinate passes](@id CD-10)

**Statement.** Pass `stopping=rule`, `limits=MaxPasses(n)`, or both to
`solve!` with `CDSolver`. A limit alone selects a pass-budget solve. A rule
without a limit uses `CDSolver.maxpasses`. If a supplied limit disagrees with
`maxpasses`, the limit can override the default value of `maxpasses` (100,000).
A nondefault disagreement is refused. Omitting both keywords uses default stopping.

Validate the problem through [CD-01](@ref), the momentum setting, the resolved
limit and the complete rule tree before initialization. Supported leaves are
`ObjectiveChange` and `UserStop`, including trees composed with `AnyOf` and
`AllOf`. Limits are supplied through `limits`. `MaxPasses(0)` returns the starting
coefficients with a missing objective and zero work counts after validation.

On a positive budget, run the plain CD pass schedule in [CD-02](@ref). The
change test in [CD-03](@ref) selects the next pass. An explicit rule and the
pass limit decide when the run ends. The budget counts each completed full or
active pass once, including an empty active pass. Coordinate visits count the
candidate coordinates at the start of the sweep, before compaction.

With a rule, evaluate the composite objective at initialization and after each
completed pass from the cached residual and the penalty in [CD-09](@ref).
The two adjacent computed values and their arithmetic are those of
`ObjectiveChange` in [STOP-22](@ref). The initial observation has no predecessor.
Evaluate `UserStop` with `(; iteration, objective)` under the predicate rules
of [STOP-22](@ref), with `iteration` the number of completed passes. Both leaves
share each checkpoint's objective. Composition uses the same ordered short
circuiting as [STOP-22](@ref). At the cap the required final objective and its
predecessor can settle an objective tie. `UserStop` is unchecked at the cap.
A positive limit-only solve evaluates the objective once at return.

An active sweep can leave the objective unchanged while an omitted coordinate
still violates the full problem's KKT conditions. `ObjectiveChange` supplies
progress evidence at its two endpoints. [RES-05](@ref) specifies how that
evidence appears in the result.

A required nonfinite objective raises an error. A numerical or predicate
exception can escape before a completed result and before the private iterate
is copied back to the caller, as in [RES-03](@ref). [RES-05](@ref) specifies the
explicit result.

**Applies to.** `CDSolver`, dense `Vector{Float32}` or `Vector{Float64}` with
matching dense vector-response least squares, unweighted `NormL1`, and momentum
off. A raw loss or a supported positive scale is accepted. Both coordinate
orders are supported with `momentum=false`. Cyclic order also accepts the
default `momentum=nothing`.

**Code.** `src/cd/solver.jl` and `src/stopping.jl`.

**Tests.** `test/cd_stopping.jl` checks analytic full and active passes, including
an unchanged active pass with an inactive-coordinate KKT violation. It also
checks zero visits, composition, counts, preflight, rollback and default
trajectory agreement with a fixed budget and matched RNG state.

**Sources.** [#523, solver rollout B3](https://github.com/mlakolar/ProximalSolvers.jl/issues/523)
and [the shared stopping design](https://github.com/mlakolar/ProximalSolvers.jl/issues/525#issuecomment-7072155495).
