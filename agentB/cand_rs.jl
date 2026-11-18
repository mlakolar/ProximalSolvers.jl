# Candidate C3: response_scale as ONE path, _se_scale(T, _se_mul(_root_scale(T, s), _se_norm_onepass(T, Σy²_T, y))),
# versus the current 3-tier response_scale; BigFloat(600) reference √α‖y‖ on the rounded inputs.
using ProximalSolvers, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
function rs_new(m::PS.LSModel{T}) where T
  iszero(m.s) && return zero(T)
  s = zero(T)
  @inbounds for i in eachindex(m.y); s += m.y[i]*m.y[i]; end
  ny = PS._se_norm_onepass(T, s, m.y)
  ny === nothing && PS._refuse_response_scale(T, false)
  PS._se_scale(T, PS._se_mul(PS._root_scale(T, m.s), ny))
end
# same, with the sum formed in Float64 for Float32 data (what the exceptional tier does today)
function rs_new64(m::PS.LSModel{T}) where T
  iszero(m.s) && return zero(T)
  W = T === Float32 ? Float64 : T
  s = zero(W)
  @inbounds for i in eachindex(m.y); v = W(m.y[i]); s += v*v; end
  ny = PS._se_norm_onepass(W, s, m.y)
  ny === nothing && PS._refuse_response_scale(T, false)
  PS._se_scale(T, PS._se_mul(PS._root_scale(W, m.s), ny))
end
function ref(m)
  v = sqrt(BigFloat(m.s)) * sqrt(sum(abs2, BigFloat.(m.y)))
  v
end
ulperr(val::T, r::BigFloat) where T = (iszero(r) ? (iszero(val) ? 0.0 : Inf) : Float64(abs(BigFloat(val) - r) / r) / eps(T))
attempt(f, m) = try (:ok, f(m)) catch e; e isa ArgumentError ? (:refused, nothing) : rethrow() end
rng = Xoshiro(11)
for (T, S) in ((Float32, Float32), (Float32, Float64), (Float64, Float64))
  stats = Dict(:n => 0, :bitdiff_cur_new => 0, :refuse_disagree_new => 0, :refuse_disagree_new64 => 0, :bitdiff_cur_new64 => 0)
  maxe = Dict(:cur => 0.0, :new => 0.0, :new64 => 0.0); worst = Dict{Symbol,Any}()
  eymax = T === Float32 ? 40 : 450; lmax = T === Float32 ? 120 : 1000
  for trial in 1:6000
    n = rand(rng, (1, 4, 50, 1000))
    ey = rand(rng, -eymax:eymax); l = rand(rng, -lmax:lmax)
    y = T.(randn(rng, n) .* exp2(ey)); all(isfinite, y) || continue
    α = S(ldexp(S(0.5 + rand(rng)), l)); (isfinite(α) && α > 0) || continue
    X = reshape(ones(T, n), n, 1)
    m = PS.LSModel(y, X, α)
    r = ref(m)
    ok_ref = floatmin(T) <= r <= floatmax(T)   # the value that rounds to a normal number of T
    # skip a razor-edge reference (within 4 ulp of a refusal boundary) for refusal agreement
    edge = abs(r - BigFloat(floatmin(T))) < 4eps(T)*floatmin(T) || abs(r - BigFloat(floatmax(T))) < 4eps(T)*floatmax(T)
    edge && continue
    stats[:n] += 1
    (sc, vc) = attempt(m -> PS.response_scale(m, nothing), m); (sn, vn) = attempt(rs_new, m); (s6, v6) = attempt(rs_new64, m)
    # current refuses iff the reference is not a normal number of T (documented)
    (sn == :ok) == ok_ref || (stats[:refuse_disagree_new] += 1)
    (s6 == :ok) == ok_ref || (stats[:refuse_disagree_new64] += 1)
    if sc == :ok && sn == :ok; vc === vn || (stats[:bitdiff_cur_new] += 1); end
    if sc == :ok && s6 == :ok; vc === v6 || (stats[:bitdiff_cur_new64] += 1); end
    for (k, s_, v_) in ((:cur, sc, vc), (:new, sn, vn), (:new64, s6, v6))
      s_ == :ok || continue
      e = ulperr(v_, r); if e > maxe[k]; maxe[k] = e; worst[k] = (n, ey, l); end
    end
  end
  @printf("%s data / %s scale: %d cases; refusal-disagreement with reference: new %d, new64 %d; bit-different from current: new %d, new64 %d\n   max error (ulps of T): current %.2f  new %.2f  new64 %.2f   worst new at (n,ey,l)=%s\n",
          T, S, stats[:n], stats[:refuse_disagree_new], stats[:refuse_disagree_new64], stats[:bitdiff_cur_new], stats[:bitdiff_cur_new64], maxe[:cur], maxe[:new], maxe[:new64], get(worst, :new, nothing))
end
# per-solve setup timing, indicative only (one process; not coordinate-loop timing)
function tm(f, m; reps=20000); f(m); t = @elapsed for _ in 1:reps; f(m); end; t/reps*1e9; end
for T in (Float32, Float64), n in (20, 100, 1000)
  y = randn(Xoshiro(1), T, n); X = ones(T, n, 1); m = PS.LSModel(y, X, one(T))
  @printf("%s n=%d: current %.0f ns, new (T-sum) %.0f ns, new64 %.0f ns, exceptional-only %.0f ns\n", T, n, tm(m -> PS.response_scale(m, nothing), m), tm(rs_new, m), tm(rs_new64, m), tm(PS._response_scale_exceptional, m))
end
