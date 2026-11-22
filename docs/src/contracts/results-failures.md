# Results, mutation and failures

`converged` reports the implemented criterion for the selected solver. Read its
meaning together with the [working-precision limits](@ref FP-01), the method's
contract, and the independently evaluated residual when accuracy matters.

## [RES-01 Convergence, limits and certificates](@id RES-01)

**Statement.**

Meeting the implemented stopping criterion is not the same as holding an independently
certified optimum. The solvers stop on three kinds of evidence:

| Solver | A stop is proposed by | Vetoed by | `converged = true` means | Kind of evidence |
| --- | --- | --- | --- | --- |
| `CDSolver`, least squares with `NormL1`, `ElasticNet`, `IndNonnegative()` or unweighted `NormL1Nonneg` | a full pass whose largest change, scaled when relative scaling is active, is below the threshold | nothing | with `relative = true` and `y ≠ 0`: each scaled change `abs(h_k) √(s a_k)` of one full pass is below `tol √s ‖y‖`, with `a_k = ‖X_k‖²`; with `relative = false`, or `y = 0`: each `abs(h_k)` is below `tol` | a change test, with no independent check |
| `CDSolver`, group lasso | the same, with the change of a group | nothing | the same per group: the scaled change is `‖h_k‖ √(s ℓ_k)`, with `ℓ_k` the curvature bound of the group, and the unscaled one `‖h_k‖` | a change test, with no independent check |
| `ProximalGradientDescent`, `AccProxGradDescent` on the regression routes with a dedicated KKT check | the `x`, objective or gradient test of an iteration | the stationarity check | a test proposed a stop and, for least squares with `NormL1` or `ElasticNet` on a dense vector, every coordinate's computed score passed the rule of [STOP-21](@ref) (below its threshold, or at most `0` at an exact zero scale, where no threshold is formed); otherwise the computed residual passed [STOP-04](@ref) and any applicable entry or group checks for [the logistic and matrix-response lasso](@ref STOP-03), [group lasso](@ref STOP-05), [the Euclidean norm](@ref STOP-17), or [the nonnegative penalties](@ref STOP-16) | a comparison in `T` of computed scores and thresholds, formed as stated below; for least squares with `NormL1` or `ElasticNet` on a dense vector, its exact-arithmetic analogue is approximate coordinatewise stationarity relative to the smooth part of the model that the check scores (the objective of the solve when their coefficients agree), with no general error bound ([STOP-21](@ref)) |
| `ProximalGradientDescent`, `AccProxGradDescent` on the opt-in ℓ1-ball route ([IN-12](@ref)) | the same, the last iteration, or an unchanged accepted iterate | the full check of [STOP-22](@ref) | the full check passed at a point classified inside the ball; a passing check at a point classified outside or not classified sets `approximate_solution = true` instead ([RES-04](@ref)) | a comparison in `Float64` of a computed support gap and fixed-step mapping, with model noise terms, against budgets from the tolerances ([FP-05](@ref)) |
| `ProximalGradientDescent`, `AccProxGradDescent` with a generic stationarity check | the same | the generic check | a test proposed a stop and the proximal-gradient residual passed the threshold comparison and guards in [STOP-07](@ref) | a working-precision indication that can be weaker when the accepted `L` is small |
| `ProxNewton`, logistic regression | the accepted point, at the start and after each accepted iteration | nothing | the largest ProximalBase KKT score `kkt` of the original problem, from a gradient formed at the returned point, is finite and at most `tol` (see [PN-05](@ref)) | a residual formed in working precision; `stop_reason` is `:converged`, `:maxiter` or `:stalled` |
| `LogisticADMM`, logistic regression | each completed iteration | nothing | the primal residual `‖X b - t‖` and the dual residual `ρ ‖Xᵀ(t - t_previous)‖` are within their thresholds, and the largest ProximalBase KKT score `kkt` of the original problem, from a gradient formed at the returned point, is at most `tol` (see [LA-04](@ref)) | residuals formed in working precision; `stop_reason` is `:converged`, `:maxiter`, `:stalled` or `:prox_failed` |
| `CDSolver`, square-root lasso, `λ > 0` | a full pass below the threshold | the duality certificate | where the minimum `P*` is positive: a proved `(P − P*)/P* < 1e-4`, with `gap` the bound; for `y = 0` and `x = 0`, where `P* = 0`: exact optimality, with `gap = 0` | a bounded gap |

