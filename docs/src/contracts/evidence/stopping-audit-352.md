# [Stopping audit: observations and limitations](@id evidence-stopping-352)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/stopping-limits.md:1-16 -->

# Limits of the stopping tests

This page collects what `converged = true` says for scalar CD, group CD, PGD and APG, and
the measured limits of their stopping tests. The numbers come from the Stage 0 audit of
[issue #352](https://github.com/mlakolar/ProximalSolvers.jl/issues/352), run at revision
`b8a2c04` on Julia 1.13.4; Julia 1.10.13 was run as well and gave close but not identical counts.
The audit used 11 small designs (20 to 60 rows, 8 to 60 columns) and evaluated each solve in
600-bit arithmetic on the rounded inputs the solver received. At that revision `solve!` refused a
weighted `NormL1`, so the `NormL1` problems of the audit were unweighted, and the counts on this page
do not cover a weighted `NormL1`. These are high-precision
evaluations, not proofs, and the counts are for those designs: they are not rates to expect on
other problems. The subsections from [The cached residual](@ref "The cached residual") on report a
separate, later study ([issue #378](https://github.com/mlakolar/ProximalSolvers.jl/issues/378),
revision `8cc0222`) with its own designs and starts; its counts are a different population and are
not to be combined with those of the audit.

<!-- baseline: docs/src/stopping-limits.md:79-98 -->

**Measured at the default threshold, with a positive penalty.** The benchmark target of
the repository, a relative suboptimality of `1e-8` in Float64 and `1e-5` in Float32, is a
target of the repository's benchmark. It is not part of the documented contract of
`converged = true`.

- Scalar CD (lasso and elastic net): all 16,218 converged solves that have a tight reference
  were within the benchmark target, and the worst was `1.3e-9`. A further 478 converged solves on
  the rank-deficient design have no tight reference; their suboptimality is between 0 and `1.4e-6`,
  which does not decide the comparison with `1e-8`.
- Group CD: 48 of 3,529 converged solves were above the benchmark target. With `relative = true`
  these are 12 solves, in Float64 only, with the largest excess between `2.8e-7` and `3.7e-7`
  (a lower and an upper bound; two underdetermined designs at the lowest penalty level). With
  `relative = false` they are 36 solves, with the largest excess between `4.6e-5` and `4.7e-5`,
  on the design whose column norms span six decades; its KKT residual was `3.4e-4 λmax` in
  Float64 and `5.3e-4 λmax` in Float32.

These group results are inside the contract of `converged = true`: the flag reports the
change test, and the bounds above are not a bound on the suboptimality. See also
[The stopping statistic](@ref "The stopping statistic") of the group lasso.

<!-- baseline: docs/src/stopping-limits.md:200-207 -->


Related degradation appears in the sweep. With `λ = 0` on the rank-deficient design, the exact
least-squares minimizer has large cancelling coefficients, and the warm starts taken from it give 80
converged solves per precision at the default threshold, with an exact KKT residual up to `0.063 λmax`
in Float64 and `0.16 λmax` in Float32; the cold starts on the same problems end at `1.7e-8 λmax` or
below in Float64 and `5.7e-8 λmax` or below in Float32. The stopping pass changed nothing in 24 of the
Float32 rows and in none of the Float64 rows; the others stopped on a small nonzero change. The
empty-pass mechanism is therefore established for the example above, not for all of these rows.

<!-- baseline: docs/src/stopping-limits.md:358-430 -->

## Float32

- **Coordinate descent with `relative = false`.** At the default `tol = 1e-7` with `relative = false`,
  130 of 5,700 Float32 scalar CD solves and 40 of 1,830 Float32 square-root solves ran to
  `maxpasses = 100000` in the sweep; the scalar ones that have a tight reference ended within
  `5.1e-8` of the minimum. With the default `relative = true`, no scalar solve of the sweep reached `maxpasses`
  in Float32. The CD bullet under [What does converged mean?](@ref "What does converged mean?")
  says that Float32 rounding of the coefficients can keep the change above the threshold. Keep
  `relative = true`, or choose a `tol` well above `eps(Float32)` times the size of the coefficients.
- **PGD and APG with the default options.** In the sweep, 70 of 570 Float32 PGD solves and 67 of 570 Float32 APG
  solves ended on the objective-increase exit, with `converged = false`, at points within the `1e-5`
  benchmark target; the KKT residual there was a median of 4 times the bound. The exit is described in
  [PGD stops when the computed objective increases](@ref "PGD stops when the computed objective increases"),
  which says that a Float32 solve can end on it. On the five benchmark designs with the benchmark options (10 draws each,
  Julia 1.10.13 and 1.13.3, before and after #319), Float32 PGD ended above the `1e-5` target in 36 to 39 of 50 solves
  on 1.10.13 and in 37 of 50 on 1.13.3, and 22 to 25 and 15 to 16 of those solves had `converged = true`; Float32 APG missed
  40 to 41 of 50, with 26 to 29 `converged = true`. For the Float32 PGD solves with `converged = true` that missed the target, the gap was
  2.3 to 7.0 times the independent KKT residual, which was below the bound `64 eps(Float32) ≈ 7.63e-6`. The bound is on a KKT
  residual and the target is on a duality gap, so a solve can meet the former and miss the latter. The conditions and counts are in the
  [benchmark harness notes](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/benchmark/HARNESS.md)
  and in [issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320).
- **Square-root lasso.** Certified solves at the default `tol` with `relative = true`, on the seven designs
  of the audit that are not exact or near-exact fits (210 solves per cell). The penalty level is
  a fraction of the level at which the solution is 0. The last column is an upper bound of the
  suboptimality of the worst uncertified Float32 point:

  | level | Float64 | Float32 | worst uncertified Float32 point |
  | --- | --- | --- | --- |
  | 0.001 | 196 / 210 | 40 / 210 | 6.5e-5 |
  | 0.05 | 210 / 210 | 178 / 210 | 3.6e-8 |
  | 0.3 and above | 210 / 210 | 210 / 210 | |

  The 14 uncertified Float64 solves at level 0.001 are on the design whose response dwarfs the residual,
  which [The certificate](@ref "The certificate") describes. The bound of the certificate loses the term
  `(1 − t) ‖r̂‖`, which is linear in the relative violation of the dual constraint
  `|X_kᵀr̂| ≤ λ ‖r̂‖`; and in Float32 the floor forbids tightening, as
  [Tightening and the uncertified stop](@ref "Tightening and the uncertified stop") states. An
  uncertified point is reported with `converged = false` and `gap = NaN`.

## `ftol = 0` at a fixed point

Under `ftol = 0` an iteration whose accepted iterate equals the previous one proposes no stop (the
bullet "An exact stall" under [Strict accuracy](@ref "Strict accuracy")), so the stationarity check,
which runs where a test proposes a stop, is not asked there. A solve that reaches its floating-point
fixed point can then run to `maxiter`, or end with `stagnated = true`, with `converged = false`, at a point
whose exact KKT residual is below the bound. This behaviour is kept.

In the sweep, with the documented strict configuration (`ftol = 0`, `allow_f_increases = true`,
`xtol = 1e-300`, `gradtol = 1e-11`), Float32 PGD reported `converged = true` in 12 of 570 solves,
and 538 did not converge although the exact residual was below the bound (338 at `maxiter = 20000`,
200 with `stagnated = true`). The table counts solves that did not converge although the exact
normalized KKT residual is below `max(gradtol, 64 eps)`. It uses the problems with a positive scale
`S` (the 12 solves per cell with `y = 0` and `λ = 0` are excluded: the check refuses a zero scale by
design), 570 solves per cell, and compares the exact residual with the bound; it is not a replay of the
computed check. In the table `strict` is the configuration above, and entries are Float64 / Float32.

| options | solver | converged | not converged, residual below the bound | of those, at `maxiter = 20000` | of those, `stagnated` |
| --- | --- | --- | --- | --- | --- |
| `ftol = 0` | PGD | 359 / 198 | 191 / 251 | 189 / 192 | 0 / 8 |
| `ftol = 0` | APG | 358 / 220 | 196 / 249 | 194 / 195 | 0 / 0 |
| strict | PGD | 314 / 12 | 215 / 538 | 215 / 338 | 0 / 200 |
| strict | APG | 324 / 214 | 217 / 336 | 217 / 336 | 0 / 0 |

Each of the 208 stagnation stops of the sweep was at a point whose residual is below the bound
(largest ratio 0.42). Typical cases in the sweep: `λ ≥ λmax` from each of the three starts (the
solution `x = 0` is reached and not reported as converged: 20,000 iterations, exact residual 0); a warm
start at the reference; and Float32 strict solves that reach a fixed point whose residual is below the
bound.

What you can do: with `ftol = 0`, a result with `converged = false` at `maxiter`, or with
`stagnated = true`, can be at a point whose KKT residual is below the bound; evaluate it
[independently](sparsity-and-kkt.md). With the default `ftol > 0` an unchanged iterate proposes a stop,
and the stationarity check decides.
