## Round 1 at `4c2efd7`

Commits: `a8136f6` (the change, made on `bb20b6a`) and `4c2efd7` (a merge of master `6e583f7`). Against master the PR changes one file, `src/cd/sqrtlasso.jl`, +16 −29.

### What changed

- `_scaled_norm` and its comment are deleted.
- `_prepare!`: `ny = _se_norm(Float64, m.ls.y)`, `m.floor64 = 16eps(T)*ldexp(ny.s, ny.e)`.
- `_sqrt_offrange_step`, where the cancelled distance is recomputed: `nd = _se_norm(Float64, s)`, `ds, ed = nd.s, nd.e`.
- The comment of `_sqrt_offrange_step` describes `_se_norm` where it described `_scaled_norm` (it divides by the largest magnitude of the difference; scaled entries of magnitude at most 1; significand of the norm in [1, 2)).

Executable lines of the file: 310 → 297 at `a8136f6` against its base (**−13**; `_sqrt_offrange_step` 39 → 40, `_scaled_norm` 14 → 0). The fast path, `_sqrt_band_step`, `_sqrt_threshold64` and the scaling of `_sqrt_offrange_step` are untouched.

### Why the merge commit

#362 (R2 + R4 of #353) merged while this was in work. It folds `_se_norm`, the function this PR now calls, without changing its results, and edits other lines of the same file. The merge was clean; because the PR depends on code master changed, every check below was repeated at the merge commit against a base worktree at `6e583f7`. The results equal those the implementer obtained at `a8136f6` against `bb20b6a`. Master has since gained #363 (examples and documentation only; no shared file, clean merge, no further merge commit).

### Rulings on the implementer's choices

- **No branch for a non-finite `y` in `_prepare!` (as instructed).** `_se_norm` returns `nothing` for a non-finite entry. `solve!` refuses a non-finite `y` before the model is prepared: both coordinate-descent gates that admit the square-root loss (`_check_problem`, `_check_owner_problem` in `src/solve.jl`) test `_allfinite` on the `Y` of `leastsquares_data(f)`, the array the model is built from, and the block gate refuses this loss. So the only difference is on a direct call of the private `_prepare!` with a non-finite `y`: the base stored an infinite or NaN floor, the head fails on `nothing`. The comment on the line states the condition.
- **`s` is finite at the second call:** its entries are `ldexp(r_i, −er) − q̃ x̃_i` with `|ldexp(r_i, −er)| < 2`, `|x̃_i| < 2` and `|q̃| ≤ ‖s‖/‖x̃‖ < 2√n` (the column is not flat, so `‖x̃‖ ≥ 1`), after `coordinate_step!` has refused a non-finite residual.
- **One clause added to the comment** (the division by the largest magnitude has the same absolute error bound below the normal range as the power-of-two scaling): accepted as a statement about correctly rounded division; the reviewer is asked to check the whole rewritten passage.

### What ran, at `4c2efd7` against `6e583f7`

All local, Julia 1.10.13 and 1.13.4, base and head as two modules in one process.

