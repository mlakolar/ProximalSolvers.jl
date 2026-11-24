# The accelerated proximal gradient method of Parikh and Boyd, Proximal Algorithms,
# section 4.3, with adaptive restart on an objective increase (O'Donoghue and Candès,
# Adaptive restart for accelerated gradient schemes, 2015), for the dense
# least-squares lasso of the minimal core and, with the curvature factor ¼ in its line search, the raw logistic loss
# of IN-09 (APG-08).

"""
    AccProxGradDescent(; β = 0.5, α = 0.9, preconditioner = :none)

Accelerated proximal gradient descent for dense Float32/Float64 least squares
with `NormL1` or `ElasticNet` (each with optional weights), `NormLinf`, `NormL2` or
`GroupNormL2`. A dense matrix response with dense same-type coefficients uses
unweighted `NormL1` on its entries. A raw `LogisticLoss(y, X)` with `NormL1` on a
`Vector{Float64}` is also supported (see below). APG extrapolates
from previous accepted iterates, takes a backtracked proximal step, and restarts the step
without momentum when it used momentum and the objective increased. Pass [`ProximalOptions`](@ref) as the fifth
argument to [`solve!`](@ref); the result and stopping interface are shared with PGD.

```julia
using ProximalBase, ProximalSolvers
X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
beta = zeros(2)
result = solve!(beta, (1/3)*LeastSquaresLoss(y, X), NormL1(0.1),
                AccProxGradDescent())
```

`converged` reports the computed stopping criterion, not coefficient accuracy;
see [the stopping contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).

# Extended help

- `β=0.5`: factor shrinking the step after a rejected trial; `0 < β < 1`.
- `α=0.9`: factor reducing curvature before each iteration; `0 < α <= 1`.
  At `α=1` this adjustment does not grow the step.
- `preconditioner=:none`: only supported value; other choices are rejected.

Parameter bounds must also hold after conversion to the working type, and
additional dimension bounds apply. The extrapolation weight is `k/(k+3)`,
counting from the start or last restart; this is not the textbook FISTA recurrence.
A restart repeats the step without momentum. An error in backtracking restores
the last accepted coefficients and is rethrown.

For least squares, the supported penalties are `NormL1` and `ElasticNet`, each with optional weights
([IN-03](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-03)),
`NormLinf`, `NormL2` ([IN-11](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-11)) and a matching `GroupNormL2{T}` on dense coefficients.
Box constraints use `IndBox` or `IndBallLinf`. Euclidean-ball constraints use
`IndBallL2` with four coefficients and a radius of the same type. These
indicators require a feasible starting vector.
Use [`ProximalGradientDescent`](@ref), or [`CDSolver`](@ref) on a dense `Vector`,
for `IndNonnegative()` and unweighted `NormL1Nonneg`; APG does not support those constrained penalties.

Sparse logistic regression takes a raw `LogisticLoss(y, X)` (dense `Matrix{Float64}` design, binary
`Vector{Float64}` response, no observation weights or offset) with `NormL1`, with or without penalty weights, on a
`Vector{Float64}`; a zero penalty weight leaves an intercept column unpenalized. The loss, coefficient and penalty
rules are those of the gate of [`ProximalGradientDescent`](@ref), and the dimension limits above also apply. The factor
`1/4` of the logistic Hessian bound takes the place of the loss scale in the certified line-search test: a nonzero trial
from the extrapolated point can be accepted only if the image bound is certified, after the guards in APG-08. The test does not use the local curvature, so a step can be shorter than a test on
the loss value would allow. See
[the logistic input contract](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-09) and
[APG-08](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-08).

With default stopping, a proposed stop is checked at the accepted point and the
extra gradient is included in `grad_calls`. The iteration's reported
gradient-mapping residual is measured from the extrapolated point. With an
explicit `ScaledKKT` rule, the accepted-point fused evaluation counts in both
`f_calls` and `grad_calls`. See [STOP-22](@ref).

- [Extrapolation and restarts](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-01) and [dimension limits](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-02).
- [Certified local bound test and assumptions](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-06).
- [Shared stopping and exceptional exits](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/pg-stopping/#STOP-01).
"""
struct AccProxGradDescent{T<:AbstractFloat} <: ProximalSolver
  β::T          # factor by which the step size 1/L shrinks during backtracking
  α::T          # factor by which L shrinks before each iteration, so the step can grow
  # The only constructor, so every route into an AccProxGradDescent is validated.
  AccProxGradDescent(β::T, α::T) where {T<:AbstractFloat} = (_check_steps(β, α); new{T}(β, α))
