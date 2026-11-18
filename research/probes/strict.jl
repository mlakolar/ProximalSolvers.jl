include(joinpath(@__DIR__, "variants.jl"))
using ProximalBase, Random
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
xr = X \ y
STRICT = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
for α in (1.0, 1e-158, 1e-200, 1e-300), frac in (0.0, 0.1)
  λ = frac * α * norm(X'y, Inf); x = zeros(12)
  r = try solve!(x, α*LeastSquaresLoss(y, X), NormL1(λ), ProximalGradientDescent(), STRICT) catch e; sprint(showerror, e) end
  println("$VARIANT strict α=$α frac=$frac ", r isa String ? "ERR $r" : "it=$(r.iterations) conv=$(r.converged)" * (frac == 0 ? " relerr=$(norm(x-xr)/norm(xr))" : ""))
end
