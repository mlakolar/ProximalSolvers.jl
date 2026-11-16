"""
    ProximalSolvers

Least-squares lasso with dense Matrix designs, or centered `SqrNormL2`
with an unweighted `NormL1` penalty. [`CDSolver`](@ref) accepts a dense
`Vector` or a one-dimensional `SparseIterate` as the iterate, and
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) a dense `Vector`
only, all through [`solve!`](@ref). Centered squared-norm objectives
reuse these solver engines without a dense identity design. Losses,
proximal operators and coordinate storage belong to PB.
"""
module ProximalSolvers
using LinearAlgebra
using Printf
using Random: AbstractRNG, default_rng, rand
using SparseArrays: dropzeros!
using ProximalBase: LeastSquaresLoss, SqrNormL2, Scaled, NormL1, SparseIterate,
  ncoordinates, nactive, activecoordinates, activevalues, prox_block,
  value_and_prox!, value_and_gradient!
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
include("cd/leastsquares.jl")
include("cd/squarednorm.jl")
include("utils.jl")
include("precompile.jl")
end
