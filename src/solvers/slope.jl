"""
    SLOPEAPG(; maxiter=10_000, tol=1e-7)

Accelerated proximal gradient with SLOPE working sets and full optimality
repairs for single-response `LeastSquaresLoss`, optionally `Scaled`. Call
`solve!(x, f, SLOPE(lambda), SLOPEAPG())` or
`solve_path(f, SLOPE(lambda), factors, SLOPEAPG(); screening=true)`.
The loss and penalty are used in their supplied units; normalization, intercepts,
standardization and statistical weight calibration belong to the caller.

Reduced fits use [`AccProxGradDescent`](@ref). Each is checked on the full problem
by `norm(x - prox_g(x - gradient(f,x)), Inf)`, including the zero cluster.
Convergence requires this residual to be at most
`tol * max(1, norm(gradient(f,zero(x)), Inf))`. Violating excluded coordinates
are added and refitted. A path uses the sequential SLOPE strong rule of Larsson,
Bogdan and Wallin (2020), with these checks and repairs. The total inner iteration
budget is `maxiter` per level, including repairs. The last single iteration of a
budget cannot start an APG solve, which requires at least two.

This is a screened APG driver; it performs no cluster-coordinate updates.
Returns [`SLOPEResults`](@ref) or [`SLOPEPathResults`](@ref). It accepts dense
floating-point coefficient vectors and dense or sparse designs, with no data
conversion or statistical preprocessing. The loss data and starting coefficients
must have the same floating-point element type.
"""
struct SLOPEAPG{T<:AbstractFloat} <: ProximalSolver
  maxiter::Int
  tol::T
  function SLOPEAPG(; maxiter::Integer=10_000, tol::Real=1e-7)
    maxiter >= 2 || throw(ArgumentError("maxiter must be at least 2"))
    isfinite(tol) && tol > 0 || throw(ArgumentError("tol must be finite and positive"))
    t = float(tol)
    new{typeof(t)}(Int(maxiter), t)
  end
end

Base.summary(::SLOPEAPG) = "Screened SLOPE accelerated proximal gradient"

"""
    SLOPEResults

Numerical result of `solve!(x, f, g, SLOPEAPG())`. `minimizer` aliases `x`;
`iterations`, `converged`, `kkt_residual`, `working_size`, `kkt_repairs` and the
full loss `gradient` describe the returned point. A small reduced-problem
residual alone never sets `converged=true`.
"""
struct SLOPEResults{T,V<:AbstractVector{T}}
  minimizer::V
  iterations::Int
  converged::Bool
  kkt_residual::T
  working_size::Int
  kkt_repairs::Int
  gradient::Vector{T}
end

"""
    SLOPEPathResults

Numerical SLOPE path returned by `solve_path(f, g, factors, SLOPEAPG())`.
`lambda` contains the scalar multipliers of the input penalty's weights `g.λ`,
`solutions` contains independent coefficient snapshots. Per-level fields are
`iterations`, `converged`, `kkt_residuals`, `working_sizes` and `kkt_repairs`.
Failed levels are retained with `converged=false`; every later level receives
its own full optimality check, even if its warm start was not converged.
"""
struct SLOPEPathResults{T}
  lambda::Vector{T}
  solutions::Vector{Vector{T}}
  iterations::Vector{Int}
  converged::BitVector
  kkt_residuals::Vector{T}
  working_sizes::Vector{Int}
  kkt_repairs::Vector{Int}
end

_slope_loss(f::LeastSquaresLoss) = (f.X, f.Y, one(eltype(f.Y)))
_slope_loss(f::Scaled{<:LeastSquaresLoss}) = (f.f.X, f.f.Y, f.α)
_slope_loss(f) = throw(ArgumentError("SLOPEAPG supports single-response LeastSquaresLoss, optionally Scaled"))

function _check_slope_data(x::Vector{T}, f, g::SLOPE) where {T<:AbstractFloat}
  X, y, scale = _slope_loss(f)
  y isa AbstractVector || throw(ArgumentError("SLOPEAPG needs a single response vector"))
  n, p = size(X)
  n > 0 && p > 0 || throw(ArgumentError("X must have positive dimensions"))
  length(y) == n && length(x) == p && length(g.λ) == p ||
    throw(DimensionMismatch("response, iterate and SLOPE weights must match X"))
  T == float(promote_type(eltype(X),eltype(y))) ||
    throw(ArgumentError("loss data and iterate must have the same floating-point element type"))
  isfinite(scale) && scale > 0 || throw(ArgumentError("loss scale must be finite and positive"))
  # Implicit matrices must not be scanned entry by entry (centering a sparse
  # design would turn this into O(n*p) work). Products below check finiteness
  # of the null gradient; the caller owns validation of its matrix storage.
  all(isfinite, y) && all(isfinite, x) ||
    throw(ArgumentError("loss data and iterate must be finite"))
  all(isfinite, g.λ) && all(>=(0), g.λ) && issorted(g.λ; rev=true) ||
    throw(ArgumentError("SLOPE weights must be finite, nonnegative and nonincreasing"))
  X, y, scale
