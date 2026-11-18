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

## The criterion and a certificate

Meeting the implemented stopping criterion is not the same as holding an independently
certified optimum. The solvers stop on three kinds of evidence:

| Solver | A stop is proposed by | Vetoed by | `converged = true` means | Kind of evidence |
| --- | --- | --- | --- | --- |
| `CDSolver`, least squares with `NormL1` or `ElasticNet` | a full pass whose largest change, scaled when relative scaling is active, is below the threshold | nothing | with `relative = true` and `y ≠ 0`: each scaled change `abs(h_k) √(s a_k)` of one full pass is below `tol √s ‖y‖`, with `a_k = ‖X_k‖²`; with `relative = false`, or `y = 0`: each `abs(h_k)` is below `tol` | a change test, with no independent check |
| `CDSolver`, group lasso | the same, with the change of a group | nothing | the same per group: the scaled change is `‖h_k‖ √(s ℓ_k)`, with `ℓ_k` the curvature bound of the group, and the unscaled one `‖h_k‖` | a change test, with no independent check |
| `ProximalGradientDescent`, `AccProxGradDescent` | the `x`, objective or gradient test of an iteration | the stationarity check | a test proposed a stop and the computed `‖G‖∞` is below `max(gradtol, 64 eps(T)) * max(λ, λmax)`, with `λ` the ℓ1 level (for `NormL1(λ, w)`, the largest coefficient `maxⱼ cⱼ` with `cⱼ = T(λ) wⱼ`; each entry of `G` is scored with its own `cⱼ`; see [the stationarity check](@ref "The stationarity check of a stop")) | a residual formed in working precision |
| `CDSolver`, square-root lasso, `λ > 0` | a full pass below the threshold | the duality certificate | where the minimum `P*` is positive: a proved `(P − P*)/P* < 1e-4`, with `gap` the bound; for `y = 0` and `x = 0`, where `P* = 0`: exact optimality, with `gap = 0` | a bounded gap |

In the CD rows, `h_k` is the change of coordinate (or group) `k` in the pass and `s` the loss scale.
In the first two rows the changes are computed from the solver's cached residual, and the flag does not
say that this cache is close to `y − Xx` at the returned point (see
[The cached residual](@ref "The cached residual")).

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

### The cached residual

The example is one form of a wider limit. For a least-squares loss, CD keeps the residual
`r = y − Xx` in a cache. `solve!` computes the cache from the start in working precision, and each
coordinate or group step then subtracts its own change from it. The steps read the cache, and the
change test reads the steps. In a solve without momentum, which includes every group-lasso solve,
the cache is not computed again from the coefficients. With momentum (the default for a vector
iterate with the random order) it is computed again before a full pass when an extrapolation has
moved it since it was last computed; the first pass of a solve is a full pass, and no such
computation precedes it.

The intermediate sums of `y − Σ X_k x_k` can be much larger than the residual itself, and their
rounding can then lose `y`; this happens where column images `X_k x_k` of the start are much larger
than `y`. In exact arithmetic a step changes the cache and `y − Xx` by the same amount, so an
error `e` of the cache is not removed by the steps that follow: until the cache is computed again,
the passes are those of the problem with the response `y + e`, and the change test can be met at a point that is not near a minimizer
of the problem that was posed. For `CDSolver` with a least-squares loss, `converged = true` reports
the change test as computed from the cached residual. It is not a certificate of stationarity, and
it does not say that the cache is close to `y − Xx` at the returned point.

### What the study of issue #378 measured

