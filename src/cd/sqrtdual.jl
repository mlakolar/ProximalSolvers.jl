####################################
#
#  Certificates for square-root losses
#
####################################

# For min ‖ỹ - X̃x‖_W + ∑ₖ λₖ|xₖ| the dual maximizes θ'Wỹ subject to
# ‖θ‖_W ≤ 1, |X̃ₖ'Wθ| ≤ λₖ and equality on the unpenalized coordinates
# and the intercept. The residual direction is tried first. Otherwise, on
# the support together with the unpenalized coordinates, let K = X̃_S'WX̃_S.
# Scaled solves Kα ≈ c and Kγ ≈ X̃_S'WR give
# θ = X̃_Sα + β(R - X̃_Sγ), β ≥ 0.
# Its norm and penalized products are bounded before scaling, including the
# cross term. Unrestricted leakage is corrected below. Truncating the support
# solve can only weaken this witness.
# Residuals and sufficient statistics are recomputed with error-free product
# and sum remainders. Their residual error is bounded by the final rounding
# plus 64m eps times the accumulated remainder magnitudes, of order
# eps|rᵢ| + 64m² eps²∑ₖ|Xᵢₖxₖ|. Thus ‖r‖ ≤ ‖r̂‖ + ‖r - r̂‖ supplies an upper
# loss for the primal objective, zero test and P₀ in B. The quadratic analogue
# uses q ≤ q̂ + δq before taking its square root. Norms of
# quadratic witnesses use an upper rounding bound. If zₖ approximates the
# actual product with error eₖ, |Xₖ'Wθ| ≤ |zₖ| + eₖ gives the penalized scale.
# An upper norm bound gives t‖θ‖_W ≤ 1, with both ratios rounded down.
#
# A tolerance on an unrestricted equality is insufficient. Feasibility on the
# penalized coordinates gives P* ≥ tθ'Wy - tθ'WX_U x*_U. Cauchy–Schwarz and
# P* ≤ P₀ give P* ≥ tθ'Wy - t‖P_Uθ‖_W B, where
# B = ‖y‖_W + P₀ + ∑ₖ:0<λₖ<∞ ‖Xₖ‖_W P₀/λₖ bounds ‖X_U x*_U‖_W.
# For an independent basis with column scales D, e = X_U'Wθ satisfies
# ‖P_Uθ‖² = e'K_U⁺e ≤ ‖D⁻¹e‖²/λmin(D⁻¹K_UD⁻¹). Product errors and a lower
# eigenvalue bound inflate this correction. Exactly zero correlation intervals
# give zero correction without an inverse; otherwise unresolved rank gives θ = 0.
# The least-squares model uses the original y and X here and includes the
# uncentered constant column, so rounded means require no equality assumption.
# Reusing an old relative gap only within 512eps adds at most 512eps·P₀ to the
# suboptimality bound, independently of the residual norm. It must also be
# within one sixty-fourth of the target, to retain accuracy at lower precision.

const _SQRT_GAPCHECK = 1e-4
const _SQRT_DUAL_MAXSUPPORT = 2000
const _SQRT_DUAL_ROUNDING = 64
const _SQRT_DUAL_RANK = 8
const _SQRT_GAPROUNDING = 512

@inline _sqrt_upper(x::T) where {T<:AbstractFloat} = isfinite(x) && x > 0 ? nextfloat(x) : x
@inline _sqrt_lower(x::T) where {T<:AbstractFloat} = isfinite(x) && x > 0 ? prevfloat(x) : x

@inline function _sqrt_upmul(a::T, b::T) where {T}
  p = a * b
  iszero(p) && a > 0 && b > 0 ? eps(zero(T)) : _sqrt_upper(p)
end

@inline function _sqrt_updiv(a::T, b::T) where {T}
  p = a / b
  iszero(p) && a > 0 ? eps(zero(T)) : _sqrt_upper(p)
end

@inline _sqrt_productrisk(a::T, b::T, p::T) where {T} =
  !iszero(a) && !iszero(b) && abs(p) < 4floatmin(T) / eps(T)

@inline function _sqrt_addproduct(hi::T, lo::T, errors::T, a::T, b::T) where {T}
  value = a * b
  error = fma(a, b, -value)
  _sqrt_productrisk(a, b, value) && (errors += floatmin(T))
  _sqrt_qadd(hi, lo, errors, value, error)
end

