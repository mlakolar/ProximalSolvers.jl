# How often does the stop check return :uncertified on ORDINARY problems (r* != 0 expected) from a cold start? (the fallback's trigger)
include(joinpath(@__DIR__, "stress.jl"))
function corr(n, p, k, σ, ρ, seed)
  rng = Xoshiro(seed); Z = randn(rng, n, p); z0 = randn(rng, n); Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]; Z, Z * b .+ σ .* randn(rng, n)
end
cases = NamedTuple[]
seed = 20000
for (n, p) in ((60, 20), (200, 50), (100, 40), (1000, 200)), σ in (0.1, 1.0), f in (0.02, 0.05, 0.1, 0.3, 0.6), s in 1:3
  global seed += 1; X, y = noisy(n, p, 4, σ, seed); push!(cases, (; id = "ORD-n$(n)p$(p)-s$σ-f$f-$seed", X, y, λ = f * lammax(X, y), fam = "ordinary n>p"))
end
for (n, p) in ((100, 300), (40, 120)), σ in (0.5, 1.0), f in (0.3, 0.5, 0.7, 0.9), s in 1:3
  global seed += 1; X, y = noisy(n, p, 5, σ, seed); push!(cases, (; id = "WID-n$(n)p$(p)-s$σ-f$f-$seed", X, y, λ = f * lammax(X, y), fam = "noisy p>n"))
end
for (n, p, ρ) in ((100, 40, 0.5), (100, 40, 0.9), (60, 150, 0.7)), f in (0.05, 0.2, 0.5), s in 1:3
  global seed += 1; X, y = corr(n, p, 4, 1.0, ρ, seed); push!(cases, (; id = "COR-n$(n)p$(p)-r$ρ-f$f-$seed", X, y, λ = f * lammax(X, y), fam = "correlated"))
end
out = open(joinpath(@__DIR__, "..", "out", "trigger_freq.tsv"), "w")
println(out, join(["id", "fam", "T", "config", "converged", "passes", "capped", "uncertified_stop", "gap", "cert_code_at_end"], '\t'))
for c in cases, T in (Float64, Float32), (cn, ckw) in (("cyclic", (; order = :cyclic, momentum = false)), ("default", (; rng = Xoshiro(3))))
  X, y, λ = T.(c.X), T.(c.y), T(c.λ)
  x, r, _, _ = ps_solve(X, y, λ, zeros(T, size(X, 2)); ckw...)
  capped = !r.converged && r.passes >= 20_000; code, _ = certify_at(X, y, λ, x)
  println(out, join([c.id, c.fam, T, cn, r.converged, r.passes, capped, !r.converged && !capped, r.gap, code], '\t'))
end
close(out)
