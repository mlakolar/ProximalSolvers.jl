# PGD on designs scaled up: which exit ends the solves that do not converge?
include(joinpath(@__DIR__, "lib.jl"))
setprecision(BigFloat, PREC)
for (T, exs, eys) in ((Float64, (100, 200, 400, 500), (-500, -400, -200, -100, 0, 100, 200, 400, 500)), (Float32, (0, 20, 40, 60), (-60, -40, -20, 0, 20, 40, 60)))
  _, X0, y0 = fixture("gauss")
  Xu, yu = T.(X0), T.(y0)
  λu = T(0.1 * maximum(abs, Float64.(Xu)' * Float64.(yu)))
  for ex in exs, ey in eys
    X, y, λ = ldexp.(Xu, ex), ldexp.(yu, ey), ldexp(λu, ex + ey)
    (all(isfinite, X) && all(isfinite, y) && isfinite(λ) && λ >= floatmin(T) && all(v -> iszero(v) || abs(v) >= floatmin(T), X) && all(v -> iszero(v) || abs(v) >= floatmin(T), y)) || continue
    x = zeros(T, size(X, 2))
    r = quiet(() -> solve!(x, LeastSquaresLoss(y, X), NormL1(λ), ProximalGradientDescent()))
    r.converged && continue
    m = measures(LassoRef(X, y, one(T), λ, zero(T)), x)
    @printf("%s ex=%d ey=%d iterations=%d f_increased=%s at_maxiter=%s stagnated=%s exact kkt_rel=%.3g\n", T, ex, ey, r.iterations, r.f_increased, r.iteration_converged, r.stagnated, Float64(m.G / max(big(λ), big(maximum(abs, big.(X)' * big.(y))))))
  end
end
