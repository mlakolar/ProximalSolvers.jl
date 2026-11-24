# Working precision and numerical boundaries

The supported array types and parameter conversions are defined by [IN-01](@ref) and
[IN-02](@ref). These clauses describe the limits of computations on accepted inputs.
They distinguish a library kernel's recovery from a solver's complete execution.

## [FP-01 Native precision and ownership of arithmetic](@id FP-01)

**Statement.**

Iterates retain their native `Float32` or `Float64` working accuracy. `Float32` may
stagnate earlier. Some tolerances, residual reports and scalar diagnostics are stored
in `Float64`; that storage does not promote the iterates or certify their accuracy.
A tolerance tighter than the working precision does not guarantee corresponding
coefficient accuracy. `BigFloat` is useful for independent test references, not a
supported solver working type. The loss-scale type refusals are in [IN-02](@ref).

With subnormal numbers flushed to zero on the solving thread (`set_zero_subnormals(true)`),
the stopping decisions of PGD and APG are unspecified, the exact zero cases of [STOP-21](@ref)
included: the solver's arithmetic and its compiled comparisons can treat a stored subnormal
value as zero.

Finite input entries do not guarantee finite intermediate arithmetic. ProximalBase's
least-squares kernels selectively recover some overflow/underflow cases with
representable results. ProximalSolvers adds its own matrix products, curvature
computations, state updates, stopping and finiteness checks, and does not promise
end-to-end recovery of every failed product, curvature, step or objective.

