# The overflowing-penalty fixtures with ElasticNet(0, 1): new (X = [1], y = [1e20]) and old (X = [1e-20], y = [1], x0 = [1e20]).
using Pkg; Pkg.instantiate()
using ProximalSolvers, ProximalBase
println("# Julia ", VERSION, " PS ", pkgdir(ProximalSolvers))
for (nm, X, y) in (("new X=[1] y=[1e20]", Float32[1;;], Float32[1f20]), ("old X=[1e-20] y=[1]", Float32[1f-20;;], Float32[1]))
  for m in (ProximalGradientDescent(), AccProxGradDescent())
    x0 = Float32[1f20]; x = copy(x0)
    pre = isfinite(LeastSquaresLoss(y, X)(x0)) && !isfinite(ElasticNet(0f0, 1f0)(x0))
    res = try r = solve!(x, LeastSquaresLoss(y, X), ElasticNet(0f0, 1f0), m); "returned conv=$(r.converged) it=$(r.iterations) min=$(r.minimum)" catch e; "THROWS $(typeof(e)): " * first(sprint(showerror, e), 90) end
    println(nm, "\t", nameof(typeof(m)), "\tprecondition=", pre, "\t", res, "\tx=", x[1], "\trestored=", isequal(x, x0))
  end
end
