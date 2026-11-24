struct ProximalGradientStoppingPoint{T,S}
    state::S
    iteration::Int
    objective::T
    previous_objective::T
end

function ProximalGradientStoppingPoint(state, k)
    ProximalGradientStoppingPoint(state, k, state.f_x + state.g_x,
                                  state.f_x_previous + state.g_x_previous)
end

Stopping.checkpoint_evaluation_limit_reached(monitor, point::ProximalGradientStoppingPoint) =
    Stopping.evaluation_limit_reached(monitor.evaluation_limits, point.state)

function Stopping.same_iterate(point::ProximalGradientStoppingPoint{T}) where {T}
    U = Stopping.bit_type(T)
    x = reinterpret(U, point.state.x)
    previous = reinterpret(U, point.state.x_previous)
    all(i -> Stopping.equal_bits(x[i], previous[i]), eachindex(x, previous))
end

Stopping.movement_distance(point::ProximalGradientStoppingPoint{Float64}) =
    norm(point.state.delta_x)
_gradient_policy_norm(x::Vector{Float64}) = norm(x)
_gradient_policy_norm(x::Vector{Float32}) = sqrt(sum(v -> abs2(Float64(v)), x))
Stopping.movement_scale(point::ProximalGradientStoppingPoint) =
    max(_gradient_policy_norm(point.state.x), _gradient_policy_norm(point.state.x_previous))

function Stopping.movement_distance(point::ProximalGradientStoppingPoint{Float32})
    state = point.state
    dx2 = 0.0
    @inbounds @simd for i in eachindex(state.x, state.x_previous)
        dx2 += abs2(Float64(state.x[i]) - Float64(state.x_previous[i]))
    end
    sqrt(dx2)
end

"""
    ProximalSolvers.ProximalGradientStoppingResult

Result of an explicit PGD or APG stopping-policy solve. `minimizer` aliases the supplied
coefficient vector. `minimum` holds the computed objective or `missing` when
a budget of zero prevented initialization. Use [`termination`](@ref) to inspect the reason
and the observations at the returned point.
"""
struct ProximalGradientStoppingResult{M,T,D}
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

Stopping.termination(r::ProximalGradientStoppingResult) = r.decision
Base.summary(r::ProximalGradientStoppingResult) = summary(r.method)
minimizer(r::ProximalGradientStoppingResult) = r.minimizer
minimum(r::ProximalGradientStoppingResult) = r.minimum
iterations(r::ProximalGradientStoppingResult) = r.iterations
converged(r::ProximalGradientStoppingResult) = r.converged
iteration_limit_reached(r::ProximalGradientStoppingResult) = r.iteration_converged
call_limit_reached(r::ProximalGradientStoppingResult) = !isempty(r.decision.reached_evaluation_limits)
f_increased(r::ProximalGradientStoppingResult) = r.f_increased
stagnated(r::ProximalGradientStoppingResult) = r.stagnated
backtrack_steps(r::ProximalGradientStoppingResult) = r.backtrack_steps
f_calls(r::ProximalGradientStoppingResult) = r.f_calls
grad_calls(r::ProximalGradientStoppingResult) = r.grad_calls
prox_calls(r::ProximalGradientStoppingResult) = r.prox_calls

function Base.show(io::IO, r::ProximalGradientStoppingResult)
    println(io, summary(r), " (explicit stopping policy)")
    _show_minimizer(io, minimizer(r))
    println(io, " * Minimum: ", minimum(r))
    println(io, " * Iterations: ", iterations(r))
    decision = termination(r)
    println(io, " * Convergence: ", converged(r))
    println(io, " * Stopping condition satisfied: ", decision.satisfied)
    print(io, " * Stop reason: ", decision.reason)
end

function _gradient_policy_limits(options, limits)
    defaults = ProximalOptions()
    options.callback === nothing ||
        throw(ArgumentError("ProximalOptions.callback must be nothing with explicit stopping or limits. Use UserStop for a predicate."))
    for name in (:ftol, :xtol, :gradtol, :allow_f_increases, :f_calls_limit,
                 :grad_calls_limit, :prox_calls_limit, :time_limit)
        getproperty(options, name) == getproperty(defaults, name) ||
            throw(ArgumentError("ProximalOptions.$name must have its default value with explicit stopping or limits"))
    end
    limits === nothing && return MaxIterations(options.maxiter), ()
    requested = limits isa Tuple ? limits : (limits,)
    (isempty(requested) || !all(l -> l isa Union{MaxIterations,Stopping.EvaluationLimit}, requested)) &&
        throw(ArgumentError("explicit gradient limits must be a limit or a nonempty tuple of iteration and evaluation limits"))
    allunique(map(typeof, requested)) || throw(ArgumentError("each limit kind may be specified once"))
    iteration_index = findfirst(l -> l isa MaxIterations, requested)
    limit = iteration_index === nothing ? MaxIterations(options.maxiter) : requested[iteration_index]
    (options.maxiter == defaults.maxiter || options.maxiter == limit.n) ||
        throw(ArgumentError("ProximalOptions.maxiter conflicts with limits=MaxIterations($(limit.n))"))
    limit, filter(l -> l isa Stopping.EvaluationLimit, requested)
end

