# [Working precision and numerical boundaries](@id FP-01)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/numerics.md:791-918 -->

All supplied `X`, `y` and coefficient entries must be finite.
Finite inputs do not guarantee finite intermediate arithmetic. The
ProximalBase mathematical kernels use selective overflow/underflow
recovery for some representable results, but ProximalSolvers does not
promise end-to-end recovery of every failed matrix product, curvature,
step or objective. Unrecoverable numerical failures are handled as
described below; a successful kernel recovery does not imply the
solver can continue in every extreme-range case.

All three solvers take the least-squares value from ProximalBase's oracles
(`value_from_predictor` and `value_and_gradient_from_predictor!` for PGD and APG,
`value_from_residual` for CD), and PGD and APG take the coefficient gradient from
`value_and_gradient_from_predictor!`. ProximalSolvers forms CD's coordinate
correlations and updates and the `λmax` product of the stationarity check, and
keeps the image `X x` (PGD, APG), the residual (CD), the steps, the line searches
and the stopping rules. The exact
accuracy and range statements are those of the section "Least squares at a
predictor or residual that the caller holds" of the
[ProximalBase guide to the smooth functions](https://github.com/mlakolar/ProximalBase.jl/blob/7d5d1e006b02814fb28f8cfb5eca20a05d73ee9e/docs/src/smooth.md); they are not restated here.
What changes for the solvers:

- CD takes the loss part of its objective from `value_from_residual` of its
  cached residual. ProximalBase recomputes exceptional values under the
  conditions its guide states (the "Value and rounding" section of the guide
  linked above); before, CD refused the finished solve where the sum of squares
  overflowed. The recovery holds for finite data and a value representable with
  ProximalBase's margin; near the overflow threshold its result can be `Inf` (the
  "Range" statement of the guide gives the conditions). CD returns an objective only when the loss plus the penalty is
  finite. Otherwise the finished solve is refused with a `nonfinite objective`
  `ArgumentError` and the starting point is unchanged; the sum can be non-finite
  where the recovered loss is finite, for example through an overflowing penalty
  value. Where the loss is below `floatmin(T)`, the
  guide's bound for the loss is `(n + 8) eps(T) |v|` plus
  `2 nextfloat(zero(T))`, with `n` the number of rows of `X` and `v` the exact
  value at the cached residual, so the reported loss part can be 0 or a small
  subnormal number.
