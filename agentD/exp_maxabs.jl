# PS._maxabs_diff(x,y)  vs  PB.norm_diff(x,y,Inf)   (same formula max_i |x_i - y_i|)
using ProximalBase, ProximalSolvers, Random
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
rng = MersenneTwister(9)
# equivalence
global bad = 0; global tot = 0
for T in (Float32, Float64), n in (0, 1, 7, 100, 1001)
  for trial in 1:50
    x = randn(rng, T, n); y = randn(rng, T, n)
    if trial % 10 == 0 && n > 0; x[rand(rng, 1:n)] = T(NaN); end
    if trial % 10 == 5 && n > 0; x[rand(rng, 1:n)] = T(Inf); end
    if trial % 25 == 3 && n > 0; x .*= T(2)^(exponent(floatmax(T)) - 3); y .*= T(2)^(exponent(floatmax(T)) - 3); end
    a = PS._maxabs_diff(x, y); b = PB.norm_diff(x, y, Inf)
    global tot += 1; isequal(a, b) || (global bad += 1; bad < 4 && println("DIFF ", T, " n=", n, " ", a, " ", b))
  end
end
println("equivalence: ", bad, " differences of ", tot)
function bench(f, args...; reps = 2000)
  f(args...); best = Inf
  for _ in 1:7
    t = @elapsed for _ in 1:reps; f(args...); end
    best = min(best, t/reps)
  end
  best
end
for T in (Float32, Float64), n in (100, 10_000, 1_000_000)
  x = randn(rng, T, n); y = randn(rng, T, n); reps = max(5, 2_000_00 ÷ n)
  t1 = bench(PS._maxabs_diff, x, y; reps); t2 = bench(PB.norm_diff, x, y, Inf; reps)
  println("$T n=$n: PS _maxabs_diff ", round(1e9t1/n, digits=3), " ns/elt   PB norm_diff(.,.,Inf) ", round(1e9t2/n, digits=3), " ns/elt   ratio PB/PS ", round(t2/t1, digits=2))
end
