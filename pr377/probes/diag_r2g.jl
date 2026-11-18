include(joinpath(@__DIR__, "variants.jl"))   # VARIANT=M or R2g
using ProximalBase
f = LeastSquaresLoss([0.0, 1e-6 * 1e-150], [1.0 0; 0 1e-6])
for o in (ProximalOptions(), ProximalOptions(maxiter = 20_000), ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true))
  x = [0.0, 0.0]
  r = try solve!(x, f, NormL1(0.0), ProximalGradientDescent(), o) catch e; sprint(showerror, e) end
  println(VARIANT, " maxiter=", o.maxiter, " ftol=", o.ftol, ": ", r isa String ? "ERR $r" : "it=$(r.iterations) conv=$(r.converged) finc=$(r.f_increased) x=$(x) relerr=$(abs(x[2]-1e-150)/1e-150)")
end