- PGD and APG take the value at a start and at each trial from
  `value_from_predictor` (PGD's start and its gradient refreshes use
  `value_and_gradient_from_predictor!`, and so does APG's stationarity check). A
  start or trial whose value ProximalBase recovers, under the conditions of its
  guide, is evaluated finitely where the sum of squares overflows in `T`; before,
  the sum of squares was formed in `T` without that recovery.
- A start accepted in this way can have a finite value while `Σ(z - y)²` overflows
  in `T`. PGD and APG start their curvature estimate `L` at `min(1, α‖X‖_F²)` for the
  loss scale `α` (1 for an unscaled loss), with `‖X‖_F` the solvers' upper bound on the
  Frobenius norm of `X`. The start is `1` when that product is at least 1 or `X = 0`, and
  a positive start that rounds below `floatmin(T)` is raised to `floatmin(T)`. `L` is then
  multiplied by the line search's decrease factor (default 0.9) before each iteration and
  raised on a rejected trial. The start is the Frobenius bound `α‖X‖_F²` when that is positive and below 1,
  which exceeds the curvature `α‖X‖₂²` by the factor `‖X‖_F² / ‖X‖₂²` (at most the rank of `X`), up to
  rounding and the floor; a problem whose positive Frobenius bound is far below 1 therefore starts
  below 1, and one whose bound is 1 or more starts at 1 (for example `X = I(256)/16` with `α = 1` has
  curvature `1/256` and starts at 1). For
  `X = ones(5, 1)`, `y = fill(1e160, 5)`, loss scale `1e-100`, `NormL1(0.0)` and start 0,
  the curvature `α‖X‖²` is `5.000000000000001e-100`, `X` has rank one, and both solvers start at
  `5.000000000000014e-100`. APG ends with `converged = true` after 8 iterations, and with
  `NormL1(0.1 λmax)` after 7 (Julia 1.10.13 and 1.13.3 agree). PGD ends with
  `converged = true` after 10 iterations, and with `NormL1(0.1 λmax)` after 9 (Julia
  1.10.12 and 1.13.3 agree). Its backtracking test squares the step norm, which
  overflows once a step exceeds about 1.3e154; a trial with a finite value and a step of
  finite entries is then decided on a scaled step (see "Steps whose squared norm
  overflows" under "Results and failures").
- PGD and APG log no warning when they end at `maxiter`, so check `converged` and an
  [independent KKT residual](sparsity-and-kkt.md). CD logs a warning when a run ends with
  `converged = false`. CD solved the example above (`converged = true`, `x = [1.0e160]`);
  this is not a statement about extreme-scale problems in general.
- A rescaling can serve as a workaround where it keeps the minimizers. For a `NormL1`
  penalty, `x = s u` with `s > 0` replaces `X` by `sX` and `λ` by `sλ`, multiplies the
  curvature by `s²`, and turns a start `x₀` into `x₀ / s`. On the example with `s = 1e50`
  and level `1.0e60` replaced by `1.0e110`, the curvature is above 1, the start is `1`,
  and PGD and APG both returned `converged = true`, after 9 and 7 iterations. The
  transformation `X′ = cX`, `y′ = cy`, loss scale `α/c²`, with the penalty unchanged,
  keeps the objective and the curvature `α‖X‖²`, so it keeps the start up to rounding (with `c = 1e-80`
  on the example, APG converged after 8 iterations and PGD after 10; Julia 1.10.12 and 1.13.3 agree).
- The gradient is `α` times the rounded product `Xᵀd` with `d = z - y` for the
  image `z = X x`. An `Xᵀd` that overflows or underflows before the scaling is not
  recovered, also where `α` would bring the exact gradient into range.
- Where `z - y` overflows with finite entries, `value_from_predictor` recovers the
  value, while `value_and_gradient_from_predictor!` returns a non-finite value
  and non-finite gradient entries.
  - At a start where `z - y` overflows, PGD takes the start's value from
    `value_and_gradient_from_predictor!` and refuses a non-finite one with
    `ArgumentError("start from a point where f is finite")`, also where
    `value_from_predictor` is finite. APG takes it from `value_from_predictor` and accepts
    the start where that value is finite; its first step then fails with
    `ErrorException("the gradient step did not produce a finite objective")`. Both leave
    `x` unchanged (`Float32`, `X = [1;;]`, `y = [3f38]`, loss scale `1e-44`,
    `NormL1(0f0)`, start `[-3f38]`).
    [#328](https://github.com/mlakolar/ProximalSolvers.jl/issues/328) tracks the message
    and the difference.
  - In PGD a trial is evaluated by `value_from_predictor` and the gradient at an accepted
    trial by `value_and_gradient_from_predictor!`. Where the line search decides from
    function values, the code accepts a trial on its finite value, so an accepted iterate
    can hold a non-finite gradient; this was not reproduced and is not covered by a test.
    Expected from the code only: if another step is attempted from such an iterate,
    `x - ∇f/L` is non-finite for every finite `L`, and for a penalty whose prox keeps
    non-finite entries (as `NormL1` does) the trial values are non-finite, so the line
    search raises `L` (`src/line_searches.jl:113-118`) until `next_curvature` cannot
    increase it finitely and raises
    `ErrorException("line search failed: the curvature estimate cannot increase finitely")`;
    `solve!` then restores that iterate and rethrows (`src/solve.jl:223-231`); `maxiter`
    or another stop can end the solve before that step.
    In a `Float32` probe with `maxiter = 3000` (Julia 1.10.13 and 1.13.3), a trial whose
    gradient was non-finite was rejected, the step raised
    `ErrorException("line search failed: nonfinite curvature estimate")`, and the last
    accepted iterate was restored; this is not a guarantee for every setting.
- In Float64, a subnormal squared step norm `‖d̂‖²` of a PGD trial (a nonzero value below
  `floatmin(Float64)`) can make the line search's curvature estimates unreliable. Once the
  search uses gradients, it scales a gradient-difference product by `2/‖d̂‖²`, which
  overflows when `‖d̂‖² < 2/floatmax(Float64)` (about 1.1e-308). A zero product is not
  scaled: it gives the estimate 0 and the trial is accepted, where scaling would give
  `0 · Inf = NaN`. This does not make a solve converge at such scales: a solve can still end
  with `converged = false` or with a line-search error. One case is not handled: a nonzero
  product, or rounding noise in the function values, can give an infinite estimate, and when
  `sum(abs2, d̂)` underflows to 0 while `‖d̂‖² > 0` (every entry of `d̂` below about
  1.57e-162), the computed curvature of the step is not finite and does not replace that
  estimate. See `LineSearches.BackTracking`.

`Float32` has less precision and may stagnate earlier than `Float64`.
Some solver tolerances, residual reports and other scalar diagnostics
are stored as `Float64` even when the iterate is `Float32`;
this is bookkeeping, **not** higher-precision optimization or an
accuracy certificate. In particular, a tolerance tighter than the
working precision does not guarantee corresponding coefficient
accuracy. Assess the returned result with an
[independent KKT residual](sparsity-and-kkt.md), rather than relying
only on `converged`.

<!-- baseline: docs/src/developer/implementation-notes.md:153-188 -->

CD, PGD and APG read `Y`, `X` and the stored scale through
`ProximalBase.leastsquares_data`. PGD and APG take the value and the gradient
from `value_from_predictor` and `value_and_gradient_from_predictor!`, and CD
takes its final loss value from `value_from_residual` (which returns a value
only), with the rounding, recovery and bounds that ProximalBase states; the
solvers do not repeat those value and iterate-gradient computations. ProximalSolvers owns the caches (the image `X x`, the CD
residual and curvatures), CD's coordinate correlations and updates, the `λmax`
product of the stationarity check, the step and line searches, APG's certified
bound, the stopping rules and the rollback.
ProximalBase's selective recovery may avoid
intermediate overflow/underflow for representable values, but the
solver adds independent matrix products, state updates, stopping
and numerical-finiteness checks. Do not infer end-to-end recovery
from a successful ProximalBase oracle or promise a finite result for
every finite input.

The solver retains native `Float32`/`Float64` iterates and their
working accuracy. Some option tolerances and reported scalar
residuals are stored as `Float64`. They are diagnostic storage,
not a promotion of solver iterates or an optimality certificate.
`converged=true` retains its algorithm-specific historical meaning;
use independent objective/KKT checks for accuracy, especially with
`Float32`. BigFloat may be used for independent test references,
not as a supported solver working type; a `BigFloat`, `BigInt` or
`Rational{BigInt}` loss scale is refused before any write.

This is a documentation alignment with the homogeneous numerical
policy tracked in
[ProximalBase PR #857](https://github.com/mlakolar/ProximalBase.jl/pull/857).
Failure atomicity is as before; the loss scale types that the
scalar-acceptance check accepts are narrowed as stated above (#307). CD's
coordinate step and stopping arithmetic is as before where the loss scale promotes
to `T`; for a loss scale wider than `T` it uses the scale as supplied (#295). The
loss part of the reported objective is ProximalBase's reduction, which differs
from the former one in `T` (#307).

<!-- baseline: docs/src/stopping-limits.md:99-169 -->

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
