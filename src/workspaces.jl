const _GradientSolver = Union{ProximalGradientDescent, AccProxGradDescent, MonotoneAccProxGradDescent}

struct _GradientBuffers{S, E}
  state::S
  gap::E
end

mutable struct _ADMMBuffers{X, T, E}
  xk::X
  u::X
  previous::X
  tmp::X
  ρ::T
  gap::E
end

struct _CDBuffers{X, M, S}
  iterate::X
  model::M
  state::S
end

"""
    SolverWorkspace(x, f, g, method, options = ProximalOptions())
    SolverWorkspace(x, f, g, method::CDSolver)

Allocate reusable buffers for repeated [`solve!`](@ref) calls with a fixed
loss, solver, options, iterate type and shape. Supports the three gradient
solvers, [`ADMMSolver`](@ref), and [`CDSolver`](@ref). For coordinate descent,
`f` may be an already configured [`CDModel`](@ref), for example with an
intercept. The workspace shares `x` with the caller.

`solve!(workspace)` starts from its current point. `solve!(workspace, gnew)`
uses a new penalty of the same concrete type; group partitions must stay the
same. This does not change the default penalty `workspace.g` supplied at
construction. [`reinit!`](@ref) copies a new starting point into the existing storage.
On symmetric iterates, the parameter rule of [`solve!`](@ref) is applied at
construction and again for each solve, keeping the supplied `workspace.g`.
Each call resets iteration history, counters and stopping tests. ADMM resets
its dual variable and penalty parameter too, unless `warm_start = true` is
passed to `solve!`, which keeps both from the previous solve.

Keep the loss data and group partitions fixed; create a new workspace to change
them, the solver configuration, or the dimensions. Do not share one workspace
between concurrent solves. Results share its minimizer and, for ADMM, its dual
buffer, so copy those arrays before another solve if they must be retained.
The workspace reuses solver-owned buffers; user loss/proximal operators,
tracing, returned result objects, and optional refit/Anderson work may allocate.

# Example
```julia
f = LeastSquaresLoss(y, X)
ws = SolverWorkspace(zeros(size(X, 2)), f, NormL1(0.1), AccProxGradDescent())
r1 = solve!(ws)
r2 = solve!(ws, NormL1(0.05))
reinit!(ws, zeros(size(X, 2)))
r3 = solve!(ws)
```
"""
struct SolverWorkspace{X, F, G, M, O, B, D}
  x::X
  f::F
  g::G
  method::M
  options::O
  buffers::B
  shape::D
end

function SolverWorkspace(x::Union{AbstractArray, _Blocks}, f::AbstractFunction,
                         g::AbstractFunction, method::_GradientSolver,
                         options::ProximalOptions = ProximalOptions())
  issmooth(f) || throw(ArgumentError("$(summary(method)) needs a smooth loss."))
  isproximable(g) || throw(ArgumentError("$(summary(method)) needs a proximable penalty."))
  _workspace_noalias(x)
  prepared = _symmetric_penalty(g, x)
  state = initial_state(method, options, f, prepared, x)
  gap = options.gaptol > 0 ? _gapevaluator(f, prepared, x) : nothing
  SolverWorkspace(x, f, g, method, options, _GradientBuffers(state, gap), _size(x))
end

function SolverWorkspace(x::Union{Array{T}, Tuple{Array{T}, Vararg{Array{T}}}},
                         f::AbstractFunction, g::AbstractFunction, method::ADMMSolver,
                         options::ProximalOptions = ProximalOptions()) where {T<:AbstractFloat}
  isproximable(f) && isproximable(g) ||
    throw(ArgumentError("ADMM needs a proximable loss and penalty."))
  _workspace_noalias(x)
  gap = options.gaptol > 0 ? _gapevaluator(f, g, x) : nothing
  buffers = _ADMMBuffers(_copy(x), _zero(x), _similar(x), _similar(x), T(method.ρ), gap)
  SolverWorkspace(x, f, g, method, options, buffers, _size(x))
