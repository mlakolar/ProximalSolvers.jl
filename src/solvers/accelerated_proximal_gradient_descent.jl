# The accelerated proximal gradient method of Parikh and Boyd, Proximal Algorithms,
# section 4.3, with adaptive restart on an objective increase (O'Donoghue and Candès,
# Adaptive restart for accelerated gradient schemes, 2015), for the dense
# least-squares lasso of the minimal core.

"""
    AccProxGradDescent(; β = 0.5, α = 0.9, preconditioner = :none)

Accelerated proximal gradient descent (APG) for least-squares lasso with a dense
`Vector{Float32}` or `Vector{Float64}` coefficient iterate (Parikh and Boyd,
*Proximal Algorithms*, §4.3). Iteration `k` (counted from the start or the last
restart) extrapolates `y = x + k/(k+3) (x - x')` from the last two accepted
iterates and takes a proximal gradient step from `y`: a gradient step for the
least-squares loss followed by soft thresholding. It is a FISTA-family method; its
momentum sequence `k/(k+3)` is not the textbook FISTA recurrence.

The step size `1/L` is found by backtracking on the least-squares bound
`f(x) ≤ f(y) + ⟨∇f(y), x - y⟩ + L/2 ‖x - y‖²`, which holds exactly when
`√α_f ‖X(x - y)‖ ≤ √L ‖x - y‖`. A trial is accepted only when that inequality, with
a relative slack of `4eps` on `√L`, is certified by conservative rounding-error
bounds (assuming IEEE arithmetic with gradual underflow): first from the difference
of cached products, and when that is inconclusive from a freshly computed `X(x - y)`;
a trial that is still inconclusive is rejected.
See [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).
A trial with `x == y` entrywise is accepted when its value is finite. A rejected trial sets
`L ← L/β`, `β ∈ (0, 1)`. Before each iteration `L ← α L`, `α ∈ (0, 1]`, so that the
step can grow again where the curvature is smaller; `α = 1` keeps `L` from
decreasing.

When an extrapolated step would increase the computed objective, the momentum is
restarted: the step is repeated from `y = x'` and `k` returns to zero, so the next
iteration extrapolates with `1/4`. An accepted step that used momentum therefore
never increases the computed objective. A step without momentum (the first
iteration, and a step repeated after a restart) can increase it through rounding of
the step and of the objective; as for [`ProximalGradientDescent`](@ref), that
stops the solve unless `allow_f_increases = true` in [`ProximalOptions`](@ref).

Backtracking raises an error when the next curvature estimate `L/β` is not a finite
increase of `L`; `solve!` then restores the last accepted iterate and rethrows. A
`β` close to one makes each rejected trial raise `L` only slightly. `preconditioner = :diagonal` is deferred and
rejected. Pass `ProximalOptions(...)` as the fifth argument to [`solve!`](@ref).
`converged = true` means that one of the stopping rules was satisfied; it is not an
optimality certificate. The gradient-mapping residual of the result,
`L ‖x - y‖∞`, is measured from the extrapolated point `y`, not from `x`; check KKT
conditions independently before reporting numerical results.
See the [solver guide](https://mlakolar.github.io/ProximalSolvers.jl/dev/choosing-solver/)
and [numerical behavior](https://mlakolar.github.io/ProximalSolvers.jl/dev/numerics/).
"""
struct AccProxGradDescent{T<:AbstractFloat, P} <: ProximalSolver
  β::T          # factor by which the step size 1/L shrinks during backtracking
  α::T          # factor by which L shrinks before each iteration, so the step can grow
  preconditioner::P
end

Base.summary(::AccProxGradDescent) = "Accelerated Proximal Gradient Descent"

AccProxGradDescent(β::AbstractFloat, α::AbstractFloat) = AccProxGradDescent(; β, α)

function AccProxGradDescent(; β::AbstractFloat = 0.5, α::AbstractFloat = 0.9, preconditioner::Symbol = :none)
  0 < β < 1 || throw(ArgumentError("β must be in (0, 1)."))
  0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]."))
  preconditioner === :none || throw(ArgumentError("preconditioning is deferred"))
  AccProxGradDescent(promote(β, α)..., nothing)
end

# Dense iterates and gradient with the LS image cache: z_x = A x (of the current
# trial point once a step starts), z_previous = A x_previous and z_y = A y.
mutable struct AccProxGradDescentState{T, X<:Vector{T}, M, Z}
    x::X
    f_x::T
    g_x::T
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    y::X
    f_y::T
    grad_f_y::X
    xhat::X
    delta_x::X
    L::T
    max_residual::T
    k::Int            # iterations since the start or the last restart
    restarts::Int
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    model::M
    z_x::Z
    z_previous::Z
    z_y::Z
    dz::Z             # residual A y - response (before the loss scale); buffer of the fresh A d
    bound::_BoundConstants{T}  # constants of the bound test (dimensions, ‖A‖_F)
    rootα::_SE{T}     # √ of the loss scale as given (see _root_scale)
    image_error_y::_SE{T}  # bound on the error of z_y as an image of y
    normx::_SE{T}     # ‖x‖ of the accepted iterate
    normx_previous::_SE{T}  # ‖x_previous‖
    fresh_only::Bool  # internal validation switch: decide every trial with the fresh A d
    fallbacks::Int    # trials decided with the fresh A d
