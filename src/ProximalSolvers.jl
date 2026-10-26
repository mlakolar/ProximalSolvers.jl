"""
    ProximalSolvers

Solvers for `minimize f(x) + g(x)`, built on the functions and proximal
operators of ProximalBase: [`ProximalGradientDescent`](@ref),
[`AccProxGradDescent`](@ref), [`MonotoneAccProxGradDescent`](@ref),
[`ActiveAccProxGradDescent`](@ref) and [`ADMMSolver`](@ref) for a proximable
`g`, and coordinate descent
([`CDSolver`](@ref), [`ProxNewton`](@ref)) for a separable one, all called
through [`solve!`](@ref). [`CondatVu`](@ref) handles convex linear composites
`f(x) + g(x) + h(D*x)`. Before its first release the package was called
ProximalOPT.
"""
module ProximalSolvers

include("blocks.jl")
include("line_searches.jl")

using LinearAlgebra
using LinearAlgebra: BlasInt, LAPACKException, libblastrampoline
using LinearAlgebra.BLAS: @blasfunc
using Printf
using ProximalBase
using Random: AbstractRNG, default_rng
import ProximalBase: gradient!, value_and_gradient!
using SparseArrays: SparseMatrixCSC, dropzeros!, nonzeros, nzrange, rowvals, sparse, sparsevec
using .Blocks
using .LineSearches

export
  # proximal minimization algorithms
  ProximalGradientDescent,
  AccProxGradDescent,
  MonotoneAccProxGradDescent,
  ActiveAccProxGradDescent,
  SLOPEAPG,
  SLOPEHybrid,
  ADMMSolver,
  CondatVu,
  CDSolver,
  ProxNewton,
  solve!,
  SolverWorkspace, reinit!,

  # coordinate descent: losses, models, penalty levels, drivers
  SqrtLeastSquaresLoss, SqrtQuadraticFunction,
  CDModel, cdmodel,
  lambda_max, solve_path, LLA,
  reweight!, refit!, RefitCache,
  duality_gap, kkt_residual,

  # types
  ProximalSolver,
  ProximalOptions,
  OptimizationState, OptimizationTrace,
  CDResults, PathResults, ReweightResults,
  SLOPEResults, SLOPEPathResults

# the interface of coordinate descent models (see CDModel) and the accessors of
# the least-squares and GLM models: public, not exported
@static if VERSION >= v"1.11.0-DEV.469"
  eval(Expr(:public, :initialize!, :coordinate_step!, :coordinate_derivatives, :update_cache!,
            :coordinate_scale, :response_scale, :loss_value, :check_penalty, :intercept, :residuals,
            :linear_predictor, :deviance, :nulldeviance, :PATH_GAPTOL,
            :OptimizationResults, :ActiveSetResults, :ADMMResults, :PrimalDualResults, :LineSearches))
end

include("types.jl")

include("solve.jl")

# Solvers
include("solvers/image_models.jl")
include("solvers/diagonal_metric.jl")
include("solvers/proximal_gradient_descent.jl")
include("solvers/accelerated_proximal_gradient_descent.jl")
include("solvers/monotone_accelerated_proximal_gradient_descent.jl")
include("solvers/active_accelerated_proximal_gradient_descent.jl")
include("solvers/admm.jl")
include("solvers/primal_dual.jl")

# Coordinate descent
include("cd/models.jl")
include("cd/groupcurvature.jl")
include("cd/solver.jl")
include("cd/leastsquares.jl")
include("cd/multiresponse.jl")
include("cd/quadratic.jl")
include("cd/groups.jl")
include("cd/kron.jl")
include("cd/kronu.jl")
include("cd/sqrtlasso.jl")
include("cd/sqrtquadratic.jl")
include("cd/glm.jl")
include("cd/gap.jl")
include("cd/sparsegroup.jl")
include("cd/quic.jl")
include("cd/generic_newton.jl")
include("cd/path.jl")
include("cd/refit_cache.jl")
include("cd/drivers.jl")
include("cd/lla.jl")

include("solvers/slope.jl")
include("solvers/slope_hybrid.jl")

include("utils.jl")

include("workspaces.jl")

include("precompile.jl")

end
