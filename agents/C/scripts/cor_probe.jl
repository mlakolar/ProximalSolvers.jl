# Probe the natural (non-constructed) failure COR-n60p150-r0.7-f0.2-20190: Float64, cold start, δ grid (half-decades from P*), maxpasses per stage 200k.
include(joinpath(@__DIR__, "stress.jl"))
function corr(n, p, k, σ, ρ, seed)
  rng = Xoshiro(seed); Z = randn(rng, n, p); z0 = randn(rng, n); Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]; Z, Z * b .+ σ .* randn(rng, n)
end
X, y = corr(60, 150, 4, 1.0, 0.7, 20190); λ = 0.2 * lammax(X, y)
rec = oracle_for(X, y, λ, Float64); Ps = rec.D
println("P*=", Ps, " rrel=", rec.rrel, " nnz*=", count(abs.(rec.β) .> 1e-9))
β0, conv, ps = stuck_point(X, y, λ, zeros(150)); println("stuck passes=", ps, " excess=", Float64((Pbig(X, y, λ, β0) - big(Ps)) / big(Ps)))
let β = copy(β0); bestP = Pbig(X, y, λ, β0); bestD = big(0.0)
for k in -2:2:24
  δ = Ps * 10.0^(-k / 3)
  β, ps, sec, _, cv = smooth_stage(X, y, λ, β, δ; maxpasses = 200_000)
  P = Pbig(X, y, λ, β); D = dual_res_big(X, y, λ, β); bestP = min(bestP, P); bestD = max(bestD, D)
    println("δ/P*=", round(10.0^(-k / 3); sigdigits = 3), " passes=", ps, " conv=", cv, " errP=", Float64((P - big(Ps)) / big(Ps)), " errD=", Float64((big(Ps) - D) / big(Ps)), " nnz=", count(!iszero, β), " best ratio=", Float64((bestP - bestD) / bestD))
end
end
