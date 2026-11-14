# Disposable in-process prototypes for #296 (method overrides; one variant per process).
# VARIANT is a "+"-separated list of components:
#   F   scale-relative gradtol/ftol tests (no absolute floors)
#   S   the exact-stall rule for every ftol (an unchanged iterate is never x/g convergence)
#   G   x and f tests count only after the line search has rejected a trial in this solve
#   R   gradient test counts only when L·eps(T)·‖x‖∞ < its normalizer (resolution guard)
#   I1  initial L = α‖X g0‖²/‖g0‖² (Rayleigh quotient along the first gradient), g0 = ∇f(x0)
#   I2  initial L = min(1, I1)
#   V   a proposed stop counts only when the minimal-norm KKT residual of x, from ∇f(x) and λ,
#       is < gradtol·max(λ, ‖∇f(x)‖∞, max_residual)  (APG forms ∇f(x) from its cached A x)
const PSm = ProximalSolvers
const VARIANT = Set(split(get(ENV, "VARIANT", "base"), '+'))
has(c) = c in VARIANT
const RESOLVED = IdDict{Any, Bool}()

@eval PSm begin

  function f_residual(f_x, f_x_previous, f_tol)
    if Main.has("F")
      iszero(f_tol) || return abs(f_x - f_x_previous) / abs(f_x)
    else
      iszero(f_tol) || return abs(f_x-f_x_previous)/(abs(f_x)+f_tol)
    end
    change = Float64(abs(f_x-f_x_previous))
    iszero(change) ? 0.0 : change / abs(Float64(f_x))
  end

  function convergence_assessment(state::Union{ProximalGradientDescentState, AccProxGradDescentState}, f, g, options::ProximalOptions)
    x_converged, f_converged, grad_converged, f_increased = false, false, false, false
    norm_x = _state_norm(state, state.x)
    norm_dx = _state_norm(state, state.delta_x)
    stall_rule = Main.has("S") || iszero(options.ftol)
    stalled = stall_rule && iszero(norm_dx) && _unchanged(state.x, state.x_previous)
    resolved = !Main.has("G") || get(Main.RESOLVED, state, false)
    if resolved && !stalled && norm_dx < options.xtol * max(norm_x, 1.)
      x_converged = true
    end
    fval = state.f_x + state.g_x
    fval_prev = state.f_x_previous + state.g_x_previous
    if resolved && !iszero(options.ftol) &&
          (f_residual(fval, fval_prev, options.ftol) < options.ftol ||
           abs(fval - fval_prev) < eps(abs(fval)+abs(fval_prev)))
      f_converged = true
    end
    fval > fval_prev && (f_increased = true)
    grad_converged = gradient_converged!(state, options) && !stalled
    if Main.has("V") && (x_converged || f_converged || grad_converged)
      ok = _stationary(state, g, options)
      x_converged &= ok; f_converged &= ok; grad_converged &= ok
    end
    converged = x_converged || f_converged || grad_converged
    return x_converged, f_converged, grad_converged, converged, f_increased
  end

  _xgrad(state::ProximalGradientDescentState) = state.grad_f_x
  function _xgrad(state::AccProxGradDescentState)
    m = state.model
    d = state.z_x .- m.Y
    G = transpose(m.X) * d
    G .*= m.α
    G
  end
  function _stationary(state, g, options)
    gr = _xgrad(state); x = state.x; λ = g.λ0
    kkt = zero(λ); gn = zero(λ)
    @inbounds for i in eachindex(x)
      gi = gr[i]
      kkt = max(kkt, iszero(x[i]) ? max(abs(gi) - λ, zero(λ)) : abs(gi + λ * sign(x[i])))
      gn = max(gn, abs(gi))
    end
    if Main.has("W")      # S = max(λ, λmax), λmax = ‖∇f(0)‖∞ = α‖Xᵀy‖∞ (start-independent)
      m = state.model
      S = max(λ, convert(typeof(λ), m.α * maximum(abs, transpose(m.X) * m.Y)))
    else
      S = max(λ, gn, state.max_residual)
    end
    τ = Main.has("Q") ? sqrt(options.gradtol) :
        Main.has("E") ? max(options.gradtol, 64 * eps(typeof(λ))) : options.gradtol
    kkt < τ * S
  end

  function _gtest(state, residual, normalizer, options, ::Type{T}) where T
    if Main.has("R")
      floor = state.L * eps(T) * _norm_inf(state.x)
      ok = (residual < options.gradtol * state.max_residual && floor < state.max_residual) ||
           (residual < options.gradtol * normalizer && floor < normalizer)
      return ok
    end
    if Main.has("F")
      return residual < options.gradtol * state.max_residual || residual < options.gradtol * normalizer
    end
    residual / (state.max_residual + options.gradtol) < options.gradtol ||
      residual / (normalizer + options.gradtol) < options.gradtol
  end

  function gradient_converged!(state::ProximalGradientDescentState{T}, options::ProximalOptions) where T
    residual = g_residual(state)
    state.max_residual = max(state.max_residual, residual)
    subgrad = _maxabs_axpy(state.L, state.delta_x, state.grad_f_x_previous)
    normalizer = max(_norm_inf(state.grad_f_x), subgrad)
    _gtest(state, residual, normalizer, options, T)
  end

  function gradient_converged!(state::AccProxGradDescentState{T}, options::ProximalOptions) where T
    residual = g_residual(state)
    state.max_residual = max(state.max_residual, residual)
    subgrad = _maxabs_stepdiff(state.L, state.y, state.x, state.grad_f_y)
    normalizer = max(_norm_inf(state.grad_f_y), subgrad)
    _gtest(state, residual, normalizer, options, T)
  end

  # PGD update with rejection tracking (body as at the base)
  function update_state!(f, g, state::ProximalGradientDescentState{T}, method::ProximalGradientDescent) where T
    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _copyto!(state.grad_f_x_previous, state.grad_f_x)
    state.L *= method.ls.α
    state.verified_rejection = false
    while true
      _step!(state.xhat, state.x_previous, state.grad_f_x_previous, state.L)
      state.g_x = convert(_eltype(state.x), value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(state.x, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1
      backtrack!(state, method.ls, f, g) && break
      Main.has("G") && (Main.RESOLVED[state] = true)
    end
    if has_updated_gradient(state, method.ls) == false
      LineSearches.value_and_gradient_at_x!(state, f)
      state.f_calls += 1
      state.grad_calls += 1
    end
    state
  end

  # APG trial loop with rejection tracking (body as at the base)
  function _prox_grad_step!(f, g, state::AccProxGradDescentState{T}, β::T) where T
    f_y = _value_and_gradient!(state.grad_f_y, state.y, state.model, state.z_y, state.dz)
    state.f_calls += 1
    state.grad_calls += 1
    if !(isfinite(f_y) && _allfinite(state.grad_f_y))
      state.f_x = T(Inf)
      return state
    end
    while true
      _step!(state.xhat, state.y, state.grad_f_y, state.L)
      state.g_x = convert(T, value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(state.x, state.model, state.z_x)
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
      Main.has("G") && (Main.RESOLVED[state] = true)
      state.L = LineSearches.next_curvature(state.L, β)
    end
    state
  end
end

# initial curvature (I1/I2): Rayleigh quotient of the loss Hessian along g0 = ∇f(x0), in Float64
function _rayleigh_L0(f, x0::Vector{T}) where T
  m = PSm._image_model(f)
  X, y, α = m.X, m.Y, Float64(m.α)
  g0 = α .* (Float64.(X)' * (Float64.(X) * Float64.(x0) .- Float64.(y)))
  n0 = sum(abs2, g0)
  (iszero(n0) || !isfinite(n0)) && return one(T)
  c = α * sum(abs2, Float64.(X) * g0) / n0
  (isfinite(c) && c > 0) || return one(T)
  L = T(c)
  (isfinite(L) && L > 0) || return one(T)
  has("I2") ? min(one(T), L) : L
end

if has("I1") || has("I2")
  @eval PSm begin
    function solve!(x, f, g, method::ProximalGradientDescent, options::ProximalOptions = ProximalOptions(); kwargs...)
      _check_keywords(kwargs); _check_problem(x, f, g); t0 = time()
      L0 = Main._rayleigh_L0(f, x)
      state = initial_state(method, options, f, g, x)
      state.L = L0
      _solve_gradient!(state, f, g, method, options, t0)
    end
    function solve!(x, f, g, method::AccProxGradDescent, options::ProximalOptions = ProximalOptions(); kwargs...)
      _check_keywords(kwargs); _check_problem(x, f, g)
      _check_method(method, eltype(x)); _check_bound_size(f, eltype(x)); t0 = time()
      L0 = Main._rayleigh_L0(f, x)
      state = initial_state(method, options, f, g, x)
      state.L = L0
      _solve_gradient!(state, f, g, method, options, t0)
    end
  end
end
