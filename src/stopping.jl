"""
    ProximalSolvers.Stopping

Explicit stopping conditions, composition and budgets for supported dense-vector solves.
Pass conditions as `stopping` and work budgets as `limits`
to [`solve!`](@ref ProximalSolvers.solve!).
See [STOP-22](@ref) for PGD and APG stopping and [STOP-23](@ref) and
[STOP-24](@ref) for their evaluation budgets. See [CD-10](@ref) for
coordinate descent and [ADM-06](@ref) for consensus ADMM.
"""
module Stopping

export IterateChange, ObjectiveChange, ScaledKKT, UserStop, AnyOf, AllOf, MaxIterations, MaxPasses, termination
export Every
export MaxCoordinateVisits
export PrimalResidual, DualResidual
export MaxObjectiveEvaluations, MaxGradientEvaluations, MaxProximalEvaluations

# The integer call boundary keeps scalar comparisons valid when the thread
# flushes subnormals and the compiler recognizes a floating-point zero test.
bit_type(::Type{Float16}) = UInt16
bit_type(::Type{Float32}) = UInt32
bit_type(::Type{Float64}) = UInt64
equal_bits(a, b) = a == b || iszero((a | b) << 1)
@noinline scalar_equal_bits(a, b) = equal_bits(a, b)
stored_equal(a::T, b::T) where {T} = scalar_equal_bits(reinterpret(bit_type(T), a), reinterpret(bit_type(T), b))

stored_zero(value::Real) = iszero(value)
stored_zero(value::Union{Float16,Float32,Float64}) = stored_equal(value, zero(value))

function tolerance(value::Real, name)
    converted = Float64(value)
    exact_zero = stored_zero(value)
    isfinite(value) && (exact_zero || !signbit(value)) && isfinite(converted) &&
        (exact_zero || !stored_zero(converted)) ||
        throw(ArgumentError("$name must be finite, nonnegative and representable in Float64 without rounding to zero"))
    exact_zero ? 0.0 : converted
end

"""
    IterateChange(; atol=0.0, rtol=0.0)

Check the Euclidean displacement between successive accepted iterates against
an absolute plus relative tolerance. Two zero tolerances select elementwise
equality. The exact comparison and scale are specified in [STOP-22](@ref).
"""
struct IterateChange
    atol::Float64
    rtol::Float64
    IterateChange(; atol::Real=0.0, rtol::Real=0.0) =
        new(tolerance(atol, "atol"), tolerance(rtol, "rtol"))
end

"""
    ObjectiveChange(; atol=0.0, rtol=0.0)

Check the absolute change in the original composite objective between successive
accepted iterates for PGD and APG, or successive completed full sweeps for
coordinate descent. The first full sweep has no predecessor, and the rule is
unchecked on active sweeps. Two zero tolerances select equality of the computed
objectives. See [STOP-22](@ref) for the scale and arithmetic and [CD-10](@ref)
for coordinate-descent checkpoints.
"""
struct ObjectiveChange
    atol::Float64
    rtol::Float64
    ObjectiveChange(; atol::Real=0.0, rtol::Real=0.0) =
        new(tolerance(atol, "atol"), tolerance(rtol, "rtol"))
end

"""
    ScaledKKT(; rtol)

Check coordinatewise stationarity at the current point using the relative
tolerance in [STOP-21](@ref). Supported for dense vector least-squares PGD and APG with
`NormL1` or `ElasticNet`, with or without weights. For scalar least-squares
coordinate descent with unweighted `NormL1` and momentum off, see [CD-12](@ref).
"""
struct ScaledKKT
    rtol::Float64
    ScaledKKT(; rtol::Real) = new(tolerance(rtol, "rtol"))
end

