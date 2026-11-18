include("lib.jl")
println("Julia ", VERSION)
# (1) necessity of the d² guard: fast path without the `d2 < ρ2/16` recompute (verbatim otherwise), nearly parallel residuals
function nog_step(m, old::T, a::T, b::T, ρ2::T, k, guard::Bool) where T
  ls = m.ls
  λ = m.gt.λ0; ra = sqrt(a)
  λ >= ra && return zero(T)
  q = b/a; c = old + q; d2 = ρ2 - b*q
  if guard && d2 < ρ2/16
    d2 = PS._distance_sqr(ls.X, ls.r, k, q)
  end
  d2 = max(d2, zero(T))
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ)); γ = d/p
  prox_block(m.gt, c, k, γ)
end
for T in (Float32, Float64)
  rng = Xoshiro(4); worst_g = 0.0; worst_n = 0.0; nbad_n = 0; N = 0
  for t in 1:4000
    n = rand(rng, 3:20)
    xk = T.(randn(rng, n)); u = randn(rng, n)
    eps_rel = 10.0^(-rand(rng)*10)        # distance of r from span(x_k) relative to ||r||
    ρ = T.(randn(rng) .* xk .+ eps_rel .* u)
    λ = T(rand(rng, (0.3, 0.9, 0.99)) * norm(Float64.(xk)))
    X = reshape(copy(xk), n, 1)
    m, g, x = make_model(X, ρ, λ)
    a, b, ρ2 = PS._column_dot_rsqr(m.ls.X, m.ls.r, 1, T(NaN))
    r0 = copy(m.ls.r)
    ref = bigref(xk, r0, zero(T), m.gt.λ0)
    ratio(z) = setprecision(BigFloat, 512) do
      bd = step_bound(T, n, ref.ρn, ref.rn, ref.a, m.gt.λ0); Float64(ref.φ(big(z)) - ref.φmin)/bd
    end
    rg = ratio(nog_step(m, zero(T), a, b, ρ2, 1, true)); rn = ratio(nog_step(m, zero(T), a, b, ρ2, 1, false))
    worst_g = max(worst_g, rg); worst_n = max(worst_n, rn); N += 1; nbad_n += rn > 1
  end
  @printf("%s guard on: worst excess/bound %.3g ; guard off: worst %.3g, violations %d / %d\n", T, worst_g, worst_n, nbad_n, N)
end
# (2) simplified _level_brackets: whitelist + Float64 conversion + prevfloat/nextfloat when inexact
function lb_simple(λ0)
  λ0 isa Union{Base.IEEEFloat, Integer, Rational, BigFloat, AbstractIrrational} || return (NaN, NaN)
  w = Float64(λ0); isfinite(w) || return (NaN, NaN)
  w == λ0 ? (w, w) : (prevfloat(w), nextfloat(w))
end
let rng = Xoshiro(2), bad = 0, N = 0, widened = 0
  setprecision(BigFloat, 1024) do
    levels = Any[π, ℯ, Base.MathConstants.golden, big"0.1", 0.1, 1//3, 7, big(2)^80 + 1, Float16(0.1), 1e-310, floatmax(Float64), 5e-324, prevfloat(Inf)]
    append!(levels, [Rational(rand(rng, 1:10^6), rand(rng, 1:10^6)) for _ in 1:3000])
    append!(levels, [BigFloat(rand(rng))^3 + big"1e-30" for _ in 1:1000])
    append!(levels, [Rational(BigInt(rand(rng, 1:10^18)) * 10^20, BigInt(rand(rng, 1:10^18))) for _ in 1:500])
    for λ in levels
      lo, hi = lb_simple(λ); lo0, hi0 = PS._level_brackets(λ)
      N += 1
      isnan(lo0) && !isnan(lo) && (bad += 1; continue)
      isnan(lo) && continue
      exact = λ isa Irrational ? BigFloat(λ) : λ isa Rational ? big(numerator(λ))/big(denominator(λ)) : big(λ)
      (big(lo) <= exact <= big(hi)) || (bad += 1)
      (hi - lo) > (hi0 - lo0) && (widened += 1)
    end
  end
  println("simplified _level_brackets: $bad bracket violations / $N; brackets wider than the current ones for $widened levels (by at most 1 ulp each side)")
end
# (3) rough probe: fused kernel (a, b, ρ²) vs the LS kernel (a, b) in a loop over p columns, ns per column
using ProximalSolvers: _column_dot, _column_dot_rsqr
function t_kernel(f, X, r, p, reps)
  best = Inf; sink = 0.0
  for _ in 1:reps
    t0 = time_ns()
    for k in 1:p
      v = f(X, r, k)
      sink += Float64(v[2])
    end
    best = min(best, (time_ns() - t0)/p)
  end
  best, sink
end
for T in (Float32, Float64), n in (50, 500, 5000, 50000)
  p = 40; rng = Xoshiro(1); X = randn(rng, T, n, p); r = randn(rng, T, n); a = fill(T(1), p)
  fl(X, r, k) = _column_dot(X, r, k, a[k]); ff(X, r, k) = _column_dot_rsqr(X, r, k, a[k])
  t1, _ = t_kernel(fl, X, r, p, 300); t2, _ = t_kernel(ff, X, r, p, 300)
  @printf("%s n=%6d  LS kernel %8.0f ns  fused kernel %8.0f ns  ratio %.2f\n", T, n, t1, t2, t2/t1)
end