The entrywise matrix lasso uses the same PGD/APG result flags, with the
full-matrix scores and scale in [STOP-03](@ref).

In the regression PGD/APG rows, the `λmax`-based stationarity checks form their thresholds
in `T`. [STOP-04](@ref) specifies the finite-scale and finite-residual guards,
the lower bound on the threshold and the strict comparison for those
checks; the coordinatewise check of [STOP-21](@ref) forms its thresholds from factors carried as a
`Float64` significand times a power of two and converts each to `T` once, under its own guards. [STOP-07](@ref) adds guards for the generic mapping check. A computed
threshold can overflow to `Inf`. Interpret a kept stop as the result of the
computed comparison. Graphical-lasso PGD uses the comparison in [PGD-08](@ref).

In the CD rows, `h_k` is the change of coordinate (or group) `k` in the pass and `s` the loss scale.
In the first two rows the changes are computed from the solver's cached residual, and the flag does not
say that this cache is close to `y − Xx` at the returned point (see
[The cached residual](@ref CD-05)). In the scalar least-squares row, the comparison of a scaled change
with the threshold is made between the computed values, in working precision, of [CD-03](@ref), so a
case whose exact values are equal can pass; "below" is that computed comparison.

Of the problems audited, only the square-root lasso carries a certificate, and that
certificate has the assumptions stated in [The certificate](@ref CDQ-03) and
[Tightening and the uncertified stop](@ref CDQ-04). After an uncertified stop,
[the bounded fallback](@ref CDQ-05) can certify the stopped point or return a
point with a proved lower objective. It does not guarantee recovery at exact
fits, and a final `converged = false` can still mean a nonoptimal exact fit. For the
other solvers `converged = true` reports that the criterion of its row was met. Check the
returned point with the [independent KKT residual](../sparsity-and-kkt.md) when the result
matters.

Reaching a pass or iteration limit is not convergence. CD can return a finite
nonconverged solution and logs a warning when `converged = false`; PGD and APG do
not log a warning merely because `maxiter` was reached, and `ProxNewton` and `LogisticADMM` log none
for any stop ([PN-01](@ref), [LA-01](@ref)). Gap certificates are
implemented only for square-root-lasso CD. Elsewhere `gap = NaN` means that a gap
was not calculated, and does not mean the gap is zero. CD's `kkt_checks = 0` is also
a compatibility placeholder. [CDQ-03](@ref) and [CDQ-04](@ref) specify the certificate
assumptions, tightening and uncertified stop. [CDQ-05](@ref) specifies the
fallback's returned point, pass total, restored or final-stage change statistics,
and RNG advancement. The square-root row describes the certificate at the
returned point, which can follow an uncertified initial stop and a fallback.
[CDQ-06](@ref) explains the relation between an exact-fit certificate and
the scaled-lasso noise-scale minimizer.

See [the retired normalized-residual wording](@ref RES-UNRECONCILED) for the
historical interpretation of the regression PGD/APG comparison.

For nonnegative least squares and nonnegative lasso, dense PGD uses
the constrained residual in [STOP-16](@ref), subject to the same computed-threshold
guards in [STOP-04](@ref). A kept stop is a working-precision stationarity check;
it does not supply an exact-arithmetic certificate or a calculated duality gap.
The supported inputs and feasibility refusals are in [IN-07](@ref). With `CDSolver` on a dense
`Vector`, these penalties use the change-test row of the table above: `converged` does not
check the constrained KKT conditions, and the reported minimum is the objective from the
cached residual ([CD-09](@ref)).

Uncentered `SqrNormL2` ridge was also added after the table's baseline. Its
scalar least-squares CD run uses the same full-pass change criterion as the
first row, specified by [CD-03](@ref), with `passes` counting completed passes,
`kkt_checks = 0` as a compatibility sentinel and `gap = NaN`. The result's
`minimizer` is the caller's dense vector or owner, and `minimum` is the final
finite objective evaluated from the cached least-squares residual plus the
ridge penalty. [CDS-03](@ref)/[CDS-04](@ref) retain the owner commit and propagated
failure boundary; adding a ridge penalty supplies no duality certificate.

