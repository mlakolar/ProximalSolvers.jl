# The scaled-norm helpers of the head against the base's four functions, in one process. At the head before
# the fold the base names exist too, so the head side picks whichever form it defines.
const HERE = @__DIR__
include(joinpath(HERE, "loader.jl"))
using Random
B = BaseMod.ProximalSolvers; S = X2Mod.ProximalSolvers
println("Julia ", VERSION)
folded = !isdefined(S, :_se_norm_diff)
println("head folded: ", folded)
hnorm(D, v) = S._se_norm(D, v)
hdiff(T, v, w) = folded ? S._se_norm(T, v, w) : S._se_norm_diff(T, v, w)
honep(T, s, v) = S._se_norm_onepass(T, s, v)
hdonep(T, s, v, w) = folded ? S._se_norm_onepass(T, s, v, w) : S._se_norm_diff_onepass(T, s, v, w)
function tryit(f)
  try f() catch e; "ERR:" * first(split(sprint(showerror, e), '\n')) end
end
same(a, b) = (a === nothing && b === nothing) || (a isa String && a == b) ||
  (a !== nothing && b !== nothing && !(a isa String) && !(b isa String) && a.s === b.s && a.e == b.e)
rng = Xoshiro(10)
bad = 0; tot = 0
function gen(rng, T, shape)
  n = prod(shape)
  k = rand(rng, (T == Float32 ? -149 : -1074):(exponent(floatmax(T)) - 8))
  mk() = T.(randn(rng, n) .* 2.0^k)
  v = mk(); w = mk()
  if rand(rng) < 0.15       # entries of mixed scale
    sp = T == Float32 ? 100 : 1000
    v .= T.(Float64.(v) .* 2.0 .^ rand(rng, -sp:sp, n)); w .= T.(Float64.(w) .* 2.0 .^ rand(rng, -sp:sp, n))
  end
  r = rand(rng)
  r < 0.03 && (v[rand(rng, 1:n)] = T(NaN)); 0.03 <= r < 0.05 && (w[rand(rng, 1:n)] = T(NaN))
  0.05 <= r < 0.08 && (v[rand(rng, 1:n)] = T(Inf)); 0.08 <= r < 0.10 && (w[rand(rng, 1:n)] = -T(Inf))
  0.10 <= r < 0.14 && (v .= 0); 0.14 <= r < 0.16 && (w .= 0); 0.16 <= r < 0.18 && (v[1] = -zero(T))
  0.18 <= r < 0.22 && (w .= v)
  0.22 <= r < 0.25 && (v[rand(rng, 1:n)] = nextfloat(zero(T)))
  0.25 <= r < 0.28 && (v[rand(rng, 1:n)] = floatmax(T); w[rand(rng, 1:n)] = -floatmax(T))
  0.28 <= r < 0.30 && (v[rand(rng, 1:n)] = floatmax(T); w[rand(rng, 1:n)] = floatmax(T))   # a - b may overflow? sign random
  reshape(v, shape), reshape(w, shape)
end
for (T, D) in ((Float32, Float32), (Float32, Float64), (Float64, Float64)), trial in 1:30000
  shape = rand(rng) < 0.3 ? (rand(rng, (1, 2, 3, 7)), rand(rng, (1, 2, 5, 30))) : (rand(rng, (0, 1, 2, 5, 9, 33, 200, 1000)),)
  prod(shape) == 0 && (shape = (0,))
  if prod(shape) == 0
    v = T[]; w = T[]
  else
    v, w = gen(rng, T, shape)
  end
  global tot += 1; same(tryit(() -> B._se_norm(D, v)), tryit(() -> hnorm(D, v))) || (global bad += 1; bad < 5 && println("DIFF norm ", T, D, size(v)))
  D === T || continue
  global tot += 1; same(tryit(() -> B._se_norm_diff(T, v, w)), tryit(() -> hdiff(T, v, w))) || (global bad += 1; bad < 5 && println("DIFF diff ", T, size(v)))
  s = sum(abs2, v)
  global tot += 1; same(tryit(() -> B._se_norm_onepass(T, s, v)), tryit(() -> honep(T, s, v))) || (global bad += 1; bad < 5 && println("DIFF onepass"))
  sd = isempty(v) ? zero(T) : B._sumsq_diff(v, w)
  global tot += 1; same(tryit(() -> B._se_norm_diff_onepass(T, sd, v, w)), tryit(() -> hdonep(T, sd, v, w))) || (global bad += 1; bad < 5 && println("DIFF diff onepass"))
  # one-pass with a forced non-finite or small s
  for s2 in (T(Inf), T(NaN), zero(T), floatmin(T), T(4) * length(v) * floatmin(T), prevfloat(T(4) * length(v) * floatmin(T)))
    global tot += 2
    same(tryit(() -> B._se_norm_onepass(T, s2, v)), tryit(() -> honep(T, s2, v))) || (global bad += 1; bad < 5 && println("DIFF onepass s2 ", s2))
    same(tryit(() -> B._se_norm_diff_onepass(T, s2, v, w)), tryit(() -> hdonep(T, s2, v, w))) || (global bad += 1; bad < 5 && println("DIFF diff onepass s2 ", s2))
  end
end
println("fold check: mismatches ", bad, " of ", tot, " comparisons (vectors and matrices; NaN, Inf, zero, -0.0, subnormal, huge, mixed-scale, a == b; Float32 data with Float64 working type included)")
