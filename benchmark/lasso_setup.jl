# Problems, solvers and accuracy measures for lasso_bench.jl.
#
# Every solver minimizes the same objective
#
#     F(β) = ‖y - Xβ‖² / (2n) + λ‖β‖₁
#
# (no intercept, no standardization). ProximalBase's LeastSquaresLoss is
# ‖y - Xβ‖² / 2, so the ProximalSolvers solvers get X/√n and y/√n; the solvers that
# use X'X get A = X'X/n and b = -X'y/n, whose quadratic differs from F only by
# the constant ‖y‖²/(2n).

using LinearAlgebra, Random, Statistics, SparseArrays, Printf
using ProximalBase, ProximalSolvers
using Serialization

include(joinpath(@__DIR__, "lasso_common.jl"))
include(joinpath(@__DIR__, "lasso_legacy_client.jl"))
import HighDimensionalModels, GLMNet, Lasso

################################################################################
# solvers at one λ: (P, λ, tol) -> dense β, solved from β = 0

struct Solver{F}
  name::String
  package::String
  run::F
  needs_gram::Bool
end

cd_options(tol; kwargs...) = HighDimensionalModels.CDOptions(; opt_tol = Float64(tol), max_iter = 1_000_000, kwargs...)
prox_options(tol) = ProximalOptions(; maxiter = 1_000_000, ftol = tol, xtol = tol, gradtol = tol,
                                    time_limit = 60.0)

function run_cd(P, λ, tol; kwargs...)
  x = SparseIterate(P.p)
  HighDimensionalModels.coordinate_descent!(x, HighDimensionalModels.CDLeastSquaresLoss(P.y, P.X),
    NormL1(λ), cd_options(tol; kwargs...); rng = Xoshiro(20261024))
  Vector(x)
end

function run_cd_gram(P, λ, tol)
  x = SparseIterate(P.p)
  HighDimensionalModels.coordinate_descent!(x, HighDimensionalModels.CDQuadraticLoss(P.G, P.mc),
    NormL1(λ), cd_options(tol; order = :random); rng = Xoshiro(20261024))
  Vector(x)
end

function run_prox(P, λ, tol, method; gram = false)
  f = gram ? QuadraticFunction(P.G, P.mc) : LeastSquaresLoss(P.ys, P.Xs)
  x = method isa ActiveAccProxGradDescent ? SparseIterate(P.p) : zeros(P.p)
  solve!(x, f, NormL1(λ), method, prox_options(tol))
  x isa SparseIterate ? Vector(x) : x
end

# glmnet's tol bounds squared coefficient changes, so it needs a smaller tol
# than the other solvers for the same accuracy
function run_glmnet(P, λ, tol)
  path = GLMNet.glmnet(P.X, P.y; lambda = [λ], standardize = false, intercept = false, tol = tol)
  convert(Matrix{Float64}, path.betas)[:, 1]
end

function run_lassojl(P, λ, tol)
  path = Lasso.fit(Lasso.LassoPath, P.X, P.y; λ = [λ], standardize = false, intercept = false,
                   cd_tol = tol, cd_maxiter = 1_000_000, stopearly = false, maxncoef = P.p)
  Vector(Lasso.coef(path)[:, 1])
end

const SOLVERS = [
  Solver("CD 0.5.6 cyclic",         "CoordinateDescent 0.5.6", LegacyRun(:cyclic), false),
  Solver("CD 0.5.6 random",         "CoordinateDescent 0.5.6", LegacyRun(:random), false),
  Solver("CD 0.5.6 path from λmax", "CoordinateDescent 0.5.6", LegacyRun(:continuation), false),
  Solver("CD 0.5.6 X'X/n",          "CoordinateDescent 0.5.6", LegacyRun(:gram), true),
  Solver("CD 0.8 cyclic",           "HighDimensionalModels $(pkgversion(HighDimensionalModels))", (P, λ, t) -> run_cd(P, λ, t; order = :cyclic), false),
  Solver("CD 0.8 random",           "HighDimensionalModels $(pkgversion(HighDimensionalModels))", (P, λ, t) -> run_cd(P, λ, t; order = :random), false),
  Solver("CD 0.8 path from λmax",   "HighDimensionalModels $(pkgversion(HighDimensionalModels))", (P, λ, t) -> run_cd(P, λ, t; order = :random, warm_start = false), false),
  Solver("CD 0.8 X'X/n",            "HighDimensionalModels $(pkgversion(HighDimensionalModels))", run_cd_gram, true),
  Solver("ProxGrad",                "ProximalSolvers", (P, λ, t) -> run_prox(P, λ, t, ProximalGradientDescent()), false),
  Solver("AccProxGrad",             "ProximalSolvers", (P, λ, t) -> run_prox(P, λ, t, AccProxGradDescent()), false),
  Solver("ActiveAccProxGrad",       "ProximalSolvers", (P, λ, t) -> run_prox(P, λ, t, ActiveAccProxGradDescent()), false),
  Solver("AccProxGrad X'X/n",       "ProximalSolvers", (P, λ, t) -> run_prox(P, λ, t, AccProxGradDescent(); gram = true), true),
  Solver("ActiveAccProxGrad X'X/n", "ProximalSolvers", (P, λ, t) -> run_prox(P, λ, t, ActiveAccProxGradDescent(); gram = true), true),
  Solver("glmnet",                  "GLMNet.jl", run_glmnet, false),
  Solver("Lasso.jl",                "Lasso.jl", run_lassojl, false),
]