# Error-free product and sum remainders avoid losing small correlations to
# cancellation. Products near underflow carry a first-order budget through
# the error accumulator, before a third factor can amplify their remainder.
@inline function _sqrt_finish(hi::T, lo::T, errors::T, n::Int) where {T}
  value, _, last = _sqrt_qadd(hi, zero(T), zero(T), lo, zero(T))
  error = last + _SQRT_DUAL_ROUNDING * eps(T) * max(1, n) * errors
  value, _sqrt_upper(error)
end

@inline function _sqrt_dotbounds(a::AbstractVector{T}, b::AbstractVector{T}, initial::T = zero(T)) where {T}
  hi, lo, errors = initial, zero(T), zero(T)
  for i in eachindex(a, b)
    hi, lo, errors = _sqrt_addproduct(hi, lo, errors, a[i], b[i])
  end
  _sqrt_finish(hi, lo, errors, length(a))
end

@inline function _sqrt_addtriple(hi::T, lo::T, errors::T, a::T, b::T, c::T) where {T}
  p = a * b
  pe = fma(a, b, -p)
  value = p * c
  ve, low = fma(p, c, -value), pe * c
  if _sqrt_productrisk(a, b, p)
    errors += _sqrt_upmul(floatmin(T), max(one(T), abs(c)))
  end
  if _sqrt_productrisk(p, c, value) || _sqrt_productrisk(pe, c, low)
    errors += floatmin(T)
  end
  errors += abs(ve) + abs(low)
  error = ve + low
  _sqrt_qadd(hi, lo, errors, value, error)
end

@inline function _sqrt_normupper(x::AbstractVector{T}) where {T}
  q, error = _sqrt_dotbounds(x, x)
  _sqrt_upper(sqrt(max(_sqrt_upper(q + error), zero(T))))
end

# Keep LAPACK's arrays as for group curvatures, requesting every eigenvector.
# The buffers grow with the support and are reused by later runs.
for (syevr, T) in ((:dsyevr_, :Float64), (:ssyevr_, :Float32))
  @eval function _sqrt_syevr!(ws::_GroupEig{$T}, vectors::Matrix{$T}, n::Int, lwork::Integer, liwork::Integer)
    ccall((@blasfunc($syevr), libblastrampoline), Cvoid,
          (Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{$T}, Ref{BlasInt},
           Ref{$T}, Ref{$T}, Ref{BlasInt}, Ref{BlasInt}, Ref{$T}, Ptr{BlasInt}, Ptr{$T},
           Ptr{$T}, Ref{BlasInt}, Ptr{BlasInt}, Ptr{$T}, Ref{BlasInt}, Ptr{BlasInt}, Ref{BlasInt},
           Ptr{BlasInt}, Clong, Clong, Clong),
          'V', 'A', 'U', n, ws.C, max(1, n), zero($T), zero($T), 1, n, -one($T), ws.m, ws.w,
          vectors, max(1, size(vectors, 1)), ws.isuppz, ws.work, lwork, ws.iwork, liwork, ws.info, 1, 1, 1)
    ws.info[]
  end
end

_sqrt_nrows(m::SqrtLSModel) = length(m.y)
_sqrt_nrows(m::SqrtQuadModel) = 0

function _sqrt_reserve!(m, n::Int)
  T = eltype(m)
  ws = m.dualeig
  ws.nmax >= n && return nothing
  nmax = min(2n, max(n, length(m.grad)), _SQRT_DUAL_MAXSUPPORT)
  ws.B = Matrix{T}(undef, _sqrt_nrows(m), nmax)
  ws.C = zeros(T, nmax^2)
  ws.w = zeros(T, nmax)
  ws.isuppz = zeros(BlasInt, 2nmax)
  m.dualvectors = zeros(T, nmax, nmax)
  if T <: Union{Float32, Float64}
    resize!(ws.work, 1); resize!(ws.iwork, 1)
    info = _sqrt_syevr!(ws, m.dualvectors, nmax, -1, -1)
    info == 0 || throw(LAPACKException(info))
    resize!(ws.work, max(1, round(Int, ws.work[1])))
    resize!(ws.iwork, max(1, Int(ws.iwork[1])))
  end
  resize!(m.dualrhs, nmax)
  resize!(m.dualα, nmax)
  resize!(m.dualγ, nmax)
  resize!(m.dualscale, nmax)
  ws.nmax = nmax
  nothing
end

@inline _sqrt_loading(g::NormL1, k, ::Type{T}) where {T} = T(g.λ0 * _weight(g, k))

