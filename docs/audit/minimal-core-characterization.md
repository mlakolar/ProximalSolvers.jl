# Minimal-core characterization (C0)

C0 adds `test/minimal_core_characterization.jl` to the required quick tier. It
changes no solver code, existing feature support, dependency pin, CI workflow or
legacy test. The test file has its own module and independent reference helpers;
there is no helper excluded from test discovery. Planned input/option refusals
and the nonfinite CD result safeguard belong to the subsequent reduction PR.

Baseline source identities:

- ProximalSolvers: `9be1773e911a44ec21d49df28cb01fea37c4316e`.
- ProximalBase A: `e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.
- Initial local runtime: Julia 1.13.3, Linux x86_64, OpenBLAS (`libopenblas64_`),
  one BLAS thread, explicit `Xoshiro(713)` for trajectory fixtures.

The numerical oracle uses BigFloat signed-support enumeration only on tiny,
full-column-rank designs. It checks each candidate's signs and stationarity
conditions and picks its direct residual objective. It does not call PB prox,
PS residual caches, gradients or stopping helpers. Independent orthogonal
closed forms and zero-penalty QR check the enumerator. Float32 results are
checked in Float64 against the exact rounded data and supplied scalar scale.
Duplicate-column and zero-column cases check objective/KKT and fitted values,
not an arbitrary representative coefficient vector.

The first four deterministic CD and PGD iterates were recorded by executing the
unchanged baseline. Assertions use precision-specific rounding tolerances;
integer trial/evaluation counters, flags and explicit RNG state records remain
exact. Private pass/state observers delegate all numerical operations to the
existing implementation. The deliberate zero-curvature-state fault injection
checks rollback after an already accepted step; a separate public finite-data
fixture exercises actual curvature-growth failure.

Default PGD on the correlated fixture stops after 14 iterations via objective
change, with direct KKT around `1.03e-4`, above its `gradtol=1e-5`. This is a
characterized historical stopping contract, not a numerical certificate.
Strict-option solution checks use separate precision-aware accuracy bounds.
Float32's natural value-to-gradient mode switch is not assumed; the gradient
mode is also exercised directly, while Float64 demonstrates a natural switch.

## Reproduction

The normal runner includes this test in every quick/standard/full run:

```sh
julia --startup-file=no scripts/test.jl --tier=quick minimal_core_characterization
```

The focused local execution used a temporary environment with **both** the PS
workspace and the exact PB A extract as explicit path dependencies. It did not
modify the committed Project or manifest:

```sh
JULIA_DEPOT_PATH=/tmp/ps-c0-depot:/tmp/ps-stage2-pb-depot:/tmp/issue843-depot \
OPENBLAS_NUM_THREADS=1 /tmp/julia-1.13.3/bin/julia \
  --startup-file=no --compiled-modules=no --check-bounds=yes \
  --project=/tmp/ps-c0-focused-env test/minimal_core_characterization.jl
```

Focused local result: **890/890 assertions pass** across eight testsets;
`/tmp/ps-c0-focused.log` records the run. These assertions characterize the
unchanged algorithm, not the later reduced package.

The temporary manifest was copied from the audit's exact-A environment, with
only its PS path changed to the workspace. Loaded source paths and the source
SHAs must be recorded again for final-head CI/review. Temporary paths above are
session-specific; recreate them with `Pkg.develop` of the two exact source
paths when repeating elsewhere. No Julia LTS or full-platform result is claimed
by this local command; GitHub's unchanged required/full policy supplies the
current-stable platform gates. No LTS lane is added.

## Test provenance for later extraction

| Characterization area | Existing test/source provenance | C0 destination |
| --- | --- | --- |
| Orthogonal lasso, dense starts, warm starts, units, seeded order | `coordinate_descent_basics.jl`, `prox_solvers.jl` | Independent correctness and recorded CD testsets |
| Full/active scheduling and momentum | `cd/solver.jl`, `coordinate_descent.jl`, `group_momentum.jl` | Delegating pass observer and seeded dense prefixes |
| Residual/lazy-curvature state, zero column and underflow | `coordinate_descent_basics.jl`, `flat_coordinates.jl`, `cd/leastsquares.jl` | CD cache/flat/limit testsets |
| Native LS image/scalar behavior | `image_models.jl`, `mixed_precision.jl` | PGD initial state/image testset |
| Backtracking modes, zero-step current gradient and call counts | `linesearch.jl`, `call_limits.jl` | LS-only recorded trials and gradient-refresh testsets |
| Failed-step accepted-point rollback | `audit_regressions_basics.jl`, `solve.jl` | Numerical failure and private fault-injection testset |
| Trace/callback cadence, stopping flags, counts/limits | `prox_solvers.jl`, `call_limits.jl`, `utils.jl` | PGD limits/trace testset |
| Correlated independent reference and nonuniqueness | New independent mathematical controls | BigFloat enumeration, widened KKT and duplicate/null-column tests |

All original tests remain active in C0. The later reduction must map each
remaining old testset to a retained/extracted or explicitly deferred feature;
this table is initial provenance, not authorization to drop applicable tests.
