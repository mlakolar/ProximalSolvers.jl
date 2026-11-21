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
the stationarity check's `lambda_max` product, steps and line searches, APG's
certified bound, stopping rules and rollback. Exact oracle accuracy and range
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

**Tests.** `test/core_contracts.jl`, `test/core_regressions.jl`, `test/cd_numerics.jl`, `test/initial_curvature.jl`, `test/logistic_proxnewton.jl` (the `ProxNewton` row roots at extreme logits, against analytic references, and the returned point of the public saturated-start fit, against a `BigFloat` oracle), `test/logistic_admm.jl` (the scalar root of `LogisticADMM` against a 256-bit `BigFloat` bisection, with a subnormal residual and extreme arguments) and the solver-specific numerical tests.

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
The PGD/APG stationarity check can read a computed zero gradient and a computed zero
`lambda_max` even where the exact products are nonzero. In CD, a zero computed
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

**Code.** `src/cd/leastsquares.jl`: column correlations; `src/solvers/image_models.jl`: gradient model; `src/utils.jl`: `_lambda_max!`; `src/line_searches.jl`: displacement products.

**Tests.** `test/cd_numerics.jl`, `test/stopping_scale.jl`, `test/core_regressions.jl`; executable historical examples are retained in [ORACLE-03](@ref).

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
