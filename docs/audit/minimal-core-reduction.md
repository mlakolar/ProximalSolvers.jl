# C1–C3 minimal-core reduction evidence

Local extraction evidence for the atomic reduction under
[issue #234](https://github.com/mlakolar/ProximalSolvers.jl/issues/234).
The PR and issue carry the exact-head independent review, required GitHub checks
and merge outcome. This record does not authorize a release or claim that
removed legacy algorithms still work.

## Provenance and scope

- Preserved full PS: `9be1773e911a44ec21d49df28cb01fea37c4316e`.
- C0 [#239](https://github.com/mlakolar/ProximalSolvers.jl/pull/239) merge:
  `3181968cb9b3987785b57ef929a77c95eda1c5e7`.
- Linux-only CI [#241](https://github.com/mlakolar/ProximalSolvers.jl/pull/241)
  merge/base: `428f7723c2c2b9f579418d3519e52fffc3ddd9f4`.
- Frozen implementation tested/measured: `a457a0942338a936eb3b09cebed88d4743f365bc`.
- Exact PB A throughout extraction: `e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.

The PB source used locally was compared byte-for-byte with a fresh immutable
upstream archive and the corresponding Git blobs. The benchmark checks its
loaded source digest; [complete identities and raw evidence](minimal-core-performance/README.md)
are committed. Evidence additions after the frozen implementation do not change
its `src` tree. Claude models were unavailable; disclosed Codex substitutes
implemented the extraction, with a separate GPT-6.1-Sol high reviewer required.
No archives, legacy/full, PB source or existing preserved PR were modified.

The 39-file full source tree becomes these 12 files (1,406 source lines):

```text
src/ProximalSolvers.jl
src/types.jl
src/blocks.jl
src/line_searches.jl
src/solve.jl
src/utils.jl
src/precompile.jl
src/solvers/image_models.jl
src/solvers/proximal_gradient_descent.jl
src/cd/models.jl
src/cd/solver.jl
src/cd/leastsquares.jl
```

CD retains the private PB SparseIterate, active storage/compaction, seeded
Fisher–Yates order, first/full/active scheduling, default momentum/restarts,
residual and lazy-curvature order, fused scalar prox, strict stopping and dense
scatter. The separately identifiable `1faf68b` commit refuses nonfinite final
objectives before scatter, including reachable Inf and NaN regressions.
PGD retains native LS image buffers, evaluation order, fused vector prox, both
TFOCS modes, gradient refresh, curvature failures, accepted-point rollback,
FASTA/x/objective OR stopping, counters, tracing and callbacks. Identity metric
helpers were extracted without changing their computation. Deferred algorithms
and their source dependencies leave the active branch without stubs.

## Public boundary

```julia
solve!(x, f, g, CDSolver())
solve!(x, f, g, ProximalGradientDescent(), ProximalOptions())
```

Only same-type `Vector{T}` x/y and `Matrix{T}` X, `T=Float32` or `Float64`,
with positive matching dimensions and finite entries are supported. Use raw
`LeastSquaresLoss(y,X)` or one positive finite scalar wrapper and unweighted
`NormL1` with finite nonnegative scalar lambda. Raw LS remains unnormalized;
normalized lasso uses `(one(T)/T(n))*LeastSquaresLoss(y,X)`. Existing accepted
scalar conversion sites remain unchanged. Nonzero scalar parameters must remain
positive and finite in T; arrays are not coerced.

Validation occurs once at public solve entry, before caller mutation. Shape
errors use DimensionMismatch; unsupported types/features/options and aliases
use informative ArgumentErrors. X/y are borrowed read-only during a solve;
results share x. Sparse/view/matrix iterates, non-Matrix designs, mixed arrays,
weighted penalties, other losses/compositions, intercept/offset requests and
deferred solver options are refused. Positional construction cannot bypass
deferred-option or ordinary option validation.

CDSolver, ProximalGradientDescent, ProximalOptions, CDResults, qualified
OptimizationResults and relevant accessors remain. Gap/certificate compatibility
fields are sentinels: gap=NaN and CD kkt_checks=0. Convergence is the historical
stopping flag, separate from independently measured KKT accuracy. Numerical
accuracy assumes finite representable intermediate quantities; dynamic-range
recovery and a new stopping/certificate engine are deferred.

## Validation and test provenance

The actual Pkg.test sandbox passed **2,046/2,046** assertions on Linux x64,
Julia 1.13.3, one BLAS thread and two test workers. After the independent
review correction, the complete sandbox passed again both without coverage
(bounds checking enabled) and with package-prefix coverage (default bounds):

| Test file | Passed |
| --- | ---: |
| minimal_core_characterization | 918 |
| core_contracts | 363 |
| core_regressions | 341 |
| examples | 2 |
| aqua | 11 |
| ci_gate | 139 |
| naming | 5 |
| tier_selection | 267 |

C0 remains byte-for-byte unchanged. It includes independent orthogonal formulas,
BigFloat support/sign enumeration for tiny full-rank designs, widened Float32
objective/KKT checks, nonunique cases, seeded trajectories/RNG ownership,
backtracking/counts/rollback and ordinary observations. The new tests add the
support boundary, Inf/NaN refusal and applicable legacy numerical regressions.
The [complete provenance map](minimal-core-test-provenance.md) accounts for
every old test-tree file and identifies retained, extracted and deferred cases.

Eight historical/candidate scaled-CD cases additionally matched exactly for
coefficients, passes, change/tolerance, objective and widened KKT. One Float32 cyclic q=.01 case has an existing instrumentation-dependent
outcome: 100,000-pass stagnation without coverage and 9-pass convergence with
coverage. Matched historical/core probes reproduce identical results under
each policy. The corrected new regression checks strict stopping/no warning
or bounded stagnation/exact warning, plus independent accuracy/scaling.
[Matched source/compile-policy evidence](minimal-core-coverage-probe/README.md)
records the independent review finding and its test-only correction. A new draft assertion that default tol=1e-7 implied Float64
machine-epsilon KKT accuracy was corrected after exact historical reproduction;
no C0 assertion or algorithm tolerance was changed.

Normal Pkg.precompile and package loading passed, including both solver
workloads. Documentation passed doctests, cross-references and checkdocs=:exports;
two runnable lasso examples passed. Naming and all benchmark analysis controls
passed. Example local commands, using an isolated environment with exact PB A:

```sh
julia --startup-file=no --compiled-modules=no --check-bounds=yes --project=/path/to/env -e 'using Pkg; Pkg.test("ProximalSolvers"; julia_args=["--startup-file=no","--compiled-modules=no","--check-bounds=yes"], test_args=["--tier=full","--jobs=2"])'
julia --startup-file=no --compiled-modules=no --project=/path/to/docs-env docs/make.jl
julia --startup-file=no --project=/path/to/env -e 'using Pkg; Pkg.precompile(); using ProximalSolvers, ProximalBase; println(pathof(ProximalBase))'
```

The runtime dependencies and PB pin are unchanged. Unused Statistics test extras
and unused documentation dependencies were removed; test-only Logging supports
public warning capture for the coverage-dependent regression. Package identity/version
remain unchanged; this breaking support reduction is not a patch release.

## Controlled performance comparison

Same-process old/old control followed by old/candidate; exact shared PB A,
Julia 1.13.3, OpenBLAS ILP64, one Julia/BLAS thread, raptorlake CPU. Fresh x/RNG
setup is outside timing; all solve validation is inside. Each of eight fixed
correlated zero-start/default-option cases uses four warm batches and 12
balanced randomized ABA/BAB triplets (18 samples per module). No other test
workload ran during measurement. No CPU affinity is imposed.

All 288 final records per session match across modules, including point and
minimum bits, counts, flags and residuals; all 32 paired finite trajectory steps
match. Independently widened objective/KKT are recorded. This is preservation
evidence on this grid; independent C0 oracles establish separate correctness.

Times are microseconds per call. Ratio is candidate/baseline; the bracketed
ratio compares each middle sample with its two surrounding samples. IQR is
descriptive dispersion, not a confidence interval. Allocation counts average
timed batches; input/RNG setup is excluded in both modules.

| Type | n × p | Solver | Old μs | Core μs | Median ratio | Bracketed median [IQR] | Old → core bytes |
| --- | --- | --- | ---: | ---: | ---: | --- | ---: |
| Float32 | 128 × 32 | CD | 7.221 | 5.779 | 0.8003 | 0.8146 [0.7693, 0.8847] | 4659.2 → 3891.2 |
| Float32 | 128 × 32 | PGD | 11.175 | 11.612 | 1.0391 | 1.0598 [0.9560, 1.0798] | 2528 → 2512 |
| Float32 | 1024 × 256 | CD | 131.580 | 67.768 | 0.5150 | 0.5268 [0.4829, 0.5745] | 26412.8 → 24716.8 |
| Float32 | 1024 × 256 | PGD | 503.147 | 517.722 | 1.0290 | 1.0260 [1.0187, 1.0322] | 14352 → 14336 |
| Float64 | 128 × 32 | CD | 8.598 | 8.066 | 0.9382 | 0.9609 [0.8436, 1.0067] | 7092 → 6180 |
| Float64 | 128 × 32 | PGD | 16.372 | 17.092 | 1.0440 | 1.0500 [0.9660, 1.1201] | 4288 → 4272 |
| Float64 | 1024 × 256 | CD | 179.811 | 129.247 | 0.7188 | 0.7306 [0.6887, 0.7915] | 44736 → 42024 |
| Float64 | 1024 × 256 | PGD | 1269.037 | 1316.008 | 1.0370 | 1.0220 [0.9986, 1.0517] | 27576 → 27560 |

CD allocations fall about 6–16.5%; the larger timing improvement includes
replacing historical scalar finite-data validation with the equivalent SIMD
boundary check. Numeric coordinate loops are unchanged. PGD allocates 16 fewer
bytes. Moderate Float64 PGD's bracketed ratio 1.022 overlaps its old/old control
IQR 0.9703–1.0513; small timings have broad control dispersion.

**Moderate Float32 PGD retains a small stable overhead:** bracketed median
1.0260, IQR 1.0187–1.0322, versus control median 0.9989, IQR 0.99235–1.00540.
The median-of-times ratio is 1.0290. This is consistent with the mandatory new
once-per-solve finite matrix scan, which historical PGD lacked. It is disclosed
for independent review, not labelled zero regression. No validation was removed
or arithmetic changed to improve the numbers. An earlier pre-SIMD ~15% estimate
lost raw artifacts during a host reset; it is not used as current acceptance
evidence and absolute times are not compared across hosts. The committed
[complete raw records, hashes and executed harness](minimal-core-performance/README.md)
allow these conclusions to be inspected without another benchmark run.

## CI and deferred work

Quick/standard/full remain cumulative coverage tiers on Julia `1`, Linux x64
only. Required PR required jobs and PR merge gate, fail-closed discovery,
nightly policy/environment evidence, master full validation, coverage and
benchmark controls remain. The workflow, CI scripts, CI-gate test, generic
runner/tier engine and C0 are byte-identical to the Linux-only baseline;
only the supported inventory, risk rules and feature fixtures change.

The [historical C0 macOS failure](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/42949840807)
remains unresolved and deferred: Linux and Windows passed; macOS failed the
warm-start convergence assertion. Linux assertions were not weakened, and no
algorithm defect or portability fix is claimed. Historical
[platform/test records](historical-full-testing.md) and
[full-package measurements](historical-full-performance.md) remain labelled.

C4 must separately refresh and pin current PB master, run exact-source A/B
numerical/contract diagnostics without version-only cache skipping, obtain
independent review and pass Linux gates after the reduced master is green.
Existing PRs #134/#231/#233/#237 and working-sets remain preserved for selective
later restoration. Platform expansion and release/version/registry policy need
separate maintainer decisions. Umbrella issue #234 remains open.
