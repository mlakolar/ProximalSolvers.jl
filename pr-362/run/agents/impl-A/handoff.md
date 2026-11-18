# Hand-back: #353 PR A (PR #362), implementer

## What changed

Commit 1 (R2, 226d165), five bit-identical deletions:
- `src/blocks.jl`: `_maxabs_diff` and its export deleted. Its two callers (`g_residual` in the APG file, `_se_norm_diff` in `image_models.jl`) call `_norm_diff(x, y, Inf)`.
- `src/solvers/image_models.jl`:
  - `_frobenius_upper` takes `s = _sumsq64(X)`.
  - `_significand_exponent` is deleted. `_root_scale` takes `a = Float64(α)`, `s, e = significand(a), exponent(a)`.
  - The `_root_scale` comment is rewritten (see Deviations).
- `src/solvers/proximal_gradient_descent.jl`: the `_sumsq64` comment now reads "an array of Float32 or Float64".
- `src/cd/sqrtlasso.jl`: `T(ratio, RoundUp)`, and `_round_up` is deleted.
- `src/cd/leastsquares.jl`: `_flat_column` and `_flat_group` are one-liners with `all`.
- `test/cd_numerics.jl`: only the BigFloat `j` loop of the response-scale testset is now `(-1000, -300, -1, 0, 1, 300, 1000)`, with a two-line comment. `@test ways == Set([1, 2, 3])` is untouched, and the deferred "tier 2" deletion is not ported. Before editing I checked on a copy of the base (a scratchpad `git archive` of bb20b6a with the narrowed loop): all of `cd_numerics` passes, including "the response scale over the ranges of y and the loss scale" for Float32 (1325 tests) and Float64 (1036 tests), so all three `ways` are still reached.
- `docs/src/developer/implementation-notes.md`: the two `_root_scale` passages are rewritten (near lines 69 and 360). They now say:
  - `α` is rounded once to Float64.
  - That rounding is exact for a Float32 or Float64 scale, a `Bool`, and an integer of magnitude at most 2^53; a larger integer is rounded once.
  - The significand and exponent are taken there.
  - The root of the significand is converted to `T`, and half the exponent is carried as the `Int` exponent of an `_SE`.
  - A scale outside the range of Float64 is not supported by `_root_scale`.

  I checked the Float64 conversion statements against Julia's rules. The "exact for admitted integers" claim in the code comment holds because `_check_loss_scale` requires `T(α) == α` with T Float32 or Float64.

Commit 2 (R4, 43a362d), `src/solvers/image_models.jl` only:
- `_diff(a, b, i)` and `_diff(a, ::Nothing, i)`.
- `_sumsq_scaled(a, b, m)`, `_se_norm(T, a, b = nothing)` and `_se_norm_onepass(T, s, a, b = nothing)`. `_bound_certified!` calls `_se_norm_onepass` for the difference.
- `_sumsq_scaled_diff`, `_se_norm_diff` and `_se_norm_diff_onepass` are gone.
- The prototype `sc_on_x2.patch` applied by `patch` (hunk 3 at offset 1). The result equals `sc_tree/src/solvers/image_models.jl` except for my `_root_scale` comment.
- I did not change the `_se_norm` call sites in `src/solvers/accelerated_proximal_gradient_descent.jl`, `src/cd/leastsquares.jl` and `test/accelerated_pgd.jl`: they use the 2- and 3-argument forms that keep their names.
- Proof comments rewritten for both forms:
  - `_sumsq_scaled`: dᵢ = aᵢ - bᵢ, aᵢ for `b = nothing`, m finite and positive, sum in [1, length(a)] up to rounding, "each |dᵢ/m| ≤ 1 and the largest is 1, so the sum is finite".
  - `_se_norm`: "nothing when a dᵢ is not finite (including an overflowing aᵢ - bᵢ)".
  - `_se_norm_onepass`: the γ_{n+4} and `4 length(a) floatmin(T)` text is kept, now stated for the rounded differences, plus "nothing when a dᵢ is not finite" for the two-pass fallback.

