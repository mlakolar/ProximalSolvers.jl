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

The optional workspace helpers prepare package, documentation and benchmark
environments from existing sibling checkouts; missing dependencies are cloned
from `master`. They validate package identity and UUID, but do not require a
particular branch or change an existing checkout. Record dependency commits
and dirty source hashes when reporting validation. A version string does not
identify an unreleased source edition. Julia 1.10 ignores `[sources]`, so use
explicit `Pkg.develop` calls there. The package itself has no local path source
requirement. Historical benchmark workers retain their original pins.

Keep package version numbering unchanged during this migration.

Run the complete tests with:

```sh
julia scripts/test_master.jl
```

The runner creates an isolated environment with the package, dependencies and
test extras, and runs the suite with bounds checking. It preserves extra-only
workspace dependencies on Julia 1.10 and leaves the package's `Project.toml`
unchanged. This is the development test command used by CI.
