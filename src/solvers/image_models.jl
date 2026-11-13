# Historical LS image evaluation; no exceptional-range recovery is added.

struct _LSImage{TY<:AbstractVecOrMat, TX<:AbstractMatrix, A<:Real, T<:AbstractFloat}
  Y::TY
  X::TX
  α::A                  # the scale of a Scaled loss, one otherwise
end

_LSImage(f::LeastSquaresLoss{T}, α::Real) where {T} = _LSImage{typeof(f.Y), typeof(f.X), typeof(α), T}(f.Y, f.X, α)
_image_model(f::LeastSquaresLoss) = _LSImage(f, true)
_image_model(f::Scaled{<:LeastSquaresLoss}) = _LSImage(f.f, f.α)
_image_buffer(m::_LSImage{TY, TX, A, T}) where {TY, TX, A, T} = zeros(T, size(m.Y))
_image!(z, m::_LSImage, x) = mul!(z, m.X, x)
_value!(x, m, z) = (_image!(z, m, x); convert(_eltype(x), _image_value(m, z)))
_value_and_gradient!(G, x, m, z, d) = convert(_eltype(x), _image_value_and_gradient!(G, m, z, d))
function _image_value(m::_LSImage{TY, TX, A, T}, z) where {TY, TX, A, T}
  Y = m.Y
  v = zero(T)
  @inbounds @simd for i in eachindex(z, Y)
    v += abs2(Y[i] - z[i])
  end
  m.α * (v / 2)
end

function _image_value_and_gradient!(G, m::_LSImage, z, d)
  d .= z .- m.Y
  mul!(G, transpose(m.X), d)
  v = sum(abs2, d) / 2
  G .*= m.α
  m.α * v
end

# ---- The accelerated method's certified backtracking test ----------------------------
#
# Nonnegative reals carried as s·2^e, s ∈ [1, 2) of type T and e an Int (zero as s = 0),
# so that products and sums of norms neither overflow nor lose precision to subnormal
# rounding in T. Only significands in [0, 4) are ever multiplied or added.
struct _SE{T}
  s::T
  e::Int
end
_se_zero(::Type{T}) where {T} = _SE{T}(zero(T), 0)
_renormal(s::T, e::Int) where {T} = iszero(s) ? _se_zero(T) : _SE{T}(significand(s), e + exponent(s))
# x finite and nonnegative, of any floating-point type; its significand is rounded to T
_SE{T}(x::AbstractFloat) where {T} = iszero(x) ? _se_zero(T) : _renormal(T(significand(x)), exponent(x))
_se_mul(a::_SE{T}, b::_SE{T}) where {T} =
  iszero(a.s) || iszero(b.s) ? _se_zero(T) : _renormal(a.s * b.s, a.e + b.e)
# fixed arities rather than a vararg: Julia 1.10 compiles the 4-argument vararg call to a dynamic, allocating splat
_se_mul(a::_SE, b::_SE, c::_SE) = _se_mul(_se_mul(a, b), c)
_se_mul(a::_SE, b::_SE, c::_SE, d::_SE) = _se_mul(_se_mul(a, b, c), d)
_se_le(a::_SE, b::_SE) = iszero(a.s) || (!iszero(b.s) && (a.e < b.e || (a.e == b.e && a.s <= b.s)))
function _se_add(a::_SE{T}, b::_SE{T}) where {T}
  iszero(a.s) && return b
  iszero(b.s) && return a
  a.e < b.e && ((a, b) = (b, a))
  _renormal(a.s + ldexp(b.s, b.e - a.e), a.e)
end
# max(a - b, 0)
function _se_sub(a::_SE{T}, b::_SE{T}) where {T}
  iszero(b.s) && return a
  _se_le(a, b) && return _se_zero(T)
  _renormal(a.s - ldexp(b.s, b.e - a.e), a.e)     # a > b > 0, so a.e ≥ b.e
end

