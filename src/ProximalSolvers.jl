"""
    ProximalSolvers

Least-squares lasso, with or without weights (`NormL1(λ)` or `NormL1(λ, w)`), and elastic net
(`ElasticNet(λ1, λ2)`, or `ElasticNet(λ1, λ2, w)` with weights on its L1 term) with dense Matrix designs, for
[`CDSolver`](@ref), [`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref).
[`CDSolver`](@ref) also solves least-squares ridge with uncentered `SqrNormL2`.
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) also solve the least-squares
problem with a `NormLinf` penalty (the largest magnitude of the entries) and with a `NormL2` penalty (the
Euclidean norm of the whole vector, a single group); [`CDSolver`](@ref) supports neither.
[`CDSolver`](@ref) also solves the square-root lasso, with ProximalBase's `SqrtLeastSquaresLoss` and
an unweighted `NormL1`, and reports `converged = true` for it only with a duality certificate.
[`CDSolver`](@ref) accepts a dense
`Vector` or a one-dimensional `SparseIterate` as the iterate, and, for a group lasso with
a `GroupNormL2` penalty, a `BlockIterate`. For a matrix response `Y` and a `GroupNormL2` whose
groups are the rows of the coefficients, it accepts a `Matrix` coefficient (or a `BlockIterate`
over its entries) with a dense `X`, `Y` and `LeastSquaresLoss`. [`ProximalGradientDescent`](@ref) and
[`AccProxGradDescent`](@ref) accept a dense `Vector` for these least-squares problems, all through [`solve!`](@ref);
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) also solve the group lasso with a `GroupNormL2` penalty on it.
For a dense matrix response, both accept a same-type dense matrix of coefficients
and an unweighted entrywise `NormL1` penalty under
[IN-10](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-10).
[`ProximalGradientDescent`](@ref) also supports `IndNonnegative()` and unweighted `NormL1Nonneg` on a feasible dense `Vector`, and [`CDSolver`](@ref) does too with a vector-response `LeastSquaresLoss`, raw or with one supported positive scale (the input rules are [IN-01](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-01) and [IN-02](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-02)).
[`ProximalGradientDescent`](@ref) and [`AccProxGradDescent`](@ref) also fit sparse logistic regression with a raw
`LogisticLoss(y, X)` (a dense `Matrix{Float64}` design and a binary `Vector{Float64}` response, no observation weights
or offset) and `NormL1` on a `Vector{Float64}`.
[`ProxNewton`](@ref) fits the same problem by proximal Newton steps, each solved by cyclic coordinate descent on a
weighted least-squares model ([PN-01](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-proxnewton/#PN-01)).
[`LogisticADMM`](@ref) fits it by ADMM on the split `t = X * b`, with a length-`n` predictor and dual
([LA-01](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/logistic-admm/#LA-01)).
[`ADMMSolver`](@ref) solves centered `SqrNormL2` with unweighted `NormL1` on dense vectors.
[`ADMMSolver`](@ref) also solves the lasso with a raw `LeastSquaresLoss` and unweighted `NormL1` for `Float64` data with a tall or square design, specified in [ADM-05](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-05).
[`ADMMSolver`](@ref) also supports the graphical-lasso combination of `LogDetLoss` and matrix-weighted `NormL1` on a dense `Matrix` specified in [ADM-04](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/admm/#ADM-04).
[`ProximalGradientDescent`](@ref) also solves this graphical-lasso problem with bounded SPD backtracking and a KKT check, as specified in [PGD-06](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-logdet/#PGD-06).
Losses, proximal operators and coordinate storage belong to PB.
"""
module ProximalSolvers
using LinearAlgebra
using Printf
using Random: AbstractRNG, default_rng, rand
using SparseArrays: dropzeros!
import ProximalBase
using ProximalBase: LeastSquaresLoss, SqrtLeastSquaresLoss, LogisticLoss, Scaled, NormL1, LogDetLoss, NormL1Nonneg, IndNonnegative, IndBox, IndBallL2, ElasticNet, SqrNormL2, NormLinf, NormL2, SparseIterate,
  ncoordinates, nactive, activecoordinates, activevalues, prox_block,
  prox!, value_and_prox!, BlockIterate, GroupNormL2, blockindices, blockview, prox_block!, kkt_violation
include("blocks.jl")
using .Blocks
include("line_searches.jl")
using .LineSearches
export CDSolver, ProximalGradientDescent, AccProxGradDescent, ProxNewton, LogisticADMM, solve!, ProximalSolver,
       ProximalOptions, ADMMSolver, ADMMResults, CDResults, ProxNewtonResults, LogisticADMMResults, OptimizationState,
       OptimizationTrace
@static if VERSION >= v"1.11.0-DEV.469"
  eval(Expr(:public, :OptimizationResults, :ProximalGradientStoppingResult, :CoordinateDescentStoppingResult,
            :ADMMStoppingResult, :LineSearches))
end
include("types.jl")
include("stopping.jl")
using .Stopping
export Stopping, IterateChange, ObjectiveChange, ScaledKKT, UserStop, AnyOf, AllOf, MaxIterations, MaxPasses, termination
export MaxCoordinateVisits
export PrimalResidual, DualResidual
export MaxObjectiveEvaluations, MaxGradientEvaluations, MaxProximalEvaluations
include("solve.jl")
include("solvers/image_models.jl")
include("solvers/proximal_gradient_descent.jl")
include("solvers/accelerated_proximal_gradient_descent.jl")
include("solvers/admm.jl")
include("solvers/logdet_proximal_gradient.jl")
include("cd/models.jl")
include("cd/solver.jl")
include("cd/multiresponse.jl")
include("cd/leastsquares.jl")
include("cd/sqrtlasso.jl")
include("solvers/logistic_proxnewton.jl")
include("solvers/logistic_admm.jl")
include("utils.jl")
include("solvers/gradient_stopping.jl")
include("precompile.jl")
end
