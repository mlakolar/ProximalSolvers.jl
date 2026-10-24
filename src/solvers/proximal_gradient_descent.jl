

# implements the algorithm in section 4.2 of
# https://web.stanford.edu/~boyd/papers/pdf/prox_algs.pdf

"""
    ProximalGradientDescent(; ls = LineSearches.BackTracking(), normalized = false, debias = 0)

Proximal gradient descent (Parikh and Boyd, *Proximal Algorithms*, §4.2):
`x ← prox_{g/L}(x - ∇f(x) / L)`, with the step size `1/L` chosen by the
backtracking line search `ls` of TFOCS. Use with [`solve!`](@ref).

With a nonconvex `g`, such as `IndBallL0(s)` (iterative hard thresholding),
`IndBallRank`, `NormL0`, `MCP` or `SCAD`, the line search keeps the objective
decreasing, and every limit point of the iterates is a critical point. Two
options help iterative hard thresholding:
- `normalized = true` starts the backtracking of each iteration from the
  normalized step of Blumensath and Davies (*Normalized iterative hard
  thresholding: guaranteed stability and performance*, 2010), instead of from
  the previous step: the minimizer of `f` along the gradient restricted to the
  support of `x` (all of it when `x = 0`). It costs one evaluation of `f`, and
  is exact for a quadratic `f` (least squares, `KronQuadratic`).
  For a tuple, the unrestricted gradient is used only when every block is
  zero; otherwise each block uses its own current support.
- `debias = k > 0` refits `f` on the support of `x` once the support has not
  changed for `k` iterations, with [`refit!`](@ref), and keeps the refit if it
  lowers the objective, as MendelIHT does. It needs a loss that `refit!`
  supports and a vector, `SparseIterate` or `SymmetricSparseIterate` iterate.
"""
struct ProximalGradientDescent{L} <: ProximalSolver
  ls::L
  normalized::Bool
  debias::Int
end

Base.summary(::ProximalGradientDescent) = "Proximal Gradient Descent"

ProximalGradientDescent(ls) = ProximalGradientDescent(ls, false, 0)

function ProximalGradientDescent(; ls = LineSearches.BackTracking(), normalized::Bool = false, debias::Integer = 0)
  debias >= 0 || throw(ArgumentError("debias must be nonnegative, but it is $debias."))
  ProximalGradientDescent{typeof(ls)}(ls, normalized, Int(debias))
end

# the iterates have the type of the starting point x0, an array or a tuple of
# arrays; the gradients are dense. For a loss of a linear image, f(x) = F(Ax),
# the state keeps the image of x (see image_models.jl); otherwise model and the
# image are nothing
mutable struct ProximalGradientDescentState{T, X<:Union{AbstractArray{T}, _Blocks{T}}, G<:Union{AbstractArray{T}, _Blocks{T}}, M, Z}
    x::X
    f_x::T
    g_x::T
    grad_f_x::G
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    grad_f_x_previous::G
    xhat::X
    deltaX::X
    L::T
    maxResidual::T
    backtrack_simple::Bool  # line search uses function values, not gradients
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z            # A x
    dz::Z             # F' at A x
    stable::Int             # iterations with the same support, for debias
    refitted::Bool          # whether the current support was refitted
end


function initial_state(
          method::ProximalGradientDescent,
          options,
          f,
          g,
          x0::Union{AbstractArray{T}, _Blocks{T}}) where T

    grad_f_x = _dense_similar(x0)
    model = _image_model(f)
    z_x = model === nothing ? nothing : _image_buffer(model)
    dz = model === nothing ? nothing : similar(z_x)
    model === nothing || _image!(z_x, model, x0)
    f_x = _value_and_gradient!(grad_f_x, f, x0, model, z_x, dz)
    _check_start(f_x)
    g_x = g(x0)
    method.debias > 0 && _check_debias(f, x0)

    ProximalGradientDescentState(
                         x0,          # Maintain current state in state.x
                         f_x,         # Maintain current f(x) in state.f_x
                         g_x,         # Maintain current g(x) in state.g_x
                         grad_f_x,    # Maintain gradient of f at current x in state.grad_f_x
                         _similar(x0), # Maintain previous state in state.x_previous
                         T(NaN),      # Store previous f in state.f_x_previous
                         T(NaN),      # Store previous g in state.g_x_previous
                         _similar(grad_f_x), # Maintain previous gradient of f in state.grad_f_x_previous for convergence check
                         _similar(x0), # Temporary storage
                         _similar(x0), # Temporary storage for x1 - x0
                         one(T),      # L
                         T(-Inf),     # maxResidual
                         true,        # backtrack_simple
                         0,           # backtrack_steps
                         1,           # f_calls
                         1,           # grad_calls
                         0,           # prox_calls
                         model,
                         z_x,
                         dz,
                         0,           # stable
                         false        # refitted
                         )
