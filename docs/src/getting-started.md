# Getting started

Here is how to use the current development version in **your own Julia project**, followed by an example you can verify by hand. Julia **1.10.8 or newer** is required.

## Install into your project

Start Julia in your project directory:

~~~julia
using Pkg
Pkg.activate(".")
Pkg.add(url="https://github.com/mlakolar/ProximalBase.jl",
        rev="c123d56ba1948e36a8fdbf183a9eea396a16e0d5")
Pkg.add(url="https://github.com/mlakolar/ProximalSolvers.jl",
        rev="master")
~~~

Add **both** packages: ProximalBase provides `LeastSquaresLoss`, `NormL1` and `SparseIterate`; ProximalSolvers provides `CDSolver`, `ProximalGradientDescent` and `solve!`. The long revision identifier specifies the ProximalBase source used by the development core. The `master` branch can change. Save `Project.toml` and `Manifest.toml` to reproduce your environment, or install ProximalSolvers at a fixed commit.

!!! warning "Registry releases differ"
    This guide describes **development master**. A plain `pkg> add ProximalSolvers` can select a registered release with a different set of features and interfaces. Use the source-install commands for these examples.

If you are **contributing** to the repository instead, clone it and instantiate its configured environment:

~~~sh
git clone https://github.com/mlakolar/ProximalSolvers.jl.git
cd ProximalSolvers.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. examples/01_cd_lasso.jl
~~~

The commands above are installation instructions, not CI tests that modify a project. The actual optimization examples below **execute during the documentation build**.

## The optimization problem

For `n` observations and `p` predictors, the lasso minimizes

~~~math
\min_{\beta \in \mathbb{R}^p}
\frac{1}{2n}\lVert y-X\beta\rVert_2^2+\lambda\lVert\beta\rVert_1.
~~~

The least-squares term fits the data; the L1 penalty encourages zero coefficients. For an explanation of [proximal operators and soft-thresholding](concepts.md), read the short algorithm guide.

!!! important "Explicit loss normalization"
    `LeastSquaresLoss(y, X)` means **half the sum of squared residuals**. Multiply by `1/n` to get the `1/(2n)` objective shown above.

## Solve an example by hand

~~~@example first_lasso
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
n = length(y)
lambda = 0.1
f = (1 / n) * LeastSquaresLoss(y, X)
penalty = NormL1(lambda)
beta = zeros(2)
result = solve!(beta, f, penalty, CDSolver(order=:cyclic, momentum=false))
@assert result.minimizer === beta
@assert isapprox(beta, [1.7, -0.925]; atol=1e-7)
beta
~~~

Because the columns are orthogonal, the normalized correlations are `2/3` and `-4/3` and the normalized squared lengths are `1/3` and `4/3`. Soft-thresholding gives `[1.7, -0.925]`. The objective at this answer is approximately `0.3229`.

`solve!` modifies `beta` in place. Save `copy(beta)` if you want to reuse the array later; `result.minimizer === beta`.

## Try PGD using the defaults

~~~@example first_lasso
beta_pgd = zeros(2)
pgd_result = solve!(beta_pgd, f, penalty, ProximalGradientDescent())
analytic_pgd = [1.7, -0.925]
pgd_grad = (X' * (X * beta_pgd - y)) / n
pgd_kkt = [iszero(beta_pgd[j]) ?
           max(abs(pgd_grad[j]) - lambda, 0.0) :
           abs(pgd_grad[j] + lambda * sign(beta_pgd[j]))
           for j in eachindex(beta_pgd)]
(; coefficients=beta_pgd, converged=pgd_result.converged,
   max_coefficient_error=maximum(abs.(beta_pgd .- analytic_pgd)),
   max_kkt_violation=maximum(pgd_kkt))
~~~

The defaults may report `converged=true` while the coefficients still differ
from the analytic answer. On this tutorial problem, **default PGD typically
gives about 3–4 correct digits**, not full Float64 accuracy; this is not a
general guarantee. Tighten tolerances for results you plan to report and
verify an independent KKT residual. See
[Choosing a solver](choosing-solver.md) for tighter settings.
The solver's `converged` flag is a stopping indicator, not an optimality
certificate.

## Float32 data

Use matching Float32 arrays for the design, response and coefficients,
and **prefer** Float32 scales and penalty parameters:

~~~@example first_float32
using ProximalBase, ProximalSolvers
T = Float32
X = T[1 0; 0 2; 0 0]
y = T[2, -2, 0.5]
f = (one(T) / T(length(y))) * LeastSquaresLoss(y, X)
penalty = NormL1(T(0.1))
beta = zeros(T, 2)
result = solve!(beta, f, penalty, CDSolver(order=:cyclic, momentum=false))
@assert isapprox(beta, T[1.7, -0.925]; atol=1e-3)
beta
~~~

The shorthand `1/n` produces a `Float64` scalar. The solver may accept
that scalar when it is representable in the Float32 working type without
overflow or losing a nonzero value to zero. This is a convenience for scalar
parameters, **not** a mixed-precision solver mode; the arrays must all use
the same `T`. Using `one(T)/T(n)` keeps the scale in the working type.
`Float32` iterates still have `Float32` accuracy limits, even though
some solver tolerances and reported diagnostics use `Float64`.
See [Numerical behavior](numerics.md) for recovery and stopping limits.

Next, try [a realistic sparse example with an independent KKT check](sparsity-and-kkt.md).
