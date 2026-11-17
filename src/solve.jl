# Once-per-solve validation; no numeric solver arithmetic or conversion changes.
using ProximalBase: leastsquares_data
function _allfinite(A::Array)
  finite = true
  @inbounds @simd for i in eachindex(A)
    finite &= isfinite(A[i])
  end
  finite
end

function _scalar_parameter(v, ::Type{T}, name; positive = false) where T
  v isa Real && isfinite(v) && (positive ? v > 0 : v >= 0) ||
    throw(ArgumentError("$name must be finite and $(positive ? "positive" : "nonnegative")"))
  native = try
    T(v)
  catch
    throw(ArgumentError("$name is not representable in $T"))
  end
  isfinite(native) && (!iszero(v) ? native > 0 : iszero(native)) ||
    throw(ArgumentError("$name is not representable without overflow or underflow in $T"))
  nothing
end

# The loss scale of a Scaled loss, for data of type T. A Float32 or Float64 scale must be finite and
# positive with a conversion to T that is finite and nonzero (a value that is subnormal in T is
# accepted). A fixed-width integer or Bool scale must be positive and equal to its conversion to T, so
# that ProximalBase's oracles and the solvers' own T-valued scale use the same number. A scale of any
# other type is refused.
function _check_loss_scale(α, ::Type{T}) where T
  if α isa Union{Float32, Float64}
    _scalar_parameter(α, T, "loss scale"; positive = true)
  elseif α isa Union{Base.BitInteger, Bool}
    α > 0 || throw(ArgumentError("loss scale must be finite and positive"))
    T(α) == α || _loss_scale_error(α, T, "is not exactly representable in $T")
  else
    _loss_scale_error(α, T, "has an unsupported type")
  end
  nothing
end

# Whether the Float64 value a passes the rule of _check_loss_scale for data of type T
_float64_scale_ok(a::Float64, ::Type{T}) where T = isfinite(a) && a > 0 && (n = T(a); isfinite(n) && n > 0)

@noinline function _loss_scale_error(α, ::Type{T}, why) where T
  a = try Float64(α) catch; nothing end
  hint = a isa Float64 && _float64_scale_ok(a, T) ?
    "; convert it explicitly with Float64(α) * LeastSquaresLoss(y, X), here α = $a" : ""
  throw(ArgumentError("loss scale $α of type $(typeof(α)) $why; only Float32 and Float64 scales and fixed-width integer scales that $T represents exactly are supported$hint"))
end

# The penalty check of _check_data for an x that is not a BlockIterate: a NormL1, with or without weights,
# or an unweighted ElasticNet, which the gradient solvers (PGD and APG) and CDSolver accept alike. The
# levels must pass _scalar_parameter for the data type T (finite, nonnegative, representable without
# overflow or underflow). A NormL1 with weights also passes _check_l1_weights.
function _check_penalty(g, x, ::Type{T}) where T
  if g isa NormL1
    g.w === nothing ? _scalar_parameter(g.λ0, T, "penalty lambda") : _check_l1_weights(g, x, T)
  elseif g isa ElasticNet && g.w === nothing
    _scalar_parameter(g.λ1, T, "penalty lambda1")
    _scalar_parameter(g.λ2, T, "penalty lambda2")
  else
    throw(ArgumentError("only NormL1 or unweighted ElasticNet is supported"))
  end
  nothing
end

# The weights of a NormL1 for data of type T. They must be a Vector{T} with one entry per entry of x,
# finite and nonnegative, and x must not alias them (x is the caller's array or owner, as for X and y).
# The solvers use the coefficient cⱼ = T(λ0) wⱼ, formed in T, of the entry j: it must be finite, and
# nonzero where T(λ0) and wⱼ are both positive (a product that is subnormal in T is accepted; a zero
# level or weight gives the coefficient 0, which leaves the entry unpenalized when it comes from wⱼ = 0).
function _check_l1_weights(g, x, ::Type{T}) where T
  _scalar_parameter(g.λ0, T, "penalty lambda")
  w = g.w
  w isa Vector{T} ||
    throw(ArgumentError("penalty weights must be a Vector{$T} (the element type of the data); convert an array with collect($T, vec(w)), which takes it in linear order"))
  length(w) == length(x) ||
    throw(DimensionMismatch("the penalty has $(length(w)) weights but x has $(length(x)) entries"))
  Base.mightalias(x, w) && throw(ArgumentError("mutable x must not alias the penalty weights"))
  λ = T(g.λ0)
  @inbounds for j in eachindex(w)
    wj = w[j]
    c = λ * wj
    isfinite(wj) && wj >= 0 && isfinite(c) && (!iszero(c) || iszero(λ) || iszero(wj)) ||
      _l1_weight_error(λ, wj, j, T)
  end
  nothing
