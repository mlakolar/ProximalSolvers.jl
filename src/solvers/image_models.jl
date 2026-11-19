# The image model of PGD and APG (the data X, Y and the scale read through `leastsquares_data`, and the image X x) and the arithmetic of APG's certified bound. The loss value and gradient at an image come from ProximalBase's predictor oracles. `_SE`, `_se_mul`, `_root_scale`, `_se_norm` and `_sumsq_scaled` below are also used by CD's `response_scale` (src/cd/leastsquares.jl).

using ProximalBase: leastsquares_data, value_from_predictor, value_and_gradient_from_predictor!

struct _LSImage{TY<:AbstractVecOrMat, TX<:AbstractMatrix, A<:Real, T<:AbstractFloat}
  Y::TY
  X::TX
  α::A                  # the scale of a Scaled loss as supplied, one(T) otherwise
end

function _image_model(f)
  d = leastsquares_data(f)
  _LSImage{typeof(d.Y), typeof(d.X), typeof(d.α), eltype(d.X)}(d.Y, d.X, d.α)
end
_image_buffer(m::_LSImage{TY, TX, A, T}) where {TY, TX, A, T} = zeros(T, size(m.Y))
_image!(z, m::_LSImage, x) = mul!(z, m.X, x)
# The image model of PGD for a raw LogisticLoss, which the gate of solve! accepts with PGD only and
# without observation weights or offset (IN-09): Y = f.y, X = f.X and the image z = X x. α is not a
# loss scale but the factor 1/4 of the Hessian bound ∇²f(b) = Xᵀ diag(σᵢ(1 - σᵢ)) X ⪯ ¼ XᵀX, read where
# least squares reads its scale: the initial curvature min(1, α‖X‖_F²) and the recheck
# c = m α ‖fl(X d̂)‖²/‖d̂‖² of a rejected trial (_step_curvature). In exact arithmetic the bound gives,
# for a trial x and the step d = x - u from the last accepted point u, f(x) ≤ f(u) + ⟨∇f(u), d⟩ + ⅛‖X d‖²
# and ⟨∇f(x) - ∇f(u), d⟩ ≤ ¼‖X d‖²; so c ≤ L (m = 1 in function-value mode, m = 2 in gradient mode)
# implies the acceptance test of that mode, and after a rejection c ≥ L̂, TFOCS's estimate, so the
# retry's L is at least TFOCS's (IN-09 has the argument in full).
struct _LogisticImage{TY<:AbstractVector, TX<:AbstractMatrix}
  Y::TY
  X::TX
  α::Float64
end
_image_model(f::LogisticLoss) = _LogisticImage(f.y, f.X, 0.25)
_image_buffer(m::_LogisticImage) = zeros(eltype(m.X), length(m.Y))
_image!(z, m::_LogisticImage, x) = mul!(z, m.X, x)

# The loss value at x: the image z = X x is formed here and the value is ProximalBase's.
_value!(x, f, m, z) = (_image!(z, m, x); convert(_eltype(x), value_from_predictor(f, z)))
# The value at the image z, with G the gradient and d its observation derivative, both written by
# ProximalBase: d = z - Y for least squares and d = σ(z) - Y for a logistic loss.
_value_and_gradient!(G, x, f, z, d) = convert(_eltype(x), value_and_gradient_from_predictor!(G, d, f, z))

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

# aᵢ - bᵢ, and aᵢ where b is nothing (the norm of a)
@inline _diff(a, b, i) = a[i] - b[i]
@inline _diff(a, ::Nothing, i) = a[i]

# Σ (dᵢ / m)² for dᵢ = aᵢ - bᵢ (dᵢ = aᵢ for b = nothing) and m = max|dᵢ| > 0 finite, in [1, length(a)] up to
# rounding: each |dᵢ / m| ≤ 1 and the largest is 1, so the sum is finite
function _sumsq_scaled(a, b, m)
  s = zero(m)
  @inbounds @simd for i in eachindex(a)
    s += abs2(_diff(a, b, i) / m)
  end
  s