The least-squares solvers read `Y`, `X` and the stored loss scale through
`ProximalBase.leastsquares_data`. ProximalBase owns the least-squares value in all
three solvers and the coefficient gradient in PGD/APG, with the scale as its
computation uses it. PGD/APG use `value_from_predictor` and
`value_and_gradient_from_predictor!`; CD uses `value_from_residual`, which returns
only a value. ProximalSolvers does not repeat those oracle computations. It owns the
image `X*x` and CD residual/curvature caches, CD coordinate correlations and updates,
the `lambda_max` product of the `λmax`-based stationarity checks, the column norms of the
coordinatewise check ([STOP-21](@ref)), steps and line searches, APG's
certified bound, stopping rules and rollback, and on the ℓ1-ball route of [IN-12](@ref) the widened
`Float64` decision, the budgets and the full check of [FP-05](@ref). The coordinatewise check reads
ProximalBase's least-squares value at the accepted point for its scale and does not
recompute `‖Xx - y‖`. Exact oracle accuracy and range
statements belong to the section “Least squares at a predictor or residual that the
caller holds” in the pinned
[ProximalBase smooth-function guide](https://github.com/mlakolar/ProximalBase.jl/blob/7d5d1e006b02814fb28f8cfb5eca20a05d73ee9e/docs/src/smooth.md).
ADMM's use of proximal operators and working-precision diagnostics is specified
in [ADM-02](@ref), and its Cholesky checks in `T` for the graphical lasso in
[ADM-04](@ref). For the least-squares lasso, [ADM-05](@ref) specifies the `Float64`
arithmetic, the proximal operator that ProximalBase computes from a cached SVD and the
stationarity score. It states that no cutoff on `ρ`, the penalty or the coefficients applies.

`ProxNewton` ([PN-01](@ref)) works in `Float64` only. It forms its predictors, the weighted design,
the model gradients and the objective in `Float64`, takes the logistic value and gradient from
ProximalBase's predictor oracles, and converts the penalty level to `Float64` once; the weighted model's
saturated rows and the range errors of its inner solve are specified in [PN-02](@ref) and [PN-05](@ref).
`LogisticADMM` ([LA-01](@ref)) also works in `Float64` only, with `ρ` in `[1e-10, 1e10]`. It forms the image `X b`,
the response and residual of its coefficient step, the scalar roots and the residual tests in `Float64`, takes the
loss value and gradient from ProximalBase's predictor oracle and adds the penalty itself, and holds the dual as
`w = ρ u`. Its scalar root forms `σ(t) - y` from `exp(-|t|)`; for the label `0` and `t` between about `-745.13` and
`-708.40` this value is subnormal rather than `0`, and below that range it is `0` ([LA-03](@ref)). The accuracy of the root is stated there as
a tested backward error, and the failure boundary in [LA-05](@ref).

`converged` has the algorithm-specific meaning in [RES-01](@ref). Independently
evaluate the objective and [KKT residual](../sparsity-and-kkt.md) when accuracy
matters, especially for `Float32`.
For nonnegative lasso, use the constrained residual in [STOP-16](@ref), which
accounts for feasible directions at a zero coefficient.

**Applies to.** All supported solvers and precisions.

**Code.** `src/solvers/image_models.jl`; `src/cd/leastsquares.jl`; `src/solve.jl`; ProximalBase least-squares oracles at the dependency pin.

**Tests.** The statement on flushed subnormals has no decision test (the decisions are unspecified): in `test/stopping_coordinatewise.jl` a helper enables flushing, calls the check on three fixtures, which must finish without throwing, and restores the previous setting, which the test asserts. `test/core_contracts.jl`, `test/core_regressions.jl`, `test/cd_numerics.jl`, `test/initial_curvature.jl`, `test/logistic_proxnewton.jl` (the `ProxNewton` row roots at extreme logits, against analytic references, and the returned point of the public saturated-start fit, against a `BigFloat` oracle), `test/logistic_admm.jl` (the scalar root of `LogisticADMM` against a 256-bit `BigFloat` bisection, with a subnormal residual and extreme arguments) and the solver-specific numerical tests.

**Sources.** `docs/src/numerics.md:L791`, `docs/src/numerics.md:L800`, `docs/src/numerics.md:L909`, `docs/src/developer/implementation-notes.md:L151`, `docs/src/developer/implementation-notes.md:L169`, `docs/src/getting-started.md:L119`. The constrained-residual application is added by [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8).

## [FP-02 Recovered values and different oracle boundaries](@id FP-02)

**Statement.**

CD asks `value_from_residual` for the loss at its cached residual. Its finite-final-
objective refusal and the loss's subnormal error bound are specified in [CD-09](@ref).
A recovered finite loss can still give a nonfinite loss-plus-penalty sum. The
exceptional recovery is conditional on ProximalBase's range and margin statements;
near the overflow threshold a result can remain `Inf`.

PGD and APG obtain start/trial values from ProximalBase. PGD's start and gradient
refreshes use `value_and_gradient_from_predictor!`, as does APG's stationarity check;
the other value-only evaluations use `value_from_predictor`. When the guide's
conditions hold, these oracles can recover a finite value even if the sum of squares
would overflow in `T`. This does not promise a finite gradient.

In particular, if subtraction `z-y` overflows although the entries of `z` and `y`
are finite, `value_from_predictor` can recover the value while
`value_and_gradient_from_predictor!` returns a nonfinite value and nonfinite gradient
entries. At such a start PGD refuses a nonfinite combined-oracle value with
`ArgumentError("start from a point where f is finite")`, even if the value-only
oracle would be finite. APG can accept the recovered value-only start, then fail its
first step with
`ErrorException("the gradient step did not produce a finite objective")`.
The recorded example, unchanged-start observations and issue tracking are in
[ORACLE-02](@ref); the general restoration boundaries are in [RES-03](@ref).

**Code-derived possibility, not a reproduced guarantee.** PGD evaluates a trial
with `value_from_predictor` and refreshes the gradient at an accepted trial with
`value_and_gradient_from_predictor!`. In a branch that accepts from function values,
a finite-valued accepted iterate could therefore hold a nonfinite gradient. The
baseline notes explicitly state that this accepted-iterate case was not reproduced
and has no test. If another step is attempted, `x-gradient/L` is nonfinite for every
finite `L`; for a penalty whose prox preserves nonfinite entries (such as `NormL1`),
trial values are nonfinite. The expected code path raises `L` until
`next_curvature` cannot increase it finitely and raises
`ErrorException("line search failed: the curvature estimate cannot increase finitely")`,
after which `solve!` restores the last accepted iterate and rethrows. `maxiter` or
another stop can end the solve first. The separate probe in [ORACLE-02](@ref)
rejected its nonfinite-gradient trial and raised a different line-search error;
it does not establish this possibility for every setting.

**Applies to.** Least-squares values, PGD/APG gradient refreshes and extreme-range oracle inputs.

**Code.** `src/solvers/image_models.jl`: oracle calls; `src/line_searches.jl`: finite-curvature retry; `src/solve.jl`: last-accepted-point restoration.

**Tests.** Existing range coverage is in `test/core_regressions.jl` and `test/initial_curvature.jl`; the historical nonfinite-gradient accepted-iterate possibility has no reproducing test, as stated above.

**Sources.** `docs/src/numerics.md:L812`, `docs/src/numerics.md:L827`, `docs/src/numerics.md:L868`, `docs/src/numerics.md:L871`, `docs/src/numerics.md:L881`.

## [FP-03 Products before loss scaling](@id FP-03)

**Statement.**

CD forms the coordinate correlation `r' * X_k` in the working type before applying
the loss scale. PGD/APG form the rounded product `X' * d`, with `d = z-y` and
`z = X*x`, then multiply by the scale. If such a product underflows, overflows or
cancels before scaling, the solvers do not recover it, even if the exact scaled
gradient would lie in range.

A stopping test that reads the same rounded product can be met at a nonminimizer.
The `λmax`-based PGD/APG stationarity checks can read a computed zero gradient and a computed zero
`lambda_max` even where the exact products are nonzero. The coordinatewise check of
[STOP-21](@ref) can read a computed zero gradient entry where the exact product is not
zero; its score is then `-cᵢ` at a zero coefficient and `|λ2 xᵢ + cᵢ sign xᵢ|`, which can be
positive, elsewhere. Its threshold is formed from `Φ`, the stored loss value plus the ridge
contribution `(λ2/2)‖x‖²`: a computed `Φ = 0` refuses each coordinate outside its exact zero
scales (a column of stored `±0` entries with no ridge term, and `x = y = 0`), while a positive
ridge contribution can give a normal threshold at a zero stored loss, and a design whose
columns are all of the first kind can pass at a nontrivial point of zero loss when every
computed score is at most `0`. In CD, a zero computed
correlation can make a full pass change nothing and satisfy the change test.
[ORACLE-03](@ref) preserves executable underflow and cancellation examples, their
high-precision residuals and their objective errors. Keep data and scales in a range
where `X' * r` is representable, and assess important results using independently
computed higher-precision products.

The line-search failure mode involving a subnormal or zero computed squared
displacement, including its zero-product guard and unhandled nonzero-product case,
is specified once in [LS-08](@ref). It is another limit of working-precision
products, not a general promise of convergence at small scales.

**Applies to.** CD coordinate correlations and PGD/APG gradients and stationarity products.

**Code.** `src/cd/leastsquares.jl`: column correlations; `src/solvers/image_models.jl`: gradient model; `src/utils.jl`: `_lambda_max!`, `_filled_scales!`; `src/line_searches.jl`: displacement products.

**Tests.** `test/cd_numerics.jl`, `test/stopping_scale.jl`, `test/stopping_coordinatewise.jl`, `test/core_regressions.jl`; executable historical examples are retained in [ORACLE-03](@ref).

**Sources.** `docs/src/numerics.md:L865`, `docs/src/numerics.md:L897`, `docs/src/stopping-limits.md:L99`, `docs/src/stopping-limits.md:L101`, `docs/src/stopping-limits.md:L164`, `docs/src/stopping-limits.md:L167`.

## [FP-04 Equivalent formulations and curvature scaling](@id FP-04)

**Statement.**

The PGD/APG initial curvature, its normal-number floor and the relation of its
Frobenius bound to the spectral curvature are defined in [PGD-02](@ref).

An equivalent formulation can change the arithmetic range. For a `NormL1` penalty,
substituting `x = s*u` with `s > 0` replaces `X` by `s*X` and `lambda` by
`s*lambda`, multiplies curvature by `s^2`, and maps a start `x0` to `x0/s`.
By contrast, replacing `X` by `c*X`, `y` by `c*y`, and the loss scale `alpha` by
`alpha/c^2`, while retaining the penalty, preserves the objective and curvature;
it preserves the initial curvature up to rounding. These mathematical
transformations do not guarantee recovery of an arbitrary extreme-scale solve.
[ORACLE-01](@ref) records the observed examples, solver counts and Julia versions.
Overflow of a trial's squared step norm and its scaled handling are specified in
[LS-06](@ref).

**Applies to.** Least-squares PGD/APG initialization and equivalent lasso rescalings.

**Code.** `src/solvers/image_models.jl`: `_initial_curvature`, `_frobenius_upper`; `src/solvers/proximal_gradient_descent.jl`; `src/solvers/accelerated_proximal_gradient_descent.jl`; `src/line_searches.jl`.

**Tests.** `test/initial_curvature.jl` and `test/core_regressions.jl`; historical illustrative outcomes are in [ORACLE-01](@ref).

**Sources.** `docs/src/numerics.md:L833`, `docs/src/numerics.md:L857`.

## [FP-05 The widened ℓ1 decision, the budgets and the full check of the ℓ1-ball route](@id FP-05)

**Statement.**

On the route of [IN-12](@ref) the coefficients, the trials and ProximalBase's projection stay in `T`.
The decision, the budgets, and the full check's witness, residual, gradient, support gap, noise terms
and comparisons below are formed in `Float64`; the full check's mapping point, its division by the
curvature and its projection are formed in `T`, and the differences from the projection, their maximum
and its scaling by the curvature are formed in `Float64`.
Write
`ρ = Float64(r)` for the radius, `a = Float64(s)` for the loss scale as supplied (`1.0` for a raw
loss), `u = eps(Float64)/2` and `γ(k) = k u / (1 - k u)`. The norm `‖v‖₂` of an array is computed as
`m * sqrt(sum(abs2(Float64(vᵢ) / m)))` with `m = maxᵢ |Float64(vᵢ)|`, and is `m` when `m` is zero or
not finite.

*Decision.* For `x` with `p` entries and the cap `c`, the widened mass is
`σ = sum(a -> abs(Float64(a)), x)`, the margin `m = σ - ρ` and the noise `ν = γ(p+2) max(σ, ρ)`. The
membership is `:outside` when `m > ν`, `:inside` when `m < -ν` or `σ = 0 < ρ`, and `:unknown`
otherwise. The code is `:pass` when `m - c < -ν`, `:over` when `m - c > ν`, and `:unresolved`
otherwise. A margin that is not finite gives `:unresolved` and `:unknown`, with noise `NaN`.

*Budgets*, once per solve, from `C = maxⱼ ‖Xⱼ‖₂` over the columns, `F = ‖X‖₂` over all entries,
`‖y‖₂`, `M = √a C`, `ŷ = √a ‖y‖₂` and the scale `S = max(ŷ, √a C ρ)² / 2`:

- the gap budget `G = objective_rtol * S / 2`;
- the cap `c = min(ρ, coefficient_atol + coefficient_rtol * ρ, G / (M ŷ + 1.5 M² ρ))`, the last term
  being `Inf` when its denominator is `0`;
- the curvature `κ = a C²`, or `1.0` when `C = 0`;
- the mapping budget `H = mapping_rtol * √a C * max(ŷ, √a C ρ)`.

*Full check* at `x`, with the decision of `x` cached by its trial ([IN-12](@ref)); a cached code
other than `:pass` runs no check:

1. The witness `w = φ * Float64.(x)`, with `φ = 1` when `σ + ν < ρ` and `φ = min(1, (ρ - ν) / σ)`
   otherwise, from the cached `σ` and `ν`.
2. The residual `e = X w - y` and the gradient `g = a * (Xᵀ e)` in `Float64`: for `Float64` data by
   BLAS products, for `Float32` data by column loops over `Float64(Xᵢⱼ)`. Let `δ = maxⱼ |gⱼ|` and
   `ζ = a * (γ(p+2) (F ‖w‖₂ + ‖y‖₂) + γ(n+2) ‖e‖₂)`.
3. The support gap `max(0, ρ - sum(abs, w)) δ + Σⱼ |wⱼ| (δ ± gⱼ)`, with `-gⱼ` where the sign bit of
   `wⱼ` is set and `+gⱼ` otherwise, and its noise `2ρ C ζ + γ(2p+12) (2ρ δ) + γ(p+2) ρ δ`.
4. With `L = T(κ)`: the trial `T.(w) .- T.(g) ./ L` in `T`, its projection `q` in `T` by
   ProximalBase's `prox!` for the solve's private `IndBallL1(r)` at step `one(T)/L`, the mapping
   `Float64(L) * maxⱼ |Float64(T(wⱼ)) - Float64(qⱼ)|` and its noise
   `C ζ + Float64(eps(T)) (Float64(L) maxⱼ |wⱼ| + δ)`.
5. Each noise then gains the underflow allowance below. The check passes when the support gap, the
   mapping and both noises are finite, `support gap + its noise ≤ G` and `mapping + its noise ≤ H`.

The check tests its intermediates in groups. After item 2 has evaluated, and counted, the gradient,
it tests the entries of `w`, `e` and `g` together; then the entries of the trial, before its projection,
which therefore never sees a nonfinite input; then those of `q`. A nonfinite entry in any group fails
the check, as does a product of the underflow allowance with a nonfinite factor (below), and so does a
nonfinite support gap, mapping or noise in item 5. The check counts the gradient call of item 2 and the
prox call of item 4 when it evaluates them: one each when it reaches the projection, and one gradient
call and no prox call when it fails before it.

The noises of items 3 and 4 are model estimates of the rounding of these sums and products, without
directed rounding; they are not interval enclosures. The decision compares the computed margin with
computed allowances, and a passing check compares computed quantities with computed budgets: neither
is an exact-arithmetic certificate, and a margin within the cap does not bound the distance to the
exact constrained minimizer. Apart from the underflow allowance, the operations, reductions and
conversions, and their order, are those of the research reference B1 (`norm2_64`, `budgets`,
`norm_decision`, `numerical_witness!`, `stop_scores!`) and of the B0 helpers it imports (`gamma64`,
`residual_score64!`, `estimate_gap`).

*Underflow allowance.* Under gradual underflow a nonzero product can round to a subnormal number or
to zero, and the computed gap and mapping can then be zero at a point that is not stationary. The gate
of [IN-12](@ref) refuses a design with a nonzero column whose curvature (in `Float64` and in `T`),
gap budget or mapping budget is not a normal positive number; the allowance covers the underflow
inside the full check's products. Besides these, PGD's step raises at an accepted nonzero step whose
squared norm underflows ([IN-12](@ref)); these are the route's only provisions for underflow. With
subnormals flushed to zero on the solving thread, the decisions are unspecified, as in [FP-01](@ref).

The model, per precision `P` of the operation, for finite operands and a finite result:
each product, quotient and fused multiply-add of the check obeys
`fl(a ∘ b) = (a ∘ b)(1 + δ) + ε` with `|ε| ≤ min(η_P, |a ∘ b|)` and `ε = 0` when a factor is an exact
zero, where `η_P` is the least positive subnormal number of `P`; in `Float64` (the residual, the
gradient, the support gap, the mapping's differences and its final product), `|δ| ≤ u` and
`η_P = η = nextfloat(0.0)`; in `T` (the conversions of `w` and `g`, the division by `L` and the
projection), `|δ| ≤ eps(T)/2` and `η_P = η_T = nextfloat(zero(T))`. An overflow is outside the
model; the fail-closed rules below cover it.
Additions and subtractions add no absolute error. The relative terms above account for the `δ`; the
allowance bounds the `ε` and their propagation. With `n × p` the design, `α` the loss scale, the
witness `w`, the computed residual `r`, `δ = ‖g‖∞`, `L = T(κ)`, `t` the mapping's trial point in `T`
and the computed mapping `m`:

1. The residual: `A_r = min(n p η, √n C ‖w‖₁)`, from the `n p` products `Xᵢⱼ wⱼ`.
2. The transposed product, per coordinate: `A_s = min(n η, C ‖r‖₂)`, plus the carried residual error
   `C A_r`.
3. The gradient error per coordinate: `E_g = α (C A_r + A_s) + min(η, 2α C ‖r‖₂)`.
4. The support gap: `2 max(ρ, ‖w‖₁) E_g + min((p + 1) η, δ (ρ + 2 ‖w‖₁)) + min(p η, ‖w‖₁) δ`.
5. The mapping `L (v - P(v - g/L))` at `v = T(w)`. The ℓ1-ball projection
   `P(z)ᵢ = sign(zᵢ) max(|zᵢ| - τ(z), 0)` moves its level `τ` by at most `‖Δz‖∞`, so it is
   2-Lipschitz in the ∞-norm (for `r = 3`, `z = [3, 3, 3]` and `z' = [3.125, 2.875, 2.875]` the
   ratio is `4/3`), and an error of the projection input enters with the factor 2: the gradient
   error adds `2 E_g`; for `Float32` data the conversion of `w` adds `3L min(η_T, ‖w‖∞)` and that of
   `g` adds `2 min(η_T, δ)`; the division by `L` adds `2L min(η_T, δ / L)`; the projection in `T`
   adds `L min(p η_T, ‖t‖∞)` and the final product by `L` adds `min(η, m)`.

The gap allowance is `4 × (term 4)` and the mapping allowance `4 × (term 5)`: a factor 2 for the
growth `(1 + u)^k ≤ 2` through at most `k = n + p + 2` later `Float64` roundings, which needs
`(n + p + 2) eps(Float64) ≤ 1`, times 2 for computed magnitudes in place of exact ones. That
condition gives `(1 + u)^k ≤ exp(1/2)`, which leaves room for the at most four roundings in `T` of each
trial entry (two conversions, the division and the subtraction), `(1 + eps(T)/2)^4 < 2 / exp(1/2)`; the projection in `T` enters only through the
assumption below. The products of the allowance's terms are formed by `_mulup`, which for finite
nonnegative factors returns an upper bound of their exact product: `0` when a factor is `0`, otherwise
`fl(a b)(1 + 4 eps) + η`, which is `Inf` when the product overflows. `_mulup` returns `Inf` when a
factor is not finite, whatever the other factor: a factor that overflowed, such as `2L` for a `Float64`
`L` above `floatmax(Float64) / 2`, can meet a factor that underflowed to zero although its exact value is
positive, such as the computed `δ / L`, and an exact-zero rule would then drop a positive term. The
remaining operations of the allowance (sums, `min`, `max` and the products by 2, 3 and 4) are
evaluated in round-to-nearest without that inflation. When
`(n + p + 2) eps(Float64) > 1` both allowances are `Inf`; a term that is `Inf` makes its allowance `Inf`
and a `NaN` mapping gives a `NaN` allowance; in each case the check fails. These bound and fail-closed
statements concern the values the check tests: the entries of `w`, `e`, `g`, the trial and `q`, and the
four final values. An overflowed `_mulup` result inside a `min` whose other arm is a bound by itself
leaves that bound.

The projection's own term assumes that ProximalBase's ℓ1 projection at the pinned revision `bc9e888d`
(`src/functions/indballl1.jl`), which soft-thresholds at a level formed from sums, power-of-two
scalings and divisions, has an absolute underflow error of at most `p η_T` per output entry beyond the
relative rounding of the `eps(T)` term; this rests on reading the dependency's source. B1's relative
mapping noise of item 4 carries the gradient's relative error with the factor 1 and is kept for parity
with B1; this argument covers only the absolute terms. Not covered: threads that flush subnormals; the
arithmetic of the trials and the line search ([LS-02](@ref)); and any projection error beyond that
assumption.

**Applies to.** The ℓ1-ball route of [IN-12](@ref), `Float32` and `Float64`.

**Code.** `src/solvers/l1ball.jl`: `_norm2_64`, `_l1_mass64`, `_gamma64`, `_l1_noise`, `_l1_decision`,
`_l1_budgets`, `_l1_witness!`, `_residual_score64!`, `_l1_support_gap`, `_mulup`,
`_l1_underflow_allowance`, `_l1_underflow_terms`, `_stationary!`.

**Tests.** `test/l1ball_numerical.jl` checks the budgets against a recomputation in the test from
LinearAlgebra's `norm` (relative difference at most `1e-12`). It scores each reported success on the
#508 fixtures with an independent 256-bit MPFR evaluation of the violation of the ball, the support
gap at a feasible radial witness, the fixed-step mapping with a sorted-threshold projection and the
change of the loss. It checks the membership classes `:inside`, `:outside` and `:unknown` on analytic
fixtures and each accepted iterate's decision. For the scaled case
`1e300 * LeastSquaresLoss([0.0], reshape([1e-155], 1, 1))`, `x = [1e-15]`, `r = 1e-14`, which the gate
admits and whose computed gradient is exactly zero, the full check fails, neither method reports a
success flag, and the returned point misses the budgets in MPFR. For a `Float32` case with a tolerance
override whose mapping trial overflows in its first entry (projecting it, as the check did before
this guard, gives a finite vertex; the guarded check skips that projection), neither method reports a
success flag, the MPFR mapping at the returned point exceeds its budget, and a direct call of the
check fails with one gradient call and no prox call. For a `Float64` case with a tolerance override
whose curvature exceeds `floatmax(Float64) / 2` (`X = 1e154`, `y = 1e-171`, `r = 1e-150`, start `0`,
APG with `β = 1 / 10^(308.1 / 60)`), where `2L` overflows and the computed `δ / L` is zero, neither
method reports a success flag, the MPFR mapping at the returned point exceeds its budget, and a direct
call of the check fails after one gradient call and one prox call. It also checks
the expansion example of term 5 with ProximalBase's projection in both precisions.

**Sources.** [The #515 handoff](https://github.com/mlakolar/ProximalSolvers.jl/issues/515#issuecomment-7072925678);
[B1 at d58b9099](https://github.com/mlakolar/ProximalSolvers.jl/blob/d58b9099c5837230212496766a721972b98d83f3/research/issue-515/b1.jl)
and the [#514 B0 helpers](https://github.com/mlakolar/ProximalSolvers.jl/tree/d58b9099c5837230212496766a721972b98d83f3/research/issue-514);
[the maintainer's decision 2 on the underflow escalation](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7081753480);
[ProximalBase at bc9e888d, `src/functions/indballl1.jl`](https://github.com/mlakolar/ProximalBase.jl/blob/bc9e888d09e5fc3c3feb35905dd7a14e70657fa5/src/functions/indballl1.jl);
[the maintainer's review of the shrink round](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7116783858);
[the maintainer's decision on the round 4 blockers](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7119424286),
which made a nonfinite intermediate fail the check.