"""
    Every(k, rule::ScaledKKT)

Make a `ScaledKKT` check eligible at the starting point and after every `k`
accepted updates in supported PGD and APG solves. Use a positive integer `k`
representable as `Int`. At other checkpoints the leaf is unchecked.
See [STOP-25](@ref) for scheduling, composition and limits.
"""
struct Every
    interval::Int
    rule::ScaledKKT
    function Every(k, rule)
        k isa Integer && 0 < k <= typemax(Int) ||
            throw(ArgumentError("the check interval must be a positive Int"))
        rule isa ScaledKKT || throw(ArgumentError("Every requires a ScaledKKT condition"))
        new(Int(k), rule)
    end
end

"""
    PrimalResidual()

Check the computed primal residual against the current `ADMMSolver` primal
threshold after a completed iteration. See [ADM-06](@ref).
"""
struct PrimalResidual end

"""
    DualResidual()

Check the computed dual residual against the current `ADMMSolver` dual
threshold after a completed iteration. See [ADM-06](@ref).
"""
struct DualResidual end

"""
    UserStop(predicate)

Stop when `predicate(context)` returns `true`. The immutable context has
`iteration` and `objective` fields and is available from the initial point.
For coordinate descent, `iteration` counts completed passes.
Both full and active passes supply checkpoints before the cap.
See [STOP-22](@ref) and [CD-10](@ref) for evaluation order and budget ties.
"""
struct UserStop{F}
    predicate::F
end

"""
    AnyOf(rule, rules...)

Check conditions in order and stop at the first passing child. Conditions
can themselves be composed with `AnyOf` or [`AllOf`](@ref).
"""
struct AnyOf{R<:Tuple}
    rules::R
    AnyOf(rule, rules...) = new{typeof((rule, rules...))}((rule, rules...))
end

"""
    AllOf(rule, rules...)

Require each child condition to pass at the same accepted point.
"""
struct AllOf{R<:Tuple}
    rules::R
    AllOf(rule, rules...) = new{typeof((rule, rules...))}((rule, rules...))
end

"""
    MaxIterations(n)

Hard limit of `n` accepted iterations, with `n` a nonnegative integer.
Supply this limit through `limits=MaxIterations(n)`.
"""
struct MaxIterations
    n::Int
    function MaxIterations(n::Integer)
        0 <= n <= typemax(Int) || throw(ArgumentError("the iteration limit must be a nonnegative Int"))
        new(Int(n))
    end
end

"""
    MaxObjectiveEvaluations(n)

Hard limit of `n` smooth loss values for dense vector least-squares PGD and APG.
A fused loss and gradient evaluation uses one unit. Pass the limit through
`limits`, alone or in a tuple of distinct limits. See [STOP-23](@ref) and [STOP-24](@ref).
"""
struct MaxObjectiveEvaluations
    n::Int
    MaxObjectiveEvaluations(n::Integer) = new(evaluation_capacity(n))
end

"""
    MaxGradientEvaluations(n)

Hard limit of `n` full smooth gradients for dense vector least-squares PGD and APG.
Pass the limit through `limits`, alone or in a tuple of distinct limits.
See [STOP-23](@ref) and [STOP-24](@ref).
"""
struct MaxGradientEvaluations
    n::Int
    MaxGradientEvaluations(n::Integer) = new(evaluation_capacity(n))
end

"""
    MaxProximalEvaluations(n)

Hard limit of `n` proximal calls. Dense vector least-squares PGD and APG count
penalty proximal calls. Fixed-penalty centered consensus ADMM admits whole
iterations that use two proximal calls each.
Pass the limit through `limits`, alone or in a tuple of distinct limits.
See [STOP-23](@ref), [STOP-24](@ref) and [ADM-07](@ref).
"""
struct MaxProximalEvaluations
    n::Int
    MaxProximalEvaluations(n::Integer) = new(evaluation_capacity(n))
end

function evaluation_capacity(n)
    0 <= n <= typemax(Int) || throw(ArgumentError("the evaluation limit must be a nonnegative Int"))
    Int(n)
end

