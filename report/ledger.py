#!/usr/bin/env python3
"""Ownership ledger of PS #353 as data, rendered to Markdown tables with revision-pinned source links.
Usage: ledger.py OUT_DIR   (writes ledger-sqrt.md, ledger-ls.md, ledger-pgd.md, ledger-pb.md, ledger-counts.txt)"""
import sys, os, collections

PS = "https://github.com/mlakolar/ProximalSolvers.jl/blob/dac9f4b6819d9321117ee3cf3549e9e46a043f01/"
FILES = {"SQ": "src/cd/sqrtlasso.jl", "LS": "src/cd/leastsquares.jl", "MO": "src/cd/models.jl", "SO": "src/cd/solver.jl",
         "IM": "src/solvers/image_models.jl", "BL": "src/blocks.jl", "UT": "src/utils.jl", "LI": "src/line_searches.jl",
         "PG": "src/solvers/proximal_gradient_descent.jl", "SV": "src/solve.jl", "AP": "src/solvers/accelerated_proximal_gradient_descent.jl"}

def src(f, a, b=None):
    b = b or a
    return f"[{f}:{a}" + (f"-{b}" if b != a else "") + f"]({PS}{FILES[f]}#L{a}" + (f"-L{b}" if b != a else "") + ")"

# (helper names, file, first line, last line, executable lines, call sites, purpose + guarantee, path,
#  PB equivalent, class, action, net savings, correctness, performance, dependencies)
ROWS = collections.OrderedDict()