# Σ (vᵢ / m)² for m = max|vᵢ| > 0, in [1, length(v)]
function _sumsq_scaled(v, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(v)
    s += abs2(v[i] / m)
  end
  s
end

# Σ ((aᵢ - bᵢ) / m)² for m = max|aᵢ - bᵢ| > 0
function _sumsq_scaled_diff(a, b, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(a, b)
    s += abs2((a[i] - b[i]) / m)
  end
  s
end

# The computed ‖v‖ (v a vector or matrix of T) in the scaled two-pass form m √s, m = max|vᵢ|,
# as an _SE; nothing when an entry is not finite.
function _se_norm(::Type{T}, v) where {T}
  m = T(maximum(abs, v))           # NaN when an entry is NaN
  isfinite(m) || return nothing
  iszero(m) && return _se_zero(T)
  _se_mul(_SE{T}(m), _SE{T}(sqrt(_sumsq_scaled(v, m))))
end

# The computed ‖a - b‖ of the rounded differences aᵢ - bᵢ
function _se_norm_diff(::Type{T}, a, b) where {T}
  m = _maxabs_diff(a, b)
  isfinite(m) || return nothing
  iszero(m) && return _se_zero(T)
  s = _sumsq_scaled_diff(a, b, m)
  isfinite(s) || return nothing
  _se_mul(_SE{T}(m), _SE{T}(sqrt(s)))
end

# Σ dᵢ² and Σ xᵢ² in one pass
function _sumsq2(d, x)
  sd, sx = zero(eltype(d)), zero(eltype(x))
  @inbounds @simd for i in eachindex(d, x)
    sd += abs2(d[i])
    sx += abs2(x[i])
  end
  sd, sx
end

# Σ (aᵢ - bᵢ)² in one pass
function _sumsq_diff(a, b)
  s = zero(eltype(a))
  @inbounds @simd for i in eachindex(a, b)
    s += abs2(a[i] - b[i])
  end
  s
end

# ‖v‖ from s = Σ vᵢ² summed in one pass when that sum is finite and at least
# 4 length(v) floatmin(T): each underflowing square then loses less than floatmin(T) u,
# which is below u s / length(v), so the bound γ_{n+4} on the relative error still holds.
# Otherwise the scaled two-pass form is used.
function _se_norm_onepass(::Type{T}, s, v) where {T}
  isfinite(s) && s >= 4 * length(v) * floatmin(T) && return _SE{T}(sqrt(s))
  _se_norm(T, v)
end
function _se_norm_diff_onepass(::Type{T}, s, a, b) where {T}
  isfinite(s) && s >= 4 * length(a) * floatmin(T) && return _SE{T}(sqrt(s))
  _se_norm_diff(T, a, b)
end

# u, the unit roundoff, and γₖ = k u / (1 - k u), which bounds the relative error of k
# rounded operations (k u < 1/8 is checked before a solve, see _check_bound_size).
_unit(::Type{T}) where {T} = eps(T) / 2
_gamma(::Type{T}, k) where {T} = (ku = k * _unit(T); ku / (1 - ku))

# An upper bound on ‖X‖_F as an _SE. Float32 data: the squares are exact in Float64 and
# their sum cannot overflow there, so s = Σ Float64(Xᵢⱼ)² summed in one pass satisfies
# s ≥ (1 - γ_N) ‖X‖_F² (N = n p). Float64 data: the same one-pass sum when it is finite and
# at least 4N floatmin (underflowing squares then cost less than u relative); otherwise the
# entries are scaled by the exact power of two 2^-e, e = exponent(max|Xᵢⱼ|), with ldexp
# (exact except for underflow below N·nextfloat(0.0) in total), so that each scaled entry
# is below 2 and the sum Σ(Xᵢⱼ 2^-e)² is finite (γ_{N+1}), and the result is multiplied by
# 2^e as an _SE exponent. The square root and the conversion to T are rounded up by explicit
# factors; γ_{N+3} covers every branch.
function _frobenius_upper(::Type{T}, X) where {T}
  N = length(X)
  s = 0.0
  @inbounds @simd for i in eachindex(X)
    s += abs2(Float64(X[i]))
  end
  iszero(s) && all(iszero, X) && return _se_zero(T)
  e = 0
  if !(isfinite(s) && (T === Float32 || s >= 4N * floatmin(Float64)))
    e = exponent(Float64(maximum(abs, X)))
    s = 0.0
    @inbounds for i in eachindex(X)
      s += abs2(ldexp(Float64(X[i]), -e))
    end
  end
  s_upper = (s + N * nextfloat(0.0)) / (1 - _gamma(Float64, N + 3))
  r = _se_mul(_SE{T}(sqrt(s_upper) * (1 + eps(Float64))), _SE{T}(one(T) + 8 * _unit(T)))
  _SE{T}(r.s, r.e + e)
end

# √α as an _SE{T}, for the loss scale α as given: α = s·2^e with s ∈ [1, 2). For an IEEE
# Float16/32/64 scale, s and e are exact in its own type. For any other real type (BigFloat
# of any precision, integers, rationals, irrationals), α is rounded once to 256 bits and s
# and e are taken there, inside a scoped BigFloat precision that is restored afterwards, so
# the active precision plays no part. s is rounded once to Float64 (at least the precision
# of T) before its square root, and e made even, so √α = √s′ · 2^(e′/2) without range loss.
_significand_exponent(α::Union{Float16, Float32, Float64}) = (Float64(significand(α)), exponent(α))
_significand_exponent(α::Real) = setprecision(BigFloat, 256) do
  b = BigFloat(α)
  (Float64(significand(b)), exponent(b))
end

function _root_scale(::Type{T}, α) where {T}
  s, e = _significand_exponent(α)
  if isodd(e)
    s *= 2
    e -= 1
  end
  r = _SE{T}(sqrt(s))
  _SE{T}(r.s, r.e + e ÷ 2)
end

# Constants of the bound test that depend only on n, p, T and ‖X‖_F, formed once per solve.
# η = nextfloat(zero(T)), at least twice the largest absolute error of an underflowing
# product, models gradual underflow: fl(a ∘ b) = (a ∘ b)(1 + δ) + η', |δ| ≤ u, |η'| ≤ η/2.
struct _BoundConstants{T}
  upper_image::_SE{T}        # computed ‖Δz‖ → upper bound on ‖Δz‖ (stored differences)
  lower_image::_SE{T}        # computed ‖Δz‖ → lower bound
  lower_step::_SE{T}        # computed ‖d̂‖ → lower bound on ‖d‖
  upper_step::_SE{T}        # computed ‖d̂‖ → upper bound on ‖d‖ and ‖d̂‖
  upper_fresh::_SE{T}        # computed ‖fl(X d̂)‖ → upper bound
  upper_x::_SE{T}        # computed iterate norm → upper bound
  accept::_SE{T}         # (1 + 4eps)/(1 + κ)
  reject::_SE{T}         # (1 + 4eps)(1 + κ)
  product::_SE{T}        # γ_p ‖X‖_F: relative error of a fresh product, per ‖v‖
  fresh::_SE{T}          # (γ_p + 2u) ‖X‖_F: error of fl(X d̂) against X d, per ‖d̂‖
  extrapolation::_SE{T}  # (2γ_p + 16u) ‖X‖_F: extrapolated image, per ‖x_a‖ + ‖x_b‖
  under_product::_SE{T}  # 2p √n η: absolute underflow of a fresh product
  under_extrapolation::_SE{T}  # 8p √n η + 2√p ‖X‖_F η: of an extrapolated image and y
end

function _bound_constants(::Type{T}, X) where {T}
  n, p = size(X)
  u = _unit(T)
  δn, δp, γp = _gamma(T, n + 4), _gamma(T, p + 4), _gamma(T, p)
  κ = 32u
  normX = _frobenius_upper(T, X)
  η = _SE{T}(nextfloat(zero(T)))
  rn, rp = _SE{T}(sqrt(T(n))), _SE{T}(sqrt(T(p)))
  _BoundConstants{T}(_SE{T}(inv((1 - δn) * (1 - u))), _SE{T}(inv((1 + δn) * (1 + u))),
    _SE{T}(inv((1 + δp) * (1 + u))), _SE{T}(inv((1 - δp) * (1 - u))), _SE{T}(inv(1 - δn)),
    _SE{T}(inv(1 - δp)), _SE{T}((1 + 4eps(T)) / (1 + κ)), _SE{T}((1 + 4eps(T)) * (1 + κ)),
    _se_mul(_SE{T}(γp), normX), _se_mul(_SE{T}(γp + 2u), normX),
    _se_mul(_SE{T}(2γp + 16u), normX),
    _se_mul(_SE{T}(T(2p)), rn, η),
    _se_add(_se_mul(_SE{T}(T(8p)), rn, η), _se_mul(_SE{T}(T(2)), rp, normX, η)))
end

# Whether the least-squares bound
#     f(x) ≤ f(y) + ⟨∇f(y), d⟩ + L‖d‖²/2,  d = x - y ≠ 0,   ⟺   √α ‖X d‖ ≤ √L ‖d‖,
# relaxed to √α ‖X d‖ ≤ (1 + 4eps) √L ‖d‖ (legacy's slack 8eps on L), is certified for the
# stored x and y, D being the computed ‖d̂‖ and normx the computed ‖x‖ as _SE. Returns
# (accepted, used the fresh product).
#
# The bounds assume IEEE arithmetic with gradual underflow and a matrix-vector product that
# evaluates each entry as a dot product in some order of p multiplications and additions
# (or fused multiply-adds), so that |fl(X v) - X v| ≤ γ_p |X||v| + 2p η componentwise; then
# ‖fl(X v) - X v‖ ≤ γ_p ‖X‖_F ‖v‖ + 2p √n η. Cheap path: Δz = zw - zu, the difference of the
# cached images zw = fl(X x) and zu ≈ X y, with ‖Δz - X d‖ ≤ E = (that bound for x) + Ey
# (the bound on the error of zu, see _image_error_bound). With the evaluation error of the
# computed norms (γ_{n+4}, γ_{p+4}) and ‖d̂ - d‖ ≤ u‖d‖ (d̂ = fl(x - y); a subnormal
# difference is exact), the bound is accepted when it holds with ‖X d‖ replaced by an upper
# bound, and rejected when it fails with a lower bound. Otherwise X d̂ is formed afresh in
# buf, with ‖fl(X d̂) - X d‖ ≤ (γ_p + 2u)‖X‖_F ‖d̂‖ + 2p √n η, and the trial is accepted only
# when the bound holds with that upper bound; an ambiguous trial is rejected. ‖X‖_F and the
# iterate norms enter as proved upper bounds. κ = 32u covers the roundings of √L, of √α's
# conversion and of the fixed number of _SE products and sums on each side. The data norms
# and products are carried as _SE, so their range does not limit the decision; the native
# product, the extrapolation and the one-pass sums are outside _SE and enter through the
# bounds above (a one-pass sum is used only when it is finite and at least 4n floatmin(T)).
function _bound_certified!(buf, model::_LSImage, zu, zw, d, D::_SE{T}, L, Ey::_SE{T},
                           normx::_SE{T}, rootα::_SE{T}, c::_BoundConstants{T},
                           fresh_only::Bool) where {T}
  !iszero(D.s) && L > 0 || return false, false
  rootL = _SE{T}(sqrt(L))
  accept_rhs = _se_mul(c.accept, rootL, c.lower_step, D)
  if !fresh_only
    N = _se_norm_diff_onepass(T, _sumsq_diff(zw, zu), zw, zu)
    if N !== nothing
      E = _se_add(_se_add(_se_mul(c.product, c.upper_x, normx), c.under_product), Ey)
      upper = _se_add(_se_mul(N, c.upper_image), E)
      _se_le(_se_mul(rootα, upper), accept_rhs) && return true, false
      lower = _se_sub(_se_mul(N, c.lower_image), E)
      _se_le(_se_mul(rootα, lower), _se_mul(c.reject, rootL, c.upper_step, D)) || return false, false
    end
  end
  mul!(buf, model.X, d)
  W = _se_norm_onepass(T, sum(abs2, buf), buf)
  W === nothing && return false, true
  Ew = _se_add(_se_mul(c.fresh, c.upper_step, D), c.under_product)
  upper = _se_add(_se_mul(W, c.upper_fresh), Ew)
  _se_le(_se_mul(rootα, upper), accept_rhs), true
end

# Error bound of the cached image zu ≈ X y of the current step: a fresh product of x_a
# (first step and after a restart: y = x_a, zu = fl(X x_a)), or the extrapolation
# zu = fl(z_a + ω(z_a - z_b)) of the fresh products z_a = fl(X x_a), z_b = fl(X x_b) with
# y = fl(x_a + ω(x_a - x_b)), 0 < ω ≤ 1 (the computed ω can round to 1). With
# ‖z‖ ≤ (1 + γ_p)‖X‖_F‖x‖ + 2p√n η and three roundings in each combination (one of them a
# product that can underflow), (2γ_p + 16u)‖X‖_F(‖x_a‖ + ‖x_b‖) plus
# 8p√n η + 2√p ‖X‖_F η bounds the errors of both images, the image error of the rounded y
# and the roundings of both combinations. normxa, normxb are computed norms (made upper
# bounds here).
function _image_error_bound(c::_BoundConstants{T}, normxa::_SE{T}, normxb::_SE{T},
                            extrapolated::Bool) where {T}
  extrapolated ||
    return _se_add(_se_mul(c.product, c.upper_x, normxa), c.under_product)
  _se_add(_se_mul(c.extrapolation, c.upper_x, _se_add(normxa, normxb)), c.under_extrapolation)
end

# ---- The proximal gradient method's check of a backtracking rejection ----------------

# √(2^k α) as an _SE{T}, for the loss scale α as given and an integer k: the significand and
# exponent of α are taken as in _root_scale(T, α), k is added to the exponent, which is exact,
# and the root is formed as there. For k = 0 the result is _root_scale(T, α).
function _root_scale(::Type{T}, α, k::Int) where {T}
  s, e = _significand_exponent(α)
  e += k
  if isodd(e)
    s *= 2
    e -= 1
  end
  r = _SE{T}(sqrt(s))
  _SE{T}(r.s, r.e + e ÷ 2)
end

# a / b for b ≠ 0, with one rounding of the significand quotient, which lies in (1/2, 2)
_se_div(a::_SE{T}, b::_SE{T}) where {T} = iszero(a.s) ? _se_zero(T) : _renormal(a.s / b.s, a.e - b.e)

# The value of a as a T at least a: Inf above floatmax(T); a value that ldexp rounds below a
# (possible when the result is subnormal) is replaced by the next float.
function _se_float_up(a::_SE{T}) where {T}
  iszero(a.s) && return zero(T)
  r = ldexp(a.s, a.e)
  isfinite(r) || return r
  ldexp(r, -a.e) < a.s ? nextfloat(r) : r
end

# For an upper bound `upper` on ‖X d‖ formed as in _bound_certified!, with the same D,
# scale root and constants, a T value U such that (a) U ≥ s ‖X d‖²/‖d‖² for the scale s whose
# root is `rootscale`, and (b) the acceptance comparison of _bound_certified! with this
# `upper` holds for every stored L ≥ U. U = s′ (upper / (accept lower_step D))² with the
# computed s′ = rootscale², rounded up by the factor 1 + 64u. The product rootscale·upper is
# the comparison's left side; the factor covers the five roundings after it, the roundings
# of the comparison's right side and of √L, the slack (1 + 4eps)² of the bound and the
# relative spacing 2u of normal floats; below 2 floatmin(T) two steps of η are added for the
# absolute spacing η of subnormal floats. Inf when U exceeds floatmax(T), or when D = 0.
function _curvature_cap(upper::_SE{T}, D::_SE{T}, rootscale::_SE{T}, c::_BoundConstants{T}) where {T}
  iszero(D.s) && return T(Inf)
  q = _se_div(_se_mul(rootscale, upper), _se_mul(c.accept, c.lower_step, D))
  U = _se_float_up(_se_mul(q, q, _SE{T}(one(T) + 64 * _unit(T))))
  U < 2 * floatmin(T) ? nextfloat(U, 2) : U
end

# The cap of a trial that _bound_certified!(buf, model, zu, zw, d, D, L, Ey, normx, rootscale,
# c, false) did not accept, from the upper bound of its upper-bound acceptance comparison: the fresh
# W = ‖fl(X d̂)‖ in buf when `fresh`, and otherwise N = ‖zw - zu‖, recomputed. Returns
# (U, loose). loose is true when the cached path's error E exceeds N lower_image/64 or N is
# not finite; U may then be far above s ‖X d‖²/‖d‖², and a fresh product can give a tighter
# bound.
function _curvature_upper(buf, zu, zw, D::_SE{T}, Ey::_SE{T}, normx::_SE{T}, rootscale::_SE{T},
                          c::_BoundConstants{T}, fresh::Bool) where {T}
  if fresh
    W = _se_norm_onepass(T, sum(abs2, buf), buf)
    W === nothing && return T(Inf), false
    Ew = _se_add(_se_mul(c.fresh, c.upper_step, D), c.under_product)
    return _curvature_cap(_se_add(_se_mul(W, c.upper_fresh), Ew), D, rootscale, c), false
  end
  N = _se_norm_diff_onepass(T, _sumsq_diff(zw, zu), zw, zu)
  N === nothing && return T(Inf), true
  E = _se_add(_se_add(_se_mul(c.product, c.upper_x, normx), c.under_product), Ey)
  upper = _se_add(_se_mul(N, c.upper_image), E)
  loose = !_se_le(_se_mul(E, _SE{T}(T(64))), _se_mul(N, c.lower_image))
  _curvature_cap(upper, D, rootscale, c), loose
end

# The size condition of the bound's error analysis: k u < 1/8 for k = max(n, p) + 4 in T and
# for k = n p + 3 in Float64, where ‖X‖_F is accumulated.
_bound_size_ok(::Type{T}, n, p) where {T} =
  (max(n, p) + 4) * _unit(T) < 1 / 8 && (n * p + 3) * _unit(Float64) < 1 / 8
