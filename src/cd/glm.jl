####################################
#
#  generalized linear losses  s ∑ᵢ wᵢ ℓ(ηᵢ, yᵢ),  η = Xβ + β₀ + o
#
####################################

# The model of a GLMLoss: the scalar loss ℓ with its data, and the linear
# predictor η = Xβ + β₀ + o as the cache. Coordinate descent takes the steps of
# the curvature bound s sup ℓ'' ∑ᵢ wᵢ Xᵢₖ², which majorize the loss along the
# coordinate, so that a step costs O(n); it needs a loss with a bounded
# curvature (Logistic, Huber) and no intercept. ProxNewton converges much
# faster on these losses, and also takes a loss with an unbounded curvature
# (Poisson) and an unpenalized intercept β₀ (`intercept = true`), which is zero
# otherwise.
mutable struct GLMModel{T<:AbstractFloat, L, MX<:AbstractMatrix{T}, VY<:AbstractVector{T},
                        W<:Union{Nothing, AbstractVector{T}}, O<:Union{Nothing, AbstractVector{T}}} <: CDModel{T}
  loss::L
  X::MX
  y::VY
  w::W
  offset::O
  s::T
  bound::T              # sup ℓ'', Inf for a loss without a bound
  η::Vector{T}          # Xβ + β₀ + o
  a::Vector{T}          # s sup ℓ'' ∑ᵢ wᵢ Xᵢₖ², NaN until computed
  d::Vector{T}          # wᵢ ℓ'(ηᵢ, yᵢ), for the gradient
  intercept::Bool       # whether the loss is minimized over an unpenalized β₀ too
  β0::T
end

function GLMModel(loss, y, X, w, offset, s; intercept::Bool = false)
  T = float(promote_type(eltype(y), eltype(X)))
  bound = T(ProximalBase.curvature(loss))
  Xt, yt = convert(AbstractMatrix{T}, X), convert(AbstractVector{T}, y)
  wt = w === nothing ? nothing : convert(AbstractVector{T}, w)
  ot = offset === nothing ? nothing : convert(AbstractVector{T}, offset)
  _check_finite(yt, "y"); _check_finite(Xt, "X")
  intercept && wt !== nothing && !(sum(wt) > 0) &&
    throw(ArgumentError("an intercept needs weights with a positive sum"))
  n, p = size(Xt)
  GLMModel{T, typeof(loss), typeof(Xt), typeof(yt), typeof(wt), typeof(ot)}(loss, Xt, yt, wt, ot, T(s), bound,
                                                                             zeros(T, n), fill(T(NaN), p), zeros(T, n),
                                                                             intercept, zero(T))
end

cdmodel(f::GLMLoss, x; intercept::Bool = false) = GLMModel(f.loss, f.y, f.X, f.weights, f.offset, 1; intercept)
cdmodel(f::Scaled{<:GLMLoss}, x; intercept::Bool = false) =
  GLMModel(f.f.loss, f.f.y, f.f.X, f.f.weights, f.f.offset, f.α; intercept)

# coordinate descent needs a bounded curvature for its steps, and moves only the
# coordinates of x, not an intercept
function check_penalty(m::GLMModel, g)
  isfinite(m.bound) ||
    throw(ArgumentError("the curvature of $(typeof(m.loss)) is unbounded, so coordinate descent has no step size; use ProxNewton."))
  m.intercept && throw(ArgumentError("coordinate descent does not fit the intercept of a GLMModel; use ProxNewton."))
  nothing
end

intercept(m::GLMModel, x::AbstractArray) = m.β0

_default_iterate(m::GLMModel{T}) where {T} = SparseIterate(T, size(m.X, 2))

"""
    linear_predictor(m::CDModel)

The linear predictor `η = Xβ + β₀ + o` of a GLM model, for the iterate it is
current for.
"""
linear_predictor(m::GLMModel) = m.η

"""
    deviance(m::CDModel)

The deviance `2 ∑ᵢ wᵢ (ℓ(ηᵢ, yᵢ) - minᵤ ℓ(u, yᵢ))` of a GLM model at its linear
predictor (see [`linear_predictor`](@ref)), with the observation weights `wᵢ`
but without the scale `s` of the loss: twice the negative log-likelihood ratio
against the saturated model for the logistic and Poisson losses, twice the
weighted sum of squares or of the Huber losses for those. `NaN` for a scalar
loss whose saturated loss is unknown.
"""
deviance(m::GLMModel) = _deviance(m, m.η)

"""
    nulldeviance(m::CDModel)

The [`deviance`](@ref) of the fit with `β = 0`: the offset, plus the intercept
fitted to it when the model has one.
"""
nulldeviance(m::GLMModel) = _null_deviance(m)

@inline _obsweight(::Nothing, i::Int, ::Type{T}) where {T} = one(T)
@inline _obsweight(w::AbstractVector, i::Int, ::Type{T}) where {T} = @inbounds w[i]

# η = Xx + o, without the intercept
function _predictor!(m::GLMModel{T}, x::SparseIterate{T}) where {T}
  length(x) == size(m.X, 2) || throw(DimensionMismatch("x has length $(length(x)) and X has $(size(m.X, 2)) columns"))
  m.offset === nothing ? fill!(m.η, zero(T)) : copyto!(m.η, m.offset)
  for k in activecoordinates(x)
    v = x[k]
    iszero(v) || _column_axpy!(m.η, m.X, k, zero(T), -v)
  end
  m.η
end

# With an intercept, initialize! also fits the intercept for x, from the current
# one, so that a solution at a level of a path starts from the right β₀
function initialize!(m::GLMModel{T}, x::SparseIterate{T}) where {T}
  _predictor!(m, x)
  if m.intercept
    m.β0 = _fit_intercept(m, m.β0)
    m.η .+= m.β0
  end
  fill!(m.a, T(NaN))
  m
end