end

function update_state!(
    f, g,
    state::ProximalGradientDescentState{T},
    method::ProximalGradientDescent
    ) where T

    # copy x --> x_previous
    _copy!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _copy!(state.grad_f_x_previous, state.grad_f_x)
    state.L *= method.ls.α
    method.normalized && _normalized_step!(f, state)

    # backtracking loop
    while true
      # find next point
      _step!(state.xhat, state.x_previous, state.grad_f_x_previous, state.L)
      state.g_x = value_and_prox!(state.x, g, state.xhat, one(T) / state.L)
      _drop!(state.x)
      state.f_x = _value!(f, state.x, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1

      # check if enough progress is done
      backtrack!(state, method.ls, f, g) && break
    end
    if has_updated_gradient( state, method.ls ) == false
        LineSearches.value_and_gradient_at_x!(state, f)
        state.f_calls += 1
        state.grad_calls += 1
    end
    method.debias > 0 && _debias!(f, g, state, method)
    state
end

# The normalized step of iterative hard thresholding: with d the gradient at x
# on the support of x (all of it when x = 0), the minimizer of f(x - μd) over μ
# is μ = ‖d‖² / ⟨d, ∇²f d⟩, and for a quadratic f the curvature is exact from
# f(x - τd) = f(x) - τ‖d‖² + τ² ⟨d, ∇²f d⟩ / 2. The backtracking then starts
# from L = 1/μ; it keeps L when the estimate is not positive and finite.
function _normalized_step!(f, state::ProximalGradientDescentState{T}) where T
    x, grad, w = state.x_previous, state.grad_f_x_previous, state.xhat
    whole = _allzero(x)
    τ = one(T) / state.L
    dd = _restricted_step!(w, x, grad, τ, whole)
    iszero(dd) && return state
    f_w = f(w)
    state.f_calls += 1
    curvature = 2 * (f_w - state.f_x_previous + τ * dd) / τ^2
    (isfinite(curvature) && curvature > 0) && (state.L = curvature / dd)
    state
end

function _check_debias(f, x0)
  x0 isa Union{AbstractVector, SparseIterate, SymmetricSparseIterate} ||
    throw(ArgumentError("debias needs a vector, SparseIterate or SymmetricSparseIterate iterate, not a $(typeof(x0))."))
  cdmodel(f, _refit_copy(x0))     # throws for a loss that refit! does not support
  nothing
end

_same_support(x, y) = all(i -> iszero(x[i]) == iszero(y[i]), eachindex(x, y))

_refit_copy(x::Union{SparseIterate, SymmetricSparseIterate}) = copy(x)
_refit_copy(x::AbstractVector) = SparseIterate(Vector(x))

# Once the support has been the same for `debias` iterations, refit f on it and
# keep the refit if it lowers f + g (the support, so an ℓ0 or rank constraint,
# is unchanged); a support is refitted once.
function _debias!(f, g, state::ProximalGradientDescentState{T}, method::ProximalGradientDescent) where T
    if _same_support(state.x, state.x_previous)
      state.stable += 1
    else
      state.stable, state.refitted = 0, false
    end
    (state.stable >= method.debias && !state.refitted) || return state
    state.refitted = true
    xs = refit!(_refit_copy(state.x), f)
    f_s, g_s = f(xs), g(xs)
    state.f_calls += 1
    f_s + g_s < state.f_x + state.g_x || return state
    copyto!(state.x, xs)
    _drop!(state.x)
    state.model === nothing || _image!(state.z_x, state.model, state.x)    # keep the image of x
    state.f_x = _value_and_gradient!(state.grad_f_x, f, state.x, state.model, state.z_x, state.dz)
    state.g_x = g_s
    state.f_calls += 1
    state.grad_calls += 1
    @. state.deltaX = state.x - state.x_previous
    state
end

# backtrack! evaluates ∇f at the trial point from its image, for a loss with a model
LineSearches.value_and_gradient_at_x!(state::ProximalGradientDescentState, f) =
  _value_and_gradient!(state.grad_f_x, f, state.x, state.model, state.z_x, state.dz)
