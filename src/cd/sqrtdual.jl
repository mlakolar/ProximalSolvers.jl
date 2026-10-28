####################################
#
#  Certificates for square-root losses
#
####################################

# For min ‖ỹ - X̃x‖_W + ∑ₖ λₖ|xₖ| the dual maximizes θ'Wỹ subject to
# ‖θ‖_W ≤ 1, |X̃ₖ'Wθ| ≤ λₖ and equality on the unpenalized coordinates
# and the intercept. The residual direction is tried first. Otherwise, on
# the support together with the unpenalized coordinates, K = X̃_S'WX̃_S,
# α ≈ K⁺c and γ ≈ K⁺X̃_S'WR give θ = X̃_Sα + β(R - X̃_Sγ), β ≥ 0.
# Its actual norm, cross term included, and all its constraints are checked
# before scaling. Truncating the support solve can only weaken this witness.
# Residuals and sufficient statistics are recomputed from the data. Norms of
# quadratic witnesses use an upper rounding bound; equality constraints are
# accepted only to rounding on the scale ‖X̃ₖ‖_W ‖θ‖_W. The zero point is
# always feasible, so missing a witness cannot accept a change-only stop.

const _SQRT_GAPCHECK = 1e-4
const _SQRT_DUAL_MAXSUPPORT = 2000
const _SQRT_DUAL_ROUNDING = 64
const _SQRT_DUAL_RANK = 8

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
  nmax = min(2n, length(m.grad), _SQRT_DUAL_MAXSUPPORT)
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
  ws.nmax = nmax
  nothing
end

@inline _sqrt_loading(g::NormL1, k, ::Type{T}) where {T} = T(g.λ0 * _weight(g, k))
@inline _sqrt_colnorm(m::SqrtLSModel, k) = sqrt(max(_sqnorm!(m, k), zero(eltype(m))))
@inline _sqrt_colnorm(m::SqrtQuadModel, k) = sqrt(max(m.A[k, k], zero(eltype(m))))

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
  ws = m.dualeig
  if T <: Union{Float32, Float64}
    _sqrt_syevr!(ws, m.dualvectors, n, length(ws.work), length(ws.iwork)) == 0 || return nothing
  else
    F = eigen(Symmetric(K))
    ws.w[1:n] .= F.values
    m.dualvectors[1:n, 1:n] .= F.vectors
  end
  values = view(ws.w, 1:n)
  cutoff = _SQRT_DUAL_RANK * eps(T) * n * maximum(abs, values)
  Base.minimum(values) >= -cutoff || return nothing
  for j in 1:n
    d = values[j]
    d > cutoff || continue
    v = view(m.dualvectors, 1:n, j)
    a, b = dot(v, c) / d, dot(v, s) / d
    α .+= a .* v
    γ .+= b .* v
  end
  all(isfinite, α) && all(isfinite, γ) ? (α, γ) : nothing
end

# The positive root of a + 2βh + β²d = 1, without cancellation for h ≥ 0.
function _sqrt_residualpart(a::T, h::T, d::T) where {T}
  d > 0 && a < 1 || return zero(T)
  v = sqrt(h * h + d * (1 - a))
  h >= 0 ? (1 - a) / (v + h) : (v - h) / d
end

# Validate equalities before scaling: no positive scale repairs a violated
# equality. Products and norms refer to the vector actually constructed.
function _sqrt_validated_dual(m, g, z::AbstractVector{T}, nθ, D) where {T}
  isfinite(nθ) && nθ >= 0 && isfinite(D) && all(isfinite, z) || return nothing
  t = nθ > 1 ? inv(nθ) : one(T)
  for k in eachindex(z)
    λ = _sqrt_loading(g, k, T)
    isfinite(λ) || continue
    a = abs(z[k])
    if iszero(λ)
      a <= _SQRT_DUAL_ROUNDING * eps(T) * _sqrt_colnorm(m, k) * nθ || return nothing
    elseif a > λ
      t = min(t, λ / a)
    end
  end
  t * D
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

  D = zero(T)
  iszero(P) && iszero(data.f) && (st.relgap = zero(T); return true)
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
        allowance = (1 + abs(P) / max(f, data.f)) * data.rounding +
                    _SQRT_DUAL_ROUNDING * eps(T) * abs(P)
        checkedgap = _relative_gap(max(P, data.f + penalty), candidate)
        if candidate > 0 && oldgap <= target && checkedgap <= target &&
           abs(data.f - f) <= data.rounding && abs(candidate - oldD) <= allowance
          st.relgap = oldgap
          return true
        end
      end
    end
  end

  if data.f > 0
    candidate = _sqrt_residualdual(m, data, g, inv(data.f))
    candidate === nothing || (D = max(D, candidate))
    st.relgap = _relative_gap(max(P, data.f + penalty), D)
    D > 0 && st.relgap <= target && return true
  end
  candidate = _sqrt_jointdual(m, data, g, x)
  candidate === nothing || (D = max(D, candidate))
  # Cover both the recomputed upper loss and the value reported from the cache.
  st.relgap = _relative_gap(max(P, data.f + penalty), D)
  (D > 0 || iszero(max(P, data.f + penalty))) && st.relgap <= target
end
