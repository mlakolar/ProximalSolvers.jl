# ProximalSolvers.jl #353: evidence of the implementation phase

Archive of the run that followed the Stage 0 audit of issue #353
(https://github.com/mlakolar/ProximalSolvers.jl/issues/353). Not part of the package; nothing here is built or tested.
The Stage 0 evidence itself is on the branches `archive/issue-353-evidence`, `-r2` and `-r3`, which this branch does not change.

- Base of the work: ProximalSolvers.jl `bb20b6a36cc040f7f00088919e331dce27cf257b` (master when the phase started);
  PR #362 was merged as `6e583f736422dfaf96018d47dc76eadf19793bec`.
- Machine: Intel Core i5-13600K, Linux x86-64, Julia 1.10.13 and 1.13.4, one BLAS thread and one pinned core in the
  timings. Every timing is paired in one process with a control (a second compiled copy of the base); the machine was
  shared during the runs.
- Local paths are replaced by placeholders: `<WORK>` (the directory holding the worktrees), `<STAGE0-RUN>` (the run
  directory of the Stage 0 audit), `<DEPOT>`, `<SKILLS>`, `<TMP>`, `<HOME>`. Scripts need these set back before they run.

## Layout

- `pr-362/`: PR #362 (R2: five bit-identical deletions; R4: folded scaled-norm kernels; merged).
  `run/plan-final.md`, `run/round1.md`, `run/round2.md`, `run/final.md` are the comments posted on the PR;
  `run/agents/impl-A/` the implementer's brief and hand-back; `run/reviews/` the Codex briefs and review payloads;
  `run/evidence/` the test, fingerprint (`r2-fp-*`, `r4-fp-*`), unit-sweep, allocation and timing outputs
  (`timing/pra-*`), the full-tier runs (`full-*`) and the reproducer posted on #352 (`repro352-*`); `probes/` the scripts.
  `run/decisions-353.md`, `run/post-352.md`, `run/post-339.md`, `run/post-pb698.md` are the comments posted on the issues.
- `r1-investigation/`: recommendation R1 (square-root lasso range handling). `outcome-comment.md` is the result posted
  on #353.
  - `candidate-K/`: the candidate that keeps master's fast path and replaces the three out-of-line range helpers by
    one rescaled step (`candidate-K.patch`, against `bb20b6a`; not merged), its verification (`probes/`, `evidence/`,
    `agent/handoff.md`) and the measurement of its cost on solves that take the band exit (`evidence/band-timing-*`,
    `probes/band_timing.jl`).
  - `speed-diagnosis/`: the diagnosis of the Julia 1.10 slowdown of the Stage 0 prototype. `agent/handoff.md` is the
    report; `variants/*.patch` are the single-factor variants as patches of `src/cd/sqrtlasso.jl` against `bb20b6a`;
    `out/r1d-bandfree-fastpath.patch` is the band-free fast path that passes the timing gate (not merged);
    `out/q1-*` (the shape of candidate K), `out/q2*` (single-factor runs), `out/q3-*` (the band-free candidate):
    `.tsv` raw, `.table.txt` and `.summary.txt` per cell, `.load` the load average, `.s`/`.ll` native code and IR.
- `pr-365/`: PR #365 (the fallback "R1-min": `_scaled_norm` replaced by `_se_norm`). `run/plan-final.md`,
  `run/round1.md` and `run/decision-365.md` are the comments posted on the PR; `run/reviews/codex-r1/` the review that
  found the change of outcome at the tie of the tightening floor; `run/evidence/floor-tie/` the measurements of that
  tie (`tie2-*`: base against head at tolerances on and off the tie; the other files: one tree under different
  compilation settings); `run/evidence/m-*` the checks at the merge commit `4c2efd7`; `run/evidence/timing/` the paired
  timings and the recheck of the one flagged group; `probes/` the scripts (`base_instr.patch`: the counters added to a
  copy of the base for the branch counts).

`SHA256SUMS` lists every file except itself.