# the minimizer over c of s ∑ᵢ wᵢ ℓ(ηᵢ + c, yᵢ), with η = m.η, by Newton's
# method with step halving from c; a minimizer at infinity (a logistic response
# that is all zeros or all ones) gives a large finite c
function _fit_intercept(m::GLMModel{T}, c::T) where {T}
  loss, y, w, η = m.loss, m.y, m.w, m.η
  φ(c) = _glmvalue(loss, y, w, one(T), η, c)
  fc = φ(c)
  for _ in 1:100
    G, H = zero(T), zero(T)
    @inbounds for i in eachindex(η)
      wi = _obsweight(w, i, T)
      iszero(wi) && continue
      G += wi * T(ProximalBase.deriv(loss, η[i] + c, y[i]))
      H += wi * T(ProximalBase.deriv2(loss, η[i] + c, y[i]))
    end
    (H > 0 && isfinite(G) && isfinite(H)) || break
    step = G / H
    t = one(T)
    cnew = c - step
    fnew = φ(cnew)
    while !(fnew <= fc) && t > 1e-10
      t /= 2
      cnew = c - t * step
      fnew = φ(cnew)
    end
    t > 1e-10 || break
    done = abs(cnew - c) <= 10 * eps(T) * max(abs(cnew), one(T))
    c, fc = cnew, fnew
    done && break
  end
  # near the minimizer the values no longer resolve it (to about √eps), which
  # leaves Σᵢ wᵢ ℓ'(ηᵢ + c) away from zero, the constraint of the dual point of
  # the duality gap; Newton steps on the derivative, kept while they shrink
  # it, reach the precision
  G, H = _intercept_derivatives(m, c)
  for _ in 1:3
    (H > 0 && isfinite(G) && isfinite(H) && !iszero(G)) || break
    cnew = c - G / H
    Gnew, Hnew = _intercept_derivatives(m, cnew)
    abs(Gnew) < abs(G) || break
    c, G, H = cnew, Gnew, Hnew
  end
  c
end

function _intercept_derivatives(m::GLMModel{T}, c::T) where {T}
  loss, y, w, η = m.loss, m.y, m.w, m.η
  G, H = zero(T), zero(T)
  @inbounds for i in eachindex(η)
    wi = _obsweight(w, i, T)
    iszero(wi) && continue
    G += wi * T(ProximalBase.deriv(loss, η[i] + c, y[i]))
    H += wi * T(ProximalBase.deriv2(loss, η[i] + c, y[i]))
  end
  G, H
end

function _curvaturebound!(m::GLMModel{T}, k::Int) where {T}
  a = m.a[k]
  if isnan(a)
    a = _weighted_sqnorm(m.X, m.w, k)
    a *= m.s * m.bound
    m.a[k] = a
  end
  a
end

# ∑ᵢ wᵢ Xᵢₖ², over the nonzeros for a sparse X
function _weighted_sqnorm(X::AbstractMatrix{T}, w, k::Int) where {T}
  a = zero(T)
  @inbounds for i in axes(X, 1)
    a += _obsweight(w, i, T) * X[i, k] * X[i, k]
  end
  a
end

function _weighted_sqnorm(X::SparseMatrixCSC{T}, w, k::Int) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  a = zero(T)
  @inbounds for j in nzrange(X, k)
    a += _obsweight(w, rows[j], T) * vals[j] * vals[j]
  end
  a
end

@inline function coordinate_derivatives(m::GLMModel{T}, x::SparseIterate{T}, k::Int) where {T}
  X, η, y = m.X, m.η, m.y
  G = zero(T)
  @inbounds for i in eachindex(η)
    wi = _obsweight(m.w, i, T)
    iszero(wi) && continue
    G += wi * T(ProximalBase.deriv(m.loss, η[i], y[i])) * X[i, k]
  end
  m.s * G, _curvaturebound!(m, k)
end

# a sparse X: ℓ' only at the nonzeros of the column
@inline function coordinate_derivatives(m::GLMModel{T, L, <:SparseMatrixCSC}, x::SparseIterate{T}, k::Int) where {T<:AbstractFloat, L}
  X, η, y = m.X, m.η, m.y
  rows, vals = rowvals(X), nonzeros(X)
  G = zero(T)
  @inbounds for j in nzrange(X, k)
    i = rows[j]
    wi = _obsweight(m.w, i, T)
    iszero(wi) && continue
    G += wi * T(ProximalBase.deriv(m.loss, η[i], y[i])) * vals[j]
  end
  m.s * G, _curvaturebound!(m, k)
end

update_cache!(m::GLMModel{T}, x::SparseIterate{T}, k::Int, h::T) where {T} = (_column_axpy!(m.η, m.X, k, zero(T), -h); m)

# η = Xβ + o is affine in β, and the derivatives are computed from it
_cache(m::GLMModel) = m.η

coordinate_scale(m::GLMModel, x, k::Int) = sqrt(_curvaturebound!(m, k))

# as √(s ∑ᵢ wᵢ yᵢ²) for least squares: the scale of the derivatives at the
# offset, relative to the curvature
function response_scale(m::GLMModel{T}, x) where {T}
  v = zero(T)
  @inbounds for i in eachindex(m.y)
    wi = _obsweight(m.w, i, T)
    iszero(wi) && continue
    oi = m.offset === nothing ? zero(T) : m.offset[i]
    v += wi * T(ProximalBase.deriv(m.loss, oi, m.y[i]))^2
  end
  sqrt(m.s * v / m.bound)
end

loss_value(m::GLMModel, x) = _glmvalue(m.loss, m.y, m.w, m.s, m.η)

function gradient!(G::AbstractVector{T}, m::GLMModel{T}, x) where {T}
  @inbounds for i in eachindex(m.η)
    wi = _obsweight(m.w, i, T)
    m.d[i] = iszero(wi) ? zero(T) : wi * T(ProximalBase.deriv(m.loss, m.η[i], m.y[i]))
  end
  mul!(G, transpose(m.X), m.d)
  G .*= m.s
