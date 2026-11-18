# Is PB's exported `shrink` slower than its private `_shrink_nonneg` in a caller-shaped scalar chain? (#353, X1)
using ProximalBase, Printf
@noinline function chain(f::F, c::Vector{T}, τ::Vector{T}, reps) where {F, T}
  acc = zero(T)
  for _ in 1:reps
    @inbounds for i in eachindex(c)
      acc += f(c[i] + acc*T(1e-3), τ[i])      # loop-carried dependence, as in a CD visit sequence
    end
  end
  acc
end
for T in (Float64, Float32)
  c = T.(randn(1000)); τ = T.(abs.(randn(1000)) .* 0.5)
  fs = (("shrink", ProximalBase.shrink), ("_shrink_nonneg", ProximalBase._shrink_nonneg), ("select", (v, t) -> v > t ? v - t : v < -t ? v + t : zero(v)))
  for (nm, f) in fs; chain(f, c, τ, 1); end
  res = Dict{String, Float64}()
  for r in 1:5, (nm, f) in fs
    t = minimum(begin t0 = time_ns(); chain(f, c, τ, 200); (time_ns() - t0)/200_000 end for _ in 1:7)
    res[nm] = min(get(res, nm, Inf), t)
  end
  same = all(ProximalBase.shrink(a, b) === ProximalBase._shrink_nonneg(a, b) for (a, b) in zip(c, τ))
  @printf("%s %s: shrink %.2f ns, _shrink_nonneg %.2f ns, select %.2f ns per call (same values: %s)\n", VERSION, T, res["shrink"], res["_shrink_nonneg"], res["select"], same)
end