ROWS["sqrt"] = [
 ("`SqrtLSModel`, `cdmodel`, forwarders (`initialize!`, `coordinate_scale`, `response_scale`, `_cache`, `loss_value`, `_result_gap`, `_uncertified`)", "SQ", 16, 44, 24,
  "SO:506-512 hooks", "Model state around an `LSModel` with scale 1; `loss_value` is PB `value_from_residual`. Plain values.", "setup",
  "`leastsquares_data`, `value_from_residual` (public, used)", "A", "keep", "0", "n/a", "n/a", "#332, #307"),
 ("`_prepare!`", "SQ", 49, 63, 15, "SO:508", "Per-solve setup: step level `T(λ0)`, brackets of λ0, floor `16 eps(T) ‖y‖`, two Float64 work vectors.", "setup",
  "none", "B", "keep; under R1 the norm comes from `_se_norm(Float64, y)`", "0", "n/a", "once per solve", "R1"),
 ("`_level_brackets`", "SQ", 70, 84, 15, "SQ:51", "Float64 numbers `lo ≤ λ0 ≤ hi` by exact comparison, for eight level types. Rigorous bracket.", "setup",
  "none", "B", "keep (a 7-line form exists, 0 violations on 4,513 levels, but it edits an input of the certificate proof for 8 lines)", "0", "certificate input", "once per solve", "#332"),
 ("`_scaled_norm`", "SQ", 89, 102, 14, "SQ:57 (setup), SQ:274 (cold)", "`‖v‖₂ = s·2^e` in Float64 by `ldexp` scaling. Stable value, not a bound.", "setup / cold",
  "none public. PS's own `_se_norm(Float64, ·)` (IM:74) computes the same quantity; PB private `_residual_squares` is the same family with a compensated sum", "C (PS-internal duplicate)",
  "**delete** (R1; alone as R1-min)", "−14 exec inside R1; −13 net as R1-min (the cold caller gains one line); −1 concept (a third scaled-norm algorithm in PS). PB+PS total decreases",
  "Max relative difference to `_se_norm` 1.6e-15 over 1,567 vectors across both ranges; `_se_norm` is the more accurate at large n (n=10⁵: 0.04–1.6 vs 31–168 eps(Float64))", "`_se_norm` 1.2–3.2× faster (indicative); setup/cold only", "R1; PB #896 exposure removed"),
 ("`_column_dot_rsqr`", "SQ", 105, 124, 20, "SQ:152", "Fused plain `@simd` sums `a = ‖X_k‖²` (cold cache only), `b = X_kᵀr`, `ρ² = ‖r‖²` in T. Ordinary values.", "hot",
  "none. LS `_column_dot` (LS:38) is the same loop without ρ²", "B", "keep; do not merge with `_column_dot`", "0",
  "Merge tested: warm path bit-identical, cold path bits change in 3/8 (1.10) and 8/8 (1.13) cases", "Merged kernel: Julia 1.10 Float32 cold pass 1.58–1.96× slower", "#278 item 4"),
 ("`_distance_sqr`", "SQ", 126, 133, 8, "SQ:189", "`‖r − q X_k‖²` in T, recomputed where `ρ² − b q` cancels (d² < ρ²/16).", "hot (rare branch)",
  "none", "B", "keep", "0", "Without it 820/4000 (Float32) and 1189/4000 (Float64) nearly parallel steps exceed the step bound, worst 4.4e5×", "one extra pass only when r is nearly parallel to X_k", "#332"),
 ("`_clean_sum`", "SQ", 137, 137, 1, "SQ:181, SQ:190", "`isfinite(s) & (s ≥ n·floatmin/eps)`: underflowing squares change s by ≤ eps²/2 relative.", "hot",
  "PB private `_squares_normal` (same constant, without `isfinite`; 0/20,110 disagreements except s = Inf)", "D (too small to act on)", "keep as one line", "0",
  "The constant is load-bearing: with `4n·floatmin` the step bound is exceeded by up to 1152×", "one compare", "PB #698 (no interface warranted)"),
 ("`coordinate_step!`", "SQ", 150, 165, 16, "MO:34 (`_visit!`)", "The coordinate minimizer with the refusals before any write. Reuses LS `_residual_axpy!`, `_flat_column`, `_coordinate_minimizer`, `_refuse_curvature`.", "hot",
  "`prox_block` (public, used in `_sqrt_minimizer`)", "B", "keep", "0", "0 bytes per pass", "per visit ≈ LS visit ×0.9–1.2", "#332, #278"),
 ("`_sqrt_minimizer`", "SQ", 178, 198, 21, "SQ:158", "Closed-form minimizer `shrink(c, λd/√(a(a−λ²)))`, accurate to `(37γ_n+56u)·max(‖ρ‖,‖r‖)` in objective. Five-comparison band test on p, γ, τ before `prox_block`.", "hot",
  "`prox_block(NormL1, c, k, γ)` (public, used)", "B (formula) / E (band test)", "keep the formula; **restructure under R1** (threshold formed in range, no band test)", "−9 exec in R1",
  "see R1", "see R1", "R1"),
 ("`_sqrt_band_step`", "SQ", 202, 205, 4, "SQ:197, SQ:278", "`shrink(c, τ)` with τ from `_sqrt_threshold64`, capped at floatmax(T).", "cold",
  "`shrink` (public)", "E", "**delete** (R1)", "−4 exec", "see R1", "0 calls on ordinary data", "R1"),
 ("`_sqrt_threshold64`", "SQ", 210, 217, 8, "SQ:203", "`τ = (λ/ra)(d/w)` in Float64 with `frexp`/`ldexp`, so the quotient is not formed outside the range. Stable value.", "cold",
  "none. Same technique, different formula, as LS `_threshold(Float64)`", "E", "**delete** (R1)", "−8 exec; −1 concept", "see R1", "0 calls on ordinary data", "R1; PB #896 exposure removed"),
 ("`_sqrt_offrange_step`", "SQ", 241, 279, 39, "SQ:181, SQ:190", "The whole step in Float64 on power-of-two scaled copies of the column and the residual. Stable value with absolute errors at the scale of the data.", "cold",
  "none", "E", "**replace** (R1): Float32 re-runs the fast formula in Float64; Float64 keeps r = 0 and refuses the rest", "−39 exec, +8; −1 concept (the scaled shadow step)",
  "see R1 for the exact lost Float64 ranges", "0 calls on ordinary data; when taken on every visit it is 35–200× the fast path", "R1; PB #366 items 3, 5"),
 ("`_check_residual`", "SQ", 281, 286, 6, "SQ:153", "Entry-by-entry refusal of a non-finite residual before any branch.", "cold",
  "none", "B", "keep", "0", "tested contract (test/sqrt_lasso.jl:598)", "cold", "#348 round 1"),
 ("`_stop_check!`, `_above_floor`", "SQ", 302, 328, 26, "SO (`_cd_plain!`, `_cd_momentum!`) via MO:20", "Certified / tighten / uncertified decision and the tightening floor.", "cold (per converged full pass)",
  "none", "B", "keep; policy owned by #352", "0", "n/a", "n/a", "#352"),
 ("`_round_up`", "SQ", 330, 333, 4, "SQ:305", "Smallest T ≥ v. Directed rounding.", "cold",
  "Base `T(v, RoundUp)`", "C (Base)", "**replace** (R2)", "−4 exec, +0", "{ROUNDUP}", "cold", "R2"),
 ("`_up`, `_dn`, `_CERT_TARGET`", "SQ", 339, 342, 3, "SQ:504-524", "`nextfloat`/`prevfloat` of a round-to-nearest result: outward bounds of each certificate operation.", "cold",
  "none (PB has no directed rounding)", "B", "keep", "0", "see `_certify!`", "cold", "#332"),
 ("`_certify!`", "SQ", 441, 526, 86, "SQ:303", "Residual-direction dual point with outward rounding: a proved upper bound on `(P−P*)/P*`. Rigorous one-sided bound.", "cold (per converged full pass)",
  "none. `kkt_violation` is a different object; PB's `SqrtLeastSquaresLoss` value bound `(n/2+4)eps_T` is in T and cannot back a Float32 certificate (6e-4 at n = 10⁴, above the 1e-4 target)", "B; its 97-line proof comment is F",
  "keep. The proof text may move to developer docs (docs-only, optional)", "0 exec",
  "4,822 BigFloat-512 checks (2,185 certified), 0 violations, Julia 1.10 and 1.13, FMA-contracted code", "once per converged full pass", "#332 ruling (certificate stays in PS); #352"),
]

