# Limits of the stopping tests

This page collects what `converged = true` says for scalar CD, group CD, PGD and APG, and
the measured limits of their stopping tests. The numbers come from the Stage 0 audit of
[issue #352](https://github.com/mlakolar/ProximalSolvers.jl/issues/352), run at revision
`b8a2c04` on Julia 1.13.4; Julia 1.10.13 was run as well and gave close but not identical counts.
The audit used 11 small designs (20 to 60 rows, 8 to 60 columns) and evaluated each solve in
600-bit arithmetic on the rounded inputs the solver received. These are high-precision
evaluations, not proofs, and the counts are for those designs: they are not rates to expect on
other problems.

## The criterion and a certificate

Meeting the implemented stopping criterion is not the same as holding an independently
certified optimum. The solvers stop on three kinds of evidence:

| Solver | A stop is proposed by | Vetoed by | `converged = true` means | Kind of evidence |
| --- | --- | --- | --- | --- |
| `CDSolver`, least squares with `NormL1` or `ElasticNet` | a full pass whose largest change, scaled when relative scaling is active, is below the threshold | nothing | with `relative = true` and `y ≠ 0`: each scaled change `abs(h_k) √(s a_k)` of one full pass is below `tol √s ‖y‖`, with `a_k = ‖X_k‖²`; with `relative = false`, or `y = 0`: each `abs(h_k)` is below `tol` | a change test, with no independent check |
| `CDSolver`, group lasso | the same, with the change of a group | nothing | the same per group: the scaled change is `‖h_k‖ √(s ℓ_k)`, with `ℓ_k` the curvature bound of the group, and the unscaled one `‖h_k‖` | a change test, with no independent check |
| `ProximalGradientDescent`, `AccProxGradDescent` | the `x`, objective or gradient test of an iteration | the stationarity check | a test proposed a stop and the computed `‖G‖∞` is below `max(gradtol, 64 eps(T)) * max(λ, λmax)` | a residual formed in working precision |
| `CDSolver`, square-root lasso, `λ > 0` | a full pass below the threshold | the duality certificate | where the minimum `P*` is positive: a proved `(P − P*)/P* < 1e-4`, with `gap` the bound; for `y = 0` and `x = 0`, where `P* = 0`: exact optimality, with `gap = 0` | a bounded gap |

In the CD rows, `h_k` is the change of coordinate (or group) `k` in the pass and `s` the loss scale.

Of the problems audited, only the square-root lasso carries a certificate, and that
certificate has the assumptions stated in [The certificate](@ref "The certificate") and
[Tightening and the uncertified stop](@ref "Tightening and the uncertified stop"). For the
other solvers `converged = true` reports that the criterion of its row was met. Check the
returned point with the [independent KKT residual](sparsity-and-kkt.md) when the result
matters.

## What the change test of coordinate descent implies

Assume exact arithmetic, a full pass without extrapolation, exact minimization at each
scalar visit, and relative scaling (`relative = true`, `y ≠ 0`), so that the threshold is
`τ = tol √s ‖y‖` with `s` the loss scale. Let `X_k` be column `k` of `X`, `p` the number of
columns, `h_j` the change of coordinate `j` in the stopping pass, and `G_k` the minimal-norm
KKT residual of coordinate `k` at the end of the pass. Coordinate `k` is at its minimizer when it is
visited, and only the updates of the coordinates visited after it move its gradient, so

~~~
|G_k| ≤ s ‖X_k‖ Σ_{j visited after k} ‖X_j‖ |h_j| ≤ (p − 1) · tol · s ‖X_k‖ ‖y‖     (lasso and elastic net)
‖G_k‖ ≤ K · tol · s √ℓ_k ‖y‖                                                          (group lasso, K groups)
~~~

with `ℓ_k` the curvature bound of group `k`. The elastic net adds no cross term. The first
inequality holds for any visiting order. Momentum does not enter, because the stopping pass has
no extrapolation. For the group lasso the visit is a majorization step with
`0 ⪯ X_kᵀX_k ⪯ ℓ_k I`, not a block minimization: the residual of group `k` after its own step is
at most `√(s ℓ_k) τ`, and each group visited after it adds at most the same, which gives the
factor `K`.

With the absolute threshold (`relative = false`, or `y = 0`) the scale `‖y‖` drops out:

~~~
|G_k| ≤ s · tol · ‖X_k‖ Σ_{j visited after k} ‖X_j‖
‖G_k‖ ≤ s · tol · (ℓ_k + √ℓ_k Σ_{j visited after k} √ℓ_j)                            (group lasso)
~~~

The scalar bounds are not strict: both sides are 0 for `p = 1` and for a flat column. What remains
unguaranteed, and why the flag is not a KKT certificate:

- the factor `p − 1` or `K`;
- the unit `s ‖X_k‖ ‖y‖` in place of `λmax` (a factor 5.5 on the equicorrelated design with
  correlation 0.95 of the audit, and unbounded in the cancellation example below);
- rounding (see the warm start below);
- range (see the underflow example below).

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

## Products formed in working precision

CD, PGD and APG form the product of `X` with a residual in the working type, before the loss
scale is applied: CD forms `rᵀX_k` for the coordinate step, and PGD and APG form `Xᵀd` for the
gradient. When that product underflows or cancels, the stop of each of the three can be met at a
point that is not a minimizer. The solvers do not recover such a product (see the sentence on
an `Xᵀd` that underflows or overflows before the scaling in
[Working precision: Float32 and Float64](@ref "Working precision: Float32 and Float64")).

**Underflow.** One column with entries `2^-500`, `y` entries `2^-700`, two rows, loss scale
`2^300`, and `λ = α Xᵀy / 8` for the exact `Xᵀy`:

```julia
using ProximalBase, ProximalSolvers

n = 2
X = fill(2.0^-500, n, 1)
y = fill(2.0^-700, n)
α = 2.0^300                      # loss scale
λ = 2.0^-902                     # α Xᵀy / 8, with the exact Xᵀy = 2 * 2^-1200
sum(y .* vec(X))                 # the computed Xᵀy is 0.0

loss = α * LeastSquaresLoss(y, X)
for solver in (CDSolver(order = :cyclic, momentum = false),
               ProximalGradientDescent(), AccProxGradDescent())
  x = zeros(1)
  r = solve!(x, loss, NormL1(λ), solver)
  println(nameof(typeof(solver)), ": x = ", x[1], ", converged = ", r.converged)
end
```

All the numbers are normal Float64 numbers, and the exact minimizer is `5.4e-61`. CD, PGD and APG
return `x = 0` with `converged = true`; `CDSolver()` with its default options does as well. The exact KKT
residual, evaluated in 600-bit arithmetic, is 0.875 of `max(λ, λmax)`, and the objective is 4.27
times the minimum (`(F − F*)/F* = 3.27`). PGD and APG pass the
[stationarity check of a stop](@ref "The stationarity check of a stop") because it reads the same rounded
gradient product and the same rounded `λmax` product: the computed gradient is 0, `λmax` is computed
as 0 for the same reason, so `S = λ`, and the computed residual 0 is below the bound.

**Cancellation.** One column `X = [1, d, −1]`, `y = [1, 1, 1]`, `d = eps(T)/2` and `λ = d/8`:

```julia
using ProximalBase, ProximalSolvers

for T in (Float64, Float32)
  d = eps(T) / 2
  X = reshape(T[1, d, -1], 3, 1)
  y = ones(T, 3)
  λ = d / 8
  for solver in (CDSolver(order = :cyclic, momentum = false),
                 ProximalGradientDescent(), AccProxGradDescent())
    x = zeros(T, 1)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ), solver)
    println(T, " ", nameof(typeof(solver)), ": x = ", x[1], ", converged = ", r.converged)
  end
end
```

The exact `Xᵀy` is `d`; it is computed as 0. All three solvers return `x = 0` with
`converged = true`, in Float64 and in Float32. The exact KKT residual is 0.875 `λmax`, and the
relative objective error is negligible (`1.6e-33` in Float64, `4.5e-16` in Float32). This is the
underflow example without the range: the exact value of `Xᵀy` is at the rounding level of
`‖X_k‖ ‖y‖`, and the residual is large only relative to a `λmax` that is itself at that level. A check that
reads the same working-precision products computes 0 there as well.

In CD the same product enters the coordinate step. In both examples the full pass changes nothing, and
a pass with no change meets the change test.

What you can do: keep the loss scale and the data in a range where `Xᵀr` is representable, and
evaluate the [KKT residual independently](sparsity-and-kkt.md), in higher precision, for results that matter.

## A warm start far above the solution scale (coordinate descent)

The start of `solve!` can place coefficients far above the scale of the solution. With
`X = ones(1, 2)`, `y = [1/64]`, `λ = 1/1024` and the start `[2.0^49, -2.0^49]`
(Float32: `2f0^20`):

```julia
using ProximalBase, ProximalSolvers

for (T, M) in ((Float64, 2.0^49), (Float32, 2f0^20))
  X = ones(T, 1, 2)
  y = T[1 / 64]
  λ = T(1 / 1024)
  start = T[M, -M]
  for solver in (CDSolver(order = :cyclic, momentum = false),
                 ProximalGradientDescent(), AccProxGradDescent())
    x = copy(start)
    r = solve!(x, LeastSquaresLoss(y, X), NormL1(λ), solver)
    println(T, " ", nameof(typeof(solver)), ": x == start is ", x == start,
            ", converged = ", r.converged)
  end
end
```

CD returns the start with `converged = true` after one pass. The exact KKT residual is 1.06 of
`max(λ, λmax)`, and `(F − F*)/F*` is `7.4e16` (`1.4e8` in Float32). PGD and APG also return the
start, at `maxiter` with `converged = false`. The mechanism for this example: the
residual is initialized as `y − Σ X_k x_k` in working precision, which loses `y` against the
coefficients `M`; each coordinate step is then smaller than half a unit in the last place of the
coefficient, so the new value equals the old one; and a full pass with no change satisfies `0 < tol`.

Related degradation appears in the sweep. With `λ = 0` on the rank-deficient design, the exact
least-squares minimizer has large cancelling coefficients, and the warm starts taken from it give 80
converged solves per precision at the default threshold, with an exact KKT residual up to `0.063 λmax`
in Float64 and `0.16 λmax` in Float32; the cold starts on the same problems end at `1.7e-8 λmax` or
below in Float64 and `5.7e-8 λmax` or below in Float32. The stopping pass changed nothing in 24 of the
Float32 rows and in none of the Float64 rows; the others stopped on a small nonzero change. The
empty-pass mechanism is therefore established for the example above, not for all of these rows.

What you can do: start from zero or from a point of the scale of the solution, and check the KKT
residual independently. Whether CD can stop reliably at a pass that changed nothing is tracked in
[issue #378](https://github.com/mlakolar/ProximalSolvers.jl/issues/378); the behaviour described
here is unchanged.

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
  which says that a Float32 solve can end on it. [Issue #320](https://github.com/mlakolar/ProximalSolvers.jl/issues/320)
  has the measurements on the benchmark designs.
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