end

####################################
#  proximal Newton
####################################

"""
    ProxNewton(; inner = CDSolver(; tol = 1e-8), maxiter = 100, tol = 1e-8, β = 0.5)

Proximal Newton for `f(x) + g(x)`, `f` a `GLMLoss` (or a scaled one) and `g`
a separable penalty, as glmnet fits generalized linear models: each step
minimizes the quadratic model of `f` at `x`, a weighted least-squares loss with
the weights `wᵢℓ''(ηᵢ)` and the working responses `ηᵢ - ℓ'(ηᵢ)/ℓ''(ηᵢ)`, plus
`g`, by coordinate descent (`inner`) warm started from `x`, and then backtracks
along the step on `f + g`, shrinking it by `β`, until the objective decreases.
For the nonconvex MCP and SCAD, whose coordinate problems are convex only where
the curvature of the model exceeds their concavity (`ρ = 1/a`, `1/(a - 1)`), a
step that does not decrease the objective is taken again with the proximal
term `ρ‖x - xₖ‖²`, which makes it a descent step without changing the fixed
points (the stationary points of `f + g`).
Without a duality gap, the steps stop when the objective changes by at most
`tol` relative to `max(|F|, 1)` and the original problem is stationary to the
matching accuracy: every exact coordinate step of `f + g` at `x` (and the
intercept step, when fitted), measured as `√aⱼ |Δⱼ|` with `aⱼ` the curvature of
coordinate `j` in the Newton model at `x`, is at most `√tol` times the same
measure of the Newton step available at the starting predictor. The square of
this measure is about the decrease of `f + g` the step still offers, so the
test matches `tol`, and it does not change when `f` is scaled or a constant is
added to it. The method also stops after
`maxiter` steps, with `converged = false`. Use with [`solve!`](@ref) on a `SparseIterate`;
returns [`CDResults`](@ref), whose `passes` sum the inner passes.

`f` may also be the model of a `GLMLoss` built with
`cdmodel(f, x; intercept = true)`, which fits an unpenalized intercept `β₀`
as well, as the intercept of the weighted least-squares model of each step:
`η = Xβ + β₀ + o`. The model keeps `β₀` (read it with `intercept(m, x)`) and
starts the next solve from it. [`solve_path`](@ref) takes `ProxNewton` too.

For the graphical lasso, `f` a `LogDetLoss(S, w)` (or a scaled one) and `g` a
`NormL1` (a matrix of weights leaves, for example, the diagonal free), it is
QUIC (Hsieh, Sustik, Dhillon and Ravikumar, *QUIC: quadratic approximation for
sparse inverse covariance estimation*, 2014), on a `SymmetricSparseIterate` or
a dense symmetric matrix `X`. Each step minimizes the second-order model
`w (tr(WΔWΔ)/2 + tr((S - W)Δ)) + g(X + Δ)`, `W = X⁻¹`, by coordinate descent
over the free set (the entries that are nonzero or whose gradient exceeds the
penalty), with up to `2 (1 + k ÷ 3)` passes at step `k`, and the Armijo line
search keeps `X` positive definite. The solution is block diagonal along the
connected components of the graph of the entries with `w |Sᵢⱼ|` above the
penalty, so each component is solved on its own. It stops when the relative
duality gap (see [`duality_gap`](@ref)) is at most `tol`, which the `gap` of
the results reports. `X` is the starting point when it is positive definite;
otherwise (for example zero) the start is the diagonal solution
`1/(Sᵢᵢ + λᵢᵢ/w)`.

Other smooth losses can provide `ProximalBase.hashessian`, `quadratic_model`
and `quadratic_model!`. Their quadratic model is a function of the new point
and must be supported by [`cdmodel`](@ref), for example a `QuadraticFunction`,
`LeastSquaresLoss` or `KronQuadratic`, possibly scaled. The inner coordinate
descent minimizes that model plus `g`, and an Armijo line search rejects
nonfinite trials. Dense vectors, `SparseIterate`s, `SymmetricSparseIterate`s
and dense symmetric matrices are accepted. Vector penalties must be
separable; the generic symmetric-matrix path supports `NormL1` and
`ZeroFunction`, averaging transposed entry weights for `NormL1`.

For this generic path, the unit-step proximal fixed-point residual of the
original objective must be at most `tol * max(1, norm(x, Inf))` for
convergence. The results report the residual in `maxchange` and the threshold
in `tolerance`; `gap` is `NaN`. A failed line search reports no convergence.
The quadratic-model buffers are reused, while their coordinate-descent caches
are refreshed on each outer step. Generic losses do not receive the GLM's
extra intercept or screened-path interface.
"""
struct ProxNewton <: ProximalSolver
  inner::CDSolver
  maxiter::Int
  tol::Float64
  β::Float64
end

function ProxNewton(; inner::CDSolver = CDSolver(; tol = 1e-8), maxiter::Integer = 100, tol::Real = 1e-8,
                    β::Real = 0.5)
  maxiter >= 1 || throw(ArgumentError("maxiter must be positive, but it is $maxiter."))
  isfinite(Float64(tol)) && tol >= 0 || throw(ArgumentError("tol must be nonnegative, but it is $tol."))
  0 < β < 1 || throw(ArgumentError("β must be in (0, 1), but it is $β."))
  ProxNewton(inner, Int(maxiter), Float64(tol), Float64(β))
end

Base.summary(::ProxNewton) = "Proximal Newton"

# the model that proximal Newton runs on: any GLMLoss, with any curvature
_newton_model(m::GLMModel) = m
_newton_model(f::GLMLoss) = GLMModel(f.loss, f.y, f.X, f.weights, f.offset, 1)
_newton_model(f::Scaled{<:GLMLoss}) = GLMModel(f.f.loss, f.f.y, f.f.X, f.f.weights, f.f.offset, f.α)
_newton_model(f) = throw(ArgumentError("ProxNewton needs a GLMLoss, but f is a $(typeof(f))."))

