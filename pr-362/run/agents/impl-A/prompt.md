# Implementer brief: ProximalSolvers.jl #353, PR A (https://github.com/mlakolar/ProximalSolvers.jl/pull/362)

You implement an already approved plan. Do not redesign it. Read it first:
- the plan as posted: https://github.com/mlakolar/ProximalSolvers.jl/pull/362#issuecomment-6969698187
  (local copy: `<WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/plan-final.md`)
- the maintainer decisions: https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059
- the Stage 0 report sections you implement (local files, read-only):
  `S0=<STAGE0-RUN>`
  `$S0/report/part-C-rest.md` (R2, R4), `$S0/experiments/x2/report.md` (how the prototypes were verified).

## Goal in one paragraph
Two commits on the PR branch. **Commit 1 (R2):** five deletions whose results are bit-identical to the base on every
input a public call can pass. **Commit 2 (R4):** the two parallel scaled-norm kernel families of
`src/solvers/image_models.jl` folded into one, bit-identical. No public API change, no change of stopping or
convergence statuses, no new abstraction layer, useful mathematical comments preserved. Both changes exist as
verified Stage 0 prototypes; your job is to port them to the current master, verify them again, and commit.

## Worktree, branch, base
- Worktree `<WORK>/ProximalSolvers.jl-issue353` (call it `$WT`) on branch `fix/issue-353`,
  HEAD `f8691e92deb46bf946c84d49a6cb8266076da256` (an empty bootstrap commit), base
  `bb20b6a36cc040f7f00088919e331dce27cf257b` (master).
- A read-only base worktree is at `<WORK>/ProximalSolvers.jl-issue353-base` (detached at the
  base). Never edit it. Never touch the main checkout `<WORK>/ProximalSolvers.jl` or any
  other worktree (`ps-353*`, `ProximalSolvers.jl-issue353-r1*` belong to others; `ps-353*` and `$S0` are read-only
  reference material).
- Git: commit explicit paths (`git add <paths>`, never `-A` or `.`). Commit messages describe the change only: no
  round numbers, reviewer names, agent attribution, `Co-Authored-By` lines or infrastructure. Do not push,
  force-push, merge, mark ready or touch the PR: commit and hand back.
- Forbidden: every file not listed under "Owned files"; `Project.toml`, manifests, `benchmark/`, CI workflows.
  Adding a dependency is forbidden.

## Owned files
Commit 1 (R2): `src/blocks.jl`, `src/solvers/image_models.jl`, `src/solvers/accelerated_proximal_gradient_descent.jl`,
`src/solvers/proximal_gradient_descent.jl` (the comment line of `_sumsq64` only), `src/cd/sqrtlasso.jl`
(`_round_up` and its one caller only), `src/cd/leastsquares.jl` (`_flat_column`, `_flat_group` only),
`test/cd_numerics.jl` (one loop, below), `docs/src/developer/implementation-notes.md` (the two `_root_scale`
passages, below).
Commit 2 (R4): `src/solvers/image_models.jl`.
Probe scripts go under `$WT/.codex-orchestrator/probes/` (not under git).
Anything else that must change: stop and say so in your hand-back; do not edit it.

## What to build

