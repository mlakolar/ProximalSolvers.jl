# Minimal #317 reproducer candidates (run under VARIANT=M and R1)
include(joinpath(@__DIR__, "variants.jl"))
using ProximalBase
for α in (1e-150, 1e-160, 1e-170, 1e-200), maxiter in (200, 2000)
  x = [0.0]
  r = try solve!(x, α * LeastSquaresLoss([1.0], [1.0;;]), NormL1(0.0), ProximalGradientDescent(), ProximalOptions(; maxiter)) catch e; sprint(showerror, e) end
  println("1x1 α=$α maxiter=$maxiter: ", r isa String ? "ERR $r" : "it=$(r.iterations) conv=$(r.converged) finc=$(r.f_increased) x=$(x[1])")
end
