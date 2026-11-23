# Ball rounding admission: measurements

This page records the measurements behind the admission of an `IndBallL2` trial whose ProximalBase value is `Inf`
([IN-08](@ref), issue [#537](https://github.com/mlakolar/ProximalSolvers.jl/issues/537)). They are observations at
stated revisions, not solver guarantees; the rule and its error bounds are in the clause.

## [evidence-ball-rounding Reproduction at the base](@id evidence-ball-rounding)

**Statement.** Measured at ProximalSolvers master `202545cc` with ProximalBase `bc9e888d`, on a cluster (Slurm), Julia
1.13.3. The probe drew 20,000 random four-entry `IndBallL2` projections per regime and counted those whose fused
`value_and_prox!` value is `Inf`. The last column is the largest true relative violation `(‖x‖ - r) / r` among the `Inf`
outputs, computed in BigFloat.

| T | Regime | `Inf` values | Largest violation of an `Inf` output |
|---|---|---|---|
| Float32 | ordinary, r = 1 | 0 / 20000 | – |
| Float32 | r below ProximalBase's four-entry floor `2sqrt(4floatmin/eps)` (1.26e-15) | 9961 / 20000 | 1.52e-7 (1.28 eps) |
| Float32 | coefficients around 1e19 (sums of squares can overflow) | 107 / 20000 | 5.5e-8 |
| Float32 | r = 2e-15, at the floor or above | 0 / 20000 | – |
| Float64 | ordinary, r = 1 | 0 / 20000 | – |
| Float64 | r below the floor (4e-146) | 5720 / 20000 | 2.69e-16 (1.21 eps) |
| Float64 | coefficients around 1e159 (sums of squares can overflow) | 1563 / 20000 | 2.94e-16 (1.32 eps) |
| Float64 | r = 1e-145, at the floor or above | 0 / 20000 | – |

- **Solves.** The `IndBox` and `IndBallLinf` controls (PGD and APG) and the `IndNonnegative` control (PGD) passed in
  both precisions, and so did the active and interior `IndBallL2` controls. A sweep of 200 random ordinary active-ball
  problems (scales 1e-3 to 1e3) failed 0 of 200 for each of the four combinations of method and precision. In Float64,
  `IndBallL2(1e-150)` failed with PGD and with APG, and `IndBallL2(1e157)` failed with PGD, all with "the gradient step did
  not produce a finite objective". The Float32 boundary cases passed in that draw.
- **Attribution.** The failure is not in the curvature test. PGD's `backtrack!` reads the smooth value, not the penalty
  value. APG's search first requires the smooth value of a trial to be finite; its certified image inequality then
  reads the displacement and the images, not the loss value or the penalty value. The `Inf` comes from ProximalBase's
  fused value of the stored projection, through `state.g_x`. A trial that carries it and that the step returns meets
  the outer guard `isfinite(state.f_x + state.g_x)` in `_solve_gradient!`, which rolls back. In APG with momentum the
  restart test `f_x + g_x > f_x_previous + g_x_previous` fires on such a trial first; its retry from `x_previous` can
  succeed, which is why some solves passed, or it can return a trial that reaches the same guard. In the first step and
  in a step after a restart (`ω = 0`) the trial skips the comparison and reaches the guard.
- **Ordinary range.** No failing case of the supported four-entry scope appeared in the ordinary range. The admission
  applies to a trial whose ProximalBase value is `Inf`, which the ordinary-range solves did not produce.

## [evidence-ball-rounding-sweep Check against ProximalBase and BigFloat](@id evidence-ball-rounding-sweep)

**Statement.** Measured at commit `c0878e5b` of pull request [#538](https://github.com/mlakolar/ProximalSolvers.jl/pull/538)
(the check is the code of `f2465717`, which introduces `_ball_rounding_admissible`), Julia 1.13.3 and 1.10.12 on a cluster
(Slurm), ProximalBase `bc9e888d`. The tables are from Julia 1.13.3. Julia 1.10.12 gave zero rejections as well
(183,530 Float32 and 114,505 Float64 `Inf` outputs), with the largest violation of an admitted synthetic point
8.0 eps (Float32) and 9.01 eps (Float64).
Each sample is a random four-entry point projected by `value_and_prox!` onto `IndBallL2(r)`, whose stored output `y`
is then given to `_ball_rounding_admissible(y, r)`. The violation of `y` is computed in 256-bit BigFloat.

The regimes cover an ordinary radius `r = 1`; a radius below ProximalBase's four-entry floor and near `floatmin`;
coefficients of magnitude around 1e154 to 1e159 (Float64) and 1e18.3 to 1e19.5 (Float32), whose sums of squares can
overflow; a radius drawn from the floor and its two adjacent floats (pooled in one row); entries
whose magnitudes span three to twenty decades with random signs; and one dominant entry with the others small.

**Float32**, 100,000 samples per regime.

| Regime | `Inf` values | Rejected by the check | `value_and_prox!` value differs from `g(y)` | Largest violation of an `Inf` output (units of `eps(T)`) |
|---|---|---|---|---|
| ordinary r=1 | 0 | 0 | 0 | – |
| r below floor (1e-37..floor) | 45135 | 0 | 0 | 1.224 |
| r near floatmin (1.2e-38..1e-36) | 45685 | 0 | 0 | 0.668 |
| coefficients around 1e18.3..1e19.5 (sums can overflow) | 10326 | 0 | 0 | 0.458 |
| r at, one step below and one step above the floor (pooled) | 3529 | 0 | 0 | 1.456 |
| entries spanning magnitudes, r=1e-16 | 31173 | 0 | 0 | 1.257 |
| entries spanning magnitudes, r=1e19 | 573 | 0 | 0 | 0.461 |
| one dominant entry, r below floor | 40953 | 0 | 0 | 0.755 |
| one dominant entry, huge | 6420 | 0 | 0 | 0.000 |
| Total | 183794 | 0 | | |

**Float64**, 100,000 samples per regime.

| Regime | `Inf` values | Rejected by the check | `value_and_prox!` value differs from `g(y)` | Largest violation of an `Inf` output (units of `eps(T)`) |
|---|---|---|---|---|
| ordinary r=1 | 0 | 0 | 0 | – |
| r below floor (1e-250..floor) | 16323 | 0 | 0 | 1.346 |
| r near floatmin (1e-307..1e-290) | 16404 | 0 | 0 | 1.310 |
| coefficients around 1e154..1e159 (sums can overflow) | 16392 | 0 | 0 | 1.334 |
| r at, one step below and one step above the floor (pooled) | 6472 | 0 | 0 | 1.285 |
| entries spanning magnitudes, r=1e-150 | 14141 | 0 | 0 | 1.327 |
| entries spanning magnitudes, r=1e158 | 9452 | 0 | 0 | 1.284 |
| one dominant entry, r below floor | 17566 | 0 | 0 | 1.428 |
| one dominant entry, huge | 17562 | 0 | 0 | 1.441 |
| Total | 114312 | 0 | | |

In the regimes above the check admitted all `Inf` outputs of ProximalBase. The largest violation of an `Inf` output was
below the 2.5 eps that [IN-08](@ref) derives for the general route under its range assumptions. The value returned by
`value_and_prox!` equalled `g(y)` in all the samples, which supports the use of the standalone `g(x)` for the penalty term of
the reported `minimum`.

Synthetic points test the tolerance. A direction is drawn (Gaussian, entries spanning magnitudes, or one dominant
entry), and the point `(1 + δ eps) r u`, with `u` a unit vector and the multiplier formed in BigFloat, is rounded to `T`, for radii
`1`, `1e-150`, `1e-300`, `1e158`, `1e-5`, `1e300` (Float64) and `1`, `1e-16`, `1e-30`, `1e19`, `1e-5`, `1e30`
(Float32). The violations are in units of `eps(T)`; the smallest violation among rejected points and the largest among
admitted points show where the decision switches.

| δ | Float32 admitted of 10,000 | Float32 largest violation admitted | Float32 smallest violation rejected | Float64 admitted of 10,000 | Float64 largest violation admitted | Float64 smallest violation rejected |
|---|---|---|---|---|---|---|
| -1 | 10000 | -0.5420 | – | 10000 | -0.5820 | – |
| 0 | 10000 | 0.4591 | – | 10000 | 0.4282 | – |
| 2 | 10000 | 2.4992 | – | 10000 | 2.4979 | – |
| 4 | 10000 | 4.4739 | – | 10000 | 4.4953 | – |
| 6 | 10000 | 6.4758 | – | 10000 | 6.4913 | – |
| 7 | 10000 | 7.4867 | – | 10000 | 7.4984 | – |
| 7.5 | 10000 | 7.9965 | – | 9988 | 7.9834 | 7.6761 |
| 8 | 5645 | 8.0000 | 8.0000 | 9222 | 8.4937 | 7.6999 |
| 8.5 | 625 | 8.0000 | 8.0000 | 4867 | 8.9853 | 8.1190 |
| 9 | 0 | – | 8.5084 | 274 | 8.9716 | 8.5175 |
| 9.5 | 0 | – | 9.0000 | 0 | – | 9.0000 |
| 10 | 0 | – | 9.5286 | 0 | – | 9.5008 |
| 10.5 | 0 | – | 10.0000 | 0 | – | 10.0000 |
| 11 | 0 | – | 10.5228 | 0 | – | 10.5005 |
| 12 | 0 | – | 11.5258 | 0 | – | 11.5004 |
| 16 | 0 | – | 15.5239 | 0 | – | 15.5014 |
| 64 | 0 | – | 63.5461 | 0 | – | 63.5013 |

The largest true violation of an admitted synthetic point was 8.99 eps (Float64) and 8.0 eps (Float32) against the
documented bound of 10 eps; no admitted point lay beyond 10 eps. The smallest violation of a rejected point was 7.68 eps (Float64)
and 8.0 eps (Float32). The decision is a comparison of computed values: at `r = 1.1` (Float64), the point
`(t, 0, 0, 0)` with `t` the rounded threshold `r (1 + 8eps)` is admitted at a true violation of 8.18 eps.

## [evidence-ball-rounding-cases Trial points and the base](@id evidence-ball-rounding-cases)

**Statement.** The tests of [IN-08](@ref) use hard-coded targets. A search over one-iteration solves found them: each is
a start `x0 = 0` whose first trial of both PGD and APG ends on a stored projection with value `Inf`. For the radii
`1e-150` (Float64) and `1e-16` (Float32), with `X = 2I` and loss scale 1/4, the first trial projects the target itself and
the stored violation was below 0.4 eps(T). The huge-scale cases use the design `1e-150 I` (Float64) or `1e-17 I` (Float32)
and radii near one tenth of the norm of the target. Float32 needed a search of a few hundred draws per case because
ProximalBase's `Inf` is rare there.

At the base, `test/constrained_least_squares.jl` with the new testsets, run against a module built from the base source,
passed 2098 assertions and had 14 errors: each of the twelve end-to-end admission testsets (three testsets, two precisions, two
methods) raised "the gradient step did not produce a finite objective", and the two helper testsets raised because the
helper does not exist at the base. The testset "Reported minimum: smooth term and penalty term" passed at the base, because
the behavior it checks is not changed by the admission. The existing testset "Exceptional Euclidean projection rolls back" passed
unchanged.

## [evidence-ball-rounding-minimum Smooth term of the reported minimum](@id evidence-ball-rounding-minimum)

**Statement.** The smooth term of `minimum` is the cached smooth value of the accepted trial for every penalty, and it
can differ from the standalone loss at the returned point by rounding. A Float32 case shows it: `y = vcat(fill(ldexp(1f0, 63), 2),
fill(ldexp(1f0, 51), 4))`, the loss `2f0 * LeastSquaresLoss(y, zeros(Float32, 6, 4))`, `x = zeros(Float32, 4)` and one iteration
(`ProximalOptions(maxiter=2, prox_calls_limit=1)`). With `IndBallL2(1f0)` and with `IndBox(-1f0, 1f0)`, with PGD and with APG,
at the base `202545cc` and at the head, on Julia 1.10.12 and 1.13.3, every run returned `x = 0` and `minimum = 1.701412e38`,
while the standalone `f(x) + g(x)` was `1.7014118e38`, one unit in the last place lower. The base returned the same
`minimum` for `IndBox`, so the difference is not introduced by the admission.

## [evidence-ball-rounding-perf Paired performance](@id evidence-ball-rounding-perf)

**Statement.** The base source, the head and a second copy of the head source (the A/A control) were loaded in one
process on a cluster (Slurm) node, Julia 1.10.12 and 1.13.3, with one Julia thread. The BLAS thread count was 32 on Julia 1.10.12
and 2 on Julia 1.13.3; all three sides ran in one process, so each pair shares the count. For each case the three sides
solved the same problem in alternating order inside each repetition (the order rotates), 30 repetitions in each of 5 rounds.
The ball problems have four coefficients and 40 observations, and each timed call repeats the solve 50 times. The other problems
have 200 observations and 50 coefficients, with the loss scaled by `1/n`: `IndBox(-0.5, 0.5)` (active), `IndNonnegative`
(PGD only), `NormL1` and `ElasticNet`. The ratios are medians of the per-repetition paired ratios.

Over the 36 combinations of case, method, precision and Julia version, the median head/base ratio lies between 0.985 and
1.022, and the median copy/head ratio of the control between 0.967 and 1.021. The allocation of one solve is equal on the three sides in
all 18 cases for each Julia version. In all of them the minimizer bits, iterations, `minimum` and `converged` of the head equal the base's, and those of the copy equal
the head's.

| Type | Method | Case | Julia 1.10.12 median head/base | copy/head | Julia 1.13.3 median head/base | copy/head | Allocation per solve, base = head = copy (bytes, 1.10.12 / 1.13.3) |
|---|---|---|---|---|---|---|---|
| Float64 | PGD | box | 1.008 | 0.995 | 1.003 | 1.000 | 6560 / 6160 |
| Float64 | PGD | ball | 1.006 | 0.977 | 1.012 | 0.995 | 1744 / 1712 |
| Float64 | PGD | nonneg | 1.002 | 0.999 | 0.999 | 0.994 | 6560 / 6160 |
| Float64 | PGD | l1 | 1.003 | 0.997 | 0.995 | 1.011 | 7504 / 7136 |
| Float64 | PGD | enet | 0.985 | 0.995 | 1.005 | 0.999 | 7504 / 7136 |
| Float64 | APG | box | 1.004 | 0.996 | 1.006 | 0.997 | 10512 / 9824 |
| Float64 | APG | ball | 1.004 | 0.979 | 1.004 | 1.005 | 2880 / 2848 |
| Float64 | APG | l1 | 1.006 | 0.999 | 1.005 | 0.995 | 11440 / 10784 |
| Float64 | APG | enet | 1.001 | 0.999 | 1.002 | 0.996 | 11440 / 10784 |
| Float32 | PGD | box | 1.005 | 1.002 | 1.000 | 0.995 | 3504 / 3536 |
| Float32 | PGD | ball | 1.021 | 0.991 | 1.010 | 0.991 | 1280 / 1248 |
| Float32 | PGD | nonneg | 0.999 | 1.021 | 1.003 | 1.001 | 3504 / 3536 |
| Float32 | PGD | l1 | 1.000 | 1.000 | 1.010 | 0.985 | 4448 / 4512 |
| Float32 | PGD | enet | 1.000 | 1.000 | 0.998 | 0.997 | 4448 / 4512 |
| Float32 | APG | box | 0.998 | 0.996 | 1.001 | 1.011 | 5616 / 5712 |
| Float32 | APG | ball | 1.022 | 0.967 | 1.009 | 0.989 | 2048 / 2016 |
| Float32 | APG | l1 | 1.000 | 0.994 | 1.002 | 0.996 | 6544 / 6672 |
| Float32 | APG | enet | 1.014 | 0.981 | 1.002 | 0.996 | 6544 / 6672 |
