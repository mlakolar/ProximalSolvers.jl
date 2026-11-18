# Fuzz the outward-rounded validator against BigFloat: for random data, β, θ̂ (including wide scales and
# near-feasible θ̂): (a) t_f θ̂ is exactly dual feasible; (b) gap ≥ P(β) − t_f θ̂ᵀy; (c) Dlo ≤ t_f θ̂ᵀy ≤ P*-bound.
include(joinpath(@__DIR__, "lib.jl"))
rng = Xoshiro(2026); bad = Dict(:feas => 0, :gap => 0, :dlo => 0, :nonfinite => 0); N = 0; okc = 0
for trial in 1:30_000
  n = rand(rng, 2:30); p = rand(rng, 2:40); sc = 10.0^rand(rng, -8:8)
  cs = 10.0 .^ (rand(rng, p) .* 6 .- 3)
  X = randn(rng, n, p) .* cs' .* sc; y = randn(rng, n) .* sc .* 10.0^rand(rng, -2:2)
  if rand(rng) < 0.3; X = Float64.(Float32.(X)); y = Float64.(Float32.(y)); end
  nbn = rand(rng, 0:min(p, 6)); β = zeros(p); idx = randperm(rng, p)[1:nbn]; β[idx] .= randn(rng, nbn) ./ sc
  if rand(rng) < 0.5; y = y + X*β; end           # exact-ish fit half of the time
  λ = abs(randn(rng))*sc*rand(rng, [1e-2, 1, 1e2])
  θ = randn(rng, n) .* rand(rng, [1e-3, 1.0, 1e3])
  if rand(rng) < 0.5                              # make θ̂ nearly feasible
    θ = θ ./ max(norm(θ), maximum(abs, X'*θ)/λ) .* (1 - 10.0^rand(rng, -9:-1))
  end
  v = vcert(X, y, λ, λ, β, θ)
  isfinite(v.gap) || (bad[:nonfinite] += 1; continue)
  global N += 1; v.ok && (global okc += 1)
  Xb, yb, θb, βb, λb = big.(X), big.(y), big.(θ), big.(β), big(λ)
  tf = big(v.t)
  feas = tf*norm(θb) <= 1 && tf*maximum(abs, Xb'*θb) <= λb
  feas || (bad[:feas] += 1)
  P = norm(yb - Xb*βb) + λb*sum(abs, βb); Dv = tf*dot(θb, yb)
  big(v.gap) >= P - Dv || (bad[:gap] += 1)
  isfinite(v.Dlo) && (big(v.Dlo) <= Dv || (bad[:dlo] += 1))
end
println("trials with finite gap: ", N, "  certified-ok: ", okc, "  violations: ", bad)
