# Issue #353 Stage 0, Agent B: LS-CD and group-CD numerical helpers (full report)

**Note on files:** the harness blocked me from writing `RUN/agentB/report.md` ("subagents return findings as text"), so this message is the report. All scripts and raw outputs are on disk in `RUN/agentB/` and cited inline. RUN = `<RUN>`.

Audited PS `dac9f4b6` (worktree untouched; `git status` clean), PB pin `a19c59aa` (what PS loads), PB master `13891ccf` (only `kkt_violation`/score code differs in the areas I read). Julia 1.10.13 and 1.13.4, host i5-13600K, BLAS threads 10. **Julia 1.10.13 on this host reports `CPU_NAME = goldmont` (SSE-only codegen, no AVX2); 1.13.4 reports `raptorlake`.** SIMD lane count, hence the last bits of every `@simd` reduction and every timing, differ between the two (`vercheck.out`). Line counts are from `RUN/tools/loc-ps-dac9f4b.txt`. `leastsquares.jl` has 367 executable and 264 comment-only lines.

## 0. Top findings

1. **Hot path already minimal and shared.** `_column_dot`, `_residual_axpy!`, `prox_block` and `shrink` are plain and branch-light. PS imports only exported or documented PB API; no PB private name appears in `src/`. I found no PB function that removes a pass, temporary or branch from the coordinate loop.
2. **On 6080 ordinary solves (~77 M coordinate/group visits) every exceptional branch fired zero times** (`branchfreq.out`). That covers `_outside_band`, `_exceptional_step`, the two-roots and `sqrt(p)` branches of `_curvature_scale`, tiers 2 and 3 of `response_scale`, the ridge refusal, and `_sqnorm!`'s cold branch via lasso/elastic-net scale.
3. **Four small PS-internal simplifications with evidence.** None touches a coordinate-loop body, traversal, RNG, momentum or accepted-update semantics.
   * **C4** delete `_sqnorm!`: −10 net executable lines, −1 concept. The measured effect is a 3–6x faster `_prepare!` for singleton groups (details in the ledger).
   * **C3** collapse `response_scale`: C3a −6 lines with ordinary bits unchanged; C3b −21; C7 −23 via PB's public sqrt-loss oracle. C7 is the only genuine "reuse existing PB public API" I found.
   * **C2** sqrt-lasso `_scaled_norm` → existing `_se_norm(Float64,·)`: −14 lines. The file is Agent A's.
   * **C5** `_flat_column`/`_flat_group` → `all(iszero, view)`: −9 lines, cosmetic.
4. **Rejected with evidence:**
   * Merging `_column_dot` into sqrt's `_column_dot_rsqr` via dead-code elimination: cold-path bits change, and the Julia 1.10 Float32 cold pass is up to 1.96x slower.
   * PB `lipschitz` for group ℓ: it violates majorization in 57 % of groups.
   * PB private norm kernels in PS: private, different guarantee, and APG's rigorous constants are tied to the PS formula.
5. **No wrong answer on supported ordinary inputs.** One deliberate limitation: plain `_column_dot` underflows `rᵀX_k` to 0 when X, y, α, λ, a and the exact minimizer are all normal numbers. CD then returns `converged = true` at `x = 0` (reproducer in section 3).
6. **E (maintainer decision):** refusing out-of-band lasso steps saves about 17 executable lines and narrows a range #294 deliberately widened. It also collides with PR #350. Decide it jointly with sqrt-lasso's `_sqrt_offrange_step` (Agent A).

**PR #350** (draft, head `65f7004`, diff in `pr350.diff`) touches:
* `_exceptional_step`: adds one method, `NormL1{<:Real, Vector{T}}`, forwarding to the unweighted method at `T(λ0) w[k]`.
* A comment of `_coordinate_minimizer`, the `CDSolver` docstring and `src/solve.jl`.
* In `src/utils.jl`: `_converted_penalty` and `_l1_level`.

It does not touch `_threshold`, `_column_dot`, `_sqnorm!`, `_flat_*`, `response_scale`, `_curvature_scale`, `_se_scale` or any group code. C2–C5 do not collide at source level; E (or any edit of `_exceptional_step`) would.

## 1. Ledger

Path: H = hot (per visit), S = setup, C = cold exceptional. "Net" is executable lines before/after. All candidates are PS-internal, so PB+PS total decreases rather than moves. Every candidate that changes a rounding path changes bits of stopping scales or curvature; this is stated per row. Line ranges are at `dac9f4b`. Call sites are production callers only.

