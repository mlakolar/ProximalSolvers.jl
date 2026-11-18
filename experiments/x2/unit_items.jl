# Unit-level evidence for X2 items 1, 2, 3, 4, 5 (BASE vs X2 in one process).
#   julia +lts|+release --project=<WORK>/ps-353 unit_items.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
using Random, LinearAlgebra
B = BaseMod.ProximalSolvers; X = X2Mod.ProximalSolvers
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
rng = Xoshiro(353)
biteq(a, b) = typeof(a) === typeof(b) && isequal(a, b) && (!(a isa AbstractFloat) || signbit(a) == signbit(b))

# ---------------- item 1: _maxabs_diff (BASE) vs norm_diff(x, y, Inf) (X2's _norm_diff) -------------
println("\n== item 1: _maxabs_diff vs _norm_diff(x,y,Inf)")
let bad = 0, tot = 0
  specials(T) = T[0, -0, NaN, Inf, -Inf, floatmin(T), nextfloat(zero(T)), -nextfloat(zero(T)), floatmax(T), -floatmax(T), prevfloat(floatmin(T))]
  for T in (Float32, Float64), n in (0, 1, 2, 3, 7, 8, 9, 31, 100, 1001, 4096), trial in 1:300
    x = randn(rng, T, n); y = randn(rng, T, n)
    if n > 0 && trial % 3 == 0
      for _ in 1:rand(rng, 1:3); x[rand(rng, 1:n)] = rand(rng, specials(T)); y[rand(rng, 1:n)] = rand(rng, specials(T)); end
    end
    trial % 7 == 0 && (x .*= T(2)^rand(rng, -100:100); y .*= T(2)^rand(rng, -100:100))
    a = BaseMod.ProximalSolvers.Blocks._maxabs_diff(x, y); b = X2Mod.ProximalSolvers.Blocks._norm_diff(x, y, Inf)
    tot += 1; biteq(a, b) || (bad += 1; bad < 5 && println("  DIFF $T n=$n: $a vs $b"))
    # views and matrices
    if n >= 4
      xv, yv = view(x, 2:n), view(y, 1:n-1)
      a = BaseMod.ProximalSolvers.Blocks._maxabs_diff(xv, yv); b = X2Mod.ProximalSolvers.Blocks._norm_diff(xv, yv, Inf)
      tot += 1; biteq(a, b) || (bad += 1; println("  DIFF view"))
    end
  end
  for T in (Float32, Float64), _ in 1:50
    M1 = randn(rng, T, 7, 5); M2 = randn(rng, T, 7, 5)
    a = BaseMod.ProximalSolvers.Blocks._maxabs_diff(M1, M2); b = X2Mod.ProximalSolvers.Blocks._norm_diff(M1, M2, Inf)
    tot += 1; biteq(a, b) || (bad += 1; println("  DIFF matrix"))
  end
  println("  cases=$tot mismatches=$bad")
  # type behaviour for mixed element types (not reachable: APG and _se_norm_diff pass both arrays in T)
  x = Float32[1, 2]; y = [1.5, 2.25]
  println("  mixed (Float32, Float64) old: ", BaseMod.ProximalSolvers.Blocks._maxabs_diff(x, y), "  new: ", X2Mod.ProximalSolvers.Blocks._norm_diff(x, y, Inf))
end

# ---------------- item 2: _root_scale -------------------------------------------------------
println("\n== item 2: _root_scale(T, α), BASE vs X2")
function rs(PS, T, α)
  try (r = PS._root_scale(T, α); (r.s, r.e)) catch e; "ERR:" * first(split(sprint(showerror, e), '\n')) end
end
refval(r) = setprecision(() -> ldexp(BigFloat(r[1]), r[2]), BigFloat, 512)
let tot = 0, bad = 0
  # admitted scales: Float32 and Float64 of every exponent (incl. subnormal), fixed-width ints, Bool
  for T in (Float32, Float64)
    for _ in 1:20000
      α = rand(rng, Bool) ? Float64(rand(rng) * 2.0^rand(rng, -1074:1023)) : Float32(rand(rng) * 2.0^rand(rng, -149:127))
      (isfinite(α) && α > 0) || continue
      a, b = rs(B, T, α), rs(X, T, α); tot += 1; a === b || (bad += 1; println("  DIFF ", T, " ", α, " ", a, " ", b))
    end
    for α in (nextfloat(0.0), floatmin(Float64), prevfloat(floatmin(Float64)), floatmax(Float64), nextfloat(0f0), floatmin(Float32), floatmax(Float32), 1.0, 2.0, 0.5, 3.0, 1f0, 0.1, 0.1f0)
      a, b = rs(B, T, α), rs(X, T, α); tot += 1; a === b || (bad += 1; println("  DIFF ", T, " ", α, " ", a, " ", b))
    end
    for α in vcat(Any[Int8(1), Int8(127), UInt8(255), Int16(1000), UInt16(65535), Int32(7), Int32(2^24), UInt32(2^24), Int64(1), Int64(2^24), Int64(2^53), UInt64(2^52), true, 2, 3, 1000],)
      a, b = rs(B, T, α), rs(X, T, α); tot += 1; a === b || (bad += 1; println("  DIFF ", T, " ", repr(α), " ", a, " ", b))
    end
  end
  println("  admitted scale types (Float32, Float64, BitInteger, Bool): cases=$tot mismatches=$bad")
