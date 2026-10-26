# active-set version of the accelerated proximal gradient method: the active set
# is the set of active coordinates of a SparseIterate (its stored entries) or of
# an AtomIterate (its active groups); each outer iteration adds the coordinates
# that violate the optimality conditions and minimizes over the active set with
# AccProxGradDescent

"""
    ActiveAccProxGradDescent(; β = 0.5, α = 0.9, max_add = 100, growth = 2, max_outer = 1000)

Active-set accelerated proximal gradient descent, for `f(x) + g(x)` with a
sparse minimizer, such as the lasso or the group lasso. The active set is the
set of stored entries of a `SparseIterate`, or the set of active groups of an
`AtomIterate`, whose coordinates are groups. Each outer iteration

1. removes the coordinates that are zero from the active set (`dropzeros!`);
2. computes the full gradient `∇f(x)` and finds the coordinates outside the
   active set that violate the optimality conditions, `kkt_violation > 0`;
3. stops if there are none and `x` minimizes `f + g` over the active set, that
   is, the last inner solve converged (or `x = 0`); an inner solve stopped by
   `maxiter` is thus repeated. It also stops after a converged inner solve
   that changed no entry of `x`: the next one would repeat it. This happens
   within rounding of the smallest penalty with a zero solution, where the
   check flags a coordinate that the proximal step leaves at zero;
4. adds the violators to the active set (`activate!`), the largest violations
   first, until they hold `max(max_add, (growth - 1) s)` entries, where `s` is
   the number of entries left in the active set by step 1, and with them the
   violators whose violation equals the last one;
5. minimizes `f + g` over the active set with [`AccProxGradDescent`](@ref)`(; β, α)`,
   warm-started from the current values.

The limit in step 4 keeps the active set from filling up with the many
coordinates that violate the optimality conditions at a poor starting point,
such as zero for a small penalty: at each outer iteration the active set grows
by a factor of at most `growth` over the nonzero entries of `x`, or by `max_add`
entries if that is more. So it reaches a large support in a few outer iterations,
but stays close to the support. `growth = 1` adds `max_add` entries at a time,
and `max_add = typemax(Int)` removes the limit.

Step 5 runs on `restrict(f, S)` and `restrict(g, S)` from ProximalBase, a
problem in the active entries `S` only; step 2 is the only one that involves
all coordinates. `f` and `g` need `restrict`, `g` needs `kkt_violation` and a full `prox!`, and
`f` needs `value_and_gradient!` at the iterate: in ProximalBase these are, among
others, `QuadraticFunction`, `SqrNormL2`, `LeastSquaresLoss` and `GLMLoss`,
with `NormL1`, `GroupNormL2`, `ZeroFunction` and the other separable penalties.

For the group lasso `GroupNormL2`, an `AtomIterate` that shares the groups of
`g`, `AtomIterate(x, g.groups)`, makes the groups the coordinates: a group joins and
leaves the active set whole. A dense `x` takes this route when the groups of `g`
cover all coordinates. With a `SparseIterate`, the coordinates of a group at
zero share the violation of the group, so a group that violates the optimality
conditions joins the active set whole too.

Success also requires the full proximal fixed-point residual to be at most
`options.gradtol * max(1, norm(initial_gradient, Inf))`. A repeated inner solution
that fails this check returns `converged = false`.

`max_outer` limits the number of outer iterations. The
[`ProximalOptions`](@ref) apply to each inner solve. Use with
[`solve!`](@ref), which returns an [`ActiveSetResults`](@ref).
"""
struct ActiveAccProxGradDescent{T<:AbstractFloat} <: ProximalSolver
  β::T            # backtracking factor of the inner AccProxGradDescent
  α::T            # factor by which its L shrinks before each iteration
  max_add::Int    # entries that an outer iteration may always add
  growth::Int     # factor by which an outer iteration may grow the nonzero entries
  max_outer::Int  # outer iteration limit
end

Base.summary(::ActiveAccProxGradDescent) = "Active-Set Accelerated Proximal Gradient Descent"

function ActiveAccProxGradDescent(; β::AbstractFloat = 0.5, α::AbstractFloat = 0.9, max_add::Integer = 100,
                                  growth::Integer = 2, max_outer::Integer = 1000)
  0 < β < 1 || throw(ArgumentError("β must be in (0, 1)."))
  0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]."))
  max_add > 0 || throw(ArgumentError("max_add must be positive."))
  growth > 0 || throw(ArgumentError("growth must be positive."))
  max_outer > 0 || throw(ArgumentError("max_outer must be positive."))
  ActiveAccProxGradDescent(promote(β, α)..., Int(max_add), Int(growth), Int(max_outer))
