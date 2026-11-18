# Equivalence checks of small helper pairs.
using ProximalBase, ProximalSolvers, Random
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
rng = MersenneTwister(7)

# 1. PS _clean_sum vs PB _squares_normal (+ isfinite)
let bad = 0, tot = 0
  for T in (Float32, Float64)
    vals = T[0, nextfloat(zero(T)), floatmin(T)/2, floatmin(T), floatmin(T)/eps(T), 3floatmin(T)/eps(T), one(T), floatmax(T), T(Inf), T(NaN), -one(T)]
    for _ in 1:2000; push!(vals, T(2)^rand(rng, -140:140)*rand(rng,T)); end
    for s in vals, n in (1, 2, 17, 4096, 10^6)
      a = PS._clean_sum(s, n); b = isfinite(s) && PB._squares_normal(s, n, T)
      c = PB._squares_normal(s, n, T)
      tot += 1; a == b || (bad += 1)
      (a != c) && s == T(Inf) || a == c || println("DIFF other than Inf: ", T, " ", s, " ", n)
    end
  end
  println("1. _clean_sum vs isfinite&&_squares_normal: ", bad, " disagreements of ", tot, "  (differs from _squares_normal alone only at s=+Inf)")
end

# 2. PS _round_up(T, v) vs Base T(v, RoundUp)
let bad = 0, tot = 0
  vs = Float64[0.1, 1/3, 2.0^-149, 2.0^-150, 2.0^-151, 3.4028234663852886e38, 3.4028235677973366e38, nextfloat(Float64(floatmax(Float32))), 1.0, 0.0, 5e-46, 1e-46]
  for _ in 1:20000; push!(vs, 2.0^rand(rng,-160:127)*rand(rng)); end
  for v in vs
    isfinite(v) || continue
    v <= floatmax(Float32) || continue
    for T in (Float32, Float64)
      a = PS._round_up(T, v); b = T(v, RoundUp)
      tot += 1; isequal(a, b) || (bad += 1; bad < 5 && println("  DIFF ", T, " ", v, " ", a, " ", b))
    end
  end
  println("2. _round_up vs Base T(v, RoundUp): ", bad, " disagreements of ", tot)
end

# 3. PS _SE arithmetic vs PB scaled-product kernel / _ExpSum
setprecision(BigFloat, 512)
sebig(a) = iszero(a.s) ? BigFloat(0) : ldexp(BigFloat(a.s), a.e)
let
  # 3a: _se_mul in range equals PB._scaled_product bitwise?
  same = 0; tot = 0; maxrel = 0.0
  for T in (Float32, Float64), _ in 1:5000
    a = rand(rng, T)*T(2)^rand(rng, -20:20); b = rand(rng, T)*T(2)^rand(rng, -20:20)
    p = PS._se_mul(PS._SE{T}(a), PS._SE{T}(b))
    v1 = ldexp(p.s, p.e); v2 = PB._scaled_product(a, b, 0)
    tot += 1; same += (v1 == v2)
  end
  println("3a. in-range _se_mul vs PB._scaled_product(a,b,0): bitwise equal ", same, "/", tot)
  # 3b: out of range: _SE keeps exponent, PB returns Inf/0
  a = 2.0^900; b = 2.0^900
  p = PS._se_mul(PS._SE{Float64}(a), PS._SE{Float64}(b))
  println("3b. 2^900*2^900: _se_mul -> (", p.s, ", ", p.e, ")   PB._scaled_product(a,b,0) = ", PB._scaled_product(a, b, 0), "  (a*b = ", a*b, ")")
  q = PB._scaled_product(a, b, 1.0, -1700)
  println("    PB._scaled_product(a,b,1,-1700) = ", q, " = 2^", log2(q), " (power k supplied by the caller; no value carries an exponent)")
  # 3c: _se_add vs _ExpSum accumulate (positive terms): accuracy against BigFloat, direction
  for T in (Float32, Float64)
    errse = Float64[]; errexp = Float64[]; below_se = 0; below_exp = 0; N=3000
    for _ in 1:N
      k = 6
      ms = rand(rng, T, k) .+ one(T); es = rand(rng, -3000:3000, k)
      ref = sum(ldexp(BigFloat(ms[i]), es[i]) for i in 1:k)
      acc = PS._se_zero(T); for i in 1:k; acc = PS._se_add(acc, PS._SE{T}(ms[i]*T(1)) |> x->PS._SE{T}(x.s, x.e + es[i])); end
      se = sebig(acc)
      ea = PB._expsum_start(T); for i in 1:k; ea = PB._expsum_add(ea, ms[i]/2, es[i]+1); end   # significand m/2 in [1/2,1), exponent e+1
      ev = ldexp(BigFloat(ea.s + ea.c), ea.ex)
      push!(errse, Float64(abs(se-ref)/ref)); push!(errexp, Float64(abs(ev-ref)/ref)); below_se += se < ref; below_exp += ev < ref
    end
    u = Float64(eps(T))/2
    println("3c. $T sum of 6 positive terms (exponents spread over ±3000): _se_add max rel err = ", round(maximum(errse)/u, digits=2), "u (below ", round(below_se/N, digits=2), ");  PB _ExpSum max = ", round(maximum(errexp)/u, digits=2), "u (below ", round(below_exp/N, digits=2), ")")
  end
  # 3d: which PB primitive offers comparison / difference-with-floor / product of extended numbers? grep-level fact
end
println("4. PB functions with the names _se_le/_se_sub/_se_mul-like (extended-range compare/sub): ",
  [n for n in names(PB; all=true) if occursin(r"^_(se|ext|xfloat)", String(n))])
