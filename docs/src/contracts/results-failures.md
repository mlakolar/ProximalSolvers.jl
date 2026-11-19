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
| `CDSolver`, least squares with `NormL1` or `ElasticNet` | a full pass whose largest change, scaled when relative scaling is active, is below the threshold | nothing | with `relative = true` and `y ≠ 0`: each scaled change `abs(h_k) √(s a_k)` of one full pass is below `tol √s ‖y‖`, with `a_k = ‖X_k‖²`; with `relative = false`, or `y = 0`: each `abs(h_k)` is below `tol` | a change test, with no independent check |
| `CDSolver`, group lasso | the same, with the change of a group | nothing | the same per group: the scaled change is `‖h_k‖ √(s ℓ_k)`, with `ℓ_k` the curvature bound of the group, and the unscaled one `‖h_k‖` | a change test, with no independent check |
| `ProximalGradientDescent`, `AccProxGradDescent` | the `x`, objective or gradient test of an iteration | the stationarity check | a test proposed a stop and the computed `‖G‖∞` is below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λ` the ℓ1 level (for `NormL1(λ, w)`, the largest coefficient `maxⱼ cⱼ` with `cⱼ = T(λ) wⱼ`; each entry of `G` is scored with its own `cⱼ`; for `GroupNormL2` with PGD, the group residual and the group scale; see [the stationarity check](@ref STOP-03)) | a residual formed in working precision |
| `ProximalGradientDescent`, `AccProxGradDescent`, `NormLinf` | the same | the generic check | a test proposed a stop and the proximal-gradient residual is below `max(gradtol, 64 eps(T)) * max(‖∇f(0)‖∞, ‖∇f(x)‖∞)` (see [the generic check](@ref STOP-07)) | a working-precision indication; weaker when the accepted `L` is small |
| `CDSolver`, square-root lasso, `λ > 0` | a full pass below the threshold | the duality certificate | where the minimum `P*` is positive: a proved `(P − P*)/P* < 1e-4`, with `gap` the bound; for `y = 0` and `x = 0`, where `P* = 0`: exact optimality, with `gap = 0` | a bounded gap |

In the CD rows, `h_k` is the change of coordinate (or group) `k` in the pass and `s` the loss scale.
In the first two rows the changes are computed from the solver's cached residual, and the flag does not
say that this cache is close to `y − Xx` at the returned point (see
[The cached residual](@ref CD-05)).

Of the problems audited, only the square-root lasso carries a certificate, and that
certificate has the assumptions stated in [The certificate](@ref CDQ-03) and
[Tightening and the uncertified stop](@ref CDQ-04). For the
other solvers `converged = true` reports that the criterion of its row was met. Check the
returned point with the [independent KKT residual](../sparsity-and-kkt.md) when the result
matters.

Reaching a pass or iteration limit is not convergence. CD can return a finite
nonconverged solution and logs a warning when `converged = false`; PGD and APG do
not log a warning merely because `maxiter` was reached. Gap certificates are
implemented only for square-root-lasso CD. Elsewhere `gap = NaN` means that a gap
was not calculated, and does not mean the gap is zero. CD's `kkt_checks = 0` is also
a compatibility placeholder. [CDQ-03](@ref) and [CDQ-04](@ref) specify the certificate
assumptions, tightening and uncertified stop.

The criterion table is preserved from the baseline. Its PGD/APG entries describe
a product-threshold comparison in working precision; [STOP-04](@ref) defines its
formation and guards. The historical normalized-residual assertion discussed under
[Unreconciled](@ref RES-UNRECONCILED) must not be inferred from that comparison.

Nonnegative lasso was added after this table's baseline. Its dense PGD path uses
the constrained residual in [STOP-16](@ref), subject to the same computed-threshold
guards in [STOP-04](@ref). A kept stop is a working-precision stationarity check;
it does not supply an exact-arithmetic certificate or a calculated duality gap.
The supported inputs and feasibility refusals are in [IN-07](@ref).

**Applies to.** All solver result types; each row retains its specified loss, penalty and precision scope.

**Code.** `src/cd/solver.jl`: completed passes and CD results; `src/solve.jl`: gradient iteration/stationarity decisions; `src/types.jl`: result fields.

**Tests.** `test/core_contracts.jl`, `test/stopping_scale.jl`, `test/group_pgd.jl`, `test/linf.jl`, `test/sqrt_lasso.jl`, `test/nonnegative_lasso.jl` and the solver-specific stopping tests.

**Sources.** `docs/src/numerics.md:L853`, `docs/src/numerics.md:L1072`, `docs/src/numerics.md:L1075`, `docs/src/numerics.md:L1081`, `docs/src/stopping-limits.md:L17`, `docs/src/stopping-limits.md:L19`, `docs/src/stopping-limits.md:L22`, `docs/src/stopping-limits.md:L23`, `docs/src/stopping-limits.md:L24`, `docs/src/stopping-limits.md:L25`, `docs/src/stopping-limits.md:L26`, `docs/src/stopping-limits.md:L27`, `docs/src/stopping-limits.md:L28`, `docs/src/stopping-limits.md:L30`, `docs/src/stopping-limits.md:L35`, `docs/src/support.md:L385`, `docstring:src/types.jl:L298`, `docstring:src/types.jl:L300`. The later nonnegative-lasso result interpretation follows [upstream #413 at fd45a42](https://github.com/mlakolar/ProximalSolvers.jl/commit/fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8).

## [RES-02 Gradient result fields and counters](@id RES-02)

**Statement.**

`OptimizationResults` is the result of plain or accelerated proximal gradient.
`minimizer` aliases the caller's coefficient vector and `minimum` is the reported
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
ends the solve only if `allow_f_increases = false`; the result does not store that
option. `f_residual` is `abs(F-F_previous)/abs(F)`, with `0.0` when both values are
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
flag combinations.

**Applies to.** `OptimizationResults` from PGD or APG, including nonconverged finite returns.

**Code.** `src/types.jl`: `OptimizationResults`; `src/solve.jl`: stopping/result construction; gradient solver iteration state.

**Tests.** `test/core_contracts.jl`, `test/core_regressions.jl`, `test/accelerated_pgd.jl`, `test/stopping_scale.jl`.

**Sources.** `docstring:src/solvers/proximal_gradient_descent.jl:L334`, `docstring:src/types.jl:L298`, `docstring:src/types.jl:L300`, `docstring:src/types.jl:L313`, `docstring:src/types.jl:L323`, `docstring:src/types.jl:L335`.

## [RES-03 Mutation and numerical failure boundaries](@id RES-03)

**Statement.**

Input validation completes before mutation; the alias rules are in [IN-05](@ref).
CD computes on private coefficient storage and commits only a finite completed
run. Dense vectors therefore do not receive a partial numerical result. A caller's
`SparseIterate` retains its original state on a numerical failure; a successful
commit can remove active zeros and reorder slots. The RNG can still advance.
The complete owner transaction is [CDS-03](@ref)/[CDS-04](@ref); group and matrix
owners use the specialized rules in [CDG-08](@ref) and [CDM-02](@ref).

PGD and APG numerical step exceptions restore the last accepted coefficient point
and rethrow. They do not provide a general transaction for internal counters or
buffers. The line-search boundary is [LS-09](@ref) and the accelerated trial/restart
boundary is [APG-03](@ref). A finite run that reaches a limit may still commit or
return its point with `converged = false`; this is distinct from a thrown numerical
error. Results share the mutable coefficient storage; copy it when retaining
earlier coefficients. Extended traces copy coefficients and gradients.

Continue with [Results and troubleshooting](../working-with-results.md) for reading
a returned result, or the [Glossary](../glossary.md) for terminology.

**Applies to.** Public solve wrappers; numerical exceptions and completed finite returns.

**Code.** `src/solve.jl`: validation, solve wrappers and restoration; `src/cd/solver.jl`: private run and finite-objective completion.

**Tests.** `test/sparse_cd.jl`, `test/group_cd.jl`, `test/multiresponse_cd.jl`, `test/core_contracts.jl`, `test/core_regressions.jl`.

**Sources.** `docs/src/numerics.md:L921`, `docs/src/numerics.md:L923`, `docs/src/numerics.md:L1072`, `docs/src/numerics.md:L1075`, `docs/src/numerics.md:L1081`, `docs/src/developer/implementation-notes.md:L205`, `docstring:src/solvers/proximal_gradient_descent.jl:L334`.

## [RES-UNRECONCILED Unreconciled: historical normalized-residual guarantee](@id RES-UNRECONCILED)

Owner reconciliation is tracked in [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).

**Statement.**

**Historical wording retained for review; not an active guarantee.** The baseline
`OptimizationResults` docstring said:

> It is a working-precision value, not an exact-arithmetic certificate; it guarantees
> only that the computed, normalized residual `‖G‖∞ / max(λ, λmax)` is below
> `max(gradtol, 64 eps(T))` (the threshold is formed in `T`, see `ProximalOptions`),
> not coefficient accuracy on ill-conditioned designs.

That normalization statement does not in general follow from the implemented
rounded product-threshold comparison and its underflow/overflow behavior. The
current arithmetic and guards are specified in [STOP-04](@ref); the related
baseline claims are collected in [STOP-UNRECONCILED](@ref). This documentation
migration preserves the contradiction without changing solver behavior. The
qualification about coefficient accuracy on ill-conditioned designs remains valid
as a limit; the normalized inequality is not promoted to a guarantee.

**Applies to.** Provenance of the baseline PGD/APG `OptimizationResults` documentation.

**Code.** `src/types.jl`: baseline `OptimizationResults` docstring; `src/solve.jl` and the stationarity helpers implement the product comparison.

**Tests.** No new test or behavior is claimed by this historical note; [STOP-04](@ref) records the implementation and its existing coverage.

**Sources.** `docstring:src/types.jl:L300`.
