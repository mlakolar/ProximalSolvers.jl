# Square-root lasso coordinate descent: F(β) = ‖y − Xβ‖₂ + λ0 ‖β‖₁ for ProximalBase's
# `SqrtLeastSquaresLoss(y, X)` (no 1/√n factor) and an unweighted `NormL1(λ0)` with λ0 > 0, on dense
# `Matrix{T}` and `Vector{T}` data, T = Float32 or Float64 (`solve!` validates these).
#
# `ls` is an `LSModel` with the loss scale 1, built from `leastsquares_data(f)`. It holds the borrowed X
# and y, the residual r = y − Xβ and the curvature cache a_k = ‖X_k‖², both in T, and supplies the
# residual update, the flat-column test and the two stopping scales. `gt` is the penalty at the level
# T(λ0), which the coordinate step uses for its comparison with √a and for its prox (set by
# `_prepare!`). The certificate works with brackets `lo64` ≤ λ0 ≤ `hi64` of the level of the objective,
# λ0 = g.λ0 (NaN when `_level_brackets` finds none). `floor64` = 16 eps(T) ‖y‖: with a relative change
# threshold, the stop check does not tighten it below this value. `tightenings` counts the tightenings
# of the solve. `gap` and `uncertified` record the outcome of the stop check for the result (the
# certified bound, or NaN; whether the run stopped without a certificate). `res64` and `rowmag64` are
# Float64 vectors of length n (allocated by `_prepare!`): the certificate's residual and row
# magnitudes; `res64` is also the scaled residual of `_sqrt_offrange_step`.
mutable struct SqrtLSModel{T<:Union{Float32, Float64}, M<:LSModel{T, T}} <: CDModel{T}
  ls::M
  gt::NormL1{T, Nothing}
  lo64::Float64
  hi64::Float64
  floor64::Float64
  tightenings::Int
  gap::T
  uncertified::Bool
  res64::Vector{Float64}
  rowmag64::Vector{Float64}
end
function cdmodel(f::SqrtLeastSquaresLoss{T, <:Vector{T}, <:Matrix{T}}, x::SparseIterate{T}) where {T<:Union{Float32, Float64}}
  d = leastsquares_data(f)
  ls = LSModel(d.Y, d.X, d.α)
  SqrtLSModel{T, typeof(ls)}(ls, NormL1(zero(T)), NaN, NaN, NaN, 0, T(NaN), false, Float64[], Float64[])
end

# The LS methods with the loss scale 1, forwarded: the `CDModel` defaults (unit coordinate scale, zero
# response scale, no cache, NaN loss value) do not describe this model.
initialize!(m::SqrtLSModel{T}, x::SparseIterate{T}) where T = (_initialize!(m.ls, x, true); m)
coordinate_scale(m::SqrtLSModel, x, k::Int) = coordinate_scale(m.ls, x, k)
response_scale(m::SqrtLSModel, x) = response_scale(m.ls, x)
_cache(m::SqrtLSModel) = m.ls.r
# The loss value ‖r‖₂ at the cached residual, from ProximalBase's residual oracle of the loss f.
loss_value(m::SqrtLSModel, f, x) = value_from_residual(f, m.ls.r)
# The outcome of the stop check, for the result and the warning (see `_stop_check!` in models.jl).
_result_gap(m::SqrtLSModel) = m.gap
_uncertified(m::SqrtLSModel) = m.uncertified

# Per-solve preparation (before the first pass, only when maxpasses > 0): the step's penalty at the
# level T(λ0), the certificate's brackets of λ0, the tightening floor, the counter, the outcome and the
# work vectors.
function _prepare!(m::SqrtLSModel{T}, g::NormL1, x::SparseIterate{T}) where T
  m.gt = NormL1(T(g.λ0))
  m.lo64, m.hi64 = _level_brackets(g.λ0)
  n = length(m.ls.y)
  if length(m.res64) != n
    m.res64 = Vector{Float64}(undef, n)
    m.rowmag64 = Vector{Float64}(undef, n)
  end
  ny, ey = _scaled_norm(m.ls.y, n)
  m.floor64 = 16eps(T)*ldexp(ny, ey)
  m.tightenings = 0
  m.gap = T(NaN)
  m.uncertified = false
  m
end