ROWS["ls"] = [
 ("`LSModel`, `_scale_type`, `cdmodel`, `_activeentries`, `_cache`", "LS", 8, 25, 19, "SO:506; SQ:28-32; LS:260-267", "Borrowed X, y, α from PB `leastsquares_data`; residual `r` and curvature cache `a` in T.", "setup",
  "`leastsquares_data` (public, used)", "A", "keep", "0", "n/a", "n/a", "#307, #295"),
 ("`initialize!`, `_initialize!` (scalar and block)", "LS", 26, 37, 12, "SO:507; SO:445 and SO:476 (momentum reset and refresh); LS:269-281", "`r = y − Σ X_j x_j` by one axpy per nonzero entry; curvature cache reset to NaN.", "setup",
  "none", "B", "keep", "0", "n/a", "the reset at each momentum refresh makes 5–6 % of dot calls cold: #290 (deferred)", "#278, #290"),
 ("`_column_dot` (two methods)", "LS", 38, 53, 16, "LS:97; LS:595", "`b = rᵀX_k` (and `a = ‖X_k‖²` on a cold cache), plain `@simd` sums in T. Ordinary values, no recovery.", "hot",
  "none public (PB `_scaled_dot` is dead code and a different shape)", "B", "keep", "0", "underflow of the product at extreme scales: see Q9", "the `a` cache avoids a 1.2–1.7× slower pass", "#278 item 4"),
 ("`_residual_axpy!`", "LS", 54, 60, 7, "LS:33, 106, 276, 632; SQ:163", "`r −= h X_k`, one `@simd` pass.", "hot",
  "none", "A (shared by LS, group and sqrt)", "keep", "0", "n/a", "n/a", "#278 item 4"),
 ("`_sqnorm!`", "LS", 61, 71, 11, "LS:186 (`coordinate_scale`), LS:362 (`_singleton_curvature`)", "In-order (non-`@simd`) `Σx²` with a cache write. Ordinary value.", "cold (`coordinate_scale`: cache always filled in production) / setup (singleton groups)",
  "Base `sum(abs2, view)`", "B, redundant (a second `Σx²` algorithm beside `_column_dot`'s)", "**delete** (R3)", "{SQNORM_SAVE}",
  "{SQNORM_CORR}", "{SQNORM_PERF}", "R3; #278 V3"),
 ("`_flat_column` (LS:72-77), `_flat_group` (LS:345-350)", "LS", 72, 77, 12, "LS:98, SQ:154, LS:347; LS:309", "All entries `== 0`.", "cold / setup",
  "Base `all(iszero, view)`", "C (Base)", "**replace** (R2)", "{FLAT_SAVE}", "{FLAT_CORR}", "none", "R2"),
 ("LS `coordinate_step!`", "LS", 96, 108, 13, "MO:34", "`shrink(old + b/a, λ/(s a))` (ridge weight for ElasticNet); refuses a zero non-flat or non-finite curvature before any write.", "hot",
  "`prox_block`, `shrink` (public, used)", "A", "keep", "0", "in-band step bit-identical to the pre-#294 step (test/cd_numerics.jl:1317)", "n/a", "#294, #311"),
 ("`_coordinate_minimizer`", "MO", 28, 32, 5, "LS:101; SQ:158", "The penalty's own minimizer for a flat column, through `prox_block`.", "cold", "`prox_block` (used)", "A", "keep", "0", "n/a", "cold", "#350 edits its comment"),
 ("`_scaled_prox`", "LS", 109, 114, 6, "LS:101", "`p = s a`, `γ = 1/p`; PB `prox_block` when both are ≥ floatmin(S), else `_outside_band`.", "hot (two compares)",
  "PB's own range test cannot replace it: γ is already 0, Inf or subnormal before PB sees it", "B", "keep", "0", "band p ∈ [2^-126, 2^126] (Float32), [2^-1022, 2^1022] (Float64)", "two compares", "#294"),
 ("`_outside_band`, `_refuse_curvature`", "LS", 116, 122, 6, "LS:113; SQ:156", "Refusal of a non-finite curvature, else forward.", "cold", "none", "B", "keep", "0", "n/a", "out of line", "#294"),
 ("`_exceptional_step` (NormL1, ElasticNet, fallback), `_refuse_ridge_step`", "LS", 133, 144, 9, "LS:118", "`shrink(c, min(τ, floatmax))` with `τ = λ/(s a)` formed without `p` or `1/p`; ElasticNet λ2 > 0 and other penalties are refused.", "cold",
  "`shrink` (used)", "B (an E candidate, rejected)", "keep. Refusing instead would save ~17 exec lines and lose Float32 columns with ‖X_k‖ < 1.1e-19 or in (9.2e18, 1.8e19), which #294 added after 906 false convergences", "0",
  "0 hits in 6,080 ordinary solves (~77 M visits); the generic fallback is unreachable from `solve!` and reachable by direct model construction (tested)", "cold", "#294; #350 adds a weighted method here"),
 ("`_threshold` (Float32, Float64)", "LS", 152, 158, 7, "LS:134", "`τ = λ/(α a)`: Float32 in Float64 (exact product); Float64 by `frexp`/`ldexp`. Stable value within 1 ulp.", "cold",
  "none (`_threshold_product` forms a product of three factors, not this quotient)", "B", "keep", "0", "max error 0.50 eps (Float32), 0.89 eps (Float64) over 20,000 triples; 1.10 and 1.13 differ only below 2^-1074", "cold", "#294; PB #896"),
 ("`coordinate_scale` (scalar, and block at LS:288), `_curvature_scale`", "LS", 186, 196, 10, "MO:35 (`_visit!`, when scaled and h ≠ 0); LS:288", "`√(s a)` rounded to T: `sqrt(T(p))`, or roots first where `p` leaves the range. Stable value.", "hot (after a nonzero update); branches cold",
  "none", "B", "keep", "0", "n/a", "one multiply, two compares, one root", "#293, #295 (no reciprocal cache)"),
 ("`response_scale`", "LS", 197, 213, 17, "SO:302 (`_tolerances`, once per solve); SQ:38", "`√(s Σy²)` in three tiers: clean one-pass sum; `T(sqrt(p))` for a scale type wider than T; exceptional.", "setup",
  "PB `value_from_residual(Scaled(SqrtLeastSquaresLoss(y, X), √s), y)` returns `√s‖y‖` with range recovery, but allocates and costs +3–6 % on 2–4 µs solves", "B, simplifiable",
  "keep. Dropping tier 2 is deferred (section C): it moves accepted inputs at the normal-range boundary. The single `_SE` path (−21) and the PB oracle (−23) are not recommended", "0 now (−7 if tier 2 goes)", "{RS_CORR}", "9 ns at n = 20, once per solve", "#293, #295"),
 ("`_response_scale_exceptional`, `_se_scale`, `_refuse_response_scale`", "LS", 220, 237, 17, "LS:212; LS:224-230", "`√s‖y‖` as an `_SE`, rounded once to T; refuses a result that is not a normal number of T.", "cold (setup)",
  "none; uses PS `_se_norm`, `_root_scale`, `_se_mul`", "A (shared with APG inside PS)", "keep", "0", "n/a", "1.2 µs at n = 1000, once per solve", "#293"),
 ("`loss_value` (scalar and block)", "LS", 239, 283, 2, "SO:512", "`value_from_residual(f, r)`.", "setup", "it **is** the PB oracle", "A", "keep", "0", "n/a", "n/a", "#307, #277"),
 ("`BlockLSModel`, block `cdmodel`, block `initialize!`, block `response_scale`", "LS", 251, 282, 31, "SO:506-507", "Group curvature bounds ℓ, scratch vectors, Float64 Gram buffers.", "setup", "none", "B", "keep", "0", "n/a", "buffers allocated on first Gram use", "#275, #326"),
 ("`_prepare!` (block), `_group_curvature!`, `_check_step_band`", "LS", 304, 344, 35, "SO:508; LS:318, 612", "Routing per group (flat, singleton, Gram now or deferred) and the step-band refusal.", "setup / lazy",
  "none", "B", "keep", "0", "the refusals that can be predicted (`_curvature_deferrable`) are raised in `_prepare!`, before the first pass and before the RNG is used; a deferred group computes its curvature at its first visit (LS:612) and can still be refused there (eigensolver failure or a non-finite result), after the RNG has advanced, with the caller's x preserved, as docs/src/numerics.md states", "3–32 % of a singleton-group solve today (R3 reduces it); the Gram buffers and the eigensolve allocate at the first use, which for a deferred group is inside a pass", "#326"),
 ("`_singleton_curvature`", "LS", 361, 369, 9, "LS:312", "`ℓ = nextfloat(a(1+2n eps))`: rigorous majorizer of one column.", "setup", "none", "B", "keep; under R3 the sum is `sum(abs2, view)`", "0", "{SINGLETON_CORR}", "n/a", "R3"),
 ("`_gram_curvature`", "LS", 402, 432, 31, "LS:334", "Upper bound on `λmax(X_GᵀX_G)`: Float64 Gram, `eigvals`, margin `4(n+mk²) eps`. Rigorous up to the eigensolver model.", "setup / lazy",
  "`lipschitz`, `opnorm2`, `_opnorm_upper`: none is a rounded-up bound (`opnorm2` is documented \"not a certified upper bound\")", "B", "keep", "0",
  "PB `lipschitz` violates `ℓI − G ⪰ 0` in 453/800 groups (BigFloat Cholesky); `_gram_curvature` in 0/800", "eigensolve once per group and solve", "#275, #339"),
 ("`_curvature_deferrable`, `_screen_floor`, the three `_refuse_group_*`/`_refuse_block_value`", "LS", 481, 520, 36, "LS:315; LS:601; LS:363-430, 342, 617, 625", "O(n·mk) test that no refusal can occur (so the Gram can be lazy); the zero-block screen floor; out-of-line throws.", "setup / cold",
  "none", "B; ~100 comment lines duplicate docs/src/numerics.md:415-600 (F)", "keep; the duplicated proof text is a docs-only item", "0 exec", "95 % of screen attempts return a zero certificate; 22,815 lazy and 0 eager Gram computations on ordinary data", "n/a", "#326 option B"),
 ("group `coordinate_step!`", "LS", 576, 635, 60, "MO:34", "Block step: `b = X_Gᵀr`, screen, trial `old + b/ℓ`, `prox_block!` at `1/(sℓ)`, residual update.", "hot",
  "`prox_block!`, `norm` (used)", "A/B", "keep", "0", "refuses a non-finite trial before any write", "allocation-free once ℓ is cached", "#326"),
 ("`_restartdot`, `_momentum_step!` extrapolation", "SO", 435, 490, 27, "SO:461; `_cd_momentum!`", "Sign of the restart inner product over active values; extrapolation of the residual cache.", "hot (per active pass)",
  "`dot` would need two temporaries", "B", "keep", "0", "a NaN or an overflow gives no restart", "n/a", "#278 item 3"),
 ("`_tolerances`, `_visit!`, `_sweep!`", "SO", 276, 306, 29, "`_cd_plain!`, `_cd_momentum!`; MO:33-38", "`tol × response_scale`; `|h| × coordinate_scale`; refusal of a non-finite change.", "setup / hot",
  "none", "B", "keep", "0", "n/a", "n/a", "#288, #278 (V2 NO-GO); #352 owns the policy"),
 ("`_shuffle!`, `_pass!`, `_cd!`, `_cd_plain!`, `_usemomentum`, `_cd_momentum!`, `_momentum_start!`, `_momentum_reset!`, `_momentum_update!`, `_momentum_refresh!`", "SO", 249, 480, 136, "`_run_cd!` (SO:505)", "Pass drivers: traversal order, active and full passes, momentum bookkeeping, the stop tests on the largest scaled change.", "hot (driver)",
  "none", "B", "keep (#278: no consolidation of the two loops; hooks, RNG and traversal unchanged)", "0", "n/a", "n/a", "#278, #288, #311; #352 owns the stop tests"),
]

