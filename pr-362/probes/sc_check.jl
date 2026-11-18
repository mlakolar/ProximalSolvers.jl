# S-C scratch variant (fold of _se_norm/_sumsq_scaled/_se_norm_onepass into the _diff forms) vs BASE: unit-level bit identity
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees_sc.jl"))
using Random
B = BaseMod.ProximalSolvers; S = SCMod.ProximalSolvers
println("Julia ", VERSION)
rng = Xoshiro(10)
same(a, b) = (a === nothing && b === nothing) || (a !== nothing && b !== nothing && a.s === b.s && a.e == b.e)
bad = 0; tot = 0
for (T, D) in ((Float32, Float32), (Float32, Float64), (Float64, Float64)), trial in 1:30000     # (data type, working type W)
  n = rand(rng, (1, 2, 5, 9, 33, 200, 1000))
  k = rand(rng, (T == Float32 ? -149 : -1074):(exponent(floatmax(T)) - 8))
  v = T.(randn(rng, n) .* 2.0^k); w = T.(randn(rng, n) .* 2.0^k)
  r = rand(rng)
  r < 0.03 && (v[rand(rng, 1:n)] = T(NaN)); 0.03 <= r < 0.06 && (v[rand(rng, 1:n)] = T(Inf)); 0.06 <= r < 0.1 && (v .= 0); 0.1 <= r < 0.13 && (v[1] = -zero(T)); 0.13 <= r < 0.16 && (w .= v)
  global tot += 3
  same(B._se_norm(D, v), S._se_norm(D, v)) || (global bad += 1)
  D === T && (same(B._se_norm_diff(T, v, w), S._se_norm(T, v, w)) || (global bad += 1))
  s = sum(abs2, v)
  D === T && (same(B._se_norm_onepass(T, s, v), S._se_norm_onepass(T, s, v)) || (global bad += 1))
  sd = B._sumsq_diff(v, w)
  D === T && (same(B._se_norm_diff_onepass(T, sd, v, w), S._se_norm_onepass(T, sd, v, w)) || (global bad += 1))
end
println("S-C unit bit identity: mismatches ", bad, " of ", tot, " comparisons (NaN, Inf, zero, -0.0, subnormal, huge; Float32 data with Float64 working type included)")
