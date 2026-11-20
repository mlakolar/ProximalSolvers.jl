# Entry stopping thresholds: measurements

This page records the measurements behind the entry thresholds of [STOP-03](@ref) and [STOP-05](@ref) (issue
[#464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464)). They are observations at stated revisions, not
solver guarantees.

## [evidence-entry-thresholds-464 Study and provenance](@id evidence-entry-thresholds-464)

**Statement.** Measured at ProximalSolvers `083c2f70` with ProximalBase `e03c6d96`, on Julia 1.13.4 and 1.10.13 (AMD EPYC 7513). Four rules for a proposed stop with `NormL1(λ0, w)` were compared:
- the earlier single threshold `τ max(maxᵢ cᵢ, λmax)`;
- per-entry thresholds `τ max(cᵢ, λmax)`, the rule adopted;
- the single threshold plus a separate test of the zero-weight entries against `τ λmax`;
- the single threshold with `minᵢ cᵢ` in place of `maxᵢ cᵢ`.

Accuracy was computed in 256-bit BigFloat from the stored data and the returned coefficients, against analytic minimizers or BigFloat coordinate-descent references. The scripts, raw tables and prototypes are on the branch [`research/issue-464-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/28ba4e1f6111ed31009df5a39a9e3c4f4596eec2/research464) at `28ba4e1f`; the report is the [#464 comment](https://github.com/mlakolar/ProximalSolvers.jl/issues/464#issuecomment-7052247201).

- **The #464 fixtures.** Level `λ0 = 1e300`, weight 1 on an all-zero column (coefficient `1e300`) and weight 0 on the free columns, default options, start at zero. Iterations / relative objective excess, single threshold → entry thresholds:

  | Case | Single threshold | Entry thresholds |
  |---|---|---|
  | logistic PGD | 1 / `5.8e-3` | 6 / `2.4e-11` |
  | least-squares PGD, one free column | 1 / `2.6e-32` | 1 / `2.6e-32` |
  | least-squares PGD, two free columns | 1 / `2.28` | 195 / `6.4e-8` |
  | least-squares APG, one free column | 1 / `0.93` | 7 / `5.8e-11` |
  | least-squares APG, two free columns | 1 / `0.53` | 45 / `3.9e-8` |

  Every row reported `converged = true`. In the logistic row the minimizer has the predictor `log 4`; the single threshold stopped at the predictor `1.2`, and the entry thresholds at `1.386282…`, about `1.2e-5` from `log 4`.
- **Study of 204 configurations** (PGD, APG, Float32, Float64; zero and excluded columns with weights up to `1e100`, free and tiny weights, correlation `0.95`, rescaling by `1e±100`, logistic with a free intercept), Julia 1.13.4:
  - the single threshold reported 12 converged solves with excess above `1e-3` and 61 above the accuracy target (`1e-8` in Float64, `1e-5` in Float32);
  - the entry thresholds reported 4 and 11, the 4 being the offset fixture of [STOP-12](@ref) ([#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487));
  - the separate test of zero-weight entries missed tiny non-zero weights.
- **Minimum-coefficient rule.** It decided as the entry thresholds in all those solves, but it can reject near-optimal points with an active coefficient far above `λmax`. Take `X = [2.5 1e6; 0 1]`, `y = [1, -1e6]`, `NormL1(999999.27, [0, 1])` and `maxiter = 2000`. Its minimizer has the active `x₂ = -0.73`, and `λmax = 2.5`.
  - PGD from `[292000.4, -0.73]` reaches, at its second iterate `[292000.4, -0.7299999999906868]`, a point with relative excess `8.7e-23`. There the active entry's computed score is `9.31`, against the entry threshold `τ c₂ ≈ 10`. The minimum-coefficient rule compares it with `τ λmax = 2.5e-5` and rejects the point; PGD then took 27 iterations instead of 2.
  - APG from the rounded minimizer scaled entrywise by `1 .+ [1e-9, -1e-6]` ended after 7 iterations by an objective increase, with `converged = false` and excess `4e-25` under that rule, and with `converged = true` under the entry thresholds.
  - Both Julia versions gave identical output (`research464/scripts` at the evidence revision, and the [#464 thread](https://github.com/mlakolar/ProximalSolvers.jl/issues/464)).
- **Offset response ([STOP-12](@ref), [#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487)).**
  - #464 study, offset case: `X = [1 | Gaussian]`, `n = 50`, `p = 10`, `y = 1e6 + signal + noise`, zero weight on the intercept and one predictor, `λ0 = 0.5 λ0max` computed after fitting the free columns, default options. Every rule reported `converged = true` with relative excess `3.4` (PGD) and `46` (APG). The centered response gave `8.8e-12` (PGD) and `5.1e-11` (APG, entry thresholds).
  - #400 validation, offset fixture: excess `0.22` at default options and `1.7e-7` with `gradtol = 1e-8` (PGD).
- **Changed outcomes.** When a coefficient exceeds `λmax`, Float32 solves that the single threshold stopped early can instead end by the objective-increase exit with `converged = false`, at more accurate points, as the problem without the excluded column does. With a zero weight and `y = 0`, no stop passes ([STOP-03](@ref)).
- **Group penalty.** With singleton groups on the #464 fixture, APG kept a stop after one iteration at excess `0.93`. The per-group rule stops after 7 iterations at `5.8e-11`.

**Applies to.** Weighted least-squares `NormL1` with PGD and APG; raw `LogisticLoss` with weighted `NormL1` and PGD ([IN-09](@ref)); least-squares `GroupNormL2` with PGD and APG.

**Code.** `src/utils.jl`: `_stationary!`, `_entry_thresholds_hold`.

**Tests.** `test/entry_thresholds.jl`.

**Sources.** [Issue #464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464).
