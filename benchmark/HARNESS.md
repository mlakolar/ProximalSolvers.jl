<!-- The general harness documentation, from benchmark/README.md of master 3c9241b (identical to
     the protected archive 9be1773e911a44ec21d49df28cb01fea37c4316e), with the current-core
     sections of #110 added: "Current core", "Supported and deferred cases" and "Restoring a solver". -->

# Benchmarks

This suite measures solver time and Julia heap allocation with accuracy checks independent
of solver stopping rules. It does not measure native (non-Julia) allocations or the
statistical quality of the estimates.
Peak memory is recorded only as process-wide `maxrss_bytes`, not per case.

## Current core

Master's core is `CDSolver` (dense `Vector` or vector `SparseIterate` for least-squares
lasso, and `BlockIterate` for group lasso), `ProximalGradientDescent`, and
`AccProxGradDescent` (both with dense `Vector` for least-squares lasso), all on
Float32/Float64. ProximalBase is pinned to an exact development commit in the root
`Project.toml` `[sources]`.
From the package root, with Julia 1.10 or later and Python 3.11 or later:

```sh
julia benchmark/setup.jl "$PWD" benchmark/results/env-quick pinned
JULIA_NUM_THREADS=1 PS_EXPECTED_PROXIMALBASE_REV=e03c6d9659365d54f4e0fba1a9cd54490631eea6 \
  julia --project=benchmark/results/env-quick benchmark/run.jl
python3 benchmark/validate.py benchmark/results benchmark/results/validation.json
python3 benchmark/summarize.py benchmark/results benchmark/results/summary
```

