# Probe-only code, evaluated inside the ProximalSolvers module namespace of a loaded copy (no tracked file
# is changed): copies of PGD's update_state! and APG's update_state!/_prox_grad_step! that record the
# line-search trials, and prototype entry points that differ from solve! only in the initial curvature.
# Source copied from master dac9f4b (src/solvers/*.jl); only the `rec`/`trials` lines are added.

# ---- initial-curvature candidates --------------------------------------------------------------
# α ‖X‖_F² as an _SE (APG's proved upper bound on ‖X‖_F reused; α rounded to Float64 for the _SE)
function _probe_frob_alpha(::Type{T}, f) where T
  m = _image_model(f)
  nx = _frobenius_upper(T, m.X)
  se = _se_mul(_se_mul(nx, nx), _SE{T}(Float64(m.α)))
  se
end
_se_to_T(::Type{T}, se::_SE) where T = iszero(se.s) ? zero(T) : ldexp(se.s, clamp(se.e, -100000, 100000))
# policy :base (L = 1, master), :b1 (min(1, α‖X‖_F²)), :b2 (α‖X‖_F²), :b3 (min(1, α‖X‖_F²) floored)
_probe_L0(v::Real, ::Type{T}, f) where T = T(v)
function _probe_L0(policy::Symbol, ::Type{T}, f) where T
  policy === :base && return one(T)
  policy === :b1x && return _probe_L0_early(T, f)
  se = _probe_frob_alpha(T, f)
  v = _se_to_T(T, se)
  floorL = floatmin(T)
  policy === :b2 && return max(v, floorL)
  return max(min(one(T), v), floorL)
end

