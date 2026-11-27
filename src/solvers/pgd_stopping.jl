struct ProximalGradientDescentStoppingPoint{T,S}
    state::S
    iteration::Int
    objective::T
    previous_objective::T
end

function ProximalGradientDescentStoppingPoint(state, k)
    ProximalGradientDescentStoppingPoint(state, k, state.f_x + state.g_x,
                                        state.f_x_previous + state.g_x_previous)
end

function Stopping.same_iterate(point::ProximalGradientDescentStoppingPoint{T}) where {T}
    U = Stopping.bit_type(T)
    x = reinterpret(U, point.state.x)
    previous = reinterpret(U, point.state.x_previous)
    all(i -> Stopping.equal_bits(x[i], previous[i]), eachindex(x, previous))
end

Stopping.movement_distance(point::ProximalGradientDescentStoppingPoint{Float64}) =
    norm(point.state.delta_x)
_pgd_policy_norm(x::Vector{Float64}) = norm(x)
_pgd_policy_norm(x::Vector{Float32}) = sqrt(sum(v -> abs2(Float64(v)), x))
Stopping.movement_scale(point::ProximalGradientDescentStoppingPoint) =
    max(_pgd_policy_norm(point.state.x), _pgd_policy_norm(point.state.x_previous))

function Stopping.movement_distance(point::ProximalGradientDescentStoppingPoint{Float32})
    state = point.state
    dx2 = 0.0
    @inbounds @simd for i in eachindex(state.x, state.x_previous)
        dx2 += abs2(Float64(state.x[i]) - Float64(state.x_previous[i]))
    end
    sqrt(dx2)
end

"""
    ProximalSolvers.ProximalGradientDescentStoppingResult

Result of an explicit stopping-policy solve. `minimizer` aliases the supplied
coefficient vector. `minimum` holds the computed objective or `missing` when
the iteration budget was zero. Use [`termination`](@ref) to inspect the reason
and the observations at the returned point.
"""
struct ProximalGradientDescentStoppingResult{M,T,D}
    method::M
    minimizer::Vector{T}
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

Stopping.termination(r::ProximalGradientDescentStoppingResult) = r.decision
Base.summary(r::ProximalGradientDescentStoppingResult) = summary(r.method)
minimizer(r::ProximalGradientDescentStoppingResult) = r.minimizer
minimum(r::ProximalGradientDescentStoppingResult) = r.minimum
iterations(r::ProximalGradientDescentStoppingResult) = r.iterations
converged(r::ProximalGradientDescentStoppingResult) = r.converged
iteration_limit_reached(r::ProximalGradientDescentStoppingResult) = r.iteration_converged
f_increased(r::ProximalGradientDescentStoppingResult) = r.f_increased
stagnated(r::ProximalGradientDescentStoppingResult) = r.stagnated
backtrack_steps(r::ProximalGradientDescentStoppingResult) = r.backtrack_steps
f_calls(r::ProximalGradientDescentStoppingResult) = r.f_calls
grad_calls(r::ProximalGradientDescentStoppingResult) = r.grad_calls
prox_calls(r::ProximalGradientDescentStoppingResult) = r.prox_calls

function Base.show(io::IO, r::ProximalGradientDescentStoppingResult)
    println(io, summary(r), " (explicit stopping policy)")
    _show_minimizer(io, minimizer(r))
    println(io, " * Minimum: ", minimum(r))
    println(io, " * Iterations: ", iterations(r))
    print(io, " * Stop reason: ", termination(r).reason)
end

function _pgd_policy_limit(options, limits)
    defaults = ProximalOptions()
    options.callback === nothing ||
        throw(ArgumentError("ProximalOptions.callback must be nothing with explicit stopping or limits. Use UserStop for a predicate."))
    for name in (:ftol, :xtol, :gradtol, :allow_f_increases, :f_calls_limit,
                 :grad_calls_limit, :prox_calls_limit, :time_limit)
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
    g_calls = ismissing(objective) ? 0 : prox_calls + 1
    counts = (; f_calls, grad_calls, g_calls, prox_calls, backtrack_steps, rejected_trials=prox_calls-k)
    decision = Stopping.report(monitor, reason, k, counts)
    ProximalGradientDescentStoppingResult(
        method, x, objective, k, false, decision.limit_reached, increased, reason === :stalled,
        trace, backtrack_steps, f_calls, grad_calls, prox_calls, decision)
end

function _solve_pgd_policy!(x, f, g, method, options, stopping, limits)
    base = f isa Scaled ? f.f : f
    (x isa Vector && base isa LeastSquaresLoss && base.Y isa Vector &&
     !(g isa Union{IndBox,IndBallL2,IndBallL1})) ||
        throw(ArgumentError("explicit stopping and limits require dense vector least-squares PGD with a supported pilot penalty (excluding box and ball indicators)"))
    _check_gradient_problem(x, f, g, :pgd)
    limit = _pgd_policy_limit(options, limits)
    monitor = Stopping.prepare(stopping, limit, eltype(x))
    if iszero(limit.n)
        trace = OptimizationTrace{typeof(method)}()
        return _pgd_policy_result(method, x, missing, false, trace, monitor, :limit, 0, 0, 0, 0, 0)
    end
    g_work = _working_gradient_penalty(g, eltype(x))
    state = initial_state(method, options, f, g_work, x, Val(false))
    _solve_gradient!(state, f, g_work, method, options, nothing, monitor)
end

function _initial_gradient_decision(monitor::Stopping.Monitor, state, options, t0)
    point = ProximalGradientDescentStoppingPoint(state, 0)
    isfinite(point.objective) || throw(ArgumentError("start from a point where the composite objective is finite"))
    reason = Stopping.check!(monitor, point)
    (; reason, stop=reason !== :continue, point)
end

function _assess_gradient_step(monitor::Stopping.Monitor, state, f, g, options, iteration)
    point = ProximalGradientDescentStoppingPoint(state, iteration)
    reason = Stopping.check!(monitor, point)
    if reason === :continue && _verified_pgd_stall(state)
        reason = :stalled
    end
    (; reason, stop=reason !== :continue, point)
end

# The pilot makes its decision at the checkpoint and disallows trace callbacks.
_gradient_decision_after_trace(::Stopping.Monitor, previous, assessment, state, g, options, t0,
                               iteration, stopped_by_callback) = assessment

function _gradient_result(monitor::Stopping.Monitor, decision, state, method, options, trace, iteration)
    point = decision.point
    increased = point.objective > point.previous_objective
    _pgd_policy_result(method, state.x, point.objective, increased, trace, monitor, decision.reason,
                       iteration, state.f_calls, state.grad_calls, state.prox_calls,
                       state.backtrack_steps)
end
