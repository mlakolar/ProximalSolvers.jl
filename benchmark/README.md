# Benchmarks

This suite measures solver time and Julia heap allocation with accuracy checks independent
of solver stopping rules. It does not measure native (non-Julia) allocations or the
statistical quality of the estimates.
Peak memory is recorded only as process-wide `maxrss_bytes`, not per case.

## Setup and selections

From the package root, with Julia 1.10 or later and Python 3.11 or later:

```sh
julia benchmark/setup.jl "$PWD" benchmark/results/env-quick 0.5.4
JULIA_NUM_THREADS=1 julia --project=benchmark/results/env-quick benchmark/run.jl
python3 benchmark/summarize.py benchmark/results benchmark/results/summary
```

`setup.jl` instantiates a fresh environment with this checkout and a ProximalBase version
or path. The default is one quick Float64 repetition: exploratory, with no between-run interval.

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
| `PS_LIST` | `false` | `true` prints selected `id`, `suite`, `issue` without data or records. |

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

For example, list the extended gradient cases without measuring them:

```sh
PS_SUITE=extended PS_GROUPS=gradient PS_LIST=true \
  julia --project=benchmark/results/env-quick benchmark/run.jl
```

Each case builds its inputs from a seed keyed by its scenario and repetition, so a case
selected alone has the same inputs, data hash and certificate as in the full suite.
`PS_CASES='cd/lasso-dense/cd/B/*'` measures two cases instead of the 20 of `cd`.

## Local exploration

`local.jl` is a development aid: it decides whether a change is worth pursuing, not whether
it is faster. It runs selected cases through the same `make`/`reset!`/`call!`/`certify`
closures, validation call, `observe!` timing and statuses as `run.jl`, but writes no
records. Its output and optional TSV are labelled exploratory; `validate.py` and
`compare.py` do not accept them. Claims of improvement or noninferiority need the formal
comparison below.

```sh
julia benchmark/setup.jl "$PWD" benchmark/results/env-local 0.5.4    # once per checkout
export JULIA_NUM_THREADS=1
alias pslocal='julia --project=benchmark/results/env-local benchmark/local.jl'
pslocal --list 'cd/*'                                     # case IDs, no measurement
pslocal 'cd/lasso-dense/cd/B/*' --save before.local.tsv   # before editing src/
pslocal 'cd/lasso-dense/cd/B/*' --baseline before.local.tsv
```

Quote patterns in the shell. For each case, a `CHECK` line gives the certificate of the
first (validation) call as soon as it finishes. The report then gives the status, the
first call (with compilation), the median and minimum of the timed samples (at most 25 by
default, stopping after 0.5 timed seconds once three are taken, against five in `run.jl`;
see `--help`), the allocation per call,
the certificate against its target and solver work counters read after timing. A
baseline adds the candidate/baseline median ratio, the absolute change per call and the
ratio of minimum times. A ratio is withheld unless the case, data hash, harness, Julia
version, CPU model and ProximalBase all match and both runs are `ok`. Within about 10%, a
ratio is typical run-to-run noise. Other processes inflate medians more than minima: when
the two ratios differ by more than 10%, or the header warns that the load average exceeds
half the CPU threads, rerun on a quieter machine. A non-`ok` status reports the failure and no timing; the exit status is
2, as in `run.jl`.

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
  touch commands.txt
  tail -f commands.txt | julia --project=benchmark/results/env-local \
    benchmark/local.jl --session > session.log 2>&1 &
  echo 'cd/lasso-dense/cd/B/* --save before.local.tsv' >> commands.txt
  # edit src/, then:
  echo 'cd/lasso-dense/cd/B/* --baseline before.local.tsv' >> commands.txt
  ```

  In a REPL, run `using Revise` before `include("benchmark/local.jl")`, then
  `explore("cd/lasso-dense/cd/B/*"; save = "before.local.tsv")`.

Before each run, a session applies every source file whose content changed since the last
run, without waiting for Revise's file events, and runs in the latest world. A changed
file that Revise cannot apply (for example a struct redefinition), or any edit without
Revise, stops the run with a request to restart. A harness edit also requires a restart.
Each run rebuilds its inputs and solver state. Session timings are exploratory:
compilation, garbage collection and memory state differ from a fresh process.

On one machine for #110 (Apple M3 Pro, Julia 1.13), an edit followed by one quick case took
13–21 s with `PS_GROUPS` or a fresh `local.jl` process, about 7.5 s with
`--compiled-modules=existing`, and 0.2–0.8 s in a session after a one-time start of about
7.5 s. `benchmark/check_local.jl` checks selection, input independence, statuses, baselines
and session commands.

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

Use one fixed harness copy from the same root, with two fresh environments and the same ProximalBase spec:

```sh
before=/absolute/path/to/before
after=/absolute/path/to/after
base_spec=0.5.4
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
filter), Julia/BLAS/CPU identity, package root, revision and dirty status.
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

Historical studies for issues #18–#95 remain in the [pre-cleanup tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark),
including comparisons with CoordinateDescent, glmnet, Lasso.jl, R packages,
SLOPE.jl/libslope and ProximalAlgorithms. External baselines are planned as optional
suites under `benchmark/external/` that reuse `problems.jl` and `certificates.jl` (#117).
