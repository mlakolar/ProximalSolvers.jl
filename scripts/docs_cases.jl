# The rescaling cases quoted in docs/src/numerics.md, at the worktree this runs in.
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers
println("# Julia ", VERSION, " PS ", pkgdir(PS))
function run1(name, X, y, α, λ)
  for m in (ProximalGradientDescent(), AccProxGradDescent())
    x = zeros(1)
    L0 = PS.initial_state(m, ProximalOptions(), Scaled(LeastSquaresLoss(y, X), α), NormL1(λ), zeros(1)).L
    r = solve!(x, Scaled(LeastSquaresLoss(y, X), α), NormL1(λ), m, ProximalOptions())
    println(name, "\t", nameof(typeof(m)), "\tL0=", L0, "\tconv=", r.converged, "\titer=", r.iterations, "\tf_inc=", r.f_increased, "\tx=", x[1])
  end
end
X, y, α = ones(5, 1), fill(1e160, 5), 1e-100
run1("s=1e50 lambda=1e110 (x = s u)", 1e50 .* X, y, α, 1e110)
run1("s=1e50 lambda=0", 1e50 .* X, y, α, 0.0)
run1("c=1e-80 lambda=0", 1e-80 .* X, 1e-80 .* y, α / 1e-160, 0.0)
run1("lambda=1e60 plain", X, y, α, 1e60)