end

"""
    ActiveSetResults

Returned by [`solve!`](@ref) with an [`ActiveAccProxGradDescent`](@ref):
`minimizer` (the `x` passed to `solve!`), `minimum` (`f + g` at the
minimizer), `outer_iterations`, `inner_iterations` (summed over the inner
solves), `converged` (the full proximal fixed-point residual meets the requested
threshold after the inner solve), `inner_converged`
(every inner solve converged), `max_violation` (the largest `kkt_violation`
outside the active set at the minimizer, `-Inf` if there is no such
coordinate) and `active_set_size` (the number of entries in the active set,
those of its groups for an `AtomIterate`).
"""
struct ActiveSetResults{X,T}
    minimizer::X
    minimum::T
    outer_iterations::Int
    inner_iterations::Int
    converged::Bool
    inner_converged::Bool
    max_violation::T
    active_set_size::Int
end

Base.summary(::ActiveSetResults) = "Active-Set Accelerated Proximal Gradient Descent"
minimizer(r::ActiveSetResults) = r.minimizer
minimum(r::ActiveSetResults) = r.minimum
converged(r::ActiveSetResults) = r.converged

function Base.show(io::IO, r::ActiveSetResults)
    @printf io "Results of Optimization Algorithm\n"
    @printf io " * Algorithm: %s\n" summary(r)
    @printf io " * Minimum: %e\n" minimum(r)
    @printf io " * Outer iterations: %d\n" r.outer_iterations
    @printf io " * Inner iterations: %d\n" r.inner_iterations
    @printf io " * Active set size: %d\n" r.active_set_size
    @printf io " * Convergence: %s\n" converged(r)
    @printf io "   * largest KKT violation outside the active set: %.2e\n" r.max_violation
    @printf io "   * every inner solve converged: %s\n" r.inner_converged
    return
end

# x is the starting point and is overwritten with the solution; its active
# coordinates are the active set
function solve!(
    x::Union{SparseIterate{T, 1}, AtomIterate{T}},
    f::AbstractFunction,
    g::AbstractFunction,
    method::ActiveAccProxGradDescent,
    options::ProximalOptions = ProximalOptions()
    ) where {T<:AbstractFloat}

  _check_groups(x, g)
  inner_method = AccProxGradDescent(; β = T(method.β), α = T(method.α))
  grad = Vector{T}(undef, length(x))
  trial, point = similar(grad), similar(grad)
  violators, violations = Int[], T[]
  S = Int[]                   # the active entries

  outer_iterations, inner_iterations = 0, 0
  solved = false              # x minimizes f + g over its active set
  moved = true                # the last inner solve changed an entry of x
  inner_converged = true
  kkt_converged = false
  stationarity_scale = one(T)

  options.show_trace && @printf "Outer   Active    Added   Largest violation\n"

  while true
    dropzeros!(x)
    f_x = value_and_gradient!(grad, f, x)
    outer_iterations == 0 && (stationarity_scale = max(one(T), norm(grad, Inf)))
    max_violation = _kkt_violators!(violators, violations, g, grad, x)

    # a minimizer over the active set that no coordinate outside it can improve
    # is a minimizer; so is x = 0 if no coordinate can improve it. A converged
    # inner solve that changed nothing would only be repeated
    if isempty(violators) || (solved && !moved)
      @. point = x - grad
      prox!(trial, g, point, one(T))
      residual = _maxabs_diff(x, trial)
      kkt_converged = isfinite(residual) && residual <= options.gradtol * stationarity_scale
    end
    if kkt_converged || outer_iterations == method.max_outer || (solved && !moved)
      return ActiveSetResults(x, f_x + g(x), outer_iterations, inner_iterations,
                              kkt_converged, inner_converged, max_violation,
                              length(_active_entries!(S, x)))
    end
    outer_iterations += 1

    # the largest violations join the s nonzero entries first, until they hold
    # limit entries, which are among the limit largest; the limit does not
    # split violations that are equal, as those of the coordinates of a group at
    # zero are: alone, a coordinate of the group could stay at zero, be dropped
    # and be added again
    s = length(_active_entries!(S, x))
    limit = max(method.max_add, _saturated_product(method.growth - 1, s))
    if _num_entries(x, violators) > limit
      order = partialsortperm(violations, 1:min(limit, length(violations)); rev = true)
      vmin, added = violations[order[end]], 0
      for o in order
        added += _num_entries(x, violators[o])
        if added >= limit
          vmin = violations[o]
          break
        end
      end
      violators = violators[violations .>= vmin]
    end
    for k in violators
      activate!(x, k)
    end

    # minimize over the active entries
    _active_entries!(S, x)
    if options.show_trace
      @printf "%5d   %6d   %6d   %14e\n" outer_iterations length(S) _num_entries(x, violators) max_violation
    end
    xS = T[x[i] for i in S]
    res = _active_inner_solve!(xS, restrict(f, S), restrict(g, S), inner_method,
                               options, options.gradtol * stationarity_scale)
    moved = false
    for (j, i) in enumerate(S)
      moved |= x[i] != xS[j]
      x[i] = xS[j]
    end

    inner_iterations += res.iterations
    solved = converged(res)
    inner_converged &= solved
  end
