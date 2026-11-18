## What changed

The change is one commit, with one file touched (`src/cd/sqrtlasso.jl`, +16/−29). `_scaled_norm` and its comment are deleted, and the two callers use `_se_norm(Float64, ·)`.

```julia
# _prepare!
  ny = _se_norm(Float64, m.ls.y)   # `nothing` for a y with an entry that is not finite, which `solve!` has refused
  m.floor64 = 16eps(T)*ldexp(ny.s, ny.e)

# _sqrt_offrange_step, recompute branch
    @inbounds for i in 1:n
      s[i] -= qs*ldexp(Float64(X[i, k]), -ex)
    end
    nd = _se_norm(Float64, s)      # the entries of s are finite here
    ds, ed = nd.s, nd.e
```

Comments:
- In the long comment of `_sqrt_offrange_step`, "by `_scaled_norm` (which scales by …)" now names `_se_norm`, which divides by the largest magnitude of the difference.
- The sentence "the largest magnitude of its normalized representation is in [1, 2)" is split. For x̃ and s the largest magnitude is in [1, 2) (neither is zero there). For the difference, the scaled entries have magnitude at most 1 and the norm's significand is in [1, 2); a zero difference gives d̃ = 0.
- I added one clause, which the base comment did not need. The division by the largest magnitude has the same absolute bound η/2 below the normal range, and a relative 2^-53 per entry above it.
- "d also through the scaling inside `_scaled_norm`" now says `_se_norm`.
- The two `_se_norm` facts the new comment relies on, significand in [1, 2) and scaled entries at most 1, were re-derived from `_se_norm`, `_se_mul` and `_renormal`.
- `_se_norm` and `_sumsq_scaled` are untouched.

Nothing else in the step changed: the fast path, `_sqrt_band_step`, `_sqrt_threshold64` and the scaling logic are as before.

Direct call to `_prepare!`: with a non-finite `y` it now fails with `FieldError: type Nothing has no field s`. The base returned an Inf or NaN floor. I added no refusal and no branch. `solve!` never reaches it with such a `y` (see below).

## Commit SHA and status

Commit `a8136f66bff5058d9413f46626c5709044d1bd61` on `fix/issue-353-scaled-norm`. It has not been pushed, and the PR is untouched. `git status --porcelain` is empty (`.codex-orchestrator/` is gitignored). `grep -rn _scaled_norm src test docs benchmark examples` finds nothing. No test comment or docs passage named `_scaled_norm`, so there was nothing to fix there.

## Why `y` and `s` are finite at the two calls

**`y` in `_prepare!`.** The only caller is `_run_cd!` (`src/cd/solver.jl:508`), reached from `solve!(x, f, g, ::CDSolver)` (`solver.jl:539-549`). All three paths gate first:
- Sparse owner: `_check_owner_problem` (`solve.jl:181-188`).
- Dense: `_check_problem(x, f, g, :cd)` (`solve.jl:168-175`).
- Block: `_check_block_problem` (`solve.jl:192-201`); it refuses the square-root loss through `_check_sqrt_data` with `:block`, so `_prepare!` is not reached for it.

The first two paths evaluate `_allfinite(base.Y)`, where `base = _check_sqrt_data(...)` returns `leastsquares_data(f)`, and refuse with "x, X and y must contain only finite values". `cdmodel` builds `LSModel(d.Y, …)` from the same `d.Y` that was checked. No public path found with a non-finite `y` reaching `_prepare!`; PGD and APG refuse this loss outright.

**`s` in `_sqrt_offrange_step`.** `s` is `m.res64` (length n), filled from `r` and then updated in place.
- X is finite (gated). `r` is finite because `coordinate_step!` refuses a non-finite residual (`isfinite(ρ2) || _check_residual`).
- `M > 0` here, so `s_i = ldexp(r_i, −er)` has |s_i| < 2.
- The column is not flat, so `Mx > 0` and `ã ≥ 1`. Then |q̃| = |b̃/ã| ≤ ‖s‖/‖x̃‖ ≲ 2√n, and |x̃_i| < 2, so `s_i − q̃ x̃_i` is finite.

## Commands run and results

Test files at commit `a8136f6`, via `battery.py tests … sqrt_lasso cd_numerics core_regressions core_contracts stopping_scale accelerated_pgd`. Evidence files are `evidence/b-lts-lts.out` and `evidence/b-rel-release.out` in the impl-B run dir.
- 1.10.13: `lts ok exit 0 37860/37860 62s`, `BATTERY PASS`.
- 1.13.4: `release ok exit 0 37880/37880 73s`, `BATTERY PASS`.
- `test/sqrt_lasso.jl` was not edited. I did not extract its per-file count from the output; the combined totals are above.

All probe output is under `…/run-20261118T0505-issue353-dfaf-b/evidence/` as `<name>-<version>.out`. I copied the scripts from the r1 folder into `$WT/.codex-orchestrator/probes/` and repointed the candidate tree to the `-2` worktree. The base tree is `-base`.

## Evidence for checks 1–9