# s ∑ᵢ wᵢ ℓ(ηᵢ + c, yᵢ)
function _glmvalue(loss, y, w, s::T, η::Vector{T}, c::T = zero(T)) where {T}
  v = zero(T)
  @inbounds for i in eachindex(η)
    wi = _obsweight(w, i, T)
    iszero(wi) && continue
    v += wi * T(loss(η[i] + c, y[i]))
  end
  s * v
end

# minᵤ ℓ(u, y), the loss of the saturated model, for the deviance; NaN for a
# loss without a known one
_saturated(::ProximalBase.Squared, y::T) where {T} = zero(T)
_saturated(::ProximalBase.Huber, y::T) where {T} = zero(T)
_saturated(::ProximalBase.Logistic, y::T) where {T} = -(_xlogx(y) + _xlogx(1 - y))
_saturated(::ProximalBase.Poisson, y::T) where {T} = y - _xlogx(y)
_saturated(loss, y::T) where {T} = T(NaN)
_xlogx(t::T) where {T} = t > 0 ? t * log(t) : zero(T)

# the deviance 2 ∑ᵢ wᵢ (ℓ(ηᵢ, yᵢ) - minᵤ ℓ(u, yᵢ)) at the linear predictor η
function _deviance(m::GLMModel{T}, η::AbstractVector{T}) where {T}
  v = zero(T)
  @inbounds for i in eachindex(η)
    wi = _obsweight(m.w, i, T)
    iszero(wi) && continue
    v += wi * (T(m.loss(η[i], m.y[i])) - _saturated(m.loss, m.y[i]))
  end
  2v
end

# the deviance of the fit with β = 0: the offset, plus the intercept fitted to it
function _null_deviance(m::GLMModel{T}) where {T}
  η = m.η
  saved = copy(η)
  m.offset === nothing ? fill!(η, zero(T)) : copyto!(η, m.offset)
  c = m.intercept ? _fit_intercept(m, m.β0) : zero(T)
  η .+= c
  D = _deviance(m, η)
  copyto!(η, saved)
  D
end

# x = x0 + t (x1 - x0)
function _interpolate!(x::SparseIterate{T}, x0::SparseIterate{T}, x1::SparseIterate{T}, t::T) where {T}
  copyto!(x, x0)
  for k in activecoordinates(x1)
    x[k] = x0[k] + t * (x1[k] - x0[k])
  end
  for k in activecoordinates(x0)
    isactive(x1, k) || (x[k] = (1 - t) * x0[k])
  end
  x
end

# The buffers of proximal Newton for a model and iterates like x: the weights v
# and working responses z of the quadratic model, which the weighted
# least-squares model `model` shares, the linear predictors and iterates at the
# start and the end of a step, and the state of the inner coordinate descent.
# The weighted column means that center the columns for an intercept change
# with v; `constant` marks the constant columns, whose mean is set exactly.
struct _NewtonWorkspace{T, M<:LSModel{T}, S<:_CDState{T}}
  v::Vector{T}
  z::Vector{T}
  η0::Vector{T}
  η1::Vector{T}
  x0::SparseIterate{T, 1}
  x1::SparseIterate{T, 1}
  model::M
  st::S
  constant::BitVector
  grad::Vector{T}       # ∇f on the candidates, for the duality gap
  vs::Vector{T}         # the curvatures of the stationarity check
end

function _NewtonWorkspace(m::GLMModel{T}, x::SparseIterate{T}, inner::CDSolver) where {T}
  n, p = size(m.X)
  v, z = zeros(T, n), zeros(T, n)
  model = LSModel(z, m.X, v, nothing, m.s)
  constant = m.intercept ? BitVector(n > 0 && all(==(m.X[1, k]), view(m.X, :, k)) for k in 1:p) : falses(0)
  _NewtonWorkspace(v, z, zeros(T, n), zeros(T, n), copy(x), copy(x), model, _CDState(T, x, inner), constant, zeros(T, p),
                    zeros(T, n))
end

# the weighted means of the columns and of z that center the least-squares model
# of a step for the intercept. With `cols`, only the means of those columns: the
# others keep stale means, which the step must not read (see _centered_columns).
function _center!(ws::_NewtonWorkspace{T}, cols::Union{Nothing, Vector{Int}}) where {T}
  model, v, X = ws.model, ws.v, ws.model.X
  sv = sum(v)
  if cols === nothing
    mul!(model.xbar, transpose(X), v)
    model.xbar ./= sv
    @inbounds for k in eachindex(ws.constant)
      ws.constant[k] && (model.xbar[k] = X[1, k])
    end
  else
    _column_means!(model.xbar, X, v, sv, cols)
    @inbounds for k in cols
      ws.constant[k] && (model.xbar[k] = X[1, k])
    end
  end
  model.ybar = dot(v, ws.z) / sv
  model.wsum = sv
  ws
end

# xbar[k] = X[:, k]'v / sv for the columns k in cols
function _column_means!(xbar::Vector{T}, X::AbstractMatrix{T}, v::Vector{T}, sv::T, cols::Vector{Int}) where {T}
  @inbounds for k in cols
    s = zero(T)
    @simd for i in eachindex(v)
      s += X[i, k] * v[i]
    end
    xbar[k] = s / sv
  end
  xbar
end

function _column_means!(xbar::Vector{T}, X::SparseMatrixCSC{T}, v::Vector{T}, sv::T, cols::Vector{Int}) where {T}
  rows, vals = rowvals(X), nonzeros(X)
  @inbounds for k in cols
    s = zero(T)
    for j in nzrange(X, k)
      s += vals[j] * v[rows[j]]
    end
    xbar[k] = s / sv
  end
  xbar
end

