# Implementation notes for maintainers

This page preserves the detailed implementation contracts from before the beginner documentation rewrite. It is for contributors, not a prerequisite for solving a lasso. For the beginner-level description, see [Supported problems](../support.md) and [Numerical behavior](../numerics.md).

## Working precision and numerical boundaries

The supported solve contract is homogeneous `T = Float32` or
`T = Float64` for the design matrix, response and coefficient iterate.
The boundary checks in `src/solve.jl` enforce matching array element
types, finite data and the solver-specific storage restrictions.
`_scalar_parameter` validates a finite penalty level, and a `Float32` or
`Float64` loss scale, by conversion to `T` and refuses overflow or
nonzero-to-zero underflow. `_check_loss_scale` reads the scale of a `Scaled`
loss through `ProximalBase.leastsquares_data` and accepts a `Float32` or
`Float64` scale that passes that check, and a positive `Base.BitInteger` or
`Bool` scale with `T(α) == α`; a scale of any other type, and an integer that
`T` rounds, is an `ArgumentError` before any write (#307). That is a narrowing
of what was accepted before. For an accepted integer scale, the conversions of
`α` that CD, `_lambda_max!` and `_step_curvature` use (`T(α)` or `Float64(α)`)
and the one that ProximalBase's oracles use (`Float64(α)`) all equal `α`. The
check does **not** globally convert the
original function parameters or ensure that all private arithmetic is of type
`T`. After it CD, PGD and APG use the loss scale as supplied,
combined with `T` by Julia's promotion. CD's `LSModel` stores it as
`s::S` with `S = promote_type(T, typeof(α))` if that is a concrete
`AbstractFloat` type and `S = T` otherwise. The coordinate step and the
two stopping scales form their products with `s` in `S`. The loss part of
the reported objective does not use `s` or `S`: ProximalBase forms it from the
original loss (see below). The response
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
in the objective's product), and for `Float64` data both are `Float64`. `_root_scale`
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
`X`, `y`, the residual, the
curvature cache and the iterate stay in `T`. A scale of type `T`, a
`Float32` scale on `Float64` data, or a fixed-width integer or `Bool` scale
(accepted only where `T` represents it exactly) gives `S = T` and the arithmetic
of `T` in CD's step and stopping computations; a `Float64` scale on `Float32`
data gives `S = Float64`. `S` does not describe the reported objective's
product, which ProximalBase forms (see above). This accepted
wider-scalar behavior is a narrow compatibility exception, not a generic
mixed-precision guarantee.

ProximalBase owns the least-squares value in all three solvers and the
coefficient gradient in PGD and APG, with the scale as its computation uses it.
CD, PGD and APG read `Y`, `X` and the stored scale through
`ProximalBase.leastsquares_data`. PGD and APG take the value and the gradient
from `value_from_predictor` and `value_and_gradient_from_predictor!`, and CD
takes its final loss value from `value_from_residual` (which returns a value
only), with the rounding, recovery and bounds that ProximalBase states; the
solvers do not repeat those value and iterate-gradient computations. ProximalSolvers owns the caches (the image `X x`, the CD
residual and curvatures), CD's coordinate correlations and updates, the `λmax`
product of the stationarity check, the step and line searches, APG's certified
bound, the stopping rules and the rollback.
ProximalBase's selective recovery may avoid
intermediate overflow/underflow for representable values, but the
solver adds independent matrix products, state updates, stopping
and numerical-finiteness checks. Do not infer end-to-end recovery
from a successful ProximalBase oracle or promise a finite result for
every finite input.

The solver retains native `Float32`/`Float64` iterates and their
working accuracy. Some option tolerances and reported scalar
residuals are stored as `Float64`. They are diagnostic storage,
not a promotion of solver iterates or an optimality certificate.
`converged=true` retains its algorithm-specific historical meaning;
use independent objective/KKT checks for accuracy, especially with
`Float32`. BigFloat may be used for independent test references,
not as a supported solver working type; a `BigFloat`, `BigInt` or
`Rational{BigInt}` loss scale is refused before any write.

This is a documentation alignment with the homogeneous numerical
policy tracked in
[ProximalBase PR #857](https://github.com/mlakolar/ProximalBase.jl/pull/857).
Failure atomicity is as before; the loss scale types that the
scalar-acceptance check accepts are narrowed as stated above (#307). CD's
coordinate step and stopping arithmetic is as before where the loss scale promotes
to `T`; for a loss scale wider than `T` it uses the scale as supplied (#295). The
loss part of the reported objective is ProximalBase's reduction, which differs
from the former one in `T` (#307).

## support.md (previous detailed notes)


Vector y and Matrix X with the same Float32 or Float64 element type are
supported, with positive consistent dimensions and finite entries. The iterate
is a dense Vector of that type for every solver, and additionally a
one-dimensional `SparseIterate` of that type for [`CDSolver`](@ref) only;
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) refuse every
`SparseIterate`. Use raw PB LS or
one positive finite scalar Scaled LS, and finite nonnegative NormL1 (with optional weights, a `Vector{T}`).
Parameters must be representable; positive values must not round to zero.
Scaling is explicit: raw LS means sum(abs2,y-X*x)/2; divide by n explicitly for
normalized lasso. An accepted loss scale wider than `T` is used as supplied,
combined with `T` by promotion; the penalty level keeps its historical
conversion sites.

X/y are borrowed read-only during solves and must not alias mutable x; for a
`SparseIterate` the check uses the owner's whole backing storage, so even an
owner with no active entries is refused when `parent(activevalues(x))` or a
reshape of it is passed as y or X. Results share x; extended traces copy
x/gradient. Unsupported requests fail before mutation. A CD numerical exception
preserves input x; PGD and APG numerical step exceptions restore their last
accepted point and rethrow. Counters/buffers are not generally transactional. Shape errors are
DimensionMismatch; unsupported combinations/options are informative
ArgumentError.

## CD on a `SparseIterate`

- Only the public active values are checked for finiteness. Every validation
  failure (unsupported owner, element type, shape, active NaN/Inf, data, loss,
  penalty, scalar, option, keyword or alias) happens before the owner is copied
  and before any RNG draw, and leaves the owner untouched.
- The run uses `work = copy(x)`, which keeps the active zeros and the slot order,
  and nothing is rebuilt through a dense vector. Passes, momentum and stopping
  are those of the dense wrapper; the extra storage is O(p).
- A run that completes with a finite objective commits the complete final state
  with a same-shape `copyto!(x, work)` and returns `x` itself as `minimizer`.
  This covers a finite `maxpasses` limit (`converged = false`, with a warning)
  and `maxpasses = 0`, which leaves exactly the entry state, including active
  zeros, signed zeros and order. A normal pass compacts zero coordinates, and
  they are not restored; the order is not sorted.
- A numerical error, such as a nonfinite step, a curvature that underflows or is
  not finite, or a nonfinite final objective, leaves the values, active set, signed zeros and
  order of `x` unchanged. The borrowed RNG may already have advanced; no rollback
  of the RNG is promised. Process termination, out-of-memory conditions and
  concurrent mutation of x, X or y are not covered.
- After a successful call take `activevalues(x)` and `activecoordinates(x)` again:
  the active list may have been replaced or reordered.

## Deferred

Sparse designs, sparse vectors and views as iterates, `SparseIterate` for proximal
gradient descent (plain or accelerated), matrix-shaped owners (other than the `Matrix` coefficient of CD with a matrix response and a row-group `GroupNormL2`, #396), group and symmetric owners, weighted
`ElasticNet`, `Scaled` penalties, group penalties other than `GroupNormL2` with CD, matrix responses other than least squares with CD and a row-group `GroupNormL2` (a private `BlockIterate` over `vec(B)`, #396), intercepts/offsets, generalized losses/compositions,
monotone/active-set acceleration and APG diagonal preconditioning, ADMM/Newton,
primal-dual/SLOPE/graphical models, paths/screening/workspaces/refit, certificates other
than the duality certificate of square-root lasso CD, and reweighting are deferred. Nondefault
feature requests are refused. CD kkt_checks=0 is a compatibility sentinel, and gap=NaN is one too,
except after a certified square-root lasso run of CD, where gap is the certified bound.

This is a breaking support reduction. Version/registration and any public
release remain a separate decision; existing releases are untouched. Protected
archive refs preserve the complete snapshot; legacy/full remains the historical
working branch. Restore capabilities selectively; do not merge it wholesale.


---

## numerics.md (previous detailed notes)


CD runs on a PB SparseIterate that retains stored activation/compaction order: a
private one for a dense vector, and a private copy of the caller's owner for a
`SparseIterate`, which starts with that owner's active zeros and slot order and
which the caller's owner receives, whole, only after a finite completed run. First
full passes admit coordinates, active passes refine them, and only a full pass
strictly below the change tolerance converges. Once the active passes since the
last full pass have together visited 20 times as many coordinates as a full pass,
the next pass is full. Random LS uses historical momentum/restarts and refreshes
moved residual caches before full checks, including before such a forced full
pass; the borrowed RNG advances.
Cyclic and explicit momentum=false remain supported.
Zero columns choose the nearest-zero penalty minimizer, including lambda=0.
Nonzero-column curvature underflow, and a curvature that is not finite, are errors. tol=0 stays strict; maxpasses=0
returns unconverged with no updates, and an owner then keeps its exact entry state.
After every pass zero coordinates leave the active set, so an owner that completed
at least one pass has none and their order follows from compaction, which moves the
last active coordinate into the place of a removed one. A nonfinite returned
objective is refused before dense scatter or owner commit; this is not robust
dynamic-range recovery. A nonconverged finite pass-limit return warns, then commits.
A numerical error leaves a caller's owner unchanged but may advance the RNG.
Dense and owner solves from the same canonical state (the owner built from the
dense vector) run the same arithmetic and RNG schedule. A different slot order of
the same active set can change the trajectory and the final point, and the change
stopping rule gives no general bound on the distance to a minimizer or on the KKT
violation: assess accuracy with an independent objective/KKT check.

PGD retains the native image-then-value-and-gradient order (the value and gradient themselves are ProximalBase's oracles), scalar steps, fused PB prox,
TFOCS objective-to-gradient checks, finite curvature-growth refusal and zero-step
gradient refresh. Objective/iterate/FASTA convergence tests combine by OR. The objective
denominator and the gradient normalizers carry no absolute term: the objective test is
`|F - F'| / |F| < ftol` or the flat form, and the gradient test compares the residual with
`gradtol` times the largest residual so far or times the larger of ‖∇f‖∞ and the proximal-step
residual, against a scale that exceeds `L eps(T) ‖x‖∞`. The iterate test keeps
`xtol * max(‖x‖, 1)`, which for `‖x‖ < 1` is an absolute tolerance. A stop that any of them
proposes is checked once in `_stationary!` (`src/utils.jl`): the minimal-norm KKT residual of
the accepted `x` must be below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, `λmax = α‖Xᵀy‖∞`
(formed once per solve in `xhat` and kept in the state field `λmax`), with `λ` the ℓ1 level of the
penalty. `_stationary!` converts the levels of the penalty to `T` once (`_converted_penalty`; the weights of a
`NormL1`, a `Vector{T}`, are kept as they are) and takes the
level and the residual from that penalty: `_l1_level` is `T(λ0) * maximum(w)`, the largest coefficient, for a
`NormL1` with weights. The
residual is ProximalBase's full-point `kkt_violation` of `NormL1(T(λ0))`, of `NormL1(T(λ0), w)` or of
`ElasticNet(T(λ1), T(λ2))`; for `ElasticNet` it adds `λ2 xᵢ` at the nonzero entries. `λ2` is not in `S`
(the check is the lasso check on the data augmented by `√λ2 I`, see `numerics.md`).
The penalty is validated once by `_check_penalty` in `_check_data`. For an `x` that is not a `BlockIterate`
it accepts a `NormL1` for all solvers (with weights, `_check_l1_weights`: a `Vector{T}` of the length of `x`, finite and nonnegative entries,
no alias with `x`, a level `T(λ0)` that is zero or normal, and the coefficients `T(λ0) wⱼ` finite and, for positive factors, normal) or an unweighted `ElasticNet` for all solvers and refuses any other
penalty; a `BlockIterate` has its own method, for a `GroupNormL2`. The check requires `S =
max(λ, λmax)` finite, that product, formed in `T`, at least `floatmin(T)` and the residual
finite; it does not require the product to be finite. Otherwise the three flags are cleared and the solve continues. PGD uses the `∇f(x)` it holds. APG
forms `∇f(x)` from the cached image `z_x` with `_value_and_gradient!` (ProximalBase's
`value_and_gradient_from_predictor!`), into `xhat`
and `dz`, which the next iteration overwrites before reading, and counts it in `grad_calls`.
The check is a computed working-precision residual, not an exact-arithmetic certificate.
Objective rounding can still end a solve with an objective increase; `ftol = 0`
disables the objective test. Check objective/KKT independently. Native
Float32 may stagnate earlier. Finite inputs do not ensure finite intermediates: the
value is ProximalBase's, which recovers a value whose squares leave the range of `T`,
but the image `X x` and the gradient `α fl(Xᵀd)` are not recovered.

APG (`AccProxGradDescent`) is the historical accelerated method narrowed to the
dense LS core: extrapolation `y = x + k/(k+3)(x - x_previous)`, `L ← αL` before each
iteration, backtracking `L ← L/β` until the LS bound test accepts the trial (see
"The APG bound test" below), and one restart from `y = x_previous` when an extrapolated step raises the computed
objective. `X y` is formed from `X x` and `X x_previous` without a product; a restart
copies `X x_previous`. Departures from `legacy/full`: no metric, tuple, owner or
generic smooth-loss path; β and α are validated and used in `T` (`T(β) < 1` and
`T(α) > 0` after rounding); the objective-scale bound that only guarded a nonfinite
value is dropped, so a nonfinite trial raises `L` through `next_curvature` (which
raises once `L/β` is not a finite increase) instead of failing at once; a trial is
accepted only when the bound is certified by rounding-error bounds ("The APG bound
test" below), where legacy compared rounded squares of cached-image differences with
an 8eps image allowance; a step with `x == y` entrywise is accepted with a
finite value, where legacy raised; a
nonfinite gradient at `y` is treated like a nonfinite value (restart, or failure
without momentum). Each step writes `x_previous ← x` after forming `y` and before the
first trial, so the shared engine's rollback restores the last accepted iterate.
`backtrack_steps` counts every trial, including the accepted one, so it equals
`prox_calls`. With `C` the number of stationarity checks of the solve (each evaluates
`∇f(x)` once, counted in `grad_calls` and not in `f_calls`), `grad_calls = iterations +
restarts + C` and `f_calls = 1 + grad_calls + prox_calls - C`. Its reported gradient residual
`L‖x - y‖∞` is a stopping quantity measured from `y`; it is not an independent KKT residual
at `x` (the check evaluates `∇f(x)` separately).

### The APG bound test

For least squares, `f(x) ≤ f(y) + ⟨∇f(y), d⟩ + L‖d‖²/2` (`d = x - y`) holds iff
`√α ‖X d‖ ≤ √L ‖d‖`. The target is that inequality relaxed by legacy's slack, `√α ‖X d‖
≤ (1 + 4eps) √L ‖d‖`, for the stored `x` and `y`, with `α` the loss scale as given. A
trial with `d ≠ 0` is accepted only when `_bound_certified!` (`src/solvers/image_models.jl`)
certifies the target; every other trial is rejected, so `L` grows.

*Assumptions.* IEEE arithmetic in `T` with gradual underflow, modelled as
`fl(a ∘ b) = (a ∘ b)(1 + δ) + η'` with `|δ| ≤ u = eps(T)/2` and `|η'| ≤ η/2`,
`η = nextfloat(zero(T))` (subnormal additions are exact); and a matrix-vector product that
evaluates each entry as a dot product of `p` multiplications and additions (or fused
multiply-adds) in some order. Then `|fl(X v) - X v| ≤ γ_p |X||v| + 2p η` componentwise,
`γₖ = k u/(1 - k u)`, so `‖fl(X v) - X v‖ ≤ γ_p ‖X‖_F ‖v‖ + 2p √n η`. `k u < 1/8` is required
for `k = max(n, p) + 4` in `T` and `k = n p + 3` in Float64 (`_check_bound_size`, before
mutation; for Float32 this refuses `max(n, p) ≥ 2,097,148`).

*Error bounds.* The cached `z_x` of a trial is a fresh product (bound above with `v = x`).
The cached `z_y` is a copy of a fresh product of `x_a` (first step, restart), or the
extrapolation `fl(z_a + ω(z_a - z_b))` of fresh products of `x_a` and `x_b` with
`y = fl(x_a + ω(x_a - x_b))` and computed `0 < ω ≤ 1`; three roundings per combination (one
an underflowing product) give `E_y = (2γ_p + 16u)‖X‖_F(‖x_a‖ + ‖x_b‖) + 8p√n η + 2√p ‖X‖_F η`,
covering both images, the image error of the rounded `y` and both combinations. `‖X‖_F`
enters as a proved upper bound (`_frobenius_upper`: squares summed in Float64, exactly
representable for Float32 data, in one pass when that is accurate and otherwise after an
exact scaling by the power of two `2^-e` of the maximum (`ldexp`), with `γ_{np+3}` and
underflow terms, rounding up the square root and the conversion), and each computed iterate norm is divided by `1 - γ_{p+4}`. The computed norms
of `Δz = z_x - z_y` and `d̂ = fl(x - y)` are within `γ_{n+4}` and `γ_{p+4}` of the norms of the
stored vectors (a one-pass sum is used only when finite and at least `4n floatmin(T)`; the
scaled two-pass form otherwise), and `‖d̂ - d‖ ≤ u ‖d‖`.

*Decision.* Cheap path: accept when `√α` times the upper bound `‖Δz‖/((1 - γ_{n+4})(1 - u)) + E_x + E_y`
is at most `(1 + 4eps)/(1 + κ) √L ‖d̂‖/((1 + γ_{p+4})(1 + u))`; reject when `√α` times the lower
bound `‖Δz‖/((1 + γ_{n+4})(1 + u)) - E_x - E_y` exceeds `(1 + 4eps)(1 + κ) √L ‖d̂‖/((1 - γ_{p+4})(1 - u))`.
Otherwise form `w = fl(X d̂)` in the residual buffer, with
`‖w - X d‖ ≤ (γ_p + 2u)‖X‖_F ‖d̂‖/((1 - γ_{p+4})(1 - u)) + 2p√n η`, accept when its upper bound passes,
and reject otherwise. `√α` (`_root_scale`) is formed from `α`'s significand and exponent
after `α` is rounded once to Float64 (exact for a Float32 or Float64 scale, for a `Bool` and
for an integer of magnitude at most `2^53`; a larger integer is rounded once); the exponent
is made even, the root of the significand is converted to `T`, and half the exponent is
carried as the `Int` exponent of an `_SE` value, so the range of `T` does not limit `√α`.
A scale outside the range of Float64 is not supported by `_root_scale`.
`κ = 32u` covers the roundings of `√L`, of `√α`'s conversion to `T`
and of the fixed number of `_SE` products and sums on each side; the dimension-dependent
errors enter through the factors above. These are conservative bounds: in Float32 the
cheap path is often inconclusive late in a solve and the fresh product decides, and for
data deep in the subnormal range, where the underflow terms can dominate the bounds, a
nonzero step may be rejected until `L` is far above the curvature, or the solve may fail
with rollback.

*Range.* The norms and the bound arithmetic are carried as a significand in `[1, 2)` of
type `T` and an integer binary exponent (`_SE`), so no partial product or sum of the bound,
no ratio of scale factors, and no subnormal norm is rounded to a scalar of `T`. The native
products, the extrapolation and the one-pass sums are evaluated in `T` and enter only
through the bounds above. Under the assumptions, a curvature above `floatmax(T)` is never
certified, so backtracking ends in `next_curvature`'s error and the engine's rollback.

*Edge cases.* `d̂ = 0` entrywise: accepted with a finite value (a stopping policy). A trial
with a nonfinite value or iterate norm is rejected before the test. A nonfinite `Δz` gives no
cheap decision; the fresh product decides. `L = 0` is rejected. Legacy's 8eps image allowance
and zero-`Δz` shortcut are not used.

*Validation.* These checks are samples, not a proof. `test/accelerated_pgd.jl` checks
against BigFloat references computed from `X`, `x` and `y` (the exact `X d`) that no accepted
trial violates the target, over random data with exponent spans of ±40 (Float32) and ±300
(Float64), subnormal-range data, large common offsets, extrapolated images with `ω` up to 1,
loss scales wider and narrower than `T`; that a global curvature bound `4α‖X‖_F²` is accepted
for normal-range data; that the fresh-product-only decision (an internal switch) is safe as
well; the underflow, narrower-scale and long-reduction cases found in review; and that
`_frobenius_upper` bounds `‖X‖_F`. On the 576 ordinary solves of the PR record 4.7% of trials
needed the fresh product; every solve is bit-identical to the fresh-product-only decision,
571 are bit-identical to `legacy/full`, and the 5 that differ (Float32) change the objective
by at most 2e-7 relative.

Callbacks/display sample `print_every`; stored traces include each iteration. A
callback receives the trace when storing, otherwise a state. Limits are checked
after an iteration and counts may overshoot. iteration_converged means a limit,
not success. `ProximalOptions` refuses positive gaptol at construction and does
not store gaptol or gapevery. Solvers, options and `BackTracking` each have one
validating inner constructor (settings are checked as given and after conversion),
so `solve!` does not re-check them; APG still checks β and α in the precision of
the iterate before any state is created.
The retained scalar APIs/results do not introduce a new stopping/logging engine.


---

## internals.md (previous detailed notes)


The thirteen active files are module/types/blocks/line_searches/solve/utils/precompile,
solvers/image_models, proximal_gradient_descent and accelerated_proximal_gradient_descent,
and cd/models/solver/leastsquares. Small native helpers support the separately cached
algorithms and existing result types; PGD and APG share the LS image model, the
gradient engine `_solve_gradient!`, the stopping rules and the result type. CDModel and state hooks are private extraction/test seams, not
promises of custom loss or workspace support. Generic block/metric/certificate/
logging frameworks are deferred.

The dense and `SparseIterate` entry points of CD share one private run on a
PB SparseIterate (model, state, passes, warning and finite-objective check). The
dense wrapper builds that iterate from the vector and scatters the result back.
The owner wrapper copies the caller's owner with `copy`, runs on the copy and
commits with a same-shape `copyto!` through PB's public storage methods only,
after the finite-objective check; it does not rebuild through a dense vector.
Each copy preserves the state of its source: the initial copy keeps the entry
state (active zeros and slot order), and the commit writes the final state of the
working copy, after any compaction, which removes zeros and can reorder slots
during the passes. Validation is split into data
checks shared by both gates and an owner gate that inspects only public active
values and tests aliasing against the original owner. PGD keeps the dense gate and
refuses owners.

The current exact PB pin is `a19c59aa723d085d5d7cf5242895bda16eb77214`. CD uses
its scalar `prox_block` oracle; PGD retains fused `value_and_prox!`. All three solvers take the least-squares value from the PB oracles named above, and PGD and APG take the coefficient gradient from them. The private PB
SparseIterate contract remains unchanged. PR #237's group/workspace migration is
not imported. The gated analysis job always runs isolated exact-source paired
diagnostics against PB A e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291 and frozen
PS 64930401cfc0451e886728d916263c4dab2baf36 (CD and PGD only), including when package tests are
not selected or reused. Loaded paths, clean Git HEADs and source digests are
checked; version strings never skip probes. C0 and the provenance audit describe
the independent full-suite mathematical/behavioral tests.

Current CI is stable Julia1 Linux x64 only for every tier. Preserve required
checks, full master validation, coverage, benchmark-analysis and conservative
policy-aware nightly reuse. Historical platform runs and the deferred macOS C0
warm-convergence failure remain historical, not newly passing claims.

Historical measured performance tables remain in the repository's
[full-package performance record](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/historical-full-performance.md).
They are not replaced by unmeasured minimal-core claims.