# Float64 numbers lo ≤ λ0 ≤ hi, or (NaN, NaN). For a level of a type that Julia compares exactly with a
# Float64 (the IEEE floats, the integers and Bool, Rational, BigFloat and the irrational constants), lo
# and hi are found by up to 8 steps of prevfloat and nextfloat from the rounded Float64(λ0), each tested by
# that exact comparison; a level of another type, or one for which 8 steps do not bracket it, gives NaN.
# lo == hi == λ0 when Float64(λ0) == λ0.
function _level_brackets(λ0)
  λ0 isa Union{Base.IEEEFloat, Integer, Rational, BigFloat, AbstractIrrational} || return (NaN, NaN)
  w = Float64(λ0)
  isfinite(w) || return (NaN, NaN)
  lo, hi = w, w
  for _ in 1:8
    lo <= λ0 && break
    lo = prevfloat(lo)
  end
  for _ in 1:8
    hi >= λ0 && break
    hi = nextfloat(hi)
  end
  lo <= λ0 <= hi ? (lo, hi) : (NaN, NaN)
end

# ‖v[1:n]‖₂ as (s, e) with the norm s 2^e, in Float64: with M = max_i |v_i| and 2^e ≤ M < 2^(e+1), s is
# the root of the sum of the squares of v_i 2^-e (each formed by `ldexp`), a sum between 1 and 4n where
# M is finite and positive. (0.0, 0) for v = 0, and (M, 0) for an M that is Inf or NaN.
function _scaled_norm(v::AbstractVector, n::Int)
  M = 0.0
  @inbounds for i in 1:n
    M = max(M, abs(Float64(v[i])))
  end
  (iszero(M) || !isfinite(M)) && return (M, 0)
  e = exponent(M)
  s = 0.0
  @inbounds for i in 1:n
    w = ldexp(Float64(v[i]), -e)
    s += w*w
  end
  (sqrt(s), e)
end

# The fused kernel of the step: a = ‖X_k‖² (only when the cache holds NaN), b = X_kᵀr and ρ² = ‖r‖², in T.
@inline function _column_dot_rsqr(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, a::T) where T
  b = zero(T)
  ρ2 = zero(T)
  if isnan(a)
    a = zero(T)
    @inbounds @simd for i in eachindex(r)
      v, ri = X[i, k], r[i]
      a += v*v
      b += ri*v
      ρ2 += ri*ri
    end
  else
    @inbounds @simd for i in eachindex(r)
      v, ri = X[i, k], r[i]
      b += ri*v
      ρ2 += ri*ri
    end
  end
  a, b, ρ2
end
# ‖r − q X_k‖², in T.
@inline function _distance_sqr(X::AbstractMatrix{T}, r::AbstractVector{T}, k::Int, q::T) where T
  s = zero(T)
  @inbounds @simd for i in eachindex(r)
    v = r[i] - q*X[i, k]
    s += v*v
  end
  s
end
# Whether a sum of n squares s computed in T is finite and at least n floatmin(T)/eps(T): then the
# squares that underflow (each an absolute error of at most nextfloat(zero(T))/2, under gradual
# underflow) change s by at most eps(T)²/2 relative.
@inline _clean_sum(s::T, n::Int) where T = isfinite(s) & (s >= n*(floatmin(T)/eps(T)))

# The coordinate step: the minimizer of φ(z) = ‖r_k − X_k z‖₂ + λ|z| over the coordinate, computed up to
# rounding (bounded in the comment of `step_bound` in test/sqrt_lasso.jl), with r_k = r + X_k old the
# residual without coordinate k (Stage 0 of #332, §2). With a = ‖X_k‖², b = X_kᵀr,
# the centre c = old + b/a and d = ‖r − (b/a) X_k‖ (the distance of r from the span of X_k),
# ‖r_k − X_k z‖² = a (z − c)² + d², so the minimizer is 0 for λ ≥ √a and shrink(c, τ) with
# τ = λ d/√(a (a − λ²)) for λ < √a. The level λ is T(λ0), from `gt`, in the comparison and in the prox.
# Refused, before the coordinate or the residual changes and before any other branch: a residual with an
# entry that is not finite (a computed ρ² that is not finite is checked entry by entry, because the
# squares of a finite residual can overflow), then, in the order of the LS step, a curvature that is 0 for
# a column that is not flat (its squares underflow) and a curvature that is not finite. A flat column
# takes the penalty's minimizer (`_coordinate_minimizer`).
@inline function coordinate_step!(m::SqrtLSModel{T}, g, x::SparseIterate{T}, k::Int) where T
  ls = m.ls
  a, b, ρ2 = _column_dot_rsqr(ls.X, ls.r, k, ls.a[k])
  isfinite(ρ2) || _check_residual(ls.r, k)
  iszero(a) && !_flat_column(ls, k) &&
    throw(ArgumentError("the coordinate curvature underflows; rescale the data"))
  isfinite(a) || _refuse_curvature(T, k)
  old = x[k]
  new = iszero(a) ? _coordinate_minimizer(g, old, k) : _sqrt_minimizer(m, old, a, b, ρ2, k)
  ls.a[k] = a
  h = new - old
  iszero(h) && return h      # x and the residuals do not change
  x[k] = new
  _residual_axpy!(ls, k, h)
  h
