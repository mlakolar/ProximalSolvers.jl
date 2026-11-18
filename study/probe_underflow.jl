# The product rᵀX_k underflows although X, y, the loss scale, λ, the curvature and the minimizer are
# normal numbers (#353 cross-reference). CD, PGD and APG on the same inputs, with the exact answer.
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
function case(T, ex, ey, el; n = 2)
  X = fill(ldexp(T(1), ex), n, 1); y = fill(ldexp(T(1), ey), n); α = ldexp(T(1), el)
  λ = T(ldexp(1.0, el + ex + ey)) * T(n) / 8
  R = LassoRef(X, y, α, λ, zero(T))
  xs = polish(R, [1.0])
  ms = measures(R, xs)
  @printf("%s  X = 2^%d, y = 2^%d, α = 2^%d, λ = %.4g; exact minimizer %.6g; Xᵀy computed in %s = %s\n", T, ex, ey, el, λ, Float64(xs[1]), T, string(sum(y .* vec(X))))
  for (name, solve) in (("cd", x -> solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic, momentum = false))),
                        ("pgd", x -> solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), ProximalGradientDescent())),
                        ("apg", x -> solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), AccProxGradDescent())),
                        ("pgd-strict", x -> solve!(x, α * LeastSquaresLoss(y, X), NormL1(λ), ProximalGradientDescent(), ProximalOptions(maxiter = 2000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11))))
    x = zeros(T, 1)
    try
      r = quiet(() -> solve(x))
      m = measures(R, x)
      its = r isa PS.CDResults ? r.passes : r.iterations
      @printf("  %-10s x = %-12.6g converged = %-5s its = %-5d exact ‖G‖∞/max(λ, λmax) = %.3g, (F − F*)/F* = %.3g\n", name, x[1], r.converged, its,
              Float64(m.G / max(R.l1, R.λmax)), Float64((m.F - ms.F) / ms.F))
    catch e
      @printf("  %-10s error: %s\n", name, first(sprint(showerror, e), 110))
    end
  end
end
println("Julia ", VERSION)
case(Float64, -500, -700, 300)
case(Float64, -500, -300, 300)     # control: the product is representable
case(Float32, -70, -90, 90)
case(Float32, -40, -50, 60)        # control
