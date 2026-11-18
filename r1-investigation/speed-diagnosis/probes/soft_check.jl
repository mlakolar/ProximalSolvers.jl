# _soft (candidate) against ProximalBase.shrink for every threshold τ ≥ 0: bit equality (NaN equal to any NaN).
include(joinpath(@__DIR__, "irlib.jl"))
using ProximalBase
PS = loadvariant("cand"); soft = PS._soft
same(a, b) = (isnan(a) && isnan(b)) || reinterpret(Base.uinttype(typeof(a)), a) == reinterpret(Base.uinttype(typeof(b)), b)
using Random
for T in (Float16, Float32, Float64)
  sp = T[0, -0.0, nextfloat(zero(T)), -nextfloat(zero(T)), floatmin(T), -floatmin(T), 1, -1, 0.5, 2, floatmax(T), -floatmax(T), Inf, -Inf, NaN, eps(T), 1 + eps(T), prevfloat(T(1))]
  rng = Xoshiro(1); rnd = [reinterpret(T, rand(rng, Base.uinttype(T))) for _ in 1:400]
  vs = vcat(sp, rnd); ts = vcat(filter(t -> !(t < 0) && !(isequal(t, -0.0)), sp), abs.(rnd), T[0.0])  # τ ≥ 0 or NaN, +0
  ts = filter(t -> isnan(t) || signbit(t) == false, ts)
  n = 0; bad = 0
  for v in vs, t in ts
    n += 1; same(soft(v, t), ProximalBase.shrink(v, t)) || (bad += 1; bad <= 5 && println("DIFF ", T, " v=", v, " τ=", t, " soft=", soft(v, t), " shrink=", ProximalBase.shrink(v, t)))
  end
  # random v with random nonneg τ, many pairs
  for _ in 1:1_000_000
    v = reinterpret(T, rand(rng, Base.uinttype(T))); t = abs(reinterpret(T, rand(rng, Base.uinttype(T))))
    n += 1; same(soft(v, t), ProximalBase.shrink(v, t)) || (bad += 1; bad <= 5 && println("DIFF ", T, " v=", v, " τ=", t))
  end
  println(VERSION, " ", T, ": pairs ", n, ", differences ", bad)
end