const EvaluationLimit = Union{MaxObjectiveEvaluations,MaxGradientEvaluations,MaxProximalEvaluations}
evaluation_limit_reached(limit::MaxObjectiveEvaluations, counts) = counts.f_calls >= limit.n
evaluation_limit_reached(limit::MaxGradientEvaluations, counts) = counts.grad_calls >= limit.n
evaluation_limit_reached(limit::MaxProximalEvaluations, counts) = counts.prox_calls >= limit.n
evaluation_limit_reached(limits::Tuple, counts) = any(l -> evaluation_limit_reached(l, counts), limits)

"""
    MaxPasses(n)

Hard limit of `n` completed coordinate passes, with `n` a nonnegative integer.
Supply this limit through `limits=MaxPasses(n)` to [`CDSolver`](@ref ProximalSolvers.CDSolver).
"""
struct MaxPasses
    n::Int
    function MaxPasses(n::Integer)
        0 <= n <= typemax(Int) || throw(ArgumentError("the pass limit must be a nonnegative Int"))
        new(Int(n))
    end
end

"""
    MaxCoordinateVisits(n)

Hard limit of `n` coordinate visits for explicit scalar least-squares coordinate
descent, with `n` a nonnegative integer. CD starts a sweep only if all its visits
fit. Pass the limit through `limits`, alone or in a tuple with `MaxPasses`.
See [CD-11](@ref).
"""
struct MaxCoordinateVisits
    n::Int
    function MaxCoordinateVisits(n::Integer)
        0 <= n <= typemax(Int) || throw(ArgumentError("the coordinate visit limit must be a nonnegative Int"))
        new(Int(n))
    end
end

struct Observation
    status::Symbol
    value::Union{Missing,Float64,Bool}
    threshold::Union{Missing,Float64,Bool}
    scale::Union{Missing,Float64}
end

const unchecked = Observation(:not_checked, missing, missing, missing)

# Each bound leaf stores its latest observation. Its iteration stamp makes a
# leaf skipped by a short circuit unavailable at the current checkpoint.
mutable struct RuleState{R}
    rule::R
    iteration::Int
    observation::Observation
    RuleState(rule::R) where R = new{R}(rule, -1, unchecked)
end

const GradientLeaves = Union{IterateChange,ObjectiveChange,ScaledKKT,Every,UserStop}
const ResidualLeaves = Union{PrimalResidual,DualResidual}

function bind_rule(rule, context, supported)
    rule isa supported || throw(ArgumentError("unsupported stopping condition $(typeof(rule))"))
    bind_leaf(rule, context)
end
bind_rule(rule::AnyOf, context, supported) =
    AnyOf(map(child -> bind_rule(child, context, supported), rule.rules)...)
bind_rule(rule::AllOf, context, supported) =
    AllOf(map(child -> bind_rule(child, context, supported), rule.rules)...)

bind_leaf(rule, context) = RuleState(rule)
function bind_leaf(rule::UserStop, context)
    applicable(rule.predicate, context) || throw(ArgumentError("UserStop needs a predicate callable with the stopping context"))
    RuleState(rule)
end

# A checkpoint supplies objective history from the solver. Movement is shared
# lazily across leaves, and both slots expire before the next decision.
mutable struct MovementCache
    distance::Union{Nothing,Float64}
    scale::Union{Nothing,Float64}
    unchanged::Union{Nothing,Bool}
end

mutable struct StationarityCache{F}
    provider::F
    iteration::Int
    decisions::Dict{UInt64,Bool}
end

struct Monitor{R,S,L,E}
    root::R
    limit::L
    movement::MovementCache
    stationarity::S
    evaluation_limits::E
end

user_context(k, objective) = (; iteration=k, objective)
prepare(rule, limit::Union{MaxIterations,MaxPasses}, ::Type{T}, supported=GradientLeaves;
        evaluation_limits=()) where {T} =
    Monitor(rule === nothing ? nothing : bind_rule(rule, user_context(0, zero(T)), supported),
            limit, MovementCache(nothing, nothing, nothing), nothing, evaluation_limits)