### Commit 1: R2
The Stage 0 patch applies to the base unchanged (checked): from `$WT`,
`git apply --directory=src $S0/experiments/x2/x2b.patch`. Read the result against these five items; they are the
whole change in `src/`:
1. `src/blocks.jl`: `_maxabs_diff` and its export are deleted. Its two callers use `_norm_diff(x, y, Inf)`
   (`_norm_diff` is defined in `src/blocks.jl` on ProximalBase's public `norm_diff`): `g_residual` in the APG file
   and `_se_norm_diff` in `image_models.jl`.
2. `src/solvers/image_models.jl`, `_frobenius_upper`: the Float64 summation loop becomes `s = _sumsq64(X)`
   (`_sumsq64` is in `src/solvers/proximal_gradient_descent.jl`; its comment line is widened by the patch).
3. `src/cd/sqrtlasso.jl`: `_round_up(T, ratio)` becomes `T(ratio, RoundUp)` and `_round_up` is deleted.
4. `src/cd/leastsquares.jl`: `_flat_column(m::LSModel, k::Int) = all(iszero, view(m.X, :, k))` and
   `_flat_group(ls::LSModel, idx) = all(j -> _flat_column(ls, Int(j)), idx)`.
5. `src/solvers/image_models.jl`: `_significand_exponent` is deleted; `_root_scale` takes `a = Float64(α)` and
   `s, e = significand(a), exponent(a)`, with the comment the patch gives.

Outside `src/`:
- `test/cd_numerics.jl`, in the testset "the response scale over the ranges of y and the loss scale": the BigFloat
  loop `for j in (-1500, -300, -1, 0, 1, 300, 1500)` becomes `for j in (-1000, -300, -1, 0, 1, 300, 1000)`, with a
  short comment that says why (a scale outside the range of Float64 is not supported by `_root_scale`; the solvers
  refuse non-machine scale types before it, in `_check_loss_scale`). **Nothing else in that testset changes**: the
  line `@test ways == Set([1, 2, 3])` stays as it is (Stage 0 also has a six-item prototype that deletes "tier 2"
  of `response_scale`; that deletion is deferred and must NOT be ported. If you look at
  `$S0/experiments/x2/test_edits/cd_numerics.x2.jl`, it contains that deferred edit; take only the `j` loop from it).
  Before editing, check with the base that the testset still reaches all three `ways` with the narrower loop.
- `docs/src/developer/implementation-notes.md`: two passages describe the 256-bit BigFloat conversion of
  `_root_scale` (the sentence "`_root_scale` converts an integer or `Bool` scale at a scoped precision of 256 bits."
  near line 69, and the sentences from "`√α` (`_root_scale`) is formed from …" to "… nor `α`'s range limits it."
  near lines 360–364). Rewrite them to what the code now does: `α` is rounded once to Float64 (exact for a Float32
  or Float64 scale, for a Bool and for an integer of magnitude at most 2^53; an integer beyond that is rounded
  once), its significand and exponent are taken there, and a scale outside the range of Float64 is not supported
  by `_root_scale`. Check each of these statements against the code and Julia's conversion rules before you write
  it; change no other documentation.
- `grep -rn "_maxabs_diff\|_round_up\|_significand_exponent" src test docs benchmark examples` must find nothing
  afterwards.

### Commit 2: R4
The Stage 0 prototype is `$S0/experiments/x2/sc_on_x2.patch` (a diff of `src/solvers/image_models.jl` between two
local trees, so it does not apply with plain `git apply`; its hunks are against a tree that equals your commit 1 in
that file; apply it with `patch -p0`-style path fixing or by hand, then diff your file against
`$S0/experiments/x2/sc_tree/src/solvers/image_models.jl` to confirm they are equal in the folded functions).
Content:
- `@inline _diff(a, b, i) = a[i] - b[i]` and `@inline _diff(a, ::Nothing, i) = a[i]`;
- `_sumsq_scaled(a, b, m)` (one loop over `eachindex(a)` using `_diff`) replaces `_sumsq_scaled(v, m)` and
  `_sumsq_scaled_diff(a, b, m)`;
- `_se_norm(::Type{T}, a, b = nothing)` replaces `_se_norm(T, v)` and `_se_norm_diff(T, a, b)`;
- `_se_norm_onepass(::Type{T}, s, a, b = nothing)` replaces `_se_norm_onepass(T, s, v)` and
  `_se_norm_diff_onepass(T, s, a, b)`; the one caller in `_bound_certified!` changes its name.
- Callers outside the file (`src/solvers/accelerated_proximal_gradient_descent.jl`, `src/cd/leastsquares.jl`,
  `test/accelerated_pgd.jl`) call the two-argument and three-argument forms that keep their names, so they do not
  change; confirm with grep.
- **Proof comments.** The APG certificate cites the comments of `_se_norm*` (the bound γ_{n+4}, the
  `4 length(v) floatmin(T)` condition, "nothing when an entry is not finite"). Re-read each comment against the
  folded code and make it true for both forms (norm and norm of a difference). One point to check and state
  explicitly in your hand-back: the base's `_se_norm_diff` returns `nothing` when the scaled sum `s` is not finite;
  the folded function has no such test. Decide from the code whether `s` can be non-finite when `m` is finite and
  positive (each `|dᵢ/m| ≤ 1` up to rounding), and say what you concluded; if it can be, keep the test.

## Tests
No new test file. Existing tests must pass unchanged apart from the one `j` loop. The unit sweep (check 3 below) is a
probe, not a committed test.

## Running things
- Julia: `julia +lts` is 1.10.13, `julia +release` is 1.13.4. Run everything locally, foreground only, each Bash
  call with an explicit timeout (at most 600000 ms). Never start a detached or background job. If a step cannot
  finish in one call, split it (one Julia version per call, one test file per call); if it still cannot, hand back
  the exact command for the orchestrator to run and list it under "Not run".
- Other agents of this run use the same machine. Wrap every test battery in the run's lock:
  `flock -w 480 <WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf/evidence/.heavy.lock <command>`
  (if the lock times out, wait a minute and repeat). Single-process probes need no lock but run one at a time.
- **The battery command** (test files; runs at a commit, refuses a dirty worktree, so commit first), per version:
  `python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py tests --worktree <WORK>/ProximalSolvers.jl-issue353 --run-dir <WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf --where local --versions <lts|release> --tag impl --tier none --jobs 2 --name <name> -- <test file names without .jl>`
  Its last line is `BATTERY PASS` or `BATTERY FAIL`; paste its summary into the hand-back. Use a distinct `--name`
  per call (for example `r2-lts`, `r2-release`, `r4-lts`, `r4-release`).
- **A probe script** (a path under the worktree), per version:
  `python3 -I <SKILLS>/github-issue-workflow/scripts/battery.py julia --worktree <WORK>/ProximalSolvers.jl-issue353 --run-dir <WORK>/ProximalSolvers.jl-issue353/.codex-orchestrator/runs/run-20261118T0505-issue353-dfaf --where local --versions <lts|release> --tag probe --name <name> -- --project=. .codex-orchestrator/probes/<script>.jl [args]`
  It writes `evidence/<name>-<version>.out`. The first run of each version instantiates the project (on 1.13 there
  is no `Manifest.toml` yet: run a one-line probe that does `using Pkg; Pkg.instantiate()` first).
- Truncate long outputs (`cut -c1-300`, `tail`).

### Pre-push battery and checks, in this order
After commit 1 and again after commit 2 (so each commit has its own evidence), on both Julia versions:
1. **Focused test files:** `cd_numerics accelerated_pgd sqrt_lasso group_cd core_regressions core_contracts stopping_scale`
   (split over calls as needed). The full tier is run by the orchestrator at the final head; do not run it.
2. **Fingerprint matrix.** Copy `$S0/experiments/x2/fp_lib.jl` and `fp_matrix.jl` into the probes folder and write
   a loader there that defines `module BaseMod; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end`
   and `module X2Mod; include("<WORK>/ProximalSolvers.jl-issue353/src/ProximalSolvers.jl"); end`
   (the Stage 0 loaders `loadtrees*.jl` show the pattern; `fp_matrix.jl` picks the loader from `ENV["LOADER"]` and
   takes the argument `x2`). It compares base and head in one process over about 4,800 solves (status, iterate
   bits, counts, objective, gap, thrown error and message). Criterion: `mismatches=0` in every family and in the
   TOTAL line, at commit 1 and at commit 2. The Stage 0 outputs to compare the shape with are
   `$S0/experiments/x2/fp_x2b_lts.txt` and `fp_x2b_release.txt` (TOTAL comparisons 4806 on 1.10 and 4794 on 1.13
   there; report yours). Any mismatch: stop, investigate, report; do not adjust the comparison.
3. **Unit sweep** of the changed helpers, base against head in the same process (adapt
   `$S0/experiments/x2/unit_items.jl` and `sc_check.jl` to the loader above): `_norm_diff(x, y, Inf)` against the
   base's `_maxabs_diff` (Float32 and Float64, with NaN, ±Inf, signed zeros, subnormals, empty arrays, matrices);
   `T(v, RoundUp)` against the base's `_round_up` (values on and between grid points of T, subnormal, 0, the
   largest finite, NaN); `_root_scale` on Float32, Float64, `Bool`, `Int8…Int128`, `UInt8…UInt128` scales
   (including `typemax`, values just below and above 2^53 and 2^64, the smallest subnormals; compare the `_SE`
   fields bit for bit, and separately compare `s·2^e` as a value if the fields ever differ: report it, do not hide
   it); `_frobenius_upper`; `_flat_column`/`_flat_group` (with `-0.0`, NaN, a zero-row matrix, groups of several
   index types); after commit 2 the folded `_se_norm` and `_se_norm_onepass` (two and three array arguments)
   against the base's four functions on vectors and matrices with NaN, Inf, all-zero, subnormal, huge and
   mixed-scale entries, `a == b`, both element types. Criterion: every comparison `===` (or both throw the same
   error). Report the number of comparisons.
