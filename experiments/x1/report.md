X1 report: Stage 0 audit of #353, sqrt-lasso CD prototypes X1A and X1B. Nothing committed or pushed, no Pkg operations, no GitHub writes. Both trees still differ from master only in src/cd/sqrtlasso.jl.

Headline: I found no accuracy defect and made no edits. Both prototypes pass all of test/sqrt_lasso.jl except 3 assertions (Float64 out-of-range inputs that are now refused). Float32 behaves like BASE on the one-axis scans, with two extra converged points (the Float32 rows of section 4). Float64 loses a precisely characterised set (section B).

RUN = <RUN>. Raw outputs and scripts are in RUN/experiments/x1/. In what follows, "1.13" is Julia 1.13.4, "1.10" is 1.10.13, "ok" means no throw, and ratio means excess/step_bound.

## 1. Repository tests
- **sqrt_lasso.jl** gives 1408 passed, 0 failed, 3 errored (of 1411) on X1A and X1B, on both 1.13 and 1.10. BASE gives 1411/1411.
- **Errors**, all ArgumentError "coordinate step ... outside the supported range of Float64 ... rescale the data", all class (ii), same on both trees:
  - `test/sqrt_lasso.jl:359`, twice (old = 0 and old = 2^128).
    - Tests: a tiny Float64 column `2^-530·[1,2,-1,.5]` against `r = 2^-400·[1,0,2,-1]`, λ = 2^-531.
    - Magnitudes: ‖X_k‖ = 7.1e-160, computed a = 5.06e-319 (subnormal) against the clean threshold n·floatmin/eps = 4.0e-292 (n = 4).
    - ρ² (≈ 9e-241) is clean. BASE solves it through `_sqrt_offrange_step`.
  - `:363`.
    - Tests: subnormal residual `2^-1060·[1,0,2,-1]` against `xk = [1,2,-1,.5]`.
    - Magnitudes: a = 6.25 (clean), ‖r‖ = 2.0e-319, computed ρ² = 0.0 (underflow) with r ≠ 0, so it is refused.
  - Needed assertion change: Float64 becomes `@test_throws ArgumentError step_once(...)` at those three places. The Float32 branches of the same lines still pass through the widening.
- **Class (i): none.** No assertion calls a deleted helper. Only the comments at lines 297, 298, 354 and 361 name `_sqrt_band_step` and `_sqrt_offrange_step`, and they become stale.
- **Class (iii): none.**
- **Whole suite**, `scripts/test.jl --jobs=4`, about 70 s:

| Run | Pass | Error |
|---|---|---|
| X1B, standard tier, 1.13 | 67768 | 3 (sqrt_lasso only) |
| X1B, full tier, 1.13 | 68212 | 3 (sqrt_lasso only) |
| X1A, full tier, 1.13 | 68212 | 3 (sqrt_lasso only) |
| X1B, full tier, 1.10 | 68257 | 3 (sqrt_lasso only) |

- **Per-file pass counts**, X1B, 1.13, full tier, all other files 0 failed and 0 errored: cd_numerics 24395, group_cd 14727, cd_elasticnet 9668, sparse_cd 1769, core_contracts 876, minimal_core_characterization 1005, aqua 30, naming 5.
- scripts/test.jl goes through `Pkg.test`, which makes a sandbox in the system temp dir (Pkg wrote there, not me). The worktrees stayed clean.

## 2. Step accuracy against BigFloat-512
- **Method.**
  - All three trees were loaded in one process (`trees.jl`) and every case was fed to all three.
  - The reference is computed from the rounded stored inputs (`m.ls.r` is asserted bitwise equal across trees) and compared with `step_bound` from test/sqrt_lasso.jl:305.
  - Families:
    - `ordinary`, `wide_mod` (±75 binades for Float32, ±520 for Float64) and `wide_full` (the whole representable range).
    - `near_parallel` (including exactly parallel), `tiny_d` (r = c·x + δe_n with d² < n·floatmin/eps at ordinary ‖r‖), `lam_near` (λ within ±4 ulp of √a, and within 1e-3 relative).
    - `thresh` (a or ρ² within ×2 of n·floatmin/eps, above and below) and `corner` (ρ² ∈ 1..1e4 × threshold, d² unclean or 0, λ/ra ∈ {.5, .99, .999, 1−4eps}).
    - `far` (cold inputs), `huge_edge` (a and ρ² within 1e-6 of floatmax), `band` (a and ρ² clean, ‖r‖/‖X_k‖² beyond 1e±38 for Float32 or 1e±300 for Float64) and `sub_lam` (subnormal λ).
  - n is drawn from {1, 2, 3, 5, 12, 30, 2000}.
  - Run 1: 1500 cases per family, type and version, seed 1.
  - Run 2: 20000 cases for each of 8 families (ordinary, near_parallel, tiny_d, lam_near, thresh, corner, band, sub_lam), seed 2.
  - 1.10 and 1.13 draw different samples (`hash` differs per version), so together they cover more.