@inline function _sqrt_eigen!(m, K::AbstractMatrix{T}) where {T}
  n, ws = size(K, 1), m.dualeig
  if T <: Union{Float32, Float64}
    _sqrt_syevr!(ws, m.dualvectors, n, length(ws.work), length(ws.iwork)) == 0 || return false
  else
    F = eigen(Symmetric(K))
    ws.w[1:n] .= F.values
    m.dualvectors[1:n, 1:n] .= F.vectors
  end
  true
end

# For the computed QΛQ', λmin(G) ≥ λmin(Λ)(1 - ‖I - QQ'‖) -
# ‖Ĝ - QΛQ'‖ - ‖G - Ĝ‖. Row sums of interval bounds bound both matrix norms,
# so this test does not assume that LAPACK resolved a small eigenvalue.
function _sqrt_unpen_lower(m, uncertainty, n)
  T = eltype(m)
  U, scales, Q, values = m.dualunpen, m.dualunpenscale, m.dualvectors, m.dualeig.w
  minimumvalue = Base.minimum(view(values, 1:n))
  minimumvalue > 0 || return zero(T)
  residual, orthogonal = zero(T), zero(T)
  for i in 1:n
    rowresidual, roworthogonal = zero(T), zero(T)
    for j in 1:n
      a, b = minmax(i, j)
      value, _ = _sqrt_gram(m, U[a], U[b])
      value = (value / scales[a]) / scales[b]
      rh, rl, re = -value, zero(T), zero(T)
      oh, ol, oe = i == j ? -one(T) : zero(T), zero(T), zero(T)
      for k in 1:n
        rh, rl, re = _sqrt_addtriple(rh, rl, re, Q[i, k], values[k], Q[j, k])
        oh, ol, oe = _sqrt_addproduct(oh, ol, oe, Q[i, k], Q[j, k])
      end
      r, er = _sqrt_finish(rh, rl, re, 3n)
      o, eo = _sqrt_finish(oh, ol, oe, n)
      rowresidual = _sqrt_upper(rowresidual + _sqrt_upper(abs(r) + er))
      roworthogonal = _sqrt_upper(roworthogonal + _sqrt_upper(abs(o) + eo))
    end
    residual = max(residual, rowresidual)
    orthogonal = max(orthogonal, roworthogonal)
  end
  orthogonal < 1 || return zero(T)
  _sqrt_lower(_sqrt_lower(minimumvalue * _sqrt_lower(1 - orthogonal)) -
              _sqrt_upper(residual + uncertainty))
end

# Drop only dependencies that are exact in the supplied data. An uncertain
# small eigenvalue must not hide an independent unrestricted direction.
@inline function _sqrt_unpenstart!(m, data, g, P)
  T = eltype(m)
  U, scales = m.dualunpen, m.dualunpenscale
  empty!(U); empty!(scales)
  m isa SqrtLSModel && m.centered && push!(U, 0)
  for k in eachindex(m.grad)
    iszero(_sqrt_loading(g, k, T)) || continue
    _sqrt_zerocol(m, k) && continue
    dependent = false
    for j in U
      if _sqrt_samecol(m, k, j)
        dependent = true
        break
      end
    end
    dependent && continue
    length(U) < _SQRT_DUAL_MAXSUPPORT || return false
    push!(U, k)
  end
  m.dualbound = m.dualinv = zero(T)
  isempty(U) && return true

  q, error = _sqrt_gram(m, -1, -1)
  q + error >= 0 || return false
  P₀ = _sqrt_upper(P + data.rounding + _SQRT_DUAL_ROUNDING * max(1, length(m.grad)) * eps(T) * abs(P))
  B = _sqrt_upper(_sqrt_upper(sqrt(max(_sqrt_upper(q + error), zero(T)))) + P₀)
  for k in eachindex(m.grad)
    λ = _sqrt_loading(g, k, T)
    isfinite(λ) && λ > 0 || continue
    q, error = _sqrt_gram(m, k, k)
    q + error >= 0 || return false
    column = _sqrt_upper(sqrt(max(_sqrt_upper(q + error), zero(T))))
    B = _sqrt_upper(B + _sqrt_upmul(column, _sqrt_updiv(P₀, λ)))
  end
  isfinite(B) || return false
  m.dualbound = B

  n = length(U)
  for k in U
    q, error = _sqrt_gram(m, k, k)
    q > error || return false
    d = n == 1 ? _sqrt_lower(sqrt(_sqrt_lower(q - error))) : sqrt(q)
    d > 0 && isfinite(d) || return false
    push!(scales, d)
  end
  if n == 1
    m.dualinv = one(T)
    return true
  end
  m.dualinv = -one(T)
  true
