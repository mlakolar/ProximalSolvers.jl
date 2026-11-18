# Brief: ProximalSolvers.jl #353, R1 (square-root lasso range handling), task C: a candidate that keeps the range

You build and verify one candidate simplification of the square-root lasso coordinate step. The design below is
decided; evaluate it honestly. If it fails a criterion, say so with the evidence: a negative result is a valid
outcome, and the fallback (below) is then what gets implemented. Do not invent a different, larger design.

## Background (read first, all local, read-only)
- `S0=<STAGE0-RUN>` (Stage 0 audit material).
  `$S0/report/part-C-r1.md` is the Stage 0 recommendation R1 with its evidence; `$S0/experiments/x1/report.md` the
  experiment behind it; `$S0/experiments/x1/x1d-final.patch` the Stage 0 prototype (worktree `../ps-353-x1d`).
- Maintainer rulings on R1 (https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059):
  **no new refusal**: the Stage 0 prototype refused Float64 inputs that master accepts (non-flat columns with norm
  below about `1e-146·√n`, nonzero residuals below that scale, residuals above about `1.34e154`). "Preserve
  currently supported successful behavior, including exact-fit and zero-residual cases. […] Investigate whether the
  simplified formula can retain the existing numerical range with inexpensive, localized handling. Do not introduce
  a general fallback or complicated recovery framework." And the stopping rule: if a straightforward implementation
  cannot preserve behavior and performance together, the larger simplification is abandoned and only the duplicate
  `_scaled_norm` is deleted.
- The code: `src/cd/sqrtlasso.jl` at master `bb20b6a36cc040f7f00088919e331dce27cf257b`. Line numbers there:
  `_scaled_norm` 89–102 (callers: `_prepare!` line 57, `_sqrt_offrange_step` line 274); `_clean_sum` 137;
  `coordinate_step!` 150–165; `_sqrt_minimizer` 178–198 (the fast path, with the band test at 196–197);
  `_sqrt_band_step` 202–205; `_sqrt_threshold64` 210–217; `_sqrt_offrange_step` 241–279 with its long comment
  218–240. `test/sqrt_lasso.jl` lines 280–330 hold the error analysis of the step and `step_bound`/`step_excess`.

## The candidate ("K") to build
Idea: master has three out-of-line pieces for inputs outside the fast path (`_sqrt_band_step` +
`_sqrt_threshold64` for a threshold outside the normal range of T, `_sqrt_offrange_step` for sums outside the range
of `_clean_sum`, and `_scaled_norm` inside it). They can be one cold step, because after scaling the column and the
residual by powers of two the scaled problem is always in range, and there the plain formula needs no band test.

1. **The fast path of `_sqrt_minimizer` stays byte for byte** (lines 178–196 and the `prox_block` branch): the
   same tests, the same arithmetic, the same `prox_block(m.gt, c, k, γ)` call. Ordinary inputs then give
   bit-identical results and (apart from the cold call sites) the same machine code. The three exits (line 181,
   line 190 and the band branch of line 197) all call the one cold step with the signature
   `(m, old, k)`.