- **Result: 0 cases with ratio > 1 in any tree.** About 356k cases per version, ×3 trees. 0 cases where a prototype is non-finite and BASE is not. The reproducer files `exp2_repro_*` are empty.

Worst ratio, BASE / X1A / X1B (run 1, 1.13; 1.10 is the same pattern), followed by throws:

| family | Float32 | Float64 | throws (F64 base/X1A/X1B) |
|---|---|---|---|
| ordinary | .028/.024/.024 | .020 all | 0/0/0 |
| wide_mod | .019/.018/.019 | .030 all | 0/245/108 |
| wide_full | .089 all | .019/.018/.018 | 737/1185/1146 |
| near_parallel | .016 all | .018 all | 0/0/0 |
| tiny_d | .017 all | .020 all | 0/0/0 |
| lam_near | .016/.020/.020 | .021 all | 0/0/0 |
| thresh | .025/.016/.016 | .029/.016/.016 | 0/850/850 |
| corner | .012/.013/.013 | .013/.012/.012 | 0/0/0 |
| far | .015 all | .0026/0/0 | 1384/1500/1500 |
| huge_edge | .021 all | .022/.015/.015 | 0/194/194 |
| band | 3e-8/4e-9/3e-8 | 3e-17/0/2e-17 | 0/1500/16 |
| sub_lam | .020/.013/.020 | .017/.012/.017 | 0/1397/0 |

- **Run 2** (20000 cases per family): worst ratio ≤ 0.038 for every tree. Float64 throws: thresh 10790 for X1A and X1B; band 20000 for X1A against 212 for X1B; sub_lam 18629 for X1A against 0 for X1B.
- **Float32 throws** (721 wide_full, 1050 far, 7 huge_edge, 7 band) are the same in all three trees: shared LS curvature and response-scale refusals.
- **Float32 non-finite results**: BASE 61 (wide_full) and 76 (far); prototypes 29 and 29. All 29 have a BigFloat minimizer that is itself not representable in Float32, so they are legitimate. The other 32 and 47 of BASE are centre overflow (c = old + b/a overflows while z* is representable). The Float32 widening removes them.
- **Float64 centre overflow in BASE, which contradicts agentA, section C.** BASE returns Inf where z* is representable (23 wide_full, 20 far of 1500; `t4_f64_nonfinite.txt`): for example a = 6.5e-254, b = 3.7e165, ρ² = Inf, so c ≈ 6e418 while z* = 0. Both prototypes throw on these (ρ² unclean).
- **Every prototype throw where BASE is ok matches the inequality.**
  - X1B: only when the computed a or ρ² fails `_clean_sum` with r ≠ 0. 0 unexplained cases.
  - X1A: the same, plus band or threshold exits with a and ρ² clean (137 of 245 in wide_mod, 1484 in band, 1397 in sub_lam, 19788 in the big band run).
  - 0 cases where BASE throws and a prototype is ok.
- **X1B τ-overflow claim is verified** (`exp2b_tau.jl`).
  - Search: 120000 inputs per type with n ∈ {1,2,3,5,30,2000}, a ∈ [thr, thr(1+1e-6)], d² ∈ [ρ²/16, ρ²] with ρ² up to floatmax, λ = prevfloat^k(ra), k = 1..6.
  - Result: 0 non-finite τ. The largest τ/floatmax is 0.354 in Float64 (n=1, a = 1.0021e-292, τ = 6.36e307) and 0.420 in Float32.
  - Analytic corner (n=2, ρ² = floatmax-ulp, λ = prevfloat(ra)): τ = 5.3e307 in Float64 and 1.2e38 in Float32, and the real X1B step returns z = 0.
  - Bound: d/w ≤ √floatmax/(ra√eps) ≤ ½·floatmax·(1+O(eps)), a margin of at least 2.4×.
  - Case I could not break: a, ρ² clean but b rounding to Inf (only within about nε of floatmax). The `huge_edge` family contains it, with no non-finite result and no ratio > 1.
