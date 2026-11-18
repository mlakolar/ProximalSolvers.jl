# Orchestrator reproduction of Agent C's natural cold-start failure (equicorrelated ρ=0.7, n=60, p=150, σ=1).
include(joinpath(@__DIR__, "common.jl")); using JuMP, Clarabel; include(joinpath(@__DIR__, "oracle.jl"))
function corr(n, p, k, σ, ρ, seed)
  rng = Xoshiro(seed); Z = randn(rng, n, p); z0 = randn(rng, n); Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]; Z, Z * b .+ σ .* randn(rng, n)
end
for seed in 20185:20191
  X, y = corr(60, 150, 4, 1.0, 0.7, seed)
  for f in (0.05, 0.2)
    λ = f * lammax(X, y)
    β, _ = primal(X, y, λ); θ, _ = dual(X, y, λ); D, _ = dual_lower(X, y, λ, θ)
    rro = Float64(norm(big.(y) - big.(X) * big.(β)) / norm(big.(y)))
    x, r, _, _ = ps_solve(X, y, λ, zeros(150); order = :cyclic, momentum = false)
    c = classify(X, y, λ, x, (; D = Float64(D)))
    @printf "seed %d f %.2f  opt exact=%s  conv=%s passes=%d excess=%.3e nnz=%d\n" seed f (rro < 1e-8) r.converged r.passes c.excess c.nnz
  end
end
