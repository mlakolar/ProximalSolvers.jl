# [Historical strict-accuracy evidence](@id EVIDENCE-STRICT-01)

These are preserved measurements and explanations from baseline `a6293e6ff7e654a87babbc5de2314205be13d6c5`. They are not current accuracy guarantees. The current rules are [STOP-01](@ref), [STOP-10](@ref) and [STOP-11](@ref). In particular, the configuration measurements below explicitly predate the stationarity check and were not repeated by this documentation migration.

## Strict configuration and original measurements

This is the exact code used in the baseline description:

```julia
ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true,
                xtol = 1e-300, gradtol = 1e-11)
```

On the package's benchmark cases (Float64 PGD and APG, Float32 APG, with 10
input draws each, on Julia 1.10 and 1.13 and two CPU models) it met the
independently computed targets of a relative duality gap of `1e-8` in Float64
and `1e-5` in Float32. It is **not** a guarantee of accuracy on other problems,
and `converged=true` is still not a certificate: check the returned point
independently, for example with [STOP-13](@ref). With this configuration
Float32 PGD reached its floating-point fixed point and met the independent
`1e-5` target on the benchmark cases (in these probes, with `maxiter = 10000`;
10 input draws each, on Julia 1.10 and 1.13, one CPU model). With the stagnation
stop (see [STOP-11](@ref)), such a solve ends, before `maxiter` on those
cases, at an iteration that meets its condition, with `stagnated=true` and
`converged=false`. At an iteration whose accepted iterate is unchanged, the
computed `x` and gradient tests can hold (the computed gradient residual can be
`0`), but under `ftol = 0` the exact-stall rule (see [STOP-10](@ref)) does
not count them; between such iterations the iterate can still move. The computed
residual is not an accuracy measure: the `1e-5` target was checked with the
independent duality gap.
These probes were made before the stationarity check of a stop was added
(see [The stationarity check of a stop](@ref STOP-04)); they are not repeated here for the current code.

## Option effects in those probes

- **`allow_f_increases = true`.** With the objective test off, a computed
  increase of `F` still ends the solve under the default
  `allow_f_increases=false`, and reports `converged=false` unless the `x` or
  gradient test held. Near a minimizer such increases can be at the level of
  rounding (see above). In the benchmark probes, switching off the objective
  tests alone ended most solves at an increase, and the configuration above,
  which met the targets in those probes, enables increases.
- **`xtol` is not an accuracy criterion for PGD.** PGD's step is scaled by
  `1/L`, where `L` is the inverse step size, so the test
  `norm(x - x') < xtol * max(norm(x), 1)` bounds the proximal-gradient residual
  by about `L * xtol * max(norm(x), 1)`, which depends on `L`, on the scale of
  `x` and on the penalty level `λ`, not on an accuracy target. In the benchmark
  probes with `xtol = 1e-14`, one Float64 PGD draw (on Julia 1.10) missed the
  target, and it ended on the `x` test. `xtol = 1e-300` lets that test hold
  only for steps of norm below `1e-300 * max(norm(x), 1)`, which still includes
  a nonzero step that small (for example `x = [1e-310]` after
  `x_previous = [0.0]`). In the benchmark probes with these tolerances, all
  Float64 solves ended on the gradient test.

## Global residual versus coefficient error

The check bounds the residual relative to `max(λ, λmax)`. A coordinate whose
gradient is on a scale far below `λmax` can stay inaccurate when the check
passes: for `X = diag(1e6, 1)`, `y = [1e6, 1]`, `λ = 0` from a cold start with
the default options, a review run reported convergence after 9 or 10
iterations with an independent relative KKT residual of a few `1e-6`, while the
coefficient of the flat column was almost 1 off. `converged=true` is not a
guarantee of coefficient accuracy.

## Rounding of the computed objective

**Why rounding triggers it.** For the supported least-squares lasso, with
the backtracking line search's default `Lexact = Inf`, an accepted step
does not increase the objective in exact arithmetic. A computed increase
comes from floating-point rounding. Near a minimizer, the true change in
`F` per step becomes smaller than the rounding error of evaluating `F`
in the working precision (which depends on the data; on a small test
problem of this package, a first-order bound is about 16 `eps(T)`
relative), so the sign of the computed change is decided by rounding.
At strict tolerances, whether a solve that has reached the neighborhood
of a minimizer ends with `converged=true` or with an objective-increase
stop can therefore depend on the last bits of the trajectory rather than
on the accuracy of the point. Those bits can change with the
starting point, the CPU and its vector width, the BLAS kernel, and how the
code is compiled (for example, with coverage instrumentation). It
matters mainly for tolerances near or beyond the working precision, and
the package's tests see it most often with `Float32`. In both directions, assess the returned point with the
[independent KKT residual](../../learn/02-optimality-kkt.md), not with `converged`
alone.

## PGD rejection-check measurements

In the package's probes (seeded Float32 and Float64 designs, including `p > n`,
near-duplicate columns, column scales over `10^±3`, residuals orthogonal
to the range of `X` and warm starts at the optimum), no accepted step
increased the objective by more than `64 eps(T) |F|`, evaluated in higher
precision; this is a measurement, not a guarantee.

For Float64 data, the baseline also records a narrow band around squared-norm overflow where `norm(d)^2` stays finite while the check's sum of squares overflows. Probes with random displacements of lengths 10, 100 and 1000 observed this within about `2 eps` of the threshold. No scaling occurs in that band; the original trial decision remains.

The statement above is a measurement, not an acceptance guarantee; [LS-03](@ref) and [LS-04](@ref) specify the actual check and its limits.

## A stricter-options run in the solver guide

This extract refers to the two-coefficient examples in [Choosing a solver](../../choosing-solver.md#Proximal-gradient-descent); “above” in the quotation refers to that original page.

> With these stricter tolerances and the default `allow_f_increases=false`, PGD on
> this problem ended on the objective-increase stop with `converged=false` in a
> test run on Julia 1.13.3; `allow_f_increases=true` lets it continue to a stop
> that passes the check (see "Strict accuracy" in [Numerical behavior](../pg-stopping.md)).
> The two results above report both coefficient error (possible here because
> the analytic answer is known) and an independently computed
> [KKT violation](../../learn/02-optimality-kkt.md). On other problems, evaluate the KKT
> condition directly instead of trusting `converged` alone.

**Sources.** `docs/src/numerics.md:L331`, `docs/src/numerics.md:L336`, `docs/src/numerics.md:L356`, `docs/src/numerics.md:L363`, `docs/src/numerics.md:L186`, `docs/src/numerics.md:L291`, `docs/src/numerics.md:L928`, `docs/src/numerics.md:L1031`, `docs/src/numerics.md:L1032`, `docs/src/choosing-solver.md:L167`.