ROWS["pgd"] = [
 ("`_LSImage`, `_image_model`, `_image_buffer`, `_image!`, `_value!`, `_value_and_gradient!`", "IM", 5, 20, 14, "PG, AP state and steps", "The image `Xx` and the loss value and gradient at an image.", "hot",
  "these **are** PB's public predictor oracles", "A", "keep", "0", "n/a", "n/a", "#277, #307"),
 ("`_SE`, `_se_zero`, `_renormal`, `_SE{T}(x)`", "IM", 27, 34, 7, "AP:108-111; IM constants; LS:225-227", "Nonnegative reals `s·2^e`, s ∈ [1,2), `e::Int`. Each operation is one round-to-nearest significand operation (≤ 1 u).", "hot (O(1) per trial) / setup",
  "none public. PB private `_parts`, `_ProjectionScale` carry a product only", "B", "keep (the #279 conclusion stands against PB pin and master)", "0", "0 order or invariant violations in 200,000 pairs per type", "never inside a vector loop", "#279, #272, PB #698"),
 ("`_se_mul` (2, 3, 4 arguments)", "IM", 35, 39, 4, "IM:78, 88, 153, 209-212, 242-258, 273-274; LS:225", "Product, ≤ 1 u.", "hot",
  "PB private `_parts_product` gives the same bits in range (0/100,000 mismatches) but returns one T value: `2^900·2^900` is Inf there and `(1.0, 1800)` here", "B", "keep the fixed arities (#272)", "0", "worst 1.00 u", "0 B on 1.10 and 1.13", "#272/#276"),
 ("`_se_le`, `_se_add`, `_se_sub`", "IM", 40, 52, 12, "IM:50, 212, 245-258, 272-274", "Exact comparison; sum and `max(a−b, 0)` via `ldexp`, ≤ 1 u.", "hot",
  "none (`_ExpSum` is a compensated accumulator without compare or subtract)", "B", "keep", "0", "exact order on 200,000 pairs; `ldexp` truncation on 1.10 costs ≤ 2^-1074 absolute", "O(1)", "PB #896"),
 ("`_sumsq_scaled`, `_sumsq_scaled_diff`", "IM", 55, 70, 14, "IM:78; IM:87", "`Σ(v/m)²` and `Σ((a−b)/m)²`, `@simd`.", "cold",
  "PB private `_residual_squares` (power-of-two scaling, compensated sum; 1.4 u vs 3.1 u)", "B", "keep. {SC}", "0", "worst error 0.44 of γ_{n+4}", "cold; every trial only at data scale ≲ 2^-45 (Float32), 2^-400 (Float64)", "#279"),
 ("`_se_norm`, `_se_norm_diff`", "IM", 74, 89, 14, "AP:127 (once per solve), IM:116, LS:223; IM:120", "`‖v‖`, `‖a−b‖` as `_SE` in the two-pass scaled form; relative error ≤ γ_{n+4}. Stable value with a proved a priori error, not one-sided.", "setup / cold",
  "PB `norm_diff` returns a T scalar: a subnormal norm loses relative accuracy (153/4000 Float32, 69/4000 Float64 violations of the level required)", "B", "keep; `_se_norm` becomes the one scaled norm of PS under R1", "0", "0 violations in 3,000 vectors per type; worst 0.34 of the bound", "setup / cold", "#279, PB #698"),
 ("`_sumsq2`, `_sumsq_diff`", "IM", 92, 108, 15, "AP:237; IM:244", "`Σd²` and `Σx²` in one pass; `Σ(a−b)²` in one pass. Ordinary values.", "hot (one p-pass and one n-pass per trial)",
  "PB private `_sumabs2_diff` is the same loop as `_sumsq_diff` (bitwise 100/100)", "B / D (too small to act on)", "keep", "0", "the certificate proof uses \"any summation order\"", "replacing `_sumsq2` adds a pass", "PB #698"),
 ("`_se_norm_onepass`, `_se_norm_diff_onepass`", "IM", 114, 121, 8, "AP:238-239; IM:244, 256", "One-pass sum when finite and ≥ `4n·floatmin`, else the scaled form.", "hot",
  "PB `_squares_normal` has a threshold 2.1e6 (Float32) / 1.1e15 (Float64) times higher: it would send Float32 steps below ~3e-16 per entry to the cold path", "B", "keep", "0", "0 violations", "n/a", "#267"),
 ("`_unit`, `_gamma`, `_BoundConstants`, `_bound_constants`", "IM", 125, 213, 33, "AP:107, 153, 278", "The constants of the certified test (γ's, the κ = 32u budget, underflow terms).", "setup",
  "none", "B", "keep", "0", "constants within 2.2 u of an all-BigFloat chain; ≥ 27 u of the 32 u budget unused", "once per solve", "#267"),
 ("`_frobenius_upper`", "IM", 137, 155, 19, "IM:203", "Upper bound on `‖X‖_F` with explicit rounding factors. The one helper here that is one-sided by construction.", "setup",
  "none (`opnorm2`, `_opnorm_upper` are spectral and not one-sided)", "B", "keep; its first loop can call `_sumsq64` (R2)", "{SD_SAVE}", "290 matrices per type, 0 violations", "one pass over X", "#267; R2"),
 ("`_significand_exponent` (two methods)", "IM", 163, 167, 5, "IM:170", "Significand and exponent of the loss scale; any scale that is not an IEEE float, which for `solve!` means the admitted integer and Bool scales, goes through a 256-bit BigFloat conversion.", "setup",
  "none", "E (generality beyond the scales `solve!` admits, all of which are exact in Float64)", "{SB_ACTION}", "{SB_SAVE}", "{SB_CORR}", "removes a BigFloat allocation per solve for an integer or Bool scale", "R2; #307 narrowed the scale types"),
 ("`_root_scale`", "IM", 169, 177, 9, "AP:154; LS:225", "`√α` as `_SE`, ≤ 0.91 u.", "setup", "none", "B", "keep", "0", "66 scales per type", "once per solve", "#267"),
 ("`_bound_certified!`, `_image_error_bound` (IM), `_check_bound_size` (AP:276-281)", "IM", 237, 275, 35, "AP:248; AP:175, 203; AP:318", "Accept a trial only when `√α‖Xd‖ ≤ (1+4ε)√L‖d‖` is proved from the cached image, a certified early reject, else a fresh product. Rigorous decision through the fixed budget κ.", "hot",
  "none", "B", "keep", "0", "~22,000 decisions per Julia version on an L grid, ~15,000 accepted trials of 132 real solves rechecked in BigFloat: 0 violations", "0.23–0.47 µs per call vs 0.5–140 µs per `X*x`; the early reject ends 20–23 % of trials without a product", "#265/#267, #271, #352"),
 ("`Blocks` forwards (`_norm`, `_norm_diff`, `_norm_inf`, `_dot`, `_eltype`, `_copy`, `_similar`, `_dense_similar`, `_copyto!`) and `_sub!`, `_step!`, `_extrapolate_point!`", "BL", 7, 18, 12, "PG, AP, LI, UT", "Owner seam for the iterate.", "hot",
  "Base and PB `norm_diff` (already forwarded)", "A", "keep", "0", "n/a", "n/a", "#279, #268, #230"),
 ("`_dot_diff`, `_maxabs_axpy`, `_maxabs_residual`, `_maxabs_stepdiff`", "BL", 19, 59, 29, "LI:139; UT:84; UT:32; AP:295", "Fused reductions over two or three operands without a temporary.", "hot",
  "none", "B", "keep (a closure-based generic `fsum`/`fmax` would remove ~40 lines but adds an abstraction #279 declined; untested in situ)", "0", "n/a", "on Julia 1.10 the NaN-propagating `max` loops are scalar", "#279, #268"),
 ("`_maxabs_diff`", "BL", 44, 50, 7, "AP:289 (`g_residual`, every iteration); IM:83", "`max|xᵢ − yᵢ|`, NaN propagates.", "hot",
  "**PB public `norm_diff(x, y, Inf)`**, already forwarded as `Blocks._norm_diff`", "C", "{SA_ACTION}", "{SA_SAVE}", "{SA_CORR}", "{SA_PERF}", "R2"),
 ("`f_residual`, `g_residual`, `convergence_assessment`, `gradient_converged!`, `_gradient_test`, `_unchanged`, `_state_norm`, `_state_normdiff` (PGD forms in utils.jl; APG `g_residual`, `gradient_converged!` at AP:289-297)", "UT", 28, 178, 60, "PG, AP `solve!` loops", "Stopping quantities, all plain T.", "hot",
  "Base, PB `norm_diff`", "B", "keep; policy owned by #352. No stopping quantity needs `_SE`", "0", "n/a", "n/a", "#352, #270, #296"),
 ("`_stationary!`, `_lambda_max!`, `_gradient_at_x!`, `_converted_penalty`, `_l1_level`", "UT", 122, 167, 29, "PG, AP stopping gate", "Stationarity check through PB `kkt_violation` and the PB gradient oracle.", "cold (at a stop)",
  "`kkt_violation`, predictor oracles (public, used)", "A", "keep", "0", "n/a", "n/a", "#341/#343; #350 edits `_converted_penalty`, `_l1_level`"),
 ("`_step_curvature` (T and Float32), `_sumsq64`, `_step_norms64`", "PG", 188, 243, 31, "PG `check_rejection!`", "Direct-curvature backtracking test; Float32 norms accumulated in Float64.", "hot",
  "none", "B", "keep", "0", "documented allowances", "n/a", "#284, #287, #308"),
 ("`backtrack!`, `next_curvature`", "LI", 77, 170, 54, "PG:135, AP:217", "Backtracking loop and curvature decay.", "hot", "none", "B", "keep", "0", "n/a", "n/a", "#284, #316, #321"),
 ("`_allfinite`, `_scalar_parameter`, `_check_loss_scale`, `_float64_scale_ok`, `_loss_scale_error`", "SV", 3, 50, 37, "SV:103 and the data checks", "Input-domain guards: finite data, a level representable in T, a loss scale that is Float32, Float64, a fixed-width integer or Bool and converts to T exactly or to a finite nonzero value.", "setup",
  "none", "B", "keep. R2's `Float64(α)` in `_root_scale` is exact because of `_check_loss_scale`", "0", "`Int128(2)^100` and `true` are admitted and exact in Float64; `Int128(2)^100 + 1` is refused for Float64 data", "once per solve", "#307, #322, #329"),
 ("`_check_penalty`, `_weight_ok`, `_weight_error`, `_check_data`, `_check_sqrt_data`, `_check_sqrt_penalty`, `_check_problem`, the owner and block checks, `_check_keywords`, `_check_start`", "SV", 55, 205, 113, "`solve!` methods", "Validation of the supported loss, penalty, iterate and storage combinations before anything is written.", "setup",
  "none", "B", "keep", "0", "refusals precede every write", "once per solve", "#234, #332; #350 edits `_check_penalty`"),
 ("PGD `initial_state`, `update_state!`", "PG", 92, 160, 66, "`_solve_gradient!` (SV:207)", "The PGD iteration: cached image, trial step, mode switch, curvature update.", "hot",
  "PB predictor oracles and `value_and_prox!` (used)", "B", "keep", "0", "n/a", "n/a", "#284, #287, #308, #309"),
 ("`value_and_gradient_at_x!`, `check_rejection!` (PGD methods of the line-search hooks)", "PG", 170, 182, 7, "LI:85-90, LI:159", "The fresh value and gradient at a trial point, and the direct-curvature verification with one extra product `X·Δx`.", "hot (per rejected or verified trial)",
  "none", "B", "keep", "0", "n/a", "one `X·Δx` product when the cheap test is not conclusive", "#284"),
 ("`_stagnated`", "PG", 327, 329, 3, "SV:249", "Whether a Float32 PGD run stopped at numerical stagnation.", "cold",
  "none", "B", "keep; policy owned by #352", "0", "n/a", "n/a", "#308, #312, #352"),
 ("APG `initial_state`, `update_state!`", "AP", 116, 196, 79, "`_solve_gradient!` (SV:207)", "The APG iteration: extrapolation, restart, the norms `normx`, `normx_previous` and the image-error bookkeeping that the certified test reads.", "hot",
  "PB predictor oracles and `value_and_prox!` (used)", "B", "keep", "0", "warmed `update_state!` allocates 0 B on Julia 1.10 and 1.13", "n/a", "#265/#267, #272"),
 ("`_prox_grad_step!`", "AP", 217, 264, 39, "AP:191", "One APG trial: the explicit zero-step acceptance, the retry when a norm is not available, and the dispatch to `_bound_certified!`.", "hot",
  "none", "B", "keep", "0", "the `nothing` guards are reachable on an overflowing `X d̂`", "n/a", "#267, #279"),
]

