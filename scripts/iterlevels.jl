# Would using the converted levels for the iterations change the iterates? Float32 data, non-native levels.
using ProximalSolvers, ProximalBase, Random, Printf
const PS = ProximalSolvers
include(joinpath(pkgdir(ProximalSolvers), "benchmark", "problems.jl"))
for (des, n, p, s) in ((:A, 100, 32, 5), (:B, 200, 500, 10), (:C, 1000, 200, 20))
  d = lasso_design(des, 1; n, p, s); T = Float32
  X = T.(d.X); y = T.(d.y); f = (one(T) / T(n)) * LeastSquaresLoss(y, X)
  l = 0.1lambda_max(d.X, d.y)
  for (name, g) in (("Float64 levels", ElasticNet(l, 0.05)), ("Rational levels", ElasticNet(rationalize(Int64, l; tol = 1e-12), 1 // 20)))
    gT = PS._converted_penalty(g, T)
    for m in (ProximalGradientDescent(), AccProxGradDescent(), CDSolver(rng = Xoshiro(1)))
      x1 = zeros(T, p); x2 = zeros(T, p)
      m isa CDSolver ? (solve!(x1, f, g, m); solve!(x2, f, gT, CDSolver(rng = Xoshiro(1)))) :
                       (solve!(x1, f, g, m, ProximalOptions()); solve!(x2, f, gT, m, ProximalOptions()))
      @printf("%s %-16s %-24s bitwise equal iterates: %-5s  entries that differ: %d\n", des, name, nameof(typeof(m)), x1 == x2, count(x1 .!= x2))
    end
  end
end