function _gradient_policy_result(method, x, objective, increased, trace, monitor, reason, k,
                                 f_calls, grad_calls, prox_calls, backtrack_steps)
    g_calls = ismissing(objective) ? 0 : prox_calls + 1
    counts = (; f_calls, grad_calls, g_calls, prox_calls, backtrack_steps, rejected_trials=prox_calls-k)
    report = Stopping.report(monitor, reason, k, counts)
    evaluation_limits = monitor.evaluation_limits
    reached_evaluation_limits = filter(l -> Stopping.evaluation_limit_reached(l, counts), evaluation_limits)
    decision = merge(report, (; evaluation_limits, reached_evaluation_limits,
                              limit_reached=report.limit_reached || !isempty(reached_evaluation_limits)))
    converged = monitor.stationarity !== nothing && decision.satisfied &&
        any(o -> o.evidence === :stationarity && o.status === :pass &&
               o.path in decision.winning_branch, decision.observations)
    ProximalGradientStoppingResult(
        method, x, objective, k, converged, report.limit_reached, increased, reason === :stalled,
        trace, backtrack_steps, f_calls, grad_calls, prox_calls, decision)
end

_check_gradient_policy_problem(x, f, g, ::ProximalGradientDescent) =
    _check_gradient_problem(x, f, g, :pgd)
_check_gradient_policy_problem(x, f, g, method::AccProxGradDescent) =
    _check_apg_problem(x, f, g, method)

_gradient_stationarity_provider(::ProximalGradientDescent, f, g) =
    (point, rtol) -> _coordinatewise_stationary!(point.state, point.state.grad_f_x, g, rtol)

# Between evaluations in one checkpoint, xhat holds the accepted gradient.
# APG overwrites the scratch when the next update starts.
mutable struct APGStationarityProvider{F,G}
    loss::F
    penalty::G
    iteration::Int
end

_gradient_stationarity_provider(::AccProxGradDescent, f, g) = APGStationarityProvider(f, g, -1)

function (provider::APGStationarityProvider)(point, rtol)
    state = point.state
    if provider.iteration != point.iteration
        _gradient_at_x!(state, provider.loss)
        state.f_calls += 1
        provider.iteration = point.iteration
    end
    _coordinatewise_stationary!(state, state.xhat, provider.penalty, rtol)
end

function _solve_gradient_policy!(x, f, g, method, options, stopping, limits)
    base = f isa Scaled ? f.f : f
    (x isa Vector && base isa LeastSquaresLoss && base.Y isa Vector &&
     !(g isa Union{IndBox,IndBallL2})) ||
        throw(ArgumentError("explicit stopping and limits require dense vector least-squares PGD or APG with a supported penalty (excluding box and ball indicators)"))
    _check_gradient_policy_problem(x, f, g, method)
    limit, evaluation_limits = _gradient_policy_limits(options, limits)
    monitor = Stopping.prepare(stopping, limit, eltype(x); evaluation_limits)
    use_stationarity = Stopping.needs_stationarity(monitor)
    if use_stationarity && !(g isa Union{NormL1,ElasticNet})
        throw(ArgumentError("ScaledKKT requires NormL1 or ElasticNet for dense vector least-squares PGD or APG"))
    end
    if iszero(limit.n) || any(l -> iszero(l.n), evaluation_limits)
        trace = OptimizationTrace{typeof(method)}()
        return _gradient_policy_result(method, x, missing, false, trace, monitor, :limit, 0, 0, 0, 0, 0)
    end
    g_work = _working_gradient_penalty(g, eltype(x))
    state = initial_state(method, options, f, g_work, x, Val(use_stationarity))
    if use_stationarity
        monitor = Stopping.with_stationarity(monitor, _gradient_stationarity_provider(method, f, g_work))
    end
    _solve_gradient!(state, f, g_work, method, options, nothing, monitor)
end

@inline function _gradient_step!(monitor::Stopping.Monitor, state, f, g,
                                 method::ProximalGradientDescent, options, t0)
    _update_pgd_state!(f, g, state, method, monitor.evaluation_limits)
end

@inline function _gradient_step!(monitor::Stopping.Monitor, state, f, g,
                                 method::AccProxGradDescent, options, t0)
    _update_apg_state!(f, g, state, method, monitor.evaluation_limits)
end

_interrupted_gradient_decision(::Stopping.Monitor, decision, state, options) =
    (; reason=:limit, stop=true, point=decision.point)

function _initial_gradient_decision(monitor::Stopping.Monitor, state, options, t0)
    point = ProximalGradientStoppingPoint(state, 0)
    isfinite(point.objective) || throw(ArgumentError("start from a point where the composite objective is finite"))
    reason = Stopping.check!(monitor, point)
    (; reason, stop=reason !== :continue, point)
end

function _assess_gradient_step(monitor::Stopping.Monitor, state, f, g, options, iteration)
    point = ProximalGradientStoppingPoint(state, iteration)
    reason = Stopping.check!(monitor, point)
    if reason === :continue && _verified_pgd_stall(state)
        reason = :stalled
    end
    (; reason, stop=reason !== :continue, point)
end

# The pilot makes its decision at the checkpoint and disallows trace callbacks.
_gradient_decision_after_trace(::Stopping.Monitor, previous, assessment, state, options, t0,
                               iteration, stopped_by_callback) = assessment

function _gradient_result(monitor::Stopping.Monitor, decision, state, method, options, trace, iteration)
    point = decision.point
    increased = point.objective > point.previous_objective
    _gradient_policy_result(method, state.x, point.objective, increased, trace, monitor,
                            decision.reason, iteration, state.f_calls, state.grad_calls,
                            state.prox_calls, state.backtrack_steps)
end