ROWS["pb"] = [
 ("`shrink`, `prox_block(!)`, `value_and_prox!`, `kkt_violation`, `norm_diff`", "PB", 0, 0, 0, "LS, SQ, UT, BL", "Proximal operators, optimality scores, norm of a difference. Documented in `numerics.md` as ordinary path plus selective recovery; no directed result.", "hot",
  "exported", "A", "keep", "0", "n/a", "exported `shrink` (max/min form) is 4.9 ns vs 4.3 ns for PB's private select form in a dependent chain on Julia 1.10", "PB #366"),
 ("`leastsquares_data`, `value_from_residual`, `value_from_predictor`, `value_and_gradient_from_predictor!`", "PB", 0, 0, 0, "LS:1, 239; SQ:41; IM:3, 18-20", "Loss data and values at a caller-held residual or predictor.", "hot",
  "qualified `public` (Julia ≥ 1.11), importable by name on 1.10", "A", "keep", "0", "n/a", "n/a", "PB #843, #911/#915"),
 ("`_residual_squares`, `_scaled_norm`, `_square_scaled_sum` (private)", "PB", 0, 0, 0, "PB: leastsquares, sqrnorml2, sqrt_leastsquares, norml2, groupnorml2", "`Σ(xᵢ−yᵢ)² = s·2^(2k)` with exact power-of-two scaling and a compensated sum. Stable value; the error bound is stated only in comments.", "cold in PB",
  "private", "D (candidate only)", "no interface now: the PS consumers are `_se_norm` (APG proof tied to its own formula) and sqrt-lasso `_scaled_norm` (deleted by R1)", "at most −25..−35 PS exec with a new supported PB name and a stated theorem", "more accurate than both PS forms (1.4 u)", "cold", "PB #698 (defer)"),
 ("`_sumabs2_diff`, `_squares_normal` (private)", "PB", 0, 0, 0, "PB: 4 and 7 call sites", "One-pass `Σ(x−y)²`; the clean-sum predicate.", "hot in PB",
  "private", "D (too small)", "no interface: 7 + 1 PS lines", "−7, −1", "bitwise equal to PS `_sumsq_diff`; equal to PS `_clean_sum` except at Inf", "equal", "PB #698 (defer)"),
 ("`_scaled_product`, `_ExpSum`, `_parts`, `_ProjectionScale` (private)", "PB", 0, 0, 0, "PB wrappers and recoveries", "Range-safe product rounded once to T; compensated exponent-frame sum.", "cold in PB",
  "private", "B on the PB side", "not a replacement for `_SE` (no compare, no clipped subtract, result limited to the range of T)", "0", "see `_se_mul`", "n/a", "PB #698, PS #279"),
 ("`opnorm2`, `lipschitz`, `_opnorm_upper`", "PB", 0, 0, 0, "PB LS and quadratic", "Spectral estimates, documented as not certified upper bounds.", "setup",
  "exported / private", "B on the PB side", "not a replacement for `_gram_curvature` or `_frobenius_upper`", "0", "see `_gram_curvature`", "n/a", "PS #275"),
 ("`_scaled_dot` (private)", "PB", 0, 0, 0, "none in `src` (tests only), pin and master", "Scaled dot product.", "dead", "private", "outside A–F (PB hygiene)", "mention on PB #698; not a PS matter", "8–9 PB exec", "n/a", "n/a", "PB #865"),
]

