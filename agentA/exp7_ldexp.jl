using Random, Printf, ProximalSolvers
const PS = ProximalSolvers
println("Julia ", VERSION)
# (a) ldexp with a subnormal Float64 result: compare to exact (BigFloat) round-to-nearest-even
function exact_ldexp(x::Float64, e::Int)
  setprecision(BigFloat, 256) do
    Float64(big(x) * big(2.0)^e)      # Float64(BigFloat) rounds to nearest even, subnormals included
  end
end
function main()
rng = Xoshiro(1)
bad = 0; N = 0; worst = 0.0; maxulp = 0
for _ in 1:200000
  x = ldexp(1 + rand(rng), rand(rng, -60:60))          # normal Float64
  e = rand(rng, -1080:-1000) - exponent(x)               # result around the subnormal range
  v = ldexp(x, e); w = exact_ldexp(x, e)
  N += 1
  if v != w
    bad += 1
    # distance in units of the smallest subnormal spacing
    d = abs(Int(reinterpret(Int64, v)) - Int(reinterpret(Int64, w)))
    maxulp = max(maxulp, d)
  end
end
println("ldexp(Float64) results in the subnormal range: $bad / $N differ from correct rounding; max difference = $maxulp subnormal spacing(s)")
# (b) same for Float32 -> Float64 data scaled down (the _scaled_norm / offrange pattern: ldexp(Float64(v), -e) with result subnormal)
bad = 0; N = 0
for _ in 1:100000
  x = Float64(rand(rng, Float32)) * 2.0^rand(rng, -100:100)
  iszero(x) && continue
  e = -(rand(rng, 1000:1200)) - exponent(x) + 1000     # push result near/below the normal range
  v = ldexp(x, e); w = exact_ldexp(x, e)
  N += 1; v != w && (bad += 1)
end
println("ldexp with random exponent shifts: $bad / $N differ")
# (c) frexp/exponent on subnormals
bad = 0
for _ in 1:20000
  x = reinterpret(Float64, rand(rng, UInt64(1):UInt64(2)^52 - 1))   # subnormal
  m, e = frexp(x)
  (0.5 <= m < 1 && ldexp(m, e) == x) || (bad += 1)
  exponent(x) == e - 1 || (bad += 1)
end
println("frexp/exponent on subnormal Float64 inconsistent: $bad / 20000")
# (d) level brackets for non-Float64 levels against BigFloat comparisons at 1024 bits
bad = 0; N = 0
setprecision(BigFloat, 1024) do
  levels = Any[π, ℯ, Base.MathConstants.golden, Base.MathConstants.γ, Base.MathConstants.catalan]
  append!(levels, [Rational(rand(rng, 1:10^6), rand(rng, 1:10^6)) for _ in 1:2000])
  append!(levels, [BigFloat(rand(rng))^3 + big"1e-30" for _ in 1:500])
  append!(levels, [Float16(rand(rng)) + Float16(0.001) for _ in 1:100])
  for λ in levels
    lo, hi = PS._level_brackets(λ)
    N += 1
    exact = λ isa Irrational ? BigFloat(λ) : λ isa Rational ? big(numerator(λ))/big(denominator(λ)) : big(λ)
    (isfinite(lo) && big(lo) <= exact <= big(hi)) || (bad += 1)
  end
end
println("_level_brackets: $bad / $N brackets violate the exact bracket property (BigFloat 1024)")

end
main()
