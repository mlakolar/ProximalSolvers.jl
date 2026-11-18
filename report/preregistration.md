# #320 Phase 0: preregistered adverse set and analysis plan (fixed before any matrix run)

Written 2026-11-18, after the three-draw reproduction (interim note) and before the matrix jobs.

## Designs (all Float32 PGD with controls; draws 1 to 10; inputs = Float64 draw rounded once, harness `core_problem`, harness certificate)
Harness designs (unchanged ids and keys): `lasso` (100x32), `lasso-B` cold and warm (240x160, rho 0.8), `lasso-C` (800x120, rho 0.5), `lasso-D` (180x600).

Adverse set (keys `issue320/adv/*`, built with the harness's `regression_problem`; lambda = fraction * lambda_max):
| name | design | fraction | start |
|---|---|---|---|
| adv-cor-low-cold | 240x160, AR rho 0.8 (correlated) | 0.02 | cold |
| adv-cor-low-warm | same data | 0.02 | warm (solution at 1.25 lambda) |
| adv-equi-low-cold | 240x160, equicorrelated | 0.02 | cold |
| adv-ill-mid-cold | 240x160 independent, column scales spread over two decades (ill-conditioned) | 0.15 | cold |
| adv-ill-low-cold | same | 0.02 | cold |
| adv-ill-low-warm | same | 0.02 | warm |
| adv-wide-low-cold | 180x600 independent | 0.02 | cold |

## Controls
Float64 PGD (target 1e-8) and Float32 APG (target 1e-5) on the same problems; same targets as the harness, unchanged.

## Option profiles (all through the library, cross-checked bit for bit against the probe's trajectory)
D = `ProximalOptions()`; H = `benchmark_options(residual = true)` (the harness settings of the #320 records); S = strict stress (`ftol 0, xtol 1e-300, gradtol 1e-11, allow_f_increases`, maxiter 10_000); A = #314 research candidate (`accuracy_options()`: `ftol 0, xtol 1e-14, gradtol 1e-10, allow_f_increases`); Q = `ftol 0, xtol 1e-14, gradtol = target/100 (1e-7 in Float32, 1e-10 in Float64), allow_f_increases` (the #314 P2 profile; the one other candidate). Exploratory trajectory-derived sweep (not library-run): `ftol 0, xtol 1e-14, allow_f_increases, gradtol` in 1e-5, 1e-6, 1e-8.

## Classification rules (applied per record)
- false success: `converged = true` and independent gap above target.
- truthful nonconvergence: `converged = false` (stagnation, objective increase, maxiter) and gap above target.
- premature/rounding classes use the per-iteration trace: first proposing predicate, gate verdict, the iteration k* at which the target is first met.
- unattainable: the minimum gap over the trajectory of the profile is above target.

## Environments
Revisions: PS 637f06a (+PB c123d56), PS 9f86a80 (+PB 50db4b1), PS dac9f4b (+PB a19c59a). Julia 1.10.13 and 1.13.3. CPU: Intel Xeon E5-2640 v4 (the #319 report's CPU kind) for all; Intel Xeon Silver 4116 (AVX-512) additionally for master.
