# #155 confirmation round — preregistered protocol

Written 2026-11-18, before any held-out problem was generated or solved. Its SHA256 is recorded in
`protocol.sha256` and in `state.md`. Nothing below is changed after held-out outcomes are seen; a defect
that invalidates the protocol is documented as a deviation, not silently fixed.

Revisions: PS `master` eea50923 (prototype branch `worktree-research-155-confirm` on top of it), PB pin
a19c59aa. Main run Julia 1.13.4; focused cross-check Julia 1.10.13.

## 1. Methods compared

All methods start from the base solve: the unmodified production CD solve (`CDSolver()` settings of the
configuration, default `maxpasses = 100_000`). A run is **triggered** when the base solve stops
uncertified through `_stop_check!` (`converged = false` with the uncertified flag; a `maxpasses` stop
is not a trigger). Only triggered runs enter the fallback comparison. Let `base` = base passes,
`x0` = the stuck point.

**Budget (all fallbacks):** `B = min(maxpasses − base, max(2000, 20·base))` work units, one total
budget, never reset per stage. One CD pass (full or active) = 1 unit; one PDHG iteration = 1 unit
(2 matrix-vector products). Matrix-vector counts and wall time are reported alongside.

**M0 — existing CD, no recovery.** The base result.

**M1 — D2, production bounds (the candidate).** Inside the package (prototype):
- In-step smoothing: the coordinate step minimizes `√(‖r_k − X_k z‖² + δ²) + λ|z|`, i.e. ρ² → ρ² + δ²
  and d² → d² + δ² in `_sqrt_minimizer`; the scaled off-range branch adds δ (scaled with the
  residual) and has no r = 0 early return when δ > 0. δ = 0 is the production step.
- Stage solves reuse the CD loop with the caller's order/momentum/rng/tol and `maxpasses` = the
  remaining budget. A stage stops at the first converged full pass (no certificate, no tightening).
  The polish solve is the unmodified production solve (δ = 0, its own certificate and tightenings).
- After `x0` and after every stage and the polish: the production `_certify!` at the current point,
  extended only to expose `D_lo` (its dual lower bound, when positive and finite), `P_up` and `P_lo`
  (its rigorous bounds on P at the point, also at r̂ = 0). Bank `D = max` of all valid `D_lo` so far.
- Schedule: `δ₀ = F̂(x0)`, `δ_{j+1} = min(δ_j/5, F̂best)`, at most 8 stages, then one polish.
  `F̂ = P_up` (rigorous Float64 upper bound of P at a point); `F̂best` = minimum over x0 and all
  stage points so far. δ is rounded to T for the step.
- Return rule (checked after each stage and after the polish, in this order):
  1. `ratio(P_up(x0), D) ≤ prevfloat(1e-4)` → return x0 unchanged, certified.
  2. `ratio(P_up(β), D) ≤ prevfloat(1e-4)` **and** `P_up(β) < P_lo(x0)` → return β, certified.
  Otherwise continue. When the schedule ends or the budget is exhausted (no further stage or polish
  starts once used ≥ B): return the last point β, uncertified, if `P_up(β) < P_lo(x0)`; else x0,
  uncertified. `ratio(P, D) = up(up(P − D)/D)` for D > 0, else Inf. The returned gap is that ratio.
  `converged = true` only through rules 1–2.
- Storage: one copy of the stuck `SparseIterate` (O(p)), the stage CD states (O(p)); no copy of X.

**M1g — D2, generalized validator (offline reference only).** Identical trajectory; the dual bound at
each point is the archived outward-rounded generalized validator `vcert` (θ̂ = r̂ at the point;
agents/A/lib.jl of the first study), max with the production `D_lo`. Not a production candidate.

**M2 — PDHG (matrix-free primal–dual, Chambolle–Pock), production bounds.** Research harness, in T:
- `min_β f(Xβ) + g(β)`, f(z) = ‖y − z‖, g = λ‖·‖₁. With `L` = 1.01 × (30 power iterations on XᵀX
  from a fixed start, Float64), `ω = ‖y‖/L`, `τ = 0.99 ω/L`, `σ = 0.99/(ω L)`:
  `θ⁺ = Π_{‖·‖≤1}(θ + σ(X β̄ − y))`, `β⁺ = shrink(β − τ Xᵀθ⁺, τλ)`, `β̄ = 2β⁺ − β`; start β = x0, θ = 0.
  One fixed parameter choice, no tuning.
- Every 20 iterations: the production certificate at β (T) → bank, then the same return rules 1–2.
- PDHG runs at most ⌊B/2⌋ iterations, then (if not certified) one production polish CD solve from the
  last PDHG β with the remaining budget, then the checks and the final rule as in M1.