end

_check_steps(β, α) = (0 < β < 1 || throw(ArgumentError("β must be in (0, 1)."));
                      0 < α <= 1 || throw(ArgumentError("α must be in (0, 1]."));
                      nothing)

Base.summary(::AccProxGradDescent) = "Accelerated Proximal Gradient Descent"

# checked as given and, by the inner constructor, after promotion
AccProxGradDescent(β::AbstractFloat, α::AbstractFloat) = (_check_steps(β, α); AccProxGradDescent(promote(β, α)...))

# preconditioner is accepted at its default only and not stored.
function AccProxGradDescent(; β::AbstractFloat = 0.5, α::AbstractFloat = 0.9, preconditioner::Symbol = :none)
  method = AccProxGradDescent(β, α)
  preconditioner === :none || throw(ArgumentError("preconditioning is deferred"))
  method
end

# Dense iterates and gradient with the LS image cache: z_x = A x (of the current
# trial point once a step starts), z_previous = A x_previous and z_y = A y.
mutable struct AccProxGradDescentState{T, X<:VecOrMat{T}, M, Z, C}
    x::X
    f_x::T
    g_x::T
    x_previous::X
    f_x_previous::T
    g_x_previous::T
    y::X
    grad_f_y::X
    xhat::X
    delta_x::X
    L::T
    max_residual::T
    λmax::T           # ‖∇f(0)‖ for the stationarity check: the ∞-norm for NormL1 (logistic loss, matrix response)
                      # and NormLinf, the largest group 2-norm for GroupNormL2, the 2-norm for NormL2 (_scale_norm);
                      # -1 until it is computed. The coordinatewise check (scales below) does not compute it, so it
                      # stays -1 in those solves.
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
    dz::Z             # observation derivative at the cached image z_y (z_y minus the response before the loss scale for
                      # least squares, σ(z_y) minus the response for a logistic loss), written by the value and gradient
                      # oracle when it runs (a logistic oracle is skipped for a nonfinite image); buffer of the fresh A d
    bound::_BoundConstants{T}  # constants of the bound test (dimensions, ‖A‖_F)
    rootα::_SE{T}     # √ of the loss scale as given (see _root_scale); ½ = √¼ for a logistic loss
    image_error_y::_SE{T}  # bound on the error of z_y as an image of y
    normx::_SE{T}     # ‖x‖ of the accepted iterate
    normx_previous::_SE{T}  # ‖x_previous‖
    fresh_only::Bool  # internal validation switch: decide every trial with the fresh A d
    fallbacks::Int    # trials decided with the fresh A d
    # Column data, filled at the first coordinatewise check (STOP-21).
    # Explicit policies without ScaledKKT leave this as nothing (STOP-22).
    scales::C
end