# The columns whose means a step centers: all of them, or the candidates of
# screening. The inner coordinate descent then reads the means of the
# candidates only. Its first pass is over the candidates, and the dropzeros!
# after it removes any other stored zero, so that the active set stays among
# the candidates; screening counts the nonzero coordinates among them, and the
# line search moves between two points supported on them. The columns that a
# check of the optimality conditions adds are centered from the next call on.
# The duality gap of gaptol and gapsafe is that of the problem restricted to the
# candidates, and reads only their means. A dense X with more candidates than
# half its columns needs all the means, whose product X'v costs less than the
# columns one at a time.
function _centered_columns(X::AbstractMatrix, candidates::Union{Nothing, Vector{Int}}, inner::CDSolver)
  candidates === nothing && return nothing
  2 * length(candidates) > size(X, 2) ? nothing : candidates
end

_centered_columns(X::SparseMatrixCSC, candidates::Union{Nothing, Vector{Int}}, inner::CDSolver) = candidates

# Proximal Newton steps on f + g from x, with m.η = Xx + β₀ + o current; with
# `candidates`, the inner coordinate descent visits only those coordinates (and
# the active ones), as screening does. Returns (f + g, passes, converged, gap).
#
# With gaptol > 0 and a loss and penalty that have a duality gap, the steps stop
# when the relative gap of the problem restricted to the candidates is at most
# gaptol (gap, NaN otherwise), computed after each step at the cost of one pass
# over the candidate columns, with the intercept fitted exactly first, so that
# the dual point satisfies its constraint. Each inner solve then stops on the
# gap of the quadratic model too, at _NEWTON_INNER times the last gap of f + g
# (inexact Newton), but not below gaptol / 10; when the steps stall above
# gaptol, the inner target falls a hundredfold.
function _proxnewton!(x::SparseIterate{T}, m::GLMModel{T}, g, method::ProxNewton, ws::_NewtonWorkspace{T},
                      candidates::Union{Nothing, Vector{Int}}, gaptol::Real = 0.0) where {T}
  loss, y, w, o, s = m.loss, m.y, m.w, m.offset, m.s
  η, v, z, model = m.η, ws.v, ws.z, ws.model
  n = length(η)
  F = _glmvalue(loss, y, w, s, η) + g(x)
  isfinite(F) || throw(ArgumentError("ProxNewton needs a finite starting objective"))
  passes, converged, inner_converged = 0, false, true
  cols = m.intercept ? _centered_columns(model.X, candidates, method.inner) : nothing
  gapmode = gaptol > 0 && _hasgap(m, g)
  relgap, innerfloor = T(NaN), T(gaptol) / 10
  if gapmode
    F, relgap = _newton_gap!(x, m, g, ws, candidates)
    gapmode = !isnan(relgap)          # no gap at x: the rule on the objective
    if relgap <= gaptol && _newton_raw_ok(m, g, x, ws.grad, candidates, gaptol)
      ws.st.candidates = nothing
      return F, 0, true, relgap
    end
  end
  stepper = method
  curvature_floor = _newton_curvature_floor(loss, T, gaptol)
  for _ in 1:method.maxiter
    stepper = gapmode ? _with_inner(method, max(innerfloor, T(_NEWTON_INNER) * relgap), loss) : _newton_no_gap(method, loss, gaptol)
    # the quadratic model at x: weights v, responses z (working responses minus
    # the offset), updated in place
    @inbounds for i in 1:n
      wi = _obsweight(w, i, T)
      if iszero(wi)
        v[i] = z[i] = zero(T)
        continue
      end
      d1 = T(ProximalBase.deriv(loss, η[i], y[i]))
      d2 = max(T(ProximalBase.deriv2(loss, η[i], y[i])), curvature_floor)
      v[i] = wi * d2
      z[i] = η[i] - d1 / d2 - (o === nothing ? zero(T) : o[i])
    end
    m.intercept && _center!(ws, cols)
    copyto!(ws.x0, x)
    copyto!(ws.η0, η)
    b0 = m.β0
    ws.st.candidates = candidates
    Fnew, t, p = _newton_step!(x, m, g, g, F, b0, stepper, ws)
    passes += p
    if t < 1 && _isdampable(g)
      # MCP and SCAD are weakly convex, with concavity ρ = 1/a and 1/(a - 1).
      # Where the curvature of the quadratic model along a coordinate is below
      # ρ (a logistic model has curvature at most 1/4 on standardized columns,
      # less where the fitted probabilities are near 0 or 1), the model plus the
      # penalty has several local minima along it, and the inner coordinate
      # descent, which takes the global one, can jump to a minimum of the model
      # that the objective rejects, so that the line search keeps only a sliver
      # of the step. When the step needs backtracking, take it also with the
      # proximal term ρ‖x - x0‖², which makes the model plus the penalty strongly
      # convex (a proximal Newton step in the metric H + 2ρI): its directional
      # derivative is at most -d'(H + ρI)d < 0 along its step d, and the fixed
      # points are unchanged. Keep the better of the two.
      xu, ηu, bu = copy(x), copy(η), m.β0
      copyto!(x, ws.x0); copyto!(η, ws.η0); m.β0 = b0
      Fd, _, p = _newton_step!(x, m, g, Regularize(g, 2 * _concavity(g), Vector(ws.x0)), F, b0, stepper, ws)
      passes += p
      if Fd <= Fnew
        Fnew = Fd
      else
        copyto!(x, xu); copyto!(η, ηu); m.β0 = bu
      end
    end
    inner_converged &= ws.st.converged
    dropzeros!(x)
    # a stall tightens the inner solves in gap mode; it ends the steps only at a
    # stationary point
    done = abs(F - Fnew) <= method.tol * max(abs(Fnew), one(T))
    stationary = done && _newton_stationary!(ws, m, g, x, candidates, method.tol, curvature_floor)
    F = Fnew
    if gapmode
      F, relgap = _newton_gap!(x, m, g, ws, candidates)
      if isnan(relgap)
        gapmode = false
        stationary && _newton_raw_ok(m, g, x, ws.grad, candidates, gaptol) && (converged = true; break)
      elseif relgap <= gaptol && _newton_raw_ok(m, g, x, ws.grad, candidates, gaptol)
        converged = true
        break
      end
      if done          # stalled above gaptol: solve the quadratic models more accurately
        innerfloor <= 4 * eps(T) && break
        innerfloor = max(innerfloor / 100, 4 * eps(T))
      end
    elseif stationary && _newton_raw_ok(m, g, x, ws.grad, candidates, gaptol)
      converged = true
      break
    end
  end
  ws.st.candidates = nothing
  F, passes, converged && inner_converged, relgap
