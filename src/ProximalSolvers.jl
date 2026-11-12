"""
    ProximalSolvers

Least-squares lasso with dense Matrix designs. [`CDSolver`](@ref) accepts a dense
`Vector` or a one-dimensional `SparseIterate` as the iterate and
[`ProximalGradientDescent`](@ref) a dense `Vector` only, both through
[`solve!`](@ref). Losses, proximal operators and coordinate storage belong to PB.
"""
module ProximalSolvers
using LinearAlgebra
using Printf
using Random: AbstractRNG, default_rng, rand
using SparseArrays: dropzeros!
using ProximalBase: LeastSquaresLoss, Scaled, NormL1, SparseIterate,
  ncoordinates, nactive, activecoordinates, activevalues, prox_block,
  value_and_prox!
include("blocks.jl")
using .Blocks
include("line_searches.jl")
using .LineSearches
export CDSolver, ProximalGradientDescent, solve!, ProximalSolver, ProximalOptions,
       CDResults, OptimizationState, OptimizationTrace
@static if VERSION >= v"1.11.0-DEV.469"
  eval(Expr(:public, :OptimizationResults, :LineSearches))
end
include("types.jl")
include("solve.jl")
include("solvers/image_models.jl")
include("solvers/proximal_gradient_descent.jl")
include("cd/models.jl")
include("cd/solver.jl")
include("cd/leastsquares.jl")
include("utils.jl")
include("precompile.jl")
end
