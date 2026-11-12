<!-- The general harness documentation, from benchmark/README.md of master 3c9241b (identical to
     the protected archive 9be1773e911a44ec21d49df28cb01fea37c4316e), with the current-core
     sections of #110 added: "Current core", "Supported and deferred cases" and "Restoring a solver". -->

# Benchmarks

This suite measures solver time and Julia heap allocation with accuracy checks independent
of solver stopping rules. It does not measure native (non-Julia) allocations or the
statistical quality of the estimates.
Peak memory is recorded only as process-wide `maxrss_bytes`, not per case.

## Current core

Master's core is `CDSolver` (dense `Vector` or vector `SparseIterate`) and
`ProximalGradientDescent` (dense `Vector`) on Float32/Float64 least-squares lasso, with
ProximalBase pinned to an exact development commit in the root `Project.toml` `[sources]`.
From the package root, with Julia 1.10 or later and Python 3.11 or later:

```sh
julia benchmark/setup.jl "$PWD" benchmark/results/env-quick pinned
JULIA_NUM_THREADS=1 PS_EXPECTED_PROXIMALBASE_REV=c123d56ba1948e36a8fdbf183a9eea396a16e0d5 \
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
full-package ones) keep the version and path modes. `PS_EXPECTED_PROXIMALBASE_REV` additionally
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
`solver:feature` (problem, `float32`, `sparse_iterate`, `gap` for duality-gap stopping,
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
stopping, `SolverWorkspace`, paths, setup phases, weighted or sparse designs, or other losses
and penalties.

The 30 current-core cases (`cd` and `gradient` groups) use one problem per design, shared by CD
and PGD, cold and warm starts, dense and `SparseIterate` iterates:

| Problem | Design | Suite | Variants |
|---|---|---|---|
| `lasso` | 100×32, independent columns (`regression_problem`, key `core/lasso`) | quick | CD `{dense,sparse}-{f64,f32}`; PGD `dense-{f64,f32}` |
| `lasso-B` | 240×160, correlated ρ=0.8 (inputs of `*/lasso-B/*/tight`) | quick | as above, and `warm-` of each |
| `lasso-C` | 800×120, correlated ρ=0.5 | extended | as `lasso` |
| `lasso-D` | 180×600, p > n | extended | as `lasso` |

Float32 inputs are the Float64 draw rounded once; the data hash covers the rounded values and
the start. A warm start is the solution at 1.25λ, computed in Float64 by the certificate
module's own coordinate descent (`cert_loading_refit`), so it does not depend on the solver
under test. The certificate is the least-squares lasso relative duality gap of the problem the
solver received, read back exactly in Float64 (`exact_problem`), from the returned minimizer
only. Targets are per precision for every solver: `1e-8` in Float64 (the threshold of the
#103–#109 B cases) and `1e-5` in Float32, about 50–100 times the gap of the exact solution
rounded to Float32 (5e-8 to 2e-7 on these designs). CD uses `order = :cyclic` and coefficient
tolerance `1e-11` (Float64) or `1e-6` (Float32); PGD uses `benchmark_options(residual = true)`.
PGD stops once the objective changes by less than one rounding unit, about √eps in the
coefficients (relative gaps near 1e-8 in Float64 and 1e-4 in Float32), so it misses these
targets on several designs; those cases are recorded as `target_missed` and excluded from
timing comparisons, with their accuracy kept. Where PGD stops is sensitive to rounding: with
`--check-bounds=yes` the small Float64 case ends at a gap of 1.7e-8 instead of 1.0e-9.

For example, list the extended gradient cases without measuring them:

```sh
PS_SUITE=extended PS_GROUPS=gradient PS_LIST=true \
  julia --project=benchmark/results/env-quick benchmark/run.jl
```

Each case builds its inputs from a seed keyed by its scenario and repetition, so a case
selected alone has the same inputs, data hash and certificate as in the full suite.
`PS_CASES='cd/lasso-B/cd/*-f64'` measures four of the 13 supported quick `cd` cases.

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
pslocal 'cd/lasso-B/cd/*-f64' --save before.local.tsv     # before editing src/
pslocal 'cd/lasso-B/cd/*-f64' --baseline before.local.tsv
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
  echo 'cd/lasso-B/cd/*-f64 --save before.local.tsv' >> commands.txt
  # edit src/, then:
  echo 'cd/lasso-B/cd/*-f64 --baseline before.local.tsv' >> commands.txt
  ```

  In a REPL, run `using Revise` and then `include("benchmark/local.jl")` before loading
  ProximalSolvers, then `explore("cd/lasso-B/cd/*-f64"; save = "before.local.tsv")`.

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

Editing `cases.jl` changes the harness hash, so records before and after the change are not
comparable, by design. Add the new IDs to `test/benchmark_formal.jl`.

Historical studies for issues #18–#95 remain in the [pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark),
including comparisons with CoordinateDescent, glmnet, Lasso.jl, R packages,
SLOPE.jl/libslope and ProximalAlgorithms. External baselines are planned as optional
suites under `benchmark/external/` that reuse `problems.jl` and `certificates.jl` (#117).