| Helper | Call sites | Purpose (math, guarantee) | Path | PB equivalent | Class | Action | Net savings | Correctness | Performance | Dependencies |
|---|---|---|---|---|---|---|---|---|---|---|
| `LSModel`, `_scale_type`, `cdmodel` `leastsquares.jl:8-14, 15-18, 21-24` (7+4+4) | `solver.jl:506`; `sqrtlasso.jl:28-32` (s=1); block `cdmodel` `:260-267` | Borrows X, y, α via `leastsquares_data` (PB public); owns residual `r` and curvature cache `a` in T; S = promote(T, typeof(α)) where concrete | S | `leastsquares_data` used | A | keep | 0 | n/a | n/a | #307, #295 |
| `_initialize!` `:27-37` (11); block `initialize!` `:269-281` (13) | `solver.jl:507`; momentum refresh `solver.jl:445` | `r = y − Σ X_j x_j` by one `_residual_axpy!` per nonzero entry; `fill!(a, NaN)` at every call | S | none (PB has no residual-forming API; dense `mul!` does not apply to `SparseIterate`) | B | keep | 0 | n/a | `fill!(a,NaN)` also fires at each momentum refresh: 6.3 % (F32 lasso) / 5.4 % (F64) of dot calls were cold recomputations. This is #278 V4 / #290 (deferred) | #278 item 5, #290 |
| `_column_dot` both methods `:38-53` (15+1) | LS step `:97`; group step `:595` (passes `one(T)` to skip the Σx² branch, takes `[2]`) | `b = rᵀX_k`, plus `a = ‖X_k‖²` when the cache is NaN; plain `@simd` accumulation in T; no range recovery, no bound | H (warm, b only); cold once per column per `_initialize!` | none public | B | keep | 0 | plain value; underflow limitation in section 3 | Caller-shaped in-process pass: F64 n=1000 p=50 warm 2.94 µs vs cold 4.50 µs; F32 on 1.13 1.45 vs 2.46 µs. The `a` cache avoids a 1.2–1.7x slower pass (`cand_dot.out.*`) | #278 item 4 (do not change) |
| `_residual_axpy!` `:54-60` (7) | LS step `:106`; initialize `:33`, `:276`; group step `:632`; sqrt step `sqrtlasso.jl:163` | `r −= h X_k`, one `@simd` pass | H (when h ≠ 0) | none (BLAS `axpy!` needs a column view per call) | A | keep | 0 | n/a | already shared by LS, group, sqrt | #278 item 4 |
| `_sqnorm!` `:61-71` (11) | `coordinate_scale(LSModel)` `:186`; `_singleton_curvature` `:362` | in-order (non-`@simd`) Σx² in T with cache write | C: the cold branch is **unreachable via `coordinate_scale` in production**; S for singleton groups | `sum(abs2, view)` (Base) | B, simplifiable | **migrate (C4):** `_singleton_curvature` uses `sum(abs2, view(X,:,j))`; `coordinate_scale(LSModel)` reads `m.a[k]` | −11 `_sqnorm!`, +1; −1 concept (second Σx² algorithm and #278 V3's non-`@simd` caveat). PS −10, PB 0 | Margin `nextfloat(a(1+2n eps)) ≥ exact Σx²` held on 2494 F32 + 2332 F64 BigFloat(600) columns for in-order, `@simd` and pairwise sums (`cand_sqnorm.out`). The proof comment must be restated for arbitrary summation order | Real `_prepare!` with `_sqnorm!` redefined in-process, A/B/A: F32 n=p=1000 singletons 0.39 → 0.066 ms; F64 0.40 → 0.13 ms; n=10⁴ p=200 0.78 → 0.13 ms (F32), 0.83 → 0.28 ms (F64). `_prepare!` is 3–32 % of a whole singleton-group solve today. Allocation unchanged. ℓ differs in the last bits in 75–99 % of singleton groups (max rel 3.4e-6 F32 n=10⁴; the in-order sum is the less accurate one), so group trajectories change at the ulp level (`cand_sqnorm_prepare.out`, `cand_prepare.out`) | #278 V3 (deferred to #275, merged without a decision). Six test hooks `PS._sqnorm!` at `cd_numerics.jl:1077,1133,1293,1326,1372,1590` and the cold-cache `coordinate_scale` tests (`:355,:385`) need rewriting |
| `_flat_column` `:72-77` (6) | LS step `:98`; sqrt step `sqrtlasso.jl:154`; `_flat_group` `:347` | all entries `== 0` (−0.0 counts, NaN does not) | C (a == 0); S in `_flat_group` | `all(iszero, view)` (Base) | B (trivial) | **reuse Base (C5)** | −5 | identical on {0.0, −0.0, subnormal, NaN} columns; 0 allocation | none | none |
| LS `coordinate_step!` `:96-108` (13) | `_visit!` `models.jl:34` via `_sweep!` | c = old + b/a; soft threshold at λ/(s a) (+ ridge weight for ElasticNet); flat column → penalty minimizer; refuses non-finite or non-flat zero curvature before any write | H | `prox_block`, `shrink` (exported) used | A | keep | 0 | in-band path bit-identical to the former `prox_block` step (test `cd_numerics.jl:1317`) | n/a | #294, #311 |
| `_coordinate_minimizer` `models.jl:28-32` (5) | LS `:101`; sqrt `sqrtlasso.jl:158` | `T(prox_block(g, 0, i, floatmax(T)))` = 0 for the supported penalties | C | `prox_block` used | A | keep | 0 | n/a | cold | #350 edits its comment only |
| `_scaled_prox` `:109-114` (6) | step `:101` | p = s a, γ = 1/p in S; `prox_block(g,c,k,γ)` if `floatmin(S) ≤ p` and `floatmin(S) ≤ γ`, else `_outside_band` | H (two compares) | PB's own range test inside `_threshold_product` cannot replace it: γ is already 0/Inf/subnormal before PB sees it | B | keep | 0 | band of p = [2^-126, 2^126] (F32), [2^-1022, 2^1022] (F64) | two compares, negligible against the O(n) loops | #294 |
| `_outside_band` `:116-119` (4), `_refuse_curvature` `:121-122` (2) | `_scaled_prox` `:113`; `_refuse_curvature` also `sqrtlasso.jl:156` | refuses a non-finite curvature, else forwards | C | none | B | keep (refusal shared with sqrt) | 0 | n/a | `@noinline` | none |
| `_exceptional_step` ×3 `:133-135, 139-140, 143-144` (3+2+2); `_refuse_ridge_step` `:141-142` (2) | `_outside_band` `:118` | `shrink(c, min(τ, floatmax))`, τ = λ/(s a) formed without p or 1/p; ElasticNet λ2 = 0 forwards; λ2 > 0 is **already a refusal**; generic fallback throws | C. Production-reachable: method 1 (S == T) and the ridge refusal. **Unreachable from `solve!`: the generic fallback.** An S ≠ T model never leaves the band for finite a, because α is validated representable in T and p ∈ [1e-90, 1e77]; the `wide` scans never fire `outside_band`; `_check_penalty` (`solve.jl:55`) admits only unweighted NormL1/ElasticNet. It stays reachable by direct model construction (test `cd_numerics.jl:1348`) | none (PB has only `shrink`) | B (E candidate) | keep; E would refuse instead (not recommended here) | E saves ~17 lines (`_outside_band` 4, methods 9, `_threshold` 7, minus a 3-line refusal), −1 concept | E loses p ∉ [2^-126, 2^126] (F32) / [2^-1022, 2^1022] (F64), e.g. unscaled F32 columns with ‖X_k‖ < 1.1e-19 or in (9.2e18, 1.8e19) | cold; zero hits on ordinary data | #294 (906 false convergences found there are what the band prevents); #350 adds a weighted method |
| `_threshold` `:152-158` (1+6) | `_exceptional_step` `:134` | τ = λ/(α a): F32 exact product in F64, quotient rounded twice; F64 significand/exponent split with `ldexp`. Plain value, ≤ 1 ulp | C | none | B | keep | 0 | BigFloat(600): max rel error 0.50 eps (F32), 0.89 eps (F64) over 20000 random (λ,α,a). 1.10 vs 1.13 differ only at the underflow edge (5/20000 results below 2^-1074: 0 vs 5e-324, inside the documented `nextfloat(0.0)` allowance) | cold | none |
| `_curvature_scale` `:189-196` (8); `coordinate_scale` `:186`, `:288` | `_visit!` `models.jl:35` when `scaled && h ≠ 0`; group via ℓ[k] | √(s a) rounded to T: `sqrt(T(p))` if normal; else `T(√s √a)` (p subnormal/zero, or overflowing with finite a); else `T(sqrt(p))` (wide S, Inf a). Overflow-safe value, ≤ ~1.5 ulp | H-ish (after each nonzero update); branches C | none | B | keep (caching `sqrt(s)` adds model state; #295 rejected per-column reciprocal caches) | 0 | n/a | one mul, convert, two compares, sqrt | #293, #295 |
| `response_scale` `:197-213` (17) | `solver.jl:302` (`_tolerances`, once per solve); forwarded by block and sqrt models | √(s Σy²) in 3 tiers: clean one-pass sum (≥ 4n floatmin) with normal `T(p)`; wide S via `T(sqrt(p))`; else exceptional | S | `value_from_residual(LS, y)` is αΣy²/2 and loses the range, so it cannot serve. **PB public `value_from_residual(Scaled(SqrtLeastSquaresLoss(y,X), √s), y)` returns √s‖y‖ with range recovery (C7)** | B, simplifiable | **C3a** drop tier 2; **C3b** single `_se` path; **C7** PB sqrt oracle | C3a −6 (ordinary bits unchanged); C3b −21 (30 → 9 with the next two rows); C7 −23 (30 → 7); −2 concepts (clean-sum rule restated; wide-S tier) | BigFloat(600), 4000–6000 random (n, ey, l) per type: refusal set identical to the reference for all variants. Max error (ulps of T): current 5.8–7.5; C3b 5.8–8.7 (0.49 with a Float64 sum); C7 1.3–2.3 (`cand_rs.out`, `cand_rs_pb.out`). C3b and C7 change the stopping scale in the last bits in ~35 % of cases | Per solve: current 9 ns (n=20); C3b +8 ns; C7 +20–120 ns and a 4–8 KB temporary at n=1000 (`SqrtLeastSquaresLoss` allocates `tmp`). Against 2–4 µs solves: +0.3 % (C3b) to +3–6 % (C7, F64 on 1.13, n=20). C3b `@allocated` = production | Tests `cd_numerics.jl:314,401,757,804,926` assert tier identity (`ways == Set([1,2,3])`, bit equality of tiers 1 and 2) |
| `_response_scale_exceptional` `:220-226` (7) | `response_scale` `:212` | √s‖y‖ as `_SE` (significand + Int exponent), Float64 for F32 data; refuses non-finite y. Value, not a bound | C (setup) | `_se_norm`, `_root_scale`, `_se_mul` already shared with APG | A | keep, or fold per C3 | see `response_scale` | n/a | 1.2 µs at n=1000 | APG needs `_SE` anyway |
| `_se_scale` `:227-232` (6); `_refuse_response_scale` `:234-237` (4) | `:225`; `:224`, `:230` | `T(ldexp(r.s, r.e))`, refuses a non-normal result | C | n/a | B | keep (inlining `_se_scale` saves 2 lines, optional) | 0 | n/a | n/a | none |
| `loss_value` `:239`, `:283` (1+1) | `solver.jl:512` | `value_from_residual(f, r)` = αΣr²/2 with range recovery | S | **is** the PB oracle | A | keep | 0 | n/a | n/a | #307, #277 (settled) |
| `BlockLSModel`, block `cdmodel`, block `initialize!` `:251-281` (9+8+13) | `solver.jl:506-507` | holds ℓ, scratch `old`,`u`,`b`, Float64 Gram buffers | S | n/a | B | keep | 0 | n/a | buffers allocated on first Gram use | #275 |
| `_prepare!` (block) `:304-322` (19) | `solver.jl:508` (only if `maxpasses > 0`) | per-group routing: flat → ℓ=0; singleton (n eps ≤ 1/8) → `_singleton_curvature` + band check; Gram route deferred when `_curvature_deferrable`, else computed and checked now | S | n/a | B | keep | 0 | refusals before first pass and before RNG use | share of a singleton solve 3–32 % today (C4 reduces it) | #326 |
| `_group_curvature!` `:327-337` (11) | `_prepare!` `:318`; step `:612` | curvature + band check with owned buffers | S / lazy | n/a | B | keep | 0 | n/a | eigensolve allocation once per group and solve | n/a |
| `_check_step_band` `:340-344` (5) | `:313`, `:335` | refuses s ℓ or its reciprocal below `floatmin(S)`; repeats `_scaled_prox`'s predicate | S | n/a | B | keep (a shared predicate saves ~1 line) | 0 | n/a | n/a | none |
| `_flat_group` `:345-350` (6) | `:309` | all columns flat | S | `all(...)` | B | **reuse Base (C5)** | −4 | identical | n/a | none |
| `_singleton_curvature` `:361-369` (9) | `_prepare!` `:312` | ℓ = `nextfloat(a(1+2n eps))`, rigorous majorizer of one column under gradual underflow; refuses a < floatmin or non-finite | S | n/a | B | keep (only the sum source changes under C4) | 0 | n/a | n/a | none |
| `_gram_curvature` `:402-432` (31) | `_group_curvature!` `:334` | upper bound on λmax(X_GᵀX_G): Float64 Gram, `eigvals`, margin 4(n+mk²) eps t̂ (rigorous up to the eigensolver model) | S / lazy | PB `lipschitz(LeastSquaresLoss(y, X_G))` = opnorm²; `opnorm2` = Lanczos. **Neither is a rounded-up bound** | B | keep | 0 | `lipschitz` violated ℓI − G ⪰ 0 (BigFloat Cholesky) in 230/400 F32 and 223/400 F64 groups; `_gram_curvature` in 0/800 (`cand_gram.out`). PB documents `opnorm2` as "not a certified upper bound" | timing not measured (first-call compile contaminated my probe) | #275, #339 |
| `_curvature_deferrable` `:481-507` (27) | `_prepare!` `:315` | O(n·mk) Float64 test that no refusal can occur, so the Gram can be lazy | S | n/a | B | keep | 0 | n/a | always true on ordinary data (65 160 groups deferred, eager Gram computed 0 times); 22 815 lazy Gram computations; 95 % of screen attempts return a zero certificate | #326 option B ruling |
| `_refuse_group_curvature`, `_refuse_group_step`, `_refuse_block_value` `:509-516` (4+2+2) | `:363-430`, `:342`, `:617,:625` | out-of-line throws | C | n/a | B | keep | 0 | n/a | keeps strings off the hot path | none |
| `_screen_floor` `:520` (1) | group step `:601` | 2^53 floatmin(T) guard making an all-zero `prox_block!` a zero certificate | H (cold-block visit) | rests on how PB writes `prox_block!` | B | keep | 0 | derivation in the step comment | n/a | PB `prox_block!` output rule |
| group `coordinate_step!` `:576-635` (60) | `_visit!` | b = X_Gᵀr, screen for zero blocks, trial `old + b/ℓ`, `prox_block!` at 1/(sℓ), one `copyto!`, residual update per nonzero entry, returns `norm(old)` | H | `prox_block!`, `norm` (LinearAlgebra, range-scaling) | A/B | keep | 0 | refuses non-finite trial/displacement before any write | allocation-free once ℓ is cached (test `group_cd.jl:899`) | #326 |
| `_restartdot` `solver.jl:484-490` (7) | `_momentum_update!` `:461` | sign of (x−y)·(xcur−xprev) over active values, plain sum; only `d < 0` used | H per active pass | `dot` would need two temporaries | B | keep | 0 | NaN/overflow gives no restart (harmless) | n/a | #278 item 3 |
| `_momentum_step!` extrapolation `solver.jl:435-455` (20) | `_cd_momentum!` | `c = ccur + β(ccur − cprev)` over the residual cache | H per active pass | n/a | B | keep | 0 | n/a | n/a | momentum off for `BlockIterate` |
| `_tolerances` `solver.jl:301-306` (6); `_visit!` `models.jl:33-38` (6); `_sweep!` `solver.jl:276-292` (17) | `_cd_plain!`/`_cd_momentum!` | tol × response_scale; change × coordinate_scale; finite-change refusal | S / H | n/a | B | keep | 0 | n/a | n/a | #288 |

### 1.1 Which kernels are "the same"?

| Pair | Verdict |
|---|---|
| `_column_dot` vs sqrt `_column_dot_rsqr` | **Same formula, same guarantee (plain `@simd` T sum, no recovery); different fused outputs.** Not a common robust dot: neither is robust. Sqrt post-checks ρ² and a with `_clean_sum` and routes to `_sqrt_offrange_step`. DCE merge rejected (section 2). |
| `_sqnorm!` vs `_column_dot`'s cold a | **Same formula, different summation order, same guarantee.** Both within γ_n; the BigFloat check shows the margin holds for either. |
| `_sqnorm!` vs `_se_norm`/`_sumsq_scaled` | Only superficially similar: plain unscaled sum, refused outside [floatmin, floatmax], vs two-pass scaled `m√Σ(v/m)²` returned as `_SE`. Value only, not a bound. |
| sqrt `_scaled_norm` vs `_se_norm(Float64,·)` | **Same algorithm family and guarantee class** (max, then Σ(scaled)², then √; robust value, no bound). Different scale factor (exact power of two by `ldexp`, sequential sum, result `(s,e)`) vs (division by the max, `@simd`, result `_SE`). BigFloat(600): `_se_norm` is at least as accurate (n=10⁵: F32 1.6 vs 168 eps(F64), F64 0.04–0.29 vs 31–38; all other cases ≤ 5 eps for both) and 1.2–3.2x faster (`cand_norm.out`). Drop-in for both callers (`sqrtlasso.jl:57`, `:274`): `(ds,ed) = (r.s, r.e)`; `nothing` cannot occur there. |
| `_se_norm_onepass`, `_sumsq_scaled_diff` | APG-owned (Agent C). `response_scale` restates `_se_norm_onepass`'s rule inline (finite and ≥ 4n floatmin(T)). |
| PB `norm_diff(A,B,2)` (exported) | Robust value; one-pass sum if finite and ≥ floatmin, else the squared-residual kernel. Needs two arrays and rounds once to T, so it cannot return a scale beyond T's range. Cannot replace `‖y‖` (would need a zero vector) or `response_scale` (range). |
| PB private `_residual_squares`/`_scaled_norm(x,y,s)` | Same family (power-of-two scaling by the exponent of the max, **compensated** sum, result `(s,k)`): stronger accuracy, private. APG's rigorous constants were derived for the PS formula. Promoting it is a PB feature (public function + docs + tests); PS could then drop `_se_norm`/`_sumsq_scaled`/`_scaled_norm` (27 lines) only after re-deriving the APG constants. Not recommended in Stage 0. |
| One-pass "clean sum" thresholds | Four rules, four error budgets: PB `_squares_normal` and sqrt `_clean_sum` `s ≥ n floatmin/eps`; APG and `response_scale` `s ≥ 4n floatmin`; PB `norm_diff` `s ≥ floatmin`; PB `_ls_ordinary_sum` `s ≥ 2^63 floatmin/eps`. Same idea, not a duplicate. |
| `_threshold` (F64 frexp/`ldexp`) vs sqrt `_sqrt_threshold64` | Same technique (split significands and exponents, one `ldexp`), different formulas. A shared helper saves no lines. |
| `_curvature_scale` vs `_root_scale`/`_se_scale` | Different tools for the same need: per-visit scalar vs once-per-solve exponent algebra. The per-visit version needs its fast path. |

### 1.2 Exact activation ranges (real private functions; `boundaries.out`; power-of-two scans `scan_*.tsv`)

For a = ‖X_k‖² finite, loss scale α (S = T unless stated), p = α a:
* **Band exit / `_exceptional_step` (also `_curvature_scale` two-roots):**
  * F32: p < 2^-126 = 1.18e-38 (down to a = 2^-149; a < 1.4e-45 is a zero curvature and refused) or p > 2^126 = 8.5e37.
  * F64: p < 2^-1022 or p > 2^1022.
  * At α = 1, F32: ‖X_k‖ ∈ [3.7e-23, 1.1e-19), or a ∈ (2^126, 2^128). a ≥ 2^128 is Inf and refused.
  * At α = 1, F64: ‖X_k‖ ∈ [2^-537, 2^-511), or a ∈ (2^1022, 2^1024).
  * The probe transitions at a = 2^-148 → 2^-126 and 2^126..2^128 confirm these edges.
  * With S = Float64 on F32 data the band never exits.
* **`_curvature_scale` `sqrt(p)` branch:** S wider than T and `T(p)` outside [floatmin(T), floatmax(T)], or an infinite a. It fires in the `wide` scans (338 lasso cases, 284 group cases).
* **`response_scale` tier 2:** S wider than T, clean sum, `T(αΣy²)` not normal while αΣy² is normal in S and the root is normal in T (150 of 2959 `wide` lasso cases).
* **`response_scale` tier 3:** s not finite or < 4n floatmin(T), or tier 1/2 out of range. For F32/F32 with y = 2^ey on 4 entries, tier 1 iff αΣy² ∈ [2^-126, 2^128) (l ∈ [−128, 125] at ey = 0). The result is refused when √(αΣy²) is not a normal number of T.
* **Group:**
  * Eager curvature iff one of: `lo < 2 mk floatmin(F64)`, `lo < 2 floatmin(T)`, `hi > floatmax(T)/2`, `s·lo < 2 floatmin(S)`, `s·hi > 1/(2 floatmin(S))`, or `4(n+mk²) eps(F64) > 1/16` (n ≳ 2^46, unreachable).
  * Refusals: curvature (ℓ < floatmin(T), or ℓ/Gram non-finite) and step band.
  * A singleton takes the Gram route only if n eps(T) > 1/8 (F32 n > 2^20).
  * Screen bypass: 1/s not normal in S, or 0 < bmax < 2^53 floatmin(T) (2^-73 F32, 2^-969 F64).
  * The group path **refuses** a subnormal curvature that the scalar lasso accepts.
* **Scans:** exact rescalings of one 40×12 problem with X, y, α, λ, λ2 kept normal. Exceptional branches fire only in the windows above, and refusals are `ArgumentError` with the expected messages. The only wrong answers are the underflow class of section 3.

### 1.3 Test coverage

Union line coverage of `cd_numerics.jl`, `group_cd.jl`, `group_cd_preflight.jl`, `sparse_cd.jl`, `cd_elasticnet.jl` on Julia 1.10 (`cov/*.info`, `cov_leastsquares_zero.txt`): 301 instrumented lines of `leastsquares.jl`, 18 with zero hits. All 18 are return-value or `end` lines (inlining attribution), so no executable branch is untested. Line coverage does not prove branch coverage inside one-line expressions such as the `&` band predicates.

Test map:
* band/exceptional/threshold: `cd_numerics.jl:1027-1520`
* in-band bit identity: `:1317`
* unsupported penalty / S ≠ T fallback: `:1348`
* ridge refusal: `cd_elasticnet.jl:493`
* coordinate scale: `:341,:1161`
* response scale: `:314,:401,:757,:804,:926,:967,:988`
* group refusals and band: `group_cd.jl:917-1000`
* lazy/screen: `:1075-1378`
* flat group: `:1007`
* flat column: `cd_elasticnet.jl:249,:453`, `sparse_cd.jl:282`

## 2. LS-CD ↔ sqrt-lasso-CD arithmetic overlap

**Already shared today:**
* `LSModel` itself (sqrt wraps one with s = 1: `r`, `a`).
* `_residual_axpy!` (`sqrtlasso.jl:163`), `_flat_column` (`:154`), `_coordinate_minimizer` (`:158`), `_refuse_curvature` (`:156`).
* `coordinate_scale` and `response_scale`, forwarded at `:37-38`. Every exceptional branch of both stopping scales is therefore LS code.
* The `_cache` momentum hook, and `loss_value` via PB `value_from_residual` (`:41`).

The distinct sqrt mathematics (`_sqrt_minimizer`, `_sqrt_band_step`, `_distance_sqr`, `_certify!`, `_level_brackets`, `_round_up`) uses none of the LS arithmetic beyond the above.

**Not shared, and not shareable without cost:**
* **Dot kernel.** `_column_dot_rsqr` = `_column_dot` plus a third accumulator ρ². I tested the DCE merge `_column_dot(X,r,k,a) = (t = _column_dot_rsqr(X,r,k,a); (t[1], t[2]))` (`cand_dot.jl`: exact copies of both kernels, caller-shaped pass over all columns, old/new/control interleaved in one process).
  * Warm cache (hot case): bit-identical and equal speed (new/old 0.98–1.01, control/old 0.99–1.02).
  * Cold cache (a computed, once per column per `_initialize!`): not bit-identical in 3 of 8 type/size cases on 1.10 and 8 of 8 on 1.13.
  * On 1.10 the F32 cold pass is 1.58x (n=1000) and 1.96x (n=10⁴) slower, because the 3-accumulator loop is vectorized and unrolled differently. On 1.13 it is 7–20 % faster for n ≥ 100 and 10–15 % slower at n=20.
  * The saving would be ~14 lines. **Class B, keep both.**
* **Norm.** sqrt's `_scaled_norm` is the same family as `_se_norm`, so C2 removes it. It has two callers: `_prepare!` (once) and `_sqrt_offrange_step` (cold).
* **Exceptional scaling.** Four separate range-safe scalings: `_threshold`; `_sqrt_threshold64` + `_sqrt_offrange_step`; `_curvature_scale`; `_response_scale_exceptional`. The techniques differ (exact quotient by exponent split, power-of-two-scaled Float64 recomputation, roots first, `_SE` algebra), and none can serve another's job without extra work in a per-visit path. Sqrt's offrange step (39+8+4 executable lines) is the larger instance of the E question and belongs to Agent A and the maintainer.
* **One-pass sum rules.** `_clean_sum` (n floatmin/eps) vs `response_scale`/`_se_norm_onepass` (4n floatmin): different guarantees.

Conclusion: sqrt can reuse LS arithmetic only for what it reuses now. The one real overlap with a deletion is C2.

## 3. Wrong answers

**None on supported ordinary inputs.** 6080 ordinary solves converged or ended with the documented `maxpasses` warning (200 runs, at p = 1000 and low λ or Float32 tolerances). I did not compute independent KKT residuals for all of them; the repository tests do.

**Deliberate limitation (not ordinary, no refusal).** `rᵀX_k` underflows inside plain `_column_dot` while X, y, α, λ, a and the exact minimizer are all normal numbers. The power-of-two scans found 57 (F64) and 4–5 (F32) wrong `converged = true` cases per configuration, all with exponent sum `j + i ≤ emin + 8`, and no other wrong case. Reproducer (`repro_underflow.jl`, identical on 1.10 and 1.13):

```julia
using ProximalSolvers, ProximalBase
X = fill(2.0^-500, 2, 1); y = fill(2.0^-700, 2); α = 2.0^300
λ = 2.0^-902        # = α b / 8, b = 2*2^-1200 in exact arithmetic
# a = 2^-999 (normal), α a = 2^-699 (normal), exact minimizer x* = (7/8) b/a = 5.4e-61 (BigFloat 600)
x = zeros(1)
r = solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), CDSolver(order=:cyclic, momentum=false))
# x == [0.0], r.converged == true, r.passes == 1, because sum(y .* X) == 0.0 (exact value 2^-1199 < 2^-1074)
```

* The Float32 analogue (X = 2^-70, y = 2^-90, α = 2^90, λ = 2^-52·...; the script computes λ) returns x = 0 for x* = 8.3e-7.
* Controls with products at 2^-800 (F64) and 2^-110 (F32) are correct.
* The documented position covers it (`docs/src/numerics.md`: "ProximalSolvers does not promise end-to-end recovery of every failed matrix product, curvature, step or objective").
* The exceptional-step machinery is useful only where this product is representable (large y, tiny X).
* **Classification: deliberate limitation.** An optional improvement would be a documented refusal, not a recovery.

**Optional accuracy items (not defects):**
* `_column_dot` @simd error is 58–82 eps(F32) at n=2·10⁴.
* `_sqnorm!` in-order sum error is 64–92 eps against 2.7 eps for pairwise (C4 improves it).
* `response_scale` error is 5.8–7.5 ulp (0.49 with a Float64 sum, 1.3–2.3 with C7).
* F64 `_threshold` below 2^-1074 differs by one subnormal between 1.10 and 1.13 (inside the allowance).

## 4. Do-not-change list (with evidence)

1. **`_column_dot`, `_residual_axpy!`, the `a`/`r`/ℓ caches.**
   * #278 item 4 forbids touching the first two.
   * Cold pass is 1.2–1.7x slower than warm (`cand_dot.out.*`).
   * The residual is O(n) per update against O(n·nnz) to rebuild.
   * ℓ would cost a Gram plus eigensolve per visit.
   * The `fill!(a,NaN)` re-invalidation at momentum refresh (6 % of dot calls) is #278 V4 / #290, deferred.
2. **`_sweep!` (#288), separate `_cd_plain!`/`_cd_momentum!` (#278 V2 NO-GO), the `CDModel`/`_cache`/`_cache_moved!`/`_momentum_default` hooks, the `cdmodel` fallback, `_CDState` RNG identity, `_shuffle!` draw order, the `dropzeros!` boundary.**
   * Present in current code at `solver.jl:276-292, 316-412, 358-366` and `models.jl:23`.
   * Nothing here needs them changed.
3. **`_scaled_prox` band and the in-band PB `prox_block` call.** Bit-identical to the pre-#294 step (test `cd_numerics.jl:1317`). PB's range test cannot replace it, because γ is 0/Inf before PB sees it.
4. **`_gram_curvature`, `_check_step_band`, the `_singleton_curvature` margin.** PB `lipschitz` violates the majorization in 57 % of groups; `opnorm2` is documented uncertified.
5. **`_curvature_deferrable`, lazy curvature, `_screen_floor`, the screen.** #326 option B ruling. 95 % of screen attempts return a zero certificate; every Gram in my matrix was computed lazily (22 815) and none eagerly.
6. **Roots-first `_curvature_scale`; no per-column reciprocal cache; no conditional `Float32(α)` rounding.** #295 maintainer ruling.
7. **`loss_value` via `value_from_residual`.** Already the PB oracle (#307/#277).
8. **`_restartdot`.** Fused, allocation-free, sign only.
9. **PS imports only exported or documented PB API.** Importing `_scaled_norm`, `_squares_normal` or `_threshold_product` would add coupling for no deletion.
10. **The out-of-line `_refuse_*` helpers.** They keep string interpolation off the hot path, and the messages are tested.
11. **`_threshold`.** 0.5/0.89 eps against BigFloat; unifying the F32 and F64 methods saves one line.

## 5. Verified vs inferred; open doubts

**Verified by execution** (all in `RUN/agentB/`):
* Branch frequencies on 6080 ordinary solves: an instrumented copy of `leastsquares.jl` redefined into the live module (counters only), via `mkinstr.py`, `instr_load.jl`, `branchfreq.jl`.
* Activation boundaries (`boundaries.jl`) and power-of-two scans (`scan_pow2.jl`, `analyze_scan.py`).
* BigFloat(600) checks:
  * `_scaled_norm` vs `_se_norm` (`cand_norm.jl`)
  * response-scale variants (`cand_rs.jl`, `cand_rs_pb.jl`)
  * singleton-curvature margin under three summation orders (`cand_sqnorm.jl`)
  * PB `lipschitz` vs `_gram_curvature` (`cand_gram.jl`)
  * `_threshold` (`vercheck.jl`)
* In-process A/B/A of the real `_prepare!` with `_sqnorm!` redefined (`cand_sqnorm_prepare.jl`).
* Caller-shaped old/new/control pass for the dot-kernel merge (`cand_dot.jl`).
* Line coverage of the five CD test files (`cov/`).
* Julia 1.10.13 and 1.13.4 for every probe.
* Allocations (`allocs.out`). The 16 B on 1.10 is the harness baseline and identical for the production functions.

**Inferred from reading only:**
* Reachability claims (the `_sqnorm!` cold branch, the generic `_exceptional_step` fallback, S ≠ T never leaving the band). Call-site reading was confirmed by counters (`sqnorm_cold` = 0 in 4000 lasso/enet solves; `outside_band` never fired in the `wide` scans), but not proved for all types.
* That arbitrary-order summation preserves the singleton margin. This rests on the standard γ_{n−1} bound plus BigFloat samples, not a rewritten proof.
* Test-churn estimates for C3/C4. No test was edited or run against a candidate.

**Open doubts:**
* **No controlled timing.** Everything labelled "measured" is an in-process setup-path or caller-shaped probe. No candidate changes a coordinate-loop body, so I make no coordinate-loop timing claim. Julia 1.10 here compiles for `goldmont`; the A/A–A/B runs should use the matched cluster pair, especially for C4 (singleton-group setup) and C3b/C7 (tiny solves).
* C3b, C7 and C4 change stopping-scale or curvature bits in the last ulps, which matters for frozen benchmark campaigns (#330). C3a changes no ordinary bit.
* C7 depends on PB's documented `value_from_residual` of `SqrtLeastSquaresLoss` (marked `public` only on 1.11+) and allocates the loss's `tmp`. C3b has no PB dependency and no allocation. I rank C3b over C7 on the "ordinary performance preserved" criterion, and C3a as the zero-risk step.
* Direct-LSModel tests with a `BigFloat` scale (`check_scale_point`) exercise tiers 2/3 with S = BigFloat; under C7 those fixtures must go (`solve!` refuses S = BigFloat anyway).
* PB master was not re-run.
* Statuses of #290 and #339 were not re-read.

## 6. Ranked candidates (all PS-internal; none authorized)

| # | Candidate | Net PS exec lines | Concepts | Risk | Evidence |
|---|---|---|---|---|---|
| 1 | C4 delete `_sqnorm!`; `_singleton_curvature` uses a pairwise/SIMD sum; `coordinate_scale(LSModel)` reads the cache | −10 | −1 | low: ℓ and group trajectories move at the ulp level; margin proof restated; 6+2 test hooks rewritten | `cand_sqnorm*.out`, `cand_prepare.out` |
| 2 | C3a drop tier 2 of `response_scale` (ordinary bits unchanged) | −6 | −1 | very low | `cand_rs.out` |
| 2′ | C3b single `_se` path (or C7 PB sqrt oracle) | −21 (C7 −23) | −2 | low/medium: stopping-scale bits; C7 allocates | `cand_rs.out`, `cand_rs_pb.out` |
| 3 | C2 sqrt `_scaled_norm` → `_se_norm(Float64,·)` (Agent A's file) | −14 | −1 | very low (cold/setup, more accurate, faster) | `cand_norm.out` |
| 4 | C5 `_flat_column`/`_flat_group` → `all(iszero, view)` | −9 | 0 | none | `cand_sqnorm.out` |
| 5 | F: dedupe proof text (~100 comment lines of `_curvature_deferrable`, `_gram_curvature` and the group-step comment duplicate `docs/src/numerics.md:415-600`) | 0 exec, −100 comment | 0 | none | reading |
| – | E refuse out-of-band lasso steps | −17 (+ tests) | −1 | narrows a supported domain; collides with #350; decide with sqrt offrange | `boundaries.out` |
| ✗ | merge `_column_dot` into `_column_dot_rsqr` | −14 | −1 | changes bits; 1.10 F32 cold pass up to 1.96x slower | `cand_dot.out.*` |
| ✗ | PB `lipschitz`/`opnorm2` for group ℓ | n/a | n/a | violates majorization 57 % | `cand_gram.out` |
| ✗ | PB private norm kernels in PS | n/a | n/a | private; different guarantee; APG constants | section 1.1 |
