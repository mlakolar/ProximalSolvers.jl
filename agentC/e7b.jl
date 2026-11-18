include(joinpath(@__DIR__, "common.jl"))
rng = Xoshiro(7)
sub(T) = T == Float32 ? -149 : -1074
for T in (Float32, Float64)
  emax = exponent(floatmax(T)); u = unit(T)
  cats = Dict{String, Int}()
  tot = Dict{String, Int}()
  for trial in 1:4000
    n = rand(rng, (1, 2, 3, 8, 17, 100, 1000, 5000))
    k = rand(rng, (sub(T)+3):(emax - 6))
    a = rscale(rng, T, n, k)
    b = trial % 3 == 0 ? T.(Float64.(a) .+ randn(rng, n) .* 2.0^(k - rand(rng, 1:20))) : rscale(rng, T, n, k - rand(rng, 0:2))
    all(isfinite, a) && all(isfinite, b) || continue
    δ = gam(T, n + 4); ed = bnormdiff(a, b)
    v = PB.norm_diff(a, b)
    isfinite(v) || continue
    iszero(ed) && continue
    ok = abs(BF(v) / ed - 1) <= δ * 1.5
    cat = ed < BF(floatmin(T)) ? "norm < floatmin (subnormal T result)" : ed > BF(floatmax(T)) / 2 ? "norm near/above floatmax" : "normal"
    tot[cat] = get(tot, cat, 0) + 1
    ok || (cats[cat] = get(cats, cat, 0) + 1)
  end
  println(T, " failures by class: ", cats, "   totals: ", tot)
end
