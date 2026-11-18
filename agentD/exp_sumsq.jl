using ProximalBase, ProximalSolvers, Random
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
rng = MersenneTwister(21)
function run()
  for T in (Float32, Float64)
    same = 0; tot = 0
    for n in (1, 5, 33, 1000, 100_000), _ in 1:20
      a = randn(rng, T, n); b = randn(rng, T, n)
      tot += 1; same += (PS._sumsq_diff(a, b) === PB._sumabs2_diff(a, b))
    end
    println("$T: PS._sumsq_diff === PB._sumabs2_diff bitwise: $same / $tot")
  end
  function bench(f, args...; reps)
    f(args...); best = Inf
    for _ in 1:7; t = @elapsed(for _ in 1:reps; f(args...); end); best = min(best, t/reps); end
    best
  end
  for T in (Float32, Float64), n in (1000, 100_000)
    a = randn(rng, T, n); b = randn(rng, T, n); reps = max(10, 1_000_000 ÷ n)
    t1 = bench(PS._sumsq_diff, a, b; reps); t2 = bench(PB._sumabs2_diff, a, b; reps)
    println("$T n=$n: PS _sumsq_diff $(round(1e9t1/n, digits=3)) ns/elt   PB _sumabs2_diff $(round(1e9t2/n, digits=3)) ns/elt   ratio PB/PS $(round(t2/t1, digits=2))")
  end
end
run()