For consensus ADMM, [ADM-02](@ref) specifies the computed residual tests,
the stagnation guard, counters, limit statuses and numerical failure boundary.
For the graphical lasso, [ADM-04](@ref) replaces the stagnation score and adds
the symmetry and Cholesky rules. For the least-squares lasso, [ADM-05](@ref) replaces
only the stagnation score.
Graphical-lasso PGD uses the KKT check and result fields in [PGD-08](@ref), with the
rollback boundary in [PGD-07](@ref).

**Applies to.** All solver result types; each solver retains its specified loss, penalty and precision scope.

**Code.** `src/cd/solver.jl`: completed passes and CD results; `src/solve.jl`: gradient iteration/stationarity decisions; `src/types.jl`: result fields; `src/solvers/logistic_proxnewton.jl`: the `ProxNewton` result; `src/solvers/logistic_admm.jl`: the `LogisticADMM` result.

**Tests.** `test/weighted_elasticnet.jl` checks public convergence flags against the independent weighted scores and the coordinatewise scales of [STOP-21](@ref), and `test/stopping_coordinatewise.jl` the convergence flags of zero-scale, exact-fit and offset problems, and `test/l1ball_numerical.jl` the success flags of the ℓ1-ball route, each success scored with an independent MPFR oracle (which does not reproduce the route's verdicts on rejected proposals). `test/multiresponse_lasso_pgd_apg.jl` checks matrix limits, callbacks and residuals. `test/logistic_proxnewton.jl` checks the `ProxNewton` result fields and stop reasons against an independent objective and KKT score, and `test/logistic_admm.jl` does so for the `LogisticADMM` result. `test/core_contracts.jl`, `test/stopping_scale.jl`, `test/group_pgd.jl`, `test/linf.jl`, `test/sqrt_lasso.jl`, `test/nonnegative_lasso.jl`, `test/cd_nonnegative.jl` (the nonnegative CD fits, judged by an independent constrained KKT score) and the solver-specific stopping tests. The ridge cases in `test/cd_elasticnet.jl` reuse `check_result!` for the independently evaluated objective, caller identity, `kkt_checks == 0` and `isnan(gap)`.

**Sources.** `docs/src/numerics.md:L853`, `docs/src/numerics.md:L1072`, `docs/src/numerics.md:L1075`, `docs/src/numerics.md:L1081`, `docs/src/stopping-limits.md:L17`, `docs/src/stopping-limits.md:L19`, `docs/src/stopping-limits.md:L22`, `docs/src/stopping-limits.md:L23`, `docs/src/stopping-limits.md:L24`, `docs/src/stopping-limits.md:L25`, `docs/src/stopping-limits.md:L26`, `docs/src/stopping-limits.md:L27`, `docs/src/stopping-limits.md:L28`, `docs/src/stopping-limits.md:L30`, `docs/src/stopping-limits.md:L35`, `docs/src/support.md:L385`, `docstring:src/types.jl:L298`, `docstring:src/types.jl:L300`. The later nonnegative-lasso result interpretation follows [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8). The square-root fallback qualification is from [f573224f](https://github.com/mlakolar/ProximalSolvers.jl/commit/f573224f70058be24b81378ab2d6e1c752eb93e8), as retained in [the integrated result guidance at ef8c9aae](https://github.com/mlakolar/ProximalSolvers.jl/blob/ef8c9aae0afd8dedf0b2f2b172f5a06da267c9d7/docs/src/stopping-limits.md#L35-L45).

The later ridge result assertions are [217cde72, shared result checks](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/test/cd_elasticnet.jl#L217-L228) and [their ridge callers](https://github.com/mlakolar/ProximalSolvers.jl/blob/217cde72cad2b324e174012accc949da59c1bba5/test/cd_elasticnet.jl#L378-L408).

## [RES-02 Gradient result fields and counters](@id RES-02)

**Statement.**

This clause describes `OptimizationResults` for PGD and APG with regression
coefficients, including [IN-10](@ref). See [PGD-08](@ref) for graphical-lasso PGD.
`minimizer` aliases the caller's coefficient storage and `minimum` is the reported
objective at that iterate. `iterations` counts steps. `iteration_converged` reports
reaching the iteration limit; it does not report successful convergence.

The result stores stopping flags, residuals and tolerances, an optional `trace`,
oracle call counts and backtracking counts. `x_converged`, `f_converged` and
`grad_converged` are the flags after the stationarity check, so all three are false
when that check vetoed a proposed stop. Residual fields retain the last iteration's
test residuals. APG's `grad_calls` includes one gradient at the accepted `x` for
each stationarity check. PGD's `backtrack_steps` includes accepted nonzero
line-search trials; APG counts every trial, including the accepted one. Detailed
APG accounting is in [APG-04](@ref).

`f_increased` records `F > F_previous` for the last computed objectives. An increase
ends the solve only if `allow_f_increases = false`, except on the ℓ1-ball route, where it does
not end the solve ([STOP-22](@ref)); the result does not store that option. `f_residual` is `abs(F-F_previous)/abs(F)`, with `0.0` when both values are
zero and `Inf` when `F = 0` but the previous value is nonzero. With `ftol > 0`, this
is the quantity compared with `ftol`. With `ftol = 0`, the objective test is off:
`f_tol = 0.0`, `f_converged = false`, and `f_residual` is reported without deciding
a stop. An iteration whose iterate equals the preceding one elementwise sets
neither `x_converged` nor `grad_converged` under `ftol = 0`; [STOP-10](@ref) also
specifies the accelerated method's `x == y` case.

`stagnated` reports the specific Float32 PGD exit whose full condition, flags and
scope are specified in [STOP-11](@ref). Its `x_residual` is zero; it does not certify
convergence or an accuracy target. Flags report independent conditions, so
`stagnated` can coincide with `call_limit_reached`, `iteration_converged`, or an
iteration whose callback returned true. [STOP-09](@ref) specifies simultaneous
flag combinations. [STOP-18](@ref) classifies a return by these flags, and
notes that the result has no dedicated field for a callback or time-limit stop.

Three fields follow `gap`: `approximate_solution`, `smooth_minimum` and `feasibility`. Off the
ℓ1-ball route they are `false`, the stored smooth loss at `minimizer` (to which `minimum` adds the
penalty value) and `nothing`; [RES-04](@ref) specifies them and the route's `minimum`, which can be
`Inf` or `NaN`.

**Applies to.** `OptimizationResults` from PGD or APG, including nonconverged finite returns.

**Code.** `src/types.jl`: `OptimizationResults`; `src/solve.jl`: stopping/result construction; gradient solver iteration state.

**Tests.** `test/core_contracts.jl`, `test/core_regressions.jl`, `test/accelerated_pgd.jl`, `test/stopping_scale.jl`; `test/l1ball_numerical.jl` checks the three new fields of `NormL1` and `IndBox` solves.

**Sources.** `docstring:src/solvers/proximal_gradient_descent.jl:L334`, `docstring:src/types.jl:L298`, `docstring:src/types.jl:L300`, `docstring:src/types.jl:L313`, `docstring:src/types.jl:L323`, `docstring:src/types.jl:L335`.

## [RES-03 Mutation and numerical failure boundaries](@id RES-03)

**Statement.**

Input validation completes before mutation; the alias rules are in [IN-05](@ref).
CD computes on private coefficient storage and commits only a finite completed
run. Dense vectors therefore do not receive a partial numerical result. A caller's
`SparseIterate` retains its original state when a numerical exception propagates
out of `solve!`; a successful
commit can remove active zeros and reorder slots. The RNG can still advance.
The complete owner transaction is [CDS-03](@ref)/[CDS-04](@ref); group and matrix
owners use the specialized rules in [CDG-08](@ref) and [CDM-02](@ref).

Square-root CD can catch an `ArgumentError` inside a fallback stage and complete
with the stopped point `x0`, as specified in [CDQ-05](@ref). That finite completed
result commits `x0`, which may differ from the caller's starting point. A
propagated exception, including a nonfinite final objective, retains the outer
transaction guarantee.

`ProxNewton` computes on private buffers and writes the caller's coefficients once, at a normal
return; an exception from its inner coordinate solve or the logistic oracle leaves them
unchanged ([PN-05](@ref)). `LogisticADMM` writes the caller's coefficients once, at a normal return, which
includes the `:prox_failed` return of the last completed iteration; a supplied predictor and dual are written then
too when an iteration completed, and keep their entries when none did. An exception from its coefficient step, or a
nonfinite objective or KKT score of the original problem after an iteration, leaves them unchanged. The reported
`dual_kkt`, a `Float64` evaluation formed at the return, has the range limits stated in [LA-01](@ref) and can be `Inf`
or `NaN` for valid inputs; it raises no exception ([LA-05](@ref)).

PGD and APG numerical step exceptions restore the last accepted coefficient point
and rethrow, including the line-search error of the ℓ1-ball route's 64-trial limit
([PGD-09](@ref)). For [IN-10](@ref) this restoration copies the full accepted
coefficient matrix into the supplied storage. They do not provide a general transaction for internal counters or
buffers. The line-search boundary is [LS-09](@ref) and the accelerated trial/restart
boundary is [APG-03](@ref). A finite run that reaches a limit may still commit or
return its point with `converged = false`; this is distinct from a thrown numerical
error. Results share the mutable coefficient storage; copy it when retaining
earlier coefficients. Extended traces copy coefficients and gradients.

Continue with [Results and troubleshooting](../working-with-results.md) for reading
a returned result, or the [Glossary](../glossary.md) for terminology.

**Applies to.** Public solve wrappers; numerical exceptions and completed finite returns.

**Code.** `src/solve.jl`: validation, solve wrappers and restoration; `src/cd/solver.jl`: private run and finite-objective completion; `src/solvers/logistic_proxnewton.jl`: the private `ProxNewton` solve and its single write; `src/solvers/logistic_admm.jl`: the private `LogisticADMM` solve and its single write.

**Tests.** `test/multiresponse_lasso_pgd_apg.jl` checks pre-write refusals and full-matrix restoration after a failing trial. `test/norml2_pgd.jl` checks pre-write refusals and restoration of the starting coefficients after a failed step for both gradient methods, and `test/l1ball_numerical.jl` does so for the ℓ1-ball route. `test/logistic_proxnewton.jl` checks that the coefficients and the borrowed inputs are unchanged after a refusal and after a numerical exception of the inner solve; `test/logistic_admm.jl` checks the same for `LogisticADMM`, with its predictor and dual, and the `:prox_failed` return. `test/sparse_cd.jl`, `test/group_cd.jl`, `test/multiresponse_cd.jl`, `test/core_contracts.jl`, `test/core_regressions.jl`.

**Sources.** `docs/src/numerics.md:L921`, `docs/src/numerics.md:L923`, `docs/src/numerics.md:L1072`, `docs/src/numerics.md:L1075`, `docs/src/numerics.md:L1081`, `docs/src/developer/implementation-notes.md:L205`, `docstring:src/solvers/proximal_gradient_descent.jl:L334`. The later caught-stage refusal follows [the fallback at f573224f](https://github.com/mlakolar/ProximalSolvers.jl/blob/f573224f70058be24b81378ab2d6e1c752eb93e8/src/cd/sqrtlasso.jl#L602-L665) and its unchanged outer finite-objective commit boundary.

## [RES-04 Results of the ℓ1-ball route](@id RES-04)

**Statement.**

`OptimizationResults` holds three fields after `gap`, for every PGD and APG solve:

| Field | On the ℓ1-ball route ([IN-12](@ref)) | On the other routes |
| --- | --- | --- |
| `approximate_solution::Bool` | the full check ([STOP-22](@ref)) of the final iteration passed at a point classified `:outside` or `:unknown` | `false` |
| `smooth_minimum::T` | the stored, computed smooth loss of the last loss evaluation at `minimizer` | the same; `minimum` adds the computed penalty value to it |
| `feasibility` | a `NumericalFeasibilityReport` | `nothing` |

The other fields keep their meanings ([RES-02](@ref)), with these differences on the route:

- `converged = true` means that the full check of the final iteration passed at a point classified `:inside`; `converged` and `approximate_solution` are not both true. A point classified `:unknown` or `:outside` gets `approximate_solution = true` only when that check passed; after a limit or callback stop without a passing check, both flags are false;
- `minimum` follows the classification of the returned point: the smooth loss when it is classified `:inside`, `Inf` when `:outside` and `NaN` when `:unknown`, so a finite returned point can have `minimum = Inf` or `NaN`. This is the route's convention for the composite objective, the loss plus the mathematical indicator of the ball; it can differ from the loss plus ProximalBase's indicator, which compares a rounded sum with the radius;
- the trace's `fg_x` (the “Function value” of the displayed trace), the callback's objective, `f_residual` and `f_increased` use the smooth loss;
- `allow_f_increases` does not govern termination ([STOP-22](@ref)), since the composite objective is `Inf` at an accepted iterate outside the ball;
- `gap` is `NaN`: no duality gap is computed.

The report holds `membership` and `margin = σ - ρ`, the computed widened mass minus the radius, from the cached decision ([PGD-09](@ref), [FP-05](@ref)); on a normal return that decision describes the returned point, when callbacks leave the coefficients unchanged as [PGD-09](@ref) requires. It also holds the `cap`; the `gap`, `gap_noise`, `mapping` and `map_noise` of the last full check, which can precede the returned iterate after a limit or callback stop, `NaN` when no check ran, and possibly nonfinite when a check ran and failed on nonfinite values; the `gap_budget` and `mapping_budget` of the solve; and `checks`, the number of full checks. `show` prints the route's lines only when `feasibility` is not `nothing`. The accessors `approximate_solution`, `smooth_minimum` and `feasibility` read the fields, like the other accessors of the result.

The membership `:inside` says that the widened mass is below the radius by more than the noise of [FP-05](@ref), or is zero with a positive radius: a computed classification, not an exact-arithmetic certificate. A converged result and an approximate solution both carry the full check's computed comparison and no accuracy guarantee ([STOP-01](@ref)).

**Applies to.** `OptimizationResults` of PGD and APG, the result fields of graphical-lasso PGD ([PGD-08](@ref)) included for the three new fields.

**Code.** `src/types.jl`: `OptimizationResults`, `NumericalFeasibilityReport`, the accessors and `show`; `src/solve.jl`: `_solve_gradient!`, `_approximate_solution`, `_composite_minimum`, `_feasibility_report`; `src/solvers/l1ball.jl`: the route's methods of these three hooks.

**Tests.** `test/l1ball_numerical.jl`, at the route results of the fixture, loss-scale and threshold tests: `smooth_minimum` against ProximalBase's loss at the returned point, and the reported `minimum` against the convention for the reported membership (the tests do not compare `minimum` with ProximalBase's indicator); `approximate_solution` against `converged` and the cleared flags; one analytic fixture for each membership class; `show` with and without a report; the three fields of `NormL1` and `IndBox` solves. `test/core_regressions.jl` compares every field of mixed-level and native-level solves, the new ones included.

**Sources.** [The approved plan](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7073644919) and [the maintainer's decision I2](https://github.com/mlakolar/ProximalSolvers.jl/pull/529#issuecomment-7074272157); the result of `projected_policy` in [B1 at d58b9099](https://github.com/mlakolar/ProximalSolvers.jl/blob/d58b9099c5837230212496766a721972b98d83f3/research/issue-515/b1.jl).

## [RES-UNRECONCILED Retired: historical normalized-residual guarantee](@id RES-UNRECONCILED)

**Retired by [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).** The authoritative arithmetic and guards
are [STOP-04](@ref); [RES-01](@ref) explains the result-flag interpretation.

**Statement.**

**Original wording retained verbatim for provenance; not an active guarantee.** The baseline
`OptimizationResults` docstring said:

> It is a working-precision value, not an exact-arithmetic certificate; it guarantees
> only that the computed, normalized residual `‖G‖∞ / max(λ, λmax)` is below
> `max(gradtol, 64 eps(T))` (the threshold is formed in `T`, see `ProximalOptions`),
> not coefficient accuracy on ill-conditioned designs.

That normalization statement does not generally follow from the implemented
rounded product-threshold comparison and its underflow/overflow behavior.
It was explicitly retired by [#416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416) without changing solver
behavior. The other original claims remain in [STOP-UNRECONCILED](@ref),
also retired. The caution about coefficient accuracy on ill-conditioned designs
remains valid; the normalized inequality is not a public guarantee.

**Applies to.** Provenance of the baseline PGD/APG `OptimizationResults` documentation.

**Code.** `src/types.jl`: baseline `OptimizationResults` docstring; `src/solve.jl` and the stationarity helpers implement the product comparison.

**Tests.** No new test or behavior is claimed by this historical note; [STOP-04](@ref) records the implementation and its existing coverage.

**Sources.** `docstring:src/types.jl:L300`.
