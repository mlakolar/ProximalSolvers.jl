####################################
#
#  The sparse group lasso: λmax, screening and the dual norm
#
####################################

# Paths of the sparse group lasso fix the mixture α and move the level λ of
# Scaled(SparseGroupNormL2(α, 1 - α, groups, w), λ), the penalty
# λ(α‖x‖₁ + (1 - α)Σₖ wₖ‖x_Gₖ‖₂), as along the paths of R's SGL and sparsegl.
# Group k is optimal at zero when ‖soft(∇_G f, αλ)‖₂ ≤ (1 - α)λwₖ, a condition
# on the gradient that its norm does not give. The left side minus the right is
# nonincreasing in λ, so the condition holds from a root λₖ of the gradient on:
# λmax is the largest root, and screening compares the roots with the levels.
# The same root, applied to a dual point, is the dual norm of the penalty, which
# scales the dual point of the duality gap (Ndiaye, Fercoq, Gramfort and
# Salmon, 2016).

const _SGL = SparseGroupNormL2
const _ScaledSGL = Scaled{<:SparseGroupNormL2}

# The root of h(μ) = ‖soft(v[G], aμ)‖₂ - cμ, the smallest μ ≥ 0 with h(μ) ≤ 0:
# the smallest scale μ at which zero minimizes ⟨v[G], u⟩ + μ(a‖u‖₁ + c‖u‖₂)
# over u. Inf for a group without penalty, a = c = 0, unless v[G] = 0. h is
# convex and nonincreasing, so Newton's method from μ = 0 increases to the root
# without passing it. Between the breakpoints aμ = |vⱼ|, ‖soft(v[G], aμ)‖² is a
# quadratic in μ; each iterate μ fixes the entries S above aμ, which contain
# those above a times the root, and the first root ν > μ of
# Σ_S (|vⱼ| - aν)² = c²ν² is the root of h when no entry of S falls below aν. That root is exact, and it comes after
# one to six iterates of O(|G|) on random groups of 5 to 1000 entries. Its
# discriminant is c²Σ_S vⱼ² - a²|S| Σ_S (rⱼ - r̄)², with rⱼ = |vⱼ| - aμ, which
# avoids the cancellation of the textbook form.
function _sgl_root(v::AbstractArray{T}, G, a::Real, c::Real) where {T}
  a, c = T(a), T(c)
  vmax, s = zero(T), zero(T)
  @inbounds for i in G
    u = abs(v[i])
    vmax = max(vmax, u)
    s += u * u
  end
  iszero(vmax) && return zero(T)
  iszero(a) && return iszero(c) ? T(Inf) : sqrt(s) / c      # the group lasso
  iszero(c) && return vmax / a                               # the lasso
  μ = zero(T)
  for _ in 1:100
    t = a * μ
    n, r1, r2, u2, rmin = 0, zero(T), zero(T), zero(T), T(Inf)
    @inbounds for i in G
      u = abs(v[i])
      r = u - t
      r > 0 || continue
      n += 1
      r1 += r
      r2 += r * r
      u2 += u * u
      rmin = min(rmin, r)
    end
    n == 0 && return μ
    rbar = r1 / n
    m2 = zero(T)
    @inbounds for i in G
      r = abs(v[i]) - t
      r > 0 && (m2 += (r - rbar)^2)
    end
    N = sqrt(r2)                     # ‖soft(v[G], aμ)‖, and h(μ) = N - cμ ≥ 0
    D = c * c * u2 - a * a * n * m2
    if D >= 0                        # ν = μ + δ
      δ = (N - c * μ) * (N + c * μ) / (a * r1 + c * c * μ + sqrt(D))
      a * δ <= rmin && return μ + δ
    end
    μn = μ + (N - c * μ) / (a * r1 / N + c)
    μn > μ || return μ               # rounding
    μ = μn
  end
  μ
end

# ‖soft(t v[G], c)‖₂ for c ≥ 0 and t > 0
function _softnorm(v::AbstractArray{T}, G, c, t = one(T)) where {T}
  c, t = T(c), T(t)
  s = zero(T)
  @inbounds for i in G
    d = t * abs(v[i]) - c
    d > 0 && (s += d * d)
  end
  sqrt(s)
end

function _absmax(v::AbstractArray{T}, G) where {T}
  m = zero(T)
  @inbounds for i in G
    m = max(m, abs(v[i]))
  end
  m
end

####################################
#  λmax and the strong rule
####################################

# The statistic of group k is its root, with weight one: λmax is the largest
# root, and the group is optimal at zero at the level λ when its root is at most
# λ. A group without any penalty has weight zero: it is never zero, and λmax
# leaves it out. A group of weight zero keeps the ℓ1 term when α > 0; its root
# is then ‖∇_G f‖∞/α.
_coordweight(g::_ScaledSGL, ::AtomIterate, k::Int) =
  (f = g.f; T = typeof(f.λ1); iszero(f.λ1) && iszero(f.λ0 * f.w[k]) ? zero(T) : one(T))
