"""
    ProximalSolvers.Stopping

Explicit stopping conditions, composition and iteration limits for the dense
vector least-squares PGD pilot. Pass conditions as `stopping` and the iteration
budget as `limits` to [`solve!`](@ref ProximalSolvers.solve!).
"""
module Stopping

export IterateChange, ObjectiveChange, UserStop, AnyOf, AllOf, MaxIterations, termination

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
accepted iterates. Two zero tolerances select equality of the computed
objectives. See [STOP-22](@ref) for the scale and arithmetic.
"""
struct ObjectiveChange
    atol::Float64
    rtol::Float64
    ObjectiveChange(; atol::Real=0.0, rtol::Real=0.0) =
        new(tolerance(atol, "atol"), tolerance(rtol, "rtol"))
end

"""
    UserStop(predicate)

Stop when `predicate(context)` returns `true`. The immutable context has
`iteration` and `objective` fields and is available from the initial point.
See [STOP-22](@ref) for evaluation order and budget ties.
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

bind_rule(rule, context) = throw(ArgumentError("unsupported stopping condition $(typeof(rule))"))
bind_rule(rule::Union{IterateChange,ObjectiveChange}, context) = RuleState(rule)
function bind_rule(rule::UserStop, context)
    applicable(rule.predicate, context) || throw(ArgumentError("UserStop needs a predicate callable with the stopping context"))
    RuleState(rule)
end
bind_rule(rule::AnyOf, context) = AnyOf(map(child -> bind_rule(child, context), rule.rules)...)
bind_rule(rule::AllOf, context) = AllOf(map(child -> bind_rule(child, context), rule.rules)...)

# A checkpoint supplies objective history from the solver. Movement is shared
# lazily across leaves, and both slots expire before the next decision.
mutable struct MovementCache
    distance::Union{Nothing,Float64}
    scale::Union{Nothing,Float64}
    unchanged::Union{Nothing,Bool}
end

struct Monitor{R}
    root::R
    limit::MaxIterations
    movement::MovementCache
end

user_context(k, objective) = (; iteration=k, objective)
prepare(rule, limit::MaxIterations, ::Type{T}) where {T} =
    Monitor(rule === nothing ? nothing : bind_rule(rule, user_context(0, zero(T))),
            limit, MovementCache(nothing, nothing, nothing))

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

function assess(rule::IterateChange, point, cache, at_limit)
    (point.iteration == 0 || at_limit) && return unchecked
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

function assess(rule::ObjectiveChange, point, cache, at_limit)
    point.iteration == 0 && return unchecked
    if stored_zero(rule.atol) && stored_zero(rule.rtol)
        return boolean_observation(stored_equal(point.objective, point.previous_objective))
    end
    current, previous = Float64(point.objective), Float64(point.previous_objective)
    atmost(abs(current - previous), rule.atol, rule.rtol, max(abs(current), abs(previous)))
end

function assess(rule::UserStop, point, cache, at_limit)
    at_limit && return unchecked
    pass = rule.predicate(user_context(point.iteration, point.objective))
    pass isa Bool || throw(ArgumentError("UserStop predicate must return Bool"))
    boolean_observation(pass)
end

evidence(::Union{IterateChange,ObjectiveChange}) = :progress
evidence(::UserStop) = :user

evaluate!(::Nothing, point, cache, at_limit) = :continue
function evaluate!(state::RuleState, point, cache, at_limit)
    observation = assess(state.rule, point, cache, at_limit)
    state.iteration = point.iteration
    state.observation = observation
    observation.status === :pass || return :continue
    evidence(state.rule) === :user ? :user : :rule
end

any_pass!(::Tuple{}, point, cache, at_limit) = :continue
function any_pass!(rules::Tuple, point, cache, at_limit)
    reason = evaluate!(first(rules), point, cache, at_limit)
    reason === :continue ? any_pass!(Base.tail(rules), point, cache, at_limit) : reason
end

all_pass!(::Tuple{}, point, cache, at_limit, reason) = reason
function all_pass!(rules::Tuple, point, cache, at_limit, reason)
    child_reason = evaluate!(first(rules), point, cache, at_limit)
    child_reason === :continue && return :continue
    all_pass!(Base.tail(rules), point, cache, at_limit, child_reason === :rule ? :rule : reason)
end

evaluate!(tree::AnyOf, point, cache, at_limit) = any_pass!(tree.rules, point, cache, at_limit)
evaluate!(tree::AllOf, point, cache, at_limit) = all_pass!(tree.rules, point, cache, at_limit, :user)

function check!(monitor, point)
    monitor.movement.distance = nothing
    monitor.movement.scale = nothing
    monitor.movement.unchanged = nothing
    at_limit = point.iteration == monitor.limit.n
    reason = evaluate!(monitor.root, point, monitor.movement, at_limit)
    reason === :continue && at_limit ? :limit : reason
end

observation_at(state, k) = state.iteration == k ? state.observation : unchecked
passed(state::RuleState, k) = observation_at(state, k).status === :pass
passed(tree::AnyOf, k) = any(child -> passed(child, k), tree.rules)
passed(tree::AllOf, k) = all(child -> passed(child, k), tree.rules)

observations(::Nothing, k, path) = ()
function observations(state::RuleState, k, path)
    o = observation_at(state, k)
    ((; path, name=nameof(typeof(state.rule)), evidence=evidence(state.rule),
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
checkpoint observations and work counts. See [RES-04](@ref).
"""
function termination end

end
