# X2 / X3 report (PS #353 Stage 0)

RUN = <RUN>, EXP = RUN/experiments/x2. Julia 1.10.13 is "lts" and 1.13.4 is "rel". On this host lts reports CPU goldmont (SSE only) and rel reports raptorlake (AVX2).

**Bottom line**
- **X2 is bit-identical.** I found 0 mismatches against BASE in 4806 solves on lts and 4794 on rel (PGD, APG, CD lasso, elastic net, group lasso, sqrt lasso, Float32 and Float64, dense and SparseIterate, warm starts). That includes about 5·10^6 unit comparisons for items 1–5. Allocations are equal.
- **X2 needs 4 test edits, all in `test/cd_numerics.jl`.** They come from items 2 and 6 (S-B and C3a). No test references a deleted X2 helper.
- **X3 changes last bits.** Nothing else changes: allocations are equal, all four attributable differences below come from items 7–8, and the test edits are small.
  - Item 8 (C4) alters last bits in 94–97% of singleton group-lasso solves.
  - Item 7 (A−) alters last bits in 2 of 456 sqrt-lasso solves on rel and 0 of 454 on lts.
- **Executable lines:** X2 −35, X3 −59.
- **Not flagged by the earlier agents:** the BigFloat scale beyond the Float64 range in `check_scale_point`; the silent NaN from `coordinate_scale` with a cold cache (item 8); and, for items 2 and 6, that Float32 data with a Float64 scale does reach the removed tier through `solve!`.

Everything was run by execution. Only the doc line numbers are inferred.

## Per item

Line counts are `count_loc.py` before → after.

**1. S-A: `_maxabs_diff` → `_norm_diff(x, y, Inf)`** (blocks.jl, `_se_norm_diff`, APG `g_residual`)
- Diff: delete the function (−7) and its export. `_norm_diff(x, y, p::Real = 2)` already forwards to PB `norm_diff`. Two callers changed.
- Concepts removed: 1 loop.
- Evidence (unit_items_{lts,release}.txt): 10900 cases with 0 mismatches, covering NaN, ±Inf, ±0, subnormals, floatmax, views, matrices, n = 0..4096, and Float32/Float64. Mixed element types give the same value. In the matrix, 0 mismatches.
- Allocation: equal.
- (e) Vectorization (llvm_maxabs_{lts,release}.txt, plus the `.ll`/`.s` dumps).
  - On 1.13 the loop in PB `norm_diff` (no `@simd`) vectorizes exactly like PS's `@simd` loop. Both use `llvm.maximum`, which is associative. Both give `vector.body` with `<8 x float>` or `<4 x double>`, 9–10 packed max ops and 16 or 13 `cmpunord`.
  - On 1.10 neither vectorizes: both are scalar `fcmp`/`select` loops. PB's function has extra entry checks (`_check_one_based`, size, eltype).
  - Indicative timings, labelled indicative: ratio new/old is 1.00 on both versions (1.92 ns/elt on lts, 0.12–0.26 ns/elt on rel).
- Test edits: none. Verdict: **safe**.

**2. S-B: `_significand_exponent` removed, `_root_scale` uses `Float64(α)`** (183→176 file total; −4 for the item)
- New body: `a = Float64(α); s, e = significand(a), exponent(a)`. I also rewrote the docstring.
- **An IEEE-only method is not an option.** APG stores α as supplied (`_LSImage.α`), so Int, UInt8, Int32 and Bool scales reach `_root_scale` through `solve!`. I verified all four through APG. They would hit a MethodError. `Float64(α)` covers them exactly, because `_check_loss_scale` only admits exactly representable integers.
- Callers that can pass other types:
  - `solve!` through APG and CD: Float32, Float64, BitInteger, Bool. 39982 cases with 0 mismatches.
  - Direct `LSModel` with a BigFloat scale (`_scale_type` gives S = BigFloat). Float16 promotes to T, Rational and Irrational go to T, so those never reach it.
  - Tests only.
- After the change:
  - Any real type inside the Float64 range gives the same value as BASE. I checked 24 types and values: BigFloat 256-bit, BigInt, Rational, π, Float16, Bool, UInt128, subnormals.
  - Outside the Float64 range, the result is a loud `DomainError` from `exponent(0/Inf)` instead of the right value. This includes BigFloat 2^±1100 and 10^400, `1//big(10)^400` and BigInt 10^400.
  - A BigFloat or Rational in the Float64 subnormal range would silently lose precision. Unreachable from `solve!`.