end

# Preserve the normalized least-squares arithmetic of the extracted estimator.
_slope_scale(v, scale, n) = scale == one(eltype(v))/n ? v/n : scale*v
_slope_gradient(X,y,x,scale) = _slope_scale(transpose(X)*(X*x-y),scale,length(y))

# Algorithm 2 of Larsson, Bogdan and Wallin (2020): thresholds are by rank,
# not tied to the original predictor indices.
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

# For non-strided designs retain certificate buffers and the restricted loss
# across path levels. The matrix owns its storage and column restriction:
# X[:, E] must preserve an efficient representation. The full set reuses X.
mutable struct _SLOPEWorkspace{T}
  residual::Vector{T}
  gradient::Vector{T}
  trial::Vector{T}
  point::Vector{T}
  indices::Vector{Int}
  loss::Any
end
_slope_workspace(X::StridedMatrix,y) = nothing
function _slope_workspace(X,y)
  T = eltype(y); n,p = size(X)
  _SLOPEWorkspace(zeros(T,n),zeros(T,p),zeros(T,p),zeros(T,p),
                  collect(1:p),LeastSquaresLoss(y,X))
end
_slope_restricted_loss(X,y,E,::Nothing) =
  LeastSquaresLoss(y,length(E) == size(X,2) ? X : X[:,E])
function _slope_restricted_loss(X,y,E,w::_SLOPEWorkspace)
  if E != w.indices
    w.loss = LeastSquaresLoss(y,length(E) == size(X,2) ? X : X[:,E])
    copyto!(resize!(w.indices,length(E)),E)
  end
  w.loss
end
_slope_nullgradient(X,y,scale,::Nothing) = _slope_scale(transpose(X)*y,scale,length(y))
function _slope_nullgradient(X,y,scale,w::_SLOPEWorkspace)
  mul!(w.gradient,transpose(X),y)
  w.gradient .= _slope_scale(w.gradient,scale,length(y))
  w.gradient
end
_slope_gradient(X,y,x,scale,::Nothing) = _slope_gradient(X,y,x,scale)
function _slope_gradient(X,y,x,scale,w::_SLOPEWorkspace)
  mul!(w.residual,X,x)
  w.residual .-= y
  mul!(w.gradient,transpose(X),w.residual)
  w.gradient .= _slope_scale(w.gradient,scale,length(y))
  w.gradient
end

function _slope_kkt(X,y,x,lambda,scale,::Nothing)
  grad = _slope_gradient(X,y,x,scale)
  trial = similar(x)
  prox!(trial, SLOPE(lambda), x-grad, one(eltype(x)))
  norm(x-trial,Inf), grad, trial
end

function _slope_kkt(X,y,x,lambda,scale,w::_SLOPEWorkspace)
  grad = _slope_gradient(X,y,x,scale,w)
  w.point .= x .- grad
  prox!(w.trial,SLOPE(lambda),w.point,one(eltype(x)))
  residual = zero(eltype(x))
  for j in eachindex(x)
    residual = max(residual,abs(x[j]-w.trial[j]))
  end
  residual,grad,w.trial
end

