# Once-per-solve validation; no numeric solver arithmetic or conversion changes.
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

# Loss, data, shape, penalty and alias checks shared by the dense gate and the
# CD owner gate; `x` is the caller's original array or owner, of length `length(x)`.
function _check_data(x, f, g, ::Type{T}) where T
  base = if f isa LeastSquaresLoss
    f
  elseif f isa Scaled && f.f isa LeastSquaresLoss
    _scalar_parameter(f.α, T, "loss scale"; positive = true)
    f.f
  else
    throw(ArgumentError("only LeastSquaresLoss or one positive Scaled(LeastSquaresLoss) is supported"))
  end
  base.X isa Matrix{T} && base.Y isa Vector{T} ||
    throw(ArgumentError("X must be Matrix{$T} and y Vector{$T}; sparse designs, matrix responses and mixed array types are deferred"))
  n, p = size(base.X)
  n > 0 && p > 0 || throw(DimensionMismatch("X must have positive row and column counts"))
  length(base.Y) == n && length(x) == p || throw(DimensionMismatch("x/y dimensions do not match X"))
  g isa NormL1 && g.w === nothing || throw(ArgumentError("only unweighted NormL1 is supported"))
  _scalar_parameter(g.λ0, T, "penalty lambda")
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

_check_keywords(kwargs) = isempty(kwargs) ||
  throw(ArgumentError("unsupported solve! keywords: $(join(keys(kwargs), ", "))"))
_check_start(f_x) = isfinite(f_x) || throw(ArgumentError("start from a point where f is finite"))

function _solve_gradient!(state, f, g, method, options, t0 = time())

  tr = OptimizationTrace{typeof(method)}()
  tracing = options.store_trace || options.show_trace || options.extended_trace || options.callback !== nothing
  stopped, stopped_by_callback, stopped_by_time_limit = false, false, false
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
      stopped_by_callback = trace!(tr, f, g, state, iteration, method, options)
    end

    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false
    f_limit_reached = options.f_calls_limit > 0 && state.f_calls >= options.f_calls_limit
    grad_limit_reached = options.grad_calls_limit > 0 && state.grad_calls >= options.grad_calls_limit
    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit

    increased = f_increased && !options.allow_f_increases
    if increased || stopped_by_callback ||
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
                NaN)           # gap sentinel, never computed

end
