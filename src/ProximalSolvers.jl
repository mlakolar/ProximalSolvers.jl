"""
    ProximalSolvers

Solvers for `minimize f(x) + g(x)`, built on the functions and proximal
operators of ProximalBase: [`ProximalGradientDescent`](@ref),
[`AccProxGradDescent`](@ref), [`ActiveAccProxGradDescent`](@ref) and
[`ADMMSolver`](@ref) for a proximable `g`, and coordinate descent
([`CDSolver`](@ref), [`ProxNewton`](@ref)) for a separable one, all called
through [`solve!`](@ref). Before its first release the package was called
ProximalOPT.
"""
module ProximalSolvers

include("lineSearches.jl")

using LinearAlgebra
using LinearAlgebra: BlasInt, LAPACKException, libblastrampoline
using LinearAlgebra.BLAS: @blasfunc
using Printf
using ProximalBase
import ProximalBase: gradient!, value_and_gradient!
using SparseArrays: dropzeros!, sparse, sparsevec
using .LineSearches

export
  # proximal minimization algorithms
  ProximalGradientDescent,
  AccProxGradDescent,
  ActiveAccProxGradDescent,
  ADMMSolver,
  CDSolver,
  ProxNewton,
  solve!,

  # coordinate descent: losses, models, penalty levels, drivers
  SqrtLeastSquaresLoss, SqrtQuadraticFunction,
  CDModel, cdmodel,
  lambda_max, solve_path,
  reweight!, refit!,
  duality_gap, kkt_residual,

  # types
  ProximalSolver,
  ProximalOptions,
  OptimizationState, OptimizationTrace,
  CDResults, PathResults, ReweightResults

# the interface of coordinate descent models (see CDModel) and the accessors of
# the least-squares models: public, not exported
@static if VERSION >= v"1.11.0-DEV.469"
  eval(Expr(:public, :initialize!, :coordinate_step!, :coordinate_derivatives, :update_cache!,
            :coordinate_scale, :response_scale, :loss_value, :check_penalty, :intercept, :residuals))
end

include("types.jl")

include("solve.jl")

# Solvers
include("solvers/proximal_gradient_descent.jl")
include("solvers/accelerated_proximal_gradient_descent.jl")
include("solvers/active_accelerated_proximal_gradient_descent.jl")
include("solvers/admm.jl")

# Coordinate descent
include("cd/models.jl")
include("cd/groupcurvature.jl")
include("cd/solver.jl")
include("cd/leastsquares.jl")
include("cd/quadratic.jl")
include("cd/kron.jl")
include("cd/sqrtlasso.jl")
include("cd/sqrtquadratic.jl")
include("cd/glm.jl")
include("cd/gap.jl")
include("cd/workingset.jl")
include("cd/path.jl")
include("cd/drivers.jl")

include("utils.jl")

include("precompile.jl")

end