2. **One cold step**, `@noinline`, for both element types, in Float64, replacing `_sqrt_offrange_step`,
   `_sqrt_band_step` and `_sqrt_threshold64`:
   - `ex`, `er` = exponents of the largest magnitudes of the column and the residual (as master, lines 245–260);
     the scaled column `x̃ = X_k 2^-ex` and the scaled residual `s = r 2^-er` (into `m.res64`, as master; you may
     use `m.rowmag64` for `x̃` if that simplifies the code: check that no caller relies on its contents across a
     coordinate step, it is the certificate's work vector);
   - the exact early returns of master kept: `λ̃ ≥ √ã → 0` (with `λ̃ = λ 2^-ex`, tested before the residual is
     looked at), and `r = 0 → old`;
   - then the in-range formula on the scaled quantities, all sums between 1 and 4n so no band can occur:
     `q̃ = b̃/ã`, `d̃² = ‖s‖² − b̃ q̃`, recomputed as `‖s − q̃ x̃‖²` where it is below `‖s‖²/16`,
     `τ̃ = (λ̃/√ã)·(d̃/(√(√ã − λ̃)·√(√ã + λ̃)))`;
   - unscaling by one `ldexp` each: the step is `shrink(old + T(ldexp(q̃, er − ex)), T(min(ldexp(τ̃, er − ex), floatmax(T))))`
     (the cap as in master's `_sqrt_band_step`, for the same reason).
   Master recomputes a cancelled `d̃` with `_scaled_norm`, which rescales by the largest entry of the difference and
   so keeps `d̃` relatively accurate even far below `‖s‖ 2^-511`. A plain sum of squares of the difference loses
   that, with an absolute error of the order `√n 2^-537` in the normalized units. Master's own analysis (comment
   lines 231–240 and the test comment lines 300–304) says absolute errors of that size in `d` are covered by the
   step bound. Decide which form the candidate uses: the plain sum if the bound of `test/sqrt_lasso.jl` holds with
   it over your sweeps (then `_scaled_norm` has no caller left in the step), otherwise the existing
   `_se_norm(Float64, ·)` of `src/solvers/image_models.jl` (returns an `_SE` with fields `s`, `e`; it is already
   used by `src/cd/leastsquares.jl:223`). Do not keep `_scaled_norm`.
3. **`_scaled_norm` is deleted.** Its other caller, `_prepare!` line 57–58, becomes
   `ny = _se_norm(Float64, m.ls.y); m.floor64 = 16eps(T)*ldexp(ny.s, ny.e)` (this is the Stage 0 "R1-min" change;
   `_se_norm` returns `nothing` for a non-finite entry: check what `_prepare!` can receive and handle it so that
   the outcome for a non-finite `y` is what master gives).
4. Comments: the long comment of `_sqrt_offrange_step` and the comment of `_sqrt_minimizer` are rewritten for the
   one cold step, keeping the error statements that remain true (the η/2 scaling errors, the examples) and
   dropping what described deleted code. The comments in `test/sqrt_lasso.jl` that name the deleted helpers
   (lines 297–298, 354, 361) are updated to the new name. The struct comment (lines 13–15) too.

**Fallback ("R1-min"), if K fails any criterion below and no small fix exists:** item 3 only (plus `_se_norm` in
place of `_scaled_norm` at line 274). Report which criterion failed, with a reproducer.

## Acceptance criteria (all on Julia 1.10.13 `julia +lts` and 1.13.4 `julia +release`, Float32 and Float64)
A. **No domain change.** For every input, the outcome class of a coordinate step and of a whole `solve!` is the
   one master gives: a returned finite step where master returns one; the same `ArgumentError` (type and message)
   where master throws; `converged`/certified, uncertified, or stopped at `maxpasses` as on master. In particular
   the three Float64 families the Stage 0 prototype lost, and the two counterexamples of the Stage 0 review
   (`$S0/experiments/review-r1/verify_findings.jl`: a tiny column at a zero residual, e.g.
   `X = fill(1e-150, 2, 1)`, `y = 0`, `λ = 1e-151`, zero start, which master solves with `gap = 0`; and the exact
   fit with a nonzero start), keep master's outcome.
B. **Ordinary path bit-identical.** Wherever master's step does not leave the fast path, the candidate's step is
   `===` master's; whole solves on ordinary data give identical iterates, pass counts, statuses and gaps. Reuse
   Stage 0's whole-solve corpus (`$S0/experiments/x1/exp3_solves.jl`, 748 configurations) and its `cd-sqrt` family
   of the fingerprint matrix (`$S0/experiments/x2/fp_matrix.jl`).
C. **Cold path within the step bound.** Where a step takes the cold path, the candidate's value satisfies
   `step_excess ≤ step_bound` of `test/sqrt_lasso.jl` against the BigFloat reference (reuse
   `$S0/experiments/x1/exp2_families.jl` and its families `far`, `thresh`, `corner`, `band`, `sub_lam`,
   `huge_edge`, `wide_full`, `tiny_d`, `near_parallel`; master and candidate in one process on identical inputs).
   Report, per family and type: cases, worst ratio excess/bound for master and candidate, how many cases differ
   between the two and by how much (in ulps of the step, and the largest relative difference), and every case
   where one is finite and the other is not or one throws and the other does not (there must be none).
D. **A boundary-targeted search**, not only random sweeps (Stage 0's random sweeps missed two accepted inputs that
   only a boundary search found). Enumerate, for both types and n ∈ {1, 2, 3, 5, 30}: `a` and `ρ²` at, one ulp
   below and one ulp above the `_clean_sum` threshold `n·floatmin/eps`, and at `floatmax` and overflowing; each of
   the three band conditions (`p`, `γ`, `γλ` at `floatmin`, `floatmax`, just inside and just outside); `λ` at `ra`,
   `prevfloat(ra)`, subnormal, the smallest subnormal; `r = 0`; `r` exactly parallel to `X_k` (`d = 0`); `old` at 0,
   ±floatmax, subnormal; exponent gaps `er − ex` at the extremes of each type (so that `ldexp(q̃, er − ex)` and
   `ldexp(τ̃, er − ex)` overflow, land in the subnormal range, or underflow to 0); columns and residuals with
   entries of both extreme scales in one vector. For each: outcome class equal to master's, and the bound of C
   where both return a value. Note that Julia 1.10's `ldexp` truncates instead of rounding when the result is
   subnormal (ProximalBase issue 896); master has the same exposure in `_sqrt_threshold64` and line 278. The
   criterion on 1.10 is the same step bound (its `4 (ra + λ) η` term is what covers subnormal results); report the
   worst ratio there separately.
E. **`test/sqrt_lasso.jl` passes with no assertion changed** (1411 of 1411 on master), plus `cd_numerics`,
   `core_regressions`, `core_contracts`, `stopping_scale` unchanged.
F. **Allocations:** a warmed `solve!` and a warmed cold step allocate what master's do (0 bytes for the step).
G. **`floor64`:** over Stage 0's corpus (`$S0/experiments/x1/t3_floor64.jl`), report the largest relative change
   and every solve whose outcome class or pass count changes (Stage 0 found none in 748 solves and last-bit moves
   in 2 of 456 targeted tiny-scale solves).
H. **Size:** executable lines of `src/cd/sqrtlasso.jl` before and after, with `python3 $S0/tools/count_loc.py`
   (read its usage), per function.

## Worktree, branch, base
- Worktree `<WORK>/ProximalSolvers.jl-issue353-r1` on branch `fix/issue-353-r1`, at the base
  `bb20b6a36cc040f7f00088919e331dce27cf257b`. Work only there. A read-only base worktree for comparisons is
  `<WORK>/ProximalSolvers.jl-issue353-base` (never edit it). Never touch the main checkout
  `<WORK>/ProximalSolvers.jl`, `ProximalSolvers.jl-issue353` (another agent's PR),
  `ProximalSolvers.jl-issue353-r1-perf` (another agent measures the Julia 1.10 speed of the fast path there; it
  owns the question whether the fast path formula itself can be simplified, you do not change the fast path), or
  the `ps-353*` worktrees (reference only).
- Owned files: `src/cd/sqrtlasso.jl`; comments only in `test/sqrt_lasso.jl`. Nothing else. No dependency, no
  `Project.toml` or manifest edit, no ProximalBase change.
- Git: commit explicit paths; messages describe the change only (no agent, round, reviewer or infrastructure
  words, no `Co-Authored-By`). Commit the candidate when it passes your checks (or the best state with the failing
  criterion named). Do not push; do not open a PR.

## Running things
- Probes go under `<WORK>/ProximalSolvers.jl-issue353-r1/.codex-orchestrator/probes/`.
  Load master and candidate in one process as two modules, e.g.
  `module BaseMod; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end`
  and the same for the candidate's `src` (the Stage 0 scripts `trees.jl`/`x1lib.jl` show the pattern; adapt their
  hard-coded paths in your copies).
- Probe command, per Julia version (foreground, Bash timeout at most 600000 ms; split long sweeps into several
  calls, never a detached job):
  `python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py julia --worktree <WORK>/ProximalSolvers.jl-issue353-r1 --run-dir <WORK>/ProximalSolvers.jl-issue353-r1/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf --where local --versions <lts|release> --tag probe --name <name> --allow-dirty -- --project=. .codex-orchestrator/probes/<script>.jl [args]`
  (output in that run dir's `evidence/<name>-<version>.out`; on 1.13 first run a one-line probe with
  `using Pkg; Pkg.instantiate()`).
- Test files, per version, at a commit (it refuses a dirty worktree), under the run's lock:
  `flock -w 480 <WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/evidence/.heavy.lock python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py tests --worktree <WORK>/ProximalSolvers.jl-issue353-r1 --run-dir <WORK>/ProximalSolvers.jl-issue353-r1/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf --where local --versions <lts|release> --tag impl --tier none --jobs 2 --name <name> -- sqrt_lasso`
  (if the lock times out, wait and repeat). Last line `BATTERY PASS` or `BATTERY FAIL`.
- One Julia process at a time from you; other agents share the machine. Truncate long outputs.

## Comments and documentation
Every comment line you add says what the code does under a stated condition, not more: no absolute word (every,
never, always, only, exactly, whatever, no longer) the code does not guarantee; an "X, so Y" is checked where Y
fails; numbers and examples are recomputed from the code; no history ("previously", "Stage 0", "prototype").
Run `python3 -I <SKILLS>/github-issue-workflow/scripts/comment_scan.py bb20b6a36cc040f7f00088919e331dce27cf257b HEAD`
after committing and answer each listed line.

## Hand-back (your final message, returned as text; do not write it to a file)
Headings: Verdict (K meets A–H / K fails criterion X / fallback applied); What changed (per function, with the
final code of the cold step quoted); Commit SHA and `git status --porcelain`; Evidence per criterion A–H (counts
and worst cases pasted from outputs, both Julia versions, both types; the probe script names); Differences from
master on cold inputs (distribution); The choice for the cancelled `d̃` and why; Deviations from this brief;
**Not run** (each item with the reason, or "none"); Open questions. End with `Status: COMPLETE` or
`Status: INCOMPLETE`.
