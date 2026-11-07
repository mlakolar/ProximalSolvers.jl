# Contributing

Use `UpperCamelCase` for modules and types, `snake_case` for descriptive
functions, fields and keyword arguments, and a trailing `!` for mutating
functions. Retain established Julia interface names, familiar numerical
abbreviations such as `maxiter`, and mathematical identifiers such as `X`
and `λ`. Deprecated names are compatibility exceptions, not examples for
new code.

Use standard Julia `Pkg` environments to select dependencies explicitly:

```sh
julia --project=. -e 'using Pkg; Pkg.develop(path="../ProximalBase.jl"); Pkg.instantiate(); Pkg.test()'
```

The optional workspace helpers prepare package and documentation
environments from existing sibling checkouts; missing dependencies are cloned
from `master`. They validate package identity and UUID, but do not require a
particular branch or change an existing checkout. Record dependency commits
and dirty source hashes when reporting validation. A version string does not
identify an unreleased source edition. Julia 1.10 ignores `[sources]`, so use
explicit `Pkg.develop` calls there. The package itself has no local path source
requirement. For benchmarks, use the benchmark harness in `benchmark/`.

Run the release test suite against registered dependencies with:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

`Pkg.test()` runs every test file, each in a fresh module on one of several
worker processes
([ParallelTestRunner](https://github.com/JuliaTesting/ParallelTestRunner.jl)),
with one Julia thread and one BLAS thread per worker. `test/tiers.toml` puts
each file in one of three cumulative tiers:

- **quick**: the central solver contracts on representative problems, checked
  numerically (a few minutes);
- **standard**: quick and every solver family in depth;
- **full**: everything, including the exhaustive grids and the examples. This
  is what `Pkg.test()` runs.

`julia scripts/test.jl` runs the suite with CI's options and passes its
arguments to the runner:

```sh
julia scripts/test.jl --tier=quick      # quick; --tier=standard, --tier=full
julia scripts/test.jl --tier=quick --extra=workspaces,coordinate_descent
julia scripts/test.jl --jobs=4          # four workers; PTR_NUM_JOBS=4 does the same
julia scripts/test.jl --jobs=1 admm     # one worker, only the files starting with admm
julia scripts/test.jl --verbose         # per-file compile times (Julia 1.11+)
julia scripts/test.jl --list            # the test files and their tiers
```

Through `Pkg`, use `Pkg.test(; test_args=["--tier=quick", "--jobs=2"])`.
Without `--tier` every file runs; without `--jobs` the runner picks the number
of workers from the CPU threads and free memory. Run the files you changed with
`--extra`, whatever their tier. Each file starts from `Random.seed!(1)`,
whatever ran before it on the same worker. A failing file is reported by name,
the other files still run, and the run fails. A name that matches no file is an
error rather than an empty passing run. Add a new test file to one tier in
`test/tiers.toml`: an unclassified, missing or duplicated file stops every run
before any test starts. `test/TESTING.md` records why each file sits in its
tier and the measurements behind the tiers and CI's worker counts.

## Continuous integration

A pull request runs the tier its changes need, chosen by the rules in
`.github/tier-rules.toml` (each changed path takes the first rule that matches
it, and the PR gets the highest tier):

- **quick**, with every changed test file beside it: test-only changes and the
  examples;
- **standard**, with the full-only test files that exercise the changed code
  (the rule's focus files): a change to one solver, loss model or path driver;
- **full**: shared solver architecture (solver types, the solve driver,
  workspaces, line searches, the coordinate-descent passes), convergence and
  certification code (stopping tests, duality gaps, screening, certificates,
  paths), native code (the direct LAPACK call in `src/cd/groupcurvature.jl`),
  the test runner, CI, `Project.toml`, `test/tiers.toml`, and any path no rule
  knows;
- **no package tests** when every changed path needs none: documentation,
  benchmarks (their analysis controls run anyway), `test/oracles/` and the
  scripts and workflows that are not part of the package tests.

Quick and standard run Julia 1.10 and 1 on Ubuntu; full adds macOS and Windows,
and its Julia 1 Ubuntu job collects coverage for Codecov. The plan, the naming
check and the benchmark analysis controls run on every PR. To see what CI will
choose before pushing:

```sh
julia scripts/ci_plan.jl                     # your working tree against origin/master
julia scripts/ci_plan.jl --labels=test:full  # with a label
```

The labels **test:standard** and **test:full** raise a PR's tier and never
lower it; removing one returns the PR to the tier of its paths. Add one when a
change is riskier than its paths suggest, for example a change in a loss model
that alters a certificate. To add a regression test without a full run, add a
new test file and its line in `test/tiers.toml`: a change to the tier lists that
only adds files new in the PR keeps the PR's tier, and the new file runs beside
it. Any other edit of `test/tiers.toml` runs full.

Once branch protection requires them (see `test/TESTING.md`), two checks
decide whether a PR may merge: **PR required jobs** and **PR merge gate**. PR required jobs runs after the plan, the tests and the benchmark
analysis controls, and passes only if they all passed: every test job of the
chosen tier must pass in its latest attempt, so a failed, cancelled, skipped or
missing job fails it, as does a plan that found an unclassified test file. It
also reads the PR's labels and fails if one asks for more than the run's plan
chose. (GitHub counts the checks of the run created last, so re-running an
older run does not replace a newer run's result; the label check makes that
explicit.)
The gate starts with the run, so a push or a label replaces the commit's earlier
gate with a pending one within seconds; it waits for the run's PR required jobs
and passes only if they passed. Pushes, the nightly run and manual runs name the
checks **CI required jobs** and **CI result**, so a manual run on a PR branch
cannot stand in for the PR's checks.

To retry jobs of a PR run:

- **Re-run failed jobs** re-runs the failed jobs, PR required jobs and, if it
  failed, the gate; the PR stays blocked until the new results pass. If only
  the gate failed (for example on a GitHub API outage), it re-runs only the
  gate, which then takes the run's PR required jobs result.
- **Re-run all jobs** starts the whole run again, with a pending gate and a
  new plan that reads the PR's current labels.
- **Re-run job** on one test job re-runs it and PR required jobs, but not the
  gate. The PR is blocked while the job runs and stays blocked if it fails.
  After a failed run, the gate keeps its failure even when the re-run passes;
  then use **Re-run failed jobs**, which re-runs only the gate. (ProximalBase
  #430 observed this, #468, and the gate-only re-run, #470; the scenarios here
  covered the other cases.)

Every push to master and every tag (release) runs full on all four platforms.
A nightly run checks master again with full, unless a run that passed full on
the same commit less than a day earlier tested the same Julia versions and
dependency versions (`scripts/ci_environment.jl` records them). Manual runs
(`gh workflow run CI.yml --ref <branch> -f tier=standard`) take a tier, full by
default. **When a master, tag or nightly run fails**, the workflow opens (or
comments on) the issue "CI failing on master": fix the regression or revert the
PR that caused it promptly. A PR that merged after quick or standard is not at
fault for passing its gate; the full run after the merge exists to catch what
the smaller tiers leave out. Each test job's summary lists the selected files,
the workers, the setup time and the worker time of every file.

CI and documentation builds use registered dependency resolution. A required
dependency version must be available from General before release validation
can pass.

**ProximalBase 0.6 (development).** The package requires ProximalBase 0.6, which is not
registered yet, so `Project.toml` and `docs/Project.toml` pin the development commit
through `[sources]` (read by Julia 1.11 and later) and `Manifest-v1.10.toml` pins the same
commit for Julia 1.10, which ignores `[sources]` and reads versioned manifests only from
1.10.8, so the minimum Julia version is 1.10.8 meanwhile. CI and the documentation build then
resolve exactly that commit. When ProximalBase 0.6.0 is registered, remove both
`[sources]` entries, `Manifest-v1.10.toml`, its `.gitignore` exception and the raised Julia
minimum (`julia = "1.10"`); until then the
package cannot be released from `master`.

The package reads iterates only through the public interface of ProximalBase 0.6
(`atomindices`, `activecoordinates`, `activevalues`, `nactive`, `ProximalBase.samegroups`,
and the five-argument `prox_coordinate!(x, g, k, u, γ)` for a block step at a trial point).
The fields of `SparseIterate` and `AtomIterate` are private and may change in any release;
`test/audit_regressions_basics.jl` scans `src/` for them. This is the preparation for
ProximalBase 0.6, not a promise of compatibility with ProximalBase 0.5. For optional dependency-source development checks, use:

```sh
julia scripts/test_master.jl
```

The runner creates an isolated environment with the package, dependencies and
test extras, and runs the suite with bounds checking. Arguments other than
`--setup-only` go to the test runner, as with `scripts/test.jl`. It preserves extra-only
workspace dependencies on Julia 1.10 and leaves the package's `Project.toml`
unchanged. This opt-in runner tests explicitly selected development sources;
it does not substitute for registered-dependency release validation.
