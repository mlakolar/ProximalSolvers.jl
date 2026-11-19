## #155 confirmation round: smoothing continuation (D2) vs a primal–dual fallback — final research report

Research only. No production change, no PR, and no new issue. #155 and #156 stay open. This round follows the joint report (https://github.com/mlakolar/ProximalSolvers.jl/issues/155#issuecomment-6992343537) and its proposed confirmation round. Development examples and held-out evaluation are kept separate throughout.

**Decision: GO D2**, scoped as a bounded improvement fallback. It is not an exact-fit solver. On the 583 held-out triggered runs it certified 338 (58%) and improved the objective in 542 (93%), with 0 false certifications and 0 changed points without a proved decrease. In the realistic λ/4 designs it certified 14%, and in the equicorrelated designs 0%. The review found two edge-case defects in the prototype, outside the held-out set; both are fixed and are now requirements of the implementation (see Review).

### Revisions, environment, protocol

| | |
|---|---|
| PS `master` | `eea50923` |
| Prototype | research branch on top of `eea50923`: commit `f06dfaf0` evaluated, plus `9e264a65` with the two edge-case fixes from the review; not proposed for merge |
| PB pin | `a19c59aa` (unchanged) |
| Julia | 1.13.4 (main run), 1.10.13 (focused cross-check) |
| Oracle (offline only) | Clarabel primal and dual, BigFloat (256-bit) evaluation, as in the first study |
| Machine | one 13th-gen Intel Core i5 desktop, 20 threads |

**Preregistration.** `protocol.md` (SHA256 `014d9adc…e7266`) was hashed at 2026-11-19T00:04:31Z, before any held-out problem was generated. It fixes:
- the schedule, budget and return rule;
- the methods, the held-out families and seeds, and the metrics;
- the decision rule.

Nothing was retuned after held-out results were seen. Deviations (a 1.10 cross-check harness defect, the `local.jl` order, the probe used for the sqrt step, and the matrix–vector counts) are listed at the end.

**The common setup** (the same problems, accuracy criteria and budget for every method):
- **Trigger:** the production solve stops uncertified through `_stop_check!` (not at `maxpasses`).
- **Budget:** one total fallback budget, B = min(remaining `maxpasses`, max(2000, 20 × base passes)). It is never reset per stage. One unit is one CD pass or one PDHG iteration (two matrix–vector products).
- **Return rule, for all methods:**
  - x₀ is returned certified if ratio(P_up(x₀), D) ≤ prevfloat(1e-4), where D is the best valid dual bound found so far.
  - A changed point β is returned certified only if ratio(P_up(β), D) ≤ prevfloat(1e-4) **and** P_up(β) < P_lo(x₀).
  - At the end, β is returned uncertified only if P_up(β) < P_lo(x₀); otherwise x₀ is returned with its honest status.

**Methods:**
- **M0:** the current CD solver, with no recovery.
- **M1, D2 with the production bounds (the candidate), in-package:**
  - Smoothing is applied inside the coordinate step (ρ² → ρ² + δ² and d² → d² + δ²). The scaled off-range branch has no r = 0 early return when δ > 0. δ = 0 is bitwise the production step.
  - Stages reuse the CD loop with the caller's order, momentum, rng and tol. Each stage ends at its first converged full pass.
  - The polish solve is the unmodified production solve.
  - `_certify!` is changed only to expose its D_lo and its rigorous P_up and P_lo, including at r̂ = 0. The bank keeps the maximum valid D_lo.
  - Schedule: δ₀ = F̂(x₀) and δⱼ₊₁ = min(δⱼ/5, best F̂ so far), with F̂ = P_up; at most 8 stages, then the polish.
  - Storage: one O(p) copy of the stuck `SparseIterate` and the stage CD states; X is not copied.
- **M1g:** M1, with the bank also fed by the first study's generalized outward-rounded validator (θ̂ = r̂). It is an offline reference only.
- **M2, PDHG (Chambolle–Pock):**
  - Iteration: θ ← Π_{‖·‖≤1}(θ + σ(Xβ̄ − y)), β ← shrink(β − τXᵀθ, τλ), β̄ = 2β⁺ − β.
  - Parameters: ‖X‖ from 30 power iterations (× 1.01), ω = ‖y‖/L, τ = 0.99ω/L, σ = 0.99/(ωL). One fixed choice, not tuned.
  - Start from x₀ and θ = 0, in T. The algorithm needs O(n + p) state; the research harness also makes an O(np) Float64 copy of X and builds a fresh CD model at every certificate check.
  - The production certificate at β every 20 iterations feeds the bank.
  - At most ⌊B/2⌋ iterations, then a production CD polish with the remaining budget.
