# Getting started

This guide takes you from a fresh source checkout to a solved lasso problem.
You need Julia **1.10.8 or newer** and basic familiarity with Julia arrays.

!!! note "Development version"
    The current `master` branch is a deliberately reduced solver core. It has
    **not** been released as a new package version. The commands below use the
    source checkout and its pinned ProximalBase dependency rather than assuming
    that an existing registry release has the same API.

## 1. Get the package

In a terminal:

~~~sh
git clone https://github.com/mlakolar/ProximalSolvers.jl.git
cd ProximalSolvers.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. examples/01_cd_lasso.jl
~~~

The last command runs the repository's tested coordinate-descent example.
For an interactive session, start `julia --project=.` from the same directory.
Both `ProximalSolvers` and its `ProximalBase` dependency are then available.

## 2. The optimization problem

For a design matrix `X` with `n` rows and `p` columns, a response vector `y`
of length `n`, and coefficients `β` of length `p`, we solve the lasso

\[
\underset{\beta \in \mathbb{R}^p}{\operatorname{minimize}}\quad
\frac{1}{2n}\lVert y-X\beta\rVert_2^2+\lambda\lVert\beta\rVert_1.
\]

The squared-error loss encourages fit to the data. The L1 penalty encourages
small coefficients and can set some coefficients to exactly zero. Increasing
`λ` increases the strength of the penalty **for this fixed loss scaling**.

!!! important "Explicit loss normalization"
    `LeastSquaresLoss(y, X)` represents **half the sum** of squared residuals,
    not their mean. Multiply it by `1/n` to obtain the `1/(2n)` convention
    shown above. The solvers never silently rescale your objective.

## 3. Solve a small example

Paste this into the Julia session started with `--project=.`:

~~~julia
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0] # 3 observations, 2 features
y = [2.0, -2.0, 0.5]
n = length(y)
lambda = 0.1

f = (1 / n) * LeastSquaresLoss(y, X)
g = NormL1(lambda)
beta = zeros(size(X, 2))

result = solve!(beta, f, g, CDSolver())

@show beta                   # approximately [1.7, -0.925]
@show result.converged
@show result.minimum
@assert isapprox(beta, [1.7, -0.925]; atol=1e-7)
~~~

The data are deliberately small: the columns of `X` are orthogonal, so we can
check the answer independently. `solve!` **modifies `beta` in place**.
`result.minimizer === beta`; use `copy(beta)` if you need to preserve this
solution before solving another problem with the same array.

The output field `converged` reports the solver's stopping condition, **not**
a mathematical certificate of optimality. For an important application, check
the objective and appropriate optimality conditions independently.

## 4. Try the other solver

The same `f` and `g` work with proximal gradient descent:

~~~julia
beta_pgd = zeros(size(X, 2))
options = ProximalOptions(maxiter=2000, ftol=1e-14,
                          xtol=1e-12, gradtol=1e-10)
pgd_result = solve!(beta_pgd, f, g, ProximalGradientDescent(), options)
@assert isapprox(beta_pgd, [1.7, -0.925]; atol=1e-7)
~~~

This is not a different statistical model; only the optimization algorithm
changes. See [Choosing a solver](choosing-solver.md) for when to use each one.

## 5. What to do next

- [Choose a solver and its options](choosing-solver.md).
- [Understand results, ownership and errors](working-with-results.md).
- Browse the **Examples** menu for runnable coordinate-descent,
  proximal-gradient and sparse-iterate examples.
- Check [Supported API and migration](support.md) before attempting more
  advanced models.

This development core currently accepts dense, finite
`Matrix{Float32}`/`Vector{Float32}` **or**
`Matrix{Float64}`/`Vector{Float64}` inputs with matching element types,
an unweighted `NormL1` penalty and a least-squares loss. It does not yet
support sparse design matrices, intercepts, other losses, group penalties,
paths or the legacy package's wider solver catalog.
