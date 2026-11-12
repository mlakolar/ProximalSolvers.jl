# ProximalSolvers.jl

Ordinary least-squares lasso with dense designs through [`CDSolver`](@ref),
[`ProximalGradientDescent`](@ref), and [`solve!`](@ref). Coordinate descent
accepts a dense `Vector` or a one-dimensional ProximalBase `SparseIterate` as the
iterate; proximal gradient descent accepts a dense `Vector` only. ProximalBase
provides LeastSquaresLoss, NormL1 and `SparseIterate`. The minimal core preserves
historical numerical kernels while deliberately narrowing support. See
support/migration, numerical contracts and the executable examples before using
the package.

```@docs
ProximalSolvers
```
