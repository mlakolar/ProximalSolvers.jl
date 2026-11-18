include(joinpath(@__DIR__, "common.jl"))
println("E12 PB private _parts_product vs _se_mul; PB master identical? julia ", VERSION)
rng = Xoshiro(12)
for T in (Float32, Float64)
  bad = 0; n = 100000
  for _ in 1:n
    a = PS._SE{T}(min(rand(rng, T) + 1, prevfloat(T(2))), rand(rng, -3000:3000)); b = PS._SE{T}(min(rand(rng, T) + 1, prevfloat(T(2))), rand(rng, -3000:3000))
    r = PS._se_mul(a, b)
    m, e = PB._parts_product((a.s / 2, a.e + 1), (b.s / 2, b.e + 1))       # PB parts have the significand in [1/2, 1)
    # same value: m 2^e == r.s 2^r.e exactly?
    (BF(m) * BF(2)^e == se2big(r)) || (bad += 1)
  end
  println("  $T: _parts_product == _se_mul (as exact values) mismatches: $bad of $n")
end
println("  PB names present: ", [s for s in (:_parts, :_parts_product, :_ExpSum, :_expsum_add, :_scaled_product, :_scaled_norm, :_frexp) if isdefined(PB, s)])
println("  exported/public numerical API of PB: norm_diff, shrink, opnorm2 (", isdefined(PB, :norm_diff), isdefined(PB, :shrink), isdefined(PB, :opnorm2), "); extended-range type: ", any(n -> occursin(r"(?i)extended|exp.*range|scaledfloat|_SE\b", String(n)), names(PB; all = true)))