- **M2g:** M2, with the generalized validator also applied to the PDHG dual iterate and to the residual direction.

**Held-out problems.** All seeds are new: none was used to select or tune D2.
- **H-mat:** the first study's generators with new seeds: N8p20, N40p120, N100p400, near-exact, ordinary O60p20, λ sweep, ρ = 0.95, duplicate columns. Starts: 0, X⁺y, and oracle + perturbation.
- **H-real:** BCW λ/4, four (n, p) shapes, AR ρ ∈ {0, 0.5, 0.9}, s ∈ {5, 20}, two seeds; cold start.
- **H-cor:** equicorrelated ρ = 0.7, n60 p150, 0.05 and 0.2 λmax, five seeds.
- **H-small:** noiseless n40p120 at 1e-2 and 1e-3 λmax, and n100p400 at 1e-3 λmax.

Every problem is run in Float32 and Float64 and in two configurations: `cyclic-dense` (`Vector`, cyclic, no momentum) and `random-sparse` (owner `SparseIterate`, random order with momentum).

Totals: 752 base solves, of which 583 held-out runs triggered, plus 16 triggered development-fixture runs. All 214 oracle records are resolved; the widest relative band is 1.1e-7.

**Classes:**
- **correct-certified:** certified, and the oracle-based excess (P − D*)/D* ≤ 1e-4. Because D* is a feasible dual lower bound, this is a conservative upper estimate of the true excess; checking both ends of the oracle band changes no class at 1e-4;
- **near-optimal uncertified:** not certified, excess ≤ 1e-4;
- **nonoptimal:** excess > 1e-4.

A *false certification* is a certified point whose proved lower bound on the excess, (P − U*)/U*, exceeds the reported ratio. A quantile qα is the order statistic of rank ⌈αN⌉, so q50 is the ⌈N/2⌉-th value, not an average of the two middle values.

### Evidence

**Held-out triggered runs (583: 294 Float64, 289 Float32).** Work is in units (CD passes, or PDHG iterations + polish passes), and seconds cover the fallback only.

| method | certified (correct) | near-opt uncertified | nonoptimal | false cert. | changed w/o proved decrease | worse than x₀ | improved | budget exhausted | work q50 / q90 / max | seconds q50 / q90 / max |
|---|---|---|---|---|---|---|---|---|---|---|
| M0 (no recovery) | 0 | 43 | 540 | 0 | – | – | – | – | base 28 / 402 / 70,475 | 0.0001 / 0.002 / 1.3 |
| **M1 D2, production bounds** | **338** | 36 | 209 | **0** | **0** | **0** | 542 | 220 | 962 / 5,960 / 33,026 | 0.0004 / 0.027 / 0.34 |
| M1g D2, generalized validator | 338 | 36 | 209 | 0 | 0 | 0 | 542 | 220 | identical to M1 | 0.0006 / 0.046 / 0.54 |
| M2 PDHG, production bounds | 14 | 422 | 147 | 0 | 0 | 0 | 572 | 6 | 1,012 / 4,065 / 47,800 | 0.0017 / 0.058 / 1.2 |
| M2g PDHG, generalized validator | 315 | 121 | 147 | 0 | 0 | 0 | 549 | 4 | 1,007 / 3,991 / 29,525 | 0.0011 / 0.065 / 0.71 |

M1 and M1g agree on all 599 triggered runs in certification, route, returned point and work. **On D2's trajectories the production `_certify!` bounds lose no coverage; the generalized validator was not needed on the tested trajectories.**

**By family (both types). Cells: certified / near-optimal uncertified / nonoptimal; median excess; budget exhausted.**

| family (triggered) | M0 | M1 D2 | M2 PDHG | M2g |
|---|---|---|---|---|
| H-mat (375) | 0 / 39 / 336; 4.2e-1 | **306** / 6 / 63; 4.0e-5; 65 exh. | 14 / 336 / 25; 5.8e-7 | 296 / 54 / 25 |
| H-real λ/4 (160) | 0 / 4 / 156; 3.6e-2 | **22** / 28 / 110; 2.0e-3; 119 exh. | 0 / 72 / 88; 1.4e-4 | 6 / 66 / 88 |
| H-cor ρ = 0.7 (20) | 0 / 0 / 20; 1.4e-1 | **0** / 0 / 20; 5.0e-2; 20 exh. | 0 / 0 / 20; 2.4e-2 | 0 / 0 / 20 |
| H-small (28) | 0 / 0 / 28; 1.2 | 10 / 2 / 16; 2.5e-1; 16 exh. | 0 / 14 / 14; 4.5e-5 | 13 / 1 / 14 |
| dev fixtures A155/A156/AI3 (16) | 0 / 8 / 8 | 16 / 0 / 0 | 8 / 8 / 0 | 16 / 0 / 0 |

