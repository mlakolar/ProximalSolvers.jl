# [Results, mutation and failures](@id RES-01)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/numerics.md:921-927 -->

- CD on dense coefficients calculates on private storage, avoiding a
  partially written dense result if a numerical failure occurs.
- CD on a `SparseIterate` uses a **private copy** and commits the final
  set of active coordinates only after finite completion. This means
  the original coefficient storage is unchanged if the numerical
  solve fails. A pass can remove zeros from the active list and
  change the order of stored coordinates. The RNG can still advance.

<!-- baseline: docs/src/numerics.md:1072-1082 -->

- Reaching a pass or iteration limit is not convergence. CD can return
  a finite nonconverged solution with a warning.

Gap certificates are implemented only for the square-root lasso with CD (below); elsewhere `gap=NaN` is
a placeholder.
For more precise treatment of exceptional arithmetic, compaction,
momentum, callbacks and test provenance, consult the
[technical contract notes](developer/implementation-notes.md).

Continue with [Results and troubleshooting](working-with-results.md)
or the [Glossary](glossary.md).

<!-- baseline: docs/src/stopping-limits.md:17-41 -->

## The criterion and a certificate

Meeting the implemented stopping criterion is not the same as holding an independently
certified optimum. The solvers stop on three kinds of evidence:

| Solver | A stop is proposed by | Vetoed by | `converged = true` means | Kind of evidence |
| --- | --- | --- | --- | --- |
| `CDSolver`, least squares with `NormL1` or `ElasticNet` | a full pass whose largest change, scaled when relative scaling is active, is below the threshold | nothing | with `relative = true` and `y ≠ 0`: each scaled change `abs(h_k) √(s a_k)` of one full pass is below `tol √s ‖y‖`, with `a_k = ‖X_k‖²`; with `relative = false`, or `y = 0`: each `abs(h_k)` is below `tol` | a change test, with no independent check |
| `CDSolver`, group lasso | the same, with the change of a group | nothing | the same per group: the scaled change is `‖h_k‖ √(s ℓ_k)`, with `ℓ_k` the curvature bound of the group, and the unscaled one `‖h_k‖` | a change test, with no independent check |
| `ProximalGradientDescent`, `AccProxGradDescent` | the `x`, objective or gradient test of an iteration | the stationarity check | a test proposed a stop and the computed `‖G‖∞` is below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λ` the ℓ1 level (for `NormL1(λ, w)`, the largest coefficient `maxⱼ cⱼ` with `cⱼ = T(λ) wⱼ`; each entry of `G` is scored with its own `cⱼ`; for `GroupNormL2` with PGD, the group residual and the group scale; see [the stationarity check](@ref "The stationarity check of a stop")) | a residual formed in working precision |
| `ProximalGradientDescent`, `AccProxGradDescent`, `NormLinf` | the same | the generic check | a test proposed a stop and the proximal-gradient residual is below `max(gradtol, 64 eps(T)) * max(‖∇f(0)‖∞, ‖∇f(x)‖∞)` (see [the generic check](numerics.md#The-generic-stationarity-check)) | a working-precision indication; weaker when the accepted `L` is small |
| `CDSolver`, square-root lasso, `λ > 0` | a full pass below the threshold | the duality certificate | where the minimum `P*` is positive: a proved `(P − P*)/P* < 1e-4`, with `gap` the bound; for `y = 0` and `x = 0`, where `P* = 0`: exact optimality, with `gap = 0` | a bounded gap |

In the CD rows, `h_k` is the change of coordinate (or group) `k` in the pass and `s` the loss scale.
In the first two rows the changes are computed from the solver's cached residual, and the flag does not
say that this cache is close to `y − Xx` at the returned point (see
[The cached residual](@ref "The cached residual")).

Of the problems audited, only the square-root lasso carries a certificate, and that
certificate has the assumptions stated in [The certificate](@ref "The certificate") and
[Tightening and the uncertified stop](@ref "Tightening and the uncertified stop"). For the
other solvers `converged = true` reports that the criterion of its row was met. Check the
returned point with the [independent KKT residual](sparsity-and-kkt.md) when the result
matters.

<!-- baseline: src/types.jl:298-347 -->

    OptimizationResults

Result from proximal gradient descent, plain or accelerated. `minimizer` aliases the caller's
coefficient vector; `minimum` is the reported objective at that iterate.
`iterations` counts steps and `converged` means that **at least one** stopping
test proposed a stop and that the stationarity check passed (see
[`ProximalOptions`](@ref)): the computed KKT residual at `minimizer` is below
`max(gradtol, 64 eps(T)) * max(λ, λmax)` (for `GroupNormL2`, the group residual and scale that
[`ProximalOptions`](@ref) defines). It is a working-precision value, not an
exact-arithmetic certificate; it guarantees only that the computed, normalized residual
`‖G‖∞ / max(λ, λmax)` is below `max(gradtol, 64 eps(T))` (the threshold is formed in `T`, see
[`ProximalOptions`](@ref)), not coefficient accuracy on ill-conditioned designs. For a `NormLinf` penalty the
generic proximal-gradient check of [`ProximalOptions`](@ref) is used instead. `iteration_converged` reports reaching the iteration limit,
**not** successful convergence.

The result also stores stopping flags, residuals and tolerances, optional
`trace`, call counts and backtracking counts. `x_converged`, `f_converged` and
`grad_converged` are the flags after the stationarity check, so all three are
`false` at an iteration where the check refused a proposed stop; the residual
fields are those of the tests at the last iteration. `grad_calls` of
`AccProxGradDescent` includes one gradient at `x` for each check. For PGD, `backtrack_steps`
includes accepted nonzero line-search trials; for APG it counts every trial,
including the accepted one. `gap=NaN` means a dual
gap was not calculated, not that the gap is zero.

`f_increased` is `F > F'` at the last iteration, where `F` is the computed
objective and `F'` the previous one. It reports the comparison: an increase
stops the solve only when `allow_f_increases=false`, a setting the result does
not store. With `ftol = 0` (see [`ProximalOptions`](@ref)), `f_tol` is `0.0` and
`f_converged` is `false`, because the objective test is off. `f_residual` is
then reported only and does not decide a stop; it is `|F - F'| / |F|`, with the
value `0.0` for `F = F' = 0` and `Inf` for `F = 0` and `F' != 0`. With `ftol > 0`
it is the same quantity, the one that the objective test compares with `ftol`. On an iteration whose iterate equals the
previous one elementwise, `ftol = 0` sets neither `x_converged` nor
`grad_converged` (see [`ProximalOptions`](@ref) for the accelerated method's
case `x == y`).

`stagnated` is `true` when `ProximalGradientDescent` on `Vector{Float32}` data with
`ftol = 0` stopped after an iteration in which both of these held: the accepted iterate
equals the previous one elementwise, and the last rejection of that iteration's line search
replaced the line search's curvature estimate `L̂` by the finite computed curvature of the
rejected step (see [`ProximalOptions`](@ref) for the condition). At such a stop `converged`,
`x_converged`, `f_converged` and `grad_converged` are `false` and `x_residual` is `0`.
`stagnated=true` is **not** a certificate of convergence or accuracy: it reports that an
iteration left the iterate unchanged after the last rejection of its line search was decided
by that step's computed curvature, and the returned point need not meet any accuracy target.
`stagnated` is `false` for `AccProxGradDescent`, for `Float64` data and with `ftol > 0`. Each
stopping flag reports its own condition, so `stagnated` can be `true` together with
`call_limit_reached`, with `iteration_converged`, or at an iteration at which the callback
returned `true`.