- Test edits: `test/cd_numerics.jl:943`, `check_scale_point` over `big(1.3)·2^j` for j = ±1500. It currently expects a value or an ArgumentError. Change to j = ±1000 (within the Float64 range) or accept DomainError. This accounts for 52 `:910`, 37 `:911` and 52 `:912` failure records. `accelerated_pgd.jl:470–475` (`_root_scale` over 10 types) passes unchanged.
- Docs: `docs/src/developer/implementation-notes.md` lines 69–70 and 360–363.
- Verdict: **safe with the listed edit** (a behaviour change for unsupported direct inputs).

**3. S-D: `_frobenius_upper` first loop → `_sumsq64`** (19→16, −3)
- `_sumsq64` is defined later in proximal_gradient_descent.jl but is looked up at call time. It is the same loop; I only widened its comment.
- 8000 matrices (random scales, zero, ±0, subnormal and floatmax entries) with 0 mismatches. Allocation 0 (rel).
- Test edits: none. Verdict: **safe**.

**4. `_round_up` → `T(ratio, RoundUp)`** (−4)
- 6 000 068 cases with 0 mismatches, T ∈ {Float32, Float64}, on both Julia versions. They cover 0, −0, NaN, Inf, subnormals, 2^-149..2^-151, floatmin, floatmax(Float32) ± 1 ulp, 1e39 (→ Inf), 3M random bit patterns per type, and 400k negatives (also 0 differences).
- `Float64(v, RoundUp) === v` for 10^6 random Float64 incl. subnormals.
- Test edits: none. Verdict: **safe**.

**5. C5: `_flat_column` / `_flat_group` → `all(iszero, view(...))`** (6→1 twice, −10)
- 89 775 cases on lts and 89 776 on rel, 0 mismatches. The columns include −0.0, NaN, ±Inf and subnormal, and groups of Int and Int32 indices. −0.0 is flat, NaN and subnormal are not flat, in both.
- A sparse X cannot reach `solve!` (it requires `Matrix{T}`, solve.jl:108/138). A direct `LSModel` with a sparse X gives the same answer.
- Allocation: 0 B for `_flat_column` (flat and not flat) and for `_flat_group`. Solves with zero and −0.0 columns and a flat group allocate the same as BASE (`alloc_flat.jl`).
- Test edits: none. Verdict: **safe**.

**6. C3a: drop tier 2 of `response_scale`** (17→10, −7; I merged the `if` into one `&&` chain and updated the comment)
- Tier 2 is reachable only when the scale type S is wider than T (Float32 data, Float64 scale). Reachable from `solve!` for Float32 data with Float64 α when αΣy² is outside Float32's normal range.
- Measured (`c3a_tier2.jl`, BigFloat reference):
  - Float32 data, Float64 scale: 17 405 tier-2 inputs, 7 530 change value, by at most 24.7 ulp(Float32).
  - The new value is the better one: mean/max error 0.27/0.5 ulp, against 3.3/41.9 ulp for tier 2. Tier 2 sums in Float32; the exceptional path sums in Float64.
  - IEEE scales: 0 accepted→refused and 0 refused→accepted. Inputs on tiers 1 and 3 are identical (42 595/42 595). S = T never reaches tier 2.
  - BigFloat scale with Float64 data (direct `LSModel` only): in-range α changes by at most 1.5e-15 relative, 0 refusals. α outside the Float64 range becomes DomainError (an item-2 effect).
- Test edits (`cd_numerics.jl`): `scale_way` tier-2 branch at 885–889 (delete), the `way == 2 && @test …` at 915 (delete, 6 assertions), `@test ways == Set([1, 2, 3])` at 948 → `Set([1, 3])`. Optionally the header comment at about 862–868.
- Docs: implementation-notes.md lines 28–37 ("one of three ways").
- Verdict: **safe with the listed edits**. It changes values for Float32 data with a Float64 scale outside the normal range, always toward the exact value.

**X2 edits pass.** The scratch `EXP/test_edits/cd_numerics.x2.jl` has 0 failures on rel and lts (24382 pass, against 24395 for BASE; the −13 are the removed tier-2 assertions and the changed BigFloat j range). The other 19 test files pass unchanged.