- O(n + p) extra state. Power iterations (60 matvecs) and checks are counted in the matvec column.

**M2g — PDHG, generalized validator (offline reference).** Same, with the bank also fed by `vcert`
at θ̂ = −θ (the PDHG dual iterate) and at θ̂ = r̂.

## 2. Problems

Development examples (may be inspected freely while building the prototype; reported separately as
regression controls): the fixtures A155, A156, AI3 and problems of the first study's matrix with its
original seeds.

Held-out (seeds never used before; generated only after this file is hashed):
- **H-mat** (first-study generators of `scripts/matrix.jl`): N8p20 f ∈ {0.05, 0.2} seeds 9101–9104;
  N40p120 f ∈ {0.05, 0.2} seeds 9201–9203; N100p400 (0.1 λmax) seeds 9301–9302; near-exact
  σ ∈ {1e-7, 1e-4} seeds 9401–9403; ordinary O60p20 seeds 9501–9503; sweep SW f ∈ {0.1, 0.2, 0.3,
  0.4} seeds 9601–9602; C95 seeds 9701–9703; D10 seeds 9801–9803. Starts: 0, X⁺y, oracle + fixed
  perturbation (`start_point`).
- **H-real** (BCW λ/4, `design` of `scripts/realistic.jl`): (n, p) ∈ {(100, 500), (100, 2000),
  (50, 1000), (200, 1000)}, ρ ∈ {0, 0.5, 0.9}, s ∈ {5, 20}, seeds 9901, 9902; start 0.
- **H-cor** (equicorrelated, `corr` of `orch_d2_cor.jl`): n60 p150 k4 σ1 ρ 0.7, f ∈ {0.05, 0.2},
  seeds 9951–9955; start 0.
- **H-small** (noiseless): n40p120 k5 f ∈ {1e-2, 1e-3} seeds 9961–9963; n100p400 k10 f = 1e-3 seed
  9964; start 0.

Each problem in Float64 and Float32 (T.(X), T.(y), T(λ)), and two configurations:
`cyclic-dense` (Vector, `order = :cyclic, momentum = false`) and `random-sparse` (owner
`SparseIterate`, default random order with momentum, `rng = Xoshiro(hash-free fixed seed 7)`).

## 3. Oracle and outcome classes

Oracle as in the first study (`scripts/oracle.jl`): Clarabel primal and dual on the T data, BigFloat
(256-bit) evaluation; `U = P(β*)`, `D = tθ*ᵀy` (θ* scaled to exact feasibility). Records with relative
width (U − D)/D > 1e-6 are reported as oracle-unresolved and excluded from correctness counts.

For a returned point β: `excess = (P(β) − D)/D` (BigFloat). Classes:
1. **correct-certified**: certified and excess ≤ 1e-4;
2. **near-optimal uncertified**: not certified and excess ≤ 1e-4;
3. **nonoptimal**: excess > 1e-4.
**False certification**: certified and the lower bound on the true excess, (P(β) − U)/U, exceeds the
reported ratio. **Improved**: P(β) < P(x0) in BigFloat. **Changed without proved decrease**: β ≠ x0
and not `P_up(β) < P_lo(x0)` (recomputed independently in BigFloat as P(β) ≥ P(x0) is reported too).

## 4. Measurements

Per method × family × T: triggered, certified, near-optimal, nonoptimal, false certifications,
changed-without-decrease, improved, budget exhausted; work median / 90th percentile (upper order
statistic) / max in units, matvecs, seconds; failure modes (which rule ended the run, last stage).

Cross-version: Julia 1.10.13 on H-mat N8p20 and NE, H-cor seeds 9951–9952, and the fixtures; M0 and
M1 only; compare classes with 1.13.4.

Ordinary path: `benchmark/local.jl` square-root lasso cases, master eea50923 against the prototype
with the fallback dormant, plus an A/A (master against a second master copy), interleaved, one
machine. Criterion: no repeatable slowdown > 5% beyond the A/A spread. One round; a second only if a
cell exceeds 5%. This is prototype evidence, not production benchmark evidence.

## 5. Decision rule (from the brief)

GO D2 only if, on held-out triggered runs: 0 false certifications, 0 changed points without proved
decrease, a material gain in certified/near-optimal outcomes over M0 within B, acceptable pass tails,
no ordinary-path slowdown, and a small implementation; GO PDHG if comparable reliability and cost with
less complexity; otherwise NO-GO (keep the documented limitation). M1g/M2g only inform whether the
production bounds lose coverage; they are not candidates.