end

@noinline function _l1_weight_error(λ::T, wj::T, j, ::Type{T}) where T
  isfinite(wj) && wj >= 0 ||
    throw(ArgumentError("penalty weight $j must be finite and nonnegative"))
  throw(ArgumentError("the penalty coefficient of entry $j, lambda * weight in $T, " *
                      (isinf(λ * wj) ? "overflows" : "underflows to zero") * "; rescale the level or the weights"))
end

# The penalty of group coordinate descent on a BlockIterate: a GroupNormL2 whose level and weights
# convert to T without overflow, or underflow to 0 from a nonzero value, and whose groups are those
# of x, in the same order and with the same ordered members.
function _check_penalty(g, x::BlockIterate, ::Type{T}) where T
  g isa GroupNormL2{<:Union{Float32, Float64}} ||
    throw(ArgumentError("a BlockIterate needs a GroupNormL2 penalty with Float32 or Float64 parameters"))
  _scalar_parameter(g.λ0, T, "penalty lambda")
  for k in eachindex(g.w)
    _weight_ok(g.w[k], T) || _weight_error(g.w[k], k, T)
  end
  ncoordinates(x) == length(g.groups) ||
    throw(DimensionMismatch("x has $(ncoordinates(x)) groups but the penalty has $(length(g.groups))"))
  for k in 1:ncoordinates(x)
    blockindices(x, k) == g.groups[k] ||
      throw(DimensionMismatch("the groups of x and of the penalty differ at group $k"))
  end
  nothing
end

# The rule of _scalar_parameter for a nonnegative value
function _weight_ok(w, ::Type{T}) where T
  native = T(w)
  isfinite(w) && w >= 0 && isfinite(native) && (iszero(w) ? iszero(native) : native > 0)
end

@noinline function _weight_error(w, k, ::Type{T}) where T
  _scalar_parameter(w, T, "group weight $k")
  throw(ArgumentError("group weight $k is not valid in $T"))
end

# Loss, data, shape, penalty and alias checks shared by the dense gate and the
# CD owner gate; `x` is the caller's original array or owner, of length `length(x)`.
function _check_data(x, f, g, ::Type{T}) where T
  base = if f isa LeastSquaresLoss
    f
  elseif f isa Scaled && f.f isa LeastSquaresLoss
    _check_loss_scale(leastsquares_data(f).α, T)
    f.f
  else
    throw(ArgumentError("only LeastSquaresLoss or one positive Scaled(LeastSquaresLoss) is supported"))
  end
  base.X isa Matrix{T} && base.Y isa Vector{T} ||
    throw(ArgumentError("X must be Matrix{$T} and y Vector{$T}; sparse designs, matrix responses and mixed array types are deferred"))
  n, p = size(base.X)
  n > 0 && p > 0 || throw(DimensionMismatch("X must have positive row and column counts"))
  length(base.Y) == n && length(x) == p || throw(DimensionMismatch("x/y dimensions do not match X"))
  _check_penalty(g, x, T)
  (Base.mightalias(x, base.X) || Base.mightalias(x, base.Y)) &&
    throw(ArgumentError("mutable x must not alias borrowed X or y"))
  base
end

function _check_problem(x, f, g)
  x isa Vector && eltype(x) in (Float32, Float64) ||
    throw(ArgumentError("x must be a dense Vector{Float32} or Vector{Float64}"))
  base = _check_data(x, f, g, eltype(x))
  _allfinite(x) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

