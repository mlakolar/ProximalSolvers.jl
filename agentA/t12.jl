using ProximalSolvers, ProximalBase, Random
const PS = ProximalSolvers
rng = Xoshiro(1)
for T in (Float32, Float64)
  worst = 0.0; nbad = 0
  for s in (T === Float32 ? (-148:4:127) : (-1070:20:1020)), n in (1, 5, 100, 1000)
    y = T.(ldexp.(randn(rng, n), s))
    all(isfinite, y) || continue
    ny, ey = PS._scaled_norm(y, n)
    ref = ldexp(ny, ey)
    v = Float64(ProximalBase.NormL2(one(T))(y))
    if iszero(ref) && iszero(v); continue; end
    rel = abs(v - ref)/ref
    isfinite(rel) || (nbad += 1; println(T, " s=", s, " n=", n, " scaled_norm=", ref, " NormL2=", v); continue)
    worst = max(worst, rel)
  end
  println(T, " worst rel diff NormL2 vs _scaled_norm: ", worst, "  (nonfinite/zero mismatches: ", nbad, ")")
end