end

# Keep acceleration state when a change rule would stop before stationarity.
# Certificate work occurs only at a proposed stop and is counted in the inner
# result. A requested dual gap retains its existing independent stopping rule.
function _active_inner_solve!(x, f, g, method, options, threshold)
  issmooth(f) && isproximable(g) || throw(ArgumentError("the restricted active-set problem needs a smooth loss and proximable penalty"))
  t0 = time()
  state = initial_state(method, options, f, g, x)
  gapev = options.gaptol > 0 ? _gapevaluator(f, g, x) : nothing
  gapev === nothing || return _solve_gradient!(state, f, g, method, options, gapev, t0)
  gradient, point = similar(x), similar(x)
  certificate = function (st)
    value_and_gradient!(gradient, f, st.x)
    st.f_calls += 1
    st.grad_calls += 1
    @. point = st.x - gradient
    prox!(gradient, g, point, one(eltype(x)))
    st.prox_calls += 1
    residual = _maxabs_diff(st.x, gradient)
    isfinite(residual) && residual <= threshold
  end
  _solve_gradient!(state, f, g, method, options, nothing, t0; certificate)
end

# a dense x is converted to an iterate and overwritten with the solution: an
# AtomIterate with the groups of a GroupNormL2 that cover all coordinates, and a
# SparseIterate otherwise
function solve!(
    x::Vector{T},
    f::AbstractFunction,
    g::AbstractFunction,
    method::ActiveAccProxGradDescent,
    options::ProximalOptions = ProximalOptions()
    ) where {T<:AbstractFloat}

  xs = _active_set_iterate(x, g)
  r = solve!(xs, f, g, method, options)
  copyto!(x, xs)
  ActiveSetResults(x, r.minimum, r.outer_iterations, r.inner_iterations,
                   r.converged, r.inner_converged, r.max_violation, r.active_set_size)
end

_active_set_iterate(x::Vector, ::AbstractFunction) = SparseIterate(x)
# the groups are disjoint sets of positive indices, so they partition 1:p when
# they hold p indices up to p
_active_set_iterate(x::Vector, g::GroupNormL2) =
  sum(length, g.groups; init = 0) == length(x) && all(G -> maximum(G) <= length(x), g.groups) ?
    AtomIterate(x, g.groups) : SparseIterate(x)

# kkt_violation for GroupNormL2 on an AtomIterate takes group k of x as group k of g
_check_groups(x, g) = nothing
_check_groups(x::AtomIterate, g::GroupNormL2) =
  x.groups === g.groups || x.groups == g.groups ||
    throw(ArgumentError("The groups of x must be the groups of g, as in AtomIterate(x, g.groups)."))

_saturated_product(a::Int, b::Int) = b > 0 && a > typemax(Int) ÷ b ? typemax(Int) : a * b

# the number of entries of coordinate k of x, and of the coordinates in ks
_num_entries(::SparseIterate, k::Int) = 1
_num_entries(x::AtomIterate, k::Int) = length(x.groups[k])
_num_entries(x, ks::AbstractVector{Int}) = sum(k -> _num_entries(x, k), ks; init = 0)

# the entries of the active coordinates of x
function _active_entries!(S, x::SparseIterate)
  copyto!(resize!(S, nactive(x)), activecoordinates(x))
end

function _active_entries!(S, x::AtomIterate)
  empty!(S)
  for k in activecoordinates(x)
    append!(S, x.groups[k])
  end
  S
end

# Collect the coordinates of x outside its active set with a positive
# kkt_violation, and their violations; return the largest violation.
function _kkt_violators!(violators, violations, g, grad, x::Union{SparseIterate{T}, AtomIterate{T}}) where T
  empty!(violators)
  empty!(violations)
  max_violation = T(-Inf)
  for k in 1:ncoordinates(x)
    isactive(x, k) && continue
    v = kkt_violation(g, grad, x, k)
    max_violation = max(max_violation, v)
    if v > 0
      push!(violators, k)
      push!(violations, v)
    end
  end
  max_violation
end