end

# A small objective change does not establish stationarity: a constant in the
# loss, a rejected direction or a tiny step can all produce one. Check the
# original problem at x in the metric of the Newton model, the curvatures
# vᵢ = wᵢ max(ℓ''(ηᵢ), floor) of the next step: the exact coordinate step Δⱼ of
# the original gradient with curvature aⱼ = s Σᵢ vᵢ Xᵢⱼ², measured as √aⱼ |Δⱼ|,
# and likewise the intercept. The square of this measure is about the decrease
# of f + g the step offers; it is compared with √tol times the decrease
# available from the starting predictor (the offset), the scale of the problem.
# Neither side changes when f is scaled or a constant is added to it.
function _newton_stationary!(ws::_NewtonWorkspace{T}, m::GLMModel{T}, g, x, candidates, tol, floor) where {T}
  v, grad = ws.vs, ws.grad
  sy, a0 = zero(T), zero(T)
  @inbounds for i in eachindex(m.η)
    wi = _obsweight(m.w, i, T)
    if iszero(wi)
      v[i] = zero(T)
      continue
    end
    oi = m.offset === nothing ? zero(T) : T(m.offset[i])
    sy += wi * T(ProximalBase.deriv(m.loss, oi, m.y[i]))^2 / max(T(ProximalBase.deriv2(m.loss, oi, m.y[i])), floor)
    v[i] = wi * max(T(ProximalBase.deriv2(m.loss, m.η[i], m.y[i])), floor)
    a0 += v[i]
  end
  sy = sqrt(m.s * sy)
  threshold = sqrt(T(tol)) * (sy > 0 ? sy : one(T))
  candidates === nothing ? gradient!(grad, m, x) : _partial_gradient!(grad, m, x, candidates)
  for j in (candidates === nothing ? eachindex(x) : candidates)
    a = m.s * _weighted_sqnorm(m.X, v, j)
    iszero(a) && continue                  # a column that no observation sees
    r = sqrt(a) * abs(prox_entry(g, x[j] - grad[j] / a, j, inv(a)) - x[j])
    isfinite(r) && r <= threshold || return false
  end
  if m.intercept && a0 > 0
    r = abs(m.s * sum(m.d)) / sqrt(m.s * a0)    # m.d holds wᵢ ℓ'(ηᵢ) from the gradient
    isfinite(r) && r <= threshold || return false
  end
  true
end

const _NEWTON_INNER = 0.01

_newton_curvature_floor(loss, ::Type{T}, gaptol) where {T} = sqrt(eps(T))
function _newton_curvature_floor(loss::ProximalBase.ConvolutionCheck, ::Type{T}, gaptol) where {T}
  # Compact kernels have exactly flat tails. A vanishingly small Hessian floor
  # makes z and the quadratic residual huge, losing precision when the next
  # predictor is recovered from their difference. This positive curvature
  # damping keeps that cancellation below the score targets; backtracking and
  # certification still use the original objective. Preserve gaptol=0 behavior.
  gaptol > 0 ? sqrt(sqrt(eps(T))) * T(ProximalBase.curvature(loss)) : sqrt(eps(T))
end

# A feasible contracted dual can certify objective accuracy without providing
# equally accurate raw observation scores. Quantile inference needs the latter.
# This guard never projects or substitutes the scores returned by the model.
_newton_raw_ok(m, g, x, grad, candidates, tol) = true
function _newton_raw_ok(m::GLMModel{T, <:ProximalBase.ConvolutionCheck}, g::NormL1,
                        x::SparseIterate{T}, grad, candidates, tol) where {T}
  tol > 0 || return true              # gaptol=0 explicitly selects the legacy rule
  if candidates === nothing
    gradient!(grad, m, x)
  else
    _partial_gradient!(grad, m, x, candidates)
  end
  inds = candidates === nothing ? eachindex(x) : candidates
  stationarity = maximum((abs(x[j] - prox_entry(g, x[j] - grad[j], j, one(T))) for j in inds); init=zero(T))
  stationarity <= tol || return false
  if m.intercept
    c = m.s * sum(_obsweight(m.w, i, T) * T(ProximalBase.deriv(m.loss, m.η[i], m.y[i])) for i in eachindex(m.η))
    abs(c) <= tol || return false
  end
  P = loss_value(m, x) + g(x)
  rawgap = P + _glm_conjugate(m.loss, m.y, m.w, m.offset, m.s, m.η, one(T))
  isfinite(rawgap) && abs(rawgap) <= tol * (one(T) + abs(P))
end

# method with the inner solver stopping on the relative gap gaptol
_with_inner(method::ProxNewton, gaptol) =
  ProxNewton(_with(method.inner; gaptol = Float64(gaptol)), method.maxiter, method.tol, method.β)

_with_inner(method::ProxNewton, gaptol, loss) = _with_inner(method, gaptol)
_newton_no_gap(method::ProxNewton, loss, gaptol) = method
_newton_no_gap(method::ProxNewton, loss::ProximalBase.ConvolutionCheck, gaptol) =
  gaptol > 0 ? _with_inner(method, gaptol / 10, loss) : method
function _with_inner(method::ProxNewton, target, loss::ProximalBase.ConvolutionCheck)
  # Outside the kernel window the curvature floor makes the working response
  # huge. Relative changes/gaps of that quadratic inherit a huge irrelevant
  # constant. Solve it on absolute scaled coordinate changes instead; the
  # original smoothed problem still has the certified outer gap and raw guard.
  inner = _with(method.inner; tol=min(method.inner.tol, Float64(target)), relative=false, gaptol=0.0)
  ProxNewton(inner, method.maxiter, method.tol, method.β)