HEAD = "| Helper (source, exec lines) | Call sites | Purpose and guarantee | Path | PB equivalent | Class | Proposed action | Net savings | Correctness | Performance | Dependencies |\n|---|---|---|---|---|---|---|---|---|---|---|\n"
SUBS = {}
def load_subs(path):
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if "=" in line and not line.startswith("#"):
                k, v = line.rstrip("\n").split("=", 1); SUBS[k.strip()] = v.strip()
def fill(s):
    for k, v in SUBS.items(): s = s.replace("{" + k + "}", v)
    return s
def cs(text):  # turn "SQ:57" style references into links
    import re
    def rep(m):
        f, a, b = m.group(1), m.group(2), m.group(3)
        return src(f, int(a), int(b) if b else None)
    return re.sub(r"\b(SQ|LS|MO|SO|IM|BL|UT|LI|PG|AP|SV):(\d+)(?:-(\d+))?", rep, text)

def main(out):
    load_subs(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ledger-subs.txt"))
    counts = collections.Counter(); total = 0
    for sec, rows in ROWS.items():
        with open(os.path.join(out, f"ledger-{sec}.md"), "w", encoding="utf-8") as io:
            io.write(HEAD)
            for (h, f, a, b, n, calls, purpose, path, pb, cls, act, sav, corr, perf, deps) in rows:
                where = f"{src(f, a, b)} ({n})" if f != "PB" else "PB pin a19c59aa"
                cells = [f"{h} {where}", cs(calls), purpose, path, cs(pb), cls, cs(act), sav, corr, perf, deps]
                io.write("| " + " | ".join(fill(c).replace("|", "\\|") for c in cells) + " |\n")
                counts[cls[:1]] += 1; total += n if f != "PB" else 0
    open(os.path.join(out, "ledger-counts.txt"), "w").write(f"rows by class: {dict(counts)}\nexecutable lines covered (PS rows): {total}\n")
    missing = sorted({m for sec in ROWS for r in ROWS[sec] for c in r if isinstance(c, str) for m in __import__('re').findall(r"\{([A-Z_]+)\}", fill(c))})
    print("rows:", sum(len(v) for v in ROWS.values()), "counts:", dict(counts), "exec covered:", total, "unfilled:", missing)
if __name__ == "__main__": main(sys.argv[1])
