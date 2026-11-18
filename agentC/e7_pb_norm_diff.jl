include(joinpath(@__DIR__, "common.jl"))
println("E7 PB norm_diff as a substitute for _se_norm_diff_onepass(_sumsq_diff), julia ", VERSION)
rng = Xoshiro(7)
sub(T) = T == Float32 ? -149 : -1074
# (a) value agreement and error against the budget δ = γ_{n+4}: requirement is  N/((1-δ)(1-u)) >= ‖Δ‖ >= N/((1+δ)(1+u))
function pbN(T, a, b)
  v = PB.norm_diff(a, b)
  isfinite(v) ? PS._SE{T}(v) : nothing
end
for T in (Float32, Float64)
  emax = exponent(floatmax(T)); u = unit(T)
  tp = Tally("$T PB norm_diff: ‖a-b‖ within [N/(1+δ)(1+u), N/(1-δ)(1-u)]   (ratio = relerr/δ)")
  ts = Tally("$T PS onepass: same")
  tinf = Tally("$T PB norm_diff returned a nonfinite/zero value on finite data where PS returned a finite SE")
  for trial in 1:4000
    n = rand(rng, (1, 2, 3, 8, 17, 100, 1000, 5000))
    k = rand(rng, (sub(T)+3):(emax - 6))
    a = rscale(rng, T, n, k)
    b = trial % 3 == 0 ? T.(Float64.(a) .+ randn(rng, n) .* 2.0^(k - rand(rng, 1:20))) : rscale(rng, T, n, k - rand(rng, 0:2))
    all(isfinite, a) && all(isfinite, b) || continue
    δ = gam(T, n + 4); ed = bnormdiff(a, b)
    Ns = PS._se_norm_diff_onepass(T, PS._sumsq_diff(a, b), a, b)
    Np = pbN(T, a, b)
    if Ns !== nothing && Np === nothing; rec!(tinf, false); end
    for (tt, M) in ((tp, Np), (ts, Ns))
      M === nothing && continue
      m = se2big(M)
      iszero(ed) ? rec!(tt, iszero(m)) : rec!(tt, m / ((1 - δ) * (1 - u)) >= ed >= m / ((1 + δ) * (1 + u)), Float64(abs(m / ed - 1) / δ))
    end
  end
  report(tp); report(ts); report(tinf)
end
# (b) adversarial underflow zone where PB's threshold (s >= floatmin) is below PS's (s >= 4 n floatmin)
println(" adversarial zone: squares just above half-spacing, s in [floatmin, 4n floatmin)")
for T in (Float32, Float64)
  u = unit(T); fm = floatmin(T); sp = nextfloat(zero(T))
  for n in (100, 1000, T == Float32 ? 100_000 : 100_000, T == Float32 ? 1_500_000 : 400_000)
    # entries v with v² = (k + 0.49) spacings, chosen so n v² ≈ 1.2 floatmin
    k = max(round(Int, 1.2 * Float64(fm) / n / Float64(sp)), 1)
    v = T(sqrt((k + 0.49) * Float64(sp)))
    a = fill(v, n); b = zeros(T, n)
    δ = gam(T, n + 4)
    ss = PS._sumsq_diff(a, b)
    Np = pbN(T, a, b); Ns = PS._se_norm_diff_onepass(T, ss, a, b)
    ed = bnormdiff(a, b)
    zone = ss >= fm && ss < 4n * fm
    @printf("  %s n=%8d in-zone=%s  PB relerr/δ=%.3f  PS relerr/δ=%.3f  (δ=%.3g)  one-pass sum used by PS: %s\n", T, n, zone,
      Float64(abs(se2big(Np) / ed - 1) / δ), Float64(abs(se2big(Ns) / ed - 1) / δ), δ, ss >= 4n * fm)
  end
end