end

# Delay the inverse bound until a candidate has nonzero unrestricted leakage.
# A zero interval proves P_Uθ = 0 even when the unrestricted Gram is singular.
function _sqrt_unpenfactor!(m)
  T = eltype(m)
  U, scales = m.dualunpen, m.dualunpenscale
  n = length(U)
  m.dualinv = T(Inf)
  _sqrt_reserve!(m, n)
  K = reshape(view(m.dualeig.C, 1:n^2), n, n)
  rows = view(m.dualrhs, 1:n)
  fill!(rows, zero(T))
  for j in 1:n, i in 1:j
    q, error = _sqrt_gram(m, U[i], U[j])
    value = (q / scales[i]) / scales[j]
    δ = _sqrt_upper(_sqrt_updiv(_sqrt_updiv(error, scales[i]), scales[j]) +
                    8eps(T) * max(one(T), abs(value)))
    K[i, j] = K[j, i] = value
    rows[i] = _sqrt_upper(rows[i] + δ)
    i == j || (rows[j] = _sqrt_upper(rows[j] + δ))
  end
  uncertainty = maximum(rows)
  all(isfinite, K) && _sqrt_eigen!(m, K) || return false
  lower = _sqrt_unpen_lower(m, uncertainty, n)
  lower > 0 || return false
  m.dualinv = _sqrt_upper(inv(_sqrt_lower(sqrt(lower))))
  isfinite(m.dualinv)
end

# Nonfinite loadings fix a coordinate at zero in the coordinate steps.
@inline function _sqrt_support(m, g, x)
  T = eltype(m)
  S, c = m.dualsupport, m.dualc
  empty!(S); empty!(c)
  for k in eachindex(x)
    λ = _sqrt_loading(g, k, T)
    if !isfinite(λ)
      iszero(x[k]) || return nothing
    elseif !iszero(x[k]) || iszero(λ)
      length(S) < _SQRT_DUAL_MAXSUPPORT || return nothing
      push!(S, k)
      push!(c, iszero(λ) ? zero(T) : copysign(λ, x[k]))
    end
  end
  S, c
end

# The same rank-revealing solve serves both right hand sides. No rank bound
# in observation space is needed, so dependent supports are allowed.
@inline function _sqrt_supportsolve(m, K::AbstractMatrix{T}, c, s) where {T}
  n = length(c)
  α, γ = view(m.dualα, 1:n), view(m.dualγ, 1:n)
  fill!(α, zero(T)); fill!(γ, zero(T))
  isempty(c) && return (α, γ)
  all(isfinite, K) && all(isfinite, s) || return nothing
  for i in 1:n
    K[i, i] >= 0 || return nothing
    m.dualscale[i] = iszero(K[i, i]) ? one(T) : sqrt(K[i, i])
  end
  for j in 1:n, i in 1:j
    value = (K[i, j] / m.dualscale[i]) / m.dualscale[j]
    K[i, j] = K[j, i] = value
  end
  ws = m.dualeig
  _sqrt_eigen!(m, K) || return nothing
  values = view(ws.w, 1:n)
  cutoff = _SQRT_DUAL_RANK * eps(T) * n * maximum(abs, values)
  Base.minimum(values) >= -cutoff || return nothing
  for j in 1:n
    d = values[j]
    d > cutoff || continue
    v = view(m.dualvectors, 1:n, j)
    a, b = zero(T), zero(T)
    for i in 1:n
      a += v[i] * (c[i] / m.dualscale[i])
      b += v[i] * (s[i] / m.dualscale[i])
    end
    a /= d; b /= d
    α .+= a .* v
    γ .+= b .* v
  end
  for i in 1:n
    α[i] /= m.dualscale[i]
    γ[i] /= m.dualscale[i]
  end
  all(isfinite, α) && all(isfinite, γ) ? (α, γ) : nothing
end

# The positive root of a + 2βh + β²d = 1, without cancellation for h ≥ 0.
function _sqrt_residualpart(a::T, h::T, d::T) where {T}
  d > 0 && a < 1 || return zero(T)
  v = sqrt(h * h + d * (1 - a))
  h >= 0 ? (1 - a) / (v + h) : (v - h) / d
end

