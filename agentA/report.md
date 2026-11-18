# Agent A: square-root lasso CD numerics (#353 Stage 0)

**I could not write `RUN/agentA/report.md`.** The Write tool refused ("subagents should return findings as text, not write report files"), and I did not work around it. This message is therefore the full report. All scripts and raw outputs are in `RUN/agentA/` (RUN = `<RUN>`). `<WORK>/ps-353` is untouched (`git status` clean at dac9f4b).

Julia 1.10.13 and 1.13.4 were both used (E5, E6, E6b, E7, E8, E9, E11, E12). Everything else ran on 1.10.13 only. LOC comes from `tools/count_loc.py`. `src/cd/sqrtlasso.jl` is 310 executable lines out of 526 physical, 208 of them comments (97 are the `_certify!` proof, 23 the `_sqrt_offrange_step` comment).

## Top findings
1. **No wrong answer on supported ordinary input.** Evidence:
   - 40,000 random coordinate steps per type and Julia version (wide scales, near-parallel residuals, λ near √a): worst excess/bound 0.119 (Float32) and 0.029 (Float64).
   - 20,000 steps at the edge of the clean range: worst 0.021.
   - 4,822 certificate checks in BigFloat-512: 0 violations.
   - 31 ordinary or degenerate families reproduced bitwise under the proposed change.
2. **The recovery machinery is dead code for ordinary data.** On Gaussian n,p ∈ {20×10, 100×60, 400×40, 30×120} at λ ∈ {0.5, 0.1, 0.02}·λmax, and on noiseless, near-exact-fit and collinear designs, 100% of visits take the ordinary fast path: zero `_sqrt_offrange_step` calls and zero `_sqrt_band_step` calls. It runs only for exact r=0 or an exactly parallel residual (the fast path handles both with one line), or for column norm, residual norm or ‖r‖/‖X_k‖² outside the "clean" range.
3. **`_scaled_norm` (14 lines) duplicates PS's own `_se_norm(Float64, v)` (`image_models.jl:74`)** to 1.6e-15 over 1,567 vectors spanning the full range of both types. It can be deleted with no behaviour change; the sqrt test file still passes 1411/1411. This is class C.
4. **Verdict on Option A vs B: recommend Option C2.**
   - **C2:** delete `_sqrt_offrange_step`, `_sqrt_band_step`, `_sqrt_threshold64` and `_scaled_norm`. Float32 cold exits re-run the *same formula* in Float64 (Float32 cannot leave the Float64 range); Float64 cold exits handle r=0, else refuse with "rescale".
   - **Measured:** 310 → 255 executable lines (−55, −18%), plus about 33 comment lines gone. No PB change, so PB+PS total decreases and nothing moves to PB.
   - **Float32 is unchanged:** identical converged/throws outcomes on every one-axis scan, bitwise parity on the families.
   - **Option B1** (also refuse Float32) saves only 4 more lines and loses plausible Float32 physical-unit inputs. Not recommended.
