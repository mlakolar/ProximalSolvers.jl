# Minimal reproducer: plain `_column_dot` underflows the correlation b = rᵀX_k to 0 although X, y, α, λ and the curvature are all normal
# numbers and the exact minimizer is a normal number: CD reports converged = true at x = 0.
using ProximalSolvers, ProximalBase, Logging, Printf
setprecision(BigFloat, 600)
function case(T, ex, ey, el, n=2)
  X = fill(ldexp(T(1), ex), n, 1); y = fill(ldexp(T(1), ey), n)
  α = ldexp(T(1), el)
  a = n * BigFloat(X[1])^2; b = n * BigFloat(X[1]) * BigFloat(y[1])
  λ = T(ldexp(1.0, el + ex + ey)) * T(n) / 8            # = α b / 8 exactly in exact arithmetic: nonzero minimizer x* = (7/8) b/a
  xstar = (BigFloat(α) * b - BigFloat(λ)) / (BigFloat(α) * a)
  f = α * LeastSquaresLoss(y, X); g = NormL1(λ); x = zeros(T, 1)
  r = with_logger(NullLogger()) do; solve!(x, f, g, CDSolver(order=:cyclic, momentum=false)); end
  @printf("%s: X entries 2^%d, y entries 2^%d, α = 2^%d, λ = %.3g: a = %.3g (normal: %s), α a normal: %s, exact x* = %.4g, returned x = %.4g, converged = %s, passes = %d\n",
          T, ex, ey, el, λ, Float64(a), a >= BigFloat(floatmin(T)), BigFloat(α)*a >= BigFloat(floatmin(T)), Float64(xstar), x[1], r.converged, r.passes)
  @printf("   rᵀX_k as computed in T = %s ; exact %.3g (min subnormal %.3g)\n", string(sum(y .* vec(X))), Float64(b), Float64(nextfloat(zero(T))))
end
case(Float64, -500, -700, 300)
case(Float64, -500, -300, 300)     # control: product 2^-800, no underflow of rᵀX
case(Float32, -70, -90, 90)
case(Float32, -40, -50, 60)        # control