end

# (f + g, relative gap) of the problem restricted to the candidates at x, after
# fitting the intercept exactly for x (which only decreases f): the dual point
# then satisfies the constraint Σᵢ θᵢ = 0 of the unpenalized intercept
function _newton_gap!(x::SparseIterate{T}, m::GLMModel{T}, g, ws::_NewtonWorkspace{T},
                      candidates::Union{Nothing, Vector{Int}}) where {T}
  if m.intercept
    m.η .-= m.β0
    m.β0 = _fit_intercept(m, m.β0)
    m.η .+= m.β0
  end
  res = _restricted_gap!(ws.grad, m, g, x, candidates)
  F = loss_value(m, x) + g(x)
  res === nothing && return F, T(NaN)
  P, D, _ = res
  F, _relative_gap(P, D)
end

# One proximal Newton step from x = ws.x0 (with m.η = ws.η0 and the intercept
# b0) on the quadratic model in ws: coordinate descent on the model plus the
# penalty gi (g, or g with a proximal term), then backtracking along the step on
# the objective f + g, whose value at x0 is F. Returns the objective at the new
# point, the fraction t of the step taken (zero when no fraction decreased the
# objective: x, η and the intercept are then back at x0), and the inner passes.
function _newton_step!(x::SparseIterate{T}, m::GLMModel{T}, g, gi, F::T, b0::T, method::ProxNewton,
                       ws::_NewtonWorkspace{T}) where {T}
  loss, y, w, o, s = m.loss, m.y, m.w, m.offset, m.s
  η, z, model = m.η, ws.z, ws.model
  initialize!(model, x)
  _cd!(x, model, gi, ws.st, method.inner)
  _warn_not_converged(ws.st, method.inner)
  copyto!(ws.x1, x)
  b1 = m.intercept ? intercept(model, x) : zero(T)
  # Xx + β₀ + o at the full step, from the residuals z - β₀ - Xx of the model,
  # which are model.r .+ model.δ (δ is zero but for a sparse X with an intercept)
  δ = model.δ
  @inbounds for i in eachindex(η)
    ws.η1[i] = z[i] - (model.r[i] + δ) + (o === nothing ? zero(T) : o[i])
  end

  # backtracking along the step: x0 + t (x1 - x0), η0 + t (η1 - η0)
  t = one(T)
  copyto!(η, ws.η1)
  m.β0 = b1
  Fnew = _glmvalue(loss, y, w, s, η) + g(x)
  while !(Fnew <= F + 10 * eps(T) * abs(F))
    t *= T(method.β)
    if t < 1e-10           # no decrease along the step: back to x0
      copyto!(x, ws.x0); copyto!(η, ws.η0); m.β0 = b0
      return F, zero(T), ws.st.passes
    end
    _interpolate!(x, ws.x0, ws.x1, t)
    @. η = ws.η0 + t * (ws.η1 - ws.η0)
    m.β0 = b0 + t * (b1 - b0)
    Fnew = _glmvalue(loss, y, w, s, η) + g(x)
  end
  Fnew, t, ws.st.passes
end

# the weakly convex penalties whose proximal Newton steps may need a proximal
# term, with their concavity (_concavity, in models.jl)
_isdampable(g) = false
_isdampable(::Union{MCP, SCAD, ProximalBase.BoxConstrained{<:Union{MCP, SCAD}}}) = true

solve!(x::SparseIterate, f::Union{GLMLoss, Scaled{<:GLMLoss}}, g::AbstractFunction, method::ProxNewton) =
  _solve_newton!(x, f, g, method)
solve!(x::SparseIterate, m::GLMModel, g::AbstractFunction, method::ProxNewton) = _solve_newton!(x, m, g, method)

function _solve_newton!(x::SparseIterate{T}, f, g::AbstractFunction, method::ProxNewton) where {T}
  isseparable(g) || throw(ArgumentError("ProxNewton needs a separable penalty, but g is a $(typeof(g))."))
  m = _newton_model(f)
  eltype(m) === T || throw(ArgumentError("x has element type $T and the model $(eltype(m))"))
  _check_iterate(g, x)
  _predictor!(m, x)
  m.intercept && (m.η .+= m.β0)          # warm started from the intercept of the model
  ws = _NewtonWorkspace(m, x, method.inner)
  F, passes, converged, _ = _proxnewton!(x, m, g, method, ws, nothing)
  CDResults(x, F, passes, converged, T(NaN), T(method.tol), 0)
end

