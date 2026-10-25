# SLOPE uses the sorted penalty of ProximalBase and the accelerated proximal
# gradient solver of ProximalSolvers. All penalties here use loss / n.

"""
    slope_bh(p; q=0.1, sigma=1, n=1)

The Benjamini–Hochberg sequence `sigma / sqrt(n) * Φ⁻¹(1 - q*j/(2p))`,
`j = 1:p`, for [`slope`](@ref)'s loss `‖y - Xβ‖²/(2n)`. Under independent
Gaussian errors of known standard deviation `sigma` and `X'X/n = I`, SLOPE
with this sequence controls FDR at most `q`. Standardizing correlated columns
or estimating `sigma` does not establish that guarantee.
"""
function slope_bh(p::Integer; q::Real=0.1, sigma::Real=1, n::Integer=1)
  p > 0 && n > 0 || throw(ArgumentError("p and n must be positive"))
  isfinite(q) && 0 < q < 1 || throw(ArgumentError("q must be in (0, 1)"))
  isfinite(sigma) && sigma >= 0 || throw(ArgumentError("sigma must be finite and nonnegative"))
  [sigma / sqrt(n) * sqrt(2) * erfcinv(q * j / p) for j in 1:p]
end

# Validation and centering are shared by the fit and the path. A dense copy
# makes the transformed design explicit, including for sparse input.
function _slope_data(X, y, intercept, standardize_x)
  n, p = size(X)
  n > 0 && p > 0 || throw(ArgumentError("X must have positive dimensions"))
  length(y) == n || throw(DimensionMismatch("X and y have different observation counts"))
  T = float(promote_type(eltype(X), eltype(y)))
  Z, v = Matrix{T}(X), Vector{T}(y)
  all(isfinite, Z) && all(isfinite, v) || throw(ArgumentError("X and y must be finite"))
  xb = intercept ? vec(mean(Z; dims=1)) : zeros(T, p)
  yb = intercept ? mean(v) : zero(T)
  Z .-= transpose(xb)
  v .-= yb
  scales = standardize_x ? vec(sqrt.(sum(abs2, Z; dims=1) ./ n)) : ones(T, p)
  # A zero column has coefficient zero; use unit scale to avoid dividing by zero.
  replace!(scales, zero(T) => one(T))
  Z ./= transpose(scales)
  Z, v, xb, yb, scales
end

function _slope_lambda(lambda, p, ::Type{T}) where {T}
  length(lambda) == p || throw(DimensionMismatch("lambda must have one entry per predictor"))
  λ = Vector{T}(lambda)
  all(isfinite, λ) && all(>=(0), λ) && issorted(λ; rev=true) ||
    throw(ArgumentError("lambda must be finite, nonnegative and nonincreasing"))
  λ
end

# Algorithm 2 of Larsson, Bogdan and Wallin (2020), with the preceding
# gradient sorted in magnitude. 'previous - current' is added by rank.
function _slope_strong(grad, previous, current)
  order = sortperm(abs.(grad); rev=true)
  k, s = 0, zero(eltype(grad))
  for i in eachindex(order)
    s += abs(grad[order[i]]) + previous[i] - 2current[i]
    if s >= 0
      k, s = i, zero(s)
    end
  end
  order[1:k]
end

# A full proximal fixed-point residual certifies all clusters, including the
# zero cluster: checking each coordinate against its own λ would be invalid.
function _slope_kkt(Z, y, β, λ)
  grad = transpose(Z) * (Z * β - y) / length(y)
  trial = similar(β)
  prox!(trial, ProximalBase.SLOPE(λ), β - grad, one(eltype(β)))
  norm(β - trial, Inf), grad, trial
end

