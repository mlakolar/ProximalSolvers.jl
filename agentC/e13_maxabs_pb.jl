using Random, Printf, LinearAlgebra
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers; const B = PS.Blocks
println("E13 _maxabs_diff vs PB norm_diff(.,.,Inf) vs norm(.,Inf), indicative, julia ", VERSION)
const SINK = Ref(0.0)
function tm(f, reps = 300)
  f()
  minimum(@elapsed(begin; acc = 0.0; for _ in 1:reps; acc += Float64(f()); end; SINK[] = acc; end) / reps for _ in 1:5)
end
rng = Xoshiro(13)
for T in (Float32, Float64), n in (1_000, 100_000)
  a, b = randn(rng, T, n), randn(rng, T, n); Ref(a); Ref(b)
  r = (B._maxabs_diff(a, b), norm_diff(a, b, Inf), maximum(abs, a .- b))
  ok = r[1] === r[2] === r[3]
  t1 = tm(() -> B._maxabs_diff(a, b)); t2 = tm(() -> norm_diff(a, b, Inf)); t3 = tm(() -> norm(a, Inf)); t4 = tm(() -> B._norm_inf(a))
  t5 = tm(() -> maximum(abs, a))
  @printf("  %-8s n=%7d equal=%s  Blocks._maxabs_diff=%8.2f us  PB.norm_diff(Inf)=%8.2f us  norm(x,Inf)=%8.2f us  maximum(abs,x)=%8.2f us\n", T, n, ok, t1 * 1e6, t2 * 1e6, t3 * 1e6, t5 * 1e6)
end