"""
    solve_path(f, g, λs, method::ProxNewton; x, screening = true, maxnnz = Inf, callback = nothing, devmax = 0.999,
               gaptol)

The path of [`ProxNewton`](@ref) solutions along the decreasing levels `λs`,
for a `GLMLoss` `f` or its model with an intercept (`cdmodel(f, x;
intercept = true)`), as [`solve_path`](@ref) computes it for coordinate
descent: each level is warm started from the previous solution and its
intercept, with the sequential strong rule and checks of the optimality
conditions when `screening`, and the path stops after more than `maxnnz`
nonzero coordinates or when `callback(k, λ, x, m)` returns `true`. With an
intercept, the starting intercept is fitted to the starting `x` (zero by
default), so that the first level can be λmax from [`lambda_max`](@ref) of the
same model.

The path also stops once the fraction of the null deviance that the fit
explains, `1 - D/D₀`, reaches `devmax`, as glmnet's does: `D` is the deviance
`2 ∑ᵢ wᵢ (ℓ(ηᵢ, yᵢ) - minᵤ ℓ(u, yᵢ))` and `D₀` that of the fit with `β = 0`.
Along a logistic path on separable data the coefficients grow without bound,
and the explained fraction tends to one. `devmax = 1` never stops; the rule is
off for a scalar loss whose saturated loss is unknown.

As for coordinate descent, each level stops on a relative duality gap of at
most `gaptol` ([`PATH_GAPTOL`](@ref) `= 1e-4` by default, `1e-3` for the
faster setting) when the loss and the penalty have one (the squared, logistic,
Poisson, Huber and convolution check losses with `NormL1`, `NormL1Nonneg` or `ElasticNet`): the
Newton steps stop on the gap of the problem restricted to the candidates, each
inner solve stops on the gap of its quadratic model at a hundredth of the last
gap, and the full gradient of the optimality check confirms the gap of the
whole problem, which the `gap` of the results reports. With an intercept, the
intercept is fitted exactly before each gap. `gaptol = 0`, and the other
penalties (MCP, SCAD, …), keep the rule on the change of the objective with
`method.tol` and the inner solver's own rule.

For convolution check loss and `NormL1`, positive `gaptol` also checks the raw
score stationarity, intercept constraint and absolute raw gap at that tolerance.
The feasible scaled dual used for the certificate never replaces those scores.
Compact-kernel flat tails use positive curvature damping and absolute scaled
coordinate changes for the quadratic subproblems, avoiding a relative stopping
scale dominated by their large working responses. Backtracking evaluates the
original objective. `gaptol=0` preserves the objective-change route.
"""
function solve_path(f::Union{AbstractFunction, CDModel}, g::AbstractFunction, λs::AbstractVector{<:Real},
                    method::ProxNewton; x = _default_iterate(f), screening::Bool = true, maxnnz::Real = Inf,
                    callback = nothing, devmax::Real = 0.999, gaptol::Union{Nothing, Real} = nothing)
  all(λ -> isfinite(λ) && λ >= 0, λs) || throw(ArgumentError("The penalty levels must be finite and nonnegative."))
  issorted(λs; rev = true) || throw(ArgumentError("The penalty levels must be decreasing."))
  isseparable(g) || throw(ArgumentError("ProxNewton needs a separable penalty, but g is a $(typeof(g))."))
  m = _newton_model(f)
  T = eltype(m)
  _check_iterate(g, x)
  isempty(λs) || _with_level(g, T(first(λs)))      # a penalty with a level
  gaptol === nothing || isfinite(Float64(gaptol)) && gaptol >= 0 || throw(ArgumentError("gaptol must be nonnegative, but it is $gaptol."))
  gt = gaptol === nothing ? (_hasgap(m, g) ? _default_gaptol(T) : 0.0) : Float64(gaptol)
  initialize!(m, x)
  ws = _NewtonWorkspace(m, x, method.inner)
  D0 = devmax < 1 ? _null_deviance(m) : T(NaN)
  grad, inS, λprev = _screening_state(x, m, g, screening)
  solutions = Any[]
  out = PathResults(T[], [], T[], Int[], Bool[], Int[], Int[], T[])
  for (k, λ) in enumerate(λs)
    gk = _with_level(g, T(λ))
    if screening
      F, passes, converged, checks, relgap = _screened_newton!(x, m, gk, λprev, grad, method, ws, inS, gt)
      λprev = T(λ)
    else
      F, passes, converged, relgap = _proxnewton!(x, m, gk, method, ws, nothing, gt)
      checks = 0
    end
    push!(out.λ, T(λ)); push!(solutions, _snapshot(x)); push!(out.values, F)
    push!(out.passes, passes); push!(out.converged, converged); push!(out.kkt_checks, checks); push!(out.stages, 1)
    push!(out.gap, relgap)
    (callback !== nothing && callback(k, T(λ), x, m) === true) && break
    nactive(x) > maxnnz && break
    D0 > 0 && 1 - _deviance(m, m.η) / D0 >= devmax && break
  end
  S = isempty(solutions) ? Any : typeof(first(solutions))
  PathResults{S, T}(out.λ, convert(Vector{S}, solutions), out.values, out.passes, out.converged, out.kkt_checks,
                    out.stages, out.gap)
end

# _screened! for proximal Newton: the strong rule for the step from λprev to the
# level of g selects the coordinates of the inner solves, and the optimality
# conditions of the others are checked at the solution; violators are added and
# the level solved again. grad holds the gradient at x on entry and on return.
# With gaptol, the full gradient of the check gives the gap of the whole
# problem, as in _screened!.
function _screened_newton!(x, m::GLMModel{T}, g, λprev, grad::AbstractArray, method::ProxNewton,
                           ws::_NewtonWorkspace{T}, inS::BitVector, gaptol::Real = 0.0) where {T}
  λ = _level(g)
  threshold = 2λ - λprev
  for k in eachindex(inS)
    w = _coordweight(g, x, k)
    inS[k] = iszero(w) || _isnonzero(x, k) || _strongkeep(g, grad, x, k, threshold, w)
  end
  passes, checks, retries = 0, 0, 0
  F, converged, relgap, gk = T(NaN), false, T(NaN), T(gaptol)
  while true
    F, p, converged, relgap = _proxnewton!(x, m, g, method, ws, findall(inS), gk)
    passes += p
    gradient!(grad, m, x)
    checks += 1
    violated = false
    for k in eachindex(inS)
      if !inS[k] && _kktviolated(g, grad, x, k, λ)
        inS[k] = true
        violated = true
      end
    end
    violated && continue
    isnan(relgap) && break
    res = _gap_at(grad, m, g, x, nothing)
    relgap = res === nothing ? T(NaN) : max(res[1] - res[2], 4 * eps(T) * abs(res[1])) / max(abs(res[1]), floatmin(T))
    ((relgap <= gaptol && _newton_raw_ok(m, g, x, ws.grad, nothing, gaptol)) || !converged || retries >= _GAPRETRIES) && break
    retries += 1
    gk /= 10
  end
  converged &= _newton_raw_ok(m, g, x, ws.grad, nothing, gaptol)
  F, passes, converged, checks, relgap
end
