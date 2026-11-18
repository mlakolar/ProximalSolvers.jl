include(joinpath(@__DIR__, "common.jl"))
println("E2 _se_norm family on julia ", VERSION)
rng = Xoshiro(2)
# Requirement taken from _BoundConstants: with δ = γ_{n+4}, u = unit roundoff,
#   norm of a stored vector v (D = computed ‖d̂‖, normx):  (1-δ) ‖v‖ <= D <= (1+δ) ‖v‖
#   norm of stored differences (N): upper_image N = N/((1-δ)(1-u)) >= ‖Δ‖ , lower_image N <= ‖Δ‖ with the rounded
#   differences within (1±u): N/(1+δ)/(1+u) <= ‖Δ‖ <= N/(1-δ)/(1-u)
function vecs(T, n, k)
  v = rscale(rng, T, n, k); v
end
sub(T) = T == Float32 ? -149 : -1074
for T in (Float32, Float64)
  emax = exponent(floatmax(T)); emin = exponent(floatmin(T))
  u = unit(T)
  t_se = Tally("$T _se_norm: |D-‖v‖|/‖v‖ <= γ_{n+4}")
  t_one = Tally("$T _se_norm_onepass (driven as the solver does)")
  t_d = Tally("$T _se_norm_diff_onepass: ‖a-b‖ within upper/lower_image")
  t_df = Tally("$T _se_norm_diff (two-pass) same")
  nothing_count = 0; path_two = 0; path_one = 0
  for trial in 1:3000
    n = rand(rng, (1, 2, 3, 8, 17, 100, 1000, 5000))
    k = rand(rng, (sub(T)+3):(emax - 6))
    k2 = rand(rng, 1:6) == 1 ? k - rand(rng, 0:30) : k     # nearly equal vectors
    a = rscale(rng, T, n, k)
    b = trial % 3 == 0 ? a .+ T.(randn(rng, n) .* 2.0^(k - rand(rng, 1:20))) .|> T : rscale(rng, T, n, k2)
    all(isfinite, a) && all(isfinite, b) || continue
    δ = gam(T, n + 4)
    # norm of a single vector
    s = sum(abs2, a)                      # the solver uses _sumsq2 (T accumulation) -- here the fused loop
    sd, sx = PS._sumsq2(a, b)
    D = PS._se_norm_onepass(T, sx, b)
    D === nothing && continue
    ex = bnorm(b)
    iszero(ex) ? rec!(t_one, iszero(D.s)) : (r = abs(se2big(D) / ex - 1); rec!(t_one, r <= δ, Float64(r / δ)))
    D2 = PS._se_norm(T, b)
    iszero(ex) || (r = abs(se2big(D2) / ex - 1); rec!(t_se, r <= δ, Float64(r / δ)))
    # differences
    N = PS._se_norm_diff_onepass(T, PS._sumsq_diff(a, b), a, b)
    N2 = PS._se_norm_diff(T, a, b)
    ed = bnormdiff(a, b)
    for (tt, M) in ((t_d, N), (t_df, N2))
      if M === nothing
        nothing_count += 1; continue
      end
      m = se2big(M)
      up = m / ((1 - δ) * (1 - u)); lo = m / ((1 + δ) * (1 + u))
      iszero(ed) ? rec!(tt, iszero(m)) : rec!(tt, lo <= ed <= up, Float64(abs(m / ed - 1) / δ))
    end
    ss = PS._sumsq_diff(a, b)
    (isfinite(ss) && ss >= 4n * floatmin(T)) ? (path_one += 1) : (path_two += 1)
  end
  foreach(report, (t_se, t_one, t_d, t_df))
  println("  $T: diff path counts one-pass=$path_one scaled=$path_two, `nothing` returns=$nothing_count")
end
# Adversarial: the one-pass threshold 4 n floatmin with n identical entries, so every square rounds alike
for T in (Float32, Float64)
  t = Tally("$T threshold zone: constant entries, s just above/below 4 n floatmin")
  for n in (4, 100, 3000), c in (0.5, 0.99, 1.0, 1.01, 1.5, 3.0, 20.0), pert in (0.0, 0.3, 0.49)
    v = T(sqrt(4n * floatmin(T) * c / n))
    a = fill(v, n); b = zeros(T, n)
    a .= v .* T.(1 .+ pert .* (rand(rng, n) .- 0.5) ./ 100)
    δ = gam(T, n + 4)
    N = PS._se_norm_diff_onepass(T, PS._sumsq_diff(a, b), a, b)
    N === nothing && continue
    ed = bnormdiff(a, b); m = se2big(N)
    rec!(t, abs(m / ed - 1) <= δ, Float64(abs(m / ed - 1) / δ))
  end
  report(t)
end