**Float32 against Float64** (M1, held-out):
- Float64: 175/294 certified, 16 near-optimal, 103 nonoptimal.
- Float32: 163/289 certified, 20 near-optimal, 106 nonoptimal.

With the production bounds and the bank, Float32 certifies almost as often as Float64.

**#156-type runs.** 43 held-out runs stopped uncertified at an already near-optimal point. D2 certified 39 of them by keeping x₀ unchanged, through the bank; the other 4 moved to a proved-better point but stayed uncertified.

**Cost relative to the base solve** (M1 fallback passes / base passes): median 20×, 90th percentile 200×, maximum 2000× (a 1-pass base stuck at an exact fit, budget 2000). In absolute terms the fallback took at most 0.34 s on these sizes, up to n = 200 and p = 2000.

**Failure modes of D2** (all runs that did not certify, 245 held-out):
- **Budget exhaustion on slow continuation (220 runs).** The smoothed stage solves need hundreds to thousands of passes. Small δ makes the smoothed problem ill-conditioned along the exact-fit set, and CD crawls.
  - Exhaustion came mostly at stage 3–4 for H-real (81 of its 119 exhausted runs; range 2–8), at stage 1–4 for H-cor (20/20), at stage 3–6 for H-mat (65), and at stage 1 itself for H-small (16/28).
  - Examples: N8p20 at 0.05 λmax spends 2000 passes on an 8 × 20 problem by stage 3. Smoothing makes CD escape, but slowly.
- **No silent failures.** Every uncertified return is honest (`converged = false`, `gap = NaN`), and every changed point has a proved decrease. Their honest ratios: q10 1.6e-4, median 3.4e-3, q90 8.2e-2.
- As a numerical check of the smoothed step (a diagnostic, not part of the evaluation), it was compared with a 512-bit BigFloat minimizer on 8000 random cases, covering the fast branch, the scaled off-range branch and exact fits. The worst relative objective error was 0.37 eps(T). This check does not replace the rounding analysis that a production version needs.

**PDHG.**
- With the CD polish, PDHG reaches near-optimal points more often (147 nonoptimal against 209) and lower excess in H-real (median 1.4e-4 against 2.0e-3).
- With the production bounds it certifies almost nothing (14/583).
- The tested M2g variant adds generalized validation of both the PDHG dual iterate and the residual direction, and certifies 315/583. This experiment does not separate the contributions of the two sources. Either way, certification needs the generalized validator, which is new certification machinery that the brief rules out for production unless justified.
- It also needs a ‖X‖ estimate, a primal–dual scaling rule and a second iteration loop beside CD. In this harness its fallback wall time was 4.1× D2's at the median and 2.1× at the 90th percentile. That timing includes the matrix conversion and the repeated model allocation, so it is a harness observation, not the cost of a production PDHG.
- PDHG is therefore not less complex than D2, and it is no more reliable at certification. I stopped developing it, per the brief: no tuning and no variants.

**Cross-version (Julia 1.10.13).** Fixtures, N8p20, near-exact, and H-cor seeds 9951–9952; M0 and M1; on the bitwise 1.13 data.
- Classes agree in 400/400 rows, with 0 false certifications and 0 unproved changes on both versions.
- Work agrees in 353/400 rows. It differs in 29 random-sparse and 18 cyclic-dense rows; the causes were not isolated.

**Ordinary path** (prototype measurements, not production benchmark evidence):
- The square-root lasso cases are deferred in the formal harness (`local.jl` refuses them). The sqrt step was therefore timed with the first study's in-process design:
  - master copies `old` and `ctl` (A/A) and prototype copies `new` and `newb`, interleaved at random within each repetition, 2 processes × 30 repetitions;
  - four ordinary sqrt-lasso problems and one least-squares lasso, each × Float32/Float64 × cyclic/default (20 cells), with identical work in every variant;
  - median paired ratios **0.984–1.014** for the prototype, against **0.985–1.026** for A/A; no cell is above 1.05.
- The `local.jl` harness on 16 CD lasso, lasso-B and group-lasso cases (the shared `_run_cd!` hook) gives prototype/master median ratios **0.944–1.010**, against an A/A of 0.938–1.196 (exploratory and noisy).
- No slowdown was detected. The trigger is the uncertified flag the stop check already computes.

