# Indicative probe only (not a controlled benchmark): would one closure-based fused reduction replace the hand-written loops?
using Random, Printf, InteractiveUtils
using ProximalSolvers
const PS = ProximalSolvers; const B = PS.Blocks
@inline function fsum(f::F, ::Type{T}, inds) where {F, T}
  s = zero(T)
  @inbounds @simd for i in inds
    s += f(i)
  end
  s
end
@inline function fmax(f::F, ::Type{T}, inds) where {F, T}
  m = zero(T)
  @inbounds @simd for i in inds
    m = max(m, f(i))
  end
  m
end
mine_maxabs_axpy(L::T, d, g) where {T} = fmax(i -> abs(L * d[i] + g[i]), T, eachindex(d))
mine_maxabs_residual(a, b, d, L::T) where {T} = fmax(i -> abs(a[i] - b[i] - d[i] * L), T, eachindex(d))
mine_maxabs_diff(x::AbstractArray{T}, y) where {T} = fmax(i -> abs(x[i] - y[i]), T, eachindex(x))
mine_maxabs_stepdiff(L::T, y, x, g) where {T} = fmax(i -> abs(L * (y[i] - x[i]) - g[i]), T, eachindex(x))
mine_dot_diff(::Type{T}, a, b, c) where {T} = fsum(i -> (a[i] - b[i]) * c[i], T, eachindex(a))
mine_sumsq_diff(a, b) = fsum(i -> abs2(a[i] - b[i]), eltype(a), eachindex(a, b))
mine_sumsq64(v) = fsum(i -> abs2(Float64(v[i])), Float64, eachindex(v))
mine_sumsq_scaled_diff(a, b, m) = fsum(i -> abs2((a[i] - b[i]) / m), typeof(m), eachindex(a, b))
function timeit(f, args...; reps = 200)
  f(args...); best = Inf
  for _ in 1:5
    t = @elapsed for _ in 1:reps; f(args...); end
    best = min(best, t / reps)
  end
  best
end
println("Julia ", VERSION)
rng = Xoshiro(8)
for T in (Float32, Float64), n in (10_000, 1_000_000)
  a, b, c, d, g = (randn(rng, T, n) for _ in 1:5); L = T(1.3); m = T(3)
  tests = [
    ("_maxabs_axpy",     () -> B._maxabs_axpy(L, d, g),               () -> mine_maxabs_axpy(L, d, g)),
    ("_maxabs_residual", () -> B._maxabs_residual(a, b, d, L),        () -> mine_maxabs_residual(a, b, d, L)),
    ("_maxabs_diff",     () -> B._maxabs_diff(a, b),                  () -> mine_maxabs_diff(a, b)),
    ("_maxabs_stepdiff", () -> B._maxabs_stepdiff(L, a, b, g),        () -> mine_maxabs_stepdiff(L, a, b, g)),
    ("_dot_diff",        () -> B._dot_diff(T, a, b, c),               () -> mine_dot_diff(T, a, b, c)),
    ("_sumsq_diff",      () -> PS._sumsq_diff(a, b),                  () -> mine_sumsq_diff(a, b)),
    ("_sumsq64",         () -> PS._sumsq64(a),                        () -> mine_sumsq64(a)),
    ("_sumsq_scaled_diff", () -> PS._sumsq_scaled_diff(a, b, m),      () -> mine_sumsq_scaled_diff(a, b, m)),
  ]
  for (name, f0, f1) in tests
    r0, r1 = f0(), f1()
    t0, t1 = timeit((f)->f(), f0), timeit((f)->f(), f1)
    al = @allocated f1()
    @printf("  %-8s n=%8d %-20s bitequal=%-5s  orig=%8.2f us  generic=%8.2f us  ratio=%.2f  alloc(generic)=%d\n", T, n, name, r0 === r1, t0 * 1e6, t1 * 1e6, t1 / t0, al)
  end
end