- **Float64 band inputs**: X1B supports them (worst ratio 2.0e-15, equal to BASE; its only throws are 212 of 20000 with ρ² overflow). X1A throws on all of them.
- **X1A loss I did not anticipate** (design consequence, not edited). The band test requires τ = γλ ≥ floatmin even for ordinary data, so Float64 λ < floatmin·p/d is refused: every subnormal or near-floatmin λ (1397 of 1500 `sub_lam`). X1B handles these (ratio ≤ 0.017).

## 3. Whole solves on ordinary data
- **Setup.**
  - Sizes: 20×10, 100×60, 400×40, 30×120 and 1000×200, with λ ∈ {.5, .1, .02}·λmax, in Float32 and Float64.
  - Designs: gauss, AR(.9) correlated, collinear, exact-fit.
  - Solver options: dense cyclic and random, SparseIterate with momentum default, with `momentum=false`, and cyclic, each cold and warm where applicable.
  - Special cases: y = 0, p = 1, n = 1, n = 1 with p = 1, n < p exact, dyadic exact.
  - Totals: 748 configurations × 3 trees on each Julia version.
- **X1A vs BASE: 748/748 bitwise identical** (x, passes, converged, gap, minimum), on 1.13 and 1.10. 0 differences.
  - Caveat: `floor64` (from `_se_norm` instead of `_scaled_norm`) is not bitwise equal to BASE. It differs by ≤ 1e-15 relative in about 40 % of random y (`t3_floor64`). It never changed a solve here.
- **X1B vs BASE**, 1.13 (1.10 is the same pattern):
  - Bitwise identical 64 of 748 (1.10: 69).
  - 0 `converged` changes and 0 throw changes. Outcomes per tree: 500 converged and certified, 248 uncertified (all exact-fit, n<p, collinear or edge designs, identical in all trees), 0 throws.
  - Float64, certified in BASE (248):
    - Relative objective difference: median 0, 90th percentile 2.4e-16, max 4.0e-12 (a collinear or exact-fit case).
    - gauss/corr only (159): ≤ 5.9e-16, passes difference 0 in all 159, gap difference ≤ 3.9e-14.
  - Float32, certified (252):
    - Relative objective difference ≤ 2.1e-7, 184 exactly equal. Gap difference −1.7e-5 .. +1.6e-5.
    - 98 pass counts differ, median 0, 13 with |Δ| > 5, extremes −51 and +278 (random-order Float32 trajectories, both signs, both certified).
  - Uncertified (rows where BASE is `u`): objective difference up to 6.2e-2 in Float32 and 2.6e-3 in Float64, all collinear 30×120 (p > n), all uncertified in both trees.
- **Certificates, every certified result checked independently in BigFloat-256.**
  - Method: a dual point θ = t·r/‖r‖ built from the returned x, with my own exact r, P and θᵀy. Weak duality gives true gap ≤ (P−θᵀy)/θᵀy.
  - Result: in the 1500 grid and special results (1.10: 1470) and in the scan results of section 4, true gap ≤ mine ≤ reported ≤ 1e-4 held every time.
  - Scan counts: Float32 937/939/939 for BASE/X1A/X1B; Float64 6093/5363/5937 (1.13). 0 violations.
  - Worst mine/reported is 0.99999995, so the reported bound is tight.
  - I did not compute P* separately, because it was not needed.