# ---- PGD ---------------------------------------------------------------------------------------
function traced_update_pgd!(f, g, state::ProximalGradientDescentState{T}, method, trials) where T
    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    _copyto!(state.grad_f_x_previous, state.grad_f_x)
    state.L *= method.ls.α
    state.verified_rejection = false
    while true
      Ltry = state.L
      _step!(state.xhat, state.x_previous, state.grad_f_x_previous, state.L)
      state.g_x = convert(_eltype(state.x), value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(state.x, f, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1
      mode_simple = state.backtrack_simple
      ver0 = state.verifications
      acc = backtrack!(state, method.ls, f, g)
      push!(trials, (L = Ltry, xhat = state.xhat[1], x = state.x[1], f = state.f_x, accepted = acc,
                     L_after = state.L, simple = mode_simple, verified = state.verifications - ver0,
                     dxnorm = _norm(state.delta_x)))
      acc && break
    end
    if has_updated_gradient( state, method.ls ) == false
        LineSearches.value_and_gradient_at_x!(state, f)
        state.f_calls += 1
        state.grad_calls += 1
    end
    state
end

# ---- APG ---------------------------------------------------------------------------------------
function traced_prox_grad_step!(f, g, state::AccProxGradDescentState{T}, β::T, trials) where T
    f_y = _value_and_gradient!(state.grad_f_y, state.y, f, state.z_y, state.dz)
    state.f_calls += 1
    state.grad_calls += 1
    if !(isfinite(f_y) && _allfinite(state.grad_f_y))
      state.f_x = T(Inf)
      push!(trials, (L = state.L, f = state.f_x, ok = false, fresh = 0, kind = :nonfinite_y, dnorm = NaN))
      return state
    end
    while true
      _step!(state.xhat, state.y, state.grad_f_y, state.L)
      state.g_x = convert(T, value_and_prox!(state.x, g, state.xhat, one(state.L) / state.L))
      state.f_x = _value!(state.x, f, state.model, state.z_x)
      state.prox_calls += 1
      state.f_calls += 1
      _sub!(state.xhat, state.x, state.y)
      state.backtrack_steps += 1
      ok, fresh, kind = false, 0, :nonfinite_f
      dn = NaN
      if isfinite(state.f_x)
        kind = :uncertified
        sd, sx = _sumsq2(state.xhat, state.x)
        normx = _se_norm_onepass(T, sx, state.x)
        D = _se_norm_onepass(T, sd, state.xhat)
        if normx !== nothing && D !== nothing
          dn = Float64(_se_to_T(Float64, D))
          if iszero(D.s)
            state.normx = normx
            ok, kind = true, :zero_step
          else
            ok, fresh = _bound_certified!(state.dz, state.model, state.z_y, state.z_x, state.xhat,
                                          D, state.L, state.image_error_y, normx, state.rootα,
                                          state.bound, state.fresh_only)
            state.fallbacks += fresh
            if ok
              state.normx = normx
              kind = :certified
            end
          end
        else
          kind = :norm_nothing
        end
      end
      push!(trials, (L = state.L, f = state.f_x, ok = ok, fresh = fresh, kind = kind, dnorm = dn))
      ok && break
      state.L = LineSearches.next_curvature(state.L, β)
    end
    state
end

function traced_update_apg!(f, g, state::AccProxGradDescentState{T}, method, trials) where T
    ω = T(state.k / (state.k + 3))
    state.L *= T(method.α)
    normxa, normxb = state.normx, state.normx_previous
    state.normx_previous = normxa
    state.image_error_y = _image_error_bound(state.bound, normxa, normxb, ω > 0)
    _extrapolate_point!(state.y, state.x, state.x_previous, ω)
    zx, zp = state.z_x, state.z_previous
    @. state.z_y = zx + ω * (zx - zp)
    _copyto!(state.x_previous, state.x)
    state.f_x_previous = state.f_x
    state.g_x_previous = state.g_x
    state.z_previous, state.z_x = state.z_x, state.z_previous
    while true
      traced_prox_grad_step!(f, g, state, T(method.β), trials)
      if ω > 0 && state.f_x + state.g_x > state.f_x_previous + state.g_x_previous
        ω = zero(T)
        state.k = 0
        state.restarts += 1
        _copyto!(state.y, state.x_previous)
        copyto!(state.z_y, state.z_previous)
        state.image_error_y = _image_error_bound(state.bound, normxa, normxb, false)
        push!(trials, (L = state.L, f = state.f_x, ok = false, fresh = 0, kind = :restart, dnorm = NaN))
      else
        break
      end
    end
    state.k += 1
    _sub!(state.delta_x, state.x, state.x_previous)
    state
end

# ---- driver: the loop of _solve_gradient! with a record per iteration -------------------------------
# kind = :pgd | :apg; L0policy as in _probe_L0; returns (result-like NamedTuple, records)
function traced_solve!(kind::Symbol, x, f, g, options::ProximalOptions = ProximalOptions();
                       L0 = :base, hook = nothing)
  T = eltype(x)
  method = kind === :pgd ? ProximalGradientDescent() : AccProxGradDescent()
  _check_problem(x, f, g)
  kind === :apg && (_check_method(method, T); _check_bound_size(f, T))
  state = initial_state(method, options, f, g, x)
  state.L = _probe_L0(L0, T, f)
  L_init = state.L
  recs = NamedTuple[]
  converged = false; stopped = false; iteration = 0; stop_reason = :maxiter
  flags = (false, false, false)
  while !converged && !stopped && iteration < options.maxiter
    iteration += 1
    L_start = state.L
    xprev = copy(state.x)
    trials = NamedTuple[]
    bs0, fc0, gc0 = state.backtrack_steps, state.f_calls, state.grad_calls
    ver0 = state isa ProximalGradientDescentState ? state.verifications : state.fallbacks
    err = nothing
    try
      kind === :pgd ? traced_update_pgd!(f, g, state, method, trials) : traced_update_apg!(f, g, state, method, trials)
      isfinite(state.f_x + state.g_x) || error("the gradient step did not produce a finite objective")
    catch e
      _copyto!(state.x, state.x_previous)
      err = e
    end
    if err !== nothing
      push!(recs, (iter = iteration, L_start = L_start, L_end = state.L, trials = trials, error = sprint(showerror, err), x = copy(state.x)))
      stop_reason = :error
      break
    end
    x_c, f_c, g_c, converged, f_inc = convergence_assessment(state, f, g, options)
    stagnated = _stagnated(state, options)
    increased = f_inc && !options.allow_f_increases
    rec = (iter = iteration, L_start = L_start, L_end = state.L, trials = trials,
           f = state.f_x + state.g_x, fprev = state.f_x_previous + state.g_x_previous, x = copy(state.x), xprev = xprev,
           grad_prev = kind === :pgd ? copy(state.grad_f_x_previous) : copy(state.grad_f_y),
           bs = state.backtrack_steps - bs0, fc = state.f_calls - fc0, gc = state.grad_calls - gc0,
           ver = (state isa ProximalGradientDescentState ? state.verifications : state.fallbacks) - ver0,
           flags = (x = x_c, f = f_c, g = g_c), increased = increased, stagnated = stagnated,
           resid = Float64(g_residual(state)), error = "")
    push!(recs, rec)
    hook === nothing || hook(rec, state)
    increased && (stopped = true; stop_reason = :f_increased)
    stagnated && (stopped = true; stop_reason = :stagnated)
  end
  converged && (stop_reason = :converged)
  (x = state.x, converged = converged, iterations = iteration, stop = stop_reason, L_init = L_init, L = state.L,
   f_calls = state.f_calls, grad_calls = state.grad_calls, backtrack_steps = state.backtrack_steps,
   products_fwd = 1 + (state isa ProximalGradientDescentState ? state.verifications : state.fallbacks) + state.prox_calls,
   state = state), recs
end

# ---- prototype entry points: solve! with the initial curvature of a policy ---------------------------
function solve_proto!(x, f, g, method, options::ProximalOptions = ProximalOptions(); L0 = :base)
  _check_keywords(())
  _check_problem(x, f, g)
  T = eltype(x)
  if method isa AccProxGradDescent
    _check_method(method, T); _check_bound_size(f, T)
  end
  t0 = time()
  state = initial_state(method, options, f, g, x)
  state.L = _probe_L0(L0, T, f)
  _solve_gradient!(state, f, g, method, options, t0)
end

# same as solve_proto! but returns the state too (product counters), and catches nothing
function solve_proto2!(x, f, g, method, options::ProximalOptions = ProximalOptions(); L0 = :base)
  _check_problem(x, f, g)
  T = eltype(x)
  if method isa AccProxGradDescent
    _check_method(method, T); _check_bound_size(f, T)
  end
  state = initial_state(method, options, f, g, x)
  state.L = _probe_L0(L0, T, f)
  L_init = state.L
  res = _solve_gradient!(state, f, g, method, options, time())
  res, state, L_init
end

# ---- APG with one Frobenius bound shared by the bound constants and the initial curvature -----------
function _bound_constants2(::Type{T}, X, normX) where {T}   # _bound_constants with ‖X‖_F supplied
  n, p = size(X)
  u = _unit(T)
  δn, δp, γp = _gamma(T, n + 4), _gamma(T, p + 4), _gamma(T, p)
  κ = 32u
  η = _SE{T}(nextfloat(zero(T)))
  rn, rp = _SE{T}(sqrt(T(n))), _SE{T}(sqrt(T(p)))
  _BoundConstants{T}(_SE{T}(inv((1 - δn) * (1 - u))), _SE{T}(inv((1 + δn) * (1 + u))),
    _SE{T}(inv((1 + δp) * (1 + u))), _SE{T}(inv((1 - δp) * (1 - u))), _SE{T}(inv(1 - δn)),
    _SE{T}(inv(1 - δp)), _SE{T}((1 + 4eps(T)) / (1 + κ)), _SE{T}((1 + 4eps(T)) * (1 + κ)),
    _se_mul(_SE{T}(γp), normX), _se_mul(_SE{T}(γp + 2u), normX),
    _se_mul(_SE{T}(2γp + 16u), normX),
    _se_mul(_SE{T}(T(2p)), rn, η),
    _se_add(_se_mul(_SE{T}(T(8p)), rn, η), _se_mul(_SE{T}(T(2)), rp, normX, η)))
end
function initial_state_apg_reuse(method::AccProxGradDescent, options, f, g, x0::Vector{T}) where T
    model = _image_model(f)
    z_x = _image_buffer(model)
    f_x = _value!(x0, f, model, z_x)
    _check_start(f_x)
    normx0 = _se_norm(T, x0)
    normX = _frobenius_upper(T, model.X)
    rootα = _root_scale(T, model.α)
    se = _se_mul(rootα, normX)
    L0 = max(min(one(T), _se_to_T(T, _se_mul(se, se))), floatmin(T))
    AccProxGradDescentState(x0, f_x, T(g(x0)), _copy(x0), T(NaN), T(NaN), _similar(x0), _dense_similar(x0), _similar(x0), _similar(x0),
                         L0, T(-Inf), -one(T), 0, 0, 0, 1, 0, 0, model, z_x, copy(z_x), similar(z_x), similar(z_x),
                         _bound_constants2(T, model.X, normX), rootα, _se_zero(T), normx0, normx0, false, 0)
end
function solve_apg_reuse!(x, f, g, method::AccProxGradDescent, options::ProximalOptions = ProximalOptions())
  _check_problem(x, f, g)
  T = eltype(x)
  _check_method(method, T); _check_bound_size(f, T)
  state = initial_state_apg_reuse(method, options, f, g, x)
  _solve_gradient!(state, f, g, method, options, time())
end

# ---- free lower bound on L_f from the start's residual and gradient (no extra pass over X) -------------
# L_f = α ‖X‖₂² ≥ α ‖Xᵀd₀‖² / ‖d₀‖² = ‖g₀‖² / (α ‖d₀‖²), d₀ = X x₀ − y, g₀ = α Xᵀ d₀ (as computed), in _SE arithmetic
function _se_div(a::_SE{T}, b::_SE{T}) where T
  iszero(a.s) && return _se_zero(T)
  iszero(b.s) && return _SE{T}(T(Inf), 0)
  _renormal(a.s / b.s, a.e - b.e)
end
function _probe_Llower(::Type{T}, f, x0) where T
  model = _image_model(f)
  z = _image_buffer(model); dz = similar(z); g = _dense_similar(x0)
  _image!(z, model, x0)
  _value_and_gradient!(g, x0, f, z, dz)
  ds = _se_norm(T, dz); gs = _se_norm(T, g)
  (ds === nothing || gs === nothing || iszero(ds.s)) && return nothing
  q = _se_div(gs, _se_mul(ds, _root_scale(T, model.α)))
  _se_mul(q, q)
end

# B1 with an early exit: the running sum of α‖column‖² is a lower bound on U = α‖X‖_F²; once it reaches 2 (so U ≥ 1 even allowing
# for rounding of the sum, whose relative error is far below 1/2) min(1, U) = 1 and the scan stops. Otherwise the range-safe bound is formed.
function _probe_L0_early(::Type{T}, f) where T
  m = _image_model(f); X = m.X; α = Float64(m.α)
  n, p = size(X)
  s = 0.0
  @inbounds for j in 1:p
    cj = 0.0
    @simd for i in 1:n
      cj += abs2(Float64(X[i, j]))
    end
    s += cj
    isfinite(s) && α * s >= 2.0 && return one(T)
  end
  max(min(one(T), _se_to_T(T, _probe_frob_alpha(T, f))), floatmin(T))
end
