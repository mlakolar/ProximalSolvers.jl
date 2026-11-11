# Matched coverage probe for PR #242 review

The first full CI run at `2bcd11287a0c435cbea63b046a53c555f57701c6`
passed all mathematical/C0 assertions but failed the new test's assumption that
one Float32 cyclic fixture must always stagnate. The
[independent finding](https://github.com/mlakolar/ProximalSolvers.jl/pull/242#pullrequestreview-5854290355)
required comparison with the preserved implementation before changing the test.

The matched probes use PS `9be1773e911a44ec21d49df28cb01fea37c4316e`
and candidate `a457a0942338a936eb3b09cebed88d4743f365bc`, exact PB A
`e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`, Julia 1.13.3, default
bounds, normal inlining and one BLAS thread. Both source copies have the same
hashes as [the performance evidence](../minimal-core-performance/evidence.json).
Both PS source roots are instrumented together; PB is outside the coverage
prefix, matching Pkg.test(coverage=true)'s package-prefix policy.

| Policy | Historical and core outcome (identical) |
| --- | --- |
| No coverage | unconverged after 100000 passes; x=`Float32[.61142135,-.15817948]`; change=`9.117757f-10`; tolerance=`6.78233f-10`; minimum=`1.3069732f-5`; both warn |
| Package-prefix coverage | converged in 9 passes; x=`Float32[.6114212,-.15817945]`; change=`0f0`; tolerance=`6.78233f-10`; minimum=`1.306973f-5`; neither warns |

Both outcomes were reproduced with explicit `--cpu-target=native` and
`--cpu-target=znver3` on the local Intel raptorlake host. The second is an
explicit code-generation target, **not** a claim to have run on physical AMD
hardware. GitHub's failed run used an AMD EPYC 7763, default bounds and package
coverage. CPU-target changes alone did not reproduce its convergence; matched
coverage did, for both implementations. Instrumentation-dependent rounding
explains the fixture difference; no extraction divergence was observed.

The corrected new test accepts successful strict stopping with no warning, or
max-pass native stagnation with the exact warning. It retains all independently
computed KKT/scaling checks. C0 and solver source remain unchanged. Test-only
Logging supports public TestLogger/with_logger capture instead of relying on
private Test helpers. This does not add runtime logging architecture.

For reproduction, copy `probe.jl` into a scratch directory, extract historical
`src/` into `scratch/historical/` and candidate `src/` into
`scratch/candidate/` using `git archive`. Use an isolated PB-A environment with
a direct PrecompileTools dependency, as in the performance reproduction notes.
For each target (native and znver3), compare:

```sh
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --compiled-modules=no --cpu-target=znver3 --project=/path/to/PB-A-env /path/to/scratch/probe.jl
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --compiled-modules=no --cpu-target=znver3 --code-coverage=@/path/to/scratch --project=/path/to/PB-A-env /path/to/scratch/probe.jl
```

The probe refuses unequal old/core records. The committed logs preserve actual
loaded PB paths, targets, bounds and results; SHA256SUMS verifies the artifacts.
This correction makes no assertion about the separately deferred macOS C0
failure and changes no Linux C0 assertion.

After the correction, actual full Pkg.test sandboxes passed **2046/2046**
assertions under both policies: no coverage with bounds checking enabled, and
package-prefix coverage with default bounds. All 918 C0 assertions remain
unchanged. Solver source and the recorded performance-source digest are unchanged.
