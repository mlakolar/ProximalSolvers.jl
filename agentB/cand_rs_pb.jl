# Candidate C7: response scale √s‖y‖ from PB's public oracle value_from_residual(Scaled(SqrtLeastSquaresLoss(y, X), √s), y).
using ProximalSolvers, ProximalBase, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
function rs_pb(m::PS.LSModel{T}) where T
  iszero(m.s) && return zero(T)
  S = typeof(m.s)
  f = Scaled(SqrtLeastSquaresLoss(m.y, m.X), sqrt(m.s))
  v = ProximalBase.value_from_residual(f, m.y)
  (isfinite(v) && floatmin(T) <= v <= floatmax(T)) || PS._refuse_response_scale(T, true)
  convert(T, v)
end
ref(m) = sqrt(BigFloat(m.s)) * sqrt(sum(abs2, BigFloat.(m.y)))
ulperr(val::T, r::BigFloat) where T = iszero(r) ? (iszero(val) ? 0.0 : Inf) : Float64(abs(BigFloat(val) - r) / r) / eps(T)
attempt(f, m) = try (:ok, f(m)) catch e; e isa ArgumentError ? (:refused, nothing) : rethrow() end
rng = Xoshiro(11)
for (T, S) in ((Float32, Float32), (Float32, Float64), (Float64, Float64))
  n_ = 0; dis = 0; maxe = 0.0; maxc = 0.0; worst = nothing; errs = 0
  eymax = T === Float32 ? 40 : 450; lmax = T === Float32 ? 120 : 1000
  for trial in 1:4000
    n = rand(rng, (1, 4, 50, 1000)); ey = rand(rng, -eymax:eymax); l = rand(rng, -lmax:lmax)
    y = T.(randn(rng, n) .* exp2(ey)); all(isfinite, y) || continue
    α = S(ldexp(S(0.5 + rand(rng)), l)); (isfinite(α) && α > 0) || continue
    m = PS.LSModel(y, reshape(ones(T, n), n, 1), α); r = ref(m)
    ok_ref = floatmin(T) <= r <= floatmax(T)
    (abs(r - BigFloat(floatmin(T))) < 4eps(T)*floatmin(T) || abs(r - BigFloat(floatmax(T))) < 4eps(T)*floatmax(T)) && continue
    n_ += 1
    (sp, vp) = try attempt(rs_pb, m) catch e; (:error, e) end
    sp == :error && (errs += 1; continue)
    (sp == :ok) == ok_ref || (dis += 1; dis <= 3 && @printf("   refusal disagreement: n=%d ey=%d l=%d ref=%.3g got %s\n", n, ey, l, Float64(r), sp))
    sc, vc = attempt(m -> PS.response_scale(m, nothing), m)
    if sp == :ok; e = ulperr(vp, r); if e > maxe; maxe = e; worst = (n, ey, l); end; end
    sc == :ok && (maxc = max(maxc, ulperr(vc, r)))
  end
  @printf("%s data / %s scale: %d cases; unexpected errors %d; refusal disagreement %d; max error (ulps of T) PB-oracle %.2f vs current %.2f; worst PB at %s\n", T, S, n_, errs, dis, maxe, maxc, worst)
end
for T in (Float32, Float64), n in (20, 1000)
  y = randn(Xoshiro(1), T, n); X = ones(T, n, 1); m = PS.LSModel(y, X, one(T))
  rs_pb(m); PS.response_scale(m, nothing)
  t(f) = (t0 = @elapsed(for _ in 1:20000; f(m); end); t0/20000*1e9)
  @printf("%s n=%d: current %.0f ns / %d B; PB-oracle variant %.0f ns / %d B (setup path, indicative)\n", T, n, t(m -> PS.response_scale(m, nothing)), @allocated(PS.response_scale(m, nothing)), t(rs_pb), @allocated(rs_pb(m)))
end
