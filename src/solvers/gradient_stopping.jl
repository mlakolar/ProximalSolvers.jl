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
_gradient_policy_norm(x::VecOrMat{Float64}) = norm(x)
_gradient_policy_norm(x::VecOrMat{Float32}) = sqrt(sum(v -> abs2(Float64(v)), x))
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
coefficient vector or matrix. `minimum` holds the computed objective or `missing` when
a budget of zero prevented initialization. Use [`termination`](@ref) to inspect the reason
and the observations at the returned point.
"""
struct ProximalGradientStoppingResult{M,T,D,X<:VecOrMat{T}}
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
    g_calls = ismissing(objective) ? 0 : prox_calls + 1 + _dual_gap_calls(monitor.gap)
    rejected_trials = prox_calls - _diagnostic_prox_calls(monitor.stationarity) - k
    counts = (; f_calls, grad_calls, g_calls, prox_calls, backtrack_steps, rejected_trials)
    report = Stopping.report(monitor, reason, k, counts)
    evaluation_limits = monitor.evaluation_limits
    reached_evaluation_limits = filter(l -> Stopping.evaluation_limit_reached(l, counts), evaluation_limits)
    decision = merge(report, (; evaluation_limits, reached_evaluation_limits,
                              limit_reached=report.limit_reached || !isempty(reached_evaluation_limits)))
    converged = (monitor.stationarity !== nothing || monitor.gap !== nothing) && decision.satisfied &&
        any(o -> (o.evidence === :stationarity || o.evidence === :gap_bound) && o.status === :pass &&
               o.path in decision.winning_branch, decision.observations)
    ProximalGradientStoppingResult(
        method, x, objective, k, converged, report.limit_reached, increased, reason === :stalled,
        trace, backtrack_steps, f_calls, grad_calls, prox_calls, decision)
end

_check_gradient_policy_problem(x, f, g, ::ProximalGradientDescent) =
    _check_gradient_problem(x, f, g, :pgd)
_check_gradient_policy_problem(x, f, g, method::AccProxGradDescent) =
    _check_apg_problem(x, f, g, method)

const _MatrixGradientState = Union{
    ProximalGradientDescentState{T,Matrix{T}} where T,
    AccProxGradDescentState{T,Matrix{T}} where T,
}

function _counted_lambda_max!(state)
    if state.λmax < 0
        _lambda_max!(state)
        state.grad_calls += 1
    end
    state.λmax
end

_prepare_gradient_stationarity!(state) = nothing
_prepare_gradient_stationarity!(state::_MatrixGradientState) = _counted_lambda_max!(state)

_gradient_stationarity!(state, grad, g, rtol) = _coordinatewise_stationary!(state, grad, g, rtol)
_gradient_stationarity!(state::_MatrixGradientState, grad, g, rtol) =
    _lambda_scaled_stationary(state.x, grad, g, state.λmax, rtol)

function _gradient_stationarity_provider(::ProximalGradientDescent, f, g)
    function check(point, rtol)
        state = point.state
        _prepare_gradient_stationarity!(state)
        _gradient_stationarity!(state, state.grad_f_x, g, rtol)
    end
end

# Between evaluations in one checkpoint, xhat holds the accepted gradient.
# APG overwrites the scratch when the next update starts.
mutable struct APGStationarityProvider{F,G}
    loss::F
    penalty::G
    iteration::Int
end

_gradient_stationarity_provider(::AccProxGradDescent, f, g) = APGStationarityProvider(f, g, -1)

function Stopping.stationarity_admitted(::APGStationarityProvider,
    point::ProximalGradientStoppingPoint{T,<:AccProxGradDescentState{T,Matrix{T}}}, limits) where T
    _reference_and_accepted_gradients_admitted(point.state, limits)
end

function _reference_and_accepted_gradients_admitted(state, limits)
    state.λmax < 0 || return true
    # The reached-cap guard already leaves room for the smooth value.
    !any(l -> l isa MaxGradientEvaluations && l.n - state.grad_calls < 2, limits)
end

function (provider::APGStationarityProvider)(point, rtol)
    state = point.state
    if provider.iteration != point.iteration
        # Form the reference gradient first because both calls use xhat.
        _prepare_gradient_stationarity!(state)
        _gradient_at_x!(state, provider.loss)
        state.f_calls += 1
        provider.iteration = point.iteration
    end
    _gradient_stationarity!(state, state.xhat, provider.penalty, rtol)
end

mutable struct ProximalGradientMappingProvider{F,G,T}
    loss::F
    penalty::G
    iteration::Int
    measurement::Union{Nothing,ProximalGradientMeasurement{T}}
    prox_calls::Int
end

_diagnostic_prox_calls(cache) = 0
_diagnostic_prox_calls(cache::Stopping.StationarityCache{<:ProximalGradientMappingProvider}) =
    cache.provider.prox_calls

function Stopping.stationarity_admitted(::ProximalGradientMappingProvider,
    point::ProximalGradientStoppingPoint{<:Any,<:AccProxGradDescentState}, limits)
    _reference_and_accepted_gradients_admitted(point.state, limits)
end

function (provider::ProximalGradientMappingProvider)(point, rtol)
    state = point.state
    if provider.iteration != point.iteration
        t = one(state.L) / state.L
        isfinite(t) && t > 0 || return false
        λmax = _counted_lambda_max!(state)
        grad = _gradient_at_x!(state, provider.loss)
        state isa AccProxGradDescentState && (state.f_calls += 1)
        # The initial point has no accepted predecessor.
        provider.measurement = _measure_proximal_gradient_mapping!(state, provider.penalty, grad, t, λmax;
                                                                  restore_displacement=point.iteration > 0)
        provider.prox_calls += 1
        provider.iteration = point.iteration
    end
    _proximal_gradient_mapping_passes(provider.measurement, rtol)
end

mutable struct DualGapProvider
    X::Matrix{Float32}
    y::Vector{Float32}
    level::Float32
    workspace::Union{Nothing,_DualGapWorkspace}
    calls::Int
end

_dual_gap_calls(::Nothing) = 0
_dual_gap_calls(cache::Stopping.GapCache{DualGapProvider}) = cache.provider.calls

function (provider::DualGapProvider)(point)
    _dual_gap_fp_supported() || return nothing
    workspace = provider.workspace
    if workspace === nothing
        workspace = _DualGapWorkspace(size(provider.X)...)
        provider.workspace = workspace
    end
    state = point.state
    upper = _relative_dual_gap_upper!(workspace, provider.X, provider.y, state.x,
                                     Float64(provider.level))
    state.f_calls += 1
    state.grad_calls += 1
    provider.calls += 1
    upper
end

function _dual_gap_level(x, f, g, method)
    (method isa ProximalGradientDescent && x isa Vector{Float32} &&
     f isa LeastSquaresLoss && f.X isa Matrix{Float32} && f.Y isa Vector{Float32} &&
     g isa NormL1{<:Union{Float32,Float64},Nothing}) ||
        throw(ArgumentError("DualGap requires raw dense Float32 least-squares PGD with an unweighted NormL1 penalty and a Float32 or Float64 level"))
    level = _converted_level(Float32, g.λ0)
    (isfinite(level) && !signbit(level) && !Stopping.stored_zero(level) &&
     (g.λ0 isa Float32 || Stopping.stored_equal(Float64(level), g.λ0))) ||
        throw(ArgumentError("DualGap requires a positive penalty level exactly representable in Float32"))
    level
end

function _solve_gradient_policy!(x, f, g, method, options, stopping, limits)
    base = f isa Scaled ? f.f : f
    (base isa LeastSquaresLoss &&
     ((x isa Vector && base.Y isa Vector) || (x isa Matrix && base.Y isa AbstractMatrix)) &&
     !(g isa Union{IndBox,IndBallL2,IndBallL1})) ||
        throw(ArgumentError("explicit stopping and limits require dense least-squares PGD or APG with matching vector or matrix coefficients and a supported penalty"))
    _check_gradient_policy_problem(x, f, g, method)
    limit, evaluation_limits = _gradient_policy_limits(options, limits)
    mapping_supported = g isa NormLinf
    supported = mapping_supported ? Stopping.MappingLeaves : Union{Stopping.GradientLeaves,Stopping.GapLeaves}
    monitor = Stopping.prepare(stopping, limit, eltype(x), supported; evaluation_limits)
    use_stationarity = Stopping.needs_stationarity(monitor)
    gap_level = Stopping.needs_gap(monitor) ? _dual_gap_level(x, f, g, method) : nothing
    if use_stationarity && !mapping_supported && !(g isa Union{NormL1,ElasticNet})
        throw(ArgumentError("ScaledKKT requires NormL1 or ElasticNet for dense vector least-squares PGD or APG"))
    end
    if iszero(limit.n) || any(l -> iszero(l.n), evaluation_limits)
        trace = OptimizationTrace{typeof(method)}()
        return _gradient_policy_result(method, x, missing, false, trace, monitor, :limit, 0, 0, 0, 0, 0)
    end
    g_work = _working_gradient_penalty(g, eltype(x))
    state = initial_state(method, options, f, g_work, x, Val(use_stationarity && !mapping_supported))
    if use_stationarity
        provider = if mapping_supported
            ProximalGradientMappingProvider{typeof(f),typeof(g_work),eltype(x)}(f, g_work, -1, nothing, 0)
        else
            _gradient_stationarity_provider(method, f, g_work)
        end
        monitor = Stopping.with_stationarity(monitor, provider)
    end
    if gap_level !== nothing
        data = leastsquares_data(f)
        monitor = Stopping.with_gap(monitor, DualGapProvider(data.X, data.Y, gap_level, nothing, 0))
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
_gradient_decision_after_trace(::Stopping.Monitor, previous, assessment, state, g, options, t0,
                               iteration, stopped_by_callback) = assessment

function _gradient_result(monitor::Stopping.Monitor, decision, state, method, options, trace, iteration)
    point = decision.point
    increased = point.objective > point.previous_objective
    _gradient_policy_result(method, state.x, point.objective, increased, trace, monitor,
                            decision.reason, iteration, state.f_calls, state.grad_calls,
                            state.prox_calls, state.backtrack_steps)
end