function _slope_fit!(β, Z, y, λ, candidates; max_iter, tol)
  p = length(β)
  E = sort!(unique!(collect(candidates)))
  total, repairs = 0, 0
  # Scale the residual by the gradient of the null fit, independent of the
  # reduced problem and the starting point.
  target = tol * max(one(eltype(β)), norm(transpose(Z) * y / length(y), Inf))
  while true
    if !isempty(E) && total + 1 < max_iter
      b = β[E]
      f = (one(eltype(β)) / length(y)) * LeastSquaresLoss(y, Z[:, E])
      g = ProximalBase.SLOPE(λ[1:length(E)])
      opts = ProximalOptions(; maxiter=max(2, max_iter-total), ftol=eps(Float64),
        xtol=eps(Float64), gradtol=tol/10, allow_f_increases=true)
      r = ProximalSolvers.solve!(b, f, g, AccProxGradDescent(), opts)
      total += r.iterations
      β[E] = b
    end
    residual, grad, trial = _slope_kkt(Z, y, β, λ)
    residual <= target && return total, true, residual, length(E), repairs, grad
    total + 1 >= max_iter && return total, false, residual, length(E), repairs, grad
    # Add every excluded coordinate moved by the full prox. Include all
    # remaining columns as a conservative fallback when only E fails KKT.
    added = setdiff(findall(j -> abs(trial[j]) > target, 1:p), E)
    if isempty(added)
      length(E) == p && continue
      added = setdiff(1:p, E)
    end
    append!(E, added)
    sort!(E)
    repairs += 1
  end
end

"""
    SLOPESolution

Result of [`slope`](@ref). `x` contains the coefficients on the input scale;
`intercept`, `residuals`, `lambda`, `iterations`, `converged` and `kkt_residual`
describe the fit. The convergence flag requires a full proximal KKT check.
Supports `coef`, `predict`, `residuals`, `nobs`, and `deviance` from StatsAPI.
"""
struct SLOPESolution{T}
  x::Vector{T}
  intercept::T
  hasintercept::Bool
  residuals::Vector{T}
  lambda::Vector{T}
  iterations::Int
  converged::Bool
  kkt_residual::T
end

function _slope_options(max_iter, tol)
  max_iter >= 2 || throw(ArgumentError("max_iter must be at least 2"))
  isfinite(tol) && tol > 0 || throw(ArgumentError("tol must be finite and positive"))
end

"""
    slope(X, y, lambda; intercept=false, standardize_x=false, max_iter=10000, tol=1e-7)
    slope(X, y; q=0.1, sigma=1, kwargs...)

Minimize `‖y - β₀ - Xβ‖²/(2n) + ∑ⱼ lambda[j]*|β|₍ⱼ₎` by accelerated
proximal gradient. `lambda` must be nonincreasing and nonnegative. The second
form uses [`slope_bh`](@ref) with `n=size(X,1)`. With `standardize_x`, the
penalty applies to the coefficients of columns scaled to mean square one;
returned coefficients are on the input scale. An intercept centers X and y.
The design is copied to a dense floating-point matrix. Failure of the full
optimality check gives `converged=false` and a warning.
"""
function slope(X::AbstractMatrix{<:Real}, y::AbstractVector{<:Real}, lambda::AbstractVector{<:Real};
               intercept::Bool=false, standardize_x::Bool=false, max_iter::Integer=10000, tol::Real=1e-7)
  _slope_options(max_iter, tol)
  Z, v, xb, yb, scales = _slope_data(X, y, intercept, standardize_x)
  β = zeros(eltype(Z), size(Z, 2))
  λ = _slope_lambda(lambda, length(β), eltype(β))
  it, ok, residual = _slope_fit!(β, Z, v, λ, eachindex(β); max_iter, tol)
  ok || @warn "SLOPE did not meet its full optimality tolerance" residual iterations=it
  β ./= scales
  β0 = yb - dot(xb, β)
  SLOPESolution(β, β0, intercept, Vector(y .- β0 .- X * β), λ, it, ok, residual)
end

slope(X::AbstractMatrix{<:Real}, y::AbstractVector{<:Real}; q::Real=0.1, sigma::Real=1, kwargs...) =
  slope(X, y, slope_bh(size(X, 2); q, sigma, n=size(X, 1)); kwargs...)

"""
    SLOPEPath(X, y, factors=nothing; lambda=nothing, q=0.1, sigma=1,
              nλ=50, λmin_ratio=0.01, screening=true, intercept=false,
              standardize_x=false, max_iter=10000, tol=1e-7)

Warm-started SLOPE fits with penalties `factor * lambda`. `lambda` defaults
to [`slope_bh`](@ref). Supply positive, nonincreasing `factors`, or a geometric
path from the smallest factor with a zero fit to `λmin_ratio` times it.
`screening` uses the strong rule of Larsson, Bogdan and Wallin (2020), with
full proximal KKT checks and repairs. `screening=false` fits every column.

`λpath` holds the factors, `lambda` the base sequence, `βpath` the coefficient
vectors, and `β0path` the intercepts. Per-level diagnostics are `converged`,
`iterations`, `kkt_residuals`, `working_sizes`, and `kkt_repairs`.
`coef(path)` and `predict(path, X)` have a column per level.
"""
struct SLOPEPath{T}
  λpath::Vector{T}
  lambda::Vector{T}
  βpath::Vector{Vector{T}}
  β0path::Vector{T}
  intercept::Bool
  nobs::Int
  converged::BitVector
  iterations::Vector{Int}
  kkt_residuals::Vector{T}
  working_sizes::Vector{Int}
  kkt_repairs::Vector{Int}