end
# The minimizer for a positive finite a. Fast path, where a and ρ² (the computed ‖r‖²) pass `_clean_sum`:
# λ ≥ √a is tested on ra = fl(√a) without squaring λ, and a − λ² is formed as ra² − λ² = (ra − λ)(ra + λ)
# through the two roots √(ra − λ) and √(ra + λ), whose product does not underflow where (ra − λ)(ra + λ)
# would (ra − λ is positive, and exact for λ ≥ ra/2). d² = ρ² − b (b/a); where it is below ρ²/16 (r
# nearly parallel to X_k, where the subtraction cancels), d² is formed again as ‖r − (b/a) X_k‖² by
# `_distance_sqr`. With p = ra √(ra − λ) √(ra + λ), γ = d/p and γλ, the step is `prox_block(gt, c, k, γ)`
# (the threshold γλ) when p, γ and γλ are normal numbers of T; otherwise `_sqrt_band_step` forms τ without
# γ (for example where γ overflows or is subnormal, or where γλ underflows). An a or a ρ² that does not
# pass `_clean_sum` (a subnormal curvature, whose squares can underflow, a tiny residual, r = 0
# included, or one whose squares overflow), and a recomputed d² that does not, take
# `_sqrt_offrange_step`. So the d² of the fast path passes `_clean_sum` or is at least ρ²/16 with ρ²
# passing it: it is positive, and it is not a value that underflowed to 0.
@inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
  ls = m.ls
  n = length(ls.r)
  (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_offrange_step(m, old, k)
  λ = m.gt.λ0
  ra = sqrt(a)
  λ >= ra && return zero(T)
  q = b/a
  c = old + q
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = _distance_sqr(ls.X, ls.r, k, q)
    _clean_sum(d2, n) || return _sqrt_offrange_step(m, old, k)
  end
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
  γ = d/p
  τ = γ*λ
  ((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))) ?
    prox_block(m.gt, c, k, γ) : _sqrt_band_step(c, ra, λ, Float64(d), 0)
end
# shrink(c, τ) with τ = (λ/ra)(d/√((ra − λ)(ra + λ))) for d = d̃ 2^e, formed in Float64 by
# `_sqrt_threshold64` and capped at floatmax(T) before the rounding to T. At a finite c the cap gives the 0
# that a larger τ gives; a c that is Inf or NaN stays non-finite, which `_visit!` refuses.
@noinline function _sqrt_band_step(c::T, ra, λ, d̃::Float64, e::Int) where T
  τ = _sqrt_threshold64(ra, λ, d̃, e)
  shrink(c, T(min(τ, Float64(floatmax(T)))))
end
# τ = (λ/ra)(d/w) with w = √(ra − λ) √(ra + λ), for 0 ≤ λ < ra (after the conversion to Float64) and
# d = d̃ 2^e, in Float64: d̃ and w are split into significands and exponents, so that the quotient d/w is
# not formed outside the range of Float64 before the final `ldexp` (which rounds a result outside the
# normal range to Inf, a subnormal number or 0). 0 for d̃ = 0.
function _sqrt_threshold64(ra, λ, d̃::Float64, e::Int)
  iszero(d̃) && return 0.0
  r, l = Float64(ra), Float64(λ)
  w = sqrt(r - l)*sqrt(r + l)
  md, ed = frexp(d̃)
  mw, ew = frexp(w)
  ldexp((l/r)*(md/mw), ed + e - ew)
