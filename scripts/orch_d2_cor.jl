# Rigorous D2 (B's schedule) on the correlated cold-start failures reproduced in orch_check_cor.jl.
include("<RUN>/agents/A/lib.jl")
using JuMP, Clarabel; include(joinpath(@__DIR__, "oracle.jl"))
include(joinpath(@__DIR__, "orch_d2_lib.jl"))
function corr(n, p, k, σ, ρ, seed)
  rng = Xoshiro(seed); Z = randn(rng, n, p); z0 = randn(rng, n); Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]; Z, Z * b .+ σ .* randn(rng, n)
end
for (seed, f) in ((20185, .05), (20187, .05), (20188, .05), (20189, .05), (20190, .05), (20190, .2), (20191, .2)), T in (Float64, Float32)
  X, y = corr(60, 150, 4, 1.0, 0.7, seed); λ = f * lammax(X, y)
  XT, yT, λT = T.(X), T.(y), T(λ)
  X64, y64, l64 = Float64.(XT), Float64.(yT), Float64(λT)
  θ, _ = dual(X64, y64, l64); D, _ = dual_lower(X64, y64, l64, θ)
  x0, _, _, _ = ps_solve(XT, yT, λT, zeros(T, 150); order = :cyclic, momentum = false)
  res = d2(XT, yT, λT, x0)
  c = classify(XT, yT, λT, res.ret, (; D = Float64(D)))
  @printf "seed %d f %.2f %-7s outcome=%-11s via=%-6s passes=%6d ratio=%.2e excess=%.2e nnz=%d\n" seed f T res.outcome res.via res.passes res.ratio c.excess c.nnz
end