end

function SLOPEPath(X::AbstractMatrix{<:Real}, y::AbstractVector{<:Real}, factors=nothing;
                   lambda=nothing, q::Real=0.1, sigma::Real=1, nλ::Integer=50, λmin_ratio::Real=0.01,
                   screening::Bool=true, intercept::Bool=false, standardize_x::Bool=false,
                   max_iter::Integer=10000, tol::Real=1e-7)
  _slope_options(max_iter, tol)
  Z, v, xb, yb, scales = _slope_data(X, y, intercept, standardize_x)
  T, p = eltype(Z), size(Z, 2)
  λ = _slope_lambda(lambda === nothing ? slope_bh(p; q, sigma, n=length(y)) : lambda, p, T)
  β = zeros(T, p)
  grad = -transpose(Z) * v / length(v)
  if factors === nothing
    nλ > 0 && isfinite(λmin_ratio) && 0 < λmin_ratio <= 1 ||
      throw(ArgumentError("nλ must be positive and λmin_ratio in (0, 1]"))
    λ[1] > 0 || throw(ArgumentError("automatic paths need a nonzero base sequence"))
    amax = maximum(cumsum(sort(abs.(grad); rev=true)) ./ cumsum(λ))
    amax = iszero(amax) ? one(T) : amax
    factors = nλ == 1 ? T[amax] : exp.(range(log(amax), log(amax * λmin_ratio); length=nλ))
  end
  a = T.(collect(factors))
  !isempty(a) && all(isfinite, a) && all(>(0), a) && issorted(a; rev=true) ||
    throw(ArgumentError("factors must be positive, finite and nonincreasing"))
  bs, b0 = Vector{T}[], T[]
  oks, its, res, sizes, repairs = BitVector(), Int[], T[], Int[], Int[]
  previous = a[1] .* λ
  for (i, factor) in enumerate(a)
    current = factor .* λ
    E = !screening || i == 1 ? collect(1:p) :
      union(_slope_strong(grad, previous, current), findall(!iszero, β))
    it, ok, r, sz, rep, grad = _slope_fit!(β, Z, v, current, E; max_iter, tol)
    push!(bs, β ./ scales)
    push!(b0, yb - dot(xb, bs[end]))
    push!(oks, ok); push!(its, it); push!(res, r); push!(sizes, sz); push!(repairs, rep)
    previous = current
  end
  all(oks) || @warn "some SLOPE path levels did not meet the full optimality tolerance"
  SLOPEPath(a, λ, bs, b0, intercept, length(y), oks, its, res, sizes, repairs)
end

StatsAPI.coef(s::SLOPESolution) = s.hasintercept ? [s.intercept; s.x] : copy(s.x)
function StatsAPI.predict(s::SLOPESolution, X::AbstractMatrix{<:Real})
  size(X, 2) == length(s.x) || throw(DimensionMismatch("wrong number of predictors"))
  s.intercept .+ X * s.x
end
StatsAPI.residuals(s::SLOPESolution) = s.residuals
StatsAPI.nobs(s::SLOPESolution) = length(s.residuals)
StatsAPI.deviance(s::SLOPESolution) = sum(abs2, s.residuals)
StatsAPI.coef(p::SLOPEPath) = p.intercept ? vcat(transpose(p.β0path), reduce(hcat, p.βpath)) : reduce(hcat, p.βpath)
StatsAPI.nobs(p::SLOPEPath) = p.nobs
function StatsAPI.predict(p::SLOPEPath, X::AbstractMatrix{<:Real})
  size(X, 2) == length(p.lambda) || throw(DimensionMismatch("wrong number of predictors"))
  X * reduce(hcat, p.βpath) .+ transpose(p.β0path)
end
