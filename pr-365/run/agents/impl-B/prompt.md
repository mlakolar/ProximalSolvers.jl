# Implementer brief: ProximalSolvers.jl #353, PR B (https://github.com/mlakolar/ProximalSolvers.jl/pull/365)

You implement an already approved plan. Do not redesign it and do not enlarge it. Read it first:
- the plan as posted: https://github.com/mlakolar/ProximalSolvers.jl/pull/365#issuecomment-6970475353
  (local copy: `<WORK>/ProximalSolvers.jl-issue353-2/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf-b/plan-final.md`)
- why only this small change is made: https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6970454563

## Goal in one paragraph
One commit that deletes `_scaled_norm` from `src/cd/sqrtlasso.jl` and makes its two callers use the existing
`_se_norm(Float64, v)` of `src/solvers/image_models.jl` (it returns an `_SE{Float64}` with fields `s` and `e`, the
norm being `s·2^e`; `_se_zero` for a zero vector; `nothing` when an entry is not finite). Nothing else in the
square-root lasso step changes: the fast path of `_sqrt_minimizer`, `_sqrt_band_step`, `_sqrt_threshold64` and the
scaling logic of `_sqrt_offrange_step` stay exactly as they are. Outcome classes do not change; values may move
in the last bits only where the changed norm is used (the tightening floor, and the recomputed distance of an
out-of-range step).

## Worktree, branch, base
- Worktree `<WORK>/ProximalSolvers.jl-issue353-2` (`$WT`) on branch `fix/issue-353-scaled-norm`,
  HEAD `b1efecc80032f6e22193d6556adff42fa1ecf284` (an empty bootstrap commit), base
  `bb20b6a36cc040f7f00088919e331dce27cf257b`. Work only there.
- Read-only base worktree for comparisons: `<WORK>/ProximalSolvers.jl-issue353-base` (never
  edit it). Never touch the main checkout `<WORK>/ProximalSolvers.jl` or any other worktree.
  `ProximalSolvers.jl-issue353-r1` holds a larger candidate that was NOT approved; you may copy its probe scripts
  (below) but none of its source changes.
- Git: commit explicit paths (`git add <paths>`, never `-A` or `.`). The commit message describes the change only:
  no round numbers, reviewer or agent names, `Co-Authored-By` lines or infrastructure. Do not push, force-push,
  merge, mark ready or touch the PR: commit and hand back.

## Owned files
`src/cd/sqrtlasso.jl`. Comments only in `test/sqrt_lasso.jl`, and only if a comment there names `_scaled_norm`
(check with grep; at the base none does). Nothing else: no other source file, no `Project.toml`, no manifests,
no docs unless `grep -rn "_scaled_norm" docs` finds a passage that would become false (then say so in the
hand-back and fix that passage only). Adding a dependency is forbidden.

## What to build (line numbers at the base)
1. Delete `_scaled_norm` and its comment (`src/cd/sqrtlasso.jl` lines 86–102).
2. `_prepare!` (lines 57–58): `ny, ey = _scaled_norm(m.ls.y, n)` / `m.floor64 = 16eps(T)*ldexp(ny, ey)` become
   `ny = _se_norm(Float64, m.ls.y)` / `m.floor64 = 16eps(T)*ldexp(ny.s, ny.e)`. `_se_norm` returns `nothing` for a
   non-finite entry: establish from the code (`src/solve.jl`, the gates of the square-root loss) that `solve!`
   refuses a non-finite `y` before the model is prepared, and state that condition in a short comment on the
   line. Add no refusal and no extra branch for that case (the base returns an infinite or NaN floor for a
   non-finite `y` given to `_prepare!` directly; with the change such a direct call fails on `nothing`; say so
   in the hand-back). If you find a public path on which a non-finite `y` reaches `_prepare!`, stop and report
   it instead of committing.
3. `_sqrt_offrange_step` (line 274): `ds, ed = _scaled_norm(s, n)` becomes a call of `_se_norm(Float64, s)` whose
   fields give `ds` and `ed` (the entries of `s` are finite there: say in your hand-back why). `s` is `m.res64`,
   whose length is `n`.
4. Comments: the passages that describe `_scaled_norm` (in the long comment of `_sqrt_offrange_step`, around
   lines 226–237: "formed again as ‖s − q̃ x̃‖² by `_scaled_norm` (which scales by the largest entry of the
   difference)", "d also through the scaling inside `_scaled_norm`", and "the largest magnitude of its normalized
   representation is in [1, 2)") are made true of `_se_norm` (it divides by the largest magnitude, so the scaled
   entries have magnitude at most 1 and the significand of the result is in [1, 2)). Read `_se_norm` and
   `_sumsq_scaled` in `src/solvers/image_models.jl` before you write, and re-derive any number you keep. Do not
   rewrite comments that remain true.
5. `grep -rn "_scaled_norm" src test docs benchmark examples` must find nothing afterwards.

## Tests
No new test file and no changed assertion. `test/sqrt_lasso.jl` must pass as it is (1411 assertions at the base).

## Running things
- Julia: `julia +lts` is 1.10.13, `julia +release` is 1.13.4. Local, foreground only, each Bash call with an
  explicit timeout (at most 600000 ms). Never start a detached or background job. Split a long step over calls
  (one Julia version per call); if it still cannot finish, hand back the exact command and list it under "Not run".
  One Julia process at a time from you.
