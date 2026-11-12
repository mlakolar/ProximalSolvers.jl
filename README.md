# ProximalSolvers.jl — minimal dense lasso core

Solve ordinary dense least-squares lasso with coordinate descent or proximal
gradient descent, using ProximalBase's loss and proximal operators.

```julia
using ProximalBase, ProximalSolvers
T = Float64                         # Float32 is also supported
X = T[1 0; 0 2; 0 0]
y = T[2, -2, .5]
f = (one(T)/T(length(y))) * LeastSquaresLoss(y, X)
g = NormL1(T(.1))
x = zeros(T, size(X, 2))
cd = solve!(x, f, g, CDSolver())
z = zeros(T, size(X, 2))
pg = solve!(z, f, g, ProximalGradientDescent(), ProximalOptions())
```

Raw `LeastSquaresLoss(y,X)` is `||y-X*x||²/2`, without 1/n. The solvers minimize
exactly the supplied objective; normalization is explicit. Supported arrays are
same-type Float32/Float64 Vector x/y and Matrix X, with positive consistent
dimensions, finite entries, one raw or valid positive Scaled LS wrapper, and
unweighted finite nonnegative NormL1. Positive parameters must stay positive
and finite in the working type. Arrays are not silently coerced. Detectable
x/data aliases, unsupported combinations and unsupported options fail before
caller mutation. X/y are borrowed read-only and must remain fixed during a solve.
Results share x; copy it to retain coefficients across later calls.

Convergence is a historical stopping flag, not a KKT certificate. Native
Float32 arithmetic limits accuracy; finite intermediate calculations are
required. CD refuses nonfinite returned objectives, without extreme-range
recovery. Deferred diagnostic fields are explicit sentinels (`gap=NaN`, CD
`kkt_checks=0`), not certificates.

This is an intentionally **breaking support reduction**. Sparse inputs/designs,
views, matrix responses, weights/intercepts/offsets, groups, general losses and
compositions, accelerated methods, Newton/ADMM/primal-dual/SLOPE/graphical models,
paths, screening, certificates, workspaces, refit and reweighting are deferred.
No release/version/registry decision has been made or release authorized.

Branch roles: master contains the reviewed minimal core; refactor/minimal-core
records its atomic reduction, and compat/minimal-core-pb-master isolates the PB
integration. legacy/full is the preserved full-package working reference. Protected `archive/full-before-reset-2026-11-10` and
`archive/pre-rebuild-2026-11-10` preserve full snapshot
`9be1773e911a44ec21d49df28cb01fea37c4316e`. Restore features selectively with
focused independent tests, never by merging legacy/full wholesale.

The current ProximalBase pin is
`c123d56ba1948e36a8fdbf183a9eea396a16e0d5`. The extraction baseline remains
`e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`; every CI run independently probes
both exact sources in isolated environments, including documentation-only and
nightly test-reuse runs. See [paired integration](docs/audit/minimal-core-pb-integration.md).
Existing release tags and preserved PRs are unchanged.

Current rebuild CI is stable Julia (`1`) on **Linux x64 only** for quick,
standard and full; nightly reuse is policy/provenance-aware and fail-closed.
macOS/Windows automatic jobs are temporarily disabled by separately approved
CI PR #241. Their absence is not platform validation. Historical measurements
and the deferred macOS C0 failure are preserved in the audit record.

[Examples](examples/README.md) · [Contributing](CONTRIBUTING.md) ·
[Test provenance](docs/audit/minimal-core-test-provenance.md) ·
[Extraction evidence](docs/audit/minimal-core-reduction.md) ·
[Transition issue #234](https://github.com/mlakolar/ProximalSolvers.jl/issues/234)