end

# The computed ‖a - b‖ of the rounded differences dᵢ = aᵢ - bᵢ (‖a‖ for b = nothing) in the scaled two-pass
# form m √s, m = max|dᵢ|, as an _SE; nothing when a dᵢ is not finite (including an overflowing aᵢ - bᵢ).
function _se_norm(::Type{T}, a, b = nothing) where {T}
  m = T(b === nothing ? _norm_inf(a) : _norm_diff(a, b, Inf))     # NaN when an entry is NaN
  isfinite(m) || return nothing
  iszero(m) && return _se_zero(T)
  _se_mul(_SE{T}(m), _SE{T}(sqrt(_sumsq_scaled(a, b, m))))
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

# ‖a - b‖ of the rounded differences dᵢ = aᵢ - bᵢ (‖a‖ for b = nothing) from s = Σ dᵢ² summed in one pass
# when that sum is finite and at least 4 length(a) floatmin(T): each underflowing square then loses at most
# floatmin(T) u, which is below u s / length(a), so the bound γ_{n+4} on the relative error still
# holds. Otherwise the scaled two-pass form is used (nothing when a dᵢ is not finite).
function _se_norm_onepass(::Type{T}, s, a, b = nothing) where {T}
  isfinite(s) && s >= 4 * length(a) * floatmin(T) && return _SE{T}(sqrt(s))
  _se_norm(T, a, b)
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
  _frobenius_upper(T, X, _sumsq64(X))
end

# The bound above from s = Σ Float64(Xᵢⱼ)², a one-pass sum of the squares in any order, which
# the caller has computed. The argument above applies to any such s.
function _frobenius_upper(::Type{T}, X, s::Float64) where {T}
  N = length(X)
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

# √α as an _SE{T}, for the loss scale α as given: a = Float64(α) = s·2^e with s ∈ [1, 2) (the
# conversion is exact for the Float32, Float64, fixed-width integer and Bool scales that
# `_check_loss_scale` admits). Where e is odd, s is doubled and e lowered by one, so that √a =
# √s′ · 2^(e′/2) with e′ even and the exponent kept in the _SE. An α outside the range of Float64
# is not supported.
function _root_scale(::Type{T}, α) where {T}
  a = Float64(α)
  s, e = significand(a), exponent(a)
  if isodd(e)
    s *= 2
    e -= 1
  end
  r = _SE{T}(sqrt(s))
  _SE{T}(r.s, r.e + e ÷ 2)
end

# The start of the curvature estimate L of PGD and APG for the loss (α/2)‖y - X x‖², from
# rootα, an _SE for √α, and normX, an _SE for an upper bound on ‖X‖_F (the bound of
# _frobenius_upper, rounded up). It is min(1, r²) for r = rootα normX, formed in _SE and
# rounded to T once, so that r² estimates α‖X‖_F² from above up to rounding. It is one(T)
# when r² ≥ 1, decided in _SE without converting to T, and when X = 0 (r = 0, where
# L = 0 is invalid). A positive r² that rounds to T below floatmin(T) gives floatmin(T),
# which is then above r².
function _initial_curvature(::Type{T}, rootα::_SE{T}, normX::_SE{T}) where {T}
  r = _se_mul(rootα, normX)
  iszero(r.s) && return one(T)
  b = _se_mul(r, r)
  _se_le(_SE{T}(one(T)), b) && return one(T)
  max(floatmin(T), T(ldexp(b.s, b.e)))
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

function _bound_constants(::Type{T}, X, normX) where {T}
  n, p = size(X)
  u = _unit(T)
  δn, δp, γp = _gamma(T, n + 4), _gamma(T, p + 4), _gamma(T, p)
  κ = 32u
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
    N = _se_norm_onepass(T, _sumsq_diff(zw, zu), zw, zu)
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