needs_stationarity(monitor::Monitor) = needs_stationarity(monitor.root)
needs_stationarity(::Union{Nothing,RuleState}) = false
needs_stationarity(::RuleState{<:Union{ScaledKKT,Every}}) = true
needs_stationarity(tree::Union{AnyOf,AllOf}) = any(needs_stationarity, tree.rules)

with_stationarity(monitor, provider) =
    Monitor(monitor.root, monitor.limit, monitor.movement,
            StationarityCache(provider, -1, Dict{UInt64,Bool}()), monitor.evaluation_limits)

function stationarity!(cache::StationarityCache, point, rtol::Float64)
    if cache.iteration != point.iteration
        empty!(cache.decisions)
        cache.iteration = point.iteration
    end
    # The key is the stored tolerance, even when the thread flushes subnormals.
    get!(cache.decisions, reinterpret(UInt64, rtol)) do
        cache.provider(point, rtol)
    end
end

function movement_distance end
function movement_scale end
function same_iterate end

@inline function atmost(value, atol, rtol, scale)
    threshold = stored_zero(rtol) ? atol : fma(rtol, scale, atol)
    status = if !isfinite(value) || !isfinite(threshold)
        :invalid
    else
        value <= threshold ? :pass : :fail
    end
    Observation(status, value, threshold, scale)
end

boolean_observation(pass::Bool) = Observation(pass ? :pass : :fail, pass, true, missing)

function assess(rule::IterateChange, point, monitor, at_limit)
    (point.iteration == 0 || at_limit) && return unchecked
    cache = monitor.movement
    if stored_zero(rule.atol) && stored_zero(rule.rtol)
        equal = cache.unchanged
        equal === nothing && (cache.unchanged = equal = same_iterate(point))
        return boolean_observation(equal)
    end
    value = cache.distance
    value === nothing && (cache.distance = value = movement_distance(point))
    stored_zero(rule.rtol) && return atmost(value, rule.atol, rule.rtol, missing)
    scale = cache.scale
    scale === nothing && (cache.scale = scale = movement_scale(point))
    atmost(value, rule.atol, rule.rtol, scale)
end

function assess(rule::ObjectiveChange, point, monitor, at_limit)
    point.iteration == 0 && return unchecked
    previous = point.previous_objective
    previous === nothing && return unchecked
    if stored_zero(rule.atol) && stored_zero(rule.rtol)
        return boolean_observation(stored_equal(point.objective, previous))
    end
    current, previous = Float64(point.objective), Float64(previous)
    atmost(abs(current - previous), rule.atol, rule.rtol, max(abs(current), abs(previous)))
end

stationarity_eligible(provider, point) = true

function assess(rule::ScaledKKT, point, monitor, at_limit)
    cache = monitor.stationarity
    stationarity_eligible(cache.provider, point) || return unchecked
    if at_limit
        cache.iteration == point.iteration || return unchecked
        decision = get(cache.decisions, reinterpret(UInt64, rule.rtol), nothing)
        return decision === nothing ? unchecked : boolean_observation(decision)
    end
    boolean_observation(stationarity!(cache, point, rule.rtol))
end

function assess(rule::Every, point, monitor, at_limit)
    iszero(point.iteration % rule.interval) || return unchecked
    assess(rule.rule, point, monitor, at_limit)
end

function assess(rule::UserStop, point, monitor, at_limit)
    at_limit && return unchecked
    pass = rule.predicate(user_context(point.iteration, point.objective))
    pass isa Bool || throw(ArgumentError("UserStop predicate must return Bool"))
    boolean_observation(pass)
end

residual_observation(value, threshold) =
    Observation(value <= threshold ? :pass : :fail, Float64(value), Float64(threshold), missing)
assess(::PrimalResidual, point, monitor, at_limit) = residual_observation(point.r_norm, point.eps_pri)
assess(::DualResidual, point, monitor, at_limit) = residual_observation(point.s_norm, point.eps_dual)

evidence(::Union{IterateChange,ObjectiveChange}) = :progress
evidence(::Union{ScaledKKT,Every}) = :stationarity
evidence(::UserStop) = :user
evidence(::ResidualLeaves) = :residual