- **Test files** (at a commit; it refuses a dirty worktree), per version, under the run's lock:
  `flock -w 480 <WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/evidence/.heavy.lock python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py tests --worktree <WORK>/ProximalSolvers.jl-issue353-2 --run-dir <WORK>/ProximalSolvers.jl-issue353-2/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf-b --where local --versions <lts|release> --tag impl --tier none --jobs 2 --name <name> -- sqrt_lasso cd_numerics core_regressions core_contracts stopping_scale accelerated_pgd`
  Last line `BATTERY PASS` or `BATTERY FAIL`; paste its summary.
- **Probes** (scripts under `$WT/.codex-orchestrator/probes/`), per version:
  `python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py julia --worktree <WORK>/ProximalSolvers.jl-issue353-2 --run-dir <WORK>/ProximalSolvers.jl-issue353-2/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf-b --where local --versions <lts|release> --tag probe --name <name> -- --project=. .codex-orchestrator/probes/<script>.jl [args]`
  (output in that run dir's `evidence/<name>-<version>.out`; on 1.13 first run a one-line probe with
  `using Pkg; Pkg.instantiate()`).
- **Probe scripts to reuse.** `<WORK>/ProximalSolvers.jl-issue353-r1/.codex-orchestrator/probes/`
  holds the scripts that verified the larger candidate against the same base: `trees.jl`/`r1lib.jl`/`x1lib.jl`
  (loading base and candidate as two modules in one process), `exp_b1.jl` (fast-path steps bit for bit),
  `exp2c.jl` with `exp2_fams.jl` (step families against a BigFloat reference and `step_bound`), `d_all.jl` with
  `exp_d.jl` (the boundary-targeted set), `exp_b2.jl` (748 whole solves), `tiny_solves.jl` (454 tiny- and
  huge-scale solves), `fp_sqrt.jl` with `fp_lib.jl` (158 square-root fingerprints), `floor64.jl`, `alloc.jl`,
  `verify_a.jl`, `band_timing.jl` (a paired timing pattern). Copy what you need into your own probes folder and
  change the candidate tree path to `<WORK>/ProximalSolvers.jl-issue353-2/src` (the base
  stays `<WORK>/ProximalSolvers.jl-issue353-base/src`). Read each script before trusting
  it: say in the hand-back what each one compares.
- Truncate long outputs.

### Checks (plan numbers), both Julia versions, at your commit
1. Fast-path steps bit-identical (`exp_b1`).
2. Out-of-range steps: `exp2c` families and the boundary set `d_all`: 0 above the bound, 0 outcome-class changes;
   report per family and type how many steps differ from the base in bits and the largest ulp and relative
   difference. Add a targeted set for the one branch that changed: residuals nearly parallel to the column at
   tiny and huge scales so that `_sqrt_offrange_step` recomputes the distance (`ds2 < ss/16`), including an
   exactly parallel residual (distance 0), a distance far below `2^-511` of the residual, n ∈ {1, 2, 3, 5, 30,
   2000}, both types. Count how many cases reached the recompute branch (derive it from the inputs with the
   base's formulas, or instrument a copy of the base tree under your probes folder; never the worktree).
3. Whole solves: `exp_b2` (748), `tiny_solves` (454), `fp_sqrt` (158): outcome class and pass count equal in
   every solve; report the solves whose iterates or gaps differ in bits, with the largest relative difference.
4. `floor64`: largest relative change; solves whose outcome or pass count changed (expected none).
5. The test files above; counts pasted per version.
6. Allocations (`alloc.jl`): equal to the base, including a warmed out-of-range step through the recompute branch.
7. Timing: do not run the reported timing (the orchestrator runs it alone). Prepare `timing_b.jl` in your probes
   folder from the pattern of `band_timing.jl`: base, a second base copy and the head in one process, 9 or more
   rounds rotated, minimum over batches per round; cells: ordinary square-root solves to convergence for
   (n, p) ∈ {(30, 10), (200, 40), (40, 120), (1000, 100)}, Float32 and Float64, plus solves whose visits go
   through `_sqrt_offrange_step` (tiny-scale data), with and without a nearly parallel residual so that the
   recompute branch runs. Smoke-run it with 1 round on `+release` and give the exact command.
8. Lines: `python3 <STAGE0-RUN>/tools/count_loc.py src/cd/sqrtlasso.jl`
   at base and head (expected 310 → 297).
9. `python3 -I <SKILLS>/github-issue-workflow/scripts/comment_scan.py bb20b6a36cc040f7f00088919e331dce27cf257b HEAD`
   after committing; answer each listed line.

## Comments and documentation
Every comment line you add or change says what the code does under a stated condition, not more: no absolute word
(every, never, always, only, exactly, whatever, no longer) the code does not guarantee; an "X, so Y" is checked
where Y fails; numbers are recomputed from the code; no history ("previously", "Stage 0", "was").

## Hand-back (your final message, returned as text; do not write it to a file)
Headings: What changed (the final code of the two call sites quoted); Commit SHA and `git status --porcelain`;
Why `y` and `s` are finite at the two calls (with the code lines); Commands run with results (counts pasted, each
version); Evidence for checks 1–9; Deviations from the plan; **Not run** (each item with the reason, or "none");
the timing command for the orchestrator; Open questions. End with `Status: COMPLETE` or `Status: INCOMPLETE`.
