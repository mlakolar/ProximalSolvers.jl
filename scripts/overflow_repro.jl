# PGD's backtracking test at steps whose squared norm overflows: the curvature is L_f = α‖X‖₂² = 1,
# so the start L = 1 is right, and the minimizer is 1e160 * c for each scale c.
using Pkg; VERSION >= v"1.11" && Pkg.instantiate()
using ProximalSolvers, ProximalBase, LinearAlgebra
println("Julia ", VERSION, " | ", Sys.CPU_NAME, " | PS ", pkgdir(ProximalSolvers))
for c in (1e150, 1e153, 1e154, 1e155, 1e160)
  X = ones(5, 1); y = fill(c, 5); f = Scaled(LeastSquaresLoss(y, X), 0.2)
  for (name, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
    x = zeros(1)
    r = solve!(x, f, NormL1(0.0), m)
    flags = (r.x_converged, r.f_converged, r.grad_converged)
    println(rpad(name, 4), " c=", c, " converged=", r.converged, " iterations=", r.iterations,
            " x/c=", x[1] / c, " flags(x,f,g)=", flags,
            " f_increased=", r.f_increased)
  end
end
