using ProximalSolvers, Random
const PS = ProximalSolvers
rng = Xoshiro(1)
for T in (Float32, Float64)
  worst = 0.0; N = 0
  for s in (T === Float32 ? (-149:3:127) : (-1074:7:1023)), n in (1, 3, 50, 1000)
    y = T.(ldexp.(randn(rng, n), s)); all(isfinite, y) || continue; all(iszero, y) && continue
    ny, ey = PS._scaled_norm(y, n)
    se = PS._se_norm(Float64, y)
    a = ldexp(ny, ey); b = ldexp(se.s, se.e)
    worst = max(worst, abs(a - b)/a); N += 1
  end
  println(T, ": ", N, " vectors, worst relative difference between _scaled_norm and _se_norm(Float64, v): ", worst)
end
println("zero vector: ", PS._scaled_norm(zeros(3), 3), " vs ", PS._se_norm(Float64, zeros(3)))