1. **Fast-path steps, bit for bit (`exp_b1.jl`).** It runs steps from random states in both trees and compares the coordinate value, the residual cache, the curvature cache and x bit for bit. It requires equality for steps that master classifies as `:fast` or `:lam`.
   - 1.10: Float32 fast/lam 135,237 steps, 0 differ; Float64 134,599 steps, 0 differ.
   - 1.13: Float32 134,824, 0 differ; Float64 134,111, 0 differ.
   - Non-fast steps (`:sums`, `:d2`): all bitwise equal in all four cells, 15,101 and 15,469 on 1.13.

2. **Out-of-range steps.**
   - **`exp2c.jl`**, N=4000 per family and type (20 families), seed 7, against a BigFloat-512 reference and `step_bound`.
     - 1.10: 96,000 cases, candidate above the bound 0, outcome-class mismatches 0, 26 steps differ in bits (all Float64).
     - 1.13: 96,000 cases, 0 above the bound, 0 class changes, 17 differ (all Float64).
     - Float32: no step differs in any family.
     - Differing Float64 steps, per family (count, max ulp, max relative):

       | Family | 1.10 | 1.13 |
       |---|---|---|
       | wide_mod | 1, 8 ulp, 1.2e-15 | none |
       | wide_full | 2, 128 ulp, 2.2e-14 | 1, 2 ulp, 2.4e-16 |
       | thresh | 5, 64 ulp, 1.2e-14 | 2, 4 ulp, 8.6e-16 |
       | corner | 11, 8 ulp, 1.6e-15 | 8, 2 ulp, 2.4e-16 |
       | huge_edge | 4, 2 ulp, 2.6e-16 | 5, 2 ulp, 2.5e-16 |
       | band | 3, 4 ulp, 6.8e-16 | 1, 4 ulp, 7.0e-16 |

     - Worst candidate excess/bound over all families is about 0.06 (wide_full Float32); base and candidate worst ratios are equal.
     - The 1.10 and 1.13 counts differ because the RNG streams differ between Julia versions.
   - **`d_all.jl`/`exp_d.jl`**, the boundary-targeted set: 28 blocks (type, n ∈ {1,2,3,5,30}, parts), 3,376,180 cases per version.
     - 0 above the bound, 0 outcome-class changes, 0 zero flips.
     - Only Float64 n=30 differs: 9 steps on 1.10 (max 1 ulp, 1.26e-16) and 3 on 1.13 (same maxima). All Float32 and all smaller n are bit-equal.
   - **New targeted set `par_targeted.jl`**, for the recompute branch (`ds2 < ss/16`). Details in "Probe scripts" below.
     - Run with 40 draws, seed 3, both types, n ∈ {1,2,3,5,30,2000}.
     - 1.10: 88,960 cases, 88,908 reached `_sqrt_offrange_step`, 86,790 reached the recompute branch. 0 above the bound, 0 class changes, 330 steps differ (Float64 only; every one in a recompute case).
     - 1.13: 88,960 cases, 88,910 reached `_sqrt_offrange_step`, 86,874 reached the recompute branch. 0 above the bound, 0 class changes, 312 differ.
     - Largest difference: 1.10 128 ulp / 1.46e-14 (n=5); 1.13 2,050 ulp / 4.5e-13 (Float64, n=30).
     - Per-cell numbers are in `parN-<v>.out`.
     - Both trees stay far inside the bound there (worst excess/bound about 4e-4, Float64 n=2000).

3. **Whole solves.**
   - `exp_b2` (748 solves): bitwise identical in 748 of 748 on both versions. Outcome classes (1.10: C=489, u=259; 1.13: C=500, u=248, no throws) and passes are equal, as are x, gap and minimum.
   - `tiny_solves`: 454 solves on 1.10, 456 on 1.13 (the RNG stream shifts the count of solves with a usable λ).
     - 1.10: 22 throw in both with the same text; 432 are bitwise identical; 0 differ.
     - 1.13: 24 throw in both with the same text; 430 are bitwise identical; 2 differ, with max relative x difference 3.0e-17 and objective 1.2e-16. 0 outcome-class, converged-flag or pass-count changes.
     - Base's recomputed-distance branch ran in 162 solves (264 calls beyond `_prepare!`) on 1.10 and in 161 solves (235 calls) on 1.13.
   - `fp_sqrt`: 158 comparisons, 0 mismatches on both versions.