`pinned` takes the checkout's exact ProximalBase source (URL and full commit; a branch name
or short revision is refused) and its ProximalBase compat; the other dependencies come from
`benchmark/Project.toml`, which keeps its ProximalBase 0.5 compat for the historical
environments (Stage 2A verification reads it; the registered-release cleanup is #225). The
pinned source is added before the checkout is developed, which Julia 1.10 needs because it
ignores `[sources]`. Setup prints the ProximalBase source, git-tree-sha1 and loaded path, and
refuses a manifest whose tree differs from the one the checkout's committed manifest records
for the same commit.

At startup `run.jl` reads the active manifest's ProximalBase entry and refuses a git source at
a moving revision and a git or registry source loaded from another directory than its tree's
depot directory (exit 3, no records). When the loaded checkout pins ProximalBase in its root
`Project.toml`, the loaded ProximalBase must be a git entry at exactly that URL and commit,
with the tree the checkout's committed manifests record; this needs no setting, so an
environment changed after setup (for example by `Pkg.add` of another commit, which Julia 1.10
allows because it ignores `[sources]`) is refused. Checkouts without a pin (historical
full-package ones) keep the version and path modes. `local.jl` applies the same check
before it builds any case. `PS_EXPECTED_PROXIMALBASE_REV` additionally
requires a git source at exactly that commit, and `PS_EXPECTED_PACKAGE_REVISION` requires the loaded checkout to be that
commit with no tracked or untracked change in `Project.toml`, `src` or `ext`. Start metadata
records the manifest entry (`proximalbase_source`, `_url`, `_rev`, `_tree_sha1`, `_path`,
`active_manifest`), the checkout's pin (`required_proximalbase_rev`), the declared `capabilities` and the number of `deferred_cases`.

The historical modes are unchanged: a version (`0.5.4`) or a ProximalBase checkout path copy
the compat of `benchmark/Project.toml`, for full-package checkouts such as Stack A `b0de3f7`.

## Setup and selections

`setup.jl` instantiates a fresh environment with a checkout and a ProximalBase spec (`pinned`,
a version or a path). The default is one quick Float64 repetition: exploratory, with no
between-run interval.

| Setting | Default | Use |
|---|---|---|
| `PS_SUITE` | `quick` | `extended` includes quick cases, larger inputs and correlated designs. |
| `PS_GROUPS` | All groups below | Comma-separated selection, before building data. |
| `PS_CASES` | Unset | Comma-separated case IDs or patterns (`*` matches any characters) within the suite and groups. Every entry must match; data is built only for selected cases. |
| `PS_REPETITION` | `1` | Process/input draw, numbered 1–10. |
| `PS_OUTPUT` | `benchmark/results` | Directory for process records. |
| `PS_SAMPLES` | `50` quick; `100` extended | Sample limit, subject to a minimum of five. |
| `PS_SECONDS` | `1` quick; `3` extended | Limit on accumulated timed seconds per case. |
| `PS_CASE_SECONDS` | `60` | Per-call limit for timed samples and compiled validation rechecks; the first validation call is exempt. |
| `PS_PROFILE_SECONDS` | `0` | Positive values enable diagnostic profiles per successful case. |
| `PS_EXPECTED_PACKAGE_ROOT` | Unset | Verify the loaded ProximalSolvers checkout before building cases. |
| `PS_EXPECTED_PACKAGE_REVISION` | Unset | Require the loaded checkout at this full commit, with no change in `Project.toml`, `src` or `ext`. |
| `PS_EXPECTED_PROXIMALBASE_REV` | Unset | Require ProximalBase from a git manifest entry at this full commit. |
| `PS_LIST` | `false` | `true` prints selected `id`, `suite`, `issue` without data or records; `deferred` prints the deferred cases of the suite and groups with the capabilities they lack. |

| Group | Cases |
|---|---|
| `cd` | Coordinate descent covers dense, sparse, weighted, quadratic, group and square-root lasso. |
| `paths` | Lasso and SLOPE paths cover complete penalty grids. |
| `gradient` | PG, APG, monotone, active-set and diagonal methods solve least-squares lasso. |
| `newton` | ProxNewton solves logistic L1, including weights and offsets, and QUIC solves graphical lasso. |
| `admm` | ADMM solves least-squares lasso and measures factorization setup separately. |
| `primal_dual` | Condat–Vũ solves strongly convex generalized lasso. |
| `nonconvex` | Proximal gradient covers MCP, SCAD and IHT. |
| `slope` | SLOPEAPG and SLOPEHybrid solve sorted L1 problems. |
| `sgl` | Coordinate descent and APG solve sparse group lasso. |

## Supported and deferred cases

Every case declares what it needs from the loaded package: its solver ID and, per feature,
`solver:feature` (problem, `float32`, `sparse_iterate`, `block_iterate`, `weighted_l1`, `gap` for duality-gap stopping,
`workspace`, `path`, `setup`). `CAPABILITIES` in `cases.jl` declares what the current core
provides; it is a short explicit list, not inferred from the names the package defines, since a
solver type can exist without supporting a problem, an iterate or a phase. A case with a
requirement missing from it is deferred:

- default runs, `PS_GROUPS` and patterns select only supported cases, and deferred cases are
  never constructed or run;
- a `PS_CASES` entry that names a deferred case, or a pattern that matches only deferred
  cases, stops the runner (exit 3) with the capabilities those cases lack; a pattern that also
  matches supported cases runs those and names the deferred matches on stderr;
- a suite and groups with no supported case stop the runner;
- `PS_LIST=deferred` lists the deferred cases with their missing capabilities.

The 102 historical cases keep their IDs, inputs, settings, measures and targets. Two run on the
current core unchanged: `cd/lasso-dense/cd/R/call` and `gradient/lasso/pg/R/call` (default
settings, accuracy recorded with target `NaN`). The other 100 are deferred: their solvers are
not in the core (FISTA variants, ProxNewton/QUIC, ADMM, Condat–Vũ, SLOPE), or they need gap
stopping, `SolverWorkspace`, paths, setup phases, sparse designs, or other losses
and penalties (the historical weighted lasso, `cd/weighted-lasso/cd/tight`, needs gap stopping and a workspace; the
weights themselves are supported, see below).

The 40 current-core cases (`cd` and `gradient` groups) use one problem per design, shared by CD,
PGD and APG, cold and warm starts, dense and `SparseIterate` iterates:

| Problem | Design | Suite | Variants |
|---|---|---|---|
| `lasso` | 100×32, independent columns (`regression_problem`, key `core/lasso`) | quick | CD `{dense,sparse}-{f64,f32}`; PGD and APG `dense-{f64,f32}` |
| `lasso-B` | 240×160, correlated ρ=0.8 (inputs of `*/lasso-B/*/tight`) | quick | as above, and `warm-` of each |
| `lasso-C` | 800×120, correlated ρ=0.5 | extended | as `lasso` |
| `lasso-D` | 180×600, p > n | extended | as `lasso` |

Eight more current-core cases (quick suite) run `CDSolver` on a `BlockIterate` for the group lasso
(#275). They need the capability `cd:block_iterate` (and `cd:float32` in Float32):

| Problem | Design | Suite | Variants |
|---|---|---|---|
| `group-lasso` | 120×32, independent columns, contiguous groups of four with the default weights `√4` (`grouped_problem`, key `core/group-lasso`) | quick | CD `block-{f64,f32}`; `warm-` of each |
| `group-lasso-m2` | 120×32, independent columns, 16 contiguous groups of two with weights `√2` (`grouped_problem`, key `core/group-lasso-m2`) | quick | CD `block-{f64,f32}`; `warm-` of each |

Their IDs are `cd/group-lasso/cd/{,warm-}block-{f64,f32}/call` and
`cd/group-lasso-m2/cd/{,warm-}block-{f64,f32}/call`. The two-column fixture exercises
the closed-form curvature (#339, #387). Its separate seed key gives cold and warm cases
the same draw at each repetition and keeps the four-column inputs and hashes fixed for
revision comparisons. The historical `cd/group-lasso/cd/tight/call` keeps its inputs and
stays deferred: it needs `cd:group`
(`GroupNormL2` on an `AtomIterate`) and `cd:gap`, which `CAPABILITIES` does not declare, and its
draws differ from those of the current-core key. The penalty is `GroupNormL2` of the problem's element type, and the start is a
`BlockIterate` with the groups of the problem, active where the start is nonzero. The settings,
targets (`1e-8` in Float64 and `1e-5` in Float32) and the exact Float64 read-back of the rounded
data are those of the lasso cases, and the certificate is `group_certificate`, the group-lasso
relative duality gap of the problem the solver received, from the returned minimizer only. A warm
start is the solution at 1.25λ from `group_warm_start`, cyclic block coordinate descent in Float64
with the largest eigenvalue of each Gram matrix (from all its eigenvalues) as the curvature, written in `cases.jl` and
stopped at a certified relative gap of `1e-12`; `cert_loading_refit` is lasso-only, and this start
does not depend on the solver under test. The extended suite includes these quick cases, and
there are no additional group-lasso cases exclusive to it. There are no PGD or APG group cases
(those solvers do not accept a `BlockIterate`).

The extended suite adds ten Float64 `acc-` cases for PGD and APG (#314):
`gradient/<problem>/{pg,apg}/acc-{dense,warm-dense}-f64/call` on the problems, starts and inputs
of the table, with the same target and certificate, under `accuracy_options()`
(`maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = 1e-10, allow_f_increases = true`). `acc-`
names a setting, not a `converged = true` certification: the status is the certificate's, so a
solve that ends `stagnated` or at `maxiter` with an accurate minimizer is `ok`, and a
`converged = true` solve above the target is `target_missed`. There are no Float32 `acc-` cases.

Six more current-core cases (extended suite, #331) solve the weighted lasso, `NormL1(λ, w)`, on the
100×32 independent design of `lasso` with the positive weights `0.5, …, 2.5` (`weighted_problem`, key
`core/lasso-weighted`; λ is 0.15 of the λmax of the unweighted problem), from a cold start (a warm start needs unit
weights). They need `weighted_l1` for the solver (`cd:weighted_l1`, `pg:weighted_l1`, `apg:weighted_l1`; `random-cd:weighted_l1`
is declared for the random-order CD ID, which has no current-core case) and `float32` in Float32. The relative gap
certificate applies to positive weights; zero weights would need the KKT residual certificate:

| Problem | Design | Suite | Variants |
|---|---|---|---|
| `lasso-weighted` | 100×32, independent columns, weights `0.5, …, 2.5` | extended | CD `{dense,sparse}-{f64,f32}`; PGD and APG `acc-dense-f64` |

Their IDs are `cd/lasso-weighted/cd/{dense,sparse}-{f64,f32}/call` and
`gradient/lasso-weighted/{pg,apg}/acc-dense-f64/call`. The settings, targets and certificate are those
of the other current-core cases of the same solver and precision (`acc-dense-f64`: `accuracy_options`). As for the other
`acc-` cases there are no Float32 PGD or APG cases.

With all groups selected, the default quick suite has 34 supported cases: 24 standard
lasso cases, 8 group-lasso CD `BlockIterate` cases, and 2 unchanged historical cases.
The extended suite includes quick and has 66 supported cases: 40 standard lasso cases,
10 Float64 PGD/APG `acc-` cases, 8 group-lasso CD cases, 6 weighted lasso cases, and the same 2 historical cases.
The other 100 historical cases are deferred in the extended suite.

Float32 inputs are the Float64 draw rounded once; the data hash covers the rounded values and
the start. A warm start is the solution at 1.25λ, computed in Float64 by the certificate
module's own coordinate descent (`cert_loading_refit`), so it does not depend on the solver
under test. The certificate is the least-squares lasso relative duality gap of the problem the
solver received, read back exactly in Float64 (`exact_problem`), from the returned minimizer
only. Targets are per precision for every solver: `1e-8` in Float64 (the threshold of the
#103–#109 B cases) and `1e-5` in Float32, about 50–100 times the gap of the exact solution
rounded to Float32 (5e-8 to 2e-7 on these designs). CD uses `order = :cyclic` and coefficient
tolerance `1e-11` (Float64) or `1e-6` (Float32); PGD and APG (`AccProxGradDescent()`, its
default `β` and `α`) use `benchmark_options(residual = true)`.
PGD stops once the objective changes by less than one rounding unit, about √eps in the
coefficients (relative gaps near 1e-8 in Float64 and 1e-4 in Float32), so it misses these
targets on several designs; those cases are recorded as `target_missed` and excluded from
timing comparisons, with their accuracy kept. APG uses the same stopping tests. In one
observed run of repetition 1 at the PR that added APG, both reached the Float64 target on
`lasso` and `lasso-D` only and neither reached the Float32 target; other repetitions,
CPUs or BLAS builds can change where they stop. Where PGD stops is sensitive to rounding: with
`--check-bounds=yes` the small Float64 case ends at a gap of 1.7e-8 instead of 1.0e-9.

For example, list the extended gradient cases without measuring them:

```sh
PS_SUITE=extended PS_GROUPS=gradient PS_LIST=true \
  julia --project=benchmark/results/env-quick benchmark/run.jl
```

Each case builds its inputs from a seed keyed by its scenario and repetition, so a case
selected alone has the same inputs, data hash and certificate as in the full suite.
`PS_CASES='cd/lasso-B/cd/*-f64/call'` measures four of the 21 supported quick `cd` cases.

### Float32 PGD and APG against the `1e-5` target

PGD and APG with the harness options (`benchmark_options(residual = true)`: `maxiter = 10_000`,
`ftol = 1e-15`, `xtol = 1e-14`, `gradtol = 1e-11`, `allow_f_increases = false`) often end above
the target in Float32, and the case is then recorded as `target_missed`. This subsection says
which cases, why, and what it means. The target stays at `1e-5` and the recorded results are
unchanged. The numbers are from the
[Phase 0 report of issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320#issuecomment-6967100343);
its scripts, configurations and summary tables are on the branch
[`archive/issue-320-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/archive/issue-320-evidence).
They hold for these conditions: the five designs `lasso`, `lasso-B` (cold and warm), `lasso-C` and
`lasso-D`, 10 draws each (50 solves per cell); Julia 1.10.13 and 1.13.3; the revisions before and
after #319 (master `dac9f4b` stopped at the same iterations as `9f86a80`); one CPU kind, the Intel
Xeon E5-2640 v4 of the #319 report. Counts can differ slightly with the CPU kind and the Julia
version: for Float32 PGD on master, the two CPU kinds of the report gave 214 and 215 misses of 240
records (these designs and an adverse set), with 3 records changing status. The input hashes of
the warm designs and of a few `lasso` draws differed between the two CPU kinds, so that
comparison is of nearly identical inputs.

| Solver, harness options | Julia | Misses of 50 | Of those, `converged = true` |
| --- | --- | --- | --- |
| Float32 PGD | 1.10.13 | 36 to 39 | 22 to 25 |
| Float32 PGD | 1.13.3 | 37 | 15 to 16 |
| Float32 APG | 1.10.13 | 40 | 26 |
| Float32 APG | 1.13.3 | 41 | 29 |
| Float64 PGD | 1.10.13 | 4 | 0 |
| Float64 PGD | 1.13.3 | 5 | 0 |

A miss is an independent relative duality gap above the target (`1e-5` in Float32, `1e-8` in
Float64). The ranges in the PGD rows run from the revision before #319 to the one after it: the
number of misses changed by at most 3 of 50 (36 to 39 on Julia 1.10.13, 37 and 37 on 1.13.3),
and which draws miss changed too.

**Why they miss, Float32 PGD.**

- The objective test proposes the stop. In 237 of the 240 Float32 PGD records of the report
  (these designs and the adverse set, both Julia versions, master), the first proposal came from
  the objective test, through its one-ulp branch `|F - F'| < eps(|F| + |F'|)` (about two spacings
  of `F` in the ordinary range; see [Strict accuracy](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/#Strict-accuracy)),
  because `ftol = 1e-15` is below the resolution of a Float32 objective. In the other 3 records no
  test proposed a stop first.
- The stationarity check accepts a proposal when its computed normalized KKT residual is below
  `max(gradtol, 64 eps(T))`, which is `64 eps(Float32) ≈ 7.63e-6` here. The relative duality gap
  of the target is a different quantity: a computed KKT residual can pass that threshold while the
  independent relative gap exceeds `1e-5`. Among the 119 Float32 PGD `converged = true` records
  that missed the target (summed over the six revision and Julia-version cells), the independent
  relative gap was 1.07e-5 to 3.75e-5 and was 2.3 to 7.0 times the independent KKT residual. This
  range is for Float32 PGD and is not a bound for APG.
- On master and the five harness designs, the misses with `converged = false` ended on the
  objective-increase stop: 14 of 50 solves on Julia 1.10.13 and 21 of 50 on 1.13.3. The stationarity
  check had refused at least one earlier proposal in 14 and in 19 of them. The other 2 on 1.13.3
  (`lasso-B-warm` draw 4 and `lasso-D` draw 6) ended on the increase with no proposal made. On the
  adverse set of the report, on master, 63 (1.10.13) and 57 (1.13.3) of the 69 misses ended on the
  objective-increase stop after refused proposals, and 2 and 4 at the iteration limit. On master,
  all 156 objective-increase stops of the report (these designs and the adverse set) were
  increases of 1 to 3 Float32 spacings of the objective, 142 of them of exactly 1.
- The gradient evaluation was not the limit: the Float32 gradient of the solver differed from the
  Float64 gradient of the same rounded data by at most `2.5e-7` of the residual's scale
  `max(λ, λmax)`, over about 957,000 recorded iterations, which is 30 times below the threshold
  of the check.

**What the evidence shows.** In these measurements, the independent KKT residual of each Float32
PGD `converged = true` record was below the threshold of the check (191 records on these designs,
largest value `7.616e-6`), so those records meet the contract documented for `converged = true`.
The measurements indicate a limit of the stopping criterion in Float32 relative to a stricter
benchmark target, and do not show a solver defect. Float32 APG was measured for the counts in the
table; the report did not classify its mechanism separately. For both solvers, a
`target_missed` status on a default-settings Float32 case, or one record changing status between
revisions, is not by itself evidence for or against a code change.

**When the gap target is stricter than the stopping contract.** The contract of `converged = true`
is in [Limits of the stopping tests](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/).
On the Float32 PGD records above, meeting it did not imply meeting the independent `1e-5` gap
target, so a gap target can be stricter than that contract. With the strict profiles S and A of
the report (`ftol = 0`, `allow_f_increases = true`, with `xtol` and `gradtol` as listed there),
Float32 PGD missed the target in 0 of 50 solves in each of the six revision and Julia-version
cells and reported `converged = true` in none (all ended on the stagnation stop, a median of 10 to 14
iterations after the target was reached); Float32 APG with the same profiles reported
`converged = true` in 50 of 50 with no miss. On the adverse set of the report (ill-conditioned
and low-penalty designs, not part of this suite), those profiles ended at the iteration limit
in 40 or 41 of 70 Float32 PGD solves, so they are not a general remedy.

## Local exploration

`local.jl` is a development aid: it decides whether a change is worth pursuing, not whether
it is faster. It runs selected cases through the same `make`/`reset!`/`call!`/`certify`
closures, validation call, `observe!` timing and statuses as `run.jl`, but writes no
records. Its output and optional TSV are labelled exploratory; `validate.py` and
`compare.py` do not accept them. Claims of improvement or noninferiority need the formal
comparison below.

```sh
julia benchmark/setup.jl "$PWD" benchmark/results/env-local pinned   # once per checkout
export JULIA_NUM_THREADS=1
alias pslocal='julia --project=benchmark/results/env-local benchmark/local.jl'
pslocal --list 'cd/*'                                     # case IDs, no measurement
pslocal 'cd/lasso-B/cd/*-f64/call' --save before.local.tsv     # before editing src/
pslocal 'cd/lasso-B/cd/*-f64/call' --baseline before.local.tsv
```

Quote patterns in the shell. For each case, a `CHECK` line gives the certificate of the
first (validation) call as soon as it finishes. The report then gives the status, the
first call (with compilation), the median and minimum of the timed samples (at most 25 by
default, stopping after 0.5 timed seconds once three are taken, against five in `run.jl`;
see `--help`), the allocation per call, the certificate against its target and solver work
counters read after timing. A baseline adds the candidate/baseline median ratio, the
absolute change per call and the ratio of minimum times. A ratio is withheld unless the
case, data hash, harness, `local.jl`, active project and manifest, Julia version, CPU model
and ProximalBase all match and both runs are `ok`. Saved times must be positive integer
nanoseconds. An invalid baseline median suppresses the ratio; an invalid minimum suppresses
only the minimum-time ratio. Within about 10%, a ratio is typical run-to-run noise. Other
processes inflate medians more than minima: when the two ratios differ by more than 10%,
or the header warns that the load average exceeds half the CPU threads, rerun on a quieter
machine. A case stops at its first non-`ok`
certificate, in validation or in a timed sample, and reports the failure, its `CHECK`
line and no timing (earlier `ok` samples are not a timing of a failed case); the exit
status is 2, as in `run.jl`.

After an edit to `src/`, a new process recompiles ProximalSolvers before it runs. Two ways
avoid most of that cost:

- On Julia 1.11 or later, `julia --compiled-modules=existing --project=...
  benchmark/local.jl ...` loads the edited package from source instead of precompiling it.
- `--session` keeps one process running and applies edits with Revise, which must be
  installed in the default environment (for example `julia -e 'using Pkg;
  Pkg.add("Revise")'`). It reads one command per line, for example from a file that an
  agent appends to, and ends each command with `LOCAL_DONE status=N`. Arguments are split
  on spaces, without quoting, so paths must not contain spaces:

  ```sh
  : > commands.txt                 # empty, so a restart does not replay old commands
  tail -n 0 -f commands.txt | julia --project=benchmark/results/env-local \
    benchmark/local.jl --session > session.log 2>&1 &
  echo 'cd/lasso-B/cd/*-f64/call --save before.local.tsv' >> commands.txt
  # edit src/, then:
  echo 'cd/lasso-B/cd/*-f64/call --baseline before.local.tsv' >> commands.txt
  ```

  In a REPL, run `using Revise` and then `include("benchmark/local.jl")` before loading
  ProximalSolvers, then `explore("cd/lasso-B/cd/*-f64/call"; save = "before.local.tsv")`.

Before each run, a session applies every source file whose content changed since the last
run, without waiting for Revise's file events, and runs in the latest world. A changed
file that Revise cannot apply (for example a struct redefinition), or any `src/` edit
without Revise, stops the run with a request to restart. So does a change to `local.jl`,
the harness, ProximalSolvers' `Project.toml`, ProximalBase's files, the active project or
manifest, or the package paths the environment resolves. With Revise, deleting a `src/` or
`ext/` file requires a restart even if the file is restored, because Revise removes its
methods only later. Runs are allowed only when `local.jl` itself loaded ProximalSolvers (a fresh
process, a session, or a REPL that includes `local.jl` before loading ProximalSolvers),
with or without Revise: the methods of a package loaded earlier cannot be matched to its
files. A path-developed ProximalBase must likewise be loaded by `local.jl`. Each run
rebuilds its inputs and solver state. In a REPL, Revise also revises before every prompt,
so a file deleted while other commands run, and restored before `explore`, may have lost
its methods without `local.jl` seeing the deletion; restart after deleting a file there.
A session calls Revise only from its own check, so this does not apply to it.

Session timings are exploratory: compilation, garbage collection and memory state differ
from a fresh process. Ratios between a baseline saved in one mode (fresh process, session
or REPL) and a candidate run in another are not like-for-like evidence; the report says
so. Save the baseline in the mode you will compare against, typically in the same
session before editing. Methods redefined by Revise can also run differently from
precompiled ones: for #110, a no-op edit sometimes doubled the time of a 6 µs case (median
and minimum ratios both about 2). The same shift appeared between two fresh processes with
identical source and environment (in one scenario, on Julia 1.10 and 1.13), so a single ratio near 2 for a microsecond case is
not evidence on its own. Repeat an apparent change in fresh processes, and claim it only
with `compare.py`.

On one machine for #110 (Apple M3 Pro, Julia 1.13), an edit followed by one quick case took
13–21 s with `PS_GROUPS` or a fresh `local.jl` process, about 7.5 s with
`--compiled-modules=existing`, and 0.2–0.8 s in a session after a one-time start of about
7.5 s. `benchmark/check_local.jl` checks selection, input independence, statuses, the
stop after a failed certificate, freshness refusals, baselines and session commands.

## Certificates and phases

`certificates.jl` uses plain problem data and returned solutions, without reading solver
stopping diagnostics. Relative gaps use `max(P-D, 0)/max(abs(P), floatmin(Float64))`;
weak-duality violations beyond a summation error bound scaled by the problem dimension
and the magnitude of the summed terms, and nonfinite values, are uncertifiable.

| Problem | Certificate |
|---|---|
| Least squares + weighted L1, including ADMM | Relative duality gap; KKT residual for zero penalty weights or zero penalty. |
| Group lasso, sparse group lasso, SLOPE | Relative duality gap using the corresponding polar constraints. |
| Logistic L1, square-root lasso, graphical lasso | Relative duality gap with explicit domain checks. |
| Generalized lasso | Relative gap from a strongly convex primal–dual lower bound. |
| Quadratic L1 | Unit-step KKT residual; a separate `dual-gap` case records the least-squares gap. |
| MCP, SCAD, IHT | Fixed-point residual with step `1/L`; IHT also checks sparsity feasibility. |
| Setup | Self-consistency of cached factorization or coordinate curvature. |

Nonconvex residuals certify stationarity, not global optimality. Square-root residual
norms at or below `fit_floor` are uncertifiable. Paths require the full requested grid
and certify every returned level; their value is the worst level. A `record` target
is `NaN`: accuracy is recorded without a threshold, but the certificate must be valid.
Finite targets require `value <= target`. `check_certificates.jl` tests analytic and
nonoptimal controls, domains, weak duality and dual feasibility; package agreement is secondary.

| Status | Meaning |
|---|---|
| `ok` | Certificate is valid and any finite target is met. |
| `target_missed` | Valid certificate exceeds the finite target. |
| `incomplete` | Returned path does not contain the complete requested grid. |
| `uncertifiable` | Certificate is invalid, outside its domain or nonfinite. |
| `error` | Construction, reset, solve or certification throws an exception. |
| `timeout` | A timed sample or compiled validation recheck exceeds `PS_CASE_SECONDS` after returning; the first validation call cannot time out. |

| Phase | Timed operation |
|---|---|
| `call` | Warm public `solve!` or path driver, including per-call setup and result construction; loss caches and ADMM factorizations are warm. |
| `workspace` | Warm `solve!` reusing a `SolverWorkspace`; workspace construction and reset are excluded. |
| `setup` | Fresh loss/cache, curvature or factorization construction from prepared inputs; no solve. |

Input generation, compilation, state/workspace/RNG resets and certification are outside
sample timing. One validation call precedes sampling. Each sample times one call with
`@timed`, then certifies its output. Sampling stops at either limit, with at least five
samples unless an error or timeout stops the case. Statistics use only `ok` samples; all
sampled attempts are retained. Case status follows `error`, `timeout`, `incomplete`,
`uncertifiable`, `target_missed`, including validation failures. The first validation call
includes compilation and is exempt from the timeout limit. If it exceeds `PS_CASE_SECONDS`
without error, one compiled recheck is observed against that limit. Timed samples use
the same per-call limit. Profiles are diagnostic, not timings.

## Fixed workloads for #103–#109

R is [benchmark/release_candidate/reproduce.jl](https://github.com/mlakolar/ProximalSolvers.jl/blob/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark/release_candidate/reproduce.jl).
B is [docs/audit/20261026/performance-batched.jl](https://github.com/mlakolar/ProximalSolvers.jl/blob/f7e3f28026a8e83e0fa18203b39839cf57a1c949/docs/audit/20261026/performance-batched.jl).
R/B inputs are fixed across repetitions at this snapshot. R records default-setting
accuracy (`target=NaN`); B uses a `1e-8` threshold. In the table, `{R,B}` expands to two
IDs and `*` to `call` and `workspace`.

| Issue | Case IDs | Source |
|---|---|---|
| #103 | `newton/logistic-l1/prox-newton/{R,B}/call` | R `newton`; B GLM-Newton. |
| #104 | `cd/sqrt-lasso/cd/R/*` | R `sqrt`. |
| #105 | `gradient/lasso/monotone/{R,B}/*` | R/B `monotone`. |
| #106 | `gradient/lasso/pg/{R,B}/*` | R `pg`; B PG. |
| #107 | `gradient/lasso/active/{R,B}/call` | R/B `active`. |
| #108 | `cd/lasso-dense/cd/{R,B}/*`, `cd/lasso-csc/cd/B/*` | R `cd`; B CD and CSC-CD. |
| #109 | `admm/lasso/admm/{R,B}/*`, `admm/lasso/admm/construction/setup` | R/B ADMM; separate factorization setup uses generated inputs. |

## Compare revisions

Use one fixed harness copy from the same root, with two fresh environments and the same ProximalBase spec.
For the current core, use clean checkouts of committed revisions (for example `git worktree add
--detach DIR COMMIT`), the harness of a committed checkout outside both, `base_spec=pinned`, and add
`PS_EXPECTED_PACKAGE_REVISION="$(git -C "$checkout" rev-parse HEAD)"` and
`PS_EXPECTED_PROXIMALBASE_REV=<the pinned commit>` to the run line below; both revisions must pin
the same ProximalBase commit, or `compare.py` refuses the different `proximalbase_hash`.

```sh
before=/absolute/path/to/before
after=/absolute/path/to/after
base_spec=0.5.4   # pinned for the current core
julia benchmark/setup.jl "$before" benchmark/results/env-before "$base_spec"
julia benchmark/setup.jl "$after" benchmark/results/env-after "$base_spec"
runs=3
for rep in $(seq 1 "$runs"); do
  if [ "$((rep % 2))" -eq 1 ]; then set -- before after; else set -- after before; fi
  for side in "$@"; do
    code=0
    case "$side" in before) checkout="$before" ;; after) checkout="$after" ;; esac
    PS_EXPECTED_PACKAGE_ROOT="$checkout" PS_REPETITION="$rep" \
      PS_OUTPUT="benchmark/results/$side" JULIA_NUM_THREADS=1 \
      julia --project="benchmark/results/env-$side" benchmark/run.jl || code=$?
    [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || exit "$code"
  done
done
python3 benchmark/compare.py benchmark/results/before benchmark/results/after \
  benchmark/results/comparison --expected-runs "$runs"
```

Use `PS_REPETITION=1..N` in fresh processes, alternating which revision runs first;
choose `runs` from 1–10. Match suite, groups, sample/time limits, CPU, Julia/BLAS
versions and threads. The runner requires one Julia thread and sets one BLAS thread. Use
separate environments for different Julia versions. For an A/A comparison, set `before`
and `after` to the same revision and use two fresh environments and result directories;
this shows the noise level on the machine.

`compare.py` writes `REPORT.md`, `comparison.csv` and `coverage.json` to a fresh output
directory. It reports after/before ratios of repetition medians, paired 95% Student-t
intervals on log ratios, worst accuracy and median/maximum bytes. An interval containing
one is inconclusive. Any non-`ok` repetition excludes that case from ratios, with
reasons retained in the report and coverage JSON; even an all-failed comparison writes
all three files. Invalid records, mismatched settings, catalogs or data hashes prevent
comparison. Intervals include input variability and machine noise, without corrections
for correlated noise or multiple comparisons.

## Centered-quadratic ADMM measurements

`benchmark/admm.jl` uses the formal runner and its record format for
`SqrNormL2(λ, c) + NormL1(τ)` at sizes 32 and 8192 in Float32 and Float64.
The ordinary fixed penalty is `ρ = 2`. Fixed and adaptive cases also start
at the same `ρ = 64` to compare the policies at matched accuracy. Every
case uses `α = 1.4`. The variants measure three ways of calling the solver:

| Variant prefix | What goes into each timed call |
|---|---|
| `fresh` | Construct the two functions, the method and options, and a zero primal vector, then solve. |
| `prebuilt` | Solve using prebuilt functions, method and options. Reset the caller's primal and dual vectors to zero outside the timer. |
| `warm` | Solve from the analytic primal and scaled-dual solution using prebuilt functions, method and options. Reset both vectors outside the timer. |

Compilation, fixture generation and the independent checks run outside measured
samples. Every sample must meet the maximum coordinate KKT residual target
(`2e-5` in Float32, `1e-10` in Float64), agree with the analytic soft threshold
within that residual's point-error bound, and return the independently evaluated
objective to the stated working-precision allowance.

Use one clean harness checkout for all arms. For each arm, instantiate a fresh
environment with `benchmark/setup.jl CHECKOUT NEW_ENV pinned`. A historical
checkout that supports centered-quadratic ADMM can use its own pinned
ProximalBase revision. Repeat this command with the appropriate checkout,
environment and output directory for each arm:

```sh
PS_OUTPUT="$out" PS_REPETITION="$rep" JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  PS_EXPECTED_PACKAGE_ROOT="$checkout" \
  PS_EXPECTED_PACKAGE_REVISION="$(git -C "$checkout" rev-parse HEAD)" \
  julia --startup-file=no --project="$env" "$harness/benchmark/admm.jl"
```

Alternate arm order as in [Compare revisions](#compare-revisions), with separate
output directories for the A/A control and the revision comparison. Use
`PS_CASES` to select case IDs or glob patterns. Run `benchmark/validate.py` on
each arm and use `benchmark/compare.py` for the A/A control or comparisons
sharing the same ProximalBase pin. If the archive uses a different pin, declare
both stacks explicitly:

```sh
python3 benchmark/admm_compare.py "$archive_out" "$current_out" "$comparison" \
  --expected-runs "$runs" --before-ps "$archive_ps" --before-pb "$archive_pb" \
  --after-ps "$current_ps" --after-pb "$current_pb"
```

This comparison matches inputs and accuracy targets and attributes the timing
ratio to the whole stack. The per-repetition harness hash includes
`benchmark/admm.jl`. Keep the harness commit with the records.

## Cross-solver readout

`cross_solver.py` sets the per-case summaries of different solvers and settings (CD, PGD, APG)
side by side for the same problem and accuracy target. It reads existing records only: the
results directory, for the catalog fields and the per-repetition data hashes, and the
`summary.csv` that `summarize.py` wrote from that directory. It writes `REPORT.md` and
`cross_solver.csv` to a fresh directory and changes no record.

```sh
python3 benchmark/summarize.py benchmark/results benchmark/results/summary --expected-runs 10
python3 benchmark/cross_solver.py benchmark/results benchmark/results/summary \
  benchmark/results/cross-solver --expected-runs 10
```

- **Groups.** A group holds the cases of one Julia version, problem, phase, certificate measure,
  target and catalog input mode (`fixed`, `draw`) whose data hashes agree in every repetition. The
  data hash covers the problem data the solver received, not the solver or its settings; for the
  current-core cases it covers the data in the solver's precision, the penalty and the start, so
  the cases of a group received the same inputs. Precision (`f64`, `f32`) and start (`cold`,
  `warm`) are also read from the variant and kept apart; the solver with the rest of the variant
  names the configuration (`cd sparse`, `pg acc-dense`). Variants without a precision suffix (the
  historical `R`) show both as `not encoded`. Configurations are listed alphabetically.
- **Values.** `cross_solver.csv` carries the target, runs, timing runs, mean time, CI95 bounds,
  worst certificate and status counts of `summary.csv` as strings, unchanged, for every case.
  `REPORT.md` shows the fields its tables list to six significant digits, as `SUMMARY.md` does.
- **Failed and missing cases.** A time is shown only for a case with a finite target whose every
  repetition is `ok`, that is, whose independent certificate met the target in every sample.
  Other cases are listed with their status counts, worst certificate and the reason
  (`not every run ok`, `no accuracy target`), without a time. `not recorded` marks a configuration
  that another case of the same problem, phase and start has and this group lacks. A case with an
  empty data hash in some repetition (a failure before the runner recorded its input hash) keeps
  its row in `cross_solver.csv`; "Cases not grouped" lists its labels (including measure, target
  and input mode), ok runs, worst certificate and status counts, and a group with all of those
  labels marks the configuration `ungrouped`.
- **Refusals** (exit 2): invalid records; a `summary.csv` that does not cover the records exactly,
  or disagrees with their catalog (group, phase, measure, target), with `--expected-runs`, or with
  the records' status counts, timing runs, worst certificate or mean time (for example a summary
  of another series with other outcomes; the intervals are not rechecked); two cases of one group
  that name the same configuration.

The readout is descriptive and per case. Each interval is the case's own Student-t interval over
repetitions, not a paired comparison between solvers, so overlapping or separate intervals are not
a test. It does not rank solvers or compute ratios. A claim that one solver is faster at matched
accuracy needs the protocol of #110 (paired runs within a series, A/A controls, hardware policy).

One group of a 10-repetition extended run (Julia 1.13.3, `637f06a`):

```text
### Group 4: Julia 1.13.3, precision f32, start cold, relative_gap target 1e-05, inputs 4a1d7fea9474 (draw)

| Configuration | Case | Ok runs / total | Mean time (ns) | 95% interval (ns) | Worst certificate | Status counts | Time |
|---|---|---:|---:|---:|---:|---|---|
| apg acc-dense | | | | | | | not recorded |
| apg dense | gradient/lasso/apg/dense-f32/call | 1 / 10 |  |  | 9.67056e-05 | ok=1, target_missed=9 | excluded: not every run ok |
| cd dense | cd/lasso/cd/dense-f32/call | 10 / 10 | 5242.6 | [5041.96, 5443.24] | 3.57172e-07 | ok=10 | shown |
| cd sparse | cd/lasso/cd/sparse-f32/call | 10 / 10 | 5301.2 | [5053.68, 5548.72] | 3.57172e-07 | ok=10 | shown |
| pg acc-dense | | | | | | | not recorded |
| pg dense | gradient/lasso/pg/dense-f32/call | 4 / 10 |  |  | 0.00010668 | ok=4, target_missed=6 | excluded: not every run ok |
```

## Records and evidence

Each process writes `julia-<VERSION>-rep<NN>` files under `PS_OUTPUT` (two-digit reps).
TSVs have headers, empty missing fields, integer nanoseconds/bytes and round-trip floats:

| Suffix | Columns or contents |
|---|---|
| `-catalog.tsv` | `id group problem solver variant phase suite inputs issue measure target` |
| `-metrics.tsv` | `id group phase rep status samples ok_samples median_ns mean_ns sd_ns min_ns max_ns p95_ns gc_share median_bytes mean_bytes min_bytes max_bytes measure target worst_value median_value data_hash` |
| `-samples.tsv` | `id rep sample time_ns gc_ns bytes value status` |
| `-errors.tsv` | `id rep status exception stack`; one row per non-`ok` case. |
| `-profiles.txt` | Optional profiles when `PS_PROFILE_SECONDS > 0`. |
| `-metadata-start.toml`, `-metadata.toml` | Start provenance and final completion metadata. |

Metadata includes settings (including `case_filter`; records without it used no case
filter), Julia/BLAS/CPU identity, package root, revision and dirty status, and in current
records the ProximalBase manifest entry, the expected revisions, `capabilities` and
`deferred_cases` (see "Current core"; `validate.py` checks only the keys it requires).
SHA-1 hashes cover the four Julia harness files (`problems`, `certificates`, `cases`, `run`)
and each package's `Project.toml`, `src/**/*.jl` and `ext/**/*.jl`. ProximalBase has its
own version and source hash. SHA-256 data hashes match inputs per case/repetition. Final
metadata adds `cases`, `ok_cases`, `nonok_cases`, `elapsed_s`, `maxrss_bytes`, `finished=true`.
Preserve manifests and dirty sources with evidence. Existing process prefixes are never
overwritten; setup also refuses an existing environment `Project.toml`. Start metadata
without final metadata marks an interrupted process; retain it and restart in a fresh series.

Runner exit codes are 0 for all cases `ok`, 2 for complete records with non-`ok` cases,
and 3 for startup or record-writing failure. Validation checks integrity separately from
numerical success, so consistent failed cases can still be valid.

```sh
python3 benchmark/validate.py benchmark/results benchmark/results/validation.json
python3 benchmark/check_analysis.py
julia --project=benchmark/results/env-quick benchmark/check_certificates.jl
```

Pass `--expected-runs N` to `validate.py`, `summarize.py` and `compare.py` for repeated
series. Validation and summarization also accept `--versions VERSION ...`.
`summarize.py` writes `SUMMARY.md`
and `summary.csv`, retaining status counts and using the mean of repetition medians.
`cross_solver.py` takes the same `--expected-runs` and `--versions` (see "Cross-solver readout").
`check_analysis.py` tests synthetic records, including failures and interruptions. Generated
results, environments and profiles are ignored by Git. Put concise findings and limitations
in the pull request. Never select the fastest run or discard adverse runs.

## Restoring a solver

When a solver feature returns to the package, its existing cases need no new definitions:

1. Add its entries to `CAPABILITIES` in `cases.jl`, for example `"apg"` and `"apg:lasso"`, and
   `"apg:gap"` once its duality-gap stopping is back. `PS_LIST=deferred` shows what each case
   still lacks.
2. If its constructor or options changed, adapt `benchmark_method` (or `benchmark_options`);
   keep the historical settings where the API allows, since the settings define the case.
3. Run `PS_LIST=true`, then the cases with `local.jl` or `run.jl`, and check their certificates.
   A case whose solver runs but whose certificate needs a new problem kind needs a certificate
   in `certificates.jl` and a check in `check_certificates.jl` first.
4. For new current-core variants (another iterate or precision), follow `add_core_cases!`: new
   IDs, a target per precision chosen before measuring, and a requirement per feature.

APG's current-core cases followed step 4 (they reuse the PGD inputs, options and targets);
its historical `tight` cases stay deferred: the `call` phase needs `apg:gap`, the
`workspace` phase also `apg:workspace`.

Editing `cases.jl` changes the harness hash, so records before and after the change are not
comparable, by design. Add the new IDs to `test/benchmark_formal.jl`.

Historical studies for issues #18–#95 remain in the [pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark),
including comparisons with CoordinateDescent, glmnet, Lasso.jl, R packages,
SLOPE.jl/libslope and ProximalAlgorithms. External baselines are planned as optional
suites under `benchmark/external/` that reuse `problems.jl` and `certificates.jl` (#117).