# Coordinate descent also accepts a one-dimensional SparseIterate. Only its
# public active values are inspected; the aliasing check uses the owner itself,
# so an empty owner whose backing storage is shared with X or y is refused too.
_is_cd_owner(x) = x isa SparseIterate{<:Any, 1} && eltype(x) in (Float32, Float64)
function _check_owner_problem(x, f, g)
  _is_cd_owner(x) ||
    throw(ArgumentError("x must be a dense Vector or a one-dimensional SparseIterate of Float32 or Float64"))
  base = _check_data(x, f, g, eltype(x))
  all(isfinite, activevalues(x)) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

# Group-lasso block coordinate descent on a BlockIterate. Runs before any copy of x or draw from the
# RNG; the entries of inactive groups are zero.
function _check_block_problem(x, f, g, method)
  x isa BlockIterate{<:Union{Float32, Float64}} ||
    throw(ArgumentError("block coordinate descent needs a BlockIterate of Float32 or Float64"))
  method.momentum === true &&
    throw(ArgumentError("block coordinate descent does not support momentum; use momentum = false or nothing"))
  base = _check_data(x, f, g, eltype(x))
  all(isfinite, x) && _allfinite(base.Y) && _allfinite(base.X) ||
    throw(ArgumentError("x, X and y must contain only finite values"))
  nothing
end

_check_keywords(kwargs) = isempty(kwargs) ||
  throw(ArgumentError("unsupported solve! keywords: $(join(keys(kwargs), ", "))"))
_check_start(f_x) = isfinite(f_x) || throw(ArgumentError("start from a point where f is finite"))

function _solve_gradient!(state, f, g, method, options, t0 = time())

  tr = OptimizationTrace{typeof(method)}()
  tracing = options.store_trace || options.show_trace || options.extended_trace || options.callback !== nothing
  stopped, stopped_by_callback, stopped_by_time_limit = false, false, false
  stagnated = false
  f_limit_reached, grad_limit_reached, prox_limit_reached = false, false, false
  x_converged, fg_converged, grad_converged, f_increased = false, false, false, false

  converged = false
  iteration = 0

  options.show_trace && @printf "Iter     Function value       |dx|/|x|       Step Size\n"

  while !converged && !stopped && iteration < options.maxiter
    iteration += 1

    try
      update_state!(f, g, state, method)
      isfinite(state.f_x + state.g_x) || error("the gradient step did not produce a finite objective")
    catch
      # Trials overwrite x for allocation-free iteration. An unsuccessful
      # search must still leave the caller's last accepted point intact.
      _copyto!(state.x, state.x_previous)
      rethrow()
    end

    x_converged, fg_converged,
    grad_converged, converged, f_increased = convergence_assessment(state, f, g, options)

    if tracing
      # update trace; callbacks can stop routine early by returning true
      stopped_by_callback = trace!(tr, state, iteration, options)
    end

    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false
    f_limit_reached = options.f_calls_limit > 0 && state.f_calls >= options.f_calls_limit
    grad_limit_reached = options.grad_calls_limit > 0 && state.grad_calls >= options.grad_calls_limit
    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit

    # a numerical-stagnation stop (see _stagnated), checked after trace! and any callback call
    # that is due at this iteration under print_every
    stagnated = _stagnated(state, options)

    increased = f_increased && !options.allow_f_increases
    if increased || stagnated || stopped_by_callback ||
        stopped_by_time_limit || f_limit_reached || grad_limit_reached || prox_limit_reached
        stopped = true
    end
  end # while
  # the residuals are stored as Float64, like the tolerances, whatever the element type
  return OptimizationResults{typeof(method), typeof(state.f_x), ndims(state.x), typeof(method), typeof(state.x)}(
                method,
                state.x,
                state.f_x + state.g_x,
                iteration,
                iteration == options.maxiter,
                converged,
                x_converged,
                options.xtol,
                Float64(_state_normdiff(state)),
                fg_converged,
                options.ftol,
                Float64(f_residual(state.f_x + state.g_x, state.f_x_previous + state.g_x_previous, options.ftol)),
                grad_converged,
                options.gradtol,
                Float64(g_residual(state)),
                f_increased,
                tr,
                state.backtrack_steps,
                state.f_calls,
                state.grad_calls,
                state.prox_calls,
                f_limit_reached || grad_limit_reached || prox_limit_reached,
                stagnated,
                NaN)           # gap sentinel, never computed

end