function _slope_fit!(x,X,y,lambda,scale,candidates,method,w)
  p = length(x)
  indices = collect(candidates)
  all(j -> j isa Integer && 1 <= j <= p, indices) || throw(ArgumentError("candidate indices must be integers in 1:p"))
  E = sort!(unique!(Int.(indices)))
  # A restricted sorted penalty uses its leading weights only when every
  # coefficient outside the working set is zero.
  E = sort!(union(E,findall(!iszero,x)))
  total, repairs = 0, 0
  target = method.tol * max(one(eltype(x)),norm(_slope_nullgradient(X,y,scale,w),Inf))
  isfinite(target) || throw(ArgumentError("null gradient must be finite in the supplied loss units"))
  while true
    if !isempty(E) && total + 1 < method.maxiter
      b = x[E]
      f = scale * _slope_restricted_loss(X,y,E,w)
      g = SLOPE(lambda[1:length(E)])
      options = ProximalOptions(;maxiter=max(2,method.maxiter-total),ftol=eps(Float64),
        xtol=eps(Float64),gradtol=method.tol/10,allow_f_increases=true)
      r = solve!(b,f,g,AccProxGradDescent(),options)
      total += r.iterations
      x[E] = b
    end
    residual, grad, trial = _slope_kkt(X,y,x,lambda,scale,w)
    converged = isfinite(residual) && residual <= target
    (converged || total + 1 >= method.maxiter) &&
      return SLOPEResults(x,total,converged,residual,length(E),repairs,grad)
    added = setdiff(findall(j -> abs(trial[j]) > target,1:p),E)
    if isempty(added)
      length(E) == p && continue
      added = setdiff(1:p,E)
    end
    append!(E,added);sort!(E);repairs += 1
  end
end

function solve!(x::Vector{<:AbstractFloat}, f::AbstractFunction, g::SLOPE, method::SLOPEAPG;
                candidates=eachindex(x))
  X,y,scale = _check_slope_data(x,f,g)
  _slope_fit!(x,X,y,g.λ,scale,candidates,method,_slope_workspace(X,y))
end

"""
    lambda_max(f, g::SLOPE, x::Vector)

For single-response least squares, optionally scaled, return the smallest
multiplier of the SLOPE weights making zero optimal: the maximum of the sorted
absolute null-gradient prefix sums divided by the weight prefix sums. `x`
supplies the coefficient type and dimensions and is not modified. All-zero
weights give `Inf` unless the null gradient is zero, in which case the result
is zero. This is an optimization threshold, with no statistical calibration.
"""
function lambda_max(f::Union{LeastSquaresLoss,Scaled{<:LeastSquaresLoss}},g::SLOPE,x::Vector{<:AbstractFloat})
  X,y,scale = _check_slope_data(x,f,g)
  nullgradient = _slope_nullgradient(X,y,scale,_slope_workspace(X,y))
  all(isfinite,nullgradient) || throw(ArgumentError("null gradient must be finite in the supplied loss units"))
  numerators = cumsum(sort(abs.(nullgradient);rev=true))
  denominators = cumsum(g.λ)
  maximum(iszero(d) ? (iszero(v) ? zero(v) : oftype(v,Inf)) : v/d for (v,d) in zip(numerators,denominators))
end

function _slope_default_x(f)
  X,y,_ = _slope_loss(f)
  zeros(float(promote_type(eltype(X),eltype(y))),size(X,2))
end

"""
    solve_path(f, g::SLOPE, factors, method::SLOPEAPG; x, screening=true)

Solve single-response least-squares problems `f + factors[k]*g` by screened APG.
`factors` must be positive, finite and nonincreasing. `x` defaults to a dense
zero vector and holds the last solution on return; saved solutions do not alias
it. Screening always includes the current support and repairs violations using
the full SLOPE proximal fixed-point equation. `screening=false` fits all columns.
The caller supplies already prepared data and penalty weights. See
[`SLOPEAPG`](@ref) for the residual and per-level iteration budget.
"""
function solve_path(f::AbstractFunction,g::SLOPE,factors::AbstractVector{<:Real},method::SLOPEAPG;
                    x=_slope_default_x(f),screening::Bool=true)
  X,y,scale = _check_slope_data(x,f,g)
  T = eltype(x);a = T.(factors)
  !isempty(a) && all(isfinite,a) && all(>(0),a) && issorted(a;rev=true) ||
    throw(ArgumentError("factors must be positive, finite and nonincreasing"))
  workspace = _slope_workspace(X,y)
  grad = zeros(T,length(x)) # first level uses all columns
  previous = first(a).*g.λ
  out = SLOPEPathResults(a,Vector{T}[],Int[],BitVector(),T[],Int[],Int[])
  for (i,factor) in enumerate(a)
    current = factor.*g.λ
    E = !screening || i == 1 ? collect(eachindex(x)) :
      union(_slope_strong(grad,previous,current),findall(!iszero,x))
    r = _slope_fit!(x,X,y,current,scale,E,method,workspace)
    push!(out.solutions,copy(x));push!(out.iterations,r.iterations)
    push!(out.converged,r.converged);push!(out.kkt_residuals,r.kkt_residual)
    push!(out.working_sizes,r.working_size);push!(out.kkt_repairs,r.kkt_repairs)
    previous,grad = current,r.gradient
  end
  out
end