end
# The step where a, ρ² or the recomputed d² is outside the range of `_clean_sum`, out of line, in Float64
# with the column and the residual scaled by powers of two (each entry by `ldexp`, into Float64; for
# Float32 data the scaled entries and their products are exact). With 2^ex ≤ max_i |X_ik| < 2^(ex+1) (the
# column is not flat, so the maximum is positive, and it is finite) and x̃ = X_k 2^-ex: ã = ‖x̃‖² is between 1
# and 4n, √a = √ã 2^ex and λ̃ = λ 2^-ex, so λ ≥ √a is tested as λ̃ ≥ √ã (a λ̃ that overflows to Inf
# passes it). Then, with M = max_i |r_i| (finite: `coordinate_step!` has refused a residual that is not):
# r = 0 (M = 0) gives b = 0 and d = 0, so the minimizer is c = old. Otherwise, with 2^er ≤ M < 2^(er+1)
# and s = r 2^-er (into `res64`): b̃ = x̃ᵀs, ‖s‖² (between 1 and 4n) and q̃ = b̃/ã give
# b/a = q̃ 2^(er − ex); d̃² = ‖s‖² − b̃ q̃, formed again as ‖s − q̃ x̃‖² by `_scaled_norm` (which scales by the
# largest entry of the difference) where it is below ‖s‖²/16, gives d = d̃ 2^er. The step is
# shrink(c, τ) with c = old + T(q̃ 2^(er − ex)) and τ = (λ̃/√ã)(d̃/√((√ã − λ̃)(√ã + λ̃))) 2^(er − ex), the
# threshold of the scaled problem, from `_sqrt_band_step`. For each nonzero vector among x̃, s and the
# difference, the largest magnitude of its normalized representation is in [1, 2); a zero vector is
# returned as 0. Power-of-two scaling is exact when its exact result is in the normal Float64 range; below
# that range it may lose bits or underflow to zero, with absolute error at most η/2 in the normalized
# units (η = 2^-1074). For example, a residual [2^1000, 2^-1000] against the column [1, 0] gives d̃ = 0 for
# d = 2^-1000, a relative change of 1 in d, while [1.5 2^1000, 2^-74] keeps 2^-74 as η. To first order in
# η, these errors change √a by at most √n η √a, and b/√a and d by at most 3 n η ‖r‖ (2^ex ≤ √a,
# 2^er ≤ ‖r‖, ‖x̃‖ ≥ 1 and ‖s‖ < 2√n; d also through the scaling inside `_scaled_norm`): absolute errors
# at the scales of the column and the residual, not relative to b or d. They are far below the terms
# u max(‖ρ‖, ‖r‖) of the objective-error bound of the step (the comment of `step_bound` in
# test/sqrt_lasso.jl), which covers them; for example a d computed as 0 moves the coordinate objective
# by at most 2d.
@noinline function _sqrt_offrange_step(m::SqrtLSModel{T}, old::T, k::Int) where T
  ls = m.ls
  X, r, s = ls.X, ls.r, m.res64
  n = length(r)
  Mx, M = 0.0, 0.0
  @inbounds for i in 1:n
    Mx = max(Mx, abs(Float64(X[i, k])))
    M = max(M, abs(Float64(r[i])))
  end
  ex = exponent(Mx)
  as = 0.0
  @inbounds for i in 1:n
    v = ldexp(Float64(X[i, k]), -ex)
    as += v*v
  end
  ras = sqrt(as)
  λs = ldexp(Float64(m.gt.λ0), -ex)
  λs >= ras && return zero(T)
  iszero(M) && return old
  er = exponent(M)
  bs, ss = 0.0, 0.0
  @inbounds for i in 1:n
    v = ldexp(Float64(r[i]), -er)
    s[i] = v
    bs += v*ldexp(Float64(X[i, k]), -ex)
    ss += v*v
  end
  qs = bs/as
  ds2 = ss - bs*qs
  if ds2 < ss/16
    @inbounds for i in 1:n
      s[i] -= qs*ldexp(Float64(X[i, k]), -ex)
    end
    ds, ed = _scaled_norm(s, n)
  else
    ds, ed = sqrt(ds2), 0
  end
  _sqrt_band_step(old + T(ldexp(qs, er - ex)), ras, λs, ds, ed + er - ex)
end
# The refusal of a residual with an entry that is not finite, at the visit of coordinate k.
@noinline function _check_residual(r::AbstractVector{T}, k::Int) where T
  for v in r
    isfinite(v) || throw(ArgumentError("the residual is not finite in $T at the visit of coordinate $k; rescale the data"))
  end
  nothing
end

# The stop check at a converged full pass (see `_stop_check!` in models.jl), in this order:
# 1. the certificate `_certify!` runs (also where the pass changed nothing, so that y = 0 and λ0 ≥ λmax
#    from 0 can be certified at the first pass); certified: `m.gap` holds the certified bound rounded up
#    to T, and the run stops with `converged = true`;
# 2. otherwise `m.gap` is NaN, and the run stops uncertified (`m.uncertified = true`, `converged =
#    false`) where the certificate is undefined (`:undefined`), or the pass changed nothing (maxh = 0),
#    or 2 tightenings were made in this solve, or the candidate tol/100 (in T) is not finite, is not
#    below the current threshold, is 0, or is below the floor (so a threshold that overflowed to Inf in T
#    is not lowered and spends no tightening);
# 3. otherwise the threshold is tightened, `st.tolerance = tol/100`, and the loop continues with it.
# The floor is in the units of the threshold: with a relative threshold (`scaled`, the changes scaled by
# √a_k and compared with tol ‖y‖) it is `floor64` = 16 eps(T) ‖y‖; with an absolute one (relative =
# false, or y = 0, the changes |h| themselves) it is 16 eps(T) max_k |β_k| at the check, a roundoff scale
# of the largest coefficient, and there is no tightening where every β_k is 0.
function _stop_check!(m::SqrtLSModel{T}, g, x::SparseIterate{T}, st, maxh, scaled::Bool) where T
  code, ratio = _certify!(m, x)
  if code === :certified
    m.gap = T(ratio, RoundUp)
    return :converged
  end
  m.gap = T(NaN)
  if code === :failed && !iszero(maxh) && m.tightenings < 2
    tol = st.tolerance/100
    if isfinite(tol) && tol < st.tolerance && tol > 0 && _above_floor(m, x, scaled, Float64(tol))
      m.tightenings += 1
      st.tolerance = tol
      return :retry
    end
  end
  m.uncertified = true
  :uncertified
