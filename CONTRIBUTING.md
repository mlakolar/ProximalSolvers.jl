# Contributing

Use `UpperCamelCase` for modules and types, `snake_case` for descriptive
functions, fields and keyword arguments, and a trailing `!` for mutating
functions. Retain established Julia interface names, familiar numerical
abbreviations such as `maxiter`, and mathematical identifiers such as `X`
and `λ`. Deprecated names are compatibility exceptions, not examples for
new code.

Develop and test against local `master` checkouts of workspace dependencies,
including ProximalBase. Active package, documentation and benchmark
environments specify those checkouts with relative `[sources]` paths. Run
`julia scripts/instantiate.jl` from the package root to develop the full master
stack explicitly on Julia 1.10 and newer. Use
`julia scripts/instantiate.jl docs` for the documentation environment.
Frozen historical benchmark workers retain their original package names and
version pins; they are independent baselines, not development dependencies.

Keep package version numbering unchanged during this migration.

Run the complete tests with:

```sh
julia scripts/test_master.jl
```

The runner creates an isolated environment with the package, dependencies and
test extras, and runs the suite with bounds checking. It preserves extra-only
master dependencies on Julia 1.10 and leaves the package's `Project.toml`
unchanged. This is the development test command used by CI.
