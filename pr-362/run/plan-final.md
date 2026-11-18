## Plan for PR A (R2 + R4 of #353)

Drafted by the orchestrator from the plan in the Stage 0 report of #353, revision r3 ([recommendations and sequence](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6968386639)) and the [maintainer decisions](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059). No separate critique: the report already passed an independent Codex review (r3, PASS / NO BLOCKERS), both changes exist as verified prototypes, and the maintainer approved them as specified.

This comment records only what the plan adds to the report.

### Base

`bb20b6a` (master). The audit was made at `dac9f4b`; since then `src/` changed only in `src/utils.jl` (#360), which neither change touches. The Stage 0 patch of R2 (`experiments/x2/x2b.patch` of `archive/issue-353-evidence-r3`) applies to `bb20b6a` unchanged.

### Commits and owned files

1. **R2, five deletions with bit-identical results** (report: −28 executable lines)
   - `src/blocks.jl`: delete `_maxabs_diff` and its export; its two callers (`g_residual` in `src/solvers/accelerated_proximal_gradient_descent.jl`, `_se_norm_diff` in `src/solvers/image_models.jl`) call `_norm_diff(x, y, Inf)`.
   - `src/solvers/image_models.jl`: `_frobenius_upper` sums through the existing `_sumsq64`; `_root_scale` takes `Float64(α)` and `_significand_exponent` goes.
   - `src/solvers/proximal_gradient_descent.jl`: the comment of `_sumsq64` (it now also serves Float64 arrays).
   - `src/cd/sqrtlasso.jl`: `_round_up(T, v)` becomes `T(v, RoundUp)`.
   - `src/cd/leastsquares.jl`: `_flat_column` and `_flat_group` become `all(iszero, …)` one-liners.
   - `test/cd_numerics.jl`: the BigFloat scales of one unit loop stay inside the range of Float64 (a scale outside that range is refused by `_check_loss_scale` before any solver arithmetic; only the direct unit call reached it).
   - `docs/src/developer/implementation-notes.md`: the two `_root_scale` passages that describe the 256-bit conversion.
2. **R4, folded scaled-norm kernels** (report: −17 executable lines), on top of R2
   - `src/solvers/image_models.jl`: `_se_norm(T, a, b = nothing)`, `_sumsq_scaled(a, b, m)` and `_se_norm_onepass(T, s, a, b = nothing)` replace the four norm and norm-of-difference functions; one caller inside `_bound_certified!`.
   - The proof comments of `_se_norm*` are re-read against the folded code, because the APG certificate cites them.

Not in this PR: `_sqnorm!` (#339), tier 2 of `response_scale`, proof-comment moves, anything in the square-root lasso step (R1), any ProximalBase change, the pin.

### Tests and checks (pre-registered)

| # | Check | Criterion |
|---|---|---|
| 1 | Test suite, full tier, Julia 1.10.13 and 1.13.4, at the R4 head | all pass; assertion counts equal to the base except for the one edited loop |
| 2 | Fingerprint matrix of Stage 0 (`fp_matrix.jl`: CD lasso, elastic net, group, square-root; PGD; APG; both element types; about 4,800 solves per Julia version), base against the R2 commit and against the R4 head, in one process | 0 mismatches in status, iterate bits, pass or iteration counts, objective, gap, thrown error type and message |
| 3 | Unit sweeps of the changed helpers against the deleted ones (`_norm_diff(·,·,Inf)` against `_maxabs_diff`, `T(v, RoundUp)` against `_round_up`, `_root_scale` on Float32, Float64, integer and Bool scales, `_frobenius_upper`, `_flat_*`, the folded `_se_norm*` against the four originals with NaN, Inf, zero and subnormal entries) | bit-identical, both Julia versions |
| 4 | Warmed allocations of `solve!` and of the changed helpers, base and head | equal |
| 5 | Paired in-process timing (Stage 0 harness `x2_paired.jl`: base, a second copy of the base as A/A control, head; 15 rounds; pinned to one core, one BLAS thread), Julia 1.10.13 (default and AVX2 target) and 1.13.4 | no case with a median ratio above 1.05 that the control does not also show; a flagged case is repeated |
| 6 | Executable-line count (`tools/count_loc.py` of the archive) | reported per commit against −28 and −17 |
| 7 | `comment_scan.py` on the added comment and documentation lines | each listed line narrowed or justified |

Required PR CI (Linux, Julia 1) picks the full tier for these source files by the repository's selection rule. Julia 1.10 and macOS are not in PR CI, so the full `Nightly` workflow is dispatched once on the branch at the final commit (Linux 1.10, Linux, macOS ARM and Windows with Julia 1), and the 1.10 suite also runs locally (check 1).

### Risks

- A `@simd` reduction that moves to another function can vectorize differently on another CPU. The fingerprints compare base and head in one process on one machine; the nightly dispatch is the cross-platform check, through the repository's own bitwise and certificate tests.
- `_root_scale` no longer accepts a scale outside the range of Float64. No public path passes one (`_check_loss_scale` admits Float32, Float64, fixed-width integers and Bool); the review is asked to confirm that from the code.

### Where things run

Tests, fingerprints and timings run locally (the cluster the workflow uses by default is unreachable; the Stage 0 references were produced on the same machine, which makes the comparison direct). Review: Codex gpt-6.1-sol, high, every implementation push, in parallel with CI.

**Plan approved in self mode**: the maintainer asked for this work to be completed and merged without their review of routine choices, once the gates hold (Codex PASS / NO BLOCKERS on the final commit, green required CI, no open review thread), except for the decisions that are always theirs: changes to supported numerical behavior, new refusal conditions, a reproducible slowdown above 5 %, the PB/PS boundary, new recovery machinery.
