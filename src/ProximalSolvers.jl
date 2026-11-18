"""
    ProximalSolvers

Least-squares lasso, with or without weights (`NormL1(λ)` or `NormL1(λ, w)`), and elastic net (an
unweighted `ElasticNet`) with dense Matrix designs, for
[`CDSolver`](@ref), [`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref).
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) also solve the least-squares
problem with a `NormLinf` penalty (the largest magnitude of the entries); [`CDSolver`](@ref) does not.
[`CDSolver`](@ref) also solves the square-root lasso, with ProximalBase's `SqrtLeastSquaresLoss` and
an unweighted `NormL1`, and reports `converged = true` for it only with a duality certificate.
[`CDSolver`](@ref) accepts a dense
`Vector` or a one-dimensional `SparseIterate` as the iterate, and, for a group lasso with
a `GroupNormL2` penalty, a `BlockIterate`. For a matrix response `Y` and a `GroupNormL2` whose
groups are the rows of the coefficients, it accepts a `Matrix` coefficient (or a `BlockIterate`
over its entries) with a dense `X`, `Y` and `LeastSquaresLoss`. [`ProximalGradientDescent`](@ref) and
[`AccProxGradDescent`](@ref) accept a dense `Vector` only, all through [`solve!`](@ref);
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) also solve the group lasso with a `GroupNormL2` penalty on it.
Losses, proximal operators and coordinate storage belong to PB.
"""
module ProximalSolvers
using LinearAlgebra
using Printf
using Random: AbstractRNG, default_rng, rand
using SparseArrays: dropzeros!
using ProximalBase: LeastSquaresLoss, SqrtLeastSquaresLoss, Scaled, NormL1, ElasticNet, NormLinf, SparseIterate,
  ncoordinates, nactive, activecoordinates, activevalues, prox_block,
  value_and_prox!, BlockIterate, GroupNormL2, blockindices, blockview, prox_block!, kkt_violation
include("blocks.jl")
using .Blocks
include("line_searches.jl")
using .LineSearches
export CDSolver, ProximalGradientDescent, AccProxGradDescent, solve!, ProximalSolver, ProximalOptions,
       CDResults, OptimizationState, OptimizationTrace
@static if VERSION >= v"1.11.0-DEV.469"
  eval(Expr(:public, :OptimizationResults, :LineSearches))
end
include("types.jl")
include("solve.jl")
include("solvers/image_models.jl")
include("solvers/proximal_gradient_descent.jl")
include("solvers/accelerated_proximal_gradient_descent.jl")
include("cd/models.jl")
include("cd/solver.jl")
include("cd/multiresponse.jl")
include("cd/leastsquares.jl")
include("cd/sqrtlasso.jl")
include("utils.jl")
include("precompile.jl")
end