### Complexity

- **Prototype:** +114 / −13 lines in `src/cd/` after the review fixes (`sqrtlasso.jl` +112 / −13, `solver.jl` +1, `models.jl` +1), research toggles and logging included:
  - the δ fields and their use in the fast and off-range step, about 12 lines;
  - the P_up, P_lo and D_lo exposure in `_certify!`, about 15 lines, mostly moved;
  - one line for the stage stop in `_stop_check!`;
  - the fallback driver, about 60 lines;
  - the hook, 1 line.
- No new dependency, no factorization, and no new validator: M1 = M1g.
- **Production estimate: about 150–200 source lines.** On top of the prototype, the repository's standard requires:
  - the rounding analysis of the smoothed step (the `step_bound` comment and test cover δ = 0 only);
  - a short proof note for P_up and P_lo (both reuse steps 1, 2 and 5 of the existing proof);
  - docstrings for the changed meaning of `passes` and the uncertified warning.
- About 150–250 test lines. The research toggles (`_FALLBACK`, `_FALLBACK_DUAL`, `_FALLBACK_LOG`) are dropped.
- **Maintenance:**
  - a second stopping mode in the square-root model (the stage stop);
  - the smoothing parameter in a hot kernel (no slowdown detected in the ordinary-path probe);
  - a solver-level behaviour change: every uncertified square-root stop now spends up to B extra passes.

### Remaining limitations (not solved by D2)

- **Realistic λ/4 designs:** 22/160 certified and 110/160 still nonoptimal after the fallback. The fallback improves them (median excess 3.6e-2 → 2.0e-3) but does not solve them within B.
- **Equicorrelated ρ = 0.7 designs:** 0/20 certified, all nonoptimal, all at the budget. The first study needed 4.5e4–1.6e5 passes there.
- **Very small λ (1e-3 λmax) in noiseless p > n:** all 16/16 runs remain nonoptimal, and all exhaust B = 2000 in stage 1. The other 12 H-small runs, at 1e-2 λmax, end 10 certified and 2 near-optimal uncertified.
- **Budget exhaustion is common:** 38% of triggered runs.
- **No finite-budget recovery guarantee.** The claim is bounded improvement with honest status on the tested regimes: synthetic noiseless, near-exact and adversarial exact-fit starts (82% certified), the realistic and correlated designs above, Float32 and Float64, Julia 1.10 and 1.13.
- **Example 09 and the stopping-limits documentation must keep the limitation:** `converged = false` can still mean a nonoptimal exact fit.
- **#156:** a standalone certificate remains declined. D2 certifies the stuck-at-optimum runs it reaches (39/43) with the production bounds, but not all of them.

### Implementation outline (one PR, if approved)

**Source, `src/cd/sqrtlasso.jl`:**
- `δ2::T` and `δ64::Float64` in `SqrtLSModel`.
- ρ² + δ² and d² + δ² in `_sqrt_minimizer`.
- δ in `_sqrt_offrange_step`: scale by the larger of max|r| and δ; no r = 0 return when δ > 0.
- `_stop_check!` returns `:converged` for a stage.
- `_certify!` stores P_up, P_lo and D_lo.
- `_sqrt_fallback!` with the preregistered schedule, budget and return rule.
- From the review: `_certify!` sets P_up = P_lo = 0 and invalidates D_lo at its y = 0, β = 0 early return. The driver starts no stage unless P_up and P_lo are finite and δ₀ = P_up is positive and finite in T; otherwise it keeps x₀ with its uncertified status.

**Source, `src/cd/solver.jl`:** `_uncertified(m) && _fallback!(...)` in `_run_cd!`, with a no-op default in `models.jl`.

**Docs:** `CDSolver` and `CDResults` docstrings (`passes` includes fallback passes within `maxpasses`; a certified changed point is a proved decrease); `docs/src/stopping-limits.md`.

**Tests (`test/sqrt_lasso.jl`, `test/scaled_lasso.jl`):**
- Update the exact-fit assertions that encode today's behaviour (`sqrt_lasso.jl` lines 408–416, 587 and 825; `scaled_lasso.jl` lines 310–311).
- The #155 fixture is certified at β = 0, and the #156 fixture keeps x₀ and certifies it.
- A deterministic hard case ends uncertified, with `converged = false` and `gap = NaN`, and is never worse than x₀.
- Budget accounting: total passes ≤ `maxpasses`; `maxpasses` reached inside the fallback.
- A δ = 0 bitwise-identity check of the step.
- The smoothed step against a BigFloat minimizer (fast and off-range branches).
- Float32 and Float64.
- Regression cases from the review: y = 0 with a nonzero start returns the improved zero point; an exact fit at a scale where P_up overflows (x₀ ~ 1e200) returns x₀ uncertified instead of throwing.