end

function initial_state(
          method::AccProxGradDescent,
          options,
          f,
          g,
          x0::Vector{T}) where T

    model = _image_model(f)
    z_x = _image_buffer(model)
    f_x = _value!(f, x0, model, z_x)
    _check_start(f_x)
    normx0 = _se_norm(T, x0)          # x0 is finite (checked before)
    AccProxGradDescentState(
                         x0,          # Maintain current state in state.x
                         f_x,
                         T(g(x0)),
                         _copy(x0),   # x_previous = x0, so the first step has no momentum
                         T(NaN),
                         T(NaN),
                         _similar(x0), # extrapolated point y
                         T(NaN),      # f(y)
                         _dense_similar(x0), # gradient of f at y
                         _similar(x0), # Temporary storage
                         _similar(x0), # x - x_previous
                         one(T),      # L
                         T(-Inf),     # max_residual
                         0,           # k
                         0,           # restarts
                         0,           # backtrack_steps
                         1,           # f_calls
                         0,           # grad_calls
                         0,           # prox_calls
                         model,
                         z_x,
                         copy(z_x),   # A x_previous
                         similar(z_x), # A y
                         similar(z_x), # residual at A y
                         _bound_constants(T, model.X),
                         _root_scale(T, model.α),
                         _se_zero(T),
                         normx0,
                         normx0,
                         false,
                         0
                         )
end

function update_state!(
    f, g,
    state::AccProxGradDescentState{T},
    method::AccProxGradDescent
    ) where T

    ω = T(state.k / (state.k + 3))
    state.L *= T(method.α)
    # norms of the accepted x (x_a) and of the one before it (x_b), kept from the trials
    # that accepted them, for the error bound of the extrapolated image
    normxa, normxb = state.normx, state.normx_previous
    state.normx_previous = normxa
    state.image_error_y = _image_error_bound(state.bound, normxa, normxb, ω > 0)
    # y and its image are formed before x_previous is overwritten; they change no
    # caller-visible array, so x_previous holds the last accepted iterate whenever a
    # trial below can throw (the engine restores x from it).
    _extrapolate_point!(state.y, state.x, state.x_previous, ω)
    # A y as the same combination of A x and A x_previous, without a product
    zx, zp = state.z_x, state.z_previous
    @. state.z_y = zx + ω * (zx - zp)

    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    # A x_previous = A x; the old buffer of A x_previous receives the trial images
    state.z_previous, state.z_x = state.z_x, state.z_previous

    while true
      _prox_grad_step!(f, g, state, T(method.β))
      # The restart sets ω = 0, so it happens at most once per iteration. An exact
      # proximal step from y = x_previous that satisfies the certified bound (with its
      # 4eps slack) does not increase the exact objective; rounding of the computed step
      # and objective can raise the computed value, and the engine's increase test sees
      # that.
      if ω > 0 && state.f_x + state.g_x > state.f_x_previous + state.g_x_previous
        ω = zero(T)
        state.k = 0
        state.restarts += 1
        _copyto!(state.y, state.x_previous)
        copyto!(state.z_y, state.z_previous)
        state.image_error_y = _image_error_bound(state.bound, normxa, normxb, false)
      else
        break
      end
    end

    state.k += 1
    _sub!(state.delta_x, state.x, state.x_previous)
    state
end

