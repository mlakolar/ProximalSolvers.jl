using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const PS = ProximalSolvers
BLAS.set_num_threads(1)
strict(m) = PS.ProximalOptions(maxiter = m, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)
rng = Xoshiro(1); n, p = 50, 10
for T in (Float32, Float64)
  X = T.(randn(rng, n, p)); y = T.(randn(rng, n))
  lmax = maximum(abs, X' * y) / n
  # (a) lambda above lambda_max, start at the exact optimum 0
  f = (one(T)/T(n)) * LeastSquaresLoss(y, X); g = NormL1(T(1.5lmax))
  x = zeros(T, p)
  r = try PS.solve!(x, f, g, ProximalGradientDescent(), strict(5000)) catch e; e end
  println(T, " (a) lambda>lambda_max, x0=0: ", r isa Exception ? "THROWS: $(sprint(showerror, r))" : "iters=$(r.iterations) converged=$(r.converged) x==0: $(all(iszero, x))")
  # (b) exact interpolation, integer data, lambda = 0, start at the exact optimum
  Xi = T.(rand(rng, -3:3, n, p)); β = T.(rand(rng, -2:2, p)); yi = Xi * β
  f = (one(T)/T(n)) * LeastSquaresLoss(yi, Xi); g = NormL1(zero(T))
  x = copy(β)
  r = try PS.solve!(x, f, g, ProximalGradientDescent(), strict(5000)) catch e; e end
  println(T, " (b) exact interpolation at x*: ", r isa Exception ? "THROWS: $(sprint(showerror, r))" : "iters=$(r.iterations) converged=$(r.converged) x==β: $(x == β)")
  r = try PS.solve!(x, f, g, AccProxGradDescent(), strict(5000)) catch e; e end
  println(T, " (b) APG: ", r isa Exception ? "THROWS: $(sprint(showerror, r))" : "iters=$(r.iterations) converged=$(r.converged)")
end
