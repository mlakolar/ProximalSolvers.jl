using Random, Printf
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers; const B = PS.Blocks
rng = Xoshiro(14); bad = 0; tot = 0
for T in (Float32, Float64), _ in 1:20000
  n = rand(rng, (1, 3, 8, 50)); a, b = randn(rng, T, n) .* T(2)^rand(rng, -20:20), randn(rng, T, n)
  r = rand(rng); r < .05 && (a[rand(rng, 1:n)] = T(NaN)); .05 <= r < .1 && (a[rand(rng, 1:n)] = T(Inf)); .1 <= r < .13 && (a[1] = floatmax(T); b[1] = -floatmax(T))
  global tot += 1
  x, y = B._maxabs_diff(a, b), B._norm_diff(a, b, Inf)
  (x === y || (isnan(x) && isnan(y))) || (global bad += 1)
end
println(VERSION, " _maxabs_diff vs Blocks._norm_diff(.,.,Inf): mismatches ", bad, " of ", tot)
a = randn(100); b = randn(100); B._norm_diff(a, b, Inf); B._maxabs_diff(a, b)
println("  allocs: _maxabs_diff=", @allocated(B._maxabs_diff(a, b)), " _norm_diff(Inf)=", @allocated(B._norm_diff(a, b, Inf)))