## 4. Outcome scans of public `solve!` (n=30, p=8, λ = 0.3·λmax)
- **Codes**: C = converged and certified, u = returned with converged=false, T = throws. For T: R = prototype refusal ("outside the supported range"), A = "curvature underflows", B = "curvature not finite", S = "step or stopping scale not finite" (shared).
- **Scaling**: s is the exact power-of-two exponent applied to the generating data (‖y0‖ ≈ 5.3, ‖X0_k‖ ≈ 5.4).
- **Julia versions**: 1.10 and 1.13 agree, except for "." entries (unrepresentable data built with `ldexp` from the loaded generator, a 1-binade shift).
- **Float32**:
  - All tree columns agree for y-only, X-only, joint and one-column scans (C for y ∈ 2^[−128, 125], X ∈ 2^[−75, 61], joint [−75, 61]).
  - Opposite-direction scans, y·2^s with X·2^−s: BASE gives S at s = 65, both prototypes give C. In the mirrored scan y·2^−s, X·2^s: BASE S, prototypes C at s = −65 (reported as −65 in the scan listing).
  - These are the only two changes in any scan. T→C only, from the Float32 widening removing centre overflow. No C or u becomes T.
- **Float64** (BASE / X1A / X1B):

| scan | BASE | X1A | X1B |
|---|---|---|---|
| y only | u[−1024,−485]; C[−484,508]; u[509,1021] | R[−1024,−485]; C same; u[509]; R[510,1021] | same as X1A |
| X only | C[−538,509] | R[−539,−485]; C[−484,509] | same as X1A |
| joint | u[−538,−485]; C[−484,508]; u[509] | R[−539,−485]; C same; u[509] | same as X1A |
| one column (col 1 only) | C[−539,509] | R[−539,−486]; C[−485,509] | same as X1A |
| opposite (y·2^s, X·2^−s) | u[−509,−485]; C[−484,508]; u[509,512] | R[−509,−340]; C[−339,342]; R[343,539] | R[−509,−485]; C[−484,484]; R[485,539] |
| opposite2 (y·2^−s, X·2^s) | u[−512,−509]; C[−508,484]; u[485,509] | R[−539,−343]; C[−342,339]; R[340,509] | R[−539,−485]; C[−484,484]; R[485,509] |

  - Outside these ranges BASE already throws A, B or S in all three trees.
  - Nothing changes from T or u to C in Float64.
  - X1B loses C only where a < n·2^−970 (X scale below 2^−485 or above 2^485 in the opposite scans), and u where ρ² is below n·2^−970 or overflows.
  - X1A additionally loses C at roughly ‖r‖/‖X_k‖² beyond 2^±1020: opposite s ∈ [−484, −340] ∪ [343, 508], opposite2 s ∈ [−484, −343] ∪ [340, 484].

## 5. Refusals are transactional
- **How BASE restores x.** `solve!` never touches the caller's x until success.
  - Dense: `_solve_dense!` wraps x in `SparseIterate(x)` (a private copy), and `_run_cd!` runs the whole solve on it. `_copy_dense!` writes back only after success.
  - Owner: `_solve_owner!` works on `copy(x)` and calls `copyto!(x, work)` only after `_run_cd!` returns.
  - solver.jl is untouched in both prototypes, and the refusals are thrown from `coordinate_step!` before `ls.a[k]`, `x[k]` or the residual change.
- **Experiment** (`exp5_txn.jl`, Julia 1.13): 3 scenarios × {dense, owner} × {cold, warm} × {cyclic, random} = 24 runs per tree.
  - Scenarios: column 5 at 2^−520 (BASE solves), the last column 8 at 2^−520 (so the throw comes after 7 successful visits in the pass), column 1 at 2^−1070 (BASE throws).
  - Both prototypes throw in 16 runs each; BASE throws in the 8 curvature runs.
  - The caller's x was unchanged in every throwing run. For the owner path I compared values, `nactive` and the active-coordinate order.

## 6. Allocations (inside functions, warmed; 1.13 / 1.10)
- Ordinary single pass of 40 visits (n=500) and 20 passes: 0 B in all trees, both Julia versions.
- Warmed `solve!`, identical across the three trees:

| case | 1.13 | 1.10 |
|---|---|---|
| Float32 dense cyclic | 14992 B | 15536 B |
| Float64 dense cyclic | 19648 B | 20208 B |
| Float32 sparse random with momentum | 21072 B | 21536 B |
| Float64 sparse random with momentum | 30512 B | 30992 B |

- Cold paths, 2000 visits, same in all trees:
  - Float32 tiny residual, tiny column and huge residual: 0 B total.
  - Float32 r = 0: 0 B.
  - Float64 r = 0: 0 B.
  - Float64 tiny residual and tiny column: 0 B on BASE; X1A and X1B refuse.
