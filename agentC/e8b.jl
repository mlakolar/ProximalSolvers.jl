using Random, Printf
using ProximalSolvers
const PS = ProximalSolvers; const B = PS.Blocks
@inline function fsum(f::F, ::Type{T}, inds) where {F, T}
  s = zero(T); @inbounds @simd for i in inds; s += f(i); end; s end
@inline function fmax(f::F, ::Type{T}, inds) where {F, T}
  m = zero(T); @inbounds @simd for i in inds; m = max(m, f(i)); end; m end
mine_maxabs_axpy(L::T, d, g) where {T} = fmax(i -> abs(L * d[i] + g[i]), T, eachindex(d))
mine_sumsq_diff(a, b) = fsum(i -> abs2(a[i] - b[i]), eltype(a), eachindex(a, b))
function allocs(T)
  rng = Xoshiro(1); a, b, g = (randn(rng, T, 1000) for _ in 1:3); L = T(1.3)
  B._maxabs_axpy(L, a, g); mine_maxabs_axpy(L, a, g); PS._sumsq_diff(a, b); mine_sumsq_diff(a, b)
  f1() = @allocated B._maxabs_axpy(L, a, g)
  f2() = @allocated mine_maxabs_axpy(L, a, g)
  f3() = @allocated PS._sumsq_diff(a, b)
  f4() = @allocated mine_sumsq_diff(a, b)
  (f1(), f2(), f3(), f4())
end
println(VERSION, " allocations (orig maxabs_axpy, generic, orig sumsq_diff, generic): F32 ", allocs(Float32), " F64 ", allocs(Float64))