| # | check | result |
|---|---|---|
| 1 | steps that stay on the fast path (classified by master's conditions), bit for bit | 135,104 Float32 and 134,567 Float64 steps on 1.10.13, 134,812 and 134,123 on 1.13.4: **0 differ**. The roughly 15,000 out-of-range steps per type of the same run are bitwise equal too |
| 2 | out-of-range steps against a BigFloat reference and `step_bound` | random families (96,000 per version): 0 above the bound, 0 outcome-class changes; 26 (1.10.13) and 17 (1.13.4) Float64 steps differ in bits, by at most 128 ulp (2.2e-14 relative); no Float32 step differs. Boundary-targeted set (3,376,180 per version): 0 above the bound, 0 outcome-class changes; 9 and 3 Float64 steps differ, by 1 ulp. Targeted set for the changed branch (residual nearly or exactly parallel to the column at tiny and huge scales, distances down to far below 2^-511 of the residual, n from 1 to 2000): 88,960 cases per version, 86,790 and 86,874 through the recompute branch, 0 above the bound, 0 outcome-class changes; 330 and 312 Float64 steps differ, all in recompute cases, by at most 128 ulp (1.5e-14) on 1.10.13 and 2,050 ulp (4.5e-13) on 1.13.4. Worst excess/bound equal on base and head in every group |
| 3 | whole solves | 748-solve corpus: 748 of 748 bitwise identical (iterate, passes, `converged`, gap, minimum, error text), both versions. Tiny- and huge-scale solves: 454 on 1.10.13, all identical or throwing the same text; 456 on 1.13.4, of which 2 differ in the last bits (iterate by 3.0e-17 relative, objective by 1.2e-16), with no change of outcome class, `converged` or pass count; master's recompute branch runs in 162 and 161 of them. 158 square-root fingerprints: 0 mismatches |
| 4 | `floor64` over 4,000 vectors per type | bits differ in about 40 % of vectors, by at most 1.1e-15 relative (4e-14 at n = 10^5, where the deleted sequential sum is the less accurate one); no solve of check 3 changes its outcome class or pass count |
| 5 | full test tier (20 files) | 68,270 / 68,270 (1.10.13) and 68,225 / 68,225 (1.13.4), the same totals as the base `6e583f7`. `test/sqrt_lasso.jl` is not edited |
| 6 | warmed allocations | `solve!` equal on base and head; out-of-range steps 0 bytes on both, the recompute branch included (the branch counted as taken in an instrumented copy of the base) |
| 8 | executable lines | −13 |
| 9 | `comment_scan.py` | 0 candidate lines |

The implementer ran checks 1 to 6 and 8 to 9 at `a8136f6`; the orchestrator repeated them at `4c2efd7`, ran the full tier on head and base, and ran the timing.

### Timing (check 7)

Base, a second copy of the base (control) and the head in one process, 15 rounds rotated, minimum over 7 solves per round, one pinned core, one BLAS thread; shared machine (load average 3 to 5). Entries: range over cells of the median head/base ratio, with the control's range in parentheses. 8 ordinary square-root solves to convergence; 20 solves on tiny-scale data whose visits go through `_sqrt_offrange_step` (general, nearly parallel and collinear residuals); 10 step-level loops in which every visit takes that step, with and without the recompute branch.

| Julia | ordinary solves | out-of-range solves | step loops |
|---|---|---|---|
| 1.10.13, default target | 0.987–1.013 (0.994–1.010) | 0.958–1.025 (0.959–1.019) | 0.908–1.005 (0.997–1.004) |
| 1.10.13, AVX2 target, first run | 0.977–1.000 (0.999–1.009) | **0.991–1.330** (0.979–1.004) | 0.911–1.003 (0.997–1.003) |
| 1.10.13, AVX2 target, repeat 1 | 0.977–1.001 (1.000–1.006) | 0.969–1.002 (0.976–1.004) | 0.909–1.003 (0.998–1.003) |
| 1.10.13, AVX2 target, repeat 2 | 0.909–1.000 (0.912–1.010) | 0.988–1.002 (0.998–1.004) | 0.910–1.003 (0.998–1.003) |
| 1.13.4 | 0.973–1.008 (0.992–1.010) | 0.981–1.002 (0.994–1.003) | 0.961–1.001 (0.996–1.002) |

**One flagged group, not reproduced.** In the first run with the AVX2 target, the three Float32 out-of-range solves with a nearly parallel residual read 1.043, 1.100 and 1.330 (n × p = 200 × 1, 200 × 40, 1000 × 100), steady over the 15 rounds of that process, with the control at 0.98 to 1.00. The same harness run twice more gives 0.97 to 1.00 for those cells, and a recheck with two copies of the base and two of the head in three further processes (three load orders, 9 rounds) gives 0.980 to 1.008 for all six head measurements of each cell. So the reading belongs to that one process and not to the code; the same cells are at 0.96 to 0.98 with the default target and at 1.00 on 1.13.4. With that reading set aside, no cell is above 1.025, and the recompute branch itself is 2 to 9 % faster in the step loops (`_se_norm` vectorizes its sum; `_scaled_norm` did not).
