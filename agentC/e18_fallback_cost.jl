using Random, Printf
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers; const PB = ProximalBase
println("E18 fallback cost: PS scaled two-pass vs PB norm_diff recovery (indicative), julia ", VERSION)
const SINK = Ref(0.0)
function tm(f, reps = 200); f(); minimum(@elapsed(begin; acc = 0.0; for _ in 1:reps; acc += f(); end; SINK[] = acc; end) / reps for _ in 1:5); end
rng = Xoshiro(18)
for T in (Float32, Float64), n in (1_000, 100_000)
  for (name, sc) in (("ordinary", 0.0), ("underflowing squares", T == Float32 ? -70.0 : -540.0))
    a = T.(randn(rng, n) .* 2.0^sc); b = T.(randn(rng, n) .* 2.0^sc)
    t_ps_one = tm(() -> (s = PS._sumsq_diff(a, b); r = PS._se_norm_diff_onepass(T, s, a, b); Float64(r.s)))
    t_pb = tm(() -> Float64(PB.norm_diff(a, b)))
    t_ps_two = tm(() -> Float64(PS._se_norm_diff(T, a, b).s))
    @printf("  %-8s n=%7d %-22s PS onepass(+fallback)=%9.2f us  PS two-pass alone=%9.2f us  PB norm_diff=%9.2f us\n", T, n, name, t_ps_one * 1e6, t_ps_two * 1e6, t_pb * 1e6)
  end
end
