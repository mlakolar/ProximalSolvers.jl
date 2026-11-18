# Agent C: PGD/APG numerical helpers and APG certification (PS #353, Stage 0)

**Delivery note.** The Write tool refused `RUN/agentC/report.md` ("subagents should return findings as text"), and I did not work around it. The full report is inline below (section A is the ≤60-line summary, section B is the report body). All scripts and raw outputs are in `RUN/agentC/`, where `RUN=<RUN>`: `common.jl`, `e1_frobenius.jl` through `e18_fallback_cost.jl`, `out_*`, `e6_*.out`, `e45_*.out`, `e8.out`, `e9*.out`, `e13.out`, `e18.out`, `loc.txt`, `i279.txt`, `i352.txt`, `pb896.txt`, `pb366.txt`, `pr350.diff`. Nothing tracked was edited and no Pkg operation was run. Julia 1.10.13 and 1.13.4 were run for every experiment (i5-13600K, OpenBLAS 1 thread, BigFloat 512 bits).

## A. Summary

1. **Correctness.** The APG certification arithmetic (`_SE`, `_se_*`, `_se_norm*`, `_frobenius_upper`, `_root_scale`, `_BoundConstants`, `_bound_certified!`, `_image_error_bound`) showed 0 violations in every BigFloat check on both Julia versions.
   - E5: about 22,000 decisions per version against the stored x, y, X.
   - E6: 132 real APG solves, about 15,000 certified trials rechecked in BigFloat.
   - E17: about 40,000 decisions.
   - I found no wrong answer on a supported ordinary input in any helper in scope.
2. **`_SE` verdict: the #279 conclusion stands against PB pin `a19c59aa` and master `13891ccf`.**
   - PB has no extended-range scalar with add, subtract and compare.
   - Its private cousins are product-only: `_ProjectionScale` (`functions/scaled.jl:8`) and `_parts_product` (`numerical_kernels.jl:390-400`). `_parts_product` is bit-identical to `_se_mul` after power-of-two rescaling (E12, 0/100,000 mismatches).
   - `_ExpSum` is a compensated frame triple, not a comparable scalar.
   - Moving `_SE` removes about 23 executable lines from PS but adds public API, contract and tests to PB. PB+PS total goes up. No new evidence overturns #279.
   - PB master's `numerical_kernels.jl` differs from the pin only by an added KKT block, which is outside this scope.
3. **Certificate guarantee.** Only `_frobenius_upper` is a rigorous one-sided bound with explicit directions (E1: 290 matrices per type, 0 violations).
   - The `_se_*` operations are round-to-nearest with at most 1.0u error each (E11).
   - The final decision is rigorous through a fixed budget κ=32u, not through directed rounding.
   - E14: computed LHS is at most 2.15u below ideal, computed RHS at least 28u below ideal, so at least 27u of the 32u is unused (a hand count gives about 17u used).
4. **Candidate simplifications.** All are PS-internal; PB is unchanged. Each was prototyped or measured bit-identical, with equal speed and 0 allocations on both Julia versions.

