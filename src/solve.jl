
# remove the zero entries or groups from the stored ones of a sparse iterate, so
# that products by it touch only its support; nothing to do for an Array
_drop!(x::AbstractArray) = x
_drop!(x::Union{SparseIterate, SymmetricSparseIterate, AtomIterate}) = dropzeros!(x)
_drop!(x::Tuple) = (foreach(_drop!, x); x)

# the gradient methods step from a point where f is finite, and keep to such
# points, rejecting the trial points off the domain of f
# the parameter N of OptimizationResults: the dimension of an array, 1 for a tuple
_resultdims(x::AbstractArray) = ndims(x)
_resultdims(::Tuple) = 1

_check_start(f_x) = isfinite(f_x) ||
  throw(ArgumentError("f(x0) = $f_x: start from a point where f is finite, such as the identity for LogDetLoss."))

"""
    solve!(x, f, g, method::ProximalSolver, options = ProximalOptions())

Minimize `f(x) + g(x)` starting from `x`, and overwrite `x` with the solution.
For a convex linear composite, use
`solve!(x, f, g, h, D, CondatVu(), options)` for `f(x) + g(x) + h(D*x)`;
see [`CondatVu`](@ref).

For [`ProximalGradientDescent`](@ref), [`AccProxGradDescent`](@ref) and
[`MonotoneAccProxGradDescent`](@ref), `f` is a smooth function of ProximalBase
(`issmooth(f)`) and `g` a proximable one (`isproximable(g)`), possibly
nonconvex, and `x` is an array of any shape that they accept, such as the
`p × k` coefficient matrix of a `LeastSquaresLoss` with `k` responses and a
`NuclearNorm` penalty; the result is an [`OptimizationResults`](@ref). There `x`
may also be a `SparseIterate`, a `SymmetricSparseIterate` (a symmetric matrix,
as for `KronQuadratic`, `LogDetLoss` and `IndBallL0(s; diagonal = false)`), or
for the group lasso `GroupNormL2` an `AtomIterate` that shares the groups of `g`
(`AtomIterate(x, g.groups)`): the iterates keep its type, zeros are dropped
after each step, and products by the iterates touch only their stored entries
or active groups. For
[`ActiveAccProxGradDescent`](@ref), `x` is a vector, a `SparseIterate` or an
`AtomIterate`, and the result is an `ActiveSetResults`. For
[`ADMMSolver`](@ref), both `f` and `g` are proximable and the result is an
`ADMMResults`. For [`CDSolver`](@ref) and [`ProxNewton`](@ref), see their
documentation.

The gradient solvers and ADMM also take a tuple of arrays with one element
type, `x = (x1, …, xK)`: a point of a product space, for functions of several
blocks such as ProximalBase's `SeparableSum(f1, …, fK)` (`fₖ` on block `k`) or a
penalty that couples the blocks. Norms and inner products are taken over all
the blocks, and a tuple of one array computes exactly what the array does.

# Example
```julia
using ProximalBase, ProximalSolvers
A, b = [2. 0.; 0. 1.], [-1., -1.]
x = zeros(2)
res = solve!(x, QuadraticFunction(A, b), NormL1(0.1), AccProxGradDescent())
```
"""
function solve!(
    initial_x::Union{AbstractArray, _Blocks},
    f::AbstractFunction,
    g::AbstractFunction,
    method::ProximalSolver,
    options::ProximalOptions = ProximalOptions()
    )

  issmooth(f) || throw(ArgumentError("$(summary(method)) needs a smooth f (issmooth(f)), but f is a $(typeof(f))."))
  isproximable(g) || throw(ArgumentError("$(summary(method)) needs a proximable g (isproximable(g)), but g is a $(typeof(g))."))
  _workspace_noalias(initial_x)
  t0 = time()
  state = initial_state(method, options, f, g, initial_x)
  gapev = options.gaptol > 0 ? _gapevaluator(f, g, initial_x) : nothing
  _solve_gradient!(state, f, g, method, options, gapev, t0)
end

# The iteration engine also serves SolverWorkspace, which supplies its existing
# state and gap buffers after resetting the counters and starting point.
function _solve_gradient!(state, f, g, method, options, gapev, t0 = time(); certificate = nothing)

  tr = OptimizationTrace{typeof(method)}()
  tracing = options.store_trace || options.show_trace || options.extended_trace || options.callback !== nothing
  stopped, stopped_by_callback, stopped_by_time_limit = false, false, false
  f_limit_reached, grad_limit_reached, prox_limit_reached = false, false, false
  x_converged, fg_converged, grad_converged, f_increased = false, false, false, false

  converged = false
  iteration = 0

  # with gaptol, the duality gap replaces the other convergence tests
  options.gaptol > 0 && gapev === nothing &&
    @warn "there is no duality gap for $(nameof(typeof(f))) with $(nameof(typeof(g))); gaptol is ignored." maxlog = 1
  relgap, relgap_iteration = NaN, -1

  options.show_trace && print_header(method, options)

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
    if gapev !== nothing
      if iteration % options.gapevery == 0
        relgap, relgap_iteration = _relgap!(gapev, f, g, state.x), iteration
        # a gap that cannot be computed here leaves the other tests in charge
        isnan(relgap) || (converged = relgap <= options.gaptol)
      else
        converged = false
      end
    end
    certificate === nothing || !(converged || f_increased) || (converged = certificate(state))

    if tracing
      # update trace; callbacks can stop routine early by returning true
      stopped_by_callback = trace!(tr, f, g, state, iteration, method, options)
    end

    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false
    f_limit_reached = options.f_calls_limit > 0 && state.f_calls >= options.f_calls_limit
    grad_limit_reached = options.grad_calls_limit > 0 && state.grad_calls >= options.grad_calls_limit
    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit

    # with a gap, an objective that rises by rounding near the solution does not
    # stop the solver: the primal converges before the dual point does
    increased = f_increased && !options.allow_f_increases && gapev === nothing
    if increased && certificate !== nothing
      F, Fprev = state.f_x + state.g_x, state.f_x_previous + state.g_x_previous
      increased = F - Fprev > 16 * eps(typeof(state.f_x)) * max(abs(F), abs(Fprev), one(F))
    end
    if increased || stopped_by_callback ||
        stopped_by_time_limit || f_limit_reached || grad_limit_reached || prox_limit_reached
        stopped = true
    end
  end # while
  gapev === nothing || relgap_iteration == iteration || (relgap = _relgap!(gapev, f, g, state.x))
  # A final gap check can fall between the scheduled checks when a limit or a
  # callback stops the solve. Report the chosen criterion at the returned point,
  # retaining the residual flags as diagnostics rather than as a gap certificate.
  if gapev !== nothing
    converged = isnan(relgap) ? x_converged || fg_converged || grad_converged : relgap <= options.gaptol
  end

  # the residuals are stored as Float64, like the tolerances, whatever the element type
  return OptimizationResults{typeof(method), typeof(state.f_x), _resultdims(state.x), typeof(method), typeof(state.x)}(
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
                relgap)

end
