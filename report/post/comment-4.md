**Stage 0 report for #353, revision r2 — part 4 of 4: recommendations, Do Not Change, ProximalBase interface, sequence, reproducibility**

## C. Ranked recommendations

### R1. Square-root lasso: one fast formula, Float32 re-run in Float64, Float64 refusal outside the range of the sums — **GO, with a Julia 1.10 timing gate**

**Scope.** `src/cd/sqrtlasso.jl` only. No PB change, no pin change, no change to the certificate, the stop check, scheduling, the RNG or accepted-update semantics.

| | master `dac9f4b` | prototype |
|---|---|---|
| `_sqrt_offrange_step` (power-of-two scaled Float64 step) | 39 exec | deleted |
| `_sqrt_band_step` + `_sqrt_threshold64` (split-exponent threshold) | 12 exec | deleted |
| `_scaled_norm` | 14 exec | deleted; `_prepare!` calls the existing `_se_norm(Float64, y)` |
| `_sqrt_minimizer` | 21 exec, five-comparison band test, `prox_block(gt, c, k, γ)` | 12 exec: `τ = (λ/ra)·(d/(√(ra−λ)·√(ra+λ)))`, `shrink(c, τ)`, no band test |
| cold path | — | `_sqrt_cold`, two methods, 8 exec |
| file total (executable / physical) | 310 / 526 | 244–246 / 426–429 |

Removed: 64–66 executable lines (21 % of the file) and four concepts (the scaled shadow step, the split-exponent threshold, the band test, a third scaled-norm algorithm). Added: one concept, "a Float32 step outside the range is the same formula in Float64", which is the idea `_threshold(::Type{Float32}, …)` in `leastsquares.jl` already uses. The total of PB and PS decreases by the same amount; nothing moves.

**Why the band test can go.** With `a` and `ρ²` passing `_clean_sum` (finite and at least `n·floatmin/eps`), `ra = fl(√a) ≥ √(floatmin/eps)`, `d ≤ √floatmax` and `w = √(ra−λ)·√(ra+λ) ≥ ra·√(eps/2)` for `λ < ra`, so `d/w ≤ √(2·floatmax/floatmin) < floatmax` and `λ/ra < 1`: the product does not overflow, and it underflows only where the exact threshold does. A search over 120,000 inputs per type at that corner found no non-finite `τ` (largest `τ/floatmax` 0.354 in Float64, 0.420 in Float32).

**What changes for callers.**

