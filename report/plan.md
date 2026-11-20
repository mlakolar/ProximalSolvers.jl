## Validation plan (self-approved; research only, no PR)

This follows the execution handoff above and the maintainer's `NormLinf` comparison request. No solver, default, PB pin or test change is made. The issue is the record. Code goes through a PR, Codex and CI only if a later approved change needs it.

**Revisions.** PS `origin/master` `083c2f705b37a285dc433a89676ce4e6a4356dea`; PB pin `e03c6d9659365d54f4e0fba1a9cd54490631eea6` (git-tree-sha1 `8de7a696…`, recorded from the loaded manifest in each output). The pin contains PB #981 (merge `acfb3451`), so the full-point `kkt_violation(NormLinf(λ), ∇f(x), x)` is the merged one. PR #357 is merged (`eea5092`), so the `NormLinf` portion is no longer gated. Julia 1.13.4 and 1.10.13, cluster (Slurm), the CPU kind recorded in each output, single-threaded BLAS, one process per (script, type).

**Reused material.** `study/lib.jl` from `archive/issue-352-evidence` (`e2a5178`) is included unchanged: the deterministic splitmix64 fixtures (11 designs: orthogonal, Gaussian, ρ = 0.95, rank-deficient, two wide, a zero column, column scales 10^±3, tall noiseless, a 1e6 offset, y = 0), the BigFloat (600-bit) helpers and the polish step. The new files are adaptations of `grad.jl`:
- `lib400.jl`: independent BigFloat measures. Weighted lasso: the KKT residual ‖G‖∞ with `cⱼ = λ0 wⱼ`, and a dual value with θ = κ P r, where P projects off the span of the zero-weight columns. ℓ∞: the Euclidean distance from −∇f(x) to λ∂‖x‖∞ (PB's definition, computed by an independent sort-based simplex projection), its ∞-norm, and a dual value with θ = κ r, κ = min(1, λ/‖sXᵀr‖₁). It also builds the references: weighted CD and long PGD/APG candidates, polished exactly on their support or face, with the bounds evaluated independently.
- `wl1.jl`: the PGD/APG sweep for `NormL1(λ0, w)`.
- `linf.jl`: the same sweep for `NormLinf(λ)` (`sweep`), plus a criteria comparison along long trajectories (`traj`).

**Matrix (both precisions, both Julia versions).**
- Weighted ℓ1: 11 fixtures × raw/mean loss × weights {unweighted control, unit, spread 2^[−2,2], spread with two zero weights (one on a true-support coordinate)} × λ0/λ0max ∈ {0, 1e-3, 0.1, 0.5, 1.01, 2} × PGD/APG × options {default, ftol0, gradtol1e-8, strict} × starts {cold, reference, perturbed reference}. That is 11,904 solves per type and version (y = 0 has two levels). λ0max = maxⱼ |∇f(0)ⱼ|/wⱼ over positive weights.
- `NormLinf` sweep: 11 fixtures × 2 losses × λ/‖∇f(0)‖₁ ∈ {0, 1e-3, 0.1, 0.5, 1.01} × PGD/APG × the same 4 option sets × 3 starts.
- `NormLinf` trajectories: cold and perturbed starts, run with `ftol = 0, gradtol = 0, xtol = 1e-300`, increases allowed and `maxiter = 20000`, so that no proposal stops them. At every iterate these criteria are evaluated in `T`:
  - `gen`: the existing STOP-07 mapping residual over `S = max(‖∇f(0)‖∞, ‖∇f(x)‖∞)`.
  - `kkt`: PB's full-point score over the same `S`.
  - `kktl`: the same score over `max(λ, ‖∇f(0)‖₁)`.
  - `gap`: the relative duality gap.
  - `dx`: the iterate change.
  - `df`: the objective change.

  For τ ∈ {1e-3 … 1e-12}, the first iterate where each criterion is below τ gets independent BigFloat measures. The "oracle" iteration is the first with max coefficient error ≤ 1e-4; it is recorded only where the reference is unique (full column rank) and certified (BigFloat gap ≤ 1e-20 relative).

**Pre-registered classification** (as in #352).
- *Contract check*, weighted ℓ1: `converged = true` ⇒ independent `‖G‖∞/S < max(gradtol, 64eps)`. Every exception is listed with its ratio.
- *False convergence*: `converged = true` with the proved lower bound `(F − Fref)/Fref` above the target (1e-8 Float64, 1e-5 Float32). Where the reference is unique, this also counts a max coefficient error above 1e-4.
- *Missed target*: `converged = false` while the proved upper bound `(F − Dref)/Dref` is within the target.
- *Criteria*, for each criterion and τ: how often a fire is within 1e-4 per coordinate and within the objective target; fires before the oracle iteration (premature) and after it (late), with the iteration ratio; and cases that never fire. The gap criterion is not available at λ = 0: θ = κr is then not dual-feasible except at κ = 0.
- Per-check cost of `gen`, `kkt` and `gap`: the operation count, plus one small in-process timing. This is not a benchmark campaign.

**Review.** The handoff asks for Codex and CI only if code changes, so neither runs here. Before the report is posted, a fresh Claude Opus subagent checks the independent measures in `lib400.jl` (formulas, dual feasibility, the face polish) without being given the results.

**Out of scope.** Solver changes, a stopping-options API (to be scoped separately, as the maintainer said), the 165,888-solve #352 suite, and #378's campaign. Existing defects are cross-linked, not refiled.

**Approval (self mode).** Approved as above; execution started.
