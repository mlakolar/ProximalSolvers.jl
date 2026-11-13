## Run report at `7662585`

**What changed.** Baseline `3408e1f` → final `7662585` (one change commit after the bootstrap). Five files, +10/−16 lines in `src`: the five approved #279 items, as described in [round 1](https://github.com/mlakolar/ProximalSolvers.jl/pull/299#issuecomment-6846460862). Master has since moved to `001ed43` (#297). That commit touches only CI configuration and test-infrastructure files, none of this PR's files, so no catch-up merge was made.

**Where it ran.**
- Tests, fingerprints, IR, allocations and inference: cluster (Slurm), AMD Zen 3 nodes, BLAS at 1 thread.
- Paired timing: an exclusive node (Intel Xeon Silver 4116), one pinned core.
- Julia 1.10.12 and 1.13.3 throughout.
- ProximalBase pin `c123d56` (manifest tree `c2e2ddde…`), checked against the loaded source on every probe run.

### Verification

| Gate | Result at `7662585` |
|---|---|
| CI (all checks on the SHA) | **green**: full Julia 1 tier, Documentation, three benchmark analysis controls, test plan, required-jobs and merge gates, Codecov patch/project |
| Terminal review (Codex, GPT-6.1 Sol, high) | **PASS / NO BLOCKERS**, round 1, posted by Codex: [review](https://github.com/mlakolar/ProximalSolvers.jl/pull/299#pullrequestreview-5887395381); no inline findings |
| Pre-push battery (aqua, accelerated_pgd, minimal_core_characterization, core_regressions, core_contracts) | 11,893/11,893 (1.10.12); 11,911/11,911 (1.13.3) |
| Complete suite on the cluster | 14,458/14,459 (1.10.12); 14,476/14,477 (1.13.3). See the note below |
| Fingerprints, A/A at `3408e1f` | byte-identical on both versions |
| Fingerprints, `3408e1f` vs head | byte-identical with the removed `f_y` state-dump line excluded |
| Inference | equal to master on both versions |
| Warmed allocations | not higher anywhere |
| LLVM IR | only the expected differences |
| Paired timing | no slowdown; within the A/A spread |

**The one suite failure** is `test/benchmark_formal.jl:260`: `validate.py` needs a boolean `proximalsolvers_dirty`, which the cluster's synced tree cannot provide because it has no `.git`. It fails identically at `3408e1f` in the same setup, and CI's full tier passes it on a git checkout.

**Fingerprints.** The #279 harness was rebaselined against `3408e1f` and extended with 716 `ftol = 0` cases from #270:
- stalls from a zero start and from warm starts, and stalls until `maxiter`;
- `allow_f_increases` both ways, traces and callbacks;
- the four `f_residual` reporting branches;
- the zero spellings including `-0.0`, and the refusals of a positive `ftol` that rounds to 0.

Every new branch is reached on both `T` and both versions. Records cover every result field (bit-exact), traces with metadata, callbacks, `show_trace` output, exception types and messages, and the state after rollback. That is 13,572 records per tree: apg/Float32 3,422, apg/Float64 3,402, pgd/Float32 3,431, pgd/Float64 3,317. Each comparison runs base, control and head as fresh processes in one job on one node:
- `3408e1f` vs a second `3408e1f` (control): **identical** byte for byte on both versions.
- `3408e1f` vs head: 2,183 records differ raw. These are exactly the records that dump APG state, which no longer has `f_y`. With that line removed from both sides, the records are **identical** byte for byte on both versions.
- The `initial_state` + `_solve_gradient!` path reproduces `solve!` on 4,339 of 4,339 checked cases on all three trees.

**Allocations** (628 probe scenarios, warmed, same job): 519 unchanged and 109 lower, all APG Float64 solves (48 bytes less with the field gone). None is higher, and warmed `update_state!` bytes are unchanged at the measured update indices. The control is identical in all 628.

**Inference:** `Base.return_types` and `@inferred` of `solve!` and `_solve_gradient!` were checked for PGD/APG × Float32/Float64, with default options and with `ftol = 0`. Results equal master on both versions.

**LLVM IR** (75 normalized sections per version; the control is identical or the same modulo names). The differences:
- **PGD `update_state!`:** the `resize!`/length-check branches of `copy!` are gone (1.13: 414→388 lines for Float64).
- **`trace!`:** one compare and select fewer.
- **`_solve_gradient!`:** the `trace!` call passes fewer arguments.
- **APG `_prox_grad_step!`:** one field store fewer. The other APG functions differ only in struct field offsets.
- **`_state_norm`/`_state_normdiff` (APG):** the argument list only.
- **`_copy!`:** absent.

**Paired timing** (5 rotated fresh-process repetitions per side, A/A = `3408e1f` against itself):

| | Julia 1.13.3 | Julia 1.10.12 |
|---|---|---|
| Solve driver, 32 PGD/APG cases (both `T`; small/tall/wide/correlated; default and `ftol = 0`): geometric mean of per-case median ratios, A/B | 0.9984 | 0.9972 |
| same, A/A | 1.0015 | 0.9978 |
| cases with median ratio > 1.05 (A/B) | 0 | 0 |
| iterations and minimizer hashes equal on both sides | all 32 | all 32 |
| Formal harness (`PS_SUITE=extended PS_GROUPS=gradient`), timed cases | 2, both inconclusive (A/B 1.005 and 0.998; A/A 1.014 and 1.004) | 1, inconclusive (A/B 1.000; A/A 0.995) |

The formal harness times only cases that meet their accuracy targets. The other PGD/APG cases are `target_missed` identically on all three sides, so they are excluded rather than tied. With byte-identical results, accuracy is unchanged.

**Limitations.**
- Fingerprints, IR and allocations were measured on one CPU kind (Zen 3), timing on another (Skylake-SP). Neither covers other targets.
- The formal harness covers only 1–2 timed cases. The supplementary solve driver is the main timing evidence.

**Follow-ups:** none. The only failure found depends on the cluster environment, not on a defect.