[Issue #378](https://github.com/mlakolar/ProximalSolvers.jl/issues/378) measured how far this limit
reaches: revision `8cc0222`, Julia 1.13.4 and 1.10.13, two CPU kinds, and 1,667,350 solves per run on
49 designs (ten of the designs of the audit and 39 generated ones, up to 5000×20 and 50×200) with lasso,
elastic-net, ridge and group-lasso penalties, in Float32 and Float64. Each returned point was
evaluated in 600-bit arithmetic. Most of the starts were built to provoke the failure:
`x_ref + 2^j z` for a reference solution `x_ref`, up to five directions `z` per design, scaled so that the largest
column image of `z` has the norm of `y`, and `j` up to 28 in Float32 and 60 in Float64. The counts are
for those designs and starts; they are not rates to expect on other problems. They are from one run
under Julia 1.13.4. The other three runs give close counts: 264,651 to 264,960 false stops where this
run has 264,795, and 443 to 464 where it has 434.

A *false stop* below is a solve with `converged = true` whose returned point is above the benchmark
target (a relative suboptimality of `1e-8` in Float64 and `1e-5` in Float32) and at which an exact
first visit would change a coefficient or group by more than `p` times the threshold, in the scaled
unit of the change test, with `p` the number of columns. In exact arithmetic a converged full pass
does not leave that much: a visit changes its coordinate by at most the KKT residual divided by the curvature, so
the bounds of
[What the change test of coordinate descent implies](@ref "What the change test of coordinate descent implies")
limit that change to `p − 1` times the threshold for the lasso and the elastic net, and to the number
of groups times the threshold for the group lasso.

- **The cache was stale at each false stop.** With `relative = true` the run has 264,795 false
  stops, 163,901 with a vector penalty and 100,894 with the group lasso. At each of them the cache
  differed from `y − Xx` at the returned point by at least `tol ‖y‖` in the Euclidean norm, which is
  the threshold divided by `√s`. Converged solves above the target occur with `relative = false` as
  well (3,606 Float32 solves with a vector penalty from the starts `x_ref + 2^j z` ended above the
  target after a pass that changed nothing); the study did not classify them further.
- **A pass that changed nothing is not the marker.** 30,258 of the false stops (11%) ended, as the
  example does, with a full pass in which no coefficient or group changed. In the others the last
  pass moved coefficients or groups, each by a scaled change below the threshold. One hand-built case of the study: from the
  start `2^50 e_1` on the Gaussian design of the audit, a Float64 solve with cyclic order and no
  momentum converged in 16 passes at a point whose exact KKT residual is `5.9e-3` of
  `max(λ, λmax)`; with the default options the same start ended at `2.3e-10`.
- **The size of the start.** Converged solves with a vector penalty, and the false stops among them
  (a dash: `j` is not in the ladder of that precision):

  | start | Float32 | Float64 |
  | --- | --- | --- |
  | zero, or the next point of a λ path | 0 of 36,383 | 0 of 44,840 |
  | the reference solution, or a perturbation of it | 128 of 54,850 | 64 of 67,933 |
  | an unpenalized least-squares point | 158 of 24,080 | 196 of 29,955 |
  | `x_ref + 2^j z`, `j = 0` | 80 of 28,881 | 80 of 28,930 |
  | `j = 8` | 122 of 27,086 | 80 of 27,244 |
  | `j = 12` | 653 of 24,922 | – |
  | `j = 16` | 7,785 of 23,601 | 80 of 23,848 |
  | `j = 20` | 15,319 of 23,526 | – |
  | `j = 36` | – | 480 of 22,454 |
  | `j = 40` | – | 4,154 of 22,256 |
  | `j = 48` | – | 13,920 of 22,197 |

  In this table the false stops become frequent between `j = 12` and `j = 16` in Float32 and between
  `j = 36` and `j = 40` in Float64, where the largest column image of `2^j z` is that power of two
  times `‖y‖`. The study does not establish a size of the start
  below which the stop is reliable: the false stops of the second and third rows, and those at
  `j = 0`, are on the rank-deficient design of the audit, and two Float32 false stops at `j = 4` on
  another design started from column images whose norms sum to 29 `‖y‖`.
- **An ordinary start that meets it.** The 158 and 196 false stops of the third row are warm starts
  of a problem with a positive penalty from the unpenalized least-squares point of the
  rank-deficient design. That point has cancelling coefficients, and the norms of its column images
  sum to `7e6 ‖y‖` in Float32 and `2e15 ‖y‖` in Float64. The false stops of the second row are on the same
  design with `λ = 0`, where the reference solution is itself such a point. From zero, from a λ-path
  point, and from the reference solution or its perturbation on a problem with a positive penalty,
  the sweep has no false stop.
- **The configuration.** Float32, starts `x_ref + 2^j z`; the three rows for a vector penalty are on
  the same designs and differ in the number of solves (the second row passed a `SparseIterate`, the
  other two a dense vector):

  | configuration | converged | false stops |
  | --- | --- | --- |
  | vector penalty, cyclic order, no momentum | 69,244 | 27,116 |
  | vector penalty, random order, no momentum | 75,612 | 30,924 |
  | vector penalty, random order, default momentum (`CDSolver()`) | 74,694 | 434 |
  | group lasso, cyclic order | 44,594 | 19,174 |
  | group lasso, random order | 90,625 | 38,936 |

  The default configuration for a vector iterate, which is the one that computes the cache again
  during the solve, is much less exposed. It is not immune: with the default options (random order,
  default momentum) CD also returns the start of the example above with `converged = true` after one
  pass. The group lasso runs without momentum.

### No change to the solver

The study built four changes to the solver and compared them with requirements fixed before the
measurements: stop without `converged = true` on the example above and on its `λ = 0` variant; with
constants fixed on the designs of the audit, lose none of the solves that must keep converging,
there and on the generated designs (ordinary starts, a positive penalty, converged at a point that
is not above the target); and stay within the repository's limit of 5% on the time of an ordinary
solve. None of the four met them.

- A statistic of the visits that changed nothing caught 6% of the false stops, and not the `λ = 0`
  variant of the example.
- Two rules triggered by a statistic of the rounding accumulated along the solve, one that compares
  the cache with a recomputed residual and reports, and one that recomputes the residual and
  continues, left 22 and 0 of the 114,053 false stops (vector penalties) of their comparison with
  the unchanged solver. They lost 64 and 17 Float32 solves that must keep converging, and 23 and 51
  of 260 timing cases, small warm-started solves among them, were more than 5% slower.
- A rule that recomputes the residual when a first-order estimate of the rounding error of the
  last computation of the cache is large, and stops without `converged = true` when that estimate
  is large at the stop, lost none of those solves and left 18 of the 114,053. It was designed after the results were
  known, and its constant has no validation on designs that were held out. It reports
  `converged = false` at some exact minimizers with heavy cancellation, its group form is looser
  than its vector form and not range-safe, and one of its timing cases was above 5% in both of
  two runs. Its estimate is not a bound on the error of the cache, so passing its tests would not
  certify the residual either.

The stopping rule, its defaults and the work of a solve are therefore unchanged, and the limit of
this section remains; [issue #392](https://github.com/mlakolar/ProximalSolvers.jl/issues/392) tracks
it. The measurements are in the
[report](https://github.com/mlakolar/ProximalSolvers.jl/issues/378#issuecomment-6977946590); the
scripts, tables and prototype patches are on the branch
[`archive/issue-378-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/archive/issue-378-evidence).

What you can do:

- Start from zero, or from a point at the scale of the solution such as the previous point of a
  λ path.
- Do not warm-start from a point whose column images are far larger than the response. An
  unpenalized fit with large cancelling coefficients is such a point, and a rank-deficient or
  nearly collinear design is where such fits arise; the study gives no size below which a start is
  safe.
- Evaluate the [KKT residual independently](sparsity-and-kkt.md) at the returned point. It forms
  `y − Xx` from the returned coefficients, so it does not inherit the error of the cache; where the
  returned coefficients are still far above the scale of the solution, as in the example, evaluate
  it in higher precision.
- Calling `solve!` again from the returned point also computes the cache from the returned
  coefficients. The study did not measure this, and it is not guaranteed to improve the result: it
  still fails on the example above, which returns its start.

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
