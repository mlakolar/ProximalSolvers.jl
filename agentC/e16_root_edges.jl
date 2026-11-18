include(joinpath(@__DIR__, "common.jl"))
println("E16 _root_scale: BigFloat route vs Float64 route on every scale type that _check_loss_scale accepts; edge cases. julia ", VERSION)
rng = Xoshiro(16)
function root_f64(::Type{T}, α) where {T}      # the proposed single route
  a = Float64(α); s, e = Float64(significand(a)), exponent(a)
  if isodd(e); s *= 2; e -= 1; end
  r = PS._SE{T}(sqrt(s)); PS._SE{T}(r.s, r.e + e ÷ 2)
end
bad = 0; tot = 0
for T in (Float32, Float64)
  αs = Any[true, 1, 2, 3, 7, 255, Int8(5), UInt8(200), Int16(1000), Int32(123456), UInt32(4000000000), 2^20, 3 * 2^30, Int64(2)^40, Int64(2)^53, UInt64(2)^60, Int128(2)^70, Bool(1)]
  for _ in 1:2000; push!(αs, T(2.0)^rand(rng, -100:100) * T(1 + rand(rng))); push!(αs, 2.0^rand(rng, -1000:1000) * (1 + rand(rng))); end
  for α in αs
    # accepted by _check_loss_scale: Float32/Float64 finite positive with a finite nonzero T conversion; integers exactly representable in T
    if α isa Union{Float32, Float64}
      c = T(α); (isfinite(α) && α > 0 && isfinite(c) && c > 0) || continue
    else
      α > 0 && T(α) == α || continue
    end
    global tot += 1
    r1, r2 = PS._root_scale(T, α), root_f64(T, α)
    (r1.s === r2.s && r1.e == r2.e) || (global bad += 1)
  end
end
println("  _root_scale vs single Float64 route: mismatches $bad of $tot accepted scales")
# edge cases of the norm helpers
for T in (Float32, Float64)
  big = floatmax(T)
  println("  $T: _se_norm_diff overflowing difference -> ", PS._se_norm_diff(T, [big], [-big]), "; NaN -> ", PS._se_norm_diff(T, [T(NaN)], [T(1)]), "; Inf -> ", PS._se_norm_diff(T, [T(Inf)], [T(1)]), "; _se_norm(floatmax,floatmax) exponent: ", PS._se_norm(T, [big, big]).e, " (finite as SE)")
end