4. **Warmed allocations:** adapt `$S0/experiments/x2/allocs.jl` to the loader; criterion: equal on base and head
   for every listed call.
5. **Line counts:** `python3 $S0/tools/count_loc.py` (read its usage) on the base and head `src` trees; report the
   executable-line delta of each commit per file against the expected −28 (R2) and −17 (R4).
6. `python3 -I <SKILLS>/github-issue-workflow/scripts/comment_scan.py bb20b6a36cc040f7f00088919e331dce27cf257b HEAD`
   after the last commit; answer each listed line in the hand-back (narrowed, or kept with the reason).
7. The import check (changes under `test/`):
   `cd <WORK>/ProximalSolvers.jl-issue353 && perl -e 'alarm 30; exec @ARGV; die "exec failed: $!\n"' julia --startup-file=no <SKILLS>/github-issue-workflow/scripts/check_test_imports.jl bb20b6a36cc040f7f00088919e331dce27cf257b`

The paired timing comparison (plan check 5) and the full test tier (plan check 1) are run by the orchestrator after
your hand-back; do not run them. But prepare the timing: copy `$S0/experiments/timing/x2_paired.jl` and
`summarize.py` to the probes folder and adapt the harness to load three trees in one process: base, a second copy
of the base (the A/A control) and the head, from the two worktree paths above (read how the Stage 0 harness names
its trees and keep its workloads and output format). Run it once with 1 round on `+release` as a smoke test only
(it must run to completion and print rows for all three trees), and give the exact command for the full 15-round
run in your hand-back.

## Comments and documentation
Every comment and documentation line you add says what the code does under a stated condition, not more.
- No absolute word (every, never, always, only, whatever, exactly, free, no longer) that the code does not guarantee.
- An implication "X, so Y" is checked at the case where Y fails.
- A number or a worked example in a comment is recomputed from the code, not remembered.
- No history in comments or docs (no "Stage 0", "prototype", "previously", issue-audit narration): describe the code
  as it is.

## Hand-back (your final message; the orchestrator saves it verbatim)
Headings: What changed (per file, why); Commit SHA(s) and `git status --porcelain`; Commands run with results
(counts pasted from the outputs: each file, each Julia version, each commit); Evidence for each check 1–7;
The `_se_norm_diff` finiteness question (your conclusion and argument); Deviations from the plan (smaller choices
you made, each with the reason); **Not run** (every item of this brief you did not run, each with the reason, or
"none"); the timing command for the orchestrator; Open questions. End with `Status: COMPLETE` (nothing under Not
run) or `Status: INCOMPLETE`. Do not describe what you did not run. Return the hand-back as your final message; do
not try to write it to a file.