function initial_state(
          method::AccProxGradDescent,
          options,
          f,
          g,
          x0::VecOrMat{T},
          ::Val{allocate_scales} = Val(true)) where {T, allocate_scales}

    model = _image_model(f)
    z_x = _image_buffer(model)
    f_x = _value!(x0, f, model, z_x)
    _check_start(f_x)
    normx0 = _se_norm(T, x0)          # x0 is finite (checked before)
    normX = _frobenius_upper(T, model.X)
    rootα = _root_scale(T, model.α)
    AccProxGradDescentState(
                         x0,          # Maintain current state in state.x
                         f_x,
                         T(g(x0)),
                         _copy(x0),   # x_previous = x0, so the first step has no momentum
                         T(NaN),
                         T(NaN),
                         _similar(x0), # extrapolated point y
                         _dense_similar(x0), # gradient of f at y
                         _similar(x0), # Temporary storage
                         _similar(x0), # x - x_previous
                         _initial_curvature(T, rootα, normX), # L
                         T(-Inf),     # max_residual
                         -one(T),     # λmax, not yet computed
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
                         _bound_constants(T, model.X, normX, size(x0, 2)),
                         rootα,
                         _se_zero(T),
                         normx0,
                         normx0,
                         false,
                         0,
                         allocate_scales ? _coordinate_scales(model, g, x0) : nothing
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

# x = prox_{g/L}(y - ∇f(y)/L). Both exits require that the smooth value of the trial and the computed norms of x and of
# the rounded displacement x - y are finite. Then x == y entrywise is accepted, and a nonzero displacement is accepted when
# _bound_certified! certifies the image inequality √α ‖X (x - y)‖ ≤ (1 + 4eps) √L ‖x - y‖. Any other trial raises L through
# next_curvature, a finite increase or else an error. The gradient ∇f(y) comes from the cached image z_y, which can differ
# from the product X y, and the derivative buffer state.dz receives the observation derivative at z_y when the oracle runs.
# In exact arithmetic the image inequality is, for least squares, equivalent to
# f(x) ≤ f(y) + ⟨∇f(y), x - y⟩ + (1 + 4eps)² L/2 ‖x - y‖²; for a logistic loss (α = ¼) it implies that inequality (APG-08).
function _prox_grad_step!(f, g, state::AccProxGradDescentState{T}, β::T) where T
    f_y = _value_and_gradient!(state.grad_f_y, state.y, f, state.z_y, state.dz)
    state.f_calls += 1
    state.grad_calls += 1
    # An extrapolated y whose value or gradient overflows gives no step; f(x) = Inf
    # makes the caller restart from x_previous, or, without momentum, fail with rollback.
    if !(isfinite(f_y) && _allfinite(state.grad_f_y))
      state.f_x = T(Inf)
      return state
    end
    while true
      _step!(state.xhat, state.y, state.grad_f_y, state.L)
      v = convert(T, value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.g_x = _trial_penalty_value(g, v, state.x)
      state.f_x = _value!(state.x, f, state.model, state.z_x)
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

# β and α are used in the precision of the iterate.
function _check_method(m::AccProxGradDescent, ::Type{T}) where T
  β, α = T(m.β), T(m.α)
  0 < β < 1 && 0 < α <= 1 ||
    throw(ArgumentError("AccProxGradDescent needs 0 < β < 1 and 0 < α <= 1 after conversion to $T"))
  nothing
end

# Subtract the margins from the exact powers of two before comparing array lengths.
_bound_size_ok(::Type{T}, q, r, design) where T =
  max(q, r) < 1 / (4eps(T)) - 4 && design < 1 / (4eps(Float64)) - 3

function _check_bound_size(f, ::Type{T}) where T
  X = _image_model(f).X
  n, p = size(X)
  _bound_size_ok(T, n, p, length(X)) ||
    throw(ArgumentError("AccProxGradDescent needs max(n, p) + 4 < 1/(4 eps($T)) and n p + 3 < 1/(4 eps(Float64)) for its rounding-error bounds"))
  nothing
end

_check_bound_size(f, x::Vector{T}) where T = _check_bound_size(f, T)

function _check_bound_size(f, B::Matrix{T}) where T
  model = _image_model(f)
  _bound_size_ok(T, length(model.Y), length(B), length(model.X)) ||
    throw(ArgumentError("AccProxGradDescent needs max(nK, pK) + 4 < 1/(4 eps($T)) and n p + 3 < 1/(4 eps(Float64)) for its rounding-error bounds"))
  nothing
end

function _check_apg_problem(x, f, g, method::AccProxGradDescent)
  _check_gradient_problem(x, f, g, :gradient)
  _check_method(method, eltype(x))
  _check_bound_size(f, x)
end

extended_trace!(dt, state::AccProxGradDescentState) = dt["grad_f(y)"] = _copy(state.grad_f_y)

# The step is taken from y, so L (y - x) - ∇f(y) ∈ ∂g(x) and
# r = ∇f(x) - ∇f(y) - L (x - y) ∈ ∇f(x) + ∂g(x). The reported residual does not evaluate
# ∇f(x) (the stationarity check does, at each proposed stop, see _gradient_at_x!), but
# ‖r‖ ≤ (L + L_f) ‖x - y‖ when ∇f is L_f-Lipschitz, so L ‖x - y‖∞ is used instead.
g_residual(state::AccProxGradDescentState) = state.L * _norm_diff(state.x, state.y, Inf)

function gradient_converged!(state::AccProxGradDescentState, options::ProximalOptions)
  residual = g_residual(state)
  state.max_residual = max(state.max_residual, residual)
  # (xhat - x) / τ = L (y - x) - ∇f(y), with xhat = y - τ∇f(y)
  subgrad = _maxabs_stepdiff(state.L, state.y, state.x, state.grad_f_y)
  _gradient_test(state, options, residual, max(_norm_inf(state.grad_f_y), subgrad))
end

"""
    solve!(x, f, g, AccProxGradDescent(), options=ProximalOptions())
    solve!(x, f, g, AccProxGradDescent(); stopping=rule, limits=MaxIterations(n))

Minimize the same least-squares lasso, elastic net, `NormLinf` or `NormL2` problem as [`ProximalGradientDescent`](@ref) with
accelerated proximal gradient descent, overwriting dense `Vector{T}` coefficients
with `T = Float32` or `Float64`. A dense matrix response uses same-type dense
matrix coefficients and unweighted `NormL1` under
[IN-10](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-10).

Dense vector least squares supports explicit stopping conditions and an
independent iteration budget under [STOP-22](@ref).

# Extended help

For least squares, the options and their validation are those of
`ProximalGradientDescent` (see [`ProximalOptions`](@ref)), and the penalties are those listed for
[`AccProxGradDescent`](@ref); `IndNonnegative()` and unweighted `NormL1Nonneg` on dense vector coefficients are accepted by `ProximalGradientDescent` and
`CDSolver` only. The listed penalties, a weighted `ElasticNet` and a `GroupNormL2` included, apply to dense vector
coefficients with least squares, and the group stopping check is described under `ProximalGradientDescent`. In addition `β`
and `α` must satisfy their bounds after conversion to `T`, and the dimensions must satisfy `max(n, p) + 4 < 1/(4 eps(T))` and
`n p + 3 < 1/(4 eps(Float64))` (for Float32, `max(n, p) < 2,097,148`), which the
rounding-error bounds of the line search need for one response. For `K` response
columns, the first bound uses `max(nK, pK)`. See
[APG-07](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-07).

A raw `LogisticLoss(y, X)` with `NormL1` on a `Vector{Float64}` is solved for the summed logistic objective of
[IN-09](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/inputs/#IN-09), which gives the input rules and the
order of refusals shared with PGD. The factors `β` and `α` and the dimension limits for one response above also apply, and the
line search is that of
[APG-08](https://mlakolar.github.io/ProximalSolvers.jl/dev/contracts/apg/#APG-08).

Every refusal of an input, option or
method setting happens before `x` is modified. A step error
restores the last accepted `x` and rethrows, without a transaction guarantee for
internal counters. The result shares `x`.
"""
function solve!(x, f, g, method::AccProxGradDescent,
                options::ProximalOptions = ProximalOptions(); stopping=nothing, limits=nothing, kwargs...)
  _check_keywords(kwargs)
  if stopping !== nothing || limits !== nothing
    return _solve_gradient_policy!(x, f, g, method, options, stopping, limits)
  end
  _check_apg_problem(x, f, g, method)
  t0 = time()
  g_work = _working_gradient_penalty(g, eltype(x))
  state = initial_state(method, options, f, g_work, x)
  _solve_gradient!(state, f, g_work, method, options, t0)
end
