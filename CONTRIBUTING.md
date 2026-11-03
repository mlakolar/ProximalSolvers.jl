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

`Pkg.test()` runs every file listed in `test/runtests.jl`, each in a fresh
module on one of several worker processes
([ParallelTestRunner](https://github.com/JuliaTesting/ParallelTestRunner.jl)),
with one Julia thread and one BLAS thread per worker. `julia scripts/test.jl`
runs the same suite with CI's options and passes its arguments to the runner:

```sh
julia scripts/test.jl --jobs=4          # four workers; PTR_NUM_JOBS=4 does the same
julia scripts/test.jl --jobs=1 admm     # one worker, only the files starting with admm
julia scripts/test.jl --verbose         # per-file compile times (Julia 1.11+)
julia scripts/test.jl --list            # the test files
```

Through `Pkg`, use `Pkg.test(; test_args=["--jobs=2"])`. Without `--jobs`, the
runner picks the number of workers from the CPU threads and free memory. Each
file starts from `Random.seed!(1)`, whatever ran before it on the same
worker. A failing file is reported by name, the other files still run, and the
run fails. A name that matches no file is an error rather than an empty
passing run. Add a new test file to the list in `test/runtests.jl`: an unlisted
or missing file stops the run before any test starts. `test/TESTING.md`
records the inventory and the measurements behind CI's worker counts.

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
