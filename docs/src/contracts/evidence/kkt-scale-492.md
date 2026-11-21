# Matrix PGD KKT scale: measurements

This page records the measurements behind the entrywise KKT scale of [PGD-08](@ref) (issue
[#492](https://github.com/mlakolar/ProximalSolvers.jl/issues/492)). They are observations at stated revisions, not
solver guarantees.

## [evidence-kkt-scale-492 Study and provenance](@id evidence-kkt-scale-492)

**Statement.** Measured at ProximalSolvers master `fa6e31c6` with ProximalBase `bc9e888d`. The probes ran on a cluster (Slurm) with Julia 1.13.4; the issue's table was also reported on Julia 1.10.13. Each probe replaced the solver's KKT-score helper by a candidate rule in the same process and recomputed every score in BigFloat at the returned point. Before the change, matrix PGD divided every entry's violation by the single scale `max(1, maximum(abs, S), maximum(C))` with `C = T(λ0) Λ`, and stopped when the largest ratio was at most `max(gradtol, 64eps(T))`. The maintainer chose rule F below. The rule was implemented after pull request [#483](https://github.com/mlakolar/ProximalSolvers.jl/pull/483) merged (`17e33ddd`), which permits nonnegative diagonal weights ([PGD-06](@ref)), so the diagonal-weight routes below are reachable through `solve!`.

- **Routes at the single scale.** Start `2I` (or `θ = 2`), `maxiter = 100`, `ftol = 0`. Every row was reproduced at the head `76077c98` of pull request [#483](https://github.com/mlakolar/ProximalSolvers.jl/pull/483), which accepts a positive diagonal weight. The first row was also reproduced on master, where [PGD-06](@ref) requires zero diagonal weights, and so was the Float32 row below it.

  | Case | Data | `gradtol` | Returned point | Optimum | `converged` | Reported score |
  |---|---|---|---|---|---|---|
  | Zero diagonal weight, PSD `S`, Float64 | `S = [1 0.1; 0.1 1]`, off-diagonal `C = 1e9`, diagonal `C = 0` | `5e-10` | `Θ₁₁ = 1.5`, one step | `I` | true | `3.3e-10` |
  | Same, Float32 | off-diagonal `C = 1e4` | 0 (floor `64eps`) | `Θ₁₁ = 1.0238` | `I` | true | `2.3e-6` |
  | Positive diagonal weight, indefinite `S`, Float64 | `S = -2^32`, `C = 2^32 + 1` | `5e-10` | `θ = 1.5`, one step | 1 | true | `7.8e-11` |
  | Covariance-shift form | `Sshift = S + C = 1`, `Cshift = 0`, Float64 | `5e-10` | `1 + 9.4e-14` | 1 | true | `9.4e-14` |
  | Positive diagonal, Float32 | `S = -2^16`, `C = 2^16 + 1` | 0 | `θ = 1.5` | 1 | true | `5.1e-6` |
  | Positive diagonal, Float32 | `S = -4096`, `C = 4097` | 0 | `θ ≈ 1.024` | 1 | true | `5.7e-6` |
  | Positive diagonal, Float64 | `S = -1000`, `C = 1001` | `5e-10` | `θ ≈ 1 + 3.1e-7` | 1 | true | `3.1e-10` |

  At `θ = 1.5` in the third row the unnormalized residual is `|S + C - 1/θ| = 1/3` and the scale is about `2^32`. In the first row the off-diagonal penalty `1e9` suppresses an order-one diagonal violation.
- **Wider than the table.** With `S = [1 0.1; 0.1 1]`, Float64 `λ0 = 1e8` stopped at `θ₁₁ = 1.0238`, and Float32 `λ0 = 100` stopped `5.5e-4` from the optimum. Raising `maxiter` to 20000 changed nothing.
- **Seeded problems with large weights.** Positive semidefinite problems with a few structural-zero weights at `1e6`, or adaptive weights `0.05/|θ̃ᵢⱼ|` capped at `1e4`, `1e6` or `1e8`, 48 problems per precision. The single scale returned `converged = true` at a point whose BigFloat per-entry score, rule F below, exceeded `100 g_tol` in 23 of 48 problems (Float32) and 24 of 48 (Float64).
- **Cancellation in the numerator.** With the representable Float64 inputs `S = -2^51`, `C = 2^51 + 1`, `θ = 1.25`, the order `(S - inv(θ)) + C` gave `0.0` and `(S + C) - inv(θ)` gave about `0.2`. This is IEEE arithmetic on a scalar, not a completed solve. A change of the denominator alone cannot recover a numerator that has been rounded to zero.
- **Two routes found while the plan was critiqued, both measured on master.**
  1. Indefinite `S` with an off-diagonal entry that cancels its penalty. Float64 `S = [1 1e9; 1e9 1]`, `C₁₂ = 1e9 - 0.4`: the single scale converged after one step, 26% from the optimum `inv([1 0.4; 0.4 1])`. Float32 with `S₁₂ = 2¹⁶` behaved the same.
  2. One large variance, no penalty. Float64 `S = diag(1e9, 1.4)` converged at `θ₂₂ = 1` against an optimum of 0.714, and Float32 `S = diag(1e5, 1.5)` at `θ₂₂ = 1` against 0.667. PGD itself makes almost no progress on `θ₂₂` here, because its step is limited by the curvature in `θ₁₁`.
- **Options compared.** Every option kept the violations and `g_tol = max(gradtol, 64eps(T))`; only the denominator changed. Write `a = diag(S + C)`. "Ordinary" means 4 seeds × `p ∈ {5, 10, 20}` × uniform `λ ∈ {0.02, 0.05, 0.1, 0.3}`, plus `λ` at 0.9 to 2 times `λmax`: 48 problems per regime and precision.

  | Rule | Denominator | Routes of the issue | Route 1 (indefinite) | Route 2 (large variance) | Large weights: false certificates, F32 / F64 | Ordinary PSD problems |
  |---|---|---|---|---|---|---|
  | single scale | `max(1, maximum(abs, S), maximum(C))` | certifies far points | certifies | certifies | 23 / 24 of 48 | baseline |
  | A | per entry: diagonal `max(1, \|aᵢ\|)`, off-diagonal `max(1, \|Sᵢⱼ\|, Cᵢⱼ)` | fixed | fixed (stagnated, `converged = false`) | fixed (`converged = false`) | 0 / 0 | F32: 4 of 192 lost, up to 76× more iterations; F64: up to 14.7× |
  | B | `max(1, maximum(abs, S + Diagonal(C)), max off-diagonal C)` | master route not fixed | certifies | certifies | not measured | identical to the single scale |
  | C | `max(1, maximum(abs, S + Diagonal(C)), maximum(abs, inv(Θ)))` | fixed | certifies | certifies | 0 / 0 | identical to the single scale |
  | G | `max(1, maximum(abs, a))` | fixed | fixed (stagnated) | certifies | 0 / 0 | identical to the single scale |
  | F, adopted | per entry `max(1, sqrt(\|aᵢ\| \|aⱼ\|))` | fixed | fixed (stagnated) | fixed (`converged = false`) | 0 / 0 | F32: 1 of 48 lost, up to 23×; F64: up to 1.57× |

  Under the large weights every new rule needed more iterations: the median ratio was 82× in Float32 and 3.2× in Float64, and 21 (Float32) and 27 (Float64) of 48 converged within 20000 iterations. A sweep with variances spread over `10^±1` to `10^±4` converged for 1 of 48 under every rule, so it cannot tell the rules apart. The Float32 losses under rules A and F come from a per-entry score that is stricter than the single scale where `max|S| > 1`. The critique rejected rule C: at a point that passes, its term `maximum(abs, inv(Θ))` does not change a decision beyond rule G's, and its `maximum(abs, S + Diagonal(C))` keeps the off-diagonal `|Sᵢⱼ|` in the scale, which lets route 1 through.
- **Rounding limits that any fixed scale shows.** Where `|Sᵢⱼ|` or `Cᵢⱼ` is much larger than the scale, the computed violation has an absolute rounding error of about `eps(T) max(|Sᵢⱼ|, Cᵢⱼ)`. The threshold can then be out of reach, and the solve ends by stagnation or at the iteration limit with `converged = false`. The computed violation can also be exactly 0 while the true one is not: `fl(S - 1/θ) = -C` holds over a band of `θ`.
- **What `test/logdet_kkt_scale.jl` measured.** On Julia 1.10.13 and 1.13.4, each result compared with a 256-bit BigFloat score from the stored data at the returned point. The fixed points and the stop rule are checked against the definition of [PGD-08](@ref), with an allowance for the rounding of the computed score.
  - Heterogeneous weights: 27 seeded problems per precision, with `p ∈ {5, 8, 10}`, three seeds, and structural weights `1e6` or block-structured adaptive weights capped at `1e4` and `1e6`. Within 20000 iterations, 11 of 27 reached the stop in Float32 on both versions, and 15 (1.10.13) and 13 (1.13.4) of 27 in Float64. None stagnated and no converged solve exceeded the bound. The largest difference between `g_residual` and the BigFloat score was 0.08 of its allowance.
  - Diagonal weights, `1 × 1` with `S + C = 1` (Float64 `S = -2^32`, `C = 2^32 + 1` and `S = -1000`, `C = 1001`; Float32 `S = -2^16`, `C = 2^16 + 1` and `S = -4096`, `C = 4097`), start `θ = 2`, `maxiter = 100`, `ftol = 0`, Julia 1.13.4: each solve converged in 4 to 6 iterations at `θ` within `1.2e-13` of 1, where the single scale had converged at `θ = 1.5`, `1 + 3.1e-7`, `1.5` and `1.024`. The start score at `θ = 1.5` was `0.33333333333333315` (Float64) and `0.3333333730697632` (Float32), the definition being `1/3`.
  - The `2^51` numerator through `solve!` (`S = -2^51`, `C = 2^51 + 1`, `θ = 1.25`; Float32 with `2^22`): `g_residual` was `0.20000000000000007` in Float64 and `0.20000004768371582` in Float32, and `G + C` was `0.0` in both.
  - Covariance shift: for the four `1 × 1` cases and for a `3 × 3` positive-semidefinite `S` with positive diagonal weights, the direct and the shifted formulations gave the same start score (difference 0 in both precisions), and both solves converged. Their points differed by `3.3e-16` (Float64) and `1.3e-6` (Float32) in the `3 × 3` case.
  - Ordinary problems (`p ∈ {6, 10}`, uniform and moderately varied weights): 6 of 6 converged in each precision on both versions.
  - Allocation of a warmed call of the evaluation, with the factor already in the scratch matrix, for `p = 12` and `p = 36`: 0 bytes on Julia 1.13.4 in both evaluation paths, and 16 bytes on Julia 1.10.13, where master's evaluation also reported 16 bytes.
  - Against the source of master `fa6e31c6`, the same file reported 233 failures and 151 errors among 665 tests on each version; the errors are calls to helpers that master does not have. In the heterogeneous testset, 53 of the 54 solves returned `converged = true` at a point whose BigFloat score exceeded the bound. On the master route in Float64, master reported `g_residual = 3.3e-10` at `Θ = 1.5I`, where the definition gives `1/3`, and its solve from `2I` returned a point `0.5` from the optimum `I`.

**Applies to.** Matrix PGD with `LogDetLoss` and matrix-weighted `NormL1` ([PGD-06](@ref)).

**Code.** `src/solvers/logdet_proximal_gradient.jl`: `_logdet_pgd_preflight`, `_logdet_pgd_cancellation`, `_logdet_pgd_kkt`, `_logdet_pgd_kkt!`.

**Tests.** `test/logdet_kkt_scale.jl` and the independent score in `test/pgd_graphical_lasso.jl`.

**Sources.** [Issue #492](https://github.com/mlakolar/ProximalSolvers.jl/issues/492), in particular the [options comparison](https://github.com/mlakolar/ProximalSolvers.jl/issues/492#issuecomment-7058438878).