| ID | Change | Exec lines | Concepts |
|---|---|---|---|
| S-A | `_maxabs_diff` → `_norm_diff(x,y,Inf)` (PB public `norm_diff`; 0/40,000 mismatches, same speed) | −7, −1 export | −1 loop |
| S-B | `_significand_exponent` (both methods) → `Float64(α)`; the 256-bit BigFloat route is dead because `_check_loss_scale` (solve.jl:29-38) admits only Float32, Float64, fixed-width Int and Bool, all exactly representable in Float64 (0/6,298 mismatches) | −5 (plus about 5 test lines and 3 doc lines) | −1 |
| S-C | Fold `_se_norm`, `_sumsq_scaled` and `_se_norm_onepass` into the `_diff` forms with a zero operand (0/120,000 mismatches); also removes the unreachable `isfinite(s)` line in `_se_norm_diff` | −11 to −13 | −3 |
| S-D | `_frobenius_upper`'s first loop → existing `_sumsq64` (bit-identical) | −4 | −1 loop |

   - Together S-A to S-D remove about 27–29 of the 236 executable lines in `image_models.jl` + `blocks.jl` (about 12%) and about 6 concepts.
   - **S-E (optional, contradicts #268/#279 "deliberately remain", needs a ruling):** one closure-based `fsum`/`fmax` replaces 9 hand-written fused loops (about −40 lines, −7 loops). Bit-identical, same speed, 0 B in isolation (E8). It is untested in situ.
5. **Rejected or kept, with evidence.**
   - PB `norm_diff` as a drop-in for `_se_norm_diff_onepass(_sumsq_diff)` (about −22 net lines) is the same formula with a different guarantee.
     - It returns a `T` scalar, so the N-level requirement fails whenever the norm is subnormal: 153/4000 Float32 and 69/4000 Float64 cases (E7), all subnormal norms, none in the normal range.
     - Substituted into the real decision it gave 0 violations and 0 changed decisions in 40,000 trials, including about 1,200 cases with ‖Δz‖ < floatmin (E17). The certificate survives only because `under_product ≥ 2η` happens to absorb the subnormal rounding.
     - PB documents no accuracy statement for `norm_diff`.
     - It would save only about 9 lines more than S-C and couple a certificate to an unstated PB property. Not recommended.
   - `_bound_certified!`'s early certified reject (the `_se_sub`, `reject`, `upper_step` branch) ends 20% of ordinary Float32 trials and 23% of ordinary Float64 trials without a fresh product (323/1588 and 384/1699). Without it, about +10–13% matrix products. Keep.
   - The fresh product is needed in 22% of ordinary Float32 trials (348/1588 on 1.10, 391/1661 on 1.13) and 0% of ordinary Float64 trials (0/1699). It reaches 34 of about 50 in one near-converged Float64 probe (E9c). This is the documented Option A/B cost, not a defect.
6. **Hot path.**
   - `_SE` is never inside a vector loop. Per trial it is about 16 O(1) operations plus one fused p-pass (`_sumsq2`) and one fused n-pass (`_sumsq_diff`).
   - The whole cheap certified call takes 0.23–0.47 µs at n=200–2000, against 0.5–140 µs for one `X*x` (E9).
   - Warmed `update_state!` allocates 0 B for APG and PGD, Float32 and Float64, on both Julia versions (E9c).
   - The two-pass `_se_norm`/`_se_norm_diff` run once per solve at ordinary scale (setup, `_se_norm(T,x0)`). They run on every trial only at data scale ≲ 2^-45 (Float32) or ≲ 2^-400 (Float64).
7. **Bugs: none found.** Observations that are not bugs:
   - `_SE{T}(-1.0)` is silently accepted. It is unreachable; Inf and NaN throw `DomainError`.
   - Julia 1.10 NaN-propagating `max` loops (`_maxabs_*`) are scalar, 1.9 ns/element against 0.13–0.25 on 1.13 (E8). There are about 4 per iteration, 1–4% of one matvec at n≈p≈1000.
8. **Cross-references for #352 (no helper change proposed).**
   - No stopping quantity needs `_SE`; all are plain `T`.
   - `convergence_assessment` recomputes `norm(x)` although APG already holds `state.normx`. Reuse would couple stopping to `_SE` and change bits.
   - E15: Float64 PGD and APG return `converged=false` at maxiter=200 for data scales 2^-20 and below (initial L=1, 0.9 decay; docs say "rescale"). Float32 stops unconverged at 39–52 iterations with x=0 at 2^-20.
9. **Concurrent PRs.**
   - #350 modifies `utils.jl` `_converted_penalty`, `_l1_level` and the `_stationary!` comment. In the PGD and APG files it changes docstrings only.
   - #357 (head 521a8cf8) has one "start" commit and no code yet. It plans an ℓ∞ stopping check, which is #352 territory. Neither touches an `_SE` helper.
10. **Cross-reference for Agent A.** `src/cd/sqrtlasso.jl:89-103` `_scaled_norm` (14 lines) duplicates `_se_norm(Float64, ·)` and is a candidate C. `_se_scale` (cd/leastsquares.jl:227) is the CD consumer of `_SE`.

---

## B. Report body

### B0. Identity
- PS `dac9f4b`. PB pin `a19c59aa` (tree `138929aa`, the tree PS loads). PB master `13891ccf` diffed; `_parts`, `_ExpSum`, `_scaled_product` and `norm_diff` are byte-identical at pin and master.
- LOC from `RUN/tools/count_loc.py` (`RUN/agentC/loc.txt`):

| File | Executable lines |
|---|---|
| `image_models.jl` | 183 |
| `line_searches.jl` | 78 |
| `utils.jl` | 96 |
| `blocks.jl` | 53 |
| PGD file | 156 |
| APG file | 196 |

### B1. Ledger
Conventions:
- Guarantee letters: (i) ordinary value, (ii) stable value with bounded relative error, (iii) rigorous one-sided bound.
- IM = `src/solvers/image_models.jl`, APG = `src/solvers/accelerated_proximal_gradient_descent.jl`, PGD = `src/solvers/proximal_gradient_descent.jl`, LS = `src/line_searches.jl`, U = `src/utils.jl`, BL = `src/blocks.jl`, CDL = `src/cd/leastsquares.jl`.
- Ranges are at dac9f4b. Each row lists: helper and lines | call sites | purpose and guarantee | path | PB equivalent | class | action | net savings | correctness | performance | dependencies.

**Extended-range arithmetic**

- **`_SE{T}` struct, IM:27-30 (4 lines)**
  - Call sites: APG:108-111; IM constants; CDL:225, 227.
  - Purpose: nonnegative `s·2^e` with s in [1,2) and `e::Int`. (ii): each operation is one correctly rounded significand operation, at most u (E11, worst 1.00u for mul, add and sub, exponent gaps to ±3000, both versions).
  - Path: per trial (O(1), about 16 ops) and setup.
  - PB: none public. Private `_ProjectionScale{T}(m,e)` (significand in [1/2,1), product only); `_parts`/`_parts_product` (numerical_kernels.jl:390-400).
  - Class B. Action: keep. Net 0.
  - Correctness: 0 invariant or order violations in 200,000 pairs per type.
  - Performance: not in any vector loop; the cheap call is 0.23–0.47 µs (E9).
  - Deps: #279, #272/#276, PB #366.
- **`_se_zero` IM:31, `_renormal` IM:32, `_SE{T}(x)` IM:34 (1 line each)**
  - Call sites: IM 34, 36, 45, 51, 76-88, 114-121, 153, 199-212; APG:155; CDL.
  - Purpose: zero as (0,0); renormalize a significand in [0,4); convert a finite nonnegative float of any width with one rounding.
  - PB: `_parts` (frexp) is the same idea.
  - Class B. Keep. Net 0.
  - Correctness: the constructor does not check its precondition (Inf and NaN throw `DomainError`, -1.0 is accepted), and no caller can pass those.
- **`_se_mul` (2, 3, 4 args), IM:35-39 (4 lines)**
  - Call sites: IM 78, 88, 153, 209-212, 242, 246-250, 256-258, 273-274; CDL:225.
  - Purpose: product, (ii), 1u per product.
  - PB: private `_parts_product`, value bit-identical (E12), no zero rule.
  - Class B (only product exists in PB). Keep the fixed arities, since a vararg brings #272 back.
  - Net 0. Correctness: E11. Performance: 0 B on both versions (E9c). Deps: #272/#276.
- **`_se_le` IM:40 (1)**
  - Call sites: IM 50, 248, 250, 258.
  - Purpose: exact comparison, zero least.
  - Class B. Keep. E11: exact order on 200,000 pairs per type.
- **`_se_add` IM:41-46 (6)**
  - Call sites: IM 212, 245-247, 256-257, 272-274.
  - Purpose: sum via `ldexp`; the gap shift is harmless even where 1.10 `ldexp` truncates, because a subnormal shift costs at most 2^-1074 absolute on a significand ≥ 1 (E11 with gaps to 3000 binades).
  - PB: `_expsum_add` is a different object (compensated frame triple).
  - Class B. Keep. Net 0. Deps: PB #896.
- **`_se_sub` IM:48-52 (5)**
  - Call sites: IM:249 only.
  - Purpose: max(a−b, 0), (ii).
  - Path: per trial, only when the cheap accept fails.
  - Class B. Keep (feeds the early certified reject). E11.

**Norms and sums of squares**

- **`_sumsq_scaled` IM:55-61 (7)**
  - Call sites: IM:78 only.
  - Class B, duplicate of the next loop. S-C: fold into the `_diff` kernel. Net −7 (within S-C).
  - Correctness: fold bit-identical, 0/120,000 including NaN, Inf, −0.0 and subnormals (E10).
  - Path: cold.
- **`_sumsq_scaled_diff` IM:64-70 (7)**
  - Call sites: IM:87 only.
  - PB: private `_residual_squares` (compensated).
  - Class B. Keep as the single scaled kernel.
  - Correctness: E2, worst 0.44 of γ_{n+4}.
  - Performance: cold, but runs every trial at Float32 scale ≲ 2^-45 or Float64 ≲ 2^-400 (E6).
- **`_se_norm` IM:74-79 (6)**
  - Call sites: APG:127 (once per solve, two passes over p), IM:116 (fallback), CDL:223.
  - Purpose: (ii), relative error ≤ γ_{n+4}, worst observed 0.34 of the bound (E2).
  - Path: setup and fallback.
  - PB: none (PB `norm` returns a scalar `T`; `_scaled_norm` is private).
  - Class B. S-C: becomes a one-line wrapper. Net −5. CD keeps calling it.
- **`_se_norm_diff` IM:82-89 (8)**
  - Call sites: IM:120 only.
  - Purpose: (ii), norm of the rounded differences.
  - PB: public `norm_diff`, see B3.
  - Class B. Keep as the single scaled implementation after S-C. The line `isfinite(s) || return nothing` is unreachable (each term ≤ 1, so s ≤ n): −1 line.
- **`_sumsq2` IM:92-99 (8)**
  - Call sites: APG:237.
  - Purpose: Σd² and Σx² in one fused pass, (i).
  - Path: hot (one p-pass per trial).
  - Class B (two outputs, one pass). Keep.
- **`_sumsq_diff` IM:102-108 (7)**
  - Call sites: IM:244.
  - Purpose: one fused n-pass, no temporary.
  - Path: hot.
  - PB: private `_sumabs2_diff` is the same loop.
  - Class B. Keep.
- **`_se_norm_onepass` IM:114-117 (4)**
  - Call sites: APG:238-239 (two per trial), IM:256.
  - Purpose: `_SE{T}(sqrt(s))` when s is finite and ≥ 4n·floatmin, else `_se_norm`. Underflow of squares costs less than u/4 relative. (ii).
  - Class B. Keep; S-C merges it, net −3. E2: 0 violations.
- **`_se_norm_diff_onepass` IM:118-121 (4)**
  - Call sites: IM:244.
  - Class B. Keep. See B3 for `norm_diff`.

Passes on ordinary input:

| Stage | Work |
|---|---|
| Setup, once per APG solve | `_se_norm(T,x0)`, two passes over p |
| Per trial | `_sub!` (p), `_sumsq2` (p, fused), `_sumsq_diff` (n, fused), about 16 `_se_*` ops |
| Fresh product (22% of ordinary Float32 trials) | `mul!` n×p plus `sum(abs2,buf)` |
| Two-pass scaled kernels | only when a sum is non-finite or below 4n floatmin |

Instrumented counts (E6, 24 solves per type at scale 2^0):

| Quantity | Float32 | Float64 |
|---|---|---|
| Trials | 1588 | 1699 |
| Iterations | 1170 | 1276 |
| Fresh products | 348 | 0 |
| Cheap certified rejects | 323 | 384 |

Matrix products per iteration: one `Xᵀ` product at y (PB oracle) plus 1.36 `X x` per iteration, plus 0.30 fresh products per iteration in Float32. The certificate adds no product on the cheap path.

**Constants and certificate**

- **`_unit`, `_gamma` IM:125-126 (2)**
  - Call sites: IM:152, 200-201; APG:278.
  - Class B. Keep. E14: constants within 2.2u of ideal.
- **`_frobenius_upper` IM:137-155 (19)**
  - Call sites: IM:203.
  - Purpose: (iii). Float64-accumulated squares, γ_{N+3}, `+N·nextfloat(0)`, `(1+eps)` on the root, `(1+8u_T)` on the conversion.
  - Path: setup, one pass over X, plus an `ldexp` pass only when the Float64 sum overflows or underflows.
  - PB: none. `_opnorm_upper` and `opnorm2` are spectral-norm estimates, not Frobenius and not one-sided.
  - Class B. Keep. S-D: first loop → `_sumsq64`, net −4.
  - Correctness: E1, 0 violations.
- **`_significand_exponent` IM:163-166 (5)**
  - Call sites: IM:170.
  - Class E (dead generality). S-B: delete both methods. Net −5, −1 concept. This also removes about 1.2 KB of BigFloat allocation per solve for an Int or Bool α.
  - Correctness: identical on 6,298 accepted scales (E16). Float16, BigFloat, Rational and irrational scales are refused before solver code.
  - Deps: #279 kept it; #307 narrowed the scale domain afterwards.
- **`_root_scale` IM:169-177 (9)**
  - Call sites: APG:154; CDL:225.
  - Purpose: (ii), error ≤ 0.91u (E3). Class B. Keep.
- **`_BoundConstants` IM:182-196 (15) and `_bound_constants` IM:198-213 (16)**
  - Call sites: APG:107, 153.
  - Purpose: 13 round-to-nearest constants, not directed bounds. E4, E14.
  - Class B. Keep.
- **`_bound_certified!` IM:237-259 (23)**
  - Call sites: APG:248.
  - Purpose: (iii). Accept only if the inequality is certified.
  - Path: hot.
  - Class B. Keep.
  - Correctness: E5 (13,504 Float32 and 8,544 Float64 decisions per version, 0 violations); E6; E17.
  - Deps: #265/#267, #272, #352 (does not own it).
- **`_image_error_bound` IM:270-275 (6)**
  - Call sites: APG:175, 203.
  - Class B. Keep. E4: ‖zu−Xy‖/Ey ≤ 0.76 (fresh), ≤ 0.17 (extrapolated); chain E4b ≤ 0.62.
- **`_check_bound_size` APG:276-281 (6)**
  - Call sites: APG:318.
  - Purpose: requires (max(n,p)+4)u_T < 1/8 and (np+3)u_64 < 1/8. Class B. Keep.
- **Image-model glue IM:5-20 (14)**
  - `_LSImage`, `_image_model`, `_image!`, `_value!`, `_value_and_gradient!`.
  - PB: these ARE the PB public oracles (`value_from_predictor`, `value_and_gradient_from_predictor!`, `leastsquares_data`).
  - Class A. Keep. Deps: #277/#307.

**Blocks reductions**

- **Forwards `_norm`, `_norm_diff`, `_norm_inf`, `_dot` BL:15-18.** Class A. Keep (#279/#268 owner seam, tested at core_regressions.jl:90-91).
- **`_dot_diff` BL:19-25 (7)**
  - Call site: LS:139. Fused, no temporary.
  - Class B. Keep; part of S-E (−5).
- **`_maxabs_axpy` BL:27-33 (7), `_maxabs_residual` BL:35-41 (7), `_maxabs_stepdiff` BL:53-59 (8)**
  - Call sites: U:84; U:32 (PGD `g_residual`); APG:295.
  - Class B (fused). Keep; part of S-E (−5, −5, −6).
- **`_maxabs_diff` BL:44-50 (7)**
  - Call sites: IM:83; APG:289.
  - PB: public `norm_diff(x,y,Inf)`, same loop, value and speed.
  - Class **C**. S-A: delete and call `_norm_diff(x,y,Inf)`. Net −7, −1 export.
  - Correctness: bit-identical on 40,000 cases including NaN, Inf and overflow (E13b).
  - Performance: timing equal (E13). No test references it.
- **`_sub!`, `_step!`, `_extrapolate_point!` BL:12-14.** Fused broadcasts, owner seam. Class B. Keep.

**utils.jl, PGD curvature, line search** (stopping policy belongs to #352)

- **`f_residual` U:28-31.** `f_tol` is unused. Class B (#352). Keep.
- **`g_residual` U:32 and APG:289, `gradient_converged!` U:80-86 and APG:291-297, `_gradient_test` U:94-99, `convergence_assessment` U:33-79 (28 lines).** Class B, owned by #352. Keep. S-A touches APG:289 only.
- **`_stationary!` U:122-133 (12).**
  - Uses PB public `kkt_violation`. Class A. Keep.
  - Deps: #341/#343, #350 (changes `_converted_penalty`, `_l1_level` and the comment).
- **`_lambda_max!` U:141-147.**
  - Using the PB oracle at z=0 would need a third n-buffer because the oracle forbids `d===z`. No gain. Keep.
- **`_gradient_at_x!` U:150, 156-160 and `_converted_penalty`/`_l1_level` U:164-167.** Class A. Keep.
- **`_unchanged` U:170-175.** Class B. Keep.
- **`_state_norm`/`_state_normdiff` U:177-178.** Class A, settled at #279. Keep.
- **`_step_curvature` (T) PGD:188-191, (Float32) PGD:213-222.** Class B, #284/#287. Keep. Float64 spurious-zero cases are documented limits.
- **`_sumsq64` PGD:225-231 and `_step_norms64` PGD:234-243.** Class B. Keep. S-D reuses `_sumsq64`.
- **`backtrack!` LS:92-170, `next_curvature` LS:77-81.** Class B. Keep. `xy_sq=_norm(delta_x)^2` underflows for ‖d‖ ≲ 1e-19 in Float32, which is documented.
- **CD cross-use.** `_se_scale` (CDL:227-231) consumes `_SE`. `_scaled_norm` (sqrtlasso.jl:89-103) is a candidate C for Agent A.

### B2. APG certification inequality chain

Notation:
- u = eps(T)/2; γ_k = ku/(1−ku); ε = eps(T); η = nextfloat(zero(T)); κ = 32u.
- δn = γ_{n+4}; δp = γ_{p+4}; γp = γ_p.
- x is the stored trial point and y the stored extrapolated point; d = x−y exactly; d̂ = fl(x−y).
- zw = fl(Xx); zu is the cached image of y; Δz = zw − zu.

**What is bounded.** √α‖Xd‖ ≤ (1+4ε)√L‖d‖ for the stored x and y. This is the exact least-squares majorization test, relaxed by legacy's slack. Accept only when it is certified. Rejection is always safe.

The direction required is: computed LHS ≥ (1−r_L)·true LHS and computed RHS ≤ (1+r_R)·true RHS, with (1+r_L)(1+r_R) ≤ 1+κ.

**Left side.**
1. Δz − Xd = (zw − Xx) − (zu − Xy), so ‖Xd‖ ≤ ‖Δz‖ + ‖zw − Xx‖ + ‖zu − Xy‖.
2. Matvec model (IEEE with gradual underflow; each entry a ≤p-term dot product in some order, FMA allowed): ‖fl(Xv) − Xv‖ ≤ γp‖X‖_F‖v‖ + 2p√n·η.
   - So ‖zw − Xx‖ ≤ `product`·`upper_x`·`normx` + `under_product`.
   - `product` = γp·‖X‖_F^up and `upper_x` = 1/(1−δp).
3. ‖zu − Xy‖ ≤ Ey from `_image_error_bound`.
   - Fresh case: `product`·‖x_a‖ + `under_product`.
   - Extrapolated case: (2γp+16u)‖X‖_F(‖x_a‖+‖x_b‖) + 8p√n·η + 2√p·‖X‖_F·η.
4. ‖Δz‖ ≤ `upper_image`·N, with `upper_image` = 1/((1−δn)(1−u)): u for the rounded differences, γ_{n+4} for the norm.
5. So √α‖Xd‖ ≤ √α(`upper_image`·N + E), with E = product term + `under_product` + Ey. ‖X‖_F enters as a proved upper bound (`_frobenius_upper`).

**Right side.** ‖d‖ ≥ ‖d̂‖/(1+u) ≥ D/((1+δp)(1+u)) = `lower_step`·D. The code tests `rootα·upper ≤ accept·rootL·lower_step·D` with `accept` = (1+4ε)/(1+κ).

**What absorbs which rounding.**
- Norm evaluation errors (γ_{n+4}, γ_{p+4}) and d̂ (u) are built into `upper_image`, `lower_step`, `upper_x` and `accept` by division by (1∓δ)(1∓u).
- κ=32u absorbs all rounding of the test's own arithmetic. That covers √L (u), √α's conversion (≤ 0.91u), the round-to-nearest rounding of each constant, and the fixed number of `_SE` ops (each at most u).
- No `_se_*` op is directed. The guarantee is "round to nearest within u per op, with a fixed budget κ".
- `_se_le` is exact. `_se_sub` clipping is used only on the reject side.
- Over- and underflow: all norms, products and sums are `_SE`. The native `X*v`, the extrapolation, and the one-pass sums are evaluated in `T` and enter only through the bounds. A one-pass sum is used only when finite and ≥ 4n·floatmin, else the scaled two-pass form.

**Reject side.** √α(‖Δz‖/((1+δn)(1+u)) − E) > (1+4ε)(1+κ)√L‖d̂‖/((1−δp)(1−u)) proves a violation, and the function returns without a product. This branch is performance only.

**Fresh path.**
- w = fl(Xd̂) in `buf`, with ‖w − Xd‖ ≤ (γp+2u)‖X‖_F‖d̂‖/((1−δp)(1−u)) + 2p√n·η.
- W is the computed norm of w, with `upper_fresh` = 1/(1−δn).
- Accept iff `rootα·(upper_fresh·W + Ew) ≤ accept_rhs`. Inconclusive means reject.

**Validity domain.** `_check_bound_size`, finite data, IEEE gradual underflow, and the matvec model. Flush-to-zero is not covered for APG (Float32 PGD has an explicit check). Matvecs that are not a p-term dot per entry are not covered.

**Must stay in PS regardless of the arithmetic interface.**
- The chain and the constants (δ's, γp, κ, the 4ε slack, the underflow terms), because they encode PS's matvec model and operation counts.
- `_bound_certified!`'s decision structure: cheap accept, certified early reject, fresh product, "inconclusive means reject", the `nothing` guards.
- `_image_error_bound` and the `normx`, `normx_previous`, `image_error_y` bookkeeping.
- `_frobenius_upper` and `_check_bound_size`.
- Line-search acceptance, restart, rollback and all stopping decisions (#352).

Only the scalar type and an accurate range-safe norm could ever live in PB.

### B3. `_SE` verdict and the PB contract

**Does #279 stand: yes.**
- PB has no public extended-range scalar, and no private one with add, subtract or compare.
- The private pieces state no rounding bound beyond "rounded once per factor" in comments.
- PB #366 policy (no generic framework, share a helper only when it removes duplication) argues against adding a public type for one consumer.
- PB's internal consumers (`Scaled` factors through `_ProjectionScale`; `NormL1`, linear and quadratic recoveries through `_ExpSum`) need product and sum only, never compare or clipped subtract.
- In PS the consumers are the APG certificate, CD `response_scale`, and possibly `sqrtlasso.jl:_scaled_norm`.
- Moving `_SE` removes at most about 23 lines from PS and adds public API, contract and tests to PB. PB+PS total increases.

**Pairs.**

| Pair | Verdict |
|---|---|
| `_se_mul` vs `_parts_product` | same algorithm and guarantee (bit-identical, E12); private; no zero rule |
| `_se_add` vs `_expsum_add` | superficially similar (different object) |
| `_SE` vs `_ProjectionScale` | same representation idea; different normalization; product only in PB |
| `_se_norm_diff_onepass(_sumsq_diff)` vs `norm_diff` | same formula in the ordinary range, different guarantee (details below) |
| `_se_norm` vs `_scaled_norm` / `_residual_squares` | PB's is private and compensated (more accurate); superficially similar |
| `_frobenius_upper` vs `_opnorm_upper`, `opnorm2`, `LinearAlgebra.norm` | superficially similar; not Frobenius, not one-sided |
| `_maxabs_diff` vs `norm_diff(.,.,Inf)` | same algorithm and guarantee (C) |
| `_value!`, `_value_and_gradient!`, `_gradient_at_x!`, `_stationary!` vs PB oracles and `kkt_violation` | already shared (A) |

The `norm_diff` row in detail:
- The ordinary loop is identical (`_sumabs2_diff`).
- PB's threshold is `s ≥ floatmin`, not PS's `4n·floatmin`. A hand argument keeps it inside γ_{n+4}, and the E7 adversarial zone shows PB error at 0.34–0.41 of the budget against PS ≈ 0.
- The result is a `T` scalar, so a subnormal norm loses relative accuracy. This accounts for all 153/4000 Float32 and 69/4000 Float64 violations of the N-level requirement (E7).
- Substituted into the real decision: 0/40,000 violations and 0 changed decisions (E17), because `under_product ≥ 2η` absorbs the subnormal rounding. The proof gap is that absorption argument plus the threshold-zone argument.
- PB's only statement about `norm_diff` is "‖A−B‖ without allocating A−B".
- Fallback cost is comparable (E18; PB 1.0–1.7× PS in the underflow regime).

**Contract a PB extended-range type would need.**
1. Representation: `s·2^e` with s in [1,2) (or [1/2,1) with constants rescaled), `e::Int`, zero as (0,0), the invariant restored after each op.
2. Operations: mul, add, max(a−b,0), each exactly one correctly rounded (nearest) significand operation, relative error ≤ u, operand significands in [0,4) so nothing underflows. Any weaker bound requires re-deriving κ. The measured slack is ≥ 27u, so about 15u extra would fit.
3. Exponent gaps: a gap beyond the exponent range returns the larger operand. The Julia 1.10 subnormal `ldexp` truncation (PB #896) costs at most 2^-1074 absolute on a significand ≥ 1; this must be stated.
4. Comparison: exact, total, zero least, no NaN representable.
5. Construction from a finite nonnegative float of any width with one rounding. Non-finite or negative input is a refusal or a documented precondition.
6. `Int` exponent overflow behavior stated (BigFloat uses `Int128` in PB).
7. Norm constructors for ‖v‖ and ‖a−b‖ with a stated relative error (γ_{n+4} or a PB factor), the one-pass threshold stated, and refusal on non-finite entries or an overflowing difference.
8. Zero allocation and inference-stable on 1.10 and 1.13, with fixed arities (#272).

PB today meets only (2) for products, and none of (1), (4), (5) or (7) as a public contract.

### B4. Do-not-change list

| Item | Evidence |
|---|---|
| `_SE`, `_se_zero`, `_renormal`, `_se_mul` fixed arities, `_se_le`, `_se_add`, `_se_sub` | E11 (≤1.0u per op); E9c (0 B warmed `update_state!`); #279, #272; no PB replacement |
| early certified reject | ends 20% (Float32) and 23% (Float64) of ordinary trials; deleting it costs about +10–13% matrix products |
| fresh-product fallback | 22% of ordinary Float32 trials (348/1588); near-converged Float64 probe (34 of about 50); `fresh_only=true` also 0 violations (E5) |
| `_frobenius_upper` | only helper that is one-sided by construction; E1; no PB Frobenius upper bound |
| `_sumsq2` + `_se_norm_onepass` | one fused p-pass for two sums; replacing it adds a pass |
| `_sumsq_diff` + `_se_norm_diff_onepass` | hot; the PB substitute has no stated guarantee |
| `_unit`, `_gamma`, `_BoundConstants`, `_bound_constants`, `_image_error_bound`, `_check_bound_size` | encode the matvec model and op counts; E4, E4b, E14 |
| `nothing` guards in `_prox_grad_step!` and `_bound_certified!` | defensive per #279; the `W === nothing` branch is reachable on an overflowing `X d̂` |
| `_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_stepdiff`, `_sumsq64`, `_step_norms64` | distinct fused operands; keep unless S-E approved |
| `_lambda_max!` | the PB oracle at z=0 needs a third n-buffer for no saving |
| `_stationary!`, `_gradient_test`, `convergence_assessment`, `_state_norm*`, `f_residual` | stopping policy is #352's; no `_SE` interface requirement (all plain `T`) |
| Blocks forwards and `_sub!`/`_step!`/`_extrapolate_point!` | #279/#268 owner seam; tested (core_regressions.jl:90-95) |
| Float32 PGD `_step_curvature` allowances | #284/#287 documented design |

### B5. Experiments (both Julia versions, BigFloat 512 bits, real private functions)

| ID | File | What | Result |
|---|---|---|---|
| E1 | `e1_frobenius.jl` | `_frobenius_upper ≥ ‖X‖_F`: ordinary, wide to floatmax, near-overflow, near the 4N·floatmin threshold, subnormal, all-floatmax, zero | 290 matrices per type, 0 violations; upper/exact−1 ≤ 5.5e-7 (F32), 5.2e-12 (F64) |
| E2 | `e2_norms.jl` | `_se_norm*` vs BigFloat against γ_{n+4}; image-constant sandwich; adversarial threshold zone | 3,000 vectors per type, 0 violations, worst error/bound 0.34–0.44 |
| E3 | `e3_root.jl` | `_root_scale` vs √α for Float16/32/64, Int, Bool, Rational, BigFloat, irrational | 66 per type, worst 0.91u |
| E4/E5 | `e45_bound.jl` | image error bound, cheap chain, step/iterate norm bounds, final decision on an L grid (1±64 eps to 16), both `fresh_only` settings; n≤120, p≤60; scales 2^±40 (F32) and 2^±300 (F64); subnormal data; ω∈{0,¼,0.9,prevfloat(1),1} | 0 violations (about 22,000 decisions per version); accepted decisions ≥ 71.5 eps inside the limit (grid-limited) |
| E6 | `e6_realsolves.jl` | 132 real APG solves, every accepted trial rechecked in BigFloat against the solver's own x, y, plus path counters | 15,312 (1.10) and 15,067 (1.13) trials, 0 violations |
| E7/E7b | `e7_pb_norm_diff.jl`, `e7b.jl` | PB `norm_diff` as N; adversarial zone to n=1.5e6 | 153/4000 (F32) and 69/4000 (F64) violations, all subnormal norms; PS 0 |
| E8 | `e8_generic_reductions.jl`, `e8b.jl` | closure `fsum`/`fmax` vs the 8 hand loops at n=1e4, 1e6 | bit-identical; ratios 0.88–1.17 (noise); 0 B (the 16 B in `e8.out` on 1.10 is the timing closure) |
| E9/E9b/E9c | `e9_cost.jl`, `e9b_alloc.jl`, `e9c_update_alloc.jl` | cost and allocations | cheap call 0.23–0.47 µs vs 0.5–140 µs per `X*x`; `update_state!` 0 B for APG and PGD in Float32 and Float64. The 16–336 B in e9/e9b are harness artifacts |
| E10 | `e10_fold.jl` | S-C and S-D prototypes | 0/120,000 and 0/4,000 mismatches |
| E11 | `e11_se_ops.jl` | `_se_*` error, order, zero rules | 200,000 pairs per type, ≤ 1.0u, no violation |
| E12 | `e12_pb_parts.jl` | `_parts_product` vs `_se_mul` | 0/100,000 mismatches |
| E13/E13b | `e13_maxabs_pb.jl`, `e13b_alloc_equal.jl` | `_maxabs_diff` vs `norm_diff(.,.,Inf)` | equal on 40,000 cases; timing equal |
| E14 | `e14_budget.jl` | rounding budget vs an all-BigFloat ideal chain | LHS underestimate ≤ 2.15u, RHS ≥ 28u slack; 0 of about 4,500 samples per version consume κ |
| E15 | `e15_scale.jl` | PGD/APG at scales 2^0 to 2^-60 | converge in 14–15 iterations at 2^0; Float64 `converged=false` at 200 iterations from 2^-20 down; Float32 stops unconverged at 39–52 iterations at 2^-20 |
| E16 | `e16_root_edges.jl` | `_root_scale` BigFloat route vs `Float64(α)`; edge cases | 0/6,298; an overflowing difference and NaN/Inf give `nothing` |
| E17 | `e17_pb_substitution.jl` | final decision with PB `norm_diff` substituted | 40,000 decisions per version, 0 violations, 0 differing decisions |
| E18 | `e18_fallback_cost.jl` | scaled fallback cost, PS vs PB | comparable |

### B6. Verified vs inferred; open doubts

Verified by execution: every E-tagged number above; the 0-B `update_state!`; the fresh, early-reject and two-pass counts; the S-A to S-D equivalences; the dead BigFloat route; the PB substitution results.

Inferred from reading only:
- the "about 17u of 32u" hand count (cross-checked by E14);
- that PB's subnormal rounding is the only gap in the `norm_diff` substitution;
- that the `isfinite(s)` line in `_se_norm_diff` is unreachable (each term ≤ 1);
- that `Float64(α)` is exact for every accepted α (argument: `T(α)==α` with T ⊂ Float64; E16 agrees on 6,298 samples).

Open doubts:
1. The matvec model was tested only with OpenBLAS at 1 thread on AVX2. Threaded OpenBLAS, MKL and the AVX-512 cluster pair were not run.
2. Sample sizes are small (n up to 5000 for norms; ≤120×60 for BigFloat decisions), so they cannot prove κ. The proof is the hand count plus E14. Large-n Float32 inputs (to 2^21) were not run against PS's own one-pass threshold, only PB's (E7).
3. S-E is untested in situ (closure capture in `update_state!` on 1.10, compile time, `@simd` bit changes). It needs an orchestrator A/A–A/B before any "no slowdown" claim.
4. On Julia 1.10 the NaN-propagating `max` loops are scalar (about 10× slower than 1.13). That is not a correctness issue and was not pursued.
5. The E15 small-scale non-convergence is documented guidance ("rescale", docs/src/choosing-solver.md); it is not quantified here as a policy question and belongs to #352/#284.
6. Trial counts differ slightly between Julia versions (15,312 vs 15,067) because BLAS and libm differ; no correctness difference.
7. `_scaled_norm` in sqrtlasso.jl looks like a duplicate of `_se_norm(Float64,·)`; the verdict is left to Agent A.
