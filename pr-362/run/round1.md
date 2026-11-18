## Round 1 at `43a362d`

Commits: `226d165` (R2, five deletions) and `43a362d` (R4, folded scaled-norm kernels), on the base `bb20b6a`. 8 files, +47 −92; in `src/`, 6 files, +34 −85.

### What changed

**R2 (`226d165`)**
- `src/blocks.jl`: `_maxabs_diff` and its export deleted; `g_residual` (APG) and the norm of a difference in `src/solvers/image_models.jl` call `_norm_diff(x, y, Inf)`, the wrapper of ProximalBase's public `norm_diff`.
- `src/solvers/image_models.jl`: `_frobenius_upper` sums through `_sumsq64`; `_significand_exponent` deleted, `_root_scale` takes `Float64(α)` and its significand and exponent.
- `src/cd/sqrtlasso.jl`: `_round_up(T, v)` → `T(v, RoundUp)`.
- `src/cd/leastsquares.jl`: `_flat_column`, `_flat_group` → `all(iszero, …)`.
- `test/cd_numerics.jl`: the BigFloat scales of the response-scale loop stop at `2^±1000` instead of `2^±1500`. Nothing else in the testset changed; it still requires all three ways of `response_scale`.
- `docs/src/developer/implementation-notes.md`: the two passages on `_root_scale`.

**R4 (`43a362d`)**, `src/solvers/image_models.jl` only: `_se_norm(T, a, b = nothing)`, `_sumsq_scaled(a, b, m)` and `_se_norm_onepass(T, s, a, b = nothing)` replace the four norm and norm-of-difference functions, through `_diff(a, b, i)` (`aᵢ` for `b = nothing`); one caller in `_bound_certified!`. The proof comments are restated for both forms.

Executable lines (the counter of the Stage 0 archive), base → R2 → R4: `blocks.jl` 53 → 46 → 46; `image_models.jl` 183 → 176 → 159; `sqrtlasso.jl` 310 → 306 → 306; `leastsquares.jl` 367 → 357 → 357; the PGD and APG files unchanged (156, 196). **R2 −28, R4 −17**, as the report predicted.

### Instructions the implementer worked from

The plan above and the maintainer decisions on #353. Two points beyond them: the deferred "tier 2" deletion of `response_scale`, which the six-item Stage 0 prototype contains, is not ported (only the five-item patch is); and the implementer was asked to decide from the code whether the finiteness test of the scaled sum in the old `_se_norm_diff` can be dropped.

### Rulings on the implementer's choices

