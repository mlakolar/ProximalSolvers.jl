# Julia 1.10.13 vs 1.13.4: scalar helpers (ldexp/frexp/exponent paths) vs reductions (SIMD width differs: 1.10 targets `goldmont` on this CPU).
using ProximalSolvers, Random, SHA, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
rng = Xoshiro(42)
# _threshold: Float64 and Float32 over ranges, error vs BigFloat in eps(T) of the quotient
function thr_stats(T)
  worst = 0.0; vals = T[]
  for _ in 1:20000
    λ = ldexp(1 + rand(rng), T === Float32 ? rand(rng, -60:60) : rand(rng, -900:900))
    α = ldexp(T(1 + rand(rng)), rand(rng, T === Float32 ? (-100:100) : (-900:900)))
    a = ldexp(T(1 + rand(rng)), rand(rng, T === Float32 ? (-100:100) : (-900:900)))
    v = PS._threshold(T, λ, α, a); push!(vals, v)
    ref = BigFloat(λ) / (BigFloat(α) * BigFloat(a))
    if floatmin(T) <= ref <= floatmax(T) && isfinite(v) && v > 0
      worst = max(worst, Float64(abs(BigFloat(v) - ref) / ref) / eps(T))
    end
  end
  worst, bytes2hex(sha1(reinterpret(UInt8, vals)))[1:12]
end
for T in (Float32, Float64); w, h = thr_stats(T); @printf("%s _threshold: max rel error %.2f eps(T) (normal results); result hash %s\n", T, w, h); end
# _curvature_scale hash
cs = Float64[]
for T in (Float32, Float64), _ in 1:5000
  a = ldexp(T(1 + rand(rng)), rand(rng, T === Float32 ? (-140:127) : (-1070:1023))); s = ldexp(T(1 + rand(rng)), rand(rng, T === Float32 ? (-100:100) : (-900:900)))
  m = PS.LSModel(T[1], reshape(T[1], 1, 1), s)
  push!(cs, Float64(PS._curvature_scale(m, a)))
end
@printf("_curvature_scale result hash %s\n", bytes2hex(sha1(reinterpret(UInt8, cs)))[1:12])
# reductions: bits of the cold column dot and response sums on fixed data
X = randn(Xoshiro(1), Float32, 1000, 8); r = randn(Xoshiro(2), Float32, 1000)
out = Float32[]; for k in 1:8; a, b = PS._column_dot(X, r, k, NaN32); push!(out, a, b); end
@printf("_column_dot (Float32, n=1000) hash %s\n", bytes2hex(sha1(reinterpret(UInt8, out)))[1:12])
X = randn(Xoshiro(1), 1000, 8); r = randn(Xoshiro(2), 1000)
out = Float64[]; for k in 1:8; a, b = PS._column_dot(X, r, k, NaN); push!(out, a, b); end
@printf("_column_dot (Float64, n=1000) hash %s\n", bytes2hex(sha1(reinterpret(UInt8, out)))[1:12])
y = randn(Xoshiro(3), 1000); n = PS._se_norm(Float64, y)
@printf("_se_norm(Float64) = (%.17g, %d); _scaled_norm = %s\n", n.s, n.e, string(PS._scaled_norm(y, 1000)))
@printf("ldexp/exponent/significand checks: %s\n", (ldexp(1.5, -1074), exponent(5e-324), significand(5e-324), frexp(5e-324), ldexp(0.75, -1073), ldexp(1.0, 1024) , ldexp(3.0, -1075)))