_screengrad(g::_ScaledSGL, grad::AbstractArray, x::AtomIterate, k::Int) =
  _sgl_root(grad, x.groups[k], g.f.λ1, g.f.λ0 * g.f.w[k])

# The strong rule keeps group k at μ = 2λₖ - λₖ₋₁ when its root is at least μ,
# that is when ‖soft(∇_G f, αμ)‖₂ ≥ (1 - α)μwₖ (the sequential strong rule of
# Tibshirani et al., 2012, written for the sparse group lasso as in sparsegl);
# with (1 - α)wₖ = 0, when ‖∇_G f‖∞ ≥ αμ. The group violates optimality at λ when
# its root exceeds λ: ‖soft(∇_G f, αλ)‖₂ > (1 - α)λwₖ. Both read one pass over the
# group, without the root.
function _strongkeep(g::_ScaledSGL, grad::AbstractArray, x::AtomIterate, k::Int, μ, w)
  μ > 0 || return true
  G = x.groups[k]
  a, c = g.f.λ1, g.f.λ0 * g.f.w[k]
  iszero(c) && return _absmax(grad, G) >= a * μ
  _softnorm(grad, G, a * μ) >= c * μ
end

_kktviolated(g::_ScaledSGL, grad::AbstractArray, x::AtomIterate, k::Int, λ) =
  _softnorm(grad, x.groups[k], g.f.λ1 * λ) > g.f.λ0 * g.f.w[k] * λ

####################################
#  the dual norm, the gap and gap-safe screening
####################################

_hasdual(::Union{_SGL, _ScaledSGL}) = true

# the thresholds (c1, c2) of group k in g(x) = Σₖ c1‖x_Gₖ‖₁ + c2‖x_Gₖ‖₂
_sglthresholds(g::_SGL, k::Int, ::Type{T}) where {T} = (T(g.λ1), T(g.λ0 * g.w[k]))
_sglthresholds(g::_ScaledSGL, k::Int, ::Type{T}) where {T} = (T(g.α * g.f.λ1), T(g.α * g.f.λ0 * g.f.w[k]))

# The largest t ∈ (0, 1] for which -t z is in the domain of g*: for each group,
# ‖soft(t z_G, c1)‖₂ ≤ c2, that is 1/t at least the root of z_G with (c1, c2). So
# t = min(1, 1/maxₖ rootₖ), the inverse of the dual norm of g at z when it
# exceeds one; only the groups that violate the condition at t = 1 need their
# root. nothing when an index in no group, or a group without penalty, has a
# nonzero gradient.
function _dualscale(g::Union{_SGL, _ScaledSGL}, z::AbstractVector{T}) where {T}
  f = g isa _SGL ? g : g.f
  for i in eachindex(z)        # an index in no group is not penalized
    (i > length(f.group_of) || iszero(f.group_of[i])) && !iszero(z[i]) && return nothing
  end
  _sglscale(g, z, eachindex(f.groups))
end

# the same over the groups ks only, as for the problem restricted to them
_dualscale_on(g::Union{_SGL, _ScaledSGL}, z::AbstractVector, x::AtomIterate, cand::Vector{Int}) = _sglscale(g, z, cand)

function _sglscale(g::Union{_SGL, _ScaledSGL}, z::AbstractVector{T}, ks) where {T}
  f = g isa _SGL ? g : g.f
  t = one(T)
  for k in ks
    G = f.groups[k]
    c1, c2 = _sglthresholds(g, k, T)
    _softnorm(z, G, c1) > c2 || continue
    ρ = _sgl_root(z, G, c1, c2)
    isfinite(ρ) || return nothing
    t = min(t, inv(ρ))
  end
  t
end

# Gap-safe screening of group k (Ndiaye, Fercoq, Gramfort and Salmon, 2016):
# the group is zero at the solution if ‖soft(u, c1)‖₂ < c2 for every u within
# ρ = √(2 gap L_G) of u₀ = t z_G, the image of the dual point, where L_G is the
# curvature over the group (see _gapscreen!). Soft thresholding is
# nonexpansive, so the left side is at most ‖soft(u₀, c1)‖₂ + ρ. When
# ‖u₀‖∞ ≤ c1, it is at most (‖u₀‖∞ + ρ - c1)₊: every entry of u is within its
# move of c1 - (c1 - ‖u₀‖∞), and the move has norm at most ρ. The second bound
# also gives the test of the lasso, c2 = 0: ‖u₀‖∞ + ρ < c1.
function _safezero(g::Union{_SGL, _ScaledSGL}, m, z::AbstractVector, x::AtomIterate, k::Int, t::T, gap::T) where {T}
  c1, c2 = _sglthresholds(g, k, T)
  (c1 > 0 || c2 > 0) || return false
  G = x.groups[k]
  umax = t * _absmax(z, G)
  if umax > c1
    s = _softnorm(z, G, c1, t)
    s < c2 || return false
    s + sqrt(2 * gap * _screencurvature(m, x, k)) < c2
  else
    umax - c1 < c2 || return false
    umax + sqrt(2 * gap * _screencurvature(m, x, k)) - c1 < c2
  end
end
