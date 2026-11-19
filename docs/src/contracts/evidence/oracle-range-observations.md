# Oracle and working-precision observations

These examples preserve the baseline's numerical observations and executable
counterexamples. They are not new runs performed during this migration and do not
promise general recovery at extreme scales. The current limits are in [FP-01](@ref)
through [FP-04](@ref), and the stopping interpretation is in [RES-01](@ref).

## [ORACLE-01 Recovered loss values and rescaled examples](@id ORACLE-01)

**Statement.**

The baseline records the problem `X = ones(5, 1)`, `y = fill(1e160, 5)`, loss scale
`1e-100`, `NormL1(0.0)` and start zero. Its spectral curvature was
`5.000000000000001e-100`; `X` has rank one, and both gradient methods started at
`5.000000000000014e-100`. APG returned `converged = true` after 8 iterations,
or 7 with `NormL1(0.1 * lambda_max)` (Julia 1.10.13 and 1.13.3 agreed). PGD
returned `converged = true` after 10 iterations, or 9 at that positive level
(Julia 1.10.12 and 1.13.3 agreed). CD also solved this example with
`converged = true` and `x = [1.0e160]`. These are outcomes for this example,
not an extreme-scale support claim.

The start can have a finite recovered loss although the residual's direct sum of
squares overflows in `T`. PGD's backtracking squares the step norm, which overflows
once a step exceeds about `1.3e154`; its scaled decision is specified in
[LS-06](@ref), while [PGD-02](@ref) defines the initial curvature.

With the coefficient substitution of [FP-04](@ref), choosing `s = 1e50` and
replacing the level `1.0e60` by `1.0e110` made the curvature exceed one and the
initial estimate equal one. PGD and APG returned `converged = true` after 9 and
7 iterations. With the alternative common rescaling `c = 1e-80` of `X` and `y`
and loss scale `alpha/c^2`, APG converged after 8 iterations and PGD after 10;
Julia 1.10.12 and 1.13.3 agreed. This latter transformation keeps curvature and
therefore the initial estimate up to rounding, as the mathematical rule states.

**Applies to.** The explicitly stated one-column problem and its two rescalings at the recorded Julia versions.

**Code.** Historical least-squares oracle integrations and gradient initialization; [PGD-02](@ref), [LS-06](@ref).

**Tests.** Historical probes from the baseline; current range/initialization regression coverage is in `test/initial_curvature.jl` and `test/core_regressions.jl`.

**Sources.** `docs/src/numerics.md:L833`, `docs/src/numerics.md:L853`, `docs/src/numerics.md:L857`.

## [ORACLE-02 Overflowing predictor differences and gradient probes](@id ORACLE-02)

**Statement.**

For `Float32`, `X = [1;;]`, `y = [3f38]`, loss scale `1e-44`, `NormL1(0f0)`
and start `[-3f38]`, the baseline records that both methods left `x` unchanged.
PGD rejected the nonfinite combined value/gradient start with
`ArgumentError("start from a point where f is finite")`; APG accepted the
finite value-only start, then its first step raised
`ErrorException("the gradient step did not produce a finite objective")`.
[#328](https://github.com/mlakolar/ProximalSolvers.jl/issues/328) tracks the
message and this difference. The oracle boundary is specified in [FP-02](@ref).

A separate Float32 probe with `maxiter = 3000` (Julia 1.10.13 and 1.13.3)
rejected a trial with a nonfinite gradient, raised
`ErrorException("line search failed: nonfinite curvature estimate")`, and
restored the last accepted iterate. This observation is not a guarantee for every
setting. In particular, it did not reproduce the accepted-iterate/nonfinite-gradient
possibility described as an untested code inference in [FP-02](@ref).

**Applies to.** The two historical probes and the stated versions; not all extreme-range configurations.

**Code.** Baseline `src/line_searches.jl:113–118`, `src/solve.jl:223–231`, predictor-value and combined-gradient oracle call sites.

**Tests.** Recorded probes; the accepted-iterate/nonfinite-gradient possibility explicitly has no reproducing test.

**Sources.** `docs/src/numerics.md:L868`, `docs/src/numerics.md:L871`, `docs/src/numerics.md:L881`.

## [ORACLE-03 Underflow and cancellation counterexamples](@id ORACLE-03)

**Statement.**

The following two executable examples and their reported high-precision evaluations
are preserved from the stopping audit. [FP-03](@ref) is the common arithmetic
limitation they illustrate.

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
[stationarity check of a stop](@ref STOP-03) because it reads the same rounded
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
evaluate the [KKT residual independently](../../sparsity-and-kkt.md), in higher precision, for results that matter.

**Applies to.** The exact inputs, looped solvers and precisions in the examples; the reported values belong to those inputs.

**Code.** CD coordinate products and PGD/APG gradient and `lambda_max` products before loss scaling.

**Tests.** Executable examples retained verbatim, apart from link targets; the underflow residual was evaluated in 600-bit arithmetic.

**Sources.** `docs/src/stopping-limits.md:L108`, `docs/src/stopping-limits.md:L111`, `docs/src/stopping-limits.md:L130`, `docs/src/stopping-limits.md:L138`, `docs/src/stopping-limits.md:L140`, `docs/src/stopping-limits.md:L157`, `docs/src/stopping-limits.md:L164`, `docs/src/stopping-limits.md:L167`.
