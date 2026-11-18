include(joinpath(@__DIR__, "common.jl"))
println("E3 _root_scale on julia ", VERSION)
rng = Xoshiro(3)
# requirement: √α_exact (α as given) within a relative error that the κ = 32u budget absorbs. Report the error in units of u_T.
function alphas()
  out = Any[]
  for k in -1074:97:1023
    push!(out, 2.0^k * (1 + rand(rng)))
  end
  for k in -149:11:127
    push!(out, Float32(2.0)^k * Float32(1 + rand(rng)))
  end
  push!(out, 1.0, 0.5, 2.0, 3.0, 1e-300, 1e300, 5e-324, floatmax(Float64), nextfloat(0.0f0), floatmax(Float32), 7, 1//3, big"1e400", BF(2)^-5000 * 3, true, BF(3)/7, pi, Float16(0.3))
  out
end
for T in (Float32, Float64)
  t = Tally("$T √α: relative error / u_T (budget: 32u covers it with the SE-op count)")
  for α in alphas()
    αb = α isa Irrational ? BF(α) : α isa Rational ? BF(numerator(α)) / BF(denominator(α)) : BF(α)
    (αb > 0 && isfinite(αb)) || continue
    r = PS._root_scale(T, α)
    ex = sqrt(αb)
    err = Float64(abs(se2big(r) / ex - 1) / unit(T))
    rec!(t, err <= 3, err)    # expected ≈ ≤ 1.5u_T + 2^-53
  end
  report(t)
end