**Example:** rewrite the "Limitation: exact fits" section of `examples/09_square_root_lasso.jl`. The #155 fixture is now resolved; keep a hard case (for example an equicorrelated design at a small λ) as the documented limitation.

**Perf:** as measured here, re-checked once on the final diff.

### Next action

Maintainer approval would authorize **one implementation PR** of D2 as outlined above. It includes:
- the in-step δ, the exposed `_certify!` bounds and the bounded fallback driver;
- the tests;
- the docstring and stopping-limits changes;
- the example 09 update.

It excludes:
- the generalized validator, PDHG, and any combination of fallbacks;
- a separate #156 certificate;
- changes to the schedule or budget beyond this protocol.

The PR would partly address #155: it does not close it, and the limitation stays documented. Without approval, the current documented limitation stands; this round needs no further research.

### Deviations from the protocol

- **1.10 cross-check, first attempt (harness defect).** The 1.10 run regenerated the problems under Julia 1.10, and 102 of 107 differ bitwise from the 1.13 data (BLAS/RNG). Against the 1.13 oracle this showed up as negative "excess" on one family. The attempt was discarded and archived, and the cross-check was rerun on the 1.13 data exported bitwise, with the oracle as an exact text copy. The main 1.13 run is unaffected.
- **`local.jl` order.** The harness was run in the order A1, A2 (A/A), B1, not the planned interleaving A1, B1, A2, because a shell step was refused. It is one round, as preregistered.
- **Ordinary path for the sqrt cases.** These cases are deferred in the formal harness, so the sqrt step was timed with the first study's in-process probe (described above) instead.
- **Matrix–vector counts not collected.** The protocol asked for matrix–vector counts beside work and time. They were not collected for D2, and the PDHG counter is incomplete: it charges one unit per certificate check and one per polish pass, and omits the initial and final certificates. The counters are withdrawn as evidence. The comparison rests on the common budget B, enforced identically in heterogeneous units (CD passes, full or active, and PDHG iterations), and on wall time. A consistent full-matrix-equivalent cost comparison was not made.

### Review

One independent Codex review (GPT-6.1-sol, high reasoning effort): CHANGES REQUESTED, 6 blocking and 3 editorial findings, all addressed above.
- The reviewer independently recomputed all 3,148 main rows and every table, and replayed all 599 triggered D2/M1g pairs; returned points, certification, route and work agree exactly, and the exposed bounds enclose the BigFloat objective of every returned point. It also reproduced the step diagnostic, 8,000 bitwise δ = 0 comparisons with `master`, the perf ranges and the 1.10 data repair. It found no false certification and no outcome-dependent tuning.
- It confirmed that each bank entry bounds the optimum of the original problem: `_certify!` evaluates the original objective and builds a dual point feasible for the original problem, and smoothing only proposes candidate points. It also confirmed the order of the two certification branches and the strict decrease gate.
- Two prototype defects, outside the held-out set:
  1. The y = 0 early return of `_certify!` left stale bounds, so D2 could restore x₀ after reaching the zero objective.
  2. An overflowing P_up gave δ = Inf, which threw where production returns uncertified.

  Both are fixed in `9e264a65` and listed in the outline. Neither can change a held-out result: no held-out problem has y = 0, and a non-finite P_up would have thrown, which never happened. The reviewer's probes now give the improved zero point and an uncertified x₀ respectively.
- Corrected numbers: 93% improved (not 95%), the PDHG wall-time ratios, and the split of the small-λ family. Qualified: PDHG storage and timing, the M2g ablation, the excess estimate, the quantile convention, the cross-version causes. The missing matrix–vector counts are disclosed as a deviation.
- The reviewer's verdict on the decision: after these corrections, GO D2 remains a defensible maintainer choice for a bounded improvement fallback (374/583 certified or near-optimal against M0's 43/583), with the pass tail and the failure families disclosed. GO PDHG is not better supported under the requirement of less complexity at comparable cost, despite its better proximity to the oracle. The draft does not meet every preregistered measurement requirement, because of the matrix–vector counts.

No second round, per the review policy (the remaining changes are editorial, and the two code fixes are verified by the reviewer's own probes).

### Evidence

Scripts, the protocol and its hash, raw TSVs, the oracle records, the prototype diff, the perf data and the review are archived on the research evidence branch (see below). They are not merged to `master`.
