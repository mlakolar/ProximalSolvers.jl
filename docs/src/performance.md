# CoordinateDescent comparison

## Summary

This page compares the time CoordinateDescent 0.6.1 (legacy) and
HighDimensionalModels on ProximalSolvers (current) take to reach the same
certified accuracy, a relative duality gap of at most `1e-4`. Ratios are
current/legacy time, so a ratio below 1 means current is faster. Over the 82
of 88 cases that reach the target on both sides, the like-for-like ratio is
0.977 [0.955, 1.00] (12 blocks, campaign of 2026-10-28). Current's best stopping
rule gives 0.845, and the package defaults give 0.897.
The path is faster only on design C (0.150), where current uses the Gram path;
on designs A, B and E it is within 2% of legacy. The square-root, scaled and
weighted lasso groups are 7–14% slower.

No case is a candidate regression. The A/A noise floors are wide (0.516, 0.507
and 0.436 on the log scale for the three views), so differences of that size
remain inconclusive, and an inconclusive result is not a tie.

## What is compared

| Arm | Packages and source |
|---|---|
| Legacy | CoordinateDescent 0.6.1; ProximalBase 0.4.1. |
| Current | HighDimensionalModels `047c4193764b4171c659f4c649bbee8bf1df65fb`; ProximalSolvers `78f7d6200ff4bd0923b56ef1efe6e93127d01a29`; ProximalBase 0.5.4. |
| Current A/A | The same source, locked environment, settings and seeds as current, in separate fresh processes. |

The measurements use Julia 1.13.3, OpenBLAS through
libblastrampoline (ILP64), one Julia thread and one BLAS thread, on a shared
machine with an AMD EPYC 9754 CPU. Each arm runs in a fresh process. The timed
operation is the compiled public-API call, including model construction,
initialization and result conversion inside it. It measures the whole package
stack. Compilation, input generation and certification are outside timing.
The quadratic cases also exclude preparation of `X'X/n` and `-X'y/n`.

The matched target is a certified relative duality gap at most `1e-4`, or a
feasible-lasso self-consistency value at most `1e-4`. The latter is the
weighted-lasso gap at loadings recomputed from the returned coefficients'
residuals, not a convex certificate for the whole iterative procedure.
In the design A canary records at like-for-like settings, the largest
coefficient error relative to the converged solution is 1–5 times the relative
gap. This is an empirical observation on those records, not a general error bound.

The inputs are designs A, B, C and E: independent Gaussian columns for A,
AR(1) correlation for B and C, and equicorrelation for E. The extended design D
is outside this campaign. Cases cover the lasso, fixed weighted lasso, full
lasso paths, quadratic L1, group lasso, square-root lasso, scaled lasso and
feasible lasso, with cyclic and random coordinate orders. There is no intercept
or standardization in the API calls; input columns have fixed normalization.
The [comparison suite README](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/external/README.md) specifies the inputs, objectives,
settings, certificates and execution commands.

## Results

The primary view compares each side's calibrated coordinate-family setting at
the matched target. The secondary view allows current's best qualifying setting
across coordinate and gap families, against the same legacy setting.
Calibration uses one block and selects settings before confirmation; the frozen
selection SHA-256 is `c21659a05e1c2308113bc55cd2e1d9f8cdc6afb2473b93baebebdbc8be328daa`.
Current retains its public automatic Gram policy, including the Gram path on
design C. These are public-API comparisons, including that policy.

Case ratios exponentiate the mean of paired block log ratios; their intervals
are 95% Student-t intervals. Groups weight eligible cases equally on the log
scale and use whole-block bootstrap intervals with 10,000 resamples and seed
117. The comparison tables use three significant digits for ratios and interval
endpoints. Rounded
endpoints do not determine screening decisions; those use the unrounded records.

### Primary matched view

