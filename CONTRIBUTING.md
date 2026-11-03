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

CI and documentation builds use registered dependency resolution. A required
dependency version must be available from General before release validation
can pass. For optional dependency-source development checks, use:

```sh
julia scripts/test_master.jl
```

The runner creates an isolated environment with the package, dependencies and
test extras, and runs the suite with bounds checking. Arguments other than
`--setup-only` go to the test runner, as with `scripts/test.jl`. It preserves extra-only
workspace dependencies on Julia 1.10 and leaves the package's `Project.toml`
unchanged. This opt-in runner tests explicitly selected development sources;
it does not substitute for registered-dependency release validation.
