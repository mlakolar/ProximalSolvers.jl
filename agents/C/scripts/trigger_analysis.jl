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

fired = Set(split(l, '\t')[1] for l in readlines(joinpath(@__DIR__, "..", "out", "trigger_freq.tsv"))[2:end] if split(l, '\t')[8] == "true")
out = open(joinpath(@__DIR__, "..", "out", "trigger_fired_analysis.tsv"), "w")
println(out, join(["id", "T", "config", "stuck_passes", "stuck_excess", "stuck_nnz", "n", "p", "rstar_rel", "H_fix1_certified", "H_passes", "H_nstages", "H_secs", "H_excess"], '\t'))
for c in cases
  c.id in fired || continue
  for T in (Float64, Float32)
    rec = oracle_for(c.X, c.y, c.λ, T); X, y, λ = T.(c.X), T.(c.y), T(c.λ)
    for (cn, ckw) in (("cyclic", (; order = :cyclic, momentum = false)),)
      x, r, sec, _ = ps_solve(X, y, λ, zeros(T, size(X, 2)); ckw...)
      r.converged && continue
      ex = Float64((Pbig(X, y, λ, x) - big(rec.D)) / big(rec.D))
      f = fallback2(X, y, λ, x; sched = :track, c = 1.0, step = 1.0, stages = 16)
      Pr = Pbig(X, y, λ, f.β)
      println(out, join([c.id, T, cn, r.passes, ex, count(!iszero, x), size(X, 1), size(X, 2), rec.rrel, f.certified, f.passes, f.nstages, f.secs, Float64((Pr - big(rec.D)) / big(rec.D))], '\t')); flush(out)
    end
  end
end
close(out)
