# ProximalSolvers.jl

[![CI](https://github.com/mlakolar/ProximalSolvers.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/mlakolar/ProximalSolvers.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![codecov](https://codecov.io/gh/mlakolar/ProximalSolvers.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mlakolar/ProximalSolvers.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Coordinate descent and proximal solvers in Julia for problems of the form

```
minimize  f(x) + g(x)
```

The core is coordinate descent. It handles a penalty `g` that separates across
coordinates or groups of coordinates (lasso, elastic net, MCP, SCAD, group
lasso, box constraints) and a loss `f` whose coordinates are cheap to update
(least squares, quadratics, Kronecker-structured quadratics of matrices,
generalized linear losses). On top of it come paths of penalty levels with
screening, reweighting and exact refits.

It also has the other proximal solvers, for a smooth `f` and a `g` with an easy
proximal operator: proximal gradient descent (plain, accelerated, or on an
active set) and ADMM. They cover the nuclear norm, the graphical lasso and
other problems that coordinate descent does not fit.

The losses, penalties and proximal operators come from
[ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl) (0.5), and the
next releases of CoordinateDescent, CovarianceSelection and DiffPrecTest run on
these solvers.

ProximalSolvers is one of five Julia packages for high-dimensional statistics,
three for estimation and inference and two for the optimization beneath them:

| Package | |
|---|---|
| [CoordinateDescent.jl](https://github.com/mlakolar/CoordinateDescent.jl) | the lasso and its paths; the group, square-root, scaled and heteroscedastic lasso; varying-coefficient models |
| [CovarianceSelection.jl](https://github.com/mlakolar/CovarianceSelection.jl) | Gaussian graphical models: the graphical lasso, CLIME and ACLIME, precision matrices by the scaled lasso, the fused graphical lasso, and the difference of two precision matrices |
| [DiffPrecTest.jl](https://github.com/mlakolar/DiffPrecTest.jl) | confidence intervals and tests for the difference of two precision matrices |
| **ProximalSolvers.jl** (this package) | the solvers: coordinate descent with penalty paths, screening and active sets; proximal gradient methods, proximal Newton and ADMM |
| [ProximalBase.jl](https://github.com/mlakolar/ProximalBase.jl) | the building blocks: losses, penalties and constraints with their gradients and proximal operators, and sparse iterates; [documentation](https://mlakolar.github.io/ProximalBase.jl/dev/) with the mathematics |

Most users need one of the first three. To solve a problem of your own, use
ProximalSolvers; to write your own algorithm, ProximalBase.

## Installation

Requires Julia 1.10 or later. Install it from the General registry, or the
development version from GitHub:

```julia
using Pkg
Pkg.add("ProximalSolvers")
Pkg.add(url = "https://github.com/mlakolar/ProximalSolvers.jl")   # development version
```

ProximalSolvers was called ProximalOPT before its first release.

## Coordinate descent

`CDSolver` minimizes `f + g` one coordinate at a time on a `SparseIterate`, a
`SymmetricSparseIterate` (the lower-triangle entries of a symmetric matrix) or
an `AtomIterate` (the groups of a `GroupNormL2`). It reads the structure of
`f` to make each step cheap, caching the residuals of least squares or the
product `Ax` of a quadratic, and goes through `prox_entry` of ProximalBase for the
penalty, so every separable penalty works: `NormL1` (with weights), `ElasticNet`,
`MCP`, `SCAD`, `NormL1Nonneg`, `IndBox`, ... The lasso of glmnet's scaling,
`‖y - Xβ‖² / (2n) + λ‖β‖₁`:

```julia
using ProximalBase, ProximalSolvers, LinearAlgebra, Random, Statistics

Random.seed!(1)
n, p = 200, 1000
X = randn(n, p)
y = X[:, 1:5] * ones(5) + randn(n)
f = (1 / n) * LeastSquaresLoss(y, X)

λmax = lambda_max(f, NormL1(1.0), SparseIterate(p))   # ‖X'y‖∞ / n
β = SparseIterate(p)
res = solve!(β, f, NormL1(0.1λmax), CDSolver())

path = solve_path(f, NormL1(1.0), λmax .* 10 .^ range(0, -2; length = 50))
```

With the random order, the default, the passes over the active set use
Nesterov momentum with adaptive restarts, as in CoordinateDescent.jl 0.6, on a
`SparseIterate` for least squares, square-root least squares, quadratics and
GLMs. In CoordinateDescent.jl's benchmark, whose passes ProximalSolvers reproduces,
it computes lasso paths 2.8 to 4.5 times faster and single solves at small
penalties 1.3 to 2.2 times. On logistic lasso problems coordinate descent is
1.4 to 5.6 times faster with it, and `ProxNewton`, whose inner solves are
weighted least squares, 1.0 to 4.5 times. `momentum = false` turns it off, and
`momentum = true` asks for it with the other models, such as `KronQuadratic` on
a symmetric iterate.
`CDSolver(; order = :cyclic, anderson = 5)` accelerates the cyclic order by
Anderson extrapolation instead, 1.6 to 2.6 times faster than cyclic order
alone on the lasso at 0.02 λmax; the random order is the safer choice when the
columns are strongly correlated.

`solve_path` warm starts each level from the previous solution and screens it
with the sequential strong rule, checking the optimality conditions of the
screened coordinates afterwards; `callback(k, λ, x, m)` can compute a
validation loss or stop the path. `solve!(β, f, g, CDSolver(); continuation = 50)`
starts from zero and follows 50 levels down to `g`. Each pass visits the
coordinates once, passes over all of them alternate with passes over the
nonzero ones, and the method stops after a full pass followed by a pass in which
no coordinate moves by more than `tol` times a scale of the data, so that the
tolerance does not depend on its units.

A duality gap certifies the accuracy instead. `duality_gap(f, g, x)` returns
`P(x) - D(θ)` for the dual point built from the gradient at `x`, an upper bound
on `P(x) - min P` that is zero at the solution, for least squares and the
logistic, Poisson and Huber losses with the ℓ1 norm (weighted or nonnegative),
the elastic net or the group lasso, and for the graphical lasso
(`LogDetLoss` with `NormL1`). `CDSolver(; gaptol = 1e-6)` stops when the
relative gap `(P - D) / |P|` is below `gaptol`, a tolerance that means the same
for every problem, and `gapsafe = true` adds the gap-safe screening of Fercoq,
Gramfort and Salmon (2015), which removes the coordinates proven zero at the
solution from the passes. `ProximalOptions(; gaptol)` does the same for the
gradient solvers and ADMM. `CDSolver(; workingset = true)` replaces the passes
over all coordinates of a single solve by passes over a growing working set of
the nonzero coordinates and those whose step would move them most (Celer,
skglm). For the losses without a gap, such as the
quadratics, `kkt_residual(f, g, x)` measures optimality on the scale of the
stopping rule.

The losses it knows:

| Loss | Coordinate step | Use |
|---|---|---|
| `LeastSquaresLoss(y, X)`, `GLMLoss(ProximalBase.Squared(), y, X; weights, offset)` | O(n), residuals cached | lasso, weighted lasso; `cdmodel(f, x; intercept = true)` adds an unpenalized intercept |
| `QuadraticFunction(A, b)` | O(p), `Ax` cached | the lasso on `X'X/n` when `n ≫ p` |
| `KronQuadratic(A, B, C)`, `⟨Θ, AΘB⟩/2 + ⟨C, Θ⟩` | O(pq), `AΘB` cached | the D-trace loss of a symmetric `Θ`, inverse Hessians of Kronecker form |
| `SqrtLeastSquaresLoss(y, X)`, `‖y - Xβ‖` | exact, O(n) | square-root lasso (with `NormL1`) |
| `SqrtQuadraticFunction(A, b, c)`, `√(x'Ax + 2b'x + c)` | exact, O(p), `Ax` cached | square-root lasso from `X'X/n`, `X'y/n` and `y'y/n`; the scaled lasso of one variable on the others from a covariance matrix (Sun and Zhang, 2013) |
| `GLMLoss` with `Logistic` or `Huber` | O(n), curvature bound | logistic and Huber lasso; `ProxNewton` is faster |

Any of them scaled, as `(1/n) * f`, works too. The difference of two precision
matrices by the D-trace loss (Zhao, Cai and Li, 2014), on a symmetric iterate:

```julia
Sx, Sy = cov(randn(500, 30)), cov(randn(500, 30))
f = KronQuadratic(Sx, Sy, Sx - Sy)       # tr(SxΔSyΔ)/2 - tr(Δ(Sy - Sx))
Δ = SymmetricSparseIterate(30)
solve!(Δ, f, NormL1(0.1), CDSolver())
refit!(Δ, f)                              # the exact minimizer on the support of Δ
```

`reweight!(x, f, g, update)` alternates between solving and updating the
penalty from the solution: the scaled lasso, data-driven penalty loadings,
two-stage weights. `refit!` minimizes the loss exactly over a support, by a
QR factorization for least squares and the Hessian on the support for the
quadratics. A new loss is a `CDModel` with `initialize!` and the coordinate
step, either `coordinate_derivatives` and `update_cache!` or the whole
`coordinate_step!`; the scales of the stopping rule, `loss_value` and
`gradient!` are optional. These functions are public but not exported; see
`?CDModel`.

## Other proximal solvers

The proximal gradient solvers need only the gradient of `f` and the proximal
operator of `g`, so they work with any `f` and `g` of ProximalBase that provide
them. ADMM needs the proximal operators of both.

### Example: lasso

Minimize `‖Y - Xβ‖² / 2 + λ‖β‖₁`:

```julia
using ProximalBase, ProximalSolvers, LinearAlgebra, Random

Random.seed!(1)
n, p = 100, 50
X = randn(n, p)
β_true = [ones(5); zeros(p - 5)]
Y = X * β_true + 0.1 * randn(n)

f = LeastSquaresLoss(Y, X)   # f(β) = ‖Y - Xβ‖² / 2
g = NormL1(10.0)             # g(β) = 10 ‖β‖₁

β = zeros(p)                 # starting point, overwritten with the solution
res = solve!(β, f, g, AccProxGradDescent())

res.minimum, res.iterations, count(!iszero, β)
```

`β` recovers the five nonzero coefficients and sets the rest to exactly zero.
Replace `AccProxGradDescent()` with `ProximalGradientDescent()` to use the
unaccelerated method. When `p` is large and the solution sparse,
`ActiveAccProxGradDescent()` is usually much faster: it runs the accelerated
method on an active set of coordinates, which it grows by the coordinates that
violate the optimality conditions the most: by 100 at a time, or by as many as
are nonzero if that is more. Its starting point may be a vector, as here,
or a `SparseIterate`. The other solvers take a `SparseIterate` too, and then
multiply `X` by their sparse iterates over the nonzero entries only.

### Example: group lasso

Minimize `‖Y - Xβ‖² / 2 + λ Σₖ √|Gₖ| ‖β[Gₖ]‖₂` over groups `Gₖ` of
coefficients that enter or leave the model together, such as the dummy
variables of a factor:

```julia
using ProximalBase, ProximalSolvers, LinearAlgebra, Random

Random.seed!(1)
n = 100
groups = [1:3, 4:5, 6:10, 11:12, [13, 15], [14]]   # sizes 3, 2, 5, 2, 2 and 1
X = randn(n, 15)
β_true = [ones(3); zeros(2); ones(5); zeros(5)]
Y = X * β_true + 0.1 * randn(n)

f = LeastSquaresLoss(Y, X)
g = GroupNormL2(10.0, groups)    # weights √|Gₖ| by default

β = zeros(15)
res = solve!(β, f, g, AccProxGradDescent())

[norm(β[G]) for G in groups]
```

The first and third groups are selected, and the other four are exactly zero.
`GroupNormL2(λ, groups, w)` takes other weights, and coordinates in no group
are not penalized. When the groups cover all coefficients, as here,
`AtomIterate(β, g.groups)` is a vector whose coordinates are the groups: the solvers
take it as a starting point and multiply by it over the nonzero groups only,
and `ActiveAccProxGradDescent()` adds and removes whole groups, as it also does
from a dense starting point.

### Example: low-rank multi-response regression

Regress `k` responses on the same `p` predictors, `Y = XB + E`, with a `p × k`
coefficient matrix `B` of low rank, by minimizing `‖Y - XB‖²_F / 2 + λ‖B‖_*`.
The nuclear norm `‖B‖_*`, the sum of the singular values of `B`, sets the small
singular values to exactly zero, as the ℓ1 norm of the lasso does with the small
coefficients:

```julia
using ProximalBase, ProximalSolvers, LinearAlgebra, Random

Random.seed!(1)
n, p, k = 200, 20, 10
X = randn(n, p)
B_true = randn(p, 2) * randn(2, k)    # rank 2
Y = X * B_true + 0.5 * randn(n, k)

σ = norm(Y - X * (X \ Y)) / sqrt((n - p) * k)   # noise level, from least squares
λ = σ * opnorm(X) * (sqrt(p) + sqrt(k))

f = LeastSquaresLoss(Y, X)            # f(B) = ‖Y - XB‖²_F / 2
g = NuclearNorm(λ)                    # g(B) = λ ‖B‖_*

B = zeros(p, k)                       # starting point, overwritten with the solution
res = solve!(B, f, g, AccProxGradDescent())

rank(B; atol = 1e-6), norm(B - B_true) / norm(B_true)
```

`B` has rank 2, as `B_true`, and relative error 0.029; least squares, `X \ Y`,
has rank 10 and relative error 0.026. As here, the starting point of
`ProximalGradientDescent()` and `AccProxGradDescent()` may be a matrix, or an
array of any shape that `f` and `g` accept.

The rule for `λ` makes the penalty dominate the noise in the gradient of `f` at
`B_true`, which is `-X'E`: for Gaussian noise with standard deviation `σ`, its
operator norm `‖X'E‖`, the largest singular value, is at most about
`σ‖X‖(√p + √k)`. The penalty also shrinks the singular values that it keeps, so
a smaller `λ` has a smaller error but keeps more of them: `λ = 50`, close to
`‖X'E‖ = 49.7`, still gives rank 2, with relative error 0.022, and `λ = 20`
gives rank 7 and relative error 0.016. For `λ ≥ ‖X'Y‖`, `B = 0`.

### Example: graphical lasso by ADMM

Estimate a sparse precision matrix by minimizing
`tr(SΘ) - log det Θ + λ‖Θ‖₁`, where both terms have closed-form proximal
operators:

```julia
using ProximalBase, ProximalSolvers, LinearAlgebra, Random

Random.seed!(1)
Z = randn(200, 10)
S = Symmetric(Z' * Z / 200)          # sample covariance

Θ = Matrix(1.0I, 10, 10)             # starting point
res = solve!(Θ, LogDetLoss(S), NormL1(0.1), ADMMSolver(; ρ = 1.0))

res.converged, res.iterations
```

## Solvers

| Solver | Problem | Method |
|---|---|---|
| `ProximalGradientDescent()` | `f` smooth, `g` proximable | Proximal gradient with TFOCS backtracking (Parikh and Boyd, §4.2) |
| `AccProxGradDescent(; β = 0.5, α = 0.9)` | `f` smooth, `g` proximable | Accelerated proximal gradient (Parikh and Boyd, §4.3) with backtracking that also lets the step grow (`α`), and adaptive restart |
| `ActiveAccProxGradDescent(; β, α, max_add, growth, max_outer)` | `f` smooth, `g` separable (`NormL1`, ...) or `GroupNormL2`, sparse solution | Active set: adds the coordinates (whole groups, for the group lasso) that violate the optimality conditions, the largest violations first, about `max(max_add, (growth - 1) s)` entries when `s` are nonzero, and runs `AccProxGradDescent` on the active coordinates only |
| `ADMMSolver(; ρ, α, abstol, reltol, adaptive)` | `f`, `g` both proximable | Over-relaxed scaled ADMM (Boyd et al., 2011), optionally with residual balancing of `ρ`; warm starts from the scaled dual variable and `ρ` of a previous result |
| `CDSolver(; maxpasses, tol, order, relative, anderson, momentum, gaptol, gapsafe, workingset)` | `f` least squares, quadratic, `KronQuadratic` or a GLM; `g` separable or `GroupNormL2` | Coordinate descent with full and active passes, in random order with momentum or in cyclic order with Anderson acceleration, and a scale-free stopping rule (see below) |
| `ProxNewton(; inner, maxiter, tol, β)` | `f` a `GLMLoss` (logistic, Poisson, Huber), `g` separable | Proximal Newton (glmnet's IRLS): coordinate descent on the weighted least-squares model of `f`, then backtracking |

All solvers are called the same way:

```julia
res = solve!(x, f, g, solver, ProximalOptions(; maxiter = 1000))
```

`solve!` overwrites `x` with the solution and returns a results object with
`minimizer`, `minimum`, `iterations`, convergence information and the number
of evaluations of `f` (`f_calls`), of its gradient (`grad_calls`) and of
proximal operators (`prox_calls`); printing it shows a summary. The solvers
work in the element type of `x`, `Float64` or `Float32`.

## Options and stopping rules

`ProximalOptions` controls the iteration and call limits, tolerances and
tracing:

| Keyword | Default | Meaning |
|---|---|---|
| `maxiter` | `200` | Maximum number of iterations |
| `ftol` | `1e-6` | Relative change in the objective |
| `xtol` | `1e-8` | Relative change in the iterate |
| `gradtol` | `1e-5` | Optimality residual (FASTA; Goldstein, Studer and Baraniuk) |
| `time_limit` | `Inf` | Maximum run time in seconds |
| `f_calls_limit`, `grad_calls_limit`, `prox_calls_limit` | `0`, `0`, `0` | Maximum number of evaluations of `f`, of its gradient and of proximal operators; `0` means no limit |
| `show_trace`, `store_trace`, `extended_trace`, `printEvery` | `false`, `false`, `false`, `1` | Print or record progress |
| `callback` | `nothing` | Called every `printEvery` iterations; return `true` to stop |
| `gaptol`, `gapevery` | `0`, `10` | With `gaptol > 0`, stop when the relative duality gap is below `gaptol`, computed every `gapevery` iterations (see `duality_gap`) |

The gradient solvers stop when any of the `ftol`, `xtol` or `gradtol` tests
passes, or, with `gaptol > 0` and functions that have a duality gap, when the
gap is small enough. `ADMMSolver` uses its own primal and dual residual tolerances
(`abstol`, `reltol`) and ignores the other three, as well as `f_calls_limit`
and `grad_calls_limit`. The call limits are checked after each iteration, so a
count can exceed its limit by the evaluations of one iteration;
`res.call_limit_reached` tells whether a limit stopped the solver.

Every exported function and type has a docstring; use `?name` in the Julia
REPL, for example `?ProximalOptions`.

## Benchmark

[`benchmark/`](benchmark) times the solvers on the lasso against coordinate
descent ([CoordinateDescent.jl](https://github.com/mlakolar/CoordinateDescent.jl)),
glmnet and Lasso.jl; [benchmark/README.md](benchmark/README.md) explains how to
run it and summarizes the results. [`benchmark/engine/`](benchmark/engine)
compares the coordinate descent of ProximalSolvers, case by case, with the code it
replaces in CoordinateDescent,
[CovSel](https://github.com/mlakolar/CovSel.jl) and
[DiffPrecTest](https://github.com/mlakolar/DiffPrecTest.jl).

## References

- N. Parikh and S. Boyd. Proximal Algorithms. *Foundations and Trends in
  Optimization*, 1(3), 2014.
- S. Boyd, N. Parikh, E. Chu, B. Peleato and J. Eckstein. Distributed
  Optimization and Statistical Learning via the Alternating Direction Method of
  Multipliers. *Foundations and Trends in Machine Learning*, 3(1), 2011.
- B. O'Donoghue and E. Candès. Adaptive Restart for Accelerated Gradient
  Schemes. *Foundations of Computational Mathematics*, 15, 2015.
- T. Goldstein, C. Studer and R. Baraniuk. A Field Guide to Forward-Backward
  Splitting with a FASTA Implementation. arXiv:1411.3406, 2014.
- S. Becker, E. Candès and M. Grant. Templates for Convex Cone Problems with
  Applications to Sparse Signal Recovery (TFOCS). *Mathematical Programming
  Computation*, 3, 2011.
- J. Friedman, T. Hastie and R. Tibshirani. Regularization Paths for
  Generalized Linear Models via Coordinate Descent. *Journal of Statistical
  Software*, 33(1), 2010.
- R. Tibshirani, J. Bien, J. Friedman, T. Hastie, N. Simon, J. Taylor and
  R. Tibshirani. Strong Rules for Discarding Predictors in Lasso-type Problems.
  *Journal of the Royal Statistical Society B*, 74(2), 2012.
- S. D. Zhao, T. T. Cai and H. Li. Direct Estimation of Differential Networks.
  *Biometrika*, 101(2), 2014.
- T. Sun and C.-H. Zhang. Sparse Matrix Inversion with Scaled Lasso. *Journal
  of Machine Learning Research*, 14, 2013.

## License

MIT, see [LICENSE](LICENSE).
