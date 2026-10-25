

# implements the accelerated proximal gradient method in section 4.3 of
# https://web.stanford.edu/~boyd/papers/pdf/prox_algs.pdf
#
# The momentum is restarted whenever the objective increases
# (O'Donoghue and Candès, 2015, Adaptive restart for accelerated gradient schemes),
# so the objective is nonincreasing across iterations.

"""
    AccProxGradDescent(; β = 0.5, α = 0.9)

Accelerated proximal gradient descent (Parikh and Boyd, *Proximal Algorithms*,
§4.3). Each iteration extrapolates `y = x + k/(k+3) (x - x')` and takes a
proximal gradient step from `y`; the step size `1/L` is found by
backtracking, shrinking it by the factor `β ∈ (0, 1)`. Before each iteration
`L` is multiplied by `α ∈ (0, 1]`, so that the step grows again where the
curvature is smaller, as in TFOCS; `α = 1` keeps `L` from decreasing. On the
lasso of the benchmark, `α = 0.9` takes 1.2 to 6.5 times less time than
`α = 1`.

Backtracking raises an error if roundoff prevents a representable step from
satisfying the descent bound, or the next curvature estimate is not finite.

The momentum restarts whenever the objective would increase (O'Donoghue and
Candès, *Adaptive restart for accelerated gradient schemes*, 2015), so the
objective is nonincreasing. Use with [`solve!`](@ref).
"""
struct AccProxGradDescent{T<:AbstractFloat} <: ProximalSolver
  β::T          # factor by which the step size 1/L shrinks during backtracking
  α::T          # factor by which L shrinks before each iteration, so the step can grow
end

Base.summary(::AccProxGradDescent) = "Accelerated Proximal Gradient Descent"

function AccProxGradDescent(; β::AbstractFloat = 0.5, α::AbstractFloat = 0.9)
  0 < β < 1 || error("β must be in (0, 1).")
  0 < α <= 1 || error("α must be in (0, 1].")
  AccProxGradDescent(promote(β, α)...)
end

# the iterates have the type of the starting point x0, an array or a tuple of
# arrays; the gradient is dense. For a loss of a linear image, f(x) = F(Ax), the
# state keeps the images of x, x_previous and y (see image_models.jl); otherwise
# model and the images are nothing
mutable struct AccProxGradDescentState{T, X<:Union{AbstractArray{T}, _Blocks{T}}, G<:Union{AbstractArray{T}, _Blocks{T}}, M, Z}
    x::X
    f_x::T
    g_x::T
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    y::X
    f_y::T
    grad_f_y::G
    xhat::X
    delta_x::X
    L::T
    max_residual::T
    k::Int            # iterations since the last restart
    restarts::Int
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z            # A x
    z_previous::Z     # A x_previous
    z_y::Z            # A y
    dz::Z             # F' at A y
end


function initial_state(
          method::AccProxGradDescent,
          options,
          f,
          g,
          x0::Union{AbstractArray{T}, _Blocks{T}}) where T

    model = _image_model(f)
    z_x = model === nothing ? nothing : _image_buffer(model)
    f_x = _value!(f, x0, model, z_x)
    _check_start(f_x)
    AccProxGradDescentState(
                         x0,          # Maintain current state in state.x
                         f_x,
                         g(x0),
                         _copy(x0),   # x_previous = x0, so the first step has no momentum
                         T(NaN),
                         T(NaN),
                         _similar(x0), # extrapolated point y
                         T(NaN),      # f(y)
                         _dense_similar(x0), # gradient of f at y
                         _similar(x0), # Temporary storage
                         _similar(x0), # Temporary storage for x1 - x0
                         one(T),      # L
                         T(-Inf),     # max_residual
                         0,
                         0,
                         0,           # backtrack_steps
                         1,           # f_calls
                         0,           # grad_calls
                         0,           # prox_calls
                         model,
                         z_x,
                         z_x === nothing ? nothing : copy(z_x),     # A x_previous
                         z_x === nothing ? nothing : similar(z_x),  # A y
                         z_x === nothing ? nothing : similar(z_x)   # F' at A y
                         )