- *Float32: no accepted input is lost.* Every step that leaves the fast path is re-run in Float64, where the squares of Float32 numbers and their sums stay in the normal range. Two scan points change from a refusal to a certified solve (master's centre `old + b/a` overflows there although the minimizer is representable).
- *Float64: a visit of a column that is not flat is refused* (`ArgumentError`, "rescale the data", before the coordinate or the residual changes) *exactly when one of these holds for the computed sums:* (i) `‖X_k‖² < n·2^-970`, whatever the residual, a zero residual included; (ii) `‖r‖² < n·2^-970` with `r ≠ 0`; (iii) `‖r‖²` is not finite. In norms: `‖X_k‖ < 1.0e-146·√n`, or `0 < ‖r‖ < 1.0e-146·√n`, or `‖r‖ ≳ 1.34e154`. A zero residual with a column in range (the usual exact fit) and `d = 0` (a residual parallel to the column) stay supported, and so do the Float64 band cases (`‖r‖/‖X_k‖²` beyond `1e±300` with both sums in range). A flat column takes the penalty's minimizer before this test, as on master.
- What master returns in the refused Float64 ranges today (public `solve!`, n = 30, p = 8, exact power-of-two rescalings):

| Float64 input | master | prototype |
|---|---|---|
| `‖X_k‖ ∈ [~6e-162, 1.0e-146·√n)`, residual in range (X scaled by 2^-539…2^-485) | converged, certified | refused |
| the same columns with `y = 0` and a zero start (e.g. `X = fill(1e-150, 2, 1)`, `λ = 1e-151`) | converged, `gap = 0` | refused |
| the same columns at an exact fit with a nonzero start (`y = X·1`, start 1) | returned unchanged, `converged = false` | refused |
| `‖y‖ < 1.0e-146·√n` (y scaled by 2^-1024…2^-485) | returned with `converged = false`, `gap = NaN` (the certificate is undefined there) | refused |
| `‖y‖ ≳ 1.34e154` (y scaled by 2^510…2^1021) | returned with `converged = false`, `gap = NaN` | refused |
| everything else | unchanged outcome class | |

So for an extreme `y` the recovery machinery already cannot produce a converged result; the tiny-column range changes from certified (or, at an exact fit, returned) to refused. The rows with `y = 0` and with an exact fit were found by the independent review and reproduced on both Julia versions.

**Correctness evidence** (Julia 1.10.13 and 1.13.4, Float32 and Float64, master and both prototypes loaded in one process on identical inputs).

- Coordinate steps against a BigFloat-512 closed-form minimizer on the rounded stored inputs, compared with `step_bound` of `test/sqrt_lasso.jl:305`: about 356,000 cases per Julia version in 12 families (ordinary, wide scales, nearly and exactly parallel residuals, an unclean recomputed `d²`, `λ` within 4 ulp of `√a`, sums within a factor 2 of the clean threshold, the corner "`ρ²` near the threshold, `d²` unclean, `λ/ra` up to `1 − 4 eps`", cold Float32 inputs, Float64 band inputs, subnormal `λ`; n from 1 to 2000). **No case exceeds the bound in any tree**; the worst excess/bound is 0.089, the same in the three trees. No prototype result is non-finite where master's is finite. Every prototype refusal where master returns matches the inequality above.
- Whole solves: 748 configurations per Julia version (Gaussian, correlated, collinear and exact-fit designs, five sizes, three levels, cyclic and random order, momentum on and off, dense and `SparseIterate`, cold and warm, `y = 0`, `p = 1`, `n = 1`). No change of `converged` and no new refusal. Float64, Gaussian and correlated designs: relative objective difference at most 5.9e-16 and identical pass counts. Float32: relative objective difference at most 2.1e-7; total passes over the certified cases 24,539 against 24,280 on 1.13 and 14,321 against 14,398 on 1.10 (single random-order Float32 runs move by −51 to +278 passes, in both directions).
- Every certified result of every tree (grid and scans, about 7,000 per tree and Julia version) rechecked with an independent BigFloat-256 dual point: true gap ≤ reported gap ≤ 1e-4, no violation.
- Repository tests: `test/sqrt_lasso.jl` 1408 of 1411 pass unchanged; the three errors are the Float64 unit cases at lines 359 (twice: column norm 7.1e-160) and 363 (residual norm 2.0e-319), which become `@test_throws`. Full suite: 68,212 passed, the same three errors.
- Refusals are transactional (24 runs per tree: dense and owner, cold and warm, cyclic and random; the caller's `x` is unchanged). The ordinary pass and the Float32 cold path allocate 0 bytes.
- The PB #896 exposure of this file (`ldexp` into the subnormal range on Julia 1.10) disappears: the only `ldexp` left is an exact one in `_certify!`.

**Performance evidence.** Paired in one process, every side compiled from source, order rotated over 15 rounds, minimum over batches per round, one pinned P-core of an i5-13600K, BLAS at one thread; `base1/base0` is a second copy of master (the A/A control). Entries are the range over cases of the per-case median ratio prototype/master, with the geometric mean.

| workload | Julia | prototype | A/A control |
|---|---|---|---|
| solves: to convergence, and 3 passes from zero (40 cases: 5 sizes × 2 levels × 2 types × 2) | 1.13.4 | 0.923–1.004 (0.978) | 0.995–1.009 |
| | 1.10.13, AVX2 target | 0.942–1.059 (0.992) | 0.983–1.024 |
| | 1.10.13, default target (goldmont on this CPU) | 0.964–1.126 (1.001) | 0.959–1.029 |
| per visit: column kernel + step formula at a fixed state, read-only (20 cases) | 1.13.4 | 0.947–1.039 (0.983) | 0.972–1.005 |
| | 1.10.13, AVX2 target | 1.004–1.106 (1.043) | 0.978–1.038 |
| | 1.10.13, default target | 0.983–1.146 (1.037) | 0.975–1.021 |

On Julia 1.13 the prototype is at parity or faster. **On Julia 1.10 it is not yet within the 5 % rule**: the solve to convergence at n = 30, p = 120, `λ = 0.1 λmax` is slower by 5.9 % (Float32) and 4.0 % (Float64) with the AVX2 target, and by 12.6 % and 7.7 % with the default target, at equal pass counts, and the three-pass solve of the same Float32 case by 5.3 % with the default target; the per-visit probe is slower by 0.4–10.6 % with the AVX2 target and by up to 14.6 % with the default target (Float64, n = 400, p = 40, zero state: 1.146, every one of the 15 rounds between 1.125 and 1.155 against a control between 0.992 and 1.019; 1.119 at the converged state). So the slowdown is not confined to p > n. One contribution is identified: PB's exported `shrink` (the max/min form) takes 4.9 ns in a dependent chain on 1.10 against 4.3 ns for the select form PB uses inside its own prox loops; the rest is not diagnosed. A variant that keeps master's arithmetic bit for bit (`prox_block` and the band test, band exits to the cold path) was also built: it keeps solves within 4.3 % but is 0.5–25 % slower per visit and refuses the Float64 band and every subnormal `λ`, so it is not the recommended form.

**Recommendation: GO**, as its own small PS issue and PR, with these conditions:

1. the Julia 1.10 solve and per-visit ratios are brought inside the A/A control, or the maintainer accepts the measured cost explicitly;
2. the Float64 refusal and the square-root section of `docs/src/numerics.md` (lines 568–611, which describe the scaled step) change in the same approved PR, with the three test assertions and one new refusal test;
3. #352 records the change of the Float64 extreme-`y` outcome from "returned uncertified" to "refused".

If the refusal is not wanted, or the gate cannot be met, the fallback is **R1-min**: delete `_scaled_norm` and call `_se_norm(Float64, ·)` at its two call sites (−13 executable lines net: the 14-line definition goes and the cold caller gains one; one duplicate algorithm fewer; `floor64` moved by at most 1e-15 relative in the 748-solve corpus and by up to 5e-14 at n = 10⁵, where the deleted sequential sum is the less accurate one; no outcome changed in 748 solves, and 2 of 456 targeted tiny-scale Float64 solves moved in the last bits).

Not recommended: refusing the Float32 cold inputs as well (4 more lines; loses Float32 data in physical units such as `y ~ 1e-19`, which certify today), relaxing the `_clean_sum` constant (violations up to 1152× the bound), or replacing the outward rounding in `_certify!`.

### R2. The bit-identical bundle of duplicate helpers — **GO**

One PS PR, 28 executable lines removed, nothing added to PB, no result of `solve!` changed.

| Item | Change | Exec | Evidence | Test edits |
|---|---|---|---|---|
| `Blocks._maxabs_diff` | deleted; `g_residual` of APG and `_se_norm_diff` call `_norm_diff(x, y, Inf)`, the existing forward to PB's public `norm_diff`. The one true duplicate of a supported PB API in the audited scope | −7, one export | 0 mismatches in 10,900 unit cases (NaN, ±Inf, ±0, subnormals, views); the callers pass same-type, same-shape Float32/Float64 arrays, so PB's extra shape and type checks do not change the domain; PB's loop vectorizes like PS's `@simd` loop on 1.13, neither does on 1.10 | none |
| `_frobenius_upper` first loop | calls the existing `_sumsq64` | −3 | 0 mismatches in 8,000 matrices | none |
| `_round_up` | Base `T(v, RoundUp)` | −4 | 0 mismatches in 6,000,068 values per type, both Julia versions | none |
| `_flat_column`, `_flat_group` | `all(iszero, view(…))` | −10 | 0 mismatches in 89,775 (Julia 1.10) and 89,776 (1.13) columns and groups; 0 B | none |
| `_significand_exponent` (two methods) | deleted; `_root_scale` starts from `Float64(α)`. On master an IEEE scale uses its own significand and every other scale, which for `solve!` means the admitted integer and Bool scales, goes through a 256-bit BigFloat conversion. `_check_loss_scale` admits only scales that are exact in Float64, so the conversion is not needed (an IEEE-only method would not do: integer and Bool scales do reach `_root_scale` through APG) | −4 | 0 mismatches in 39,982 admitted scales; `Int128(2)^100` and `true` checked by the reviewer. A BigFloat scale beyond the Float64 range, possible only for a directly constructed `LSModel`, becomes a `DomainError` | `test/cd_numerics.jl:943` (the BigFloat `2^±1500` points) |

Whole-solve fingerprints against master in one process, for exactly these five changes: 4,806 solves on Julia 1.10.13 and 4,794 on 1.13.4 (CD lasso, elastic net, group lasso, square-root lasso; PGD and APG lasso and elastic net; Float32 and Float64; dense and `SparseIterate`; scaled losses with Float32 data and a Float64 or integer scale; warm starts), comparing the minimizer, the objective, the counts, `converged`, the gap and every numeric result field bit for bit: **0 mismatches.** `test/cd_numerics.jl` passes with the one edit (24,400 assertions on both versions). The allocation and timing runs used the six-change tree of r1 (these five and the tier-2 deletion that is now deferred), which is the same code outside `response_scale`: warmed allocations of 26 solve cases equal master's on both versions; per-case median time ratio to master 0.985–1.037 on Julia 1.10 (A/A control 0.993–1.041), 0.990–1.020 with the AVX2 target (control 0.996–1.023), 0.863–1.009 on 1.13 (control 0.857–1.009; the low end is PGD, where all sides including the control are equally faster than the first-compiled copy of master). APG, the only solver whose per-iteration path changes: 0.995–1.010 everywhere.

The first four rows need no test edit and could be merged alone (−24).

### R4. One scaled-norm kernel instead of two parallel families — **GO, optional, after R2**

`_sumsq_scaled`/`_sumsq_scaled_diff`, `_se_norm`/`_se_norm_diff` and `_se_norm_onepass`/`_se_norm_diff_onepass` are three pairs that differ only in "`v[i]`" against "`a[i] − b[i]`". With a two-method accessor (`_diff(a, b, i) = a[i] − b[i]`, `_diff(a, ::Nothing, i) = a[i]`) each pair becomes one function with an optional second operand; the unreachable `isfinite(s)` line of `_se_norm_diff` goes as well. No fake zero array is involved.

- **−17 executable lines** on top of R2 (`image_models.jl` 176 → 159), three function names fewer, one small concept added. The tree that was tested also carried the tier-2 deletion of r1, which does not touch this file.
- Bit-identical: 0 mismatches in 270,000 unit comparisons (NaN, Inf, ±0, subnormal, huge; Float32 data with the Float64 working type that CD uses) and in the 4,806 / 4,794-solve matrix; allocations equal; timing inside the control on all three configurations (0.984–1.020 of master outside the PGD cases noted under R2).
- It renames kernels that the APG certificate's proof comments cite, and #279 kept this layer on purpose. The new evidence is the bit-identity. The proof comments must be re-read against the folded code in the PR, so it is listed as optional and separate from R2.

### R3. Delete `_sqnorm!` — **DEFER to the next change of the group curvature code (#339)**

`_sqnorm!` is a second `Σx²` algorithm (in order, without `@simd`) beside the cold branch of `_column_dot`. `coordinate_scale` can read the curvature cache, which production always fills before the call, and `_singleton_curvature` can use `sum(abs2, view(X, :, j))`.

- −11 executable lines, one concept. Singleton-group solves become faster: per-case median 0.40–1.01 of master, geometric mean 0.77 on Julia 1.13 and 0.85–0.89 on 1.10, because `_prepare!` no longer sums each column in order.
- The majorization margin `nextfloat(a(1 + 2n eps)) ≥ Σx²` holds for every summation order: 768 Float32 and 612–616 Float64 adversarial columns up to n = 2^20, 0 violations, the worst case using 25 % of the margin.
- It is **not bit-identical**: ℓ and the minimizer move in the last bits in 94–97 % of singleton-group solves (objective relative difference ≤ 7e-11 in Float32, 8e-25 in Float64; `converged` and an independent KKT residual unchanged at ordinary tolerances). At a Float32 tolerance below `eps(Float32)` one solve went from 5 passes to the pass limit and another from 21 to 416: last-bit effects at stagnation, in both directions in principle, but observable.
- Twelve test sites change, and a direct `coordinate_scale` call on a cold cache would return NaN unless a one-line fill is kept.

It is valid and small, but it perturbs group-lasso trajectories for 11 lines. It should ride with the next deliberate change of that code rather than be a change of its own.

### NO-GO

| Proposal | Reason | Evidence |
|---|---|---|
| `ProximalBase.NumericalKernels` now, or a separate numerical package | It would move at most 30–40 PS lines (30 in a cold fallback) behind a new supported namespace and make PS's proofs depend on guarantees PB states only in comments. No consumer outside PB and PS. | section E |
| An extended-range type in PB to replace `_SE` | One consumer family; PB+PS total would rise; PB has neither compare nor clipped subtract. The #279 conclusion stands against PB pin and master. | 0/100,000 mismatches in range, different results out of range |
| PB `norm_diff` inside the APG certificate | Same formula, different guarantee: a `T` result loses relative accuracy for a subnormal norm. | 153/4000 and 69/4000 violations of the required level |
| One fused dot kernel for LS and square-root CD | Changes cold-path bits; the Julia 1.10 Float32 cold pass is 1.58–1.96× slower. | caller-shaped pass, old/new/control |
| PB `lipschitz` or `opnorm2` for the group curvature bound | Not upper bounds. | majorization violated in 453/800 groups |
| Refusing LS coordinate steps outside the band (`_exceptional_step`, `_threshold`) | 17 lines; narrows a Float32 domain that #294 widened after 906 false convergences; collides with #350. | 0 hits on ordinary data, exact where it runs |
| Refusing the Float32 cold inputs of the square-root step as well | 4 more lines than R1; loses Float32 data in physical units that certify today. | `y ~ 1e-19`, `X ~ 1e-17` solves |
| The bit-identical form of R1 (keep `prox_block` and the band test) | 0.5–25 % slower per visit; refuses the Float64 band and every subnormal `λ`. | timing table of R1; 19,788 of 20,000 band cases refused |
| `response_scale` through PB's square-root-loss oracle | Allocates the loss's temporary and costs +3–6 % on 2–4 µs solves. | setup probe |
| A closure-based generic `fsum`/`fmax` for the fused reductions | Adds an abstraction that #279 declined; bit-identical only in isolation, untested inside the solvers. | isolation probe |

### DEFER (valid, not needed for current Float32/Float64 workloads)

- **R3**, above.
- **Dropping tier 2 of `response_scale`** (−7 executable lines, three test edits; in the GO bundle of r1, moved here after the review). Tier 2 serves Float32 data with a Float64 loss scale whose `αΣy²` leaves the Float32 normal range, which `solve!` admits. In the sweep, 7,229 of the tier-2 inputs carry an admitted scale and 3,110 of them change, by up to 42 Float32 ulps, toward the exact value (old error up to 41.9 ulp, new at most 0.5 ulp); the branch then makes two scans of `y` instead of one. But at the boundary of the Float32 normal range the more accurate value can fall on the other side: for `y = fill(1f-18, 100)`, `X = ones(Float32, 100, 1)` and the scale `floatmin(Float32)²/Σy²`, master returns `converged = true` and the changed code refuses the response scale (reproduced on both Julia versions). `docs/src/numerics.md:34-39` allows a boundary rounding to land on either side, so this is a documented kind of change, but it is an acceptance change that needs its own ruling and boundary tests, for 7 lines.
- `response_scale` as a single `_SE` path (−21): changes the stopping scale in the last bits in about 35 % of cases, and carries the same boundary question.
- A supported PB name for `_residual_squares`, `_sumabs2_diff` or `_squares_normal` (PB #698): see the thresholds in section E.
- Moving proof text to developer docs (class F): the 97-line comment of `_certify!`, and about 100 comment lines of `_curvature_deferrable`, `_gram_curvature` and the group step that repeat `docs/src/numerics.md:415-600`. No executable effect; the group-CD duplication is the better candidate, since the text exists twice.
- A 7-line `_level_brackets`: correct on 4,513 levels, but it edits an input of the certificate proof for 8 lines.
- PB housekeeping, for #698: the uncalled `_scaled_dot`; the slower max/min form of the exported `shrink`.

## D. Do Not Change

Each entry was checked against current code (PS `dac9f4b`, PB pin `a19c59aa`, PB master `13891ccf`), not only against the earlier rulings.

| Mechanism | Why it stays | Evidence |
|---|---|---|
| `_SE`, `_se_mul` (fixed arities), `_se_le`, `_se_add`, `_se_sub`, `_renormal` in PS | PB has no extended-range scalar with add, clipped subtract and compare; its private cousins carry a product (`_parts_product`, `_ProjectionScale`) or a compensated accumulator (`_ExpSum`) and return one value of `T`. The #279 conclusion stands. | `_se_mul` equals `_parts_product` bit for bit in range (0/100,000), but `2^900·2^900` is `Inf` in PB and `(1.0, 1800)` in `_SE`; each `_SE` operation ≤ 1.00 u over 200,000 pairs per type; warmed APG `update_state!` 0 B on 1.10 and 1.13 |
| `_bound_certified!`, `_BoundConstants`, `_bound_constants`, `_image_error_bound`, `_check_bound_size`, `_unit`, `_gamma` | They encode PS's matrix-product error model and operation counts (the γ's, the κ = 32u budget, the underflow terms). No arithmetic interface changes that. | ~22,000 decisions per Julia version on an L grid and ~15,000 accepted trials of 132 real solves rechecked in BigFloat-512: 0 violations; ≥ 27 u of the 32 u budget unused |
| APG's certified early reject and the fresh-product fallback | Performance and soundness of the accept test. | the early reject ends 20 % (Float32) and 23 % (Float64) of ordinary trials without a product; the fresh product is needed in 22 % of ordinary Float32 trials and 0 % of Float64 ones |
| `_frobenius_upper` | The one helper in the APG chain that is one-sided by construction; PB's `opnorm2`, `lipschitz`, `_opnorm_upper` are spectral estimates documented as not certified. | 290 matrices per type, 0 violations |
| `_se_norm`, `_se_norm_diff`, `_se_norm_onepass`, `_se_norm_diff_onepass`, `_sumsq2`, `_sumsq_diff` | The APG proof is written for these formulas and thresholds. PB's public `norm_diff` returns a value of `T`: for a subnormal norm it misses the accuracy the proof requires. PB's `_squares_normal` threshold would send small Float32 steps to the cold path. | `norm_diff` as the norm: 153/4000 (Float32) and 69/4000 (Float64) violations of the required level, all at subnormal norms; substituted in the real decision it gave 0 changed decisions in 40,000 only because an underflow term happens to absorb the error, which no PB contract states |
| The fused reductions `_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_stepdiff`, `_sumsq64`, `_step_norms64` and the `Blocks` forwards | Distinct operand shapes without temporaries; the owner seam of #230. A closure-based generic reduction would remove ~40 lines and add an abstraction that #279 declined; it is bit-identical in isolation and untested inside the solvers. | #279/#268 rulings; isolation probe only |
| `_column_dot`, `_column_dot_rsqr` as two kernels; `_residual_axpy!`; the `a`, `r` and ℓ caches | Merging the two dot kernels changes cold-path bits and slows the Julia 1.10 Float32 cold pass by 1.58–1.96×. The caches avoid a 1.2–1.7× slower pass and a Gram plus eigensolve per visit. | caller-shaped pass with old, new and control in one process |
| `_clean_sum`'s constant `n·floatmin/eps`; the `d²` guard `_distance_sqr` | Both are load-bearing for the step bound. | with `4n·floatmin`: excess up to 1152× the bound; without the guard: 820/4000 and 1189/4000 violations |
| `_certify!`, `_up`, `_dn`, `_level_brackets`, `_check_residual`, `_stop_check!`, `_above_floor` | A rigorous certificate with no PB counterpart; the maintainer ruled in #332 that it stays in PS; stopping policy belongs to #352. | 4,822 BigFloat-512 checks, 0 violations |
| LS `_scaled_prox` band, `_outside_band`, `_exceptional_step`, `_threshold` | 17 lines of plain arithmetic that keep Float32 columns with `‖X_k‖ < 1.1e-19` or in `(9.2e18, 1.8e19)` correct; #294 added them after 906 false convergences. A refusal would narrow a domain that was widened on purpose, and #350 adds a method here. | 0 hits in 6,080 ordinary solves; `_threshold` within 0.50 / 0.89 eps |
| `_curvature_scale` (roots first), no reciprocal cache; `_response_scale_exceptional`, `_se_scale` | #293/#295 rulings; the exceptional response scale already reuses `_SE`, `_se_norm`, `_root_scale` inside PS. | — |
| `_gram_curvature`, `_singleton_curvature`'s margin, `_check_step_band`, `_curvature_deferrable`, `_screen_floor`, lazy curvature | PB has no rounded-up spectral bound. The lazy route and the screen are the #326 option B ruling. | PB `lipschitz` violates the majorization in 453/800 groups, `_gram_curvature` in 0/800; 95 % of screen attempts return a zero certificate |
| `_sweep!`, separate `_cd_plain!`/`_cd_momentum!`, the `CDModel` hooks, RNG and traversal order, the transaction (work on a copy, write back on success) | #278 and #288 rulings; nothing in this audit needs them changed. | refusals of the R1 prototype go through the same mechanism unchanged |
| `loss_value` through `value_from_residual`; PGD/APG values and gradients through the predictor oracles; `_stationary!` through `kkt_violation` | Already the PB oracles (#277, #307, #341). | PS reaches no PB private name |
| PGD `_step_curvature` allowances, `backtrack!`, `next_curvature`; all of `convergence_assessment`, `gradient_converged!`, `_gradient_test` | #284/#287/#308 designs and #352's scope. No stopping quantity needs `_SE`. | — |

## E. ProximalBase interface recommendation (for PB #698)

**Recommendation: defer `ProximalBase.NumericalKernels`. Keep PB's kernels private and PS's certificate arithmetic in PS (option 1 of the three compared on #698).** A separate numerical package is not warranted: there is no consumer outside PB and PS.

What the inventory shows (PB pin `a19c59aa`; master `13891ccf` adds only the `kkt_violation` score block to `numerical_kernels.jl`):

- `src/numerical_kernels.jl` has 778 executable lines, plus about 60 numerical lines in `src/utils.jl`: about 15 % of PB's `src`. After #865 nearly every private primitive has two or more callers inside PB. None is exported, and their guarantees are stated in comments and per-function pages, not as contracts of the primitives.
- PB has no directed rounding, no extended-range value type and no certified norm or spectral bound. Every stable norm that was measured (PB `_residual_squares`, PB `norm_diff`, PS `_se_norm`, PS `_scaled_norm`, Base `norm`) is below the exact norm in 43–59 % of trials: a stable value, not a one-sided bound. PS's two certificates need one-sided bounds, so they cannot rest on any current PB primitive.
- PS imports only exported names and four names that PB declares `public` on Julia ≥ 1.11 (`leastsquares_data`, `value_from_residual`, `value_from_predictor`, `value_and_gradient_from_predictor!`). It reaches no private PB name. It does read the fields `λ0`, `w`, `λ1`, `λ2`, `groups` of exported penalty types, for which PB publishes no accessor (an observation for PB, outside this issue).

What a submodule could take over, and why that is not enough:

| Candidate | PB primitive | PS code it would replace | PS exec removed | Guarantee PB would have to state |
|---|---|---|---|---|
| already public | `norm_diff(x, y, Inf)` | `Blocks._maxabs_diff` | 7 | none new (R2) |
| D1 | `_sumabs2_diff` | `_sumsq_diff` | 7 | one `@simd` pass, ordinary arithmetic |
| D2 | `_squares_normal` | `_clean_sum` | 1 (moves a line) | `s ≥ n·floatmin/eps` |
| D3 | `_residual_squares(x, y, R) → (s, k)` | `_se_norm`, `_sumsq_scaled*` (30); sqrt-lasso `_scaled_norm` (14, deleted by R1 anyway) | about 20 net of a shim | an error theorem for the scaled compensated sum, today only in comments |

The best case is about 30–40 PS lines, 30 of them in a cold APG fallback, against a new supported namespace, docstrings with stated theorems, coverage rows and a semver commitment at `0.6.0-DEV`. The APG proof would then rest on a PB kernel instead of a formula it controls. That moves code and adds a layer; it does not reduce the combined complexity.

Mechanics, should the question return: PB already has the cheaper mechanism for a supported non-exported name (`VERSION >= v"1.11" && Core.eval(@__MODULE__, Expr(:public, …))` at `src/ProximalBase.jl:27`, importable by name on 1.10, enforced by `docs/check_api.jl`). A submodule adds only a namespace, and moving the definitions touches about 100 call sites in 11 PB files or leaves an alias layer. Inlining across the package boundary works either way (0 `:invoke` in callers on 1.10 and 1.13).

**Thresholds for reopening** (all four): (1) at least 50 net PS executable lines would migrate; (2) PB states an accuracy theorem for the exposed kernel and the PS proofs are rewritten to cite it; (3) paired Float32/Float64 timings on Julia 1.10 and the current release show the hot paths unchanged; (4) for a separate package only, a third consumer independent of PB and PS.

**What an extended-range type in PB would have to guarantee to replace `_SE`** (Q6): the representation `s·2^e` with a normalized significand, an `Int` exponent and zero as `(0, 0)`, restored after every operation; product, sum and `max(a − b, 0)` each as exactly one round-to-nearest significand operation (relative error ≤ u), since a weaker bound means re-deriving the κ = 32u budget of the APG test; an exact total comparison with zero least and no NaN representable; the behaviour at exponent gaps and under the Julia 1.10 `ldexp` truncation (PB #896) stated; construction from a finite nonnegative float of any width with one rounding and a refusal otherwise; norm constructors for `‖v‖` and `‖a − b‖` with a stated relative error and a stated one-pass threshold; zero allocation and stable inference on 1.10 with fixed arities (#272). PB today meets the product clause only. With one consumer family, adding this to PB would raise the combined total.

Two small PB observations that need no interface: `_scaled_dot` (`numerical_kernels.jl:252`) has no caller in `src` on the pin or on master; and the exported `shrink` (max/min form) is slower than PB's own select form `_shrink_nonneg` in a dependent scalar chain on Julia 1.10 (4.9 ns against 4.3 ns), which PS pays at its two `shrink` call sites.

## F. Follow-up implementation sequence (nothing here is opened or started under #353)

All three GO items are PS-only. **No PB change and no pin change is needed for any of them.**

1. **PS PR 1 (R2, the bit-identical bundle).** `src/blocks.jl`, `src/solvers/image_models.jl`, `src/solvers/accelerated_proximal_gradient_descent.jl`, `src/cd/sqrtlasso.jl` (`_round_up` only), `src/cd/leastsquares.jl` (`_flat_column`, `_flat_group`); one test edit in `test/cd_numerics.jl`; the `_root_scale` paragraph of `docs/src/developer/implementation-notes.md`. Gate: the fingerprint matrix of the archive stays bit-identical on Julia 1.10 and the current release, warmed allocations equal, paired timing inside the A/A control, independent Codex review, green CI on the final head. It touches `src/cd/leastsquares.jl` in places #350 does not, but should be rebased after #350 merges.
2. **PS PR 2 (R4, the folded norm kernels), optional, after PR 1.** `src/solvers/image_models.jl` and one caller in the APG file. Same gate, plus a re-read of the proof comments of `_se_norm*` against the folded code, because the APG certificate cites them.
3. **PS issue and PR 3 (R1), after an explicit maintainer ruling on the Float64 refusal.** `src/cd/sqrtlasso.jl`, three assertions and one new refusal test in `test/sqrt_lasso.jl`, the square-root section of `docs/src/numerics.md`, a row in #352's contract table. Gate: the step-accuracy families and the whole-solve matrix of the archive (BigFloat references, independent certificate check), the Julia 1.10 timing condition of R1, Codex review, green CI. The ruling should name the three refused Float64 families of R1 explicitly (tiny column, tiny nonzero residual, overflowing residual), including the tiny column at a zero residual. If the ruling is "no refusal", only R1-min is implemented.
4. **R3 (`_sqnorm!`) travels with the next change of the group curvature code** (#339), since it moves the last bits of singleton-group solves and edits twelve test sites.
5. **If the maintainer later wants a PB primitive** (none is recommended now), the order is: PB implementation with its stated guarantee and tests; review, timing and merge in PB; a deliberate pin update in PS as its own PR; the PS consumer migration; independent certification and regression tests in PS (BigFloat checks of the APG decision and of `_certify!`); final review, CI and the benchmark gate. The same order applies to making PB's exported `shrink` as fast as its private select form, should R1's timing gate need it.

**A lightweight review rule for new numerical helpers in PS** (the issue's question 6): the PR description of any new private numerical helper states (1) what it returns: an ordinary value, a stable value, or a one-sided bound, and in the last case which direction and why; (2) the PB public function and the existing PS helper it was checked against, by name, or "none"; (3) the input range that reaches it and the test that does. A reviewer verifies (2) with a search. No new document, label or checklist.

## G. Reproducibility record

- **Revisions.** ProximalSolvers `dac9f4b6819d9321117ee3cf3549e9e46a043f01` (master after #348). ProximalBase pin `a19c59aa723d085d5d7cf5242895bda16eb77214`, git-tree-sha1 `138929aa27c6221284ee1763e66b1110dd6ec418`; the loaded package source was compared file by file with an export of the pin (identical) on both Julia versions. ProximalBase master at audit time `13891ccfd5c33a042c5df82d670abf1f2d786a0f` (pin + #976, #977).
- **Open at audit time, not audited:** PS #350 (weighted lasso, head `65f7004`; it adds one `_exceptional_step` method and edits `_converted_penalty`, `_l1_level`, comments and docs), #357, #355, #356.
- **Machine.** Intel Core i5-13600K, Linux x86-64; Julia 1.10.13 and 1.13.4; OpenBLAS (ILP64), one BLAS thread and one Julia thread in every timing; timings pinned to one performance core. Julia 1.10 selects the code target `goldmont` (no AVX) on this CPU, so the Julia 1.10 timings were taken twice: with the default target and with `-C alderlake` (AVX2). The machine was shared with other work (load average 3–6 of 20 logical CPUs) during the runs; every timing is paired in one process with an A/A control, and the control is reported next to each result.
- **Not done.** No cluster run and no AVX-512 machine; no threaded BLAS; no change to the benchmark baseline or the frozen campaigns. The Julia 1.10 per-visit slowdown of the R1 prototype is measured but only partly explained.
- **Archive.** Branch `archive/issue-353-evidence-r2` of this repository (archive branches cannot be updated here, so revision r1 stays on `archive/issue-353-evidence` and this revision has its own branch, whose first commit is r1), with a `SHA256SUMS` manifest: the six agent reports, every script and raw output, the prototype patches (`x1a`, `x1b`, `x1d`, `x2`, `x3`, the folded-kernel patch), the timing tables and their summaries, the environment record, the ledger source and this report. Local paths are replaced by placeholders in the archived copies. The two ProximalBase source exports are not archived; they are the pinned revisions above.
- **Independent review.** Codex gpt-6.1-sol, high reasoning effort, reviewed revision r1 (archive commit `9747703`) against the source, the prototypes and the raw outputs and posted its findings on this issue: verdict BLOCKERS, with two blockers, four major and two minor findings. Changes in r2, by finding: (1) dropping tier 2 of `response_scale` is no longer in the GO bundle, because it turns an accepted boundary input into a refusal (reproduced; `experiments/review-r1/`); R2 is now five items, −28 lines, and its fingerprint matrix and test file were re-run on exactly that tree (`experiments/x2/x2b.patch`, `fp_x2b_*`, `tests_x2b_*`); (2) the Float64 refusal of R1 is stated as an exact predicate, including the tiny column at a zero residual, with the two reproduced cases in the table; (3) the tier-2 statistics are given in Float32 ulps and restricted to admitted scales; (4) the full extent of the Julia 1.10 per-visit slowdown of the R1 prototype is in the text (up to 14.6 %); (5) the ledger has rows for the iteration drivers, `check_rejection!`, `_prox_grad_step!`, `_stagnated` and the input guards, and the second `_initialize!` caller; (6) the group-curvature row states which refusals precede the first pass and which can occur during one; (7) the BigFloat conversion of `_significand_exponent` is described as reachable for integer and Bool scales and unnecessary, not as dead; (8) R1-min is −13 net, the `floor64` statement carries its range, and `_clean_sum` and `_squares_normal` are described as equal on finite inputs.
