struct PGDStoppingPoint{T,S}
    state::S
    iteration::Int
    objective::T
    previous_objective::T
end

function PGDStoppingPoint(state, k)
    PGDStoppingPoint(state, k, state.f_x + state.g_x, state.f_x_previous + state.g_x_previous)
end

Stopping.same_iterate(point::PGDStoppingPoint) = _unchanged(point.state.x, point.state.x_previous)

function Stopping.movement_norms(point::PGDStoppingPoint{Float64})
    state = point.state
    norm(state.delta_x), max(norm(state.x), norm(state.x_previous))
end

function Stopping.movement_norms(point::PGDStoppingPoint{Float32})
    state = point.state
    dx2, x2, previous2 = 0.0, 0.0, 0.0
    @inbounds @simd for i in eachindex(state.x, state.x_previous)
        x, previous = Float64(state.x[i]), Float64(state.x_previous[i])
        dx2 += abs2(x - previous)
        x2 += abs2(x)
        previous2 += abs2(previous)
    end
    sqrt(dx2), sqrt(max(x2, previous2))
end

"""
    ProximalSolvers.PGDPolicyResult

Result of an explicit stopping-policy solve. `minimizer` aliases the supplied
coefficient vector. `minimum` holds the computed objective or `missing` when
the iteration budget was zero. Use [`termination`](@ref) to inspect the reason
and the observations at the returned point.
"""
struct PGDPolicyResult{M,T,X,D}
    method::M
    minimizer::X
    minimum::Union{Missing,T}
    iterations::Int
    converged::Bool
    iteration_converged::Bool
    f_increased::Bool
    stagnated::Bool
    trace::OptimizationTrace{M}
    backtrack_steps::Int
    f_calls::Int
    grad_calls::Int
    prox_calls::Int
    decision::D
end

Stopping.termination(r::PGDPolicyResult) = r.decision
Base.summary(r::PGDPolicyResult) = summary(r.method)
minimizer(r::PGDPolicyResult) = r.minimizer
minimum(r::PGDPolicyResult) = r.minimum
iterations(r::PGDPolicyResult) = r.iterations
converged(r::PGDPolicyResult) = r.converged
iteration_limit_reached(r::PGDPolicyResult) = r.iteration_converged
f_increased(r::PGDPolicyResult) = r.f_increased
stagnated(r::PGDPolicyResult) = r.stagnated
backtrack_steps(r::PGDPolicyResult) = r.backtrack_steps
f_calls(r::PGDPolicyResult) = r.f_calls
grad_calls(r::PGDPolicyResult) = r.grad_calls
prox_calls(r::PGDPolicyResult) = r.prox_calls

function Base.show(io::IO, r::PGDPolicyResult)
    println(io, summary(r), " (explicit stopping policy)")
    _show_minimizer(io, minimizer(r))
    println(io, " * Minimum: ", minimum(r))
    println(io, " * Iterations: ", iterations(r))
    print(io, " * Stop reason: ", termination(r).reason)
end

function _pgd_policy_limit(options, limits)
    defaults = ProximalOptions()
    for name in (:ftol, :xtol, :gradtol, :allow_f_increases, :f_calls_limit,
                 :grad_calls_limit, :prox_calls_limit, :time_limit, :callback)
        getproperty(options, name) == getproperty(defaults, name) ||
            throw(ArgumentError("ProximalOptions.$name must have its default value with explicit stopping or limits"))
    end
    limits === nothing && return MaxIterations(options.maxiter)
    limits isa MaxIterations || throw(ArgumentError("limits must be MaxIterations(n) for this PGD route"))
    (options.maxiter == defaults.maxiter || options.maxiter == limits.n) ||
        throw(ArgumentError("ProximalOptions.maxiter conflicts with limits=MaxIterations($(limits.n))"))
    limits
end

function _pgd_policy_result(method, x, objective, increased, trace, monitor, reason, k,
                            f_calls, grad_calls, prox_calls, backtrack_steps)
    counts = (; f_calls, grad_calls, prox_calls, backtrack_steps, rejected_trials=prox_calls-k)
    decision = Stopping.report(monitor, reason, k, counts)
    PGDPolicyResult{typeof(method),eltype(x),typeof(x),typeof(decision)}(
        method, x, objective, k, false, decision.limit_reached, increased, reason === :stalled,
        trace, backtrack_steps, f_calls, grad_calls, prox_calls, decision)
end

function _solve_pgd_policy!(x, f, g, method, options, stopping, limits)
    base = f isa Scaled ? f.f : f
    (x isa Vector && base isa LeastSquaresLoss && base.Y isa Vector &&
     !(g isa Union{IndBox,IndBallL2})) ||
        throw(ArgumentError("explicit stopping and limits require dense vector least-squares PGD with a supported pilot penalty (excluding box and ball indicators)"))
    _check_gradient_problem(x, f, g, :pgd)
    limit = _pgd_policy_limit(options, limits)
    monitor = Stopping.prepare(stopping, limit, eltype(x))
    trace = OptimizationTrace{typeof(method)}()
    if iszero(limit.n)
        return _pgd_policy_result(method, x, missing, false, trace, monitor, :limit, 0, 0, 0, 0, 0)
    end
    g_work = _working_gradient_penalty(g, eltype(x))
    state = initial_state(method, options, f, g_work, x)
    _run_pgd_policy!(state, f, g_work, method, options, trace, monitor)
end

function _run_pgd_policy!(state, f, g, method, options, trace, monitor)
    k = 0
    point = PGDStoppingPoint(state, k)
    isfinite(point.objective) || throw(ArgumentError("start from a point where the composite objective is finite"))
    reason = Stopping.check!(monitor, point)
    tracing = _gradient_tracing(state, options)
    options.show_trace && @printf "Iter     Function value       |dx|/|x|       Step Size\n"

    while reason === :continue
        try
            update_state!(f, g, state, method)
            isfinite(state.f_x + state.g_x) || error("the gradient step did not produce a finite objective")
        catch
            _rollback_gradient_step!(state)
            rethrow()
        end
        k += 1
        point = PGDStoppingPoint(state, k)
        reason = Stopping.check!(monitor, point)
        if reason === :continue && _verified_pgd_stall(state)
            reason = :stalled
        end
        tracing && trace!(trace, state, k, options)
    end
    _pgd_policy_result(method, state.x, point.objective, point.objective > point.previous_objective,
                       trace, monitor, reason, k, state.f_calls, state.grad_calls, state.prox_calls,
                       state.backtrack_steps)
end
