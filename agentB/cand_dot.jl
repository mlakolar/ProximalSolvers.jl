# Candidate C1: derive LS `_column_dot` from sqrt's fused `_column_dot_rsqr` (3 outputs) and rely on dead-code elimination of the
# unused ρ² accumulator. Exact copies of the two production kernels; caller-shaped loops; old/new/control in one process.
module Probe
using Random, Printf
@inline function _column_dot(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, a::T) where T
  b = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      a += X[i, k]*X[i, k]
      b += r[i]*X[i, k]
    end
  else
    @inbounds @simd for i in eachindex(r)
      b += r[i]*X[i, k]
    end
  end
  a, b
end
@inline function _column_dot_rsqr(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, a::T) where T
  b = zero(T)
  ρ2 = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      v, ri = X[i, k], r[i]
      a += v*v
      b += ri*v
      ρ2 += ri*ri
    end
  else
    @inbounds @simd for i in eachindex(r)
      v, ri = X[i, k], r[i]
      b += ri*v
      ρ2 += ri*ri
    end
  end
  a, b, ρ2
end
@inline _column_dot_new(X, r, k, a) = (t = _column_dot_rsqr(X, r, k, a); (t[1], t[2]))
# caller-shaped: a pass over all columns with the cache warm (a given) or cold (NaN)
function pass_old(X, r, A, acc)
  s = zero(eltype(r))
  for k in 1:size(X, 2)
    a, b = _column_dot(X, r, k, A[k]); s += b + a*0
  end
  s
end
function pass_new(X, r, A, acc)
  s = zero(eltype(r))
  for k in 1:size(X, 2)
    a, b = _column_dot_new(X, r, k, A[k]); s += b + a*0
  end
  s
end
pass_ctl(X, r, A, acc) = pass_old(X, r, A, acc)   # control: the same code under another name
function bench(f, X, r, A; reps)
  f(X, r, A, 0); best = Inf
  for _ in 1:5
    t = @elapsed for _ in 1:reps; f(X, r, A, 0); end
    best = min(best, t/reps)
  end
  best
end
function main()
  for T in (Float32, Float64), (n, p) in ((20, 20), (100, 50), (1000, 50), (10000, 20))
    rng = Xoshiro(1); X = randn(rng, T, n, p); r = randn(rng, T, n)
    for (cache, A) in (("warm", fill(T(n), p)), ("cold", fill(T(NaN), p)))
      bo = pass_old(X, r, A, 0); bn = pass_new(X, r, A, 0)
      same = bo === bn
      reps = max(20, 2_000_000 ÷ (n*p))
      # interleave: old, new, ctl, old, new, ctl
      to = Float64[]; tn = Float64[]; tc = Float64[]
      for _ in 1:4
        push!(to, bench(pass_old, X, r, A; reps)); push!(tn, bench(pass_new, X, r, A; reps)); push!(tc, bench(pass_ctl, X, r, A; reps))
      end
      @printf("%s n=%-6d p=%-3d %s: bit-identical=%s  old %.3f us  new %.3f us  control %.3f us  new/old %.3f  ctl/old %.3f\n", T, n, p, cache, same, 1e6minimum(to), 1e6minimum(tn), 1e6minimum(tc), minimum(tn)/minimum(to), minimum(tc)/minimum(to))
    end
  end
end
end
Probe.main()