**7. A−: `_scaled_norm` → `_se_norm(Float64, ·)`** (X3; sqrtlasso 14 lines deleted, +1 in `_sqrt_offrange_step`, net −13)
- Callers: `_prepare!` (`floor64 = 16eps(T)*ldexp(ny.s, ny.e)`) and `_sqrt_offrange_step` (`d = _se_norm(Float64, s); ds, ed = d.s, d.e`).
- **`nothing` cannot occur at either site.** `_check_problem` refuses non-finite x, X and y before any prepare. The entries of `res64` are `ldexp(finite, −e)`, below 2 in magnitude, and `qs` is finite. Only a direct private `_prepare!` call with a non-finite y would hit it, as a FieldError. No test does that.
- Measured against BigFloat (`x3_item7_scalednorm.jl`):
  - `floor64` bits differ in about 46% of cases. Max relative error is 600 eps(Float64) for BASE against 39 for X3 on Float32 data, and 312 against 42 on Float64 data.
  - BASE is the less accurate one, because its sequential sum grows with n. Worst relative difference between the two: about 230 eps(Float64) at n = 10^5.
  - Excluded from those statistics: 410 Float64 cases where `floor64` itself underflows in `ldexp` and is identical.
  - The off-range step differs in 13 of 12 000 Float64 cases (0.11%) and in 0 of 12 000 Float32 cases. Both versions have the same maximum error against the BigFloat step formula (537 eps(T) on rel, 285 on lts), which is dominated by cancellation.
- Solve level (`x3_sqrt_solves.jl`): 456 solves on rel and 454 on lts, 161/162 of which reach the recomputed norm (235 and 264 extra calls). X3 mismatches: 2 on rel, both Float64 at tiny scale, last-bit or 5e-14 relative in one coordinate; 0 on lts. X2 has 0 on both versions.
- Tests: `test/sqrt_lasso.jl` passes unchanged on lts and rel. Test edits: none.
- Verdict: **safe, not bit-identical**.

**8. C4: delete `_sqnorm!`** (−11; `coordinate_scale` reads `m.a[k]`, `_singleton_curvature` uses `sum(abs2, view(ls.X, :, j))`; comments updated)
- **The cache is always filled in production.** `_visit!` calls `coordinate_step!` first. Both the LS step (leastsquares.jl:94–97) and the sqrt step (sqrtlasso.jl:141) write `m.a[k] = a` before returning. Every throw happens before the write, and a throw aborts the visit before `coordinate_scale`. `a` can be Inf but not NaN, because X is finite. The block model uses ℓ, not the cache.
- **A direct call with a cold cache silently returns NaN.** Checked: `T(sqrt(NaN))` for a zero column, an Inf-curvature column and a normal column. Only a test hits it.
- Margin `nextfloat(a(1+2n eps)) ≥ Σx²` (`c4_margin.jl`, BigFloat 300 bits):
  - Summation orders: sequential, Base `sum(abs2, view)` and the `@simd` kernel, plus the production `X3._singleton_curvature`.
  - Adversarial columns: wide dynamic range, big plus many small, ties just below and above half an ulp, descending and ascending, subnormal and floatmin-straddling squares, constant columns, n up to 2^20 (Float32) and 2^20 (Float64).
  - Result: 768 Float32 and 612–616 Float64 checks per version, **0 violations** on both Julia versions.
  - The worst case consumes exactly 25% of the 2n·eps margin. This is the theoretical maximum for any order of n terms, so the margin is sharp to a factor of 4 and the proof is order-agnostic.
- Group-lasso solves, BASE vs X3 (`x3_group.jl`; 128 singleton cases per type, 64 multi-column controls):

| | Float32 | Float64 | multi-column control |
|---|---|---|---|
| bit-identical | 8–13 of 128 | 10–11 of 128 | 64 of 64 (F32 and F64) |
| max objective rel. difference | 7e-11 | 8e-25 | 0 |
| passes differ | 17–19 cases (lts max Δ 3; rel 17 cases) | 0 | 0 |
| converged | see below | 128/128 both | 64/64 both |
| max independent BigFloat KKT residual | 3.5e-4 (base) / 3.5e-4 (X3) | 1.4e-9 / 1.4e-9 | same |

  - X2 vs BASE on the same script: all 384 bit-identical, so the changes come from C4 alone.
  - **Float32 at tol = 1e-7, below eps(Float32)** (the "floor" cases): the pass differences occur only there. On 1.13 one case went from 5 passes to 20000, `converged=false`, with KKT 1.3e-8. Another went from 21 to 416. At the ordinary tol of 1e-5 there is at most 1 case differing by 1 pass, with `converged` identical.
  - The KKT metric is mine; the test suite's `kkt_bound` is a different, stricter metric.
