using ProximalSolvers, ProximalBase, LinearAlgebra, Random
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
xr = X \ y
for α in (1.0, 1e-100, 1e-158, 1e-200, 1e-300), (on, o) in (("def", ProximalOptions(maxiter = 20_000)), ("afi", ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true)))
  x = zeros(12)
  r = try solve!(x, α*LeastSquaresLoss(y, X), NormL1(0.0), AccProxGradDescent(), o) catch e; sprint(showerror, e) end
  println("APG α=$α $on ", r isa String ? "ERR $r" : "it=$(r.iterations) conv=$(r.converged) relerr=$(norm(x-xr)/norm(xr))")
end