checkpoint_evaluation_limit_reached(monitor, point) = false

evaluate!(::Nothing, point, monitor, at_limit) = :continue
function evaluate!(state::RuleState, point, monitor, at_limit)
    # An accepted-point APG gradient can exhaust a budget during this checkpoint.
    at_limit = at_limit || checkpoint_evaluation_limit_reached(monitor, point)
    observation = assess(state.rule, point, monitor, at_limit)
    state.iteration = point.iteration
    state.observation = observation
    observation.status === :pass || return :continue
    evidence(state.rule) === :user ? :user : :rule
end

any_pass!(::Tuple{}, point, monitor, at_limit) = :continue
function any_pass!(rules::Tuple, point, monitor, at_limit)
    reason = evaluate!(first(rules), point, monitor, at_limit)
    reason === :continue ? any_pass!(Base.tail(rules), point, monitor, at_limit) : reason
end

all_pass!(::Tuple{}, point, monitor, at_limit, reason) = reason
function all_pass!(rules::Tuple, point, monitor, at_limit, reason)
    child_reason = evaluate!(first(rules), point, monitor, at_limit)
    child_reason === :continue && return :continue
    all_pass!(Base.tail(rules), point, monitor, at_limit, child_reason === :rule ? :rule : reason)
end

evaluate!(tree::AnyOf, point, monitor, at_limit) = any_pass!(tree.rules, point, monitor, at_limit)
evaluate!(tree::AllOf, point, monitor, at_limit) = all_pass!(tree.rules, point, monitor, at_limit, :user)

function check!(monitor, point, additional_limit_reached=false)
    monitor.movement.distance = nothing
    monitor.movement.scale = nothing
    monitor.movement.unchanged = nothing
    at_limit = point.iteration == monitor.limit.n || additional_limit_reached
    reason = evaluate!(monitor.root, point, monitor, at_limit)
    reason === :continue && (at_limit || checkpoint_evaluation_limit_reached(monitor, point)) ? :limit : reason
end

observation_at(state, k) = state.iteration == k ? state.observation : unchecked
passed(state::RuleState, k) = observation_at(state, k).status === :pass
passed(tree::AnyOf, k) = any(child -> passed(child, k), tree.rules)
passed(tree::AllOf, k) = all(child -> passed(child, k), tree.rules)

observations(::Nothing, k, path) = ()
observation_name(rule) = nameof(typeof(rule))
observation_name(rule::Every) = observation_name(rule.rule)

function observations(state::RuleState, k, path)
    o = observation_at(state, k)
    ((; path, name=observation_name(state.rule), evidence=evidence(state.rule),
       o.status, o.value, o.threshold, o.scale),)
end
observations(tree::Union{AnyOf,AllOf}, k, path) =
    (Iterators.flatten(observations(child, k, (path..., i)) for (i, child) in enumerate(tree.rules))...,)

winning_paths(::RuleState, k, path) = (path,)
function winning_paths(tree::AnyOf, k, path)
    i = findfirst(child -> passed(child, k), tree.rules)
    winning_paths(tree.rules[i], k, (path..., i))
end
winning_paths(tree::AllOf, k, path) =
    (Iterators.flatten(winning_paths(child, k, (path..., i)) for (i, child) in enumerate(tree.rules))...,)

function report(monitor, reason, k, counts)
    satisfied = reason in (:rule, :user)
    winning_branch = satisfied ? winning_paths(monitor.root, k, ()) : nothing
    (; reason, satisfied, winning_branch, iteration=k, limit=monitor.limit,
       limit_reached=k == monitor.limit.n, observations=observations(monitor.root, k, ()), counts)
end

"""
    termination(result)

Return the termination record of an explicit-policy solve. The record gives
the reason, policy satisfaction, winning leaf paths, iteration, limit, final
checkpoint observations and work counts. See [RES-04](@ref), [RES-05](@ref),
and [RES-06](@ref).
"""
function termination end

end
