include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss, NormL1
println("E15 solver behaviour at small data scale (observation for #352, not a helper bug claim), julia ", VERSION)
rng = Xoshiro(15)
for T in (Float64, Float32), sc in (0, -20, -30, -40, -50, -60)
  n, p = 100, 40
  X0 = randn(rng, n, p); b = zeros(p); b[1:5] .= 1; y0 = X0 * b .+ 0.1 * randn(rng, n)
  X, y = T.(X0 .* 2.0^sc), T.(y0 .* 2.0^sc)
  λ = T(0.05 * maximum(abs, X' * y))
  for (name, m) in (("APG", AccProxGradDescent()), ("PGD", ProximalGradientDescent()))
    x = zeros(T, p)
    r = try; solve!(x, LeastSquaresLoss(y, X), NormL1(λ), m); catch err; nothing; end
    r === nothing && (println("  $T 2^$sc $name threw"); continue)
    # exact optimum reference: solve to high accuracy with CD? just report iterations, converged and relative error of support
    @printf("  %-8s scale 2^%-4d %s iterations=%4d converged=%-5s maxiter-hit=%s  x[1:3]=%s\n", T, sc, name, r.iterations, r.converged, r.iteration_converged === nothing ? "?" : "-", round.(Float64.(x[1:3]) ./ 2.0^(-sc) .* 2.0^(-sc), digits = 4))
  end
end