end

_workspace_iterate(x::Union{SparseIterate, SymmetricSparseIterate, AtomIterate}, g) = x
_workspace_iterate(x::Vector{T}, g) where {T<:AbstractFloat} =
  g isa ProximalBase.AbstractGroupNorm ? AtomIterate(x, g.groups) : SparseIterate(x)

function SolverWorkspace(x, f::Union{AbstractFunction, CDModel}, g::AbstractFunction, method::CDSolver)
  xs = _workspace_iterate(x, g)
  prepared = _symmetric_penalty(g, xs)
  m = f isa CDModel ? f : cdmodel(f, xs)
  eltype(m) === eltype(xs) || throw(ArgumentError("the iterate and model must have the same element type."))
  _check_iterate(prepared, xs)
  check_penalty(m, prepared)
  initialize!(m, xs)
  buffers = _CDBuffers(xs, m, _CDState(eltype(xs), xs, method))
  SolverWorkspace(x, f, g, method, nothing, buffers, _size(x))
end

function SolverWorkspace(x, f, g, method::ProximalSolver, options::ProximalOptions = ProximalOptions())
  throw(ArgumentError("SolverWorkspace supports gradient solvers, CDSolver and ADMMSolver; got $(typeof(method))."))
end

function _workspace_penalty(ws::SolverWorkspace, g)
  _workspace_shape(ws)
  typeof(g) === typeof(ws.g) ||
    throw(ArgumentError("a workspace needs a penalty of type $(typeof(ws.g)); construct a new workspace for $(typeof(g))."))
  groups = _workspace_groups(ws.g)
  groups === nothing || groups == _workspace_groups(g) ||
    throw(ArgumentError("a workspace needs the original penalty's group partition."))
  g
end

_workspace_shape(ws::SolverWorkspace) = _size(ws.x) == ws.shape ||
  throw(DimensionMismatch("the workspace iterate was resized; construct a new workspace for a different shape."))

_workspace_groups(g) = nothing
_workspace_groups(g::ProximalBase.AbstractGroupNorm) = g.groups
_workspace_groups(g::Scaled) = _workspace_groups(g.f)
_workspace_groups(g::SeparableSum) = map(_workspace_groups, g.fs)

"""
    reinit!(workspace::SolverWorkspace, x)

Copy a new starting point into a workspace without replacing its buffers.
The type, element type, shape and, for sparse group iterates, partition must
match. This also clears ADMM's dual warm start. Returns the workspace.
Tuple blocks must have separate storage; cross-block source aliases are
rejected before any block is overwritten.
"""
function reinit!(ws::SolverWorkspace, x)
  _workspace_shape(ws)
  typeof(x) === typeof(ws.x) || throw(ArgumentError("the starting point must have type $(typeof(ws.x))."))
  _size(x) == ws.shape || throw(DimensionMismatch("the starting point must have size $(ws.shape)."))
  _workspace_partition(ws.x, x)
  _workspace_copyable(ws.x, x)
  _copyto!(ws.x, x)
  _workspace_reset!(ws.buffers, ws.method)
  ws
end

_workspace_partition(x, y) = nothing
_workspace_partition(x::AtomIterate, y::AtomIterate) =
  x.groups == y.groups || throw(ArgumentError("the starting point must have the workspace's groups."))
_workspace_partition(x::Tuple, y::Tuple) = foreach(_workspace_partition, x, y)

_workspace_noalias(x) = nothing
function _workspace_noalias(x::Tuple)
  for i in eachindex(x), j in eachindex(x)
    i < j && Base.mightalias(x[i], x[j]) &&
      throw(ArgumentError("workspace tuple blocks must have separate storage."))
  end
  nothing
end

_workspace_copyable(dest, src) = nothing
function _workspace_copyable(dest::Tuple, src::Tuple)
  for i in eachindex(dest), j in eachindex(src)
    i != j && Base.mightalias(dest[i], src[j]) &&
      throw(ArgumentError("a starting block must not alias a different workspace block."))
  end
  nothing