end
# Whether the tightened threshold `tol` is at least the floor of `_stop_check!`.
function _above_floor(m::SqrtLSModel{T}, x::SparseIterate{T}, scaled::Bool, tol::Float64) where T
  scaled && return tol >= m.floor64
  βmax = 0.0
  for k in activecoordinates(x)
    βmax = max(βmax, abs(Float64(x[k])))
  end
  βmax > 0 && tol >= 16eps(T)*βmax
end
# Rounded upward and downward: nextfloat and prevfloat of the round-to-nearest result. For a real z
# with fl(z) its round-to-nearest value in Float64 (gradual underflow, overflow to ±Inf), z lies between
# fl(z) and its neighbour on the side of z, within half their distance, so
# nextfloat(fl(z)) ≥ z ≥ prevfloat(fl(z)), also where fl(z) is subnormal or 0, and where fl(z) = ±Inf
# (prevfloat(Inf) = floatmax(Float64) < z there).
_up(z::Float64) = nextfloat(z)
_dn(z::Float64) = prevfloat(z)
# The certification target, below the real number 1e-4.
const _CERT_TARGET = prevfloat(1e-4)

# The residual-direction duality certificate (Stage 0 of #332, §3, revised in the plan of PR A), in
# W = Float64 for both data types. It returns (code, ratio): (:certified, ratio) with
# ratio ≤ prevfloat(1e-4) a proved upper bound on (P(β) − P*)/P* for the current β; (:failed, ratio or
# NaN) where the bound is larger or the dual lower bound is not positive (more passes can help); and
# (:undefined, NaN) where it cannot be formed: the computed residual r̂ is 0 in every entry while some
# β_k ≠ 0 (the direction r̂/‖r̂‖ is undefined; this is the usual outcome at an exact fit y = Xβ, and r̂ can
# also round to 0 where y − Xβ is not 0, by cancellation at the scale of the row magnitudes below), its
# sum of squares is outside the range of the proof, the level has no brackets, or an aggregate is not
# finite (tested explicitly, not through a comparison with NaN). A true exact fit whose computed r̂ is
# not 0 goes through the bound like any other point, and a certificate there is valid. It also refreshes the residual cache `ls.r` with T.(r̂) where every r̂_i is finite and
# at most floatmax(T) in magnitude; x is not changed.
#
# Problem. P(β) = ‖y − Xβ‖₂ + λ0 ‖β‖₁ for the stored β (exact values of T) and the level λ0 = g.λ0 that
# the objective `g(work)` evaluates, P* = min P. Dual: maximize θᵀy subject to ‖θ‖₂ ≤ 1 and
# ‖Xᵀθ‖∞ ≤ λ0. Weak duality: for such θ and any β, P(β) ≥ θᵀ(y − Xβ) + λ0‖β‖₁ ≥ θᵀy − ‖Xᵀθ‖∞‖β‖₁ +
# λ0‖β‖₁ ≥ θᵀy, so P* ≥ θᵀy.
#
# Assumptions. IEEE binary64 arithmetic with round to nearest (ties to even) and gradual underflow
# (subnormals not flushed to zero); n rows, p columns, m = the number of nonzero β_k, with
# (n + p + 2) u ≤ 1/8 and n + p < 2^52 (u = eps(W)/2 = 2^-53, η = nextfloat(0.0) = 2^-1074,
# ε = eps(W) = 2u, γ_k = k u/(1 − k u)); Julia's comparisons of a Float64 with the level are exact for
# the level types of `_level_brackets`. Data, β and λ0 are finite (`solve!` checks them). Error model of
# one operation on floats a, b, c: fl(a ± b) = (a ± b)(1 + δ) (exact where the result is subnormal),
# fl(a b) = a b (1 + δ) + ζ, fl(a/b) = (a/b)(1 + δ) + ζ, fl(√a) = √a (1 + δ), and, where the compiler
# contracts a product and a sum into a fused multiply-add (LLVM may do so in the `@simd` column loop),
# fl(fma(a, b, c)) = (a b + c)(1 + δ) + ζ; always |δ| ≤ u and |ζ| ≤ η/2, with ζ ≠ 0 only for a result below
# floatmin(W). Facts used (standard, for any order of summation, so they cover `@simd`): (F1) for k + 1
# terms, |fl(Σ) − Σ| ≤ γ_k Σ|terms|; for nonnegative terms the computed sum lies in [Σ (1 − γ_k),
# Σ (1 + γ_k)]. (F2) for a dot product of length k, with or without contraction,
# |fl(Σ x_i y_i) − Σ x_i y_i| ≤ γ_k Σ|x_i y_i| + (k η/2)(1 + γ_{k−1}) ≤ γ_k Σ|x_i y_i| + k η: each product
# or fused operation contributes at most one ζ, and the later additions scale it by at most 1 + γ_{k−1}.
# (F3) 1/(1 − γ_k) ≤ 1 + 2 k u and γ_k ≤ 2 k u = k ε for k u ≤ 1/4. Products of two Float32 values are
# exact in W; the bounds below hold for Float32 data as well (with room to spare). Each scalar operation
# after the loops that can round is rounded outward with `_up`/`_dn`, which bound the exact result of the
# operation on the computed operands (the products of an integer below 2^52 with ε or η, 1 ± ψ, 1 ± m ε
# and the selections by min, max and comparisons are exact); as the operands are themselves bounds and
# the operations are monotone in each operand with the signs that occur (noted where a sign matters),
# each computed bound bounds the real quantity it names.
#
# Step 1, residual (sequential over the nonzero β_k, k in the stored order, each row updated in turn).
# r̂_i = fl(y_i − Σ_k π_ik) and μ̂_i = fl(|y_i| + Σ_k |π_ik|) with π_ik = fl(X_ik β_k). With r = y − Xβ and
# e = r − r̂: by F1 (m + 1 terms), |r̂_i − (y_i − Σπ_ik)| ≤ γ_m A_i, A_i = |y_i| + Σ|π_ik|; by the model,
# |Σ(π_ik − X_ik β_k)| ≤ u Σ|X_ik β_k| + m η/2 with |X_ik β_k| ≤ (|π_ik| + η/2)/(1 − u); and μ̂_i ≥
# A_i (1 − γ_m). So, for m ≥ 1, |e_i| ≤ (γ_m + u/(1 − u)) A_i + m η ≤ κ μ̂_i + m η with
# κ = (γ_m + u/(1 − u))/(1 − γ_m) ≤ (m + 1) u/(1 − 2 m u) ≤ (m + 1) ε, and ‖e‖₂ ≤ (m + 1) ε ‖μ̂‖₂ + m n η;
# for m = 0, r̂ = y exactly and e = 0, so the same bound holds. (If the compiler fused the product and the
# subtraction of a row update, the one fused rounding replaces the two, with at most one ζ per term, and
# the bound holds as well.)
#
# Step 2, norms. ŝ_r = fl(Σ r̂_i²), ŝ_μ = fl(Σ μ̂_i²). With N = ‖r̂‖₂ (the norm of the computed vector) and
# σ = Σ fl(r̂_i²) ∈ [N²(1 − u) − nη/2, N²(1 + u) + nη/2], F1 gives ŝ_r ∈ [σ (1 − γ_{n−1}), σ (1 + γ_{n−1})].
# Where ŝ_r is finite and ŝ_r ≥ n 2^-969 (so n η/2 ≤ u² ŝ_r), F3 gives N² ≤ ŝ_r (1 + 2(n − 1)u + u²)/(1 − u)
# ≤ ŝ_r (1 + ψ) and N² ≥ ŝ_r (1 − γ_{n−1} − u²)/(1 + u) ≥ ŝ_r (1 − ψ), ψ = 2(n + 1)u = (n + 1) ε (exact
# in W, as are 1 ± ψ). Hence N_lo = dn(√dn(ŝ_r (1 − ψ))) ≤ N ≤ N_up = up(√up(ŝ_r (1 + ψ))), and N_lo > 0.
# Otherwise (ŝ_r not finite, or below n 2^-969 with r̂ ≠ 0) the result is :undefined. Without a range
# condition, the same steps give ‖μ̂‖₂² ≤ ŝ_μ (1 + ψ) + n η, so M_up = up(√up(up(ŝ_μ (1 + ψ)) + n η))
# bounds ‖μ̂‖₂; n η is exact.
#
# Step 3, columns (every k in 1:p; the loop over the rows is `@simd`, and may be contracted). b̂_k =
# fl(Σ_i X_ik r̂_i) and â_k = fl(Σ_i X_ik²); B̂ = max |b̂_k|, Â = max â_k; Q̂ = fl(Σ_k fl(β_k b̂_k)) over the
# nonzero β_k (ascending k). With a_k = ‖X_k‖² and b_k = X_kᵀ r̂ (exact): F2 for X_kᵀX_k gives
# a_k ≤ (â_k + (n η/2)(1 + γ_{n−1}))/(1 − γ_n) ≤ â_k (1 + 2 n u) + n η ≤ Â (1 + ψ) + n η (F3), so
# √a_k ≤ R_up = up(√up(up(Â (1 + ψ)) + n η)); F2 and Cauchy–Schwarz (Σ|X_ik r̂_i| ≤ √a_k N) give
# |b_k − b̂_k| ≤ γ_n √a_k N + n η ≤ n ε R_up N + n η. The n η terms of R_up and of G absorb the absolute
# errors ζ of the products or of the fused operations of these two sums. So for every k,
# |b_k|/N ≤ (B̂ + n η)/N + n ε R_up ≤ G = up(up(up(B̂ + n η)/N_lo) + up(n ε R_up)).
#
# Step 4, dual point. G ≥ η > 0 (it is `nextfloat` of a nonnegative number), and t = min(1, max(dn(lo/G),
# 0)), with lo = `lo64` ≤ λ0. Then 0 ≤ t ≤ 1 and t G ≤ lo: for t = 0 trivially; for t = 1,
# 1 ≤ dn(lo/G) ≤ lo/G; for 0 < t < 1, t = dn(lo/G) ≤ lo/G. The dual point is
# θ = t r̂/N, a real vector in the exact direction of the computed residual: ‖θ‖₂ = t ≤ 1 and, by step 3,
# ‖Xᵀθ‖∞ = t max_k |b_k|/N ≤ t G ≤ lo ≤ λ0. So θ is dual feasible and P* ≥ θᵀy.
#
# Step 5, gap. With g_k = b_k/N, r = r̂ + e and y = r + Xβ: θᵀy = t N + (t/N) r̂ᵀe + t Σ_k β_k g_k, and
# ‖r‖ ≤ N + ‖e‖, so (Cauchy–Schwarz on r̂ᵀe)
#   P(β) − θᵀy ≤ (1 − t) N + (λ0 ‖β‖₁ − t Σ_k β_k g_k) + (1 + t) ‖e‖,
# a sum of terms that are each nonnegative in exact arithmetic (λ0|β_k| ≥ t |β_k g_k| by feasibility),
# with no difference of θᵀy and P (#152). Bounds, each formed with outward rounding:
#   - (1 − t) N ≤ T1 = up(up(1 − t) N_up), as 1 − t ≥ 0.
#   - Σ_k|β_k| from Σ̂ = fl(Σ|β_k|) (F1, m terms): Σ̂ (1 − m ε) ≤ Σ|β_k| ≤ Σ̂ (1 + m ε) (F3), so
#     Σ_lo = dn(Σ̂ (1 − m ε)) ≤ Σ|β_k| ≤ Σ_up = up(Σ̂ (1 + m ε)), and λ0 ‖β‖₁ ≤ S₁ = up(hi Σ_up), hi = `hi64`.
#   - t Σ β_k g_k = t Q/N with Q = Σ_k β_k b_k. By F2 (with |β_k b̂_k| ≤ B̂ |β_k|) and step 3,
#     Q ≥ Q̂ − (m ε B̂ + n η + n ε R_up N) Σ|β_k| − m η, so, for t ≥ 0 and N_lo ≤ N ≤ N_up,
#     t Q/N ≥ t q_n − t E₂ with q_n = dn(Q̂/N_up) for Q̂ ≥ 0 and dn(Q̂/N_lo) for Q̂ < 0 (q_n ≤ Q̂/N), and
#     E₂ = up(up(up(up(up(up(m ε B̂) + n η) Σ_up) + m η)/N_lo) + up(n ε up(R_up Σ_up)));
#     S₂ = dn(dn(t q_n) − up(t E₂)) ≤ t Σ β_k g_k.
#   - ‖e‖ ≤ E_up = up(up((m + 1) ε M_up) + up(up(m n) η)) by step 1.
#   gap_hi = up(up(T1 + up(S₁ − S₂)) + up(up(1 + t) E_up)) ≥ P(β) − θᵀy.
# Step 6, dual lower bound and decision. P(β) ≥ max(0, N − ‖e‖) + λ0 ‖β‖₁ ≥ P_lo =
# dn(dn(N_lo − E_up) + dn(lo Σ_lo)), and θᵀy ≥ P(β) − gap_hi ≥ D_lo = dn(P_lo − gap_hi). Certified when
# gap_hi and D_lo are finite, D_lo > 0 and ratio = up(gap_hi/D_lo) ≤ prevfloat(1e-4) (below the real
# 1e-4). Then P* ≥ θᵀy ≥ D_lo > 0 and P(β) − P* ≤ P(β) − θᵀy ≤ gap_hi, so
# (P(β) − P*)/P* ≤ gap_hi/D_lo ≤ ratio < 1e-4. The denominator is a dual lower bound, not P(β).
#
# Special cases, decided from exact data: y = 0 (every entry) and every β_k = 0 give P(β) = 0 = P*:
# (:certified, 0.0). A computed r̂ that is 0 in every entry with some β_k ≠ 0 is :undefined (with every
# β_k = 0, r̂ = y exactly, so this case is the first one).
function _certify!(m::SqrtLSModel{T}, x::SparseIterate{T}) where T
  ls = m.ls
  X, y, res, mag = ls.X, ls.y, m.res64, m.rowmag64
  n, p = size(X)
  yzero = true
  @inbounds for i in 1:n
    v = Float64(y[i])
    res[i] = v
    mag[i] = abs(v)
    yzero &= iszero(v)
  end
  nb = 0
  sb = 0.0
  for k in activecoordinates(x)
    v = Float64(x[k])
    iszero(v) && continue
    nb += 1
    sb += abs(v)
    @inbounds for i in 1:n
      t = Float64(X[i, k])*v
      res[i] -= t
      mag[i] += abs(t)
    end
  end
  if nb == 0 && yzero
    fill!(ls.r, zero(T))
    return :certified, 0.0
  end
  sr, smu, rmax = 0.0, 0.0, 0.0
  @inbounds for i in 1:n
    v = res[i]
    sr += v*v
    smu += mag[i]*mag[i]
    rmax = max(rmax, abs(v))       # `max` propagates a NaN
  end
  if isfinite(rmax) && rmax <= floatmax(T)
    @inbounds for i in 1:n
      ls.r[i] = T(res[i])
    end
  end
  iszero(rmax) && return :undefined, NaN
  lo, hi = m.lo64, m.hi64
  (isfinite(lo) & isfinite(hi) & isfinite(sr) & isfinite(smu) & (sr >= ldexp(Float64(n), -969))) ||
    return :undefined, NaN
  bmax, amax, q, finite = 0.0, 0.0, 0.0, true
  for k in 1:p
    bk, ak = 0.0, 0.0
    @inbounds @simd for i in 1:n
      v = Float64(X[i, k])
      bk += v*res[i]
      ak += v*v
    end
    finite &= isfinite(bk) & isfinite(ak)
    bmax = max(bmax, abs(bk))
    amax = max(amax, ak)
    v = x[k]
    iszero(v) || (q += Float64(v)*bk)
  end
  (finite & isfinite(q) & isfinite(sb)) || return :undefined, NaN
  ε = eps(Float64)
  η = nextfloat(0.0)
  nη = n*η
  ψ = (n + 1)*ε
  Nup = _up(sqrt(_up(sr*(1 + ψ))))
  Nlo = _dn(sqrt(_dn(sr*(1 - ψ))))
  Mup = _up(sqrt(_up(_up(smu*(1 + ψ)) + nη)))
  Rup = _up(sqrt(_up(_up(amax*(1 + ψ)) + nη)))
  G = _up(_up(_up(bmax + nη)/Nlo) + _up((n*ε)*Rup))
  isfinite(G) || return :undefined, NaN
  t = min(1.0, max(_dn(lo/G), 0.0))
  T1 = _up(_up(1 - t)*Nup)
  sbu = _up(sb*(1 + nb*ε))
  sbl = _dn(sb*(1 - nb*ε))
  S1 = _up(hi*sbu)
  qn = _dn(q/(q >= 0 ? Nup : Nlo))
  E2 = _up(_up(_up(_up(_up(_up((nb*ε)*bmax) + nη)*sbu) + nb*η)/Nlo) + _up((n*ε)*_up(Rup*sbu)))
  S2 = _dn(_dn(t*qn) - _up(t*E2))
  Eup = _up(_up(((nb + 1)*ε)*Mup) + _up(_up(Float64(nb)*Float64(n))*η))
  gap = _up(_up(T1 + _up(S1 - S2)) + _up(_up(1 + t)*Eup))
  Plo = _dn(_dn(Nlo - Eup) + _dn(lo*sbl))
  Dlo = _dn(Plo - gap)
  (isfinite(gap) & isfinite(Dlo)) || return :undefined, NaN
  Dlo > 0 || return :failed, NaN
  ratio = _up(gap/Dlo)
  ratio <= _CERT_TARGET ? (:certified, ratio) : (:failed, ratio)
end
