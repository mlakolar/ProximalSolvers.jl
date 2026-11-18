# Shared helpers for agent A experiments (issue #353, sqrt-lasso CD numerics).
# Drives the REAL private functions of ProximalSolvers; the branch classifier below is a mirror of the
# control flow of coordinate_step!/_sqrt_minimizer (verified against the real result on every step by
# checking that the mirrored branch is consistent with the real function's returned value where checkable,
# see check_mirror).
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
const PS = ProximalSolvers
using ProximalBase: SparseIterate

# ----- mirror of control flow (verbatim conditions) -----
# returns (branch::Symbol, aux)
function classify(m, g, x, k)
  T = eltype(m.ls.r)
  ls = m.ls
  a, b, ρ2 = PS._column_dot_rsqr(ls.X, ls.r, k, ls.a[k])
  n = length(ls.r)
  if !isfinite(ρ2)
    allfin = all(isfinite, ls.r)
    allfin || return :refuse_resid
  end
  if iszero(a) && !PS._flat_column(ls, k)
    return :refuse_a0
  end
  isfinite(a) || return :refuse_ainf
  iszero(a) && return :flat
  if !(PS._clean_sum(a, n) & PS._clean_sum(ρ2, n))
    why = !PS._clean_sum(a, n) ? (isfinite(a) && a < n*(floatmin(T)/eps(T)) ? :asmall : :abig) :
            (isfinite(ρ2) ? (all(iszero, ls.r) ? :r0 : (iszero(ρ2) ? :runder : :rsmall)) : :rbig)
    return Symbol(:off_, why)
  end
  λ = m.gt.λ0
  ra = sqrt(a)
  λ >= ra && return :zero
  q = b/a
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = PS._distance_sqr(ls.X, ls.r, k, q)
    PS._clean_sum(d2, n) || return :off_d
    guard = true
  else
    guard = false
  end
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
  γ = d/p
  τ = γ*λ
  ok = ((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T)))
  ok ? (guard ? :ord_guard : :ord) : :band
end

function make_model(X::Matrix{T}, y::Vector{T}, λ, x0 = zeros(T, size(X, 2))) where T
  f = SqrtLeastSquaresLoss(y, X)
  x = SparseIterate(copy(x0))
  m = PS.cdmodel(f, x)
  PS.initialize!(m, x)
  g = NormL1(λ)
  PS._prepare!(m, g, x)
  m, g, x
end

# ----- BigFloat reference for one coordinate step -----
# rounded inputs: column xk (T), cached residual r (T), old (T), level λ (T). Returns minimizer and objective
function bigref(xk::AbstractVector{T}, r::AbstractVector{T}, old, λ) where T
  setprecision(BigFloat, 512) do
    xb = big.(xk); rb = big.(r); ob = big(old); λb = big(λ)
    a = sum(abs2, xb); b = sum(xb .* rb)
    ρ = rb .+ xb .* ob
    φ(z) = sqrt(sum(abs2, ρ .- xb .* z)) + λb*abs(z)
    if iszero(a)
      return (zstar = big(0), φmin = φ(big(0)), φ = φ, a = a, c = big(0), ρn = sqrt(sum(abs2, ρ)), rn = sqrt(sum(abs2, rb)))
    end
    ra = sqrt(a)
    c = ob + b/a
    if λb >= ra
      z = big(0)
    else
      d2 = sum(abs2, rb .- (b/a) .* xb)
      d = sqrt(d2)
      τ = iszero(d) ? big(0) : λb*d/sqrt(a*(a - λb^2))
      z = sign(c) * max(abs(c) - τ, big(0))
    end
    φmin = min(φ(z), φ(big(0)), φ(c))      # sanity: closed form should be the minimum
    (zstar = z, φmin = φ(z), φ = φ, a = a, c = c, ρn = sqrt(sum(abs2, ρ)), rn = sqrt(sum(abs2, rb)),
     sanity = φ(z) <= φmin * (1 + big(2)^-400))
  end
end

# The test-suite bound: (37γ_n + 56u) max(‖ρ‖,‖r‖) plus 4(√a+λ)η  (test/sqrt_lasso.jl, comment of step_bound)
function step_bound(::Type{T}, n, ρn, rn, a, λ) where T
  u = eps(T)/2
  γ = n*u/(1 - n*u)
  (37γ + 56u) * Float64(max(ρn, rn)) + 4*(sqrt(Float64(a)) + Float64(λ)) * Float64(nextfloat(zero(T)))
