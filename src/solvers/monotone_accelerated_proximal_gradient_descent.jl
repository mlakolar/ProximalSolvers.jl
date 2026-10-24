# implements the accelerated proximal gradient method for nonconvex problems of
# Li and Lin (2015), Accelerated proximal gradient methods for nonconvex
# programming, Algorithm 2 with c_k = F(x_k), which makes it monotone: the
# extrapolated step is kept only if it decreases the objective enough, and
# otherwise the better of it and a plain proximal gradient step from x

"""
    MonotoneAccProxGradDescent(; β = 0.5, α = 0.9, δ = 1e-3)

The monotone accelerated proximal gradient method of Li and Lin (*Accelerated
proximal gradient methods for nonconvex programming*, NeurIPS 2015), for a
smooth `f` and a proximable `g` that may be nonconvex, such as `IndBallL0`,
`IndBallRank`, `NormL0`, `MCP` or `SCAD`. Each iteration takes a proximal
gradient step from the extrapolated point

    y = x + (t'/t) (z - x) + ((t' - 1)/t) (x - x'),

where `z` is the previous step from `y` and `x'` the previous iterate, and keeps
its result `z` if `F(z) ≤ F(x) - δ L ‖z - y‖²`, with `F = f + g` and `1/L` the
step size. Otherwise it also takes a plain proximal gradient step `v` from `x`
and keeps the better of `z` and `v`. So the objective never increases, and
every limit point of the iterates is a critical point of `F` for nonconvex `g`
as well, which `AccProxGradDescent` (restarted extrapolation) doesn't
guarantee; for convex problems it keeps the accelerated rate.

The step sizes come from backtracking as in [`AccProxGradDescent`](@ref):
`L` is multiplied by `α ∈ (0, 1]` before each iteration and divided by
`β ∈ (0, 1)` until `f(z) ≤ f(y) + ⟨∇f(y), z - y⟩ + L/2 ‖z - y‖²`. A point where
`f` is not finite, such as a matrix off the positive definite cone for
`LogDetLoss`, is never kept. Use with [`solve!`](@ref).
"""
struct MonotoneAccProxGradDescent{T<:AbstractFloat} <: ProximalSolver
  β::T          # factor by which the step size 1/L shrinks during backtracking
  α::T          # factor by which L shrinks before each iteration, so the step can grow
  δ::T          # sufficient decrease that keeps the extrapolated step
end

Base.summary(::MonotoneAccProxGradDescent) = "Monotone Accelerated Proximal Gradient Descent"

function MonotoneAccProxGradDescent(; β::Real = 0.5, α::Real = 0.9, δ::Real = 1e-3)
  0 < β < 1 || error("β must be in (0, 1).")
  0 < α <= 1 || error("α must be in (0, 1].")
  δ > 0 || error("δ must be positive.")
  MonotoneAccProxGradDescent(promote(float(β), float(α), float(δ))...)
end

# the iterates have the type of the starting point x0; the gradients are dense.
# After each iteration y and grad_f_y hold the point the kept step was taken
# from and the gradient there, for the stopping rules.
mutable struct MonotoneAccProxGradDescentState{T, X<:Union{AbstractArray{T}, _Blocks{T}}, G<:Union{AbstractArray{T}, _Blocks{T}}}
    x::X
    f_x::T
    g_x::T
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    y::X
    grad_f_y::G
    z::X              # the step from y
    f_z::T
    g_z::T
    v::X              # the step from x
    f_v::T
    g_v::T
    grad_f_x::G
    xhat::X
    deltaX::X
    L::T
    t::T
    t_previous::T
    maxResidual::T
    accelerated::Int  # iterations that kept the step from y
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
end

function initial_state(method::MonotoneAccProxGradDescent, options, f, g,
                       x0::Union{AbstractArray{T}, _Blocks{T}}) where T
    f_x = f(x0)
    _check_start(f_x)
    g_x = g(x0)
    MonotoneAccProxGradDescentState(
        x0, f_x, g_x,
        _copy(x0), T(NaN), T(NaN),        # x_previous = x0, so the first y is x0
        _similar(x0), _dense_similar(x0),
        _copy(x0), T(NaN), T(NaN),        # z = x0
        _similar(x0), T(NaN), T(NaN),
        _dense_similar(x0),
        _similar(x0), _similar(x0),
        one(T),                           # L
        one(T), zero(T),                  # t₁ = 1, t₀ = 0
        T(-Inf),                          # maxResidual
        0, 0, 1, 0, 0)
end

function update_state!(f, g, state::MonotoneAccProxGradDescentState{T}, method::MonotoneAccProxGradDescent) where T
    a = state.t_previous / state.t
    b = (state.t_previous - 1) / state.t
    state.L *= T(method.α)
    _extrapolate_point!(state.y, state.x, state.z, state.x_previous, a, b)
    _drop!(state.y)

    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    F_x = state.f_x + state.g_x

    state.f_z, state.g_z = _prox_grad_step!(state.z, state.grad_f_y, f, g, state.y, state, method)
    F_z = state.f_z + state.g_z
    if F_z <= F_x - T(method.δ) * state.L * _norm_diff(state.z, state.y, 2)^2
      _keep!(state, state.z, state.f_z, state.g_z)
      state.accelerated += 1
    else
      # a plain step from x, which decreases F when f is finite at x
      state.f_v, state.g_v = _prox_grad_step!(state.v, state.grad_f_x, f, g, state.x_previous, state, method)
      if F_z <= state.f_v + state.g_v
        _keep!(state, state.z, state.f_z, state.g_z)
      else
        _keep!(state, state.v, state.f_v, state.g_v)
        _copyto!(state.y, state.x_previous)
        _copyto!(state.grad_f_y, state.grad_f_x)
        # with y off the domain of f there was no step from y: extrapolate from
        # the new iterate alone next time
        isfinite(F_z) || _copyto!(state.z, state.x)
      end
    end

    state.t_previous = state.t
    state.t = (sqrt(4 * state.t^2 + 1) + 1) / 2
    _sub!(state.deltaX, state.x, state.x_previous)
    state
end

function _keep!(state::MonotoneAccProxGradDescentState, w, f_w, g_w)
    _copyto!(state.x, w)
    state.f_x = f_w
    state.g_x = g_w
end

# w = prox_{g/L}(u - ∇f(u)/L), increasing L until
# f(w) <= f(u) + <∇f(u), w - u> + L/2 ‖w - u‖²; returns f(w) and g(w), and
# Inf when f is not finite at u (no step exists from u)
function _prox_grad_step!(w, grad, f, g, u, state::MonotoneAccProxGradDescentState{T},
                          method::MonotoneAccProxGradDescent) where T
    f_u = value_and_gradient!(grad, f, u)
    state.f_calls += 1
    state.grad_calls += 1
    isfinite(f_u) || return T(Inf), T(Inf)
    while true
      _step!(state.xhat, u, grad, state.L)
      g_w = value_and_prox!(w, g, state.xhat, one(T) / state.L)
      _drop!(w)
      f_w = f(w)
      state.prox_calls += 1
      state.f_calls += 1

      _sub!(state.xhat, w, u)
      upper = f_u + _dot(grad, state.xhat) + state.L / 2 * _sumabs2(state.xhat)
      state.backtrack_steps += 1
      # slack guards against an endless loop from rounding error near the solution
      isfinite(f_w) && f_w <= upper + 10 * eps(T) * max(abs(f_u), one(T)) && return f_w, T(g_w)
      state.L /= method.β
    end
end
