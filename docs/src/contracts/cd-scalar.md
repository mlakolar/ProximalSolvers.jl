# Scalar coordinate descent

These clauses cover least-squares lasso, weighted lasso and unweighted elastic net.
Read the [input rules](@ref IN-01), [working precision](@ref FP-01), and
[result and failure rules](@ref RES-01) with them. Specialized storage and losses have
their own clauses: [SparseIterate](@ref CDS-01), [groups](@ref CDG-01),
[matrix responses](@ref CDM-01), and [square-root lasso](@ref CDQ-01).

## [CD-01 Problem and scalar coordinate update](@id CD-01)

**Statement.**

For a loss scale `s`, the objective is `(s/2) * sum(abs2, y - X*beta) + g(beta)`.
`CDSolver` accepts matching `Float32` or `Float64` dense design/response data and
coefficients in a dense `Vector` or a one-dimensional `SparseIterate`. The penalty is
`NormL1(lambda)`, `NormL1(lambda, w)` or an unweighted `ElasticNet(lambda1, lambda2)`.
The weights of `NormL1` are a `Vector{T}` of finite nonnegative entries. Input validation
checks `T(lambda)` and the rounded coefficient `T(lambda) * w[k]` to be zero or normal
numbers of `T`; a zero weight leaves its coordinate unpenalized.

For a finite positive column squared norm `a`, the step soft-thresholds the unpenalized
coordinate minimizer at `lambda / (s * a)` in the lasso case. In the normal step band,
ProximalBase's `prox_block` forms the threshold from the supplied level and weight in its
working type, so its threshold need not equal one formed from the already-rounded checked
coefficient. The [range rule](@ref CD-04) specifies the exceptional band and the
elastic-net refusal. At every visit a flat column (all entries zero) sets its scalar
coordinate to zero for these accepted penalties, including a zero level or weight.
A nonflat column whose squared norm underflows to zero is refused. With `maxpasses = 0`
no coordinate is visited.

**Applies to.** `CDSolver`; vector response; dense `Vector{T}` or one-dimensional `SparseIterate{T}`; `T` is `Float32` or `Float64`.

**Code.** `src/cd/leastsquares.jl`: `coordinate_step!`, `_sqnorm!`; `src/solve.jl`: input validation.

**Tests.** `test/cd_numerics.jl`, `test/cd_elasticnet.jl` (flat columns and range refusals), `test/weighted_lasso.jl`.

**Sources.** `docs/src/choosing-solver.md:L83`, `docs/src/numerics.md:L9`, `docstring:src/cd/solver.jl:L6`, `README.md:L79`, `docs/src/support.md:L107`.

## [CD-02 Order, active passes and momentum](@id CD-02)

**Statement.**

`CDSolver()` uses `order = :random` and the historical default momentum behavior.
Random order borrows the supplied RNG, which advances when used; `rng = Xoshiro(seed)`
makes the random schedule repeatable. `order = :cyclic` supports `momentum = nothing`
or `false`, and rejects `momentum = true`. The deterministic tutorial configuration is
`CDSolver(order = :cyclic, momentum = false)`.

A full pass visits all coordinates and admits new active coordinates. Active passes
refine the active coordinates. Only a full pass whose largest change is strictly below
the effective tolerance can converge. Once the active passes since the last full pass
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
`change < threshold` cannot hold for a zero threshold, including `tol = 0`: the run
ends at `maxpasses` with a warning unless another numerical failure raises an error.
Float32 rounding can keep every full pass's largest scaled change at or above the
threshold, also ending at `maxpasses`. A tolerance above that rounding level avoids
this particular stall; Float64 has a much lower rounding level. No bound on the KKT
residual or distance to a minimizer follows from the convergence flag.

**Applies to.** Scalar least-squares `CDSolver`; the specialized group and square-root clauses define their visit changes.

**Code.** `src/cd/leastsquares.jl`: `response_scale`, `_response_scale_exceptional`; `src/cd/solver.jl`: stopping comparisons.

**Tests.** `test/cd_numerics.jl` (response/coordinate scales, zero response, range boundaries); `test/stopping_scale.jl`.

**Sources.** `docs/src/choosing-solver.md:L51`, `docs/src/choosing-solver.md:L69`, `docs/src/numerics.md:L9`, `docstring:src/cd/solver.jl:L40`, `docstring:src/cd/solver.jl:L69`, `docstring:src/solvers/proximal_gradient_descent.jl:L343`.

## [CD-04 Range-safe scalar step and elastic-net refusal](@id CD-04)

**Statement.**

The coordinate step is the soft threshold of the centre `c = x_k + b / a` at
`τ = λ / (s * a)`, with `b` the inner product of the residual and the column.
With `p = s * a` and `γ = inv(p)` in `S`, it is `prox_block(g, c, k, γ)`, the
step as it was, with the same bits, where `p` and `γ` are both at least
`floatmin(S)`. Otherwise `_exceptional_step` applies `shrink(c, min(τ,
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
unweighted `ElasticNet` (at `λ2 = 0` the step of `NormL1(λ1)`; at `λ2 > 0` it throws an `ArgumentError`, see `CDSolver`). With
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
also at a zero weight. For a
finite `a`, an `S` wider than `T` keeps `p` inside the band: `solve!` requires a
loss scale that is representable in `T`, and `a` is finite in `T`, so
for `Float32` data with a `Float64` scale `p` is between about `1e-90` and
`1e77`. A scale of another type, or
a penalty without a method of `_exceptional_step` (an unweighted `NormL1` or `ElasticNet`, or a `NormL1` with a `Vector{T}` of weights, has one), makes
the step throw an `ArgumentError`. A column whose `a` is not finite in `T` makes `coordinate_step!`
throw an `ArgumentError` that names the curvature, before the coordinate, the
residual or the curvature cache entry of that column changes, and `x` and an
owner are not changed.


**Applies to.** Lasso, weighted lasso and unweighted elastic net on scalar CD iterates.

**Code.** `src/cd/leastsquares.jl`: `_threshold`, `coordinate_step!`, `_sqnorm!`.

**Tests.** `test/cd_numerics.jl` (normal-band equivalence and threshold range); `test/cd_elasticnet.jl` (off-band refusals and rollback); `test/weighted_lasso.jl`.

**Sources.** `docs/src/choosing-solver.md:L83`, `docs/src/numerics.md:L9`, `docs/src/developer/implementation-notes.md:L7`, `docstring:src/cd/solver.jl:L6`, `README.md:L79`, `docs/src/support.md:L107`.

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
original loss `f` passed to `loss_value` from `_run_cd!` (once per solve; `f` is
not stored in `LSModel`). ProximalBase forms the sum of squares and its product
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
