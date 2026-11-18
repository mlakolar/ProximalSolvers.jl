## Joint research report: exact fits in square-root lasso CD (#155 with #156)

Research only. This report changes no production code and opens no PR; no implementation is authorized by it. Both issues stay open for a maintainer decision. Certification details for #156 are summarized separately on #156.

### Revisions and environment

| | |
|---|---|
| PS `master` | `a0a06477` (after #390) |
| PB pin | `a19c59aa723d085d5d7cf5242895bda16eb77214` (unchanged) |
| Julia | 1.13.4 (all experiments), 1.10.13 (fixtures, baseline, a subset of the escape runs) |
| Research-only oracle | JuMP 1.32.1, Clarabel 0.11.1, BigFloat (256 and 512 bits); not proposed as dependencies |
| Code read | `src/cd/sqrtlasso.jl`, `src/cd/solver.jl`, `src/cd/models.jl`, `test/sqrt_lasso.jl`, `examples/problems/square_root_lasso.jl`, `legacy/full:src/cd/sqrtdual.jl` (the historical support/joint witness, not restored) |

Prior work read first: #332 Stage 0 (prototype grid: every uncertified run had an exact-fit optimum), the revised decisions (D6: study #155 and #156 together), the PR #348 run report, #352 (F5: the residual certificate is first order in the KKT error), #353, #104/#110.

### 1. Reproduction on current `master`

Both fixtures behave as described, on Julia 1.13.4 and 1.10.13, Float32 and Float64, dense `Vector` and `SparseIterate`:

- **#155**, `X = [1 1; 0 0.01]`, `y = X*[1, −1]`, `λ = 0.1`, start `[1, −1]`: CD stays at the start after 1 pass, `converged = false`, `gap = NaN`, `minimum = 0.2`; `P(0) = 0.01`. From 0 it is certified at `β = 0`.
- **#156**, `X = [1 2; 0 1]`, `y = [1, 0]`, `λ = 0.1`, from 0 (cyclic): `β = [1, 0]` after 3 passes, `converged = false`, `gap = NaN`; `θ = (0.1, −0.1)` has `‖θ‖ = 0.1414`, `‖Xᵀθ‖∞ = 0.1`, `θᵀy = 0.1 = P(β)`. The certificate returns `:undefined` (r̂ = 0).
- Result fields: `minimizer, minimum, passes, converged, maxchange, tolerance, kkt_checks, gap`. Uncertified ⇒ `converged = false, gap = NaN`.

Code paths a fix would touch: the coordinate step (`_sqrt_minimizer`, `_sqrt_offrange_step`) for an escape by smoothing; `_certify!` (to expose its dual lower bound and a primal upper bound, or to accept another dual candidate); `_stop_check!` / `_run_cd!` (a fallback after an uncertified stop); the exact-fit tests in `test/sqrt_lasso.jl`; and example 09's "Limitation: exact fits" section, which asserts today's behaviour.

### 2. Mathematics (r = y − Xβ = 0, S = supp β, s = sign β_S)

All statements below are proved in the evidence notes and checked numerically.

1. **Optimality.** β is optimal iff some θ has `‖θ‖ ≤ 1`, `X_Sᵀθ = λs`, `‖X_{S^c}ᵀθ‖∞ ≤ λ`. Every such θ has `θᵀy = λ‖β‖₁ = P(β)`, so at an exact fit certification is a feasibility question.
   - The support equations are solvable iff s ⊥ null(X_S). If |S| > rank X_S and a null vector z of X_S has sᵀz < 0, the point is not optimal: β + tz stays an exact fit with a smaller ℓ₁ norm.
   - The solutions form θ₀ + N with θ₀ = (X_Sᵀ)⁺λs and N = range(X_S)^⊥. When rank X_S = n, θ₀ is the only candidate.
   - The feasible set scales with λ. An exact fit is optimal iff it solves basis pursuit and λ ≤ 1/min‖ν‖ over the basis-pursuit dual certificates of (S, s). Exact-fit optimality is therefore a threshold in λ.
2. **A coordinatewise minimum is a weak property.** `F'(β; d) = ‖Xd‖ + λsᵀd_S + λ‖d_{S^c}‖₁`. For single coordinates, F'(β; ±e_j) ≥ 0 for every j iff ‖X_j‖ ≥ λ on S. In exact arithmetic, every exact fit with ‖X_j‖ > λ on S is a fixed point of the CD step (the step returns 0 when λ ≥ ‖X_j‖), however far it is from optimal. The traps in the matrix have 14–20 nonzeros at n = 8.
3. **Minimum-norm certificate = directional lasso.** Let Θ = {θ : Xᵀθ ∈ λ∂‖β‖₁} and G(d) = ½‖Xd‖² + λsᵀd_S + λ‖d_{S^c}‖₁.
   - If Θ is nonempty, τ* = min{‖θ‖ : θ ∈ Θ} satisfies ½τ*² = −min_d G(d), with θ* = −Xd*. At the minimizer, F'(β; d*) = ‖Xd*‖(1 − ‖Xd*‖), so d* is a descent direction iff τ* > 1.
   - If Θ is empty, τ* = +∞ and inf G = −∞. There exists d ∈ null(X) with λ(sᵀd_S + ‖d_{S^c}‖₁) < 0, so d descends. Inconsistent support equations are one sufficient cause; infeasibility can also arise from the off-support inequalities.
   - β is optimal iff τ* ≤ 1.
   - Two numerical checks: on 60 rounded oracle exact-fit optima, τ agrees with Clarabel to 3.8e-7 and θ to 4.1e-6; on 60 random exact-fit points (32 optimal), the test τ* ≤ 1 agrees with an SOCP oracle in 60/60.
4. **Escapes need the residual to grow, and need unbounded blocks.**
   - In #155, det X = 0.01, so there is no null-space move. The descent direction is d = −β, with F' = −0.19, and the exact line minimizer is β = 0 (F = 0.01).
   - For X = I_n, y = 1 and λ ∈ (1/√n, 1/√(n−1)), every block of fewer than n coordinates is non-descent. The needed block size is ⌊1/λ²⌋ + 1, verified by enumeration for n = 2…7. No fixed block size works in general.
5. **One validator for any dual candidate.** For any θ̂, any β and any t ≥ 0 with tθ̂ feasible, the following holds, with both brackets nonnegative:
   `P(β) − tθ̂ᵀy = (‖r‖ − tθ̂ᵀr) + Σ_k (λ|β_k| − tβ_k X_kᵀθ̂)`.
   - The current `_certify!` is the case θ̂ = r̂/‖r̂‖. A 57-line Float64 outward-rounded generalization (which also uses the dual bound t·(θ̂ᵀy)_lo and the ratio (P_up − D_lo)/D_lo) reproduced production's 184-point certified set, with different bounds, and was sound against BigFloat on about 5,000 points and 30,000 fuzz cases.
   - A dual lower bound D_lo found at one point certifies any other point β′ with a proved upper bound P_up(β′): ratio = (P_up(β′) − D_lo)/D_lo.
6. **Smoothing.** F_δ(β) = √(‖r‖² + δ²) + λ‖β‖₁ is the square-root lasso on the augmented data [y; δ], [X; 0ᵀ], and F ≤ F_δ ≤ F + δ.
   - For δ > 0 the loss √(‖r‖² + δ²) is convex and differentiable and the penalty is convex and separable, so coordinatewise optimality gives every coordinate of the global subgradient condition and hence global optimality: CD on F_δ has no exact-fit traps.
   - At the minimizer of F_δ, θ_δ = r_δ/√(‖r_δ‖² + δ²) is dual feasible for F, and F(β_δ) − θ_δᵀy ≤ δ.
   - Mathematically the coordinate step changes only by d² → d² + δ² (and ‖r‖² → ‖r‖² + δ²). At r = 0 the step shrinks the old value instead of keeping it. In the code, the scaled off-range branch would also need its r = 0 early return removed and a safely scaled δ (`_sqrt_offrange_step`).

Three notions are kept separate throughout:
- a coordinatewise minimum (item 2);
- a global optimum (item 1);
- a numerically certified point, which needs a validated θ̂ with error allowances (item 5). Near an exact fit the residual direction is rounding noise, so a different candidate is needed even when the point is optimal.

### 3. Test matrix and baseline

- **Matrix** (preregistered before any candidate ran): 80 problems with fixed seeds.
  - Fixtures: A155, A156, and AI3 (X = I₃, y = 1, λ = 0.65, start y).
  - Noiseless n8p20, n40p120 and n100p400.
  - Near-exact fits with σ = 1e-7 and 1e-4; ordinary n60p20.
  - A λ sweep (0.1–0.4 λmax) across the interpolation threshold; equicorrelated ρ = 0.95; duplicate columns.
  - Starts: 0, the least-norm interpolant X⁺y (an adversarial exact fit), and the oracle optimum plus a fixed perturbation.
  - Both types; cyclic dense and random `SparseIterate`.
- **Oracle:** Clarabel primal and dual, re-evaluated in BigFloat. All 160 records (problem × type) have high-precision reference bands no wider than 6.5e-8 relative (stored as rounded Float64 endpoints; not outward-rounded intervals). An independent 512-bit re-derivation found 0 weak-duality violations, and 44 records re-solved with another formulation agree. 119 of the 160 optima are classified as exact fits (‖r*‖/‖y‖ < 1e-8).

**Baseline (current solver, 948 runs, Julia 1.13.4):**

| outcome | runs |
|---|---|
| certified | 184 (max excess 1.1e-10) |
| false certification | **0** |
| nonoptimal exact-fit stop (#155) | 683 (excess quantiles: min 3.1e-4, median 0.58, max 19) |
| within 1e-4 of optimal but uncertified (#156) | 81 (only 6 have `:undefined`; 75 are `:failed` at a tiny nonzero residual) |

- The least-norm interpolant start traps CD even where the optimum is not an exact fit (SW0.3/0.4, C95). In Float32 it does so even at a residual at the rounding floor rather than exactly 0.
- Restarting from 0 is no remedy: 200 of the 320 cold starts end at nonoptimal exact fits.
- **Julia 1.10.13:** cyclic runs are identical (92/348/34). The random-order runs differ in 17 labels (185/686/77 overall) because `randperm`/`shuffle!` streams differ between 1.10 and 1.13 (`rand` agrees).
- **Residual size does not identify optimal exact fits.** Among uncertified Float32 runs at the rounding floor, 335 are nonoptimal and 37 optimal, with the same median ‖r‖/‖y‖ (9.7e-8 against 9.2e-8). A "residual at floor ⇒ optimal" test would be wrong.

### 4. How serious is #155 in realistic use? (supplementary, preregistered)

**Setup:**
- λ is the Belloni–Chernozhukov–Wang pivotal choice for the unnormalized objective, λ = 1.1 Φ⁻¹(1 − 0.05/(2p)), with columns scaled to ‖X_j‖ = √n.
- Designs are Gaussian, AR(0.5) and AR(0.9), with s ∈ {5, 20} and σ = 1.
- Shapes (n, p): (100, 500), (100, 2000), (50, 1000), (200, 1000); 3 seeds each.
- 864 runs, cold start.

**Results:**

| level | exact-fit optima | outcome |
|---|---|---|
| λ (theory) and λ/2 | 0 of 144 per type at each level | 288/288 certified per type |
| λ/4 (λ/λmax 0.12–0.41) | 120 of 144 per type | all 120 stop at nonoptimal exact fits (excess 8e-4 to 0.75, median 2.9e-2); the other 24 certify |

- #155 does not occur at the theory level in these designs. It appears once λ is a fraction of it, as with prediction-oriented tuning, and is then pervasive.
- A natural cold-start failure also occurs at moderate levels. An equicorrelated (ρ = 0.7) n = 60, p = 150, σ = 1 design at 0.05 λmax gives excess 0.11–0.37 in 7/7 seeds; at 0.2 λmax, 2 of 7 seeds.
- Over 780 ordinary-looking cold-start solves, `_stop_check!` returned `:uncertified` 30 times (3.8%). On n > p with r* ≠ 0 this happened only in Float32 (7/240), where the point was already optimal.

### 5. Escape candidates (#155)

Agent B's comparison table below uses its own regenerated cohort: 763 triggered runs (386 F64, 377 F32). It rebuilt `Xoshiro(7)` per run, whereas the baseline shares one generator, so 14 class labels and 296 random-order points differ from the baseline. For A1, A2, B, C and E an escape was accepted only on a strict decrease of the original objective in Float64 with an error margin; D and D2 exit at the first certified point. Certification in rows A1–D is the production certificate; **the D2 row uses a BigFloat dual bound as a high-precision proxy**, not an outward-rounded certificate.

| candidate | F64 certified (of 386) | F32 certified (of 377) | F64 still nonoptimal |
|---|---|---|---|
| A1: take 0 if F(0) < F(β) | 14 | 6 | 333 |
| A2: full CD solve from 0, keep the better | 28 | 19 | 300 |
| B: best pair in S + exact line search | 2 | 2 | 339 |
| C: directional-lasso direction + exact line search, ≤ 100 escapes | 28 | 19 | 256 |
| E: continuation in λ | 28 | 19 | 39 (304 of 347 end with nnz > n) |
| D: smoothing continuation, production certificate at each stage | 380 | 23 | 0 |
| **D2: smoothing continuation + dual bank** | **386** | **325** | **0** |

- C is the right theory but a slow escape: each exact line search stops at the first breakpoint, one simplex-like pivot per escape. It is useful as an optimality test.
- Restart and block moves fail for the reasons in §2.4 and §3.

**D2 in detail.**
- **Schedule:** δ_j = 0.3·0.2^j·F̂(x₀) for j = 0…7, each stage a production CD solve warm-started from the previous one, then one polish solve on F.
- **Bank:** after each stage, the residual-direction dual lower bound D_j at the stage point; D = max_j D_j.
- **Return rule (as used in the rigorous replay below):** the stuck point x₀ unchanged if (P_up(x₀) − D)/D ≤ 1e-4; else a changed point only on a proved decrease, P_up(new) < P_lo(x₀), certified if (P_up(new) − D)/D ≤ 1e-4; otherwise x₀ with its own status. Smoothing decreases F_δ, not necessarily F, so certification and decrease are tested separately. (Agent B's prototype exits at the first certified point without a decrease test; in one of its runs it returned a certified A156 point with excess 6.0e-5 in place of the optimal x₀.)
- **Float32:** the bank is what makes D2 work. For these Float32 residual-direction candidates, the observed dual error was ≈ 0.3–0.5·u₃₂‖μ‖/‖r‖, accurate only at large δ, while the primal needs small δ; in these runs the two came from different stages.

**Orchestrator re-check with rigorous Float64 bounds.** I reran D2 with the outward-rounded validator of §2.5 in place of the BigFloat bound, the return rule above, and B's schedule, on the exact replay of the baseline's final points (764 triggered runs). The same replay without the decrease gate gave identical rows, and no returned point was worse than its stuck point.

| | F64 (386 triggered) | F32 (378 triggered) |
|---|---|---|
| certified | 386 (348 stage point, 38 x₀ returned unchanged) | 318 (277 stage, 41 x₀) |
| uncertified | 0 | 60, honest ratio 1.04e-4 to 4.7e-4 |
| false certifications | 0 | 0 |
| returned excess ≤ 1e-4 | 386 | 378 |
| fallback passes: median / 90th-percentile run (upper order statistic) / max | 227.5 / 8,803 / 89,268 | 178 / 5,182 / 14,104 |

- Certified within a fallback budget of 500 / 1,000 / 2,000 / 5,000 / 20,000 passes:
  - Float64: 236 / 262 / 309 / 335 / 368;
  - Float32: 262 / 277 / 302 / 318 / 318.
- Agent B's runs (BigFloat proxy bound): optimal exact fits are kept. Started at the rounded oracle optimum, D2 returns the point unchanged in 120/120 F64 runs (all certified) and 118/118 F32 runs (99 certified). It certifies A156 in 46 passes.
- Agent B on Julia 1.10.13 (126 triggered runs per type, BigFloat proxy bound): D2 certified 126 (F64) and 105 (F32). Final classes agree with 1.13 on 282/288 rows.

**Where smoothing fails (adversarial search, 103 Float64 and 97 Float32 fired starts beyond the matrix):**
- **Survived:** X = I_n (n up to 1000), orthogonal and perturbed-orthogonal X, block-diagonal #155 copies, badly scaled columns, y scaled by 2^±66, exact and near-duplicate columns, cancelling pairs, Vandermonde, λ at 0.5–1.2× the interpolation threshold, n = 200 / p = 2000, and eight #156-type problems whose least-norm support dual is infeasible (n up to 200). The returned point was never worse than the stuck point.
- **Small λ (≤ 1e-3 λmax), noiseless n40p120 and n100p400:** no schedule certified. After 1.2e5–2.4e5 passes the excess was still 0.4–1.0. Plain CD from 0 also ends at a dense exact fit there.
- **Equicorrelated ρ = 0.7, n60p150, cold start** (reproduced by me, rigorous D2, B's schedule):
  - 2 of 14 runs certified (F64 seeds 20187, 20188), each after more than 1e5 passes.
  - The other 12 return good points (excess ≤ 4.6e-5, against 1.4e-3 to 0.37 when stuck) but stay uncertified (ratio 1.9e-4 to 7e-3), after 4.5e4–1.6e5 passes. The base solves of the 0.05 λmax cases take 171–324 passes; seed 20191 at 0.2 λmax hit the 20,000-pass cap.
  - The smoothed problem becomes ill-conditioned for δ ≲ 5e-4 P*, where CD stalls.
- **Scale:** δ relative to P(x₀) is a poor scale when P(x₀) ≫ P* (9e6× in one construction). Tracking the best objective found so far fixes it.
- **Unnecessary firing:** on an already-optimal LOWRANK point (κ = 1e10), the fallback needed 32,945 passes where the base solve took 3. On Float32 ordinary problems where the certificate floor is reached, it fires for 52–96 extra passes.

### 6. Performance and complexity (prototype measurements, not production benchmark evidence)

- **Ordinary path.** Two prototypes were timed in one process, with six compiled copies, interleaved, against an A/A control:
  - (i) a runtime field δ² added in the coordinate step;
  - (ii) a compile-time variant (type parameter).
  
  Cases: n60p20, n200p50, n1000p200, and n200p600 with a non-exact-fit optimum; Float32 and Float64; cyclic and default order. Median ratios were 0.985–1.005 for (i) and 0.994–1.006 for (ii), against 0.992–1.007 for A/A. No cell is ≥ 5% slower. At δ = 0 both give bitwise-identical results, and least-squares CD is untouched (ratios 0.996–0.998). Caveat: other jobs ran concurrently, so the min/max spread is wide.
- **Trigger.** The trigger is the uncertified flag `_stop_check!` already computes, so ordinary solves pay nothing.
- **Fallback, with δ inside the step:** O(n + p) extra state, allocated lazily, 0.04–0.37 MB per fallback for n × p up to 500 × 2000. The augmented-data form copies X every stage, so production would need the in-step δ.
- **Estimated code, not prototyped in the source tree** (an estimate, not a validated implementation size; the performance prototype did not complete the off-range branch with δ): about 100–130 lines in `src/cd/`.
  - A δ² field and its use in `_sqrt_minimizer` and `_sqrt_offrange_step`.
  - `_certify!` exposing D_lo and a rigorous P_up.
  - A fallback driver of about 50 lines.
  - No LAPACK and no new dependency.
  
  For comparison, the historical witness (`legacy/full:src/cd/sqrtdual.jl`) is 456 lines with LAPACK `syevr`, error-free transforms and unpenalized projection bounds.

### 7. Certification alternatives (#156)

Summary only; details are on #156.
- A support-equation certificate ("Bcm": Cholesky of the |S|×|S| Gram, a bounded null-space alternating projection, the validator of §2.5; a gate |S_eff| ≤ n on each effective support after dropping, before the Gram factorization, is part of the proposed design but not of the prototype) certifies 75 of the 81 missed points and 119 of the 119 oracle exact-fit optima, with 0 false certifications in 683 nonoptimal controls.
- It helps only where CD already reached the right exact fit, which in the matrix is 77 of the 710 runs on problems with exact-fit optima (the other 633 are nonoptimal stops). In the λ/4 designs of §4 it would certify nothing.
- D2 returns certified answers for all 81 missed baseline cases without a factorization: transfer retains all 38 Float64 and 41 of 43 Float32 original points, while two Float32 cases (SW0.3-s1) require a changed stage point.

### 8. Decision

**#156 (certification), DOCUMENT ONLY now.**
- A standalone certificate does not deliver enough. It rescues the uncommon runs where CD lands on the correct exact fit, but adds a Cholesky, a projection loop and a generalized validator (about 100 lines).
- If #155 is pursued with smoothing, D2 covered these cases in the replay (with the generalized validator; coverage with the production bounds alone is a confirmation-round check).
- If #155 is declined, "Bcm" is the recorded design for a later, separately approved certificate, for example for users who warm-start at a known solution.

**#155 (escape), RESEARCH FURTHER: one bounded confirmation round, then a decision on implementing D2.**
- Among the tested candidates, smoothing continuation with a dual bank was the most effective on the matrix; it has no demonstrated general finite-budget escape guarantee. In one mechanism it also handles the #156 cases of the matrix, and it costs the ordinary path nothing measurable in the prototype.
- Not tested: an iterative primal–dual splitting fallback (soft-thresholding for the ℓ₁ term, projection onto the residual dual unit ball), which also avoids exact-fit coordinate traps with matrix products, O(n + p) state and no factorization. The confirmation round could include it as a comparator.
- It is not yet ready for implementation:
  1. Its schedule was tuned on the same matrix it was scored on.
  2. Its pass cost has a heavy tail, and it fails to certify (while still escaping) on natural equicorrelated designs and at very small λ.
  3. The production form (in-step δ, exposed D_lo/P_up, a budget charged to `maxpasses`) has not been prototyped in the source tree. The rigorous replay used the generalized validator; whether the production `_certify!` bounds alone give the same coverage is a check for the confirmation round.
- Proposed confirmation round, research only. Preregister before running:
  - **Schedule:** δ₀ = F̂(x₀), then δ_{j+1} = min(δ_j/5, best F̂ so far), at most 8 stages, plus a polish solve.
  - **Budget:** for example min(remaining `maxpasses`, max(2,000, 20 × base passes)).
  - **Held-out set:** new seeds of every matrix family, the realistic λ/4 designs, and the equicorrelated and small-λ failures.
  - **Prototype:** the in-step δ in a research worktree, with D_lo/P_up exposed.
  - **Acceptance:** 0 false certifications; a changed point returned only on a proved decrease, P_up(new) < P_lo(x₀); ordinary-path ratios inside A/A on the formal harness; the certified fraction and pass tail reported against the budget for the maintainer to accept.
- **One PR if accepted:** in-step δ + bank + budget + tests + the example 09 update. No separate #156 PR.

**Leave unsupported** under any design:
- Certification of Float32 points whose true relative excess exceeds 1e-4 at the stored precision, and of Float32 points for which no sufficiently accurate witness is found.
- Very small λ (≲ 1e-3 λmax) in noiseless p > n.
- Guaranteed certification of ill-conditioned dense exact-fit optima.
- A general exact-fit certification engine (LP/SOCP, SVD, LAPACK), block-move search, restart heuristics.

Proposed, not filed: the confirmation round above (research); a documentation sentence in example 09 / `docs/src/stopping-limits.md` that exact-fit stops occur when λ is well below the theory level in p > n designs, with the measured λ/4 behaviour.

### 9. Review

Independent Codex review (GPT-6.1-sol, high reasoning effort), two rounds.
- Round 1: CHANGES REQUESTED, 12 findings. The main one was that the earlier return rule did not guarantee a decrease of the original objective. It now requires the proved decrease P_up(new) < P_lo(x₀), and the gated replay gives identical outcomes.
- Round 2: 11 of 12 RESOLVED. The remaining finding: Θ can be empty because of the off-support inequalities even when the support equations are consistent. §3 now uses the reviewer's correction verbatim. The reviewer independently checked the P_lo lower bound and the gate, recomputed the gated D2 table, and found no other error.

### Evidence

[archive link filled at posting]
