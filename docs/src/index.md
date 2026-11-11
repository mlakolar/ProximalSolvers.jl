# ProximalSolvers.jl

Ordinary dense least-squares lasso through [`CDSolver`](@ref),
[`ProximalGradientDescent`](@ref), and [`solve!`](@ref). ProximalBase provides
LeastSquaresLoss and NormL1. The minimal core preserves historical numerical
kernels while deliberately narrowing support. See support/migration, numerical
contracts and both executable examples before using the package.

```@docs
ProximalSolvers
```
