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

- **The #464 fixtures.** With an all-zero column of weight `1e300`, the single threshold kept a stop after one iteration in every case, with relative objective excess:
  - logistic PGD: `5.8e-3`;
  - least-squares PGD: `2.28`;
  - least-squares APG: `0.93` and `0.53`.

  With the entry thresholds the excesses are `2.4e-11` to `6.4e-8`, at 6 to 195 iterations.
- **Study of 204 configurations** (PGD, APG, Float32, Float64; zero and excluded columns with weights up to `1e100`, free and tiny weights, correlation `0.95`, rescaling by `1e±100`, logistic with a free intercept), Julia 1.13.4:
  - the single threshold reported 12 converged solves with excess above `1e-3` and 61 above the accuracy target (`1e-8` in Float64, `1e-5` in Float32);
  - the entry thresholds reported 4 and 11, the 4 being the offset fixture of [STOP-12](@ref) ([#487](https://github.com/mlakolar/ProximalSolvers.jl/issues/487));
  - the separate test of zero-weight entries missed tiny non-zero weights.
- **Minimum-coefficient rule.** It decided as the entry thresholds in all those solves, but it rejects near-optimal points with an active coefficient far above `λmax`. For `X = [2.5 1e6; 0 1]`, `y = [1, -1e6]` and `NormL1(999999.27, [0, 1])`, PGD's second iterate has relative excess `8.7e-23` and a computed score of `9.31` in the active entry, against the entry threshold `τ c₂ ≈ 10`. The minimum-coefficient rule compares that score with `τ λmax = 2.5e-5` and rejects the point. APG from a perturbed minimizer ended with `converged = false` at excess `4e-25` under that rule, where the entry thresholds report convergence. Both Julia versions gave identical output.
- **Changed outcomes.** When a coefficient exceeds `λmax`, Float32 solves that the single threshold stopped early can instead end by the objective-increase exit with `converged = false`, at more accurate points, as the problem without the excluded column does. With a zero weight and `y = 0`, no stop passes ([STOP-03](@ref)).
- **Group penalty.** With singleton groups on the #464 fixture, APG kept a stop after one iteration at excess `0.93`. The per-group rule stops after 7 iterations at `5.8e-11`.

**Applies to.** PGD and APG with weighted `NormL1` (least squares and logistic) and `GroupNormL2`.

**Code.** `src/utils.jl`: `_stationary!`, `_entry_thresholds_hold`.

**Tests.** `test/entry_thresholds.jl`.

**Sources.** [Issue #464](https://github.com/mlakolar/ProximalSolvers.jl/issues/464).