4. **`floor64`** (4,000 random y per type, scales 2^±1000 for Float64 and 2^-120..2^100 for Float32).
   - Value differs in about 40% of vectors, by at most 1.06e-15 relative (Float32 on 1.10; Float64 at most 7.8e-16).
   - At n = 1e5 the largest change is 4.1e-14 relative (Float32 on 1.13; the base's sequential sum is less accurate there).
   - Zero y gives 0 in both.
   - No solve changed outcome class or pass count (checks 3 and 5).

5. Test files: see "Commands run" above.

6. **Allocations (`alloc.jl`).** Warmed passes: ordinary 0 B, cold tiny residual, tiny column and huge residual 0 B, `r = 0` 0 B, band 0 B, in both base and head. A warmed `solve!` allocates the same in both (Float32 15,536 B and Float64 20,208 B on 1.10; 14,992 B and 19,648 B on 1.13).
   - New `alloc_recomp.jl`: a warmed step through the recompute branch, with a near-parallel tiny-scale residual reset before each visit. Float32 and Float64, n ∈ {3, 30, 2000}: 0 B per 1000 visits, base and head, both versions.
   - The base copy with counters confirms the branch ran in 5 of 5 warm visits, in all 12 cells.

7. **Timing.** Not run for the report, as the brief says. `timing_b.jl` is prepared. It loads base, a second base and head, plus an untimed counter copy of base. It does at least 9 rotated rounds with the minimum over batches. Cells:
   - ordinary solves to convergence for (30,10), (200,40), (40,120), (1000,100), both types;
   - tiny-scale solves: general residual, near-parallel residual, and collinear columns;
   - step-level loops where every visit takes the recompute branch (collinear) or does not (general).

   One-round smoke run on 1.13: all bits equal and passes equal in all cells. Head/base ratios were ordinary 0.88–1.10 outside (30,10), and Float64 (30,10) read 1.85. Single-round tiny-solve and step-loop ratios ran 0.90–1.10, mostly 0.96–1.01. These are not measurements: each cell is one round of one solve and the control moves as much, so the orchestrator should read the full run.

8. **Lines.** `count_loc.py src/cd/sqrtlasso.jl`: base 310, head 297 (−13). `_prepare!` is 15 both, `_sqrt_offrange_step` 39 → 40.

9. **`comment_scan.py bb20b6a HEAD`:** "0 candidate lines in 0 files". Nothing to answer.

### Probe scripts, what each compares
- `trees.jl`/`r1lib.jl`: load base and head as two modules in one process. They provide a one-column model, a classification of the step by master's fast-path conditions, a BigFloat-512 reference, `step_bound`, and outcome class (value, non-finite, thrown error and text) and ulp/relative-difference helpers.
- `exp_b1.jl`: fast-path steps bit for bit (above).
- `exp2c.jl` with `exp2_fams.jl`: step families against the BigFloat reference and `step_bound`, plus base-vs-head outcome class and bits.
- `d_all.jl`/`exp_d.jl`: boundary-targeted set at the `_clean_sum` thresholds, γ and γλ range edges, and the λ ≈ √a edge.
- `exp_b2.jl`, `tiny_solves.jl`, `fp_sqrt.jl` with `fp_lib.jl`: whole solves, compared bit for bit or by outcome class and pass count.
- `floor64.jl`: `floor64` at `_prepare!`. I changed it to catch the head's failure on non-finite `y` so it reports the failure instead of crashing. The base value is printed beside it.
- `alloc.jl` is unchanged.
- New probes:
  - `par_targeted.jl`: residual r = c·x_k + a small perturbation, at tiny and huge scales. Perturbation sizes range from 0 (exactly parallel) to 2^-100 relative. A second form puts the column on one nonzero entry with perturbations 2^-600 to 2^-1060 (Float32 2^-60 to 2^-140) of the residual, which is far below 2^-511 for Float64.
  - `alloc_recomp.jl` and `timing_b.jl`, as above.
  - `base_instr/`: a copy of the base `src` with two counters. `OFFR` counts calls reaching the `ds2` line. `RECOMP` counts entries to the `ds2 < ss/16` branch. It is never in the worktree sources.

## Deviations from the plan

None in the code. The brief's checks were extended beyond the reused scripts:
- `par_targeted.jl` and `alloc_recomp.jl` are new.
- I changed `floor64.jl` as described.
- The brief says 454 tiny solves; on 1.13 the script produces 456 (RNG stream).

## Not run

- The reported timing (check 7), by instruction. The smoke run is the only timing output.
- The full test tier, which was not asked for. I ran the six listed test files on both versions.

## Timing command for the orchestrator

```
python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py julia --worktree <WORK>/ProximalSolvers.jl-issue353-2 --run-dir <WORK>/ProximalSolvers.jl-issue353-2/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf-b --where local --versions release --tag probe --name timing_b -- --project=. .codex-orchestrator/probes/timing_b.jl 9 7
```
The smoke run used the same command with arguments `1 1` and `--name timesmoke`. Output goes to `evidence/<name>-release.out`. Run it alone, since it times in-process.

## Open questions

- One Float64 step in the recompute set differs from the base by 4.5e-13 relative (2,050 ulp, 1.13, n=30). The candidate is far inside `step_bound` there. I did not trace why the step is that sensitive. It is presumably a near-cancellation in `|c| − τ`, and the base and candidate norms differ in last bits.
- The "same absolute bound (η/2) below the normal range" in the comment is a plain consequence of correctly rounded division. I did not re-derive the 3nη‖r‖ constant. I only checked that the bound has the same form with m the largest entry of the difference.

Status: COMPLETE