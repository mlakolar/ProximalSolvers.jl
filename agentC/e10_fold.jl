# Prototype (disposable): fold _se_norm/_sumsq_scaled into _se_norm_diff/_sumsq_scaled_diff with a zero operand, and
# _frobenius_upper's first loop into _sumsq64. Checks bit-identity against the real functions.
include(joinpath(@__DIR__, "common.jl"))
println("E10 fold prototypes, julia ", VERSION)
struct _ZeroVec end
Base.getindex(::_ZeroVec, i) = false
function sumsq_scaled_diff2(a, b, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(a)
    s += abs2((a[i] - b[i]) / m)
  end
  s
end
maxabs_diff2(x::AbstractArray{T}, y) where {T} = (m = zero(T); @inbounds @simd for i in eachindex(x); m = max(m, abs(x[i] - y[i])); end; m)
function se_norm_diff2(::Type{T}, a, b) where {T}
  m = maxabs_diff2(a, b)
  isfinite(m) || return nothing
  iszero(m) && return PS._se_zero(T)
  s = sumsq_scaled_diff2(a, b, T(m))
  isfinite(s) || return nothing
  PS._se_mul(PS._SE{T}(m), PS._SE{T}(sqrt(s)))
end
se_norm2(T, v) = se_norm_diff2(T, v, _ZeroVec())
same(a, b) = (a === nothing && b === nothing) || (a !== nothing && b !== nothing && a.s === b.s && a.e == b.e)
function fro_loop(X)
  s = 0.0
  @inbounds @simd for i in eachindex(X)
    s += abs2(Float64(X[i]))
  end
  s
end
rng = Xoshiro(10)
bad = 0; tot = 0
for T in (Float32, Float64), trial in 1:20000
  n = rand(rng, (1, 2, 5, 9, 33, 200))
  k = rand(rng, (T == Float32 ? -149 : -1074):(exponent(floatmax(T)) - 8))
  v = T.(randn(rng, n) .* 2.0^k)
  r = rand(rng)
  r < 0.03 && (v[rand(rng, 1:n)] = T(NaN)); 0.03 <= r < 0.06 && (v[rand(rng, 1:n)] = T(Inf)); 0.06 <= r < 0.1 && (v .= 0); 0.1 <= r < 0.13 && (v[1] = -zero(T))
  global tot += 1
  same(PS._se_norm(T, v), se_norm2(T, v)) || (global bad += 1)
  # onepass fallback equivalence
  s = sum(abs2, v)
  same(PS._se_norm_onepass(T, s, v), (isfinite(s) && s >= 4 * length(v) * floatmin(T)) ? PS._SE{T}(sqrt(s)) : se_norm2(T, v)) || (global bad += 1)
  w = T.(randn(rng, n) .* 2.0^k)
  same(PS._se_norm_diff(T, v, w), se_norm_diff2(T, v, w)) || (global bad += 1)
end
println("  _se_norm via zero operand: mismatches ", bad, " of ", tot * 3, " comparisons")
# _frobenius_upper's one-pass loop vs _sumsq64
bad2 = 0
for T in (Float32, Float64), trial in 1:2000
  n, p = rand(rng, 1:40), rand(rng, 1:40); X = T.(randn(rng, n, p) .* 2.0^rand(rng, -20:20))
  s1 = fro_loop(X)
  s2 = PS._sumsq64(X)
  s1 === s2 || (global bad2 += 1)
end
println("  _frobenius_upper loop vs _sumsq64: mismatches ", bad2, " of 4000")