- Fingerprint matrix, X3 vs BASE: 4806 (lts) / 4794 (rel) cases. **Mismatches: 309 (lts), 302 (rel)**, all in singleton group solves (about 320 such cases, 94–97%), all last-bit in the minimizer. None in lasso, enet, PGD, APG or sqrt (items 1–6 and 7 do not show up there). The only source is C4.
- Test edits needed (X3 only; `cd_numerics.jl`):
  - The six `PS._sqnorm!` refs at 1077, 1133, 1293, 1326, 1372 and 1590.
  - Cold-cache `coordinate_scale` at 355, 385, 1183 and 1185. I confirmed 1183/1185 return NaN. Before the edit they were hidden by a testset abort.
  - `core_regressions.jl:122–123`, the "cold curvature scale" testset. It needs `coordinate_step!` first.
  - `group_cd.jl` and `group_cd_preflight.jl` have no references and pass unchanged.
- Failure records before edits (both Julia versions): 24 failed plus 36 errored from items 7–8, on top of X2's 147. The errored testsets also abort about 7 300 passes.
- Scratch copies show the edits pass: `EXP/test_edits/cd_numerics.x3.jl` and `core_regressions.x3.jl`, 0 failures on lts and rel. The scratch uses a local helper `sqnorm!` that is the old function moved into the test file.
- Verdict: **safe with the listed test edits, not bit-identical**. Summation order changes ℓ in the last bit. In a tolerance-at-floor Float32 solve, one rounding-level change turned into a 20000-pass non-convergence on 1.13. That is a coin-flip at an unreachable tolerance, not a defect, but it is observable.

## S-C (not added to X2)

Patch: `EXP/sc_on_x2.patch`; tree copy `EXP/sc_tree/`.

- **No fake zero array is needed.** I did not use agent C's `_ZeroVec`. It cannot work with item 1, because PB's `norm_diff` refuses non-arrays.
- What I did:
  - `@inline _diff(a, b, i) = a[i] - b[i]` and `_diff(a, ::Nothing, i) = a[i]`.
  - One `_sumsq_scaled(a, b, m)`.
  - One `_se_norm(T, a, b = nothing)`: max from `_norm_inf(a)` or `_norm_diff(a, b, Inf)`. It drops the provably unreachable `isfinite(s)` line.
  - One `_se_norm_onepass(T, s, a, b = nothing)`.
- Net change: image_models.jl 176 → 159, **−17 executable lines on top of X2**. It also deletes `_sumsq_scaled_diff`, `_se_norm_diff` and `_se_norm_diff_onepass` (3 renames; no test or src references outside image_models.jl and the APG caller).
- New concept: the optional second operand, 2 one-line methods.
- Evidence:
  - 0 mismatches in 270 000 unit comparisons on both versions (NaN, Inf, zero, −0.0, subnormal, huge; Float32 data with a Float64 working type as CD uses it).
  - 0 mismatches in the 4806/4794-case solve matrix.
  - Allocation equal to BASE.
- Recommendation: **take S-C as a separate follow-up** — clearly net-simpler, bit-identical, no test edits. I did not fold it into X2 because the orchestrator asked for "clearly net-simpler" and it touches the APG certificate path. That path is bit-identical here, but that is your call.

## Totals

| | exec lines | test edits | docs |
|---|---|---|---|
| X2 (items 1–6) | −35: S-A −7, S-B −4, S-D −3, round_up −4, C5 −10, C3a −7 | 4 code edits in 1 file (`cd_numerics.jl` 885–889, 915, 943, 948) | implementation-notes.md ≈28–37, 69–70, 360–363 |
| X3 (adds 7–8) | −59 (A− −13, C4 −11) | X2's 4 plus 12 more sites (11 in `cd_numerics.jl`: 1 helper, 6 `_sqnorm!` refs, 4 cold calls; 1 in `core_regressions.jl:122`) | same |

- **Allocations** (`allocs_*`, 26 solve cases each, minimum over 5 warmed repetitions): 0 differences for X2, X3 and S-C on both Julia versions, covering CD (lasso, enet, group, singleton group, sqrt), PGD and APG, Float32 and Float64, scaled and tiny-scale. 1.10 shows no `_se_mul` regression. Single-call splat probes show 16–32 B on 1.10 and 0 on 1.13, identical in BASE and X2.
- **Full tier** (`scripts/test.jl --tier=full --jobs=4`; 20 files, about 1 min):
  - X2 unedited: 147 failure records (95 fail, 52 error) on both versions, all in one `cd_numerics.jl` testset (items 2 and 6).
  - X3 unedited: 119 fail, 88 error, in `cd_numerics.jl` and `core_regressions.jl` only.