end

_workspace_reset!(buffers, method) = nothing
function _workspace_reset!(buffers::_ADMMBuffers, method)
  _workspace_zero!(buffers.u)
  buffers.ρ = method.ρ
  nothing
end
_workspace_zero!(x::AbstractArray) = fill!(x, zero(eltype(x)))
_workspace_zero!(x::Tuple) = foreach(_workspace_zero!, x)

function reinitialize_state!(state::ProximalGradientDescentState{T}, f, g,
                             method::ProximalGradientDescent) where {T}
  state.model === nothing || _image!(state.z_x, state.model, state.x)
  state.f_x = _value_and_gradient!(state.grad_f_x, f, state.x, state.model, state.z_x, state.dz)
  _check_start(state.f_x)
  state.g_x = g(state.x)
  state.f_x_previous = state.g_x_previous = T(NaN)
  state.L = one(T)
  state.max_residual = T(-Inf)
  state.backtrack_simple = true
  state.backtrack_steps = state.prox_calls = state.stable = 0
  state.f_calls = state.grad_calls = 1
  state.refitted = false
  state
end

function reinitialize_state!(state::AccProxGradDescentState{T}, f, g,
                             method::AccProxGradDescent) where {T}
  state.f_x = _value!(f, state.x, state.model, state.z_x)
  _check_start(state.f_x)
  state.g_x = g(state.x)
  _copyto!(state.x_previous, state.x)
  state.model === nothing || copyto!(state.z_previous, state.z_x)
  state.f_x_previous = state.g_x_previous = state.f_y = T(NaN)
  state.L = one(T)
  state.max_residual = T(-Inf)
  state.k = state.restarts = state.backtrack_steps = state.grad_calls = state.prox_calls = 0
  state.f_calls = 1
  state
end

function solve!(ws::SolverWorkspace{X, F, G, M}, g = ws.g) where {X, F, G, M<:_GradientSolver}
  g = _workspace_penalty(ws, g)
  g = _symmetric_penalty(g, ws.x)
  t0 = time()
  reinitialize_state!(ws.buffers.state, ws.f, g, ws.method)
  _solve_gradient!(ws.buffers.state, ws.f, g, ws.method, ws.options, ws.buffers.gap, t0)
end

function solve!(ws::SolverWorkspace{X, F, G, M}, g = ws.g;
                warm_start::Bool = false) where {X, F, G, M<:ADMMSolver}
  g = _workspace_penalty(ws, g)
  t0 = time()
  b = ws.buffers
  warm_start || _workspace_reset!(b, ws.method)
  _copyto!(b.xk, ws.x)
  result = _solve_admm!(ws.x, ws.f, g, ws.method, ws.options,
                        b.xk, b.u, b.previous, b.tmp, b.gap, t0, b.ρ)
  b.ρ = result.ρ
  result
end

function solve!(ws::SolverWorkspace{X, F, G, M}, g = ws.g) where {X, F, G, M<:CDSolver}
  supplied = _workspace_penalty(ws, g)
  b = ws.buffers
  xs, m, st = b.iterate, b.model, b.state
  g = _symmetric_penalty(supplied, xs)
  _check_iterate(g, xs)
  check_penalty(m, g)
  if xs !== ws.x
    fill!(xs, zero(eltype(xs)))
    for i in eachindex(ws.x)
      iszero(ws.x[i]) || (xs[i] = ws.x[i])
    end
  end
  initialize!(m, xs)
  st.candidates = nothing
  _cd!(xs, m, g, st, ws.method)
  _warn_not_converged(st, ws.method)
  xs === ws.x || _copy_dense!(ws.x, xs)
  CDResults(ws.x, loss_value(m, xs) + supplied(xs), st.passes, st.converged, st.maxchange, st.tolerance, 0, st.relgap)
end