# each package at its default options
const DEFAULT_RUNS = [
  ("CD 0.5.6 lasso()",  LegacyRun(:default)),
  ("CD 0.8 lasso()",    (P, λ) -> Vector(HighDimensionalModels.lasso(P.X, P.y, λ; rng = Xoshiro(20261024)).x)),
  ("ProxGrad",          (P, λ) -> (x = zeros(P.p); solve!(x, LeastSquaresLoss(P.ys, P.Xs), NormL1(λ), ProximalGradientDescent()); x)),
  ("AccProxGrad",       (P, λ) -> (x = zeros(P.p); solve!(x, LeastSquaresLoss(P.ys, P.Xs), NormL1(λ), AccProxGradDescent()); x)),
  ("ActiveAccProxGrad", (P, λ) -> (x = zeros(P.p); solve!(x, LeastSquaresLoss(P.ys, P.Xs), NormL1(λ), ActiveAccProxGradDescent()); x)),
  ("glmnet",            (P, λ) -> convert(Matrix{Float64}, GLMNet.glmnet(P.X, P.y; lambda = [λ], standardize = false, intercept = false).betas)[:, 1]),
  ("Lasso.jl",          (P, λ) -> Vector(Lasso.coef(Lasso.fit(Lasso.LassoPath, P.X, P.y; λ = [λ], standardize = false, intercept = false, maxncoef = P.p))[:, 1])),
]

################################################################################
# solvers along a path of λ values, each warm started from the previous solution:
# (P, λs, tol) -> vector of dense solutions

function path_cd(P, λs, tol)
  path = HighDimensionalModels.LassoPath(P.X, P.y, λs, cd_options(tol; order = :random);
    standardize_x = false, rng = Xoshiro(20261024))
  [Vector(b) for b in path.βpath]
end

function path_cd_gram(P, λs, tol)
  x = SparseIterate(P.p)
  f = HighDimensionalModels.CDQuadraticLoss(P.G, P.mc)
  options = cd_options(tol; order = :random)
  rng = Xoshiro(20261024)
  [(HighDimensionalModels.coordinate_descent!(x, f, NormL1(λ), options; rng); Vector(x)) for λ in λs]
end

function path_prox(P, λs, tol, method; gram = false)
  f = gram ? QuadraticFunction(P.G, P.mc) : LeastSquaresLoss(P.ys, P.Xs)
  x = method isa ActiveAccProxGradDescent ? SparseIterate(P.p) : zeros(P.p)
  o = prox_options(tol)
  [(solve!(x, f, NormL1(λ), method, o); Vector(x)) for λ in λs]
end

function path_glmnet(P, λs, tol)
  path = GLMNet.glmnet(P.X, P.y; lambda = λs, standardize = false, intercept = false, tol = tol)
  B = convert(Matrix{Float64}, path.betas)
  [B[:, k] for k in axes(B, 2)]
end

function path_lassojl(P, λs, tol)
  path = Lasso.fit(Lasso.LassoPath, P.X, P.y; λ = λs, standardize = false, intercept = false,
                   cd_tol = tol, cd_maxiter = 1_000_000, stopearly = false, maxncoef = P.p)
  B = Matrix(Lasso.coef(path))
  [B[:, k] for k in axes(B, 2)]
end

const PATH_SOLVERS = [
  Solver("CD 0.5.6 LassoPath",      "CoordinateDescent 0.5.6", LegacyRun(:path), false),
  Solver("CD 0.5.6 X'X/n",          "CoordinateDescent 0.5.6", LegacyRun(:path_gram), true),
  Solver("CD 0.8 LassoPath",        "HighDimensionalModels $(pkgversion(HighDimensionalModels))", path_cd, false),
  Solver("CD 0.8 X'X/n",            "HighDimensionalModels $(pkgversion(HighDimensionalModels))", path_cd_gram, true),
  Solver("ProxGrad",                "ProximalSolvers", (P, λs, t) -> path_prox(P, λs, t, ProximalGradientDescent()), false),
  Solver("AccProxGrad",             "ProximalSolvers", (P, λs, t) -> path_prox(P, λs, t, AccProxGradDescent()), false),
  Solver("ActiveAccProxGrad",       "ProximalSolvers", (P, λs, t) -> path_prox(P, λs, t, ActiveAccProxGradDescent()), false),
  Solver("ActiveAccProxGrad X'X/n", "ProximalSolvers", (P, λs, t) -> path_prox(P, λs, t, ActiveAccProxGradDescent(); gram = true), true),
  Solver("glmnet",                  "GLMNet.jl", path_glmnet, false),
  Solver("Lasso.jl",                "Lasso.jl", path_lassojl, false),
]

################################################################################
# timing and reference solutions

# Reference solutions come from the same isolated historical implementation.
function reference(P, λ)
  β = LegacyRun(:random)(P, λ, 1e-14)
  β, objective(P, β, λ), lasso_kkt(P, β, λ)
end

path_reference(P, λs) = LegacyRun(:path_reference)(P, λs, 1e-14)