| Group | Current/legacy | 95% interval | Eligible / total | Excluded cases |
|---|---|---|---|---|
| `all` | 0.977 | [0.955, 1.00] | 82 / 88 | All six listed below |
| `feasible_lasso` | 1.02 | [0.981, 1.06] | 6 / 8 | `feasible_lasso/A/0.02lmax/cyclic`; `feasible_lasso/A/0.02lmax/random` |
| `group_lasso` | 0.915 | [0.882, 0.961] | 8 / 8 | None |
| `lasso` | 0.992 | [0.966, 1.01] | 16 / 16 | None |
| `path` | 0.620 | [0.612, 0.629] | 8 / 8 | None |
| `quadratic` | 1.01 | [0.981, 1.03] | 16 / 16 | None |
| `scaled_lasso` | 1.14 | [1.05, 1.26] | 6 / 8 | `scaled_lasso/A/0.02lmax/cyclic`; `scaled_lasso/A/0.02lmax/random` |
| `sqrt_lasso` | 1.12 | [1.06, 1.19] | 6 / 8 | `sqrt_lasso/A/0.02lmax/cyclic`; `sqrt_lasso/A/0.02lmax/random` |
| `weighted_lasso` | 1.07 | [1.02, 1.12] | 16 / 16 | None |

The square-root lasso (1.12), scaled lasso
(1.14) and weighted lasso
(1.07) group intervals lie above 1 but well inside
the noise band. They are not confirmed regressions. The targeted follow-up is
[issue #137](https://github.com/mlakolar/ProximalSolvers.jl/issues/137).

### Secondary matched view

| Group | Current/legacy | 95% interval | Eligible / total | Excluded cases |
|---|---|---|---|---|
| `all` | 0.845 | [0.826, 0.867] | 82 / 88 | All six listed below |
| `feasible_lasso` | 1.02 | [0.981, 1.06] | 6 / 8 | `feasible_lasso/A/0.02lmax/cyclic`; `feasible_lasso/A/0.02lmax/random` |
| `group_lasso` | 0.701 | [0.685, 0.718] | 8 / 8 | None |
| `lasso` | 0.701 | [0.681, 0.724] | 16 / 16 | None |
| `path` | 0.418 | [0.412, 0.424] | 8 / 8 | None |
| `quadratic` | 1.01 | [0.981, 1.03] | 16 / 16 | None |
| `scaled_lasso` | 1.14 | [1.05, 1.26] | 6 / 8 | `scaled_lasso/A/0.02lmax/cyclic`; `scaled_lasso/A/0.02lmax/random` |
| `sqrt_lasso` | 1.12 | [1.06, 1.19] | 6 / 8 | `sqrt_lasso/A/0.02lmax/cyclic`; `sqrt_lasso/A/0.02lmax/random` |
| `weighted_lasso` | 1.00 | [0.944, 1.06] | 16 / 16 | None |

### Defaults view

Defaults retain completed timings even when the matched accuracy is not reached.
Eligibility in this table concerns available timings, not matched certification.
All 88 cases remain, including the 6 cases listed below.

| Group | Current/legacy | 95% interval | Eligible / total | Excluded cases |
|---|---|---|---|---|
| `all` | 0.897 | [0.839, 0.949] | 88 / 88 | None |
| `feasible_lasso` | 0.949 | [0.861, 1.02] | 8 / 8 | None |
| `group_lasso` | 0.897 | [0.858, 0.931] | 8 / 8 | None |
| `lasso` | 0.980 | [0.921, 1.04] | 16 / 16 | None |
| `path` | 0.338 | [0.322, 0.350] | 8 / 8 | None |
| `quadratic` | 0.970 | [0.901, 1.02] | 16 / 16 | None |
| `scaled_lasso` | 1.08 | [1.00, 1.15] | 8 / 8 | None |
| `sqrt_lasso` | 1.05 | [0.957, 1.14] | 8 / 8 | None |
| `weighted_lasso` | 1.01 | [0.929, 1.10] | 16 / 16 | None |

### Primary per-case times

All 82 estimable primary cases appear below. Milliseconds are arithmetic
means of process medians, rounded to two decimals. The ratio is the geometric
mean of paired block ratios, so it need not equal the quotient of the two
displayed mean times.

| Case | Legacy ms | Current ms | Current/legacy [95% interval] |
|---|---|---|---|
| `feasible_lasso/A/0.1lmax/cyclic` | 6.66 | 8.69 | 1.33 [1.19, 1.48] |
| `feasible_lasso/A/0.1lmax/random` | 10.30 | 8.51 | 0.818 [0.717, 0.932] |
| `feasible_lasso/C/0.02lmax/cyclic` | 42.08 | 38.60 | 0.918 [0.871, 0.967] |
| `feasible_lasso/C/0.02lmax/random` | 42.66 | 42.50 | 0.994 [0.892, 1.11] |
| `feasible_lasso/C/0.1lmax/cyclic` | 29.68 | 31.13 | 1.05 [0.991, 1.11] |
| `feasible_lasso/C/0.1lmax/random` | 31.44 | 33.79 | 1.07 [0.962, 1.20] |
| `group_lasso/A/0.02lmax/cyclic` | 341.06 | 321.66 | 0.943 [0.915, 0.972] |
| `group_lasso/A/0.02lmax/random` | 364.73 | 379.29 | 1.01 [0.896, 1.14] |
| `group_lasso/A/0.1lmax/cyclic` | 51.61 | 44.56 | 0.863 [0.816, 0.913] |
| `group_lasso/A/0.1lmax/random` | 71.18 | 65.97 | 0.916 [0.835, 1.00] |
| `group_lasso/C/0.02lmax/cyclic` | 127.93 | 141.50 | 1.10 [1.04, 1.17] |
| `group_lasso/C/0.02lmax/random` | 148.38 | 124.35 | 0.837 [0.787, 0.889] |
| `group_lasso/C/0.1lmax/cyclic` | 43.65 | 38.07 | 0.861 [0.748, 0.990] |
| `group_lasso/C/0.1lmax/random` | 41.91 | 34.26 | 0.823 [0.770, 0.880] |
| `lasso/A/0.02lmax/cyclic` | 161.58 | 159.22 | 0.985 [0.973, 0.998] |
| `lasso/A/0.02lmax/random` | 97.35 | 102.34 | 1.05 [1.02, 1.08] |
| `lasso/A/0.1lmax/cyclic` | 10.70 | 10.23 | 0.965 [0.895, 1.04] |
| `lasso/A/0.1lmax/random` | 11.83 | 10.19 | 0.877 [0.763, 1.01] |
| `lasso/B/0.02lmax/cyclic` | 189.24 | 189.12 | 0.998 [0.975, 1.02] |
| `lasso/B/0.02lmax/random` | 87.51 | 85.10 | 0.974 [0.945, 1.00] |
| `lasso/B/0.1lmax/cyclic` | 9.30 | 9.13 | 0.985 [0.913, 1.06] |
| `lasso/B/0.1lmax/random` | 10.15 | 10.41 | 1.00 [0.821, 1.22] |
| `lasso/C/0.02lmax/cyclic` | 23.49 | 22.81 | 0.971 [0.938, 1.00] |
| `lasso/C/0.02lmax/random` | 28.55 | 30.28 | 1.06 [0.981, 1.15] |
| `lasso/C/0.1lmax/cyclic` | 8.22 | 7.90 | 0.958 [0.876, 1.05] |
| `lasso/C/0.1lmax/random` | 9.00 | 9.95 | 1.10 [0.985, 1.23] |
| `lasso/E/0.02lmax/cyclic` | 2209.24 | 2192.77 | 0.992 [0.974, 1.01] |
| `lasso/E/0.02lmax/random` | 68.24 | 66.25 | 0.973 [0.925, 1.02] |
| `lasso/E/0.1lmax/cyclic` | 42.21 | 42.18 | 0.997 [0.961, 1.03] |
| `lasso/E/0.1lmax/random` | 4.66 | 4.64 | 1.00 [0.921, 1.09] |
| `path/A/path/cyclic` | 1094.55 | 1084.15 | 0.990 [0.985, 0.996] |
| `path/A/path/random` | 315.46 | 316.19 | 1.00 [0.970, 1.04] |
| `path/B/path/cyclic` | 1202.26 | 1196.27 | 0.995 [0.981, 1.01] |
| `path/B/path/random` | 457.29 | 456.25 | 0.998 [0.981, 1.02] |
| `path/C/path/cyclic` | 296.28 | 44.25 | 0.150 [0.140, 0.162] |
| `path/C/path/random` | 312.96 | 46.71 | 0.150 [0.140, 0.161] |
| `path/E/path/cyclic` | 11222.71 | 11199.26 | 0.998 [0.981, 1.01] |
| `path/E/path/random` | 240.71 | 236.92 | 0.984 [0.967, 1.00] |
| `quadratic/A/0.02lmax/cyclic` | 562.88 | 544.95 | 0.970 [0.890, 1.06] |
| `quadratic/A/0.02lmax/random` | 402.45 | 374.59 | 0.943 [0.847, 1.05] |
| `quadratic/A/0.1lmax/cyclic` | 53.54 | 51.88 | 0.970 [0.922, 1.02] |
| `quadratic/A/0.1lmax/random` | 44.20 | 45.53 | 1.03 [0.985, 1.08] |
| `quadratic/B/0.02lmax/cyclic` | 817.09 | 745.27 | 0.938 [0.840, 1.05] |
| `quadratic/B/0.02lmax/random` | 351.37 | 363.63 | 1.07 [0.946, 1.21] |
| `quadratic/B/0.1lmax/cyclic` | 46.79 | 46.73 | 0.999 [0.960, 1.04] |
| `quadratic/B/0.1lmax/random` | 42.35 | 40.03 | 0.945 [0.919, 0.972] |
| `quadratic/C/0.02lmax/cyclic` | 0.95 | 1.00 | 1.05 [1.02, 1.07] |
| `quadratic/C/0.02lmax/random` | 1.15 | 1.18 | 1.02 [0.987, 1.06] |
| `quadratic/C/0.1lmax/cyclic` | 0.38 | 0.42 | 1.13 [1.08, 1.19] |
| `quadratic/C/0.1lmax/random` | 0.40 | 0.45 | 1.12 [1.07, 1.17] |
| `quadratic/E/0.02lmax/cyclic` | 8489.78 | 8122.27 | 0.957 [0.833, 1.10] |
| `quadratic/E/0.02lmax/random` | 197.78 | 196.19 | 0.990 [0.965, 1.02] |
| `quadratic/E/0.1lmax/cyclic` | 158.50 | 154.54 | 0.975 [0.965, 0.985] |
| `quadratic/E/0.1lmax/random` | 27.08 | 27.02 | 1.00 [0.944, 1.06] |
| `scaled_lasso/A/0.1lmax/cyclic` | 1.32 | 1.41 | 1.08 [0.942, 1.25] |
| `scaled_lasso/A/0.1lmax/random` | 1.51 | 1.99 | 1.20 [0.896, 1.60] |
| `scaled_lasso/C/0.02lmax/cyclic` | 10.74 | 13.01 | 1.20 [1.13, 1.29] |
| `scaled_lasso/C/0.02lmax/random` | 14.35 | 15.52 | 1.08 [0.996, 1.16] |
| `scaled_lasso/C/0.1lmax/cyclic` | 6.44 | 7.78 | 1.19 [1.04, 1.36] |
| `scaled_lasso/C/0.1lmax/random` | 7.47 | 8.29 | 1.10 [0.987, 1.23] |
| `sqrt_lasso/A/0.1lmax/cyclic` | 1.30 | 1.30 | 1.00 [0.930, 1.08] |
| `sqrt_lasso/A/0.1lmax/random` | 1.83 | 2.09 | 1.07 [0.837, 1.36] |
| `sqrt_lasso/C/0.02lmax/cyclic` | 10.69 | 12.31 | 1.15 [1.09, 1.22] |
| `sqrt_lasso/C/0.02lmax/random` | 14.38 | 16.77 | 1.17 [1.09, 1.24] |
| `sqrt_lasso/C/0.1lmax/cyclic` | 6.85 | 7.67 | 1.12 [1.05, 1.19] |
| `sqrt_lasso/C/0.1lmax/random` | 7.45 | 9.23 | 1.25 [1.14, 1.37] |
| `weighted_lasso/A/0.02lmax/cyclic` | 5.14 | 5.11 | 0.990 [0.934, 1.05] |
| `weighted_lasso/A/0.02lmax/random` | 6.04 | 6.17 | 1.07 [0.874, 1.32] |
| `weighted_lasso/A/0.1lmax/cyclic` | 1.44 | 1.41 | 1.05 [0.823, 1.33] |
| `weighted_lasso/A/0.1lmax/random` | 1.82 | 1.96 | 1.09 [0.956, 1.25] |
| `weighted_lasso/B/0.02lmax/cyclic` | 5.11 | 5.49 | 1.07 [1.02, 1.12] |
| `weighted_lasso/B/0.02lmax/random` | 6.79 | 7.31 | 1.04 [0.876, 1.22] |
| `weighted_lasso/B/0.1lmax/cyclic` | 1.41 | 1.47 | 1.09 [0.941, 1.27] |
| `weighted_lasso/B/0.1lmax/random` | 1.51 | 1.76 | 1.19 [1.06, 1.34] |
| `weighted_lasso/C/0.02lmax/cyclic` | 7.59 | 7.67 | 1.01 [0.939, 1.08] |
| `weighted_lasso/C/0.02lmax/random` | 9.08 | 9.35 | 1.03 [0.946, 1.13] |
| `weighted_lasso/C/0.1lmax/cyclic` | 4.27 | 4.75 | 1.10 [0.992, 1.23] |
| `weighted_lasso/C/0.1lmax/random` | 4.85 | 5.53 | 1.14 [0.993, 1.31] |
| `weighted_lasso/E/0.02lmax/cyclic` | 31.49 | 31.40 | 0.996 [0.969, 1.03] |
| `weighted_lasso/E/0.02lmax/random` | 4.24 | 4.04 | 0.991 [0.870, 1.13] |
| `weighted_lasso/E/0.1lmax/cyclic` | 2.09 | 1.90 | 0.965 [0.784, 1.19] |
| `weighted_lasso/E/0.1lmax/random` | 1.74 | 2.51 | 1.32 [1.07, 1.62] |

### Cases that do not reach the target

These 6 cases reach `1e-4` on neither side at any calibration rung. They
have no matched ratio and remain in the defaults view.
For feasible lasso, an interpolating fit with `‖y − Xβ‖ ≤ 1e-8‖y‖` is
uncertifiable in both the Julia certificate and the Python cross-check.
The table describes the tight calibration fits; the defaults view records the
accuracy actually reached at default settings.

| Case | Reason the matched target is not reached on either side |
|---|---|
| `feasible_lasso/A/0.02lmax/cyclic` | Interpolating fit at tight settings; uncertifiable by the residual-loading rule. |
| `feasible_lasso/A/0.02lmax/random` | Interpolating fit at tight settings; uncertifiable by the residual-loading rule. |
| `scaled_lasso/A/0.02lmax/cyclic` | Near interpolation; relative gap remains about 0.7–0.8 across the ladder. |
| `scaled_lasso/A/0.02lmax/random` | Near interpolation; relative gap remains about 0.7–0.8 across the ladder. |
| `sqrt_lasso/A/0.02lmax/cyclic` | Near interpolation; relative gap remains about 0.7–0.8 across the ladder. |
| `sqrt_lasso/A/0.02lmax/random` | Near interpolation; relative gap remains about 0.7–0.8 across the ladder. |

## Noise floor

The A/A arm compares current with the same code and settings in a separate
process. On the log scale, `δ = max(log(1.05), q)`, where `q` is the upper 95%
confidence bound for the pooled 95th percentile of
`|log(current/current-AA)|`. The order-statistic bound assumes independent,
identically distributed observations; dependence between cases within a block
limits its nominal coverage.

| View | Log noise floor δ | A/A observations | Candidate regressions | BH rejections |
|---|---|---|---|---|
| primary | 0.516 | 984 | 0 | 0 |
| secondary | 0.507 | 984 | 0 | 0 |
| defaults | 0.436 | 1056 | 0 | 0 |

A candidate requires its per-case log-interval lower endpoint to exceed `δ`.
One-sided tests against `δ` undergo Benjamini–Hochberg screening at 10% across
estimable cases separately in each view. No case meets either screen here.
An interval overlapping `[-δ, δ]` is inconclusive, not a tie.

The A/A arm shows contention from other work on the shared machine in blocks
3–5: their median `|log(current/current-AA)|` is about 0.10–0.25, compared
with about 0.01–0.05 in the other blocks. Even without those blocks, calls
of 1–5 ms drive the pooled upper tail and keep the noise floor wide.

### Sensitivity check: nine blocks

This check is not pre-registered. It excludes blocks 3–5 using only the A/A
arm, not current/legacy comparison ratios; the full 12-block analysis above
remains the headline result. The remaining 9 blocks give
`δ = 0.223` for primary and
`δ = 0.235` for secondary, with
0 candidates and 0 BH rejections in each.
An independent recomputation from raw process medians gives these group ratios;
the same 82 matched cases are eligible.

| Group | Primary current/legacy | Secondary current/legacy |
|---|---|---|
| `all` | 0.983 | 0.851 |
| `feasible_lasso` | 1.03 | 1.03 |
| `group_lasso` | 0.904 | 0.702 |
| `lasso` | 1.00 | 0.698 |
| `path` | 0.626 | 0.421 |
| `quadratic` | 1.02 | 1.02 |
| `scaled_lasso` | 1.11 | 1.11 |
| `sqrt_lasso` | 1.12 | 1.12 |
| `weighted_lasso` | 1.09 | 1.03 |

## The #110 same-code check

The unchanged #116 quick harness uses two series from one locked environment,
with 3 interleaved repetitions each. Across 60 cases, the geometric
mean time ratio is 1.002, with range 0.943–1.073.
Exactly 2/60 paired 95% intervals exclude 1: 58 are inconclusive and
2 indicate shorter time in the second series. Recorded accuracy and Julia
heap bytes are identical between the two series. These unchanged-code checks
describe repeatability on those workloads; they do not remove the comparison
suite's measured A/A noise.

## Limitations

- The measurements cover one shared machine and these designs. They do not
  establish performance on other hardware, other estimators or other inputs.
- Timings describe the whole public-API call, not isolated solver kernels.
  They do not measure statistical quality, and these calls use no intercept
  or standardization.
- The measured noise floor limits per-case sensitivity to about 25–68% on the
  time-ratio scale, from the nine-block primary check to the headline primary
  analysis. Smaller changes can remain inconclusive even when an interval
  excludes 1.
- A candidate needs an independent rerun in fresh processes before it counts
  as a confirmed regression. No result here is independently confirmed.
- The results describe ProximalSolvers 0.2.0 at the commit above. Later
  releases, including 0.3.0, are not covered by this campaign.

The 0.80 ratio from the retired `benchmark/engine` is a historical mixed-workload
aggregate. It includes CovSel, DiffPrecTest, refit, IHT, gradient and ADMM cases
and is not comparable with this suite. Those studies remain in the
[historical benchmark tree](https://github.com/mlakolar/ProximalSolvers.jl/tree/f7e3f28026a8e83e0fa18203b39839cf57a1c949/benchmark).

## Reproducing

The [suite README](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/external/README.md) contains the setup, artifact, fixture, calibration,
confirmation, validation, analysis and cross-check commands. The
[campaign pre-release](https://github.com/mlakolar/ProximalSolvers.jl/releases/tag/cd-comparison-20261028) holds the raw records, coefficients, input
artifact, lockfiles, commands and analysis outputs, with a SHA-256 list.

The independent Python certificate cross-check matches
1,990/1,990 calibration coefficient files and
6,816/6,816 confirmation files, including every archived path
level. The confirmation total includes the matched arms and the defaults arms.
The independent raw-median recomputation reproduces the headline case ratios,
noise floors and screening decisions; group bootstrap endpoints can differ
slightly because that check uses fewer resamples.