5. **Julia 1.10 `ldexp` limitation (PB #896): sqrtlasso.jl is exposed** in `_scaled_norm`, `_sqrt_offrange_step` and `_sqrt_threshold64`. On 1.10.13, 2,470 of 200,000 subnormal-range `ldexp` results are off by one spacing; on 1.13.4, 0. It is harmless here (step results identical across versions, E5). Under C2 the only remaining `ldexp` is the exact `ldexp(Float64(n), -969)` in `_certify!`.
6. **FMA contraction is present** in the `@simd` loops of `_certify!`, `_column_dot_rsqr` and `_distance_sqr` on both versions (`vfmadd` found). The proof covers it, and the BigFloat checks ran on the contracted code.

## Ledger
Classes: A shared/keep, B solver-specific/keep, C removable duplication, D missing shared primitive, E low-value recovery, F proof-only text. Format per row: exec lines | call sites | purpose and guarantee | path | PB equivalent | class → action | net savings | correctness | performance | dependencies. Line ranges are at dac9f4b.

- **`SqrtLSModel`, `cdmodel`, forwarders** (`:16-45`, 25 exec)
  - Call sites: `solve.jl` gates, `solver.jl` hooks.
  - Purpose: model state wrapping `LSModel` with s=1; `loss_value` is PB `value_from_residual`.
  - PB equivalent: `leastsquares_data` and `value_from_residual`, public, already used.
  - Class A: keep. Savings 0.
- **`_prepare!`** (`:49-63`, 14 exec)
  - Call site: `solver.jl:508`.
  - Purpose: setup (gt, brackets, floor64 = 16 eps(T)‖y‖, 2×8n work bytes).
  - Class B: keep, but call `_se_norm` instead of `_scaled_norm`.
- **`_scaled_norm`** (`:89-102`, 14 exec)
  - Call sites: `_prepare!:57`, `_sqrt_offrange_step:274`.
  - Purpose: stable value ‖v‖ = s·2^e by `ldexp` scaling.
  - PB equivalent: PS-internal `_se_norm`, same quantity. PB's private `_scaled_norm` (`numerical_kernels.jl:610`) is a different function.
  - Class **C**: delete, use `_se_norm`. Saves 14 executable and 3 comment lines; PS decreases.
  - Evidence: max relative difference 1.6e-15; tests 1411/1411.
- **`_column_dot_rsqr`** (`:105-124`, 20 exec)
  - Call site: `coordinate_step!:152`.
  - Purpose: fused plain sums a, b = X_kᵀr, ρ² = ‖r‖² in T.
  - Path: hot.
  - PB equivalent: none. Nearest is LS `_column_dot` (`leastsquares.jl:38`, same loops without ρ²).
  - Class B: keep. Merging would add an FMA to the LS hot loop. Probe: fused/LS kernel time 0.92-1.35, noise level.
- **`_distance_sqr`** (`:126-133`, 8 exec)
  - Call site: `_sqrt_minimizer:189`.
  - Purpose: d² cancellation guard where d² < ρ²/16.
  - Class B: keep. Without it, 820/4000 (Float32) and 1189/4000 (Float64) nearly parallel steps break the bound, worst 4.4e5×.
- **`_clean_sum`** (`:137`, 1 exec)
  - Call sites: `:181`, `:190`.
  - Purpose: s finite and s ≥ n·floatmin/eps, so underflow changes s by ≤ eps²/2 relative.
  - PB equivalent: private `_squares_normal` (`numerical_kernels.jl:639`), the identical constant without `isfinite`. PS `response_scale` uses a different constant (≥ 4n·floatmin).
  - Class A/B: keep as 1 line. The constant is load-bearing: 4n·floatmin gives violations up to 1152× the bound.
- **`_sqrt_minimizer`** (`:178-198`, 21 exec)
  - Call site: `coordinate_step!:158`.
  - Purpose: the closed-form formula, accurate to (37γ_n+56u)·max(‖ρ‖,‖r‖).
  - Path: hot.
  - PB equivalent: `prox_block` (public, reused).
  - Class B: keep. Under C2, factor into `_sqrt_step(X,r,g,…)` so Float32 can re-enter it in Float64.
  - Performance: per-visit ≈ LS ×0.9-1.2.
- **`_sqrt_band_step`** (`:202-205`, 4 exec)
  - Call sites: `:197`, `:278`.
  - Purpose: shrink with τ from `_sqrt_threshold64`; cold.
  - Class E: delete under C2. Saves 4.
- **`_sqrt_threshold64`** (`:210-217`, 8 exec)
  - Call site: `_sqrt_band_step:203`.
  - Purpose: stable τ via `frexp`/`ldexp`; cold.
  - PB equivalent: none. Same technique, different formula, as LS `_threshold(Float64)` (`leastsquares.jl:153`). LS `_threshold(Float32)` is plain Float64 arithmetic, which is exactly the C2 widening idea.
  - Class E: delete (C2), or keep for Float64 only (C3). Saves 8.
- **`_sqrt_offrange_step`** (`:241-279`, 39 exec)
  - Call sites: `:181`, `:190`.
  - Purpose: whole step in Float64 on power-of-two scaled data, using `res64` as scratch; cold.
  - Class **E**: replace by `_sqrt_cold`: Float32 widening (6 lines), Float64 r=0 else refuse (5 lines). Net −28 executable, −23 comment lines.
  - Performance: when it runs on every visit it is 35-200× slower than the ordinary path. C2's Float32 cold visit is 1.9× faster than today (2.1 vs 4.1 µs at n=500) but allocates 16n bytes per cold visit, avoidable with `res64`/`rowmag64`.
  - Dependencies: PB #366 items 3 and 5; #332 test plan D.
- **`_level_brackets`** (`:70-84`, 15 exec)
  - Call site: `_prepare!:51`.
  - Purpose: rigorous Float64 bracket lo ≤ λ0 ≤ hi for any whitelisted Real type.
  - Class B: keep. Optional 15 → 7 lines (`w==λ0 ? (w,w) : (prevfloat(w), nextfloat(w))`): 0 violations on 4,513 levels on both versions, brackets ≤1 ulp wider. Low value because it edits a proof input.
- **`coordinate_step!`** (`:150-165`, 16 exec)
  - Class B: keep. Reuses LS `_residual_axpy!`, `_flat_column`, `_coordinate_minimizer`. 0 bytes per pass (measured on both versions).
- **`_check_residual`** (`:281-286`, 6 exec)
  - Class B: keep. It is the "refused before the coordinate or residual changes" contract (#348 round 1, test `sqrt_lasso.jl:598`).
- **`_stop_check!`** (`:302-319`, 18 exec) and **`_above_floor`** (`:321-328`, 8 exec): Class B, keep.
- **`_round_up`, `_up`, `_dn`, `_CERT_TARGET`** (`:330-342`, 7 exec): Class B, keep (outward rounding).
- **`_certify!`** (`:441-526`, 86 exec + 97 comment lines)
  - Purpose: rigorous upper bound on (P−P*)/P* ≤ 1e-4 from a residual-direction dual point, with an a priori rounding allowance; once per converged full pass.
  - PB equivalent: none. PB #970 `kkt_violation` is a different object; the maintainer ruled the certificate stays in PS (#332).
  - Class B, plus F for the proof text. Keep. Moving the text to developer docs removes comments only, not logic.

## Option A vs B
**Activation inequalities.** `_clean_sum(s,n)` is `isfinite(s) & s ≥ n·floatmin/eps`, with floatmin/eps = 9.86e-32 (Float32) and 1.00e-292 (Float64).

| Branch | Float32 | Float64 |
|---|---|---|
| column off-range | ‖X_k‖ < 3.14e-16 √n | ‖X_k‖ < 1.00e-146 √n |
| residual small (r=0 included) | ‖r‖ < 3.14e-16 √n | ‖r‖ < 1.00e-146 √n |
| residual big | ‖r‖ ≳ 1.84e19 | ‖r‖ ≳ 1.34e154 |
| recomputed d² unclean | d < 3.14e-16 √n; includes d=0 at ordinary scale | d < 1.00e-146 √n |
| band | ‖r‖/‖X_k‖² ≲ 1e-38 or ≳ 3e38 | ≈ 1e±308 |
| already refused by shared LS checks | a rounds to 0 below ≈1e-22; a overflows at ≥ 1.84e19; response scale not normal outside [1.18e-38, 3.4e38] when relative=true | ≈6e-162 (n=30), 1.34e154, [2.2e-308, 1.8e308] |

**Where the plain fast path really stops being accurate** (E4, fast path without the clean tests, vs BigFloat):
- Float32: ‖r‖ or ‖X_k‖ ≲ 1e-19. The clean threshold of 3e-16√n is about 3 orders of magnitude more conservative.
- Float64: only where squares leave the normal range.
- Without the band path, the "naive" variant fails by up to 1e6× the bound.

**Options built and run as run-time overlays** (fast-path code copied verbatim from `sqrtlasso.jl:178-198`):

| Option | Exec lines | Δ |
|---|---|---|
| A (current) | 310 | 0 |
| A− (`_scaled_norm` → `_se_norm`) | 296 | −14 |
| B1 (all cold exits refuse) | 251 | −59 |
| **C2** (Float32 widens, Float64 refuses) | **255** | **−55** |
| C3 (C2 + keep Float64 band) | ≈267, inferred, not built | ≈ −43 |

**Lost cases** (public `solve!`, n=30, p=8; C = converged and certified, u = `converged=false`, T = throws):

| Range | A today | B1 | C2 |
|---|---|---|---|
| Float32 ‖y‖ ∈ [1.6e-38, 1.2e-15) | C | T | C |
| Float32 ‖y‖ ∈ [2.5e19, 2.3e38] | C | T | C |
| Float32 ‖X_k‖ ∈ [1.5e-22, 1.2e-15) | C | T | C |
| Float32 band (‖r‖/‖X_k‖² beyond 1e±38) | C | T | C |
| Float64 ‖X_k‖ ∈ [6e-162, 5.5e-146) | C | T | **T** |
| Float64 ‖y‖ ∈ [2e-308, 5.5e-146) or ≥ 1.3e154 | **u**: iterate accurate, `gap=NaN`, "stopped without a duality certificate" warning | T | **T** |
| Float64 band (ratio beyond ≈1e±300) | C | T | T |
| inside the clean box, r=0, y=0, exactly parallel, one-hot-like dyadic data | identical (bitwise, 31 families × 2 types) | identical | identical |

- **What a refusal looks like:** `ArgumentError: the coordinate step of coordinate k is outside the supported range of T (...); rescale the data`. It is thrown before any mutation, and the caller `x` is unchanged for dense and owner paths.
- **Physical-unit examples** (Float32):
  - y = 1.6e-19·N(0,1), n=200, p=20: A and C2 converge (objective 5.768508e-18 identical to 7 digits), B1 throws.
  - y = 1e-21, and a femto-scale design X = 1e-17·N(0,1): A and C2 converge, B1 throws.
  - Float64 y = 1e±200: A returns uncertified; C2 and B1 throw.
- **Plausibility, Float32:** the 3e-16√n limit is reached by raw SI-unit data (Coulombs, joules, Planck) or femto-scaled designs. This is unusual for a lasso but not exotic. The sqrt lasso is exactly y-scale invariant, so y ~ 1e-19 is legitimate. This is why C2 keeps Float32 whole.
- **Plausibility, Float64:** 1e-146 and 1e154 are not data. Exact zero residual is the only realistic member, and it is kept.
- **Contract:**
  - PB #366 prefers a simple, bounded recovery that reuses shared machinery, otherwise a clear failure over bespoke multi-stage recovery. Float32 widening qualifies; the Float64 exponent-scaling path does not.
  - PS `numerics.md:700-703` explicitly does not promise end-to-end recovery of every step.
  - The sqrt section (`numerics.md:568-611`) describes the Float64 scaling and stays normative until a maintainer-approved docs PR changes it.
  - `support.md` states no range limit for this loss.
  - #332 Stage 0 test plan D allows "certified, or refused before mutation". PR #348 round 1 chose recovery over the planned refusal. I found no maintainer ruling on whether the recovery itself is wanted; the "keep the derivation" ruling covered only that PR's comment passage.
- **Recommendation:** C2 as a separately approved follow-up (#278 authorised no further CD refactoring; #366 requires approved docs wording).
  - Zero-risk part first: A− (−14 lines).
  - C2 follow-ups: the sqrt section of `numerics.md`; three test assertions at `test/sqrt_lasso.jl:359` (twice) and `:363` (the Float64 tiny-column and subnormal-residual unit cases become refusals); one new refusal test.
  - Under the C2 overlay the other 1,408 assertions of `test/sqrt_lasso.jl` pass unchanged.
  - Not recommended: B1, relaxing the `_clean_sum` constant, or replacing outward rounding in `_certify!` with first-order slack.

## Wrong answers
None demonstrated. Two deliberate limitations, kept separate:
- **Centre overflow, a refusal not a wrong value.** If c = old + b/a overflows T while the exact minimizer is representable, the step returns Inf and `_visit!` refuses the solve.
  - Reproducer: `repro_centre_overflow.jl` (Float32, column norm 8e-23, residual norm 7e16, c = 4.7e38, z* = 0).
  - Frequency: 15-16 of 40,000 wide-scale Float32 trials, 0 Float64.
  - C2 removes it for Float32 as a side effect.
- **Certificate undefined for Float64 ‖r̂‖² < n·2^-969 or non-finite.** Documented; such solves end uncertified, never falsely certified. E6b: `:undefined` below the boundary, `:certified` above it.

## Do-not-change list
1. **`_certify!`, `_up/_dn`, `_round_up`.**
   - 4,822 cases, 2,185 certified, 0 violations on both versions. For each point I rebuilt θ from the code's own r̂ and t in BigFloat-512 and checked feasibility, gap ≥ P − θᵀy, D_lo ≤ θᵀy and ratio ≥ true ratio.
   - The probe is generated verbatim from the source (only the name and the final return changed) and returns identical `(code, ratio)`.
   - Families: solved and perturbed optima; near λmax; fit dwarfing the residual (β up to 2^50); joint and independent 2^s scaling to the range limits; subnormal coefficients; tiny columns; 3,000 mixed-scale coefficients; n=20,000; exact fits with r̂≠0 and rounded-to-zero r̂; an 800-point scan of the 1e-4 boundary per type; levels of 8 types including BigFloat under all four BigFloat rounding modes; sr at 2^-969·n·(1±1e-9).
2. **`_clean_sum` constant:** 4n·floatmin gives violations up to 1152× the bound.
3. **d² guard:** 820/4000 and 1189/4000 violations without it.
4. **`_check_residual`:** a tested contract.
5. **`_column_dot_rsqr`:** time within noise of the LS kernel, 0 bytes.
6. **Float32 recovery:** Float32 physical-unit inputs certify today and still do under C2.
7. **`_level_brackets`:** keep unless the maintainer wants −8 lines.

## Verified vs inferred; open doubts
- **Verified by execution:**
  - Branch census with real-call counters (they agree with the mirrored classifier).
  - Scale grids and one-axis scans of public `solve!`.
  - Per-step excess against a BigFloat closed-form minimizer.
  - Certificate inequalities in BigFloat.
  - `ldexp`/`frexp`/`exponent`/`nextfloat` and level brackets on both Julia versions.
  - FMA in native code.
  - Test-file behaviour under the overlays.
  - Branch coverage by the repo tests: across `test/sqrt_lasso.jl`, offrange is called 39 times, band 21, threshold64 21, `_check_residual` 6.
  - Rough timing and allocation probes.
- **Inferred, not run:** the C3 line count; the proof-margin statement for the 1.10 `ldexp` error (supported only by E5 being identical across versions); implications for the >5% LS gate; compile and precompile effects; that C2's cold-path allocation is avoidable.
- **Open doubts:**
  1. Whether the maintainer counts the Float64 recoveries as part of the #332-approved behaviour. I found no ruling either way.
  2. The conservative `_clean_sum` constant sends nearly parallel residuals with ‖r‖ < 16·3.1e-16√n (Float32) through the cold path: 99% of the 20,000 edge trials. Harmless numerically, irrelevant at ordinary scale.
  3. Timings are single-process probes, not A/A–A/B.

## Files in `RUN/agentA/`
- **Drivers and overlays:** `lib.jl`, `certprobe.jl`, `optB.jl`, `optC.jl`, `optC2.jl`.
- **Mock sources for LOC counting:** `sqrtlasso_B1.jl`, `sqrtlasso_C.jl`, `sqrtlasso_C2.jl`.
- **Experiments `exp1`…`exp20`:** `exp1_ordinary.jl`, `exp2_scale.jl`, `exp3_exactfit.jl`, `exp4_onecol.jl`, `exp5_stress.jl`, `exp6_cert.jl`/`exp6_run.jl`/`exp6b_adv.jl`, `exp7_ldexp.jl`, `exp8_fma.jl`, `exp9_timing.jl`/`exp9b_cold.jl`, `exp10_*.jl`, `exp11_optC.jl`, `exp12_misc.jl`, `exp13_testcov.jl`, `exp14_testC2.jl`, `exp15_phys.jl`, `exp16_edge.jl`, `exp17_alloc.jl`, `exp18_seNorm.jl`, `exp19_parity.jl`, `exp20_txn.jl`.
- **Reproducers and small checks:** `repro_centre_overflow.jl` (output in `repro_centre_overflow_out.txt`), `t17.jl` (`_scaled_norm` vs `_se_norm`).
- **Raw outputs:** `*.txt`, where `_lts` is Julia 1.10.13 and `_rel`/`_release` is 1.13.4.
- **Context copies:** `issue332.txt`, `pr348.txt`, `pb366.txt`, `pb896.txt`, `issue278.txt`.