- **The finiteness test of the scaled sum is dropped (accepted).** With `m = max|dᵢ|` finite and positive, every `dᵢ` is finite (`max` propagates NaN, and an infinite `dᵢ` makes `m` infinite), each correctly rounded quotient satisfies `|dᵢ/m| ≤ 1` with the largest equal to 1, so the sum lies between 1 and `length(a)` up to rounding. `_se_norm` is the only caller of `_sumsq_scaled`, and it returns before the sum for a non-finite or zero `m`. The folded and the original functions agree on 990,000 comparisons per Julia version, overflowing differences included.
- **The comment of `_root_scale` and the second docs passage are worded by the implementer** instead of copied from the prototype (accepted; the prototype's comment used an undefined symbol).
- **A second BigFloat loop in `test/cd_numerics.jl`** (`check_coordinate_point`, the coordinate scale, still `2^±1500`) is left alone: it does not reach `_root_scale` (accepted; it passes).

### What ran, at which commit

All local, Julia 1.10.13 and 1.13.4.

| check | commit | result |
|---|---|---|
| full test tier (20 files), 1.10.13 | `43a362d` | 68,269 / 68,269 pass |
| full test tier (20 files), 1.13.4 | `43a362d` | 68,224 / 68,224 pass |
| full test tier at the base, for the counts | `bb20b6a` | 68,264 / 68,264 (1.10.13) and 68,219 / 68,219 (1.13.4): the head has 5 more assertions on each version, all in `test/cd_numerics.jl` (24,395 at the base, 24,400 at the head, the file run alone on both versions). They come from the edited loop: `check_scale_point` makes a different number of assertions at `2^±1000` than at `2^±1500`. The 19 other files have equal totals (68,264 − 24,395 = 68,269 − 24,400) |
| focused files (`cd_numerics`, `accelerated_pgd`, `sqrt_lasso`, `group_cd`, `group_cd_preflight`, `core_regressions`, `core_contracts`, `stopping_scale`) | `226d165` and `43a362d` | 53,057 / 53,057 (1.10.13) and 53,013 / 53,013 (1.13.4) at each commit |
| fingerprint matrix, base against head in one process (status, iterate bits, counts, objective, gap, thrown error and message) | `226d165` and `43a362d` | 4,806 comparisons on 1.10.13 and 4,794 on 1.13.4 (CD lasso and elastic net 2,952 / 2,940, group 512, square-root 158, PGD and APG 1,184): **0 mismatches** at each commit |
| unit sweep of the replaced helpers against the deleted ones | `226d165` and `43a362d` | about 6.19 million comparisons per version, all `===`: `_norm_diff(·,·,Inf)` 10,900; `_root_scale` on admitted scales 83,178 (integers 43,196, including `typemax` and values around 2^24, 2^53, 2^64); `_frobenius_upper` 8,000; `T(v, RoundUp)` 6,000,068; `_flat_*` 89,892 / 89,885 |
| folded `_se_norm`, `_se_norm_onepass` against the four originals | `43a362d` | 990,000 comparisons per version, 0 mismatches |
| warmed allocations, 26 solve cases and single helper calls | `226d165` and `43a362d` | equal on base and head in every case, both versions |
| `comment_scan.py` | `43a362d` | 0 candidate lines |
| test import check | `43a362d` | all declared |

The full tier, the base run and the timing were run by the orchestrator; the rest by the implementer, and the orchestrator read the evidence files (commit, clean state, totals) and the diff.

Outside the plan's scope, for information: for a scale **outside the range of Float64** given directly to `_root_scale` (BigFloat `2^1100`, `10^400`, `2^-1080`; BigInt `10^400`), the base returns a value and the head throws a `DomainError`. `_check_loss_scale` refuses such scale types before any solver arithmetic; this is the difference the plan names under "Risks", and the reviewer is asked to confirm that no public path reaches it.

### Timing (paired, in one process)

Base, a second copy of the base (A/A control) and the head, compiled from source in one process, 15 rounds with the order rotated, a round's figure the minimum over 5 batches, one pinned core, one BLAS thread. 50 cells per run: APG, PGD, CD lasso, CD group lasso with singleton groups and with groups of 4; Float32 and Float64; (n, p) ∈ {(20, 12), (100, 60), (400, 40), (40, 120), (1000, 200)}; solves to their stop at `λ = 0.1 λmax`. Pass and iteration counts are equal on the three sides in every cell. The machine was shared (load average 3 to 6 on 20 logical CPUs).

| Julia | cells | head / base: range of per-cell medians (geometric mean) | A/A control |
|---|---|---|---|
| 1.10.13, default target | 50 | 0.893–1.015 (0.9919) | 0.910–1.013 (0.9935) |
| 1.10.13, AVX2 target | 50 | 0.989–1.023 (1.0021) | 0.978–1.020 (0.9997) |
| 1.13.4 | 50 | 0.988–1.015 (1.0017) | 0.984–1.021 (1.0010) |

The cells with a head median of at least 1.015 (`median[min, max]` over rounds):

| Julia | workload | type | n | p | head / base | A/A control |
|---|---|---|---|---|---|---|
| 1.10.13, default target | apg | Float64 | 20 | 12 | 1.015[1.006,1.077] | 1.007[1.000,1.070] |
| 1.10.13, AVX2 target | apg | Float64 | 20 | 12 | 1.023[1.016,1.029] | 1.008[0.955,1.014] |
| 1.10.13, AVX2 target | cd | Float64 | 20 | 12 | 1.016[1.010,1.025] | 0.998[0.990,1.005] |
| 1.10.13, AVX2 target | cd | Float64 | 100 | 60 | 1.021[1.015,1.028] | 1.001[0.998,1.006] |
| 1.10.13, AVX2 target | group4 | Float64 | 400 | 40 | 1.019[0.993,1.034] | 1.020[0.995,1.042] |
| 1.13.4 | apg | Float32 | 20 | 12 | 1.015[1.011,1.020] | 1.006[1.003,1.009] |

**No cell exceeds 1.05; the largest is 1.023.** The one pattern above the control is APG at p = 12 (1.5 to 2.3 % on 1.10, 1.5 % in Float32 on 1.13). It is consistent with a fixed per-call cost of ProximalBase's `norm_diff` (its argument checks) in the per-iteration `g_residual`, which would show at 12 coefficients and not at 40 or more; that attribution is not measured separately. The two CD cells on the AVX2 target are solves of 2 to 6 µs; the only code this PR changes on that path is in the per-solve setup (`response_scale`), and the same cells are at 1.007 and 0.974 with the default target.

### Not done in this round

- The `Nightly` workflow (Linux 1.10, macOS, Windows) is dispatched at the final commit, after the review.
