# #351 lifecycle audit: how often does a solve convert penalty levels in ProximalSolvers?
# Counts calls of PS._converted_penalty (only caller: _stationary!) by redefining it in this session
# with a counter around the same body. Run: julia --project=<PS 8d2a30e> count.jl
using ProximalSolvers, ProximalBase, Random, LinearAlgebra, Printf
const PS = ProximalSolvers
include(joinpath(pkgdir(ProximalSolvers), "benchmark", "problems.jl"))   # lasso_design, lambda_max

const NCONV = Ref(0)
@eval PS begin
  _converted_penalty(g::NormL1, ::Type{T}) where T = ($NCONV[] += 1; NormL1(T(g.λ0)))
  _converted_penalty(g::ElasticNet, ::Type{T}) where T = ($NCONV[] += 1; ElasticNet(T(g.λ1), T(g.λ2)))
end

opts = (("default", ProximalOptions()),
        ("bench", ProximalOptions(maxiter = 10_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)),
        ("acc", ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = 1e-10, allow_f_increases = true)))
@printf("%-7s %-4s %-9s %-7s %-4s %-20s %6s %6s %5s %9s\n", "T", "des", "n×p", "opts", "meth", "penalty", "iters", "checks", "conv", "refused")
tot = Dict{String, Vector{Int}}()
for T in (Float32, Float64), (des, n, p, s) in ((:A, 100, 32, 5), (:B, 200, 500, 10), (:C, 1000, 200, 20)), (oname, o) in opts
  d = lasso_design(des, 1; n, p, s)
  X = T.(d.X); y = T.(d.y)
  α = one(T) / T(n)
  λmax = lambda_max(d.X, d.y)
  f = α * LeastSquaresLoss(y, X)
  for (pname, g) in (("NormL1(0.1λmax)", NormL1(T(0.1λmax))), ("EN(0.1λmax, 0.05)", ElasticNet(T(0.1λmax), T(0.05))),
                     ("EN Rational", ElasticNet(rationalize(Int64, 0.1λmax; tol = 1e-12), 1 // 20)))
    for (mname, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
      x = zeros(T, p)
      NCONV[] = 0
      r = solve!(x, f, g, m, o)
      refused = NCONV[] - (r.converged ? 1 : 0)
      @printf("%-7s %-4s %-9s %-7s %-4s %-20s %6d %6d %5s %9d\n", T, des, "$(n)×$(p)", oname, mname, pname, r.iterations, NCONV[], r.converged, refused)
      v = get!(tot, mname, [0, 0, 0]); v .+= (1, r.iterations, NCONV[])
    end
  end
  # CD: count, with the default CDSolver
  x = zeros(T, p); NCONV[] = 0
  solve!(x, f, NormL1(T(0.1λmax)), CDSolver(rng = Xoshiro(1)))
  solve!(zeros(T, p), f, ElasticNet(T(0.1λmax), T(0.05)), CDSolver(rng = Xoshiro(1)))
  v = get!(tot, "CD", [0, 0, 0]); v .+= (2, 0, NCONV[])
end
for (k, v) in tot
  @printf("%s: %d solves, %d iterations, %d conversions (%.3f per solve, %.4f per iteration)\n", k, v[1], v[2], v[3], v[3] / v[1], v[2] > 0 ? v[3] / v[2] : 0.0)
end
