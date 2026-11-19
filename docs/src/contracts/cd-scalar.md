# [Scalar coordinate descent](@id CD-01)

<!-- Migration source: docs/src/numerics.md:L9-L55 -->

- **Coordinate descent (CD):** the change during a full pass has fallen
  below the effective `tol` (for the square-root lasso, a duality certificate must also pass; see
  the square-root lasso section below). With `relative=true` this threshold is
  scaled by a response-dependent quantity, `sqrt(s * sum(abs2, y))`, formed
  so that the sum of squares and its product with the loss scale `s` may
  leave the range of the working type; the reported effective
  tolerance can differ from the value passed to the constructor. When
  relative scaling is active (`relative=true` and a positive response scale),
  each coordinate change is also multiplied by `sqrt(s * a)` for the squared
  norm `a` of its column, formed from the two square roots where the product
  `s * a` is zero, subnormal or overflowing for a finite `a`; a nonzero change
  times an infinite scale (a computed scale that overflows the working type) is
  refused with an `ArgumentError`. The coordinate step forms its threshold
  `lambda / (s * a)` without the product or its reciprocal where either is
  outside the normal range (with weights, outside that range `lambda` stands for the coefficient `T(lambda) * w[k]`
  rounded in `T`; inside it ProximalBase's `prox_block` forms its threshold from `lambda` and `w[k]`), and a column whose squared norm is not finite is
  refused with an `ArgumentError` that names the curvature. For an `ElasticNet`,
  in the normal range the step of a visit is ProximalBase's `prox_block`. At a visit to a column
  with a finite positive `a` where `s * a` or its reciprocal is below `floatmin` of the type that
  combines `s` with the working type, the step with `lambda2 = 0` is the lasso's, and with
  `lambda2 > 0` the visit is refused with an `ArgumentError` that names the coordinate, during the
  pass: the iterate passed to `solve!` is unchanged, and a borrowed RNG may have advanced.
  A visit to a flat column (all entries 0) sets its coordinate to 0 at the levels that `solve!`
  accepts (also for a `NormL1` at a zero weight), and a visit to a column that is not flat whose `a` underflows to 0 is refused with an
  `ArgumentError` about the curvature, as for the lasso. With `maxpasses = 0` no coordinate is visited. With
  `relative=false`, or with `y = 0`, the coordinate scale is
  not used. If the computed `sqrt(s) * norm(y)`, after
  rounding to the working type, is not a normal floating-point number, the
  solve is refused with an `ArgumentError` before the first pass (rescale, or
  use `relative=false`, which can still end in the `nonfinite objective`
  refusal described below); a value within a rounding error of the limits can
  fall on either side. `y = 0` uses the absolute threshold. `tol` times a
  normal scale can be subnormal or 0; the test `change < threshold` cannot hold
  for a threshold of 0, so such a run cannot converge by it and ends at
  `maxpasses` with a warning, unless an independent numerical failure (for
  example a non-finite coordinate step) stops it first with an error. Once the
  active passes since the last full pass have together visited 20 times as many
  coordinates as a full pass, the next pass is a full pass even when the active
  changes have not fallen below the threshold. Float32 rounding of the
  coefficients can also keep the largest change of every full pass at or above
  the effective threshold (the reported `tolerance`, against which the change is
  compared after the scaling described above when relative scaling is active);
  the run then ends at `maxpasses` without converging, with the warning. A
  threshold well above that rounding level avoids this; Float64 data has a much
  lower rounding level.
  For a group lasso on a `BlockIterate`, the change is that of a whole group; see
  [Group lasso on a BlockIterate](@ref "Group lasso on a BlockIterate").

<!-- Migration source: docs/src/stopping-limits.md:L42-L98 -->

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

<!-- Migration source: docs/src/stopping-limits.md:L170-L228 -->

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

<!-- Migration source: docs/src/developer/implementation-notes.md:L260-L284 -->

CD runs on a PB SparseIterate that retains stored activation/compaction order: a
private one for a dense vector, and a private copy of the caller's owner for a
`SparseIterate`, which starts with that owner's active zeros and slot order and
which the caller's owner receives, whole, only after a finite completed run. First
full passes admit coordinates, active passes refine them, and only a full pass
strictly below the change tolerance converges. Once the active passes since the
last full pass have together visited 20 times as many coordinates as a full pass,
the next pass is full. Random LS uses historical momentum/restarts and refreshes
moved residual caches before full checks, including before such a forced full
pass; the borrowed RNG advances.
Cyclic and explicit momentum=false remain supported.
Zero columns choose the nearest-zero penalty minimizer, including lambda=0.
Nonzero-column curvature underflow, and a curvature that is not finite, are errors. tol=0 stays strict; maxpasses=0
returns unconverged with no updates, and an owner then keeps its exact entry state.
After every pass zero coordinates leave the active set, so an owner that completed
at least one pass has none and their order follows from compaction, which moves the
last active coordinate into the place of a removed one. A nonfinite returned
objective is refused before dense scatter or owner commit; this is not robust
dynamic-range recovery. A nonconverged finite pass-limit return warns, then commits.
A numerical error leaves a caller's owner unchanged but may advance the RNG.
Dense and owner solves from the same canonical state (the owner built from the
dense vector) run the same arithmetic and RNG schedule. A different slot order of
the same active set can change the trajectory and the final point, and the change
stopping rule gives no general bound on the distance to a minimizer or on the KKT
violation: assess accuracy with an independent objective/KKT check.

<!-- Migration source: docs/src/choosing-solver.md:L51-L97 -->

CD forms this scale without the sum of squares `sum(abs2, y)` or its product
with `s` having to stay in the range of `Float32` or `Float64`: where either
overflows or underflows it uses wider or exponent-separated arithmetic. There
are three outcomes. A scale that is a normal floating-point number of the
working type is used. For `y = 0` the scale is 0 and CD uses the absolute
threshold. If the computed `sqrt(s) * norm(y)`, after rounding to the working
type, is not a normal number (above its largest finite value or below its
smallest normal number), `solve!` throws an `ArgumentError` before the first
pass and leaves the starting point unchanged. A value within a rounding error
of those limits can fall on either side. In that case rescale the data or the
loss, or use `relative=false`; with `relative=false` a problem whose objective
overflows can still end in the `nonfinite objective` error described in
[Numerical behavior](../numerics.md). A normal scale can still give a threshold
`tol * scale` that is subnormal or 0. The change test `change < threshold`
cannot hold for a threshold of 0, so the solve cannot converge by this test:
it ends at `maxpasses` with a warning, unless an independent numerical failure
(for example a non-finite coordinate step) stops it first with an error.

When relative scaling is active (`relative=true` and a positive response
scale), each coordinate change is also multiplied by `sqrt(s * a)`, where `a` is
the squared norm of the column. With `relative=false`, or with `y = 0`, the
coordinate scale is not used. Where the product `s * a` is zero, subnormal or
overflowing for a finite `a` (in the type that combines `s` with the working
type), CD takes the square roots of `s` and of `a` separately and multiplies
them, so the scale does not become 0 or infinite because the product left the
range. The computed scale is still 0 where the root is at most half the
smallest subnormal number, and infinite where the computed, rounded scale
overflows the working type; with relative scaling active a nonzero coordinate
change times an infinite scale makes
`solve!` throw an `ArgumentError` ("a coordinate step or its stopping scale is
not finite") and leave the starting point unchanged.

The coordinate step soft-thresholds the unpenalized minimizer along the
coordinate at `lambda / (s * a)` (with weights, `lambda` stands for the coefficient `lambda * w[k]` of the coordinate; where the step forms its
threshold without the product, it uses `T(lambda) * w[k]` formed in `T`, which is 0 or a normal number on the inputs `solve!` accepts). Where `s * a` and its reciprocal are both at
least the smallest normal number of the type that combines `s` with the working
type, it applies the proximal operator with the coefficient `1 / (s * a)`.
Where one of them is smaller (the product is zero or subnormal, or it is large
enough that its reciprocal is subnormal or zero), that coefficient can be 0,
infinite or inexact. With a positive penalty, 0 would ignore the penalty and an
infinite coefficient would set a finite unpenalized minimizer to 0; a zero
penalty stays unpenalized for any coefficient. The step then forms the
threshold without the product and its reciprocal. A threshold above the largest finite number sets a
finite unpenalized minimizer to 0. A column whose squared norm `a` is not finite
in the working type makes `solve!` throw an `ArgumentError` that names the
curvature, with the starting point unchanged.

<!-- Migration source: src/cd/solver.jl:L6-L31 -->

Coordinate descent for the least-squares lasso and elastic net, and, with ProximalBase's
`SqrtLeastSquaresLoss`, the square-root lasso (described below). Call
`solve!(beta, f, g, CDSolver())` with matching `Float32` or `Float64`
design/response data and coefficients. The coefficient storage can be
a dense `Vector` or a one-dimensional ProximalBase `SparseIterate`. With the least-squares
loss, the penalty is `NormL1(lambda)`, `NormL1(lambda, w)` or an unweighted `ElasticNet(lambda1, lambda2)`
(the square-root lasso, below, takes an unweighted `NormL1` with a positive level). The weights `w`
of a `NormL1` are a `Vector{T}` (`T` the element type of the data) with finite nonnegative entries (see
[`solve!`](@ref)): `solve!` checks the coefficient `T(lambda) w[j]` of entry `j`, the product rounded in `T`, to be zero
or a normal number of `T` (with `T(lambda)` zero or normal as well), and a zero weight leaves it unpenalized. The
coordinate step in the normal range is ProximalBase's `prox_block`, which forms its threshold from `lambda` and
`w[j]` in its working type; see [Supported problems](https://mlakolar.github.io/ProximalSolvers.jl/dev/support/#weighted-lasso-support)
for how that threshold and the checked coefficient can differ.
For an `ElasticNet` the coordinate step of a visit in the normal range is ProximalBase's
`prox_block` of the penalty. Let `s` be the loss scale and `a` the squared norm of the
column, finite and positive. At a visit where `s * a` or its reciprocal is below
`floatmin` of the type that combines `s` with the working type, the step with
`lambda2 = 0` is the lasso's range-safe form (the threshold formed without the product
or its reciprocal), and with `lambda2 > 0` the visit is refused with an `ArgumentError`
that names the coordinate; for a `NormL1` with weights the step there is the lasso's range-safe form at
the coefficient `T(lambda) w[k]` of the coordinate. The refusal happens during the pass: the iterate passed to
`solve!` is unchanged, and a borrowed RNG may have advanced. A visit to a flat column
(all entries 0) sets its coordinate to 0, at the levels that `solve!` accepts, for each of these
penalties (also where a weight is zero); a visit to a column that is not flat and whose `a` underflows to 0 is refused
as for the lasso. With `maxpasses = 0` no coordinate is visited.
For a group lasso it can be a ProximalBase `BlockIterate`, as described below.

<!-- Migration source: src/cd/solver.jl:L33-L38 -->

`CDSolver()` uses random coordinate order and the algorithm's default
momentum behavior, a reasonable exploratory choice. For deterministic
tutorial examples use `CDSolver(order=:cyclic, momentum=false)`;
for repeatable random order supply `rng=Xoshiro(seed)` from `Random`.
The borrowed RNG advances when used. Cyclic order does not support
`momentum=true`.

<!-- Migration source: src/cd/solver.jl:L40-L77 -->

`tol` (default `1e-7`) measures coefficient change, **not** independent
optimality (the square-root lasso adds a certificate, below). With `relative=true`, the
stopping threshold is `tol` times the
response scale `sqrt(s * sum(abs2, y))`, `s` the loss scale; the sum of
squares and its product with `s` may leave the range of the working type.
For `y = 0` the threshold is the absolute `tol`. A response scale whose
computed value, rounded to the working type, is not a normal number is refused
with an `ArgumentError` before the first pass: rescale the data or use
`relative=false` (an objective that overflows is still refused). `tol` times a
normal response scale can be subnormal or 0. The test `change < threshold`
cannot hold for a threshold of 0, so the run cannot converge by it and ends at
`maxpasses` with a warning, unless an independent numerical failure (for
example a non-finite coordinate step) stops it first with an error.
A column whose squared norm `a` is not finite in the working type is refused with
an `ArgumentError` before the first change of its coordinate, and the starting
point is unchanged. Where the product `s * a` or its reciprocal is outside the
normal range of the type that combines `s` with the working type, the
coordinate step forms its threshold `lambda / (s * a)` without them.
`relative=false` makes the threshold an absolute change threshold;
`maxpasses` limits the run. For least squares (lasso and elastic net) and the group lasso, an end-of-pass
convergence flag does not guarantee a small KKT residual; for reported fits, check
optimality independently. What the change test implies, and where it can be met away
from a minimizer (a product that underflows or cancels, a warm start far above the
solution scale), is described in the
[numerical guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/stopping-limits/).
Anderson acceleration, a user-set gap target and screening
are not implemented: `anderson`, `gaptol` and `gapsafe` are accepted only
at their defaults, are not stored, and other values are rejected.

Once the active passes since the last full pass have together visited 20 times
as many coordinates as a full pass, the next pass is a full pass even when the
active changes have not fallen below the threshold. Float32 rounding of the
coefficients can also keep the largest change of every full pass at or above the
effective threshold (the reported `tolerance`; with `relative=true` and a
positive response scale, each coordinate change is first multiplied by
`sqrt(s * a)`, `a` the squared norm of its column); the run then ends at
`maxpasses` without converging, with the warning. A threshold well above that
rounding level avoids this; Float64 data has a much lower rounding level.