- **Pkg.test:** `scripts/test.jl` makes `Pkg.test` build its own `<TMP>*` environment. I ran no other Pkg operation.

## Contradictions with the earlier reports

- **Line counts differ by 1–2 per item** (counting conventions): S-B −4 (agent C: −5), S-D −3 (−4), C3a −7 (−6), C4 −11 (−10), C5 −10 (−9).
- **Agent B on C3a ("ordinary bits unchanged")** is true for S = T only. For Float32 data with a Float64 scale outside the normal range it changes values by up to 25 ulp, toward the exact value, and `solve!` does reach it. Also not flagged: C3a plus S-B turns a BigFloat scale beyond the Float64 range (accepted by `check_scale_point`) into a DomainError.
- **Agent C's S-B** ("Float64(α); the 256-bit route is dead") is right for `solve!`. It missed that α is stored as supplied, so an IEEE-only method would break Int and Bool scales. It also missed the `cd_numerics` BigFloat ±1500 assertions.
- **Agent A on A−:** not bit-identical (bits differ in about 46% of `floor64`), but more accurate. Agent B's "drop-in" holds numerically.
- **C4 "`_prepare!` 3–6× faster"** (agent B): not measured by me.
- **Not flagged by agent B:** cold-cache `coordinate_scale` is a silent NaN, not an error.

## Open doubts

- **Fingerprints cover a finite matrix**: about 4.8k solves per tree and version plus the targeted unit sweeps. Other shapes (very large n, n ≥ 2^20 groups) are untested. The C4 proof is order-agnostic and the margin held up to Float32 n = 2^20.
- **The 1.13 20000-pass case at tol = 1e-7** is one observation, not a systematic pattern.
- **Doc line numbers** are from grep, not exact edits.
- **The test-edit scratch copies** show the edited assertions pass, not that these are the minimal edits maintainers would choose. The BigFloat range edit (±1500 → ±1000) loses coverage of beyond-Float64 BigFloat scales. The alternative is `@test_throws DomainError` for those.
- **Indicative timings** (llvm script only, labelled indicative) are noisy: shared machine, lts is goldmont.

## Files written (all under EXP = RUN/experiments/x2/)

- **Patches:** `x2.patch`, `x3.patch`, `sc_on_x2.patch`.
- **Fingerprints and loaders:** `loadtrees.jl`, `loadtrees_sc.jl`, `fp_lib.jl`, `fp_matrix.jl`, `fp_x2_{lts,release}.txt`, `fp_x3_{lts,release}.txt`, `fp_sc_{lts,release}.txt`, `fp_mismatches_x3_{1.10,1.13}.txt`.
- **Unit and item experiments:**
  - `unit_items.jl` + `unit_items_{lts,release}.txt`
  - `c3a_tier2.jl` + `c3a_{lts,release}.txt`
  - `x3_item7_scalednorm.jl` + `x3_item7_{lts,release}.txt`
  - `x3_sqrt_solves.jl` + `x3_sqrt_solves_{x2,x3}_{lts,release}.txt`
  - `x3_group.jl` + `x3_group_{lts,release}.txt`
  - `c4_margin.jl` + `c4_margin_{lts,release}.txt`
  - `sc_check.jl`
  - `sc_tree/src/` (copy of X2 src with the S-C edit)
- **Allocations and codegen:**
  - `allocs.jl` + `allocs_{x2,x3,sc}_{lts,release}.txt`
  - `alloc_flat.jl`
  - `llvm_maxabs.jl` + `llvm_maxabs_{lts,release}.txt` + `llvm_{old,new}_*.ll` + `native_{old,new}_*.s`
- **Tests and LOC:**
  - `tests_x2_{lts,release}_full.txt`, `tests_x3_{lts,release}_full.txt`
  - `test_edits/` (`cd_numerics.x2.jl`, `cd_numerics.x3.jl`, `core_regressions.x3.jl`, and the `.out` logs)
  - `loc_delta.sh`, `loc_x2.txt`, `loc_x3.txt`
  - `load_test.out`

Source edits are only under `src/` of `<WORK>/ps-353-x2` (items 1–6) and `<WORK>/ps-353-x3` (items 1–8), uncommitted. BASE is untouched.