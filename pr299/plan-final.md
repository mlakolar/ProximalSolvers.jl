## Plan

Drafted by the orchestrator from the approved PR 1 design in the [#279 memo](https://github.com/mlakolar/ProximalSolvers.jl/issues/279#issuecomment-6845277225). No separate critique: the maintainer approved the design and the change is small. The maintainer asked for this PR to be implemented, reviewed and merged once every gate passes. Numerical differences, unresolved findings and material performance regressions are escalated, not absorbed by widening the PR.

### Baseline (re-resolved)

- `master` = `3408e1f`. Since the research snapshot `782b74c` it has gained:
  - #286 (merged as `a214099`, closing #270): `ftol = 0` switches off the objective test; with `ftol = 0`, an unchanged iterate is a stall, not convergence. This is in `convergence_assessment`, `_unchanged`, `f_residual` and `ProximalOptions`.
  - #289 (CD `_sweep!`);
  - CI changes (#283, #291).
  - None of them touches the five sites below, apart from line shifts in `src/utils.jl`.
- ProximalBase pin: `c123d56ba1948e36a8fdbf183a9eea396a16e0d5` in `[sources]`. `Manifest-v1.10.toml` has `git-tree-sha1 = c2e2ddde114a1e7800358595193ee0869830180d`. Each probe checks the loaded source against these.
- Julia 1.10.12 and 1.13.3, both on a cluster (Slurm). Each record states the CPU kind and BLAS configuration (1 BLAS thread).

### Changes (at `3408e1f`)

1. **`_copy!`:** delete it (`src/blocks.jl:5,12`) and call `_copyto!` at `src/solvers/proximal_gradient_descent.jl:121,124`.
2. **APG `f_y`:** delete the field (`src/solvers/accelerated_proximal_gradient_descent.jl:82`) and its constructor argument (`:128`). Use a local in `_prox_grad_step!` (`:210,215`).
3. **`trace!`:** drop the always-true `iteration > 0` (`src/utils.jl:9`).
4. **`trace!` arguments:** `trace!(tr, state, iteration, options)` (`src/utils.jl:7`), with its only caller updated (`src/solve.jl:103`).
5. **State norms:** one `_state_norm(s::Union{ProximalGradientDescentState, AccProxGradDescentState}, x)` and one `_state_normdiff(s::Union{…})` in `src/utils.jl`. The APG copies (`accelerated…:292-293`) are deleted and the state argument is kept.

Owned files: `src/blocks.jl`, `src/utils.jl`, `src/solve.jl`, `src/solvers/proximal_gradient_descent.jl`, `src/solvers/accelerated_proximal_gradient_descent.jl`. No test, doc or Project/Manifest change is expected. A test that needs one goes to the orchestrator first.

**Excluded:**
- the eight `Blocks` forwards and the owner seams (#230);
- `_SE` and the APG certification, its bounds and guards;
- both line-search acceptance policies;
- the #270 stopping rules, including `convergence_assessment(state, f, g, options)`, which keeps its arguments;
- least-squares oracle code (#277);
- result types and public interfaces;
- any new abstraction.

### Verification

- **Pre-push battery** (cluster, 1.10.12 and 1.13.3): `aqua`, `accelerated_pgd`, `minimal_core_characterization`, `core_regressions`, `core_contracts`, plus the import check. CI then runs the PR tier at every pushed SHA.
- **Complete suite:** the full tier on both versions on the cluster at the final head, plus all CI checks green at that SHA.
- **Fingerprint rebaseline against `3408e1f`.** The #279 harness: 12,856 seeded PGD/APG cases, one fresh process per tree, byte comparison within one job and one node. It is extended with `ftol = 0` cases from #286: stalls in which the accepted iterate equals the previous one, `maxiter` reached under a stall, the `f_residual` reporting branches, PGD and APG, both `T`. Order of runs:
  1. A/A at `3408e1f`;
  2. A/B with the PR head.

  Records cover every result field, the traces with metadata, callbacks, `show_trace` output, exceptions and messages, and the state after rollback. The only expected difference is the removed `f_y` line in APG state dumps. The comparison reports raw bytes first, then with that line excluded. The old comparison against `782b74c` is not used as evidence for this base.
- **Compiler and memory:** inference (`Base.return_types`, `@inferred` on the four default cases), warmed allocations of `solve!` and `update_state!` on the probe paths, and normalized LLVM IR of the touched functions, each against `3408e1f`.
- **Paired timing with an A/A control,** because the generated code changes:
  - the formal harness (`benchmark/run.jl`, `PS_SUITE=extended PS_GROUPS=gradient`; fixed harness copy; before = `3408e1f`, after = head, A/A = `3408e1f` twice; pinned revisions; 1 thread on one pinned core; 5 rotated fresh-process repetitions; `compare.py`);
  - a supplementary paired PGD/APG solve driver (both `T`, default and `ftol = 0` options; 5 rotated fresh-process repetitions; A/A), as in #273/#274, because the formal harness times only cases that meet their targets.

**Pre-registered criteria:**
- **Fingerprints:** identical apart from the `f_y` dump line.
- **Inference:** equal.
- **Warmed allocations:** not higher.
- **Timing:** a case whose paired interval lies above 1 by more than 5% on an ordinary path, and which reproduces on a rerun, goes to the maintainer. Otherwise timing is reported as faster, slower or inconclusive against the A/A spread, never as "no regression".
- **CI and review:** all CI checks green, and a terminal review that passes without blockers at the final SHA.

### Review

Codex (GPT-6.1 Sol, high reasoning effort) reviews every implementation push from a detached checkout of the head. At the maintainer's request, Codex posts its findings directly on this PR as a COMMENT review whose first line is `**Verdict: REQUEST_CHANGES**` or `**Verdict: PASS / NO BLOCKERS**`. The orchestrator replies with a round comment per push.

### Archive

The probe scripts, exact revisions, reproduction instructions and verification summaries are preserved in a project artifact linked from the closing report on #279: a dedicated archive branch, or, if that is not permitted, collapsed sections in a PR comment. #279 is closed after the merge with a short report.

**Plan approved in self mode**: the maintainer asked for this issue to be completed and merged without their review, except for the decisions that are always theirs. Long-running checks run on a cluster.