end

# one visit with branch tag, excess against the BigFloat reference. returns NamedTuple
function visit!(m, g, x, k; reference = true)
  T = eltype(m.ls.r)
  br = classify(m, g, x, k)
  xk = m.ls.X[:, k]; r = copy(m.ls.r); old = x[k]
  local h, err
  err = nothing
  try
    h = PS.coordinate_step!(m, g, x, k)
  catch e
    err = e
    return (branch = br, h = zero(T), err = e, excess = NaN, bound = NaN, ratio = NaN, zerr = NaN, znew = old, zstar = NaN)
  end
  znew = x[k]
  if !reference
    return (branch = br, h = h, err = nothing, excess = NaN, bound = NaN, ratio = NaN, zerr = NaN, znew = znew, zstar = NaN)
  end
  ref = bigref(xk, r, old, m.gt.λ0)
  setprecision(BigFloat, 512) do
    exc = Float64(ref.φ(big(znew)) - ref.φmin)
    n = length(r)
    bd = step_bound(T, n, ref.ρn, ref.rn, ref.a, m.gt.λ0)
    # coordinate error relative to the problem scale |c| (or |z*|)
    sc = max(abs(ref.zstar), abs(big(znew)), abs(ref.c))
    zerr = iszero(sc) ? 0.0 : Float64(abs(big(znew) - ref.zstar)/sc)
    (branch = br, h = h, err = nothing, excess = exc, bound = bd, ratio = exc/bd, zerr = zerr, znew = znew, zstar = Float64(ref.zstar))
  end
end

# run cyclic passes, collect visit records
function run_passes(X::Matrix{T}, y::Vector{T}, λ, passes; reference = true, x0 = zeros(T, size(X,2)), stoptol = 0.0) where T
  m, g, x = make_model(X, y, λ, x0)
  recs = NamedTuple[]
  p = size(X, 2)
  for pass in 1:passes
    maxh = zero(T)
    for k in 1:p
      v = visit!(m, g, x, k; reference)
      push!(recs, v)
      v.err === nothing || return recs, m, x, v.err
      maxh = max(maxh, abs(v.h))
    end
    maxh <= stoptol && break
  end
  recs, m, x, nothing
end

function summarize(recs)
  cnt = Dict{Symbol,Int}()
  worst = Dict{Symbol,Float64}()
  worstz = Dict{Symbol,Float64}()
  for v in recs
    cnt[v.branch] = get(cnt, v.branch, 0) + 1
    isfinite(v.ratio) && (worst[v.branch] = max(get(worst, v.branch, 0.0), v.ratio))
    isfinite(v.zerr) && (worstz[v.branch] = max(get(worstz, v.branch, 0.0), v.zerr))
  end
  cnt, worst, worstz
end

fmtcnt(cnt) = join(["$(k)=$(v)" for (k, v) in sort(collect(cnt); by = first)], " ")

# λmax = ‖Xᵀy‖∞/‖y‖ in Float64 (BigFloat not needed for choosing a level)
function lam_max(X, y)
  Xb, yb = Float64.(X), Float64.(y)
  # scaled to avoid overflow
  sy = maximum(abs, yb); sx = maximum(abs, Xb)
  (iszero(sy) || iszero(sx)) && return 0.0
  Yn = yb ./ sy; Xn = Xb ./ sx
  norm(Xn' * Yn, Inf) / norm(Yn) * sx
end

# ----- real-call counters: more specific methods that count and `invoke` the original method -----
const REAL_OFF = Ref(0)
const REAL_BAND = Ref(0)
const REAL_T64 = Ref(0)
for T in (Float32, Float64)
  M = PS.SqrtLSModel{T, PS.LSModel{T, T, Matrix{T}, Vector{T}}}
  @eval function PS._sqrt_offrange_step(m::$M, old::$T, k::Int)
    REAL_OFF[] += 1
    invoke(PS._sqrt_offrange_step, Tuple{PS.SqrtLSModel{$T}, $T, Int}, m, old, k)
  end
  @eval function PS._sqrt_band_step(c::$T, ra, λ, d̃::Float64, e::Int)
    REAL_BAND[] += 1
    invoke(PS._sqrt_band_step, Tuple{Any, Any, Any, Float64, Int}, c, ra, λ, d̃, e)
  end
end