end
println("  Other types, as the existing test (accelerated_pgd.jl:470) uses them and beyond; BASE and X2 values, relative error vs √α in BigFloat(512):")
for (T, α) in ((Float64, BigFloat(2)^-1074 * 3), (Float32, 1.49 * Float64(nextfloat(0f0))), (Float64, 0.5f0), (Float32, BigFloat(10)^30),
               (Float64, BigFloat("0.5012345678901234567"; precision = 256)), (Float64, BigInt(257)), (Float64, 257 // 512), (Float64, true), (Float64, π),
               (Float32, Float16(0.3)), (Float64, BigFloat(0.1)), (Float64, big(0.1) + big(2.0)^-80), (Float64, 1 // 3), (Float64, BigInt(2)^80 + 1),
               (Float64, BigFloat(2)^-1075), (Float64, BigFloat(2)^-1080), (Float64, BigFloat(2)^1100), (Float64, BigFloat(2)^-2000), (Float64, BigFloat(10)^400),
               (Float64, big(2)^70), (Float64, BigInt(10)^400), (Float64, 1 // big(10)^400), (Float64, UInt128(2)^100), (Float64, UInt128(2)^120 + 1))
  a, b = rs(B, T, α), rs(X, T, α)
  ref = α isa Union{Rational} || α isa Integer ? setprecision(() -> sqrt(BigFloat(α)), BigFloat, 512) : setprecision(() -> sqrt(BigFloat(α; precision = 512)), BigFloat, 512)
  relerr(r) = r isa String ? r : (setprecision(() -> Float64(abs(refval(r) / ref - 1)), BigFloat, 512))
  same = a === b
  println("  ", rpad("$T α=$(repr(α))"[1:min(end, 60)], 62), same ? "identical" : "DIFFERENT", "  base: ", relerr(a), "  x2: ", relerr(b))
end
# direct LSModel scale types that reach _root_scale through CD (response_scale -> exceptional)
println("  CD route: LSModel scale types by construction: ", join(unique(string.(typeof.(getfield.([B.LSModel(zeros(Float32,2), ones(Float32,2,1), α) for α in (1.0, 0.5f0, 2, 1//3, big(0.5), Float16(0.5), π)], :s)))), ", "))

# ---------------- item 3: _frobenius_upper ---------------------------------------------------------
println("\n== item 3: _frobenius_upper, BASE vs X2 (=== on the _SE)")
let tot = 0, bad = 0
  for T in (Float32, Float64), trial in 1:4000
    n, p = rand(rng, 1:30), rand(rng, 1:30)
    M = randn(rng, T, n, p)
    trial % 4 == 1 && (M .*= T(2)^rand(rng, -140:120))
    trial % 4 == 2 && T === Float64 && (M .*= 2.0^rand(rng, -1070:1020))
    trial % 11 == 0 && (M .= 0)
    trial % 13 == 0 && (M[rand(rng, 1:n*p)] = rand(rng, T[nextfloat(zero(T)), floatmax(T), floatmin(T), 0, -0.0]))
    a = B._frobenius_upper(T, M); b = X._frobenius_upper(T, M); tot += 1
    (a.s === b.s && a.e == b.e) || (bad += 1; println("  DIFF ", T, " ", a, " ", b))
  end
  println("  cases=$tot mismatches=$bad")
end

# ---------------- item 4: _round_up(T, v) vs T(v, RoundUp) ------------------------------------------
println("\n== item 4: _round_up(T, v) vs T(v, RoundUp)")
old_round_up(::Type{T}, v::Float64) where T = (r = T(v); Float64(r) < v ? nextfloat(r) : r)
let tot = 0, bad = 0
  fixed = Float64[0.0, -0.0, NaN, Inf, -Inf, 5e-324, 1e-320, 2.0^-149, 2.0^-150, 2.0^-151, 1.4e-45, 1.5e-45, 2.0^-126, prevfloat(2.0^-126), nextfloat(2.0^-126),
                1e-300, floatmin(Float64), prevfloat(floatmin(Float64)), 1.0, nextfloat(1.0), prevfloat(1.0), 1e-4, prevfloat(1e-4),
                Float64(floatmax(Float32)), nextfloat(Float64(floatmax(Float32))), Float64(floatmax(Float32)) + 2.0^103, Float64(floatmax(Float32)) + 2.0^104,
                1e39, 1e300, floatmax(Float64), 16777217.0, 16777216.0, 0.1, 1/3]
  for T in (Float32, Float64), v in fixed
    tot += 1; a = old_round_up(T, v); b = T(v, RoundUp)
    biteq(a, b) || (bad += 1; println("  DIFF $T $v: old $a new $b"))
  end
  for T in (Float32, Float64), _ in 1:3_000_000
    v = reinterpret(Float64, rand(rng, UInt64) & ~(UInt64(1) << 63))   # any nonnegative bit pattern incl. NaN payloads, Inf
    rand(rng, Bool) && (v = rand(rng) * 2.0^rand(rng, -170:-120))
    tot += 1; a = old_round_up(T, v); b = T(v, RoundUp)
    biteq(a, b) || isnan(v) && isnan(a) && isnan(b) || (bad += 1; bad < 6 && println("  DIFF $T $v: old $a new $b"))
  end
  # negative values (never passed: ratio ≥ 0), reported for completeness
  negbad = 0
  for T in (Float32, Float64), _ in 1:200_000
    v = -rand(rng) * 2.0^rand(rng, -170:30); a = old_round_up(T, v); b = T(v, RoundUp); biteq(a, b) || (negbad += 1)
  end
  println("  cases=$tot mismatches=$bad  (negative inputs, not reachable: $negbad of 400000 differ)")
  println("  Float64(v, RoundUp) === v for 1e6 random Float64 incl. subnormals: ", all(v -> Float64(v, RoundUp) === v, [reinterpret(Float64, rand(rng, UInt64) & ~(UInt64(1) << 63)) for _ in 1:10^6] |> v -> filter(!isnan, v)))
end

# ---------------- item 5: _flat_column / _flat_group ---------------------------------------------
println("\n== item 5: _flat_column / _flat_group, BASE vs X2")
let tot = 0, bad = 0
  for T in (Float32, Float64)
    vals = T[0, -0.0, NaN, Inf, -Inf, nextfloat(zero(T)), -nextfloat(zero(T)), floatmin(T), 1, -1]
    for trial in 1:5000
      n, p = rand(rng, 1:6), rand(rng, 1:5)
      M = zeros(T, n, p)
      for j in 1:p; rand(rng) < 0.5 && continue; for i in 1:n; rand(rng) < 0.4 && (M[i, j] = rand(rng, vals)); end; end
      y = zeros(T, n)
      mb, mx = B.LSModel(y, M, 1.0), X.LSModel(y, M, 1.0)
      for j in 1:p
        tot += 1; B._flat_column(mb, j) === X._flat_column(mx, j) || (bad += 1; println("  DIFF col"))
      end
      for _ in 1:3
        idx = rand(rng, 1:p, rand(rng, 1:p)); tot += 1
        B._flat_group(mb, idx) === X._flat_group(mx, idx) || (bad += 1; println("  DIFF group"))
        idx = Int32.(idx); tot += 1
        B._flat_group(mb, idx) === X._flat_group(mx, idx) || (bad += 1; println("  DIFF group Int32"))
      end
    end
  end
  println("  cases=$tot mismatches=$bad (-0.0 flat, NaN not flat, subnormal not flat in both)")
  # sparse design: cannot reach solve! (X must be Matrix{T}); direct construction only
  using SparseArrays
  Ms = sparse(Float64[0 1; 0 0; 0 2])
  try
    mb = B.LSModel(zeros(3), Ms, 1.0); mx = X.LSModel(zeros(3), Ms, 1.0)
    println("  sparse X direct LSModel: base flat = ", [B._flat_column(mb, j) for j in 1:2], " x2 flat = ", [X._flat_column(mx, j) for j in 1:2])
  catch e
    println("  sparse X direct LSModel: ", sprint(showerror, e)[1:min(end, 150)])
  end
end
