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
- **Dropping tier 2 of `response_scale`** (−7 executable lines, three test edits; in the GO bundle of r1, moved here after the review). Tier 2 serves Float32 data with a Float64 loss scale whose `αΣy²` leaves the Float32 normal range, which `solve!` admits. In the sweep (Julia 1.10.13), 7,229 of the tier-2 inputs carry an admitted scale and 3,110 of them change, by up to 42 Float32 ulps, toward the exact value (old error up to 41.9 ulp, new at most 0.5 ulp); for those inputs the branch then makes three scans of `y` instead of one (the sum loop stays, and `_se_norm` adds a maximum scan and a scaled-square scan). But at the boundary of the Float32 normal range the more accurate value can fall on the other side: for `y = fill(1f-18, 100)`, `X = ones(Float32, 100, 1)` and the Float64 scale `Float64(floatmin(Float32))^2 / Float64(s)`, with `s` the sequential Float32 sum of the squares of `y`, master returns `converged = true` and the changed code refuses the response scale (reproduced on both Julia versions). `docs/src/numerics.md:34-39` allows a boundary rounding to land on either side, so this is a documented kind of change, but it is an acceptance change that needs its own ruling and boundary tests, for 7 lines.
- `response_scale` as a single `_SE` path (−21): changes the stopping scale in the last bits in about 35 % of cases, and carries the same boundary question.
- A supported PB name for `_residual_squares`, `_sumabs2_diff` or `_squares_normal` (PB #698): see the thresholds in section E.
- Moving proof text to developer docs (class F): the 97-line comment of `_certify!`, and about 100 comment lines of `_curvature_deferrable`, `_gram_curvature` and the group step that repeat `docs/src/numerics.md:415-600`. No executable effect; the group-CD duplication is the better candidate, since the text exists twice.
- A 7-line `_level_brackets`: correct on 4,513 levels, but it edits an input of the certificate proof for 8 lines.
- PB housekeeping, for #698: the uncalled `_scaled_dot`; the slower max/min form of the exported `shrink`.
