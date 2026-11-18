## Plan for PR B (R1-min of #353)

Drafted by the orchestrator from the plan in the Stage 0 report of #353, revision r3 (the fallback "R1-min" of recommendation R1, [part 4](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6968386639)), the [maintainer decisions](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059) and the [result of the R1 investigation](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6970454563). No separate critique: the change is the fallback the maintainer named, and it is two call sites.

### Change (one commit, `src/cd/sqrtlasso.jl`)

- `_scaled_norm` is deleted (14 executable lines).
- `_prepare!`: the tightening floor `floor64 = 16 eps(T) ‖y‖` takes `‖y‖` from `_se_norm(Float64, y)`.
- `_sqrt_offrange_step`: the distance recomputed after a cancellation takes its norm from `_se_norm(Float64, ·)` (one line more than before).
- Comments that describe `_scaled_norm` are updated. Nothing else in the step changes: the fast path, `_sqrt_band_step`, `_sqrt_threshold64` and the scaling of `_sqrt_offrange_step` stay.

Expected: −13 executable lines.

### What can change, and the criteria (pre-registered)

`_se_norm` scales by the largest magnitude (a division per entry) where `_scaled_norm` scaled by a power of two, so the two norms can differ in the last bits.

| # | Check | Criterion |
|---|---|---|
| 1 | Steps that stay on the fast path, base against head in one process | bit-identical (they do not reach the changed code) |
| 2 | Steps through `_sqrt_offrange_step`, random families and a boundary-targeted set, against a BigFloat reference | every returned value inside `step_bound` of `test/sqrt_lasso.jl`; outcome class (value, non-finite, thrown error and message) equal to the base in every case; the number of steps whose bits differ and the largest difference reported |
| 3 | Whole solves: the 748-solve corpus, the 454 tiny- and huge-scale solves and the 158 square-root fingerprints of the R1 investigation | `converged`, certified or uncertified, thrown error and pass count equal to the base in every solve; differing iterates reported with their size |
| 4 | `floor64` | largest relative change reported; no solve changes its outcome class or pass count because of it |
| 5 | Tests: `sqrt_lasso` (no assertion changed), `cd_numerics`, `core_regressions`, `core_contracts`, `stopping_scale`, `accelerated_pgd`, Julia 1.10.13 and 1.13.4; the full tier at the final head | all pass, counts equal to the base |
| 6 | Warmed allocations of `solve!` and of an out-of-range step | equal to the base |
| 7 | Paired in-process timing (base, second base copy, head): ordinary square-root solves, and solves whose visits go through `_sqrt_offrange_step` including the recomputed-distance branch | no cell above 1.05 that the control does not show |
| 8 | Executable-line count | reported against −13 |

Required PR CI (Linux, Julia 1) picks the full tier for this source file. The 1.10 suite runs locally. This PR also meets PR #362 (R2 + R4 of #353) in `src/cd/sqrtlasso.jl` (other lines) and in `_se_norm`, which #362 folds without changing its results: whichever merges second is caught up with master and its checks 1 to 3 are repeated at the merge commit.

**Where things run:** locally, as for #362. Review: Codex gpt-6.1-sol, high, every implementation push.

**Plan approved in self mode**, on the same terms as #362: merge after Codex PASS / NO BLOCKERS on the final commit, green required CI and no open review thread; changes to supported numerical behavior, new refusals, a reproducible slowdown above 5 % and anything larger than this fallback go to the maintainer.