# x = prox_{g/L}(y - ∇f(y)/L), increasing L until _bound_certified! certifies
# f(x) ≤ f(y) + ⟨∇f(y), x - y⟩ + L/2 ‖x - y‖² (with legacy's slack 8eps on L), or until
# x == y entrywise.
function _prox_grad_step!(f, g, state::AccProxGradDescentState{T}, β::T) where T
    state.f_y = _value_and_gradient!(state.grad_f_y, f, state.y, state.model, state.z_y, state.dz)
    state.f_calls += 1
    state.grad_calls += 1
    # An extrapolated y whose value or gradient overflows gives no step; f(x) = Inf
    # makes the caller restart from x_previous, or, without momentum, fail with rollback.
    if !(isfinite(state.f_y) && _allfinite(state.grad_f_y))
      state.f_x = T(Inf)
      return state
    end
    while true
      _step!(state.xhat, state.y, state.grad_f_y, state.L)
      state.g_x = convert(T, value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(f, state.x, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1

      _sub!(state.xhat, state.x, state.y)
      state.backtrack_steps += 1
      if isfinite(state.f_x)
        sd, sx = _sumsq2(state.xhat, state.x)
        normx = _se_norm_onepass(T, sx, state.x)
        D = _se_norm_onepass(T, sd, state.xhat)
        if normx !== nothing && D !== nothing
          if iszero(D.s)
            # x == y entrywise: there is no step to test. The step is accepted, as PGD
            # accepts a zero step; this is a stopping policy, not a claim that a larger L
            # would also return y.
            state.normx = normx
            break
          end
          ok, fresh = _bound_certified!(state.dz, state.model, state.z_y, state.z_x, state.xhat,
                                        D, state.L, state.image_error_y, normx, state.rootα,
                                        state.bound, state.fresh_only)
          state.fallbacks += fresh
          if ok
            state.normx = normx
            break
          end
        end
      end
      # A trial that is not certified, including one with a nonfinite value or norm,
      # raises L; next_curvature raises once L/β is not a finite increase, so a curvature
      # beyond floatmax(T) ends in that error and the engine's rollback.
      state.L = LineSearches.next_curvature(state.L, β)
    end
    state
end

function _check_method(m::AccProxGradDescent)
  m.preconditioner === nothing || throw(ArgumentError("preconditioning is deferred"))
  0 < m.β < 1 && 0 < m.α <= 1 ||
    throw(ArgumentError("AccProxGradDescent needs 0 < β < 1 and 0 < α <= 1"))
  nothing
end

# β and α are used in the precision of the iterate.
function _check_method(m::AccProxGradDescent, ::Type{T}) where T
  β, α = T(m.β), T(m.α)
  0 < β < 1 && 0 < α <= 1 ||
    throw(ArgumentError("AccProxGradDescent needs 0 < β < 1 and 0 < α <= 1 after conversion to $T"))
  nothing
end

# The error bounds of the bound test need k u < 1/8 for k = max(n, p) + 4 in T, and for
# k = n p + 3 in Float64, where ‖X‖_F is accumulated.
function _check_bound_size(f, ::Type{T}) where T
  n, p = size(_image_model(f).X)
  (max(n, p) + 4) * _unit(T) < 1 / 8 && (n * p + 3) * _unit(Float64) < 1 / 8 ||
    throw(ArgumentError("AccProxGradDescent needs max(n, p) + 4 < 1/(4 eps($T)) and n p + 3 < 1/(4 eps(Float64)) for its rounding-error bounds"))
  nothing
end

extended_trace!(dt, state::AccProxGradDescentState) = dt["grad_f(y)"] = _copy(state.grad_f_y)

# The step is taken from y, so L (y - x) - ∇f(y) ∈ ∂g(x) and
# r = ∇f(x) - ∇f(y) - L (x - y) ∈ ∇f(x) + ∂g(x). ∇f(x) is not evaluated, but
# ‖r‖ ≤ (L + L_f) ‖x - y‖ when ∇f is L_f-Lipschitz, so L ‖x - y‖∞ is used instead.
g_residual(state::AccProxGradDescentState) = state.L * _maxabs_diff(state.x, state.y)

function gradient_converged!(state::AccProxGradDescentState, options::ProximalOptions)
  residual = g_residual(state)
  state.max_residual = max(state.max_residual, residual)
  # (xhat - x) / τ = L (y - x) - ∇f(y), with xhat = y - τ∇f(y)
  subgrad = _maxabs_stepdiff(state.L, state.y, state.x, state.grad_f_y)
  normalizer = max(_norm_inf(state.grad_f_y), subgrad) + options.gradtol
  n_residual = residual / normalizer
  residual / (state.max_residual + options.gradtol) < options.gradtol || n_residual < options.gradtol
end

_state_norm(s::AccProxGradDescentState, x) = _norm(x)
_state_normdiff(s::AccProxGradDescentState) = _norm_diff(s.x, s.x_previous, 2.)

"""
    solve!(x, f, g, AccProxGradDescent(), options=ProximalOptions())

Minimize the same least-squares lasso as [`ProximalGradientDescent`](@ref) with
accelerated proximal gradient descent, overwriting `x`, a dense `Vector{T}` with
`T = Float32` or `Float64`. The inputs, the options and their validation are those
of `ProximalGradientDescent`; in addition `β` and `α` must satisfy their bounds after
conversion to `T`, and the dimensions must satisfy `max(n, p) + 4 < 1/(4 eps(T))` and
`n p + 3 < 1/(4 eps(Float64))` (for Float32, `max(n, p) < 2,097,148`), which the
rounding-error bounds of the line search need. Every refusal of an input, option or
method setting happens before `x` is modified. A step error
restores the last accepted `x` and rethrows, without a transaction guarantee for
internal counters. The result shares `x`.
"""
function solve!(x, f, g, method::AccProxGradDescent,
                options::ProximalOptions = ProximalOptions(); kwargs...)
  _check_keywords(kwargs)
  _check_method(method)
  _check_options(options)
  _check_problem(x, f, g)
  _check_method(method, eltype(x))
  _check_bound_size(f, eltype(x))
  t0 = time()
  state = initial_state(method, options, f, g, x)
  _solve_gradient!(state, f, g, method, options, t0)
end