end

function update_state!(
    f, g,
    state::AccProxGradDescentState{T},
    method::AccProxGradDescent
    ) where T

    ω = T(state.k / (state.k + 3))
    state.L *= T(method.α)
    _extrapolate_point!(state.y, state.x, state.x_previous, ω)
    _drop!(state.y)
    _extrapolate_image!(state, state.model, ω)

    # copy x --> x_previous
    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _shift_image!(state, state.model)

    while true
      _prox_grad_step!(f, g, state, method)

      # a step from y = x_previous cannot increase the objective,
      # so this restarts at most once; an extrapolated y off the domain of f
      # restarts too, through f(x) = Inf
      if ω > 0 && state.f_x + state.g_x > state.f_x_previous + state.g_x_previous
        ω = zero(T)
        state.k = 0
        state.restarts += 1
        _copyto!(state.y, state.x_previous)
        _restart_image!(state, state.model)
      else
        break
      end
    end

    state.k += 1
    _sub!(state.delta_x, state.x, state.x_previous)
    state
end

# x = prox_{g/L}(y - ∇f(y)/L), increasing L until
# f(x) <= f(y) + <∇f(y), x - y> + L/2 ‖x - y‖²
function _prox_grad_step!(f, g, state::AccProxGradDescentState{T}, method::AccProxGradDescent) where T
    state.f_y = _value_and_gradient!(state.grad_f_y, f, state.y, state.model, state.z_y, state.dz)
    state.f_calls += 1
    state.grad_calls += 1
    # off the domain of f, as a y off the positive definite cone for LogDetLoss,
    # the gradient is NaN and no step from y exists
    if !isfinite(state.f_y)
      state.f_x = T(Inf)
      return state
    end
    while true
      _step!(state.xhat, state.y, state.grad_f_y, state.L)
      state.g_x = value_and_prox!(state.x, g, state.xhat, one(T) / state.L)
      _drop!(state.x)
      state.f_x = _value!(f, state.x, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1

      _sub!(state.xhat, state.x, state.y)
      stepnorm2 = _sumabs2(state.xhat)
      upper = state.f_y + _dot(state.grad_f_y, state.xhat) + state.L / 2 * stepnorm2
      state.backtrack_steps += 1
      # slack guards against an endless loop from rounding error near the solution
      state.f_x <= upper + 10 * eps(T) * max(abs(state.f_y), one(T)) && break
      # A rounded zero step cannot repair an inconsistent image/value bound by
      # increasing L. In particular, do not let L overflow and turn Inf*0 into
      # NaN, after which the backtracking comparison would fail forever.
      isfinite(upper) && !iszero(stepnorm2) ||
        error("APG line search failed: no representable step satisfies the descent bound")
      next_L = state.L / method.β
      isfinite(next_L) && next_L > state.L ||
        error("APG line search failed: the curvature estimate cannot increase finitely")
      state.L = next_L
    end
    state
end

# the images under the linear map of f, for a loss with a model: A y as the same
# combination of A x and A x_previous as y (no product); after x_previous = x,
# A x_previous = A x, and the buffer of A x is free for the next trial point;
# after a restart from y = x_previous, A y = A x_previous
_extrapolate_image!(state, ::Nothing, ω) = state
function _extrapolate_image!(state, m, ω)
  zx, zp = state.z_x, state.z_previous
  @. state.z_y = zx + ω * (zx - zp)
  state
end

_shift_image!(state, ::Nothing) = state
function _shift_image!(state, m)
  state.z_previous, state.z_x = state.z_x, state.z_previous
  state
end

_restart_image!(state, ::Nothing) = state
_restart_image!(state, m) = (copyto!(state.z_y, state.z_previous); state)