## Commit SHA(s) and `git status --porcelain`
- 226d165 Delete five numerical helpers that Base or an existing helper already provides (#353)
- 43a362d Fold the two scaled-norm kernel families of the image model into one (#353)
- Base f8691e9 (empty bootstrap) on bb20b6a. HEAD is 43a362d.
- `git status --porcelain`: empty (probes live under the ignored `.codex-orchestrator/`). Nothing was pushed and GitHub was not touched.
- `grep -rn "_maxabs_diff\|_round_up\|_significand_exponent" src test docs benchmark examples` finds nothing. The old `_se_norm_diff` and `_sumsq_scaled_diff` names are also absent.

## Commands run with results
All runs local, under the run lock. Evidence files are in `$R/evidence/` with `R=<WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf`.

Focused tests. The battery's prefix filter matches 8 files: cd_numerics, accelerated_pgd, sqrt_lasso, group_cd, group_cd_preflight, core_regressions, core_contracts, stopping_scale. The battery prints only a total for the run, not a count per file.

| Run | Commit | Julia | Result |
|---|---|---|---|
| r2-lts | 226d165 | 1.10.13 | BATTERY PASS, 53057/53057, 85 s |
| r2-release | 226d165 | 1.13.4 | BATTERY PASS, 53013/53013, 79 s |
| r4-lts | 43a362d | 1.10.13 | BATTERY PASS, 53057/53057, 80 s |
| r4-release | 43a362d | 1.13.4 | BATTERY PASS, 53013/53013, 78 s |

Other commands:
- Probe scripts are in `.codex-orchestrator/probes/`: `loader.jl`, `fp_lib.jl`, `fp_matrix.jl`, `unit_items.jl`, `fold_check.jl`, `empty_check.jl`, `allocs.jl`, `loc_delta.sh`, `pra_paired.jl`, `summarize.py`.
- One exploratory `empty_check` run on lts used `--allow-dirty` before commit 2 (`x-empty-lts`). One exploratory fold-check pass on each version, also `--allow-dirty` before commit 2, gave the same result as the final runs (`x-fold-*`). All other probe runs are at clean commits.
- Import check: `test imports: all declared`.

## Evidence for each check 1–7
1. Focused test files: see the table above.
2. Fingerprint matrix, base against head, one process (`r2-fp-*` and `r4-fp-*`):

   | Julia | TOTAL comparisons | cd-group | cd-lasso/enet | cd-sqrt | pgd/apg | mismatches |
   |---|---|---|---|---|---|---|
   | 1.10.13 | 4806 | 512 | 2952 | 158 | 1184 | 0 |
   | 1.13.4 | 4794 | 512 | 2940 | 158 | 1184 | 0 |

   Every family shows `mismatches=0`, at both commit 1 and commit 2. The totals equal the Stage 0 numbers.
3. Unit sweep, base against head in one process. These numbers are the same at commit 1 and commit 2, on both Julia versions unless noted. (`r2-unit-*`, `r4-unit-*`; `unit_items.jl` was adapted to the new loader, with an added integer-type sweep for `_root_scale`.)
   - `_norm_diff(x, y, Inf)` against `_maxabs_diff`: 10,900 comparisons, 0 mismatches. This covers Float32 and Float64, NaN, ±Inf, signed zeros, subnormals, n = 0, views and matrices.
   - `_root_scale` on admitted scale types: 83,178 comparisons, 0 field mismatches.
     - Scales: Float32, Float64, `Bool`, Int8…Int128 and UInt8…UInt128, including typemax and values around 2^24, 2^53 and 2^64.
     - The integer part alone is 43,196 comparisons, with 0 field mismatches and 0 value mismatches.
     - `_SE` fields are `===` in every case, so no `s·2^e` value comparison was needed.
   - `_root_scale` on types outside the plan (BigFloat, Rational, π, Float16, BigInt, UInt128 and so on) was run as an informational check.
     - It gives identical fields for every BigFloat, Rational, BigInt, UInt128 and irrational scale within Float64 range.
     - It differs only for scales outside the range of Float64 (BigFloat 2^-1075, 2^-1080, 2^1100, 2^-2000, 10^400; BigInt 10^400; Rational 1//10^400). There the base returns a value and the head throws a `DomainError`. These are the intended "not supported by `_root_scale`" cases; the solvers refuse non-machine scale types before `_root_scale`.
   - `_frobenius_upper`: 8,000 comparisons, 0 mismatches.
   - `T(v, RoundUp)` against `_round_up`: 6,000,068 comparisons, 0 mismatches. Extra informational checks: 400,000 negative inputs (unreachable) also show 0 differences, and `Float64(v, RoundUp) === v` for 10^6 random Float64 values.
   - `_flat_column` and `_flat_group`: 89,892 comparisons on lts and 89,885 on release, 0 mismatches. This covers -0.0, NaN, subnormals, groups of Int and Int32 indices, and a direct sparse LSModel.
   - Total of the `unit_items.jl` sweep: about 6.19 million comparisons per version, all `===`.
   - Folded `_se_norm` and `_se_norm_onepass` (`r4-fold-*`) against the base's four functions: 990,000 comparisons per version, 0 mismatches.
     - Inputs: vectors and matrices; NaN, Inf, all-zero, -0.0, subnormal, huge and mixed-scale entries; `a == b`; forced one-pass sums (Inf, NaN, 0, floatmin, at and just below the `4 n floatmin` threshold); Float32 data with a Float64 working type; empty arrays.
     - Errors would be compared by message; none occurred.
   - `empty_check`: empty problems (n or p = 0) through the three solvers throw the same `DimensionMismatch` in base and head. `_se_norm(T, [])` is `_se_zero` in both.
4. Warmed allocations (`r2-allocs-*`, `r4-allocs-*`). 26 solve cases (CD lasso, enet, group, sqrt, PGD, APG, Float32 and Float64, tiny-scale cases) plus single warmed helper calls (`_norm_diff` Inf, `_frobenius_upper`, `_root_scale`, `response_scale`, `_flat_column`, `_flat_group`).
   - "Cases with differing allocation: 0 of 26" on both versions, at both commits.
   - Single calls are equal on base and head. On 1.10 they are 16, 32, 32, 16, 16, 0, 0 bytes; on 1.13 they are all 0.
   - The listed single calls do not include the folded `_se_norm`, but APG and `response_scale` exercise it inside the solve cases.
5. Line counts, executable lines per `count_loc.py`, base to head:

   | File | Base | Commit 1 | Commit 2 |
   |---|---|---|---|
   | `src/blocks.jl` | 53 | 46 (-7) | 46 |
   | `src/solvers/image_models.jl` | 183 | 176 (-7) | 159 (-17) |
   | `src/cd/sqrtlasso.jl` | 310 | 306 (-4) | 306 |
   | `src/cd/leastsquares.jl` | 367 | 357 (-10) | 357 |

   The two APG and PGD files are unchanged in executable lines (196 and 156). R2 is -28 and R4 is -17, as expected.
6. `comment_scan.py bb20b6a HEAD`: "0 candidate lines in 0 files". There is nothing to answer.
7. `check_test_imports.jl bb20b6a`: "test imports: all declared".

## The `_se_norm_diff` finiteness question
Conclusion: the `isfinite(s)` test is redundant, and the folded function has no such test.

Argument from the code:
- `m = _norm_diff(a, b, Inf)` is ProximalBase's `max(v, abs(T(a[i] - b[i])))` loop, i.e. the exact maximum of the rounded differences dᵢ computed in T.
  - `max` propagates NaN, so a finite m means every dᵢ is finite and not NaN.
- `_sumsq_scaled` divides each dᵢ by m, where m is at least |dᵢ|.
  - Division is correctly rounded and monotone, so |dᵢ/m| ≤ 1, and the term for the maximum is exactly 1.
  - Each square is at most 1. The computed sum is at least 1 (a sum of non-negative terms is at least its largest term) and at most length(a) up to rounding.
  - That is far below floatmax(T) for any array length.
  - With m a normal or subnormal positive number, dᵢ/m cannot overflow.
- The same holds when Float32 differences are divided by a Float64 m: the conversion is exact and the maximum term is still exactly 1. In `_se_norm_diff`, T equals the element type of both arrays; the only mixed-type call (Float32 data, Float64 working type) is the single-array norm.
- Evidence: the fold check with 990,000 comparisons per version, including overflowing differences (floatmax minus -floatmax), NaN, Inf and mixed scales, never shows base `nothing` and head non-`nothing` or vice versa.

I recorded this as a comment line on `_sumsq_scaled` and in the commit message.

## Deviations from the plan (smaller choices)
- I did not copy the patch's `_root_scale` comment. It used an undefined "s′" and "without range loss". It now says: a = Float64(α) = s·2^e with s in [1, 2); the conversion is exact for the scales that `_check_loss_scale` admits; where e is odd s is doubled and e lowered by one; an α outside the range of Float64 is not supported.
- The second docs passage says the root of the significand is converted to `T` and half the exponent is carried in the `_SE`. The brief's wording was "the significand and exponent are taken there". I dropped "rounded once to Float64 before its root" because `significand(a)` of a Float64 is already exact.
- I added a short comment above the test loop: "not beyond the range of Float64: `_root_scale` does not support such a scale (the solvers refuse a scale of a non-machine type before it, in `_check_loss_scale`)".
- The second BigFloat loop at `test/cd_numerics.jl` line ~1176 (`check_coordinate_point`, the coordinate scale) still uses `(-1500, …, 1500)`. It is a different testset that does not reach `_root_scale`, so I left it alone as instructed.
- I edited the fingerprint, unit and allocation probes only to point at the new loader and to add the integer-type, matrix, empty-array and forced one-pass cases listed above.

## Not run
Every item in the brief was run, except the two timing and full-tier steps the brief assigns to the orchestrator:
- The full test tier (plan check 1): reserved for the orchestrator at the final head.
- The full 15-round paired timing run (plan check 5): reserved for the orchestrator. Only the 1-round smoke on 1.13.4 ran, as instructed. It completed with 150 rows (3 sides × 5 workloads × 2 element types × 5 sizes × 1 round) at commit 43a362d. Per-case head/base0 median ratio ranged 0.987 to 1.016 (geo-mean 1.0011); base1 (A/A) 0.984 to 1.015 (geo-mean 0.9991). This is a smoke only, not evidence of no slowdown.

## Timing command for the orchestrator
Full 15-round run on the release build; run it alone, since it is timing-sensitive. Use `+lts` instead of `release` for the 1.10 run, and change the output names.
```
cd <WORK>/ProximalSolvers.jl-issue353 && R=$PWD/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf && python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py julia --worktree $PWD --run-dir $R --where local --versions release --tag probe --name pra-timing -- --project=. .codex-orchestrator/probes/pra_paired.jl $R/evidence/timing/pra-release.tsv 15 && python3 .codex-orchestrator/probes/summarize.py $R/evidence/timing/pra-release.tsv
```
Wall time for 1 round was about 14 s, so about 3.5 minutes at 15 rounds, plus the TSV. `summarize.py` prints the per-round ratio of each side to base0 (the A/A control is `base1`).

## Open questions
- `_se_norm` for `b === nothing` now uses `_norm_inf(a)` (`norm(a, Inf)`) where the base used `maximum(abs, v)`. Results are bit-identical in every sweep (NaN, Inf, empty included). The orchestrator's timing run on the APG workloads is what shows whether the two cost the same in the APG fallback.
- The `_root_scale` comment says the conversion is exact for what `_check_loss_scale` admits. The docs say an integer beyond 2^53 is rounded once, which holds for an integer given directly to `_root_scale` (for example from a hand-built LSModel). Through `solve!`, `_check_loss_scale` admits only integers that are exactly representable in `T`.

Status: COMPLETE