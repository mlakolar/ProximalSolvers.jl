###################################
# tracing based on optim package
# removed grad norm field
#

function update!(tr::OptimizationTrace{T},
                 iteration::Int64,
                 f_x::Real,
                 g_x::Real,
                 dxx::Real,   # |dx|/|x|
                 L::Real,
                 dt::Dict,
                 store_trace::Bool,
                 show_trace::Bool,
                 print_every::Int64,
                 callback) where T

    os = OptimizationState{T}(iteration, f_x + g_x, dxx, L, dt)
    if store_trace
        push!(tr, os)
    end
    if show_trace && mod(iteration, print_every) == 0
        show(os)
    end

    if callback !== nothing && (iteration % print_every == 0)
        if store_trace
            stopped = callback(tr)
        else
            stopped = callback(os)
        end
    else
        stopped = false
    end
    stopped
end


function trace!(tr, f, g, state, iteration, method::ProximalSolver, options)
    dt = Dict()
    if options.extended_trace && iteration > 0
        dt["x"] = _copy(state.x)
        extended_trace!(dt, state)
    end
    update!(tr,
            iteration,
            state.f_x,
            state.g_x,
            _state_normdiff(state) / _state_norm(state, state.x),
            state.L,
            dt,
            options.store_trace,
            options.show_trace,
            options.print_every,
            options.callback)
end

extended_trace!(dt, state::ProximalGradientDescentState) = dt["grad_f(x)"] = _copy(state.grad_f_x)

f_residual(f_x, f_x_previous, f_tol) = abs(f_x-f_x_previous)/(abs(f_x)+f_tol)
g_residual(state::ProximalGradientDescentState) = _maxabs_residual(state.grad_f_x, state.grad_f_x_previous, state.delta_x, state.L)
function convergence_assessment(
  state::Union{ProximalGradientDescentState, AccProxGradDescentState},
  f, g, options::ProximalOptions
  )

  x_converged, f_converged, grad_converged, f_increased = false, false, false, false

  norm_x = _state_norm(state, state.x)
  norm_dx = _state_norm(state, state.delta_x)

  if norm_dx < options.xtol * max( norm_x, 1. )
    x_converged = true
  end

  # Relative Tolerance
  fval = state.f_x + state.g_x
  fval_prev = state.f_x_previous + state.g_x_previous
  if f_residual(fval, fval_prev, options.ftol) < options.ftol ||
        abs(fval - fval_prev) < eps(abs(fval)+abs(fval_prev))
    f_converged = true
  end

  if fval > fval_prev
    f_increased = true
  end

  grad_converged = gradient_converged!(state, options)

  converged = x_converged || f_converged || grad_converged

  return x_converged, f_converged, grad_converged, converged, f_increased
end
function gradient_converged!(state::ProximalGradientDescentState{T}, options::ProximalOptions) where T
  residual = g_residual(state)
  state.max_residual = max(state.max_residual, residual)
  # (xhat - x) / τ = -(L (x - x_previous) + ∇f(x_previous))
  subgrad = _maxabs_axpy(state.L, state.delta_x, state.grad_f_x_previous)
  normalizer = max(_norm_inf(state.grad_f_x), subgrad) + options.gradtol
  n_residual = residual / normalizer
  residual / (state.max_residual + options.gradtol) < options.gradtol || n_residual < options.gradtol
end

_state_norm(s::ProximalGradientDescentState, x) = _norm(x)
_state_normdiff(s::ProximalGradientDescentState) = _norm_diff(s.x, s.x_previous, 2.)