- An earlier version of this probe, which resolved the function through the module at run time, showed 32 B/visit in every tree. That was boxing of the harness, not of the solver.

## 7. Hot-path codegen (`coordinate_step!`, `SqrtLSModel{Float64}`, `code_llvm` optimized; `ir/`, `exp7_counts.txt`)
- **Loops and allocations.**
  - `view(m.ls.X, :, k)` appears in the typed IR as a `%new SubArray` (stack constructed). It adds no allocation (0 B measured) and no loop.
  - Loop count is 14 / 14 / 14 for BASE / X1A / X1B on 1.13, with 7 vectorized loops each. On 1.10 it is 13 each, with 4 vector loops.
  - Heap allocation calls in the IR are the same 3 in each tree (exception-throw boxes only).
- **IR counts (Float64, 1.13), BASE / X1A / X1B:**

| scalar op | BASE | X1A | X1B |
|---|---|---|---|
| fdiv | 2 | 2 | 3 |
| sqrt | 4 | 4 | 4 |
| fcmp (whole function) | 28 | 29 | 19 |
| fmul | 13 | 13 | 12 |

- **Fast-path differences:**
  - BASE: the band test (`p ≥ floatmin`, `floatmin ≤ γ ≤ floatmax`, `floatmin ≤ τ ≤ floatmax`: 5 comparisons), τ = γλ, the inlined `prox_block` (threshold γλ0 with the NormL1 weight and infinity checks, then `_shrink_nonneg`), and calls to `_sqrt_band_step` and `_sqrt_offrange_step`.
  - X1A: the same band test and `prox_block`. The `_clean_sum(d2)` test (2 comparisons) in the d² guard is removed and one `iszero(d)` is added. Cold exits go to `_sqrt_cold`.
  - X1B: no band test, no γ, no τ product, no `prox_block`. It adds one division (λ/ra) and one multiplication, and uses `shrink` (max/min). The extra division per visit is one extra divide latency.