# Penalized products use intervals. Unrestricted products give the projection
# correction above, rather than an equality tolerance.
function _sqrt_validated_dual(m, g, z::AbstractVector{T}, nθ, D, z₀::T = zero(T), e₀::T = zero(T)) where {T}
  errors = m.dualcorrerr
  isfinite(nθ) && nθ >= 0 && isfinite(D) && all(isfinite, z) && all(isfinite, errors) || return nothing
  t = nθ > 1 ? _sqrt_lower(inv(nθ)) : one(T)
  for k in eachindex(z)
    λ = _sqrt_loading(g, k, T)
    isfinite(λ) || continue
    iszero(λ) && continue
    a = _sqrt_upper(abs(z[k]) + errors[k])
    if a > λ
      t = min(t, _sqrt_lower(λ / a))
    end
  end
  projection = zero(T)
  for (i, k) in enumerate(m.dualunpen)
    upper = k == 0 ? _sqrt_upper(abs(z₀) + e₀) : _sqrt_upper(abs(z[k]) + errors[k])
    v = _sqrt_updiv(upper, m.dualunpenscale[i])
    projection = _sqrt_upper(hypot(projection, v) * (1 + 4eps(T)))
  end
  correction = zero(T)
  if !iszero(projection)
    m.dualinv < 0 && !_sqrt_unpenfactor!(m) && return nothing
    isfinite(m.dualinv) || return nothing
    projection = _sqrt_upmul(projection, m.dualinv)
    correction = _sqrt_upmul(_sqrt_upmul(t, projection), m.dualbound)
  end
  isfinite(correction) || return nothing
  _sqrt_lower(_sqrt_lower(t * D) - correction)
end

@inline function _sqrt_jointdual(m, data, g, x)
  support = _sqrt_support(m, g, x)
  support === nothing && return nothing
  S, c = support
  isempty(S) && return nothing
  _sqrt_reserve!(m, length(S))
  geometry = _sqrt_supportdata(m, data, S)
  solved = _sqrt_supportsolve(m, geometry.K, c, geometry.s)
  solved === nothing && return nothing
  α, γ = solved
  _sqrt_restore_support!(m, geometry, S)
  _sqrt_jointpoint(m, data, g, S, geometry, α, γ)
end

_sqrt_restore_support!(m::SqrtLSModel, geometry, S) = nothing

function _sqrt_certified!(st, m, g, x, s)
  T = eltype(m)
  f = loss_value(m, x)
  penalty = T(g(x))
  P = f + penalty
  target = s.gaptol > 0 ? s.gaptol : _SQRT_GAPCHECK
  data = _sqrt_dualdata(m, x)
  if data === nothing || !isfinite(P)
    st.relgap = T(Inf)
    return false
  end
  for k in eachindex(x)
    if !isfinite(_sqrt_loading(g, k, T)) && !iszero(x[k])
      st.relgap = T(Inf)
      return false
    end
  end

  upperP = max(P, data.f + penalty)
  D = zero(T)
  iszero(upperP) && (st.relgap = zero(T); return true)
  if !_sqrt_unpenstart!(m, data, g, upperP)
    st.relgap = _relative_gap(upperP, D)
    return false
  end
  if f > 0
    G = gradient!(m.grad, m, x)
    t = _dualscale(g, G)
    if t !== nothing
      Gx = zero(T)
      for k in eachindex(G)
        iszero(x[k]) || (Gx += G[k] * x[k])
      end
      oldD = t * (f - Gx)
      oldgap = _relative_gap(P, oldD)
      candidate = _sqrt_residualdual(m, data, g, t / f)
      if candidate !== nothing
        D = max(D, candidate)
        # Keep the arithmetic of ordinary certified runs when recomputation
        # confirms both values to rounding. No support factorization is paid.
        checkedgap = _relative_gap(upperP, candidate)
        if candidate > 0 && oldgap <= target && checkedgap <= target &&
           abs(checkedgap - oldgap) <= min(_SQRT_GAPROUNDING * eps(T), target / 64)
          st.relgap = oldgap
          return true
        end
      end
    end
  end

  if data.f > 0
    candidate = _sqrt_residualdual(m, data, g, inv(data.f))
    candidate === nothing || (D = max(D, candidate))
    st.relgap = _relative_gap(upperP, D)
    D > 0 && st.relgap <= target && return true
  end
  candidate = _sqrt_jointdual(m, data, g, x)
  candidate === nothing || (D = max(D, candidate))
  # Cover both the recomputed upper loss and the value reported from the cache.
  st.relgap = _relative_gap(upperP, D)
  (D > 0 || iszero(upperP)) && st.relgap <= target
end
