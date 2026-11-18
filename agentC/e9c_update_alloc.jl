include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss, NormL1
println("E9c warmed update_state! allocations, julia ", VERSION)
rng = Xoshiro(10)
for T in (Float32, Float64), (name, method) in (("APG", AccProxGradDescent()), ("PGD", ProximalGradientDescent()))
  n, p = 300, 80
  X = randn(rng, T, n, p); y = X * T.(vcat(ones(5), zeros(p - 5))) .+ T(0.1) .* randn(rng, T, n)
  f = LeastSquaresLoss(y, X); g = NormL1(T(0.1) * maximum(abs, X' * y))
  x = zeros(T, p)
  st = PS.initial_state(method, ProximalOptions(), f, g, x)
  for _ in 1:30; PS.update_state!(f, g, st, method); end     # warm
  alloc = [(@allocated PS.update_state!(f, g, st, method)) for _ in 1:20]
  @printf("  %-8s %s update_state! allocations over 20 iterations: min=%d max=%d bytes (fallbacks so far: %s)\n", T, name, minimum(alloc), maximum(alloc), hasproperty(st, :fallbacks) ? st.fallbacks : "-")
end