- **Indicative timing only** (shared machine, one process, interleaved, 1.13, median ns per visit; the orchestrator's controlled timing supersedes it):

| size | Float32 BASE / X1A / X1B | Float64 BASE / X1A / X1B |
|---|---|---|
| n=20, p=10 | 8.4 / 9.9 / 8.3 | 18.2 / 18.9 / 15.0 |
| n=100, p=60 | 23.3 / 24.3 / 23.3 | 24.0 / 25.1 / 23.8 |
| n=500, p=40 | 30.6 / 31.2 / 31.4 | 49.7 / 50.3 / 50.5 |

  X1A looks about 3 to 18 % slower at small n (Float32 n=20: +18 %). X1B is level or faster.

## (A) Prototype changes
None. `x1a-final.patch` and `x1b-final.patch` are byte-identical to the initial patches (`cmp`).

## (B) Lost cases, relative to BASE (n = column length; thr = n·floatmin/eps)
- **Float32: nothing is lost.** Widening covers every cold input. The refusals that remain are BASE's own shared ones: a not finite, a rounding to 0, response scale not normal. Two scan points gain (section 4).
- **X1B, Float64**, with the computed sums ã = `fl(‖X_k‖²)` and ρ̃² = `fl(‖r‖²)` at the visit. It refuses exactly when ã < thr or ρ̃² < thr (or either is not finite), unless r = 0 exactly with ã clean. Here thr = n·2^−970 ≈ n·1.0e−292, which at n = 30 is ‖·‖ < 2^−485·√n ≈ 1.0e−146·√n.
  - Column: ‖X_k‖ < 1.0e−146·√n, down to where BASE already refuses (a rounds to 0 for ‖X_k‖ ≲ 6e−162 at n = 30). Lost: ‖X_k‖ ∈ [~6e−162, 1.0e−146·√n).
  - Residual: ‖r‖ < 1.0e−146·√n with r ≠ 0 (BASE: C, or u for y), and ‖r‖ ≳ 1.34e154 (√floatmax) where ρ² overflows (BASE: u, up to its own refusal at ‖y‖ ≳ 2^1022). At the first pass ‖r‖ = ‖y‖.
  - Float64 band cases with clean a and ρ² are not lost.
- **X1A, Float64** also refuses band exits with clean a and ρ²:
  - γ = d/(ra·√(ra−λ)·√(ra+λ)) > floatmax or < floatmin, or τ = γλ < floatmin with d ≠ 0 (so any subnormal or near-floatmin λ), or p < floatmin. d = 0 is admitted.
  - In scale terms: ‖r‖/‖X_k‖² beyond about 2^±1020, which is s ∈ [−484, −340] ∪ [343, 508] in the opposite scan.

## (C) Contradictions with RUN/agentA/report.md
1. "0 Float64 centre-overflow cases": BASE does return Inf at extreme Float64 scales (above). The other claims hold: the 1408 assertions pass, and the three failing lines are 359 ×2 and 363.
2. "Float32 identical converged/throws on every one-axis scan": true for his three scans, but my opposite-direction scans show two T→C points at s = ±65 (BASE centre overflow).
3. Line counts differ by design: 251 (X1A) and 244 (X1B) against agentA's 255; this is not a contradiction.
4. The C2 claim "Float64 band: T" is correct for X1A. X1B restores it.
5. Confirmed: ‖X_k‖ ∈ [6e−162, 5.5e−146) and ‖y‖ ≥ 1.3e154 refusal ranges, Float32 0 B allocation, and branches 100 % ordinary on ordinary data (X1A bitwise identical).
6. One comment in the prototype source (sqrtlasso.jl:13–15, `res64`/`rowmag64`) still names `_sqrt_offrange_step`. It is stale in both.

## (D) Verified by execution vs inferred
- **Executed:**
  - Tests in both versions.
  - Step accuracy at 356k cases per version.
  - Whole solves with independent BigFloat certificate checks.
  - Scans with certificate checks.
  - Transactionality.
  - Allocations.
  - IR counts.
  - Both Julia versions for all the above.
- **Inferred:**
  - The ½·floatmax bound on τ/floatmax is analytic plus the 120000-point search. I did not prove a sharp constant.
  - The d ≤ √floatmax step for a recomputed d², which rests on d2 < ρ²/16 triggering the recompute.
  - The FMA effect was not examined here.
- **Doubts:**
  - The b → Inf corner (a ≈ ρ² within about nε of floatmax) found nothing, but it is a measure-zero edge.
  - Timing is indicative only, and the one-process timings were noisy.
  - X1A's +18 % at Float32 n = 20 may be noise or a real extra guard cost; I did not isolate it.
  - A 10-binade n = 30 scan only; other n shift the thresholds by √n.

## (E) Files written (all in RUN/experiments/x1/)
- **Harness:** `trees.jl`, `x1lib.jl`, `t0.jl`.
- **Experiments:**
  - `exp2_families.jl`, `exp2b_tau.jl`, `exp3_solves.jl`, `exp3_analysis.py`.
  - `exp4_scans.jl`, `exp4b_cert.jl`, `exp5_txn.jl`, `exp6_alloc.jl`.
  - `exp7_ir.jl`, `exp7_count.py`, `exp8_indicative_timing.jl`.
  - `t1_classify.jl`, `t3_floor64.jl`, `t4_gen.jl`, `t4_f64_nonfinite.jl`.
- **Raw outputs:**
  - Tests: `t1_sqrt_x1{a,b}_{lts,release}.txt`, `t1_suite_*.txt`, `t1_classify.txt`.
  - Accuracy: `exp2_families_*.txt`, `exp2_big_seed2_*.txt`, `exp2_repro_*.txt` (empty), `exp2b_tau_release.txt`.
  - Whole solves: `exp3_solves_*.txt`, `exp3_rows_*.tsv`, `exp3_analysis_*.txt`.
  - Scans and certificates: `exp4_scans_*.txt`, `exp4b_cert_*.txt`.
  - Other: `exp5_txn_release.txt`, `exp6_alloc_*.txt`, `exp7_counts.txt`, `exp8_indicative_timing_release.txt`, `t3_floor64_*.txt`, `t4_f64_nonfinite.txt`.
  - IR: `ir/` (`.ll`, `.typed`, `.native` per tree, type and Julia version).
- **Patches:** `x1a-final.patch`, `x1b-final.patch` (identical to the initial ones).