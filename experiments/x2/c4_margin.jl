# X3 item 8 (C4): the one-sided property  ℓ = nextfloat(a(1 + 2n eps)) >= exact Σx²  for the sums Julia uses.
#   julia +lts|+release --project=<WORK>/ps-353 c4_margin.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
using Random, LinearAlgebra
B = BaseMod.ProximalSolvers; X3 = X3Mod.ProximalSolvers
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
rng = Xoshiro(8)
exact(v) = setprecision(() -> sum(abs2, BigFloat.(v)), BigFloat, 300)       # products of floats are exact in 300 bits for Float32/Float64 sums of ≤ 2^20 terms of moderate range
function simdsum(v::AbstractVector{T}) where T       # the loop of _column_dot (a += X*X)
  a = zero(T)
  @inbounds @simd for i in eachindex(v)
    a += v[i] * v[i]
  end
  a
end
function seqsum(v::AbstractVector{T}) where T         # the former _sqnorm! loop (in order)
  a = zero(T)
  @inbounds for i in eachindex(v)
    a += v[i] * v[i]
  end
  a
end
ell(a::T, n) where T = nextfloat(a * (one(T) + 2n * eps(T)))
function columns(T, n)
  c = Pair{String, Vector{T}}[]
  push!(c, "randn" => randn(rng, T, n))
  push!(c, "constant 1+3eps" => fill(one(T) + 3eps(T), n))
  push!(c, "constant 1.5" => fill(T(1.5), n))
  push!(c, "constant 1/sqrt(3)" => fill(T(1 / sqrt(3)), n))
  push!(c, "wide range 2^[-30,30]" => randn(rng, T, n) .* T.(2.0 .^ rand(rng, -30:30, n)))
  push!(c, "one big + many small" => (v = ones(T, n); v[1] = T(2)^((T === Float32 ? 12 : 26)); v))
  push!(c, "geometric decay" => T.(0.9999 .^ (0:n-1)))
  push!(c, "geometric growth" => T.(1.0001 .^ (0:n-1) ./ 1.0001^n))
  lo = T === Float32 ? -65 : -520
  push!(c, "squares subnormal (|x|~2^$(lo))" => randn(rng, T, n) .* T(2)^lo)
  push!(c, "squares straddling floatmin" => randn(rng, T, n) .* T(2)^(T === Float32 ? -63 : -511) .* T.(2.0 .^ rand(rng, -3:3, n)))
  push!(c, "tiny entries, one normal" => (v = randn(rng, T, n) .* T(2)^(lo - 5); v[rand(rng, 1:n)] = T(2)^(T === Float32 ? -62 : -510); v))
  push!(c, "alternating magnitudes" => T.(repeat([1.0, 2.0^-12], cld(n, 2))[1:n]))
  push!(c, "all ones" => ones(T, n))
  push!(c, "descending |randn|" => sort(abs.(randn(rng, T, n)); rev = true))
  push!(c, "ascending |randn|" => sort(abs.(randn(rng, T, n))))
  push!(c, "big + smalls just below a half-ulp of the big square" => (v = fill(T(0.999), n); v[1] = T(2)^((T === Float32 ? 12 : 26)); v))
  push!(c, "big + smalls just above a half-ulp" => (v = fill(T(1.0001), n); v[1] = T(2)^((T === Float32 ? 12 : 26)); v))
  push!(c, "two big at both ends + smalls" => (v = ones(T, n); v[1] = T(2)^((T === Float32 ? 12 : 26)); v[end] = v[1]; v))
  c
end
for T in (Float32, Float64)
  ns = T === Float32 ? (1, 2, 3, 7, 33, 100, 1000, 4096, 10^4, 10^5, 2^20) : (1, 2, 3, 7, 100, 1000, 10^4, 10^5, 2^20)
  tot = 0; viol = Dict("seq" => 0, "base-sum" => 0, "simd" => 0, "production(X3._singleton_curvature)" => 0)
  consumed = Dict(k => 0.0 for k in keys(viol)); cworst = Dict(k => "" for k in keys(viol)); refused = 0; minslack = Dict(k => Inf for k in keys(viol)); worst = Dict(k => "" for k in keys(viol))
  for n in ns, (nm, v) in columns(T, n)
    all(isfinite, v) || continue
    ex = exact(v)
    for (name, a) in (("seq", seqsum(v)), ("base-sum", sum(abs2, view(reshape(v, :, 1), :, 1))), ("simd", simdsum(v)))
      (a < floatmin(T) || !isfinite(a)) && (name == "seq" && (refused += 1); continue)
      l = ell(a, n)
      isfinite(l) || continue
      tot += 1
      cons = Float64((ex - BigFloat(a)) / (BigFloat(a) * 2n * eps(T)))   # fraction of the margin 2n eps used by the computed sum (negative: overestimate)
      cons > consumed[name] && (consumed[name] = cons; cworst[name] = "$nm n=$n")
      slack = Float64((BigFloat(l) - ex) / ex)
      slack < minslack[name] && (minslack[name] = slack; worst[name] = "$nm n=$n")
      BigFloat(l) >= ex || (viol[name] += 1; println("  VIOLATION $T $name $nm n=$n  l=$l exact=$(Float64(ex)) slack=$slack"))
    end
    # production path: ls model + _singleton_curvature (n eps ≤ 1/8 is the route's own condition)
    if n * eps(T) <= 1 / 8
      ls = X3.LSModel(zeros(T, n), reshape(copy(v), n, 1), 1.0)
      l = try X3._singleton_curvature(ls, 1, 1) catch e; nothing end
      if l !== nothing
        tot += 1
        slack = Float64((BigFloat(l) - ex) / ex)
        k = "production(X3._singleton_curvature)"
        slack < minslack[k] && (minslack[k] = slack; worst[k] = "$nm n=$n")
        BigFloat(l) >= ex || (viol[k] += 1; println("  VIOLATION production $T $nm n=$n l=$l exact=$(Float64(ex))"))
      end
    end
  end
  println("$T: checks=$tot (columns refused as underflow/overflow: $refused of sequential sums); violations: ", join(["$k=$v" for (k, v) in viol], ", "))
  println("    largest fraction of the margin 2n eps consumed by the underestimate (exact − a)/(a 2n eps): ", join(["$k: $(round(consumed[k], sigdigits = 3)) [$(cworst[k])]" for k in keys(viol) if k != "production(X3._singleton_curvature)"], "; "))
  println("    min slack (ℓ/exact − 1): ", join(["$k: $(round(minslack[k], sigdigits = 3)) [$(worst[k])]" for k in keys(viol)], "; "))
end
# the factor 2n eps is exact in T and the margin is far above the worst-case bound? print the margin as a multiple of n u
println("\nmargin 2n eps(T) relative to the worst-case recursive bound γ_n ≈ n eps/2 is a factor ~4 (Float32 n=2^20: 2n eps = ", 2 * 2^20 * eps(Float32), ")")
