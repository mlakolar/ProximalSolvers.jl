struct NumericalFailure <: Exception
    reason::Symbol
end

same_bits(x::Vector{T}, y::Vector{T}) where T =
    reinterpret(UInt8, x) == reinterpret(UInt8, y)

mutable struct Audit{T}
    alternate::Vector{T}
    trial_hash::SHA.SHA2_256_CTX
    mapping_hash::SHA.SHA2_256_CTX
    trials::Int
    mappings::Int
    nonfinite_fused::Int
    last::Vector{T}
    max_accepted_violation::BigFloat
    accepted_exterior::Int
    trace::Vector{NamedTuple}
end

Audit(x::Vector{T}) where T =
    Audit(similar(x), SHA.SHA2_256_CTX(), SHA.SHA2_256_CTX(), 0, 0, 0, copy(x), BigFloat(0), 0, NamedTuple[])

function record_bits!(a, x, y, step, kind)
    ctx = if kind === :trial
        a.trials += 1
        a.trial_hash
    else
        a.mappings += 1
        a.mapping_hash
    end
    SHA.update!(ctx, reinterpret(UInt8, x))
    SHA.update!(ctx, reinterpret(UInt8, [step]))
    SHA.update!(ctx, reinterpret(UInt8, y))
end

function apply_projection!(y, g, x, step, ::Nothing, kind)
    PB.prox!(y, g, x, step)
end

function apply_projection!(y, g, x, step, a::Audit, kind)
    PB.prox!(y, g, x, step)
    v = PB.value_and_prox!(a.alternate, g, x, step)
    @assert same_bits(y, a.alternate) && isequal(v, g(y))
    a.nonfinite_fused += !isfinite(v)
    record_bits!(a, x, y, step, kind)
    y
end

function accepted!(a::Audit, x, g, row)
    copyto!(a.last, x)
    signed = big_norm(g, BigFloat.(x)) - BigFloat(g.r)
    a.max_accepted_violation = max(a.max_accepted_violation, signed)
    a.accepted_exterior += signed > 0
    push!(a.trace, (; row..., violation=Float64(max(0, signed))))
    false
end
accepted!(::Nothing, x, g, row) = false

# Strict A with a read-only instrumentation layer on the oracle. This type
# takes the same generic PS stationarity method as each underlying ball.
struct StrictAudit{G,A,X}
    ball::G
    audit::A
    current::X
end
(g::StrictAudit)(x) = g.ball(x)
function PB.value_and_prox!(y, g::StrictAudit, x, step)
    v = PB.value_and_prox!(y, g.ball, x, step)
    a = g.audit
    PB.prox!(a.alternate, g.ball, x, step)
    @assert same_bits(y, a.alternate) && isequal(v, g.ball(y))
    a.nonfinite_fused += !isfinite(v)
    record_bits!(a, x, y, step, y === g.current ? :trial : :mapping)
    v
end

name(::PS.ProximalGradientDescent) = :PGD
name(::PS.AccProxGradDescent) = :APG
method_kind(::PS.ProximalGradientDescent) = :pgd
method_kind(::PS.AccProxGradDescent) = :gradient

function methods(d)
    alpha = startswith(d.name, "l2_1036_") ? 1.0 : 0.9
    (PS.ProximalGradientDescent(; ls=PS.LineSearches.BackTracking(; α=alpha)),
     PS.AccProxGradDescent(; α=alpha))
end

# Invoke the regular dimension, type, finiteness and alias validation with an
# admissible placeholder penalty. Apply the actual ball restriction separately.
function check_ball_problem(x::Vector{T}, f, g, method) where T
    PS._check_problem(x, f, PB.NormL1(zero(T)), method_kind(method))
    g.r isa T && isfinite(g.r) && g.r > 0 || throw(ArgumentError("need a finite positive radius in T"))
    if method isa PS.AccProxGradDescent
        PS._check_method(method, T)
        PS._check_bound_size(f, x)
    end
end

function strict_result(state, result, x, stats, status, error="")
    have_result = result !== nothing
    smooth = isempty(stats.trace) && !have_result ? NaN :
             have_result ? Float64(state.f_x) : stats.trace[end].smooth
    composite = have_result ? Float64(result.minimum) :
                isempty(stats.trace) ? NaN : stats.trace[end].monitor
    n = have_result ? result.iterations : length(stats.trace)
    trial_count = have_result && state !== nothing && stats.trials == 0 ?
                  missing : stats.trials
    (; x, status, error, completed=have_result, success=have_result && result.converged,
       converged=have_result && result.converged, iterations=n,
       gradients=state === nothing ? 0 : state.grad_calls, values=state === nothing ? 0 : state.f_calls,
       projections=state === nothing ? 0 : state.prox_calls, trials=trial_count, rejected=ismissing(trial_count) ?
       missing : trial_count-n, restarts=state isa PS.AccProxGradDescentState ? state.restarts : 0,
       backtracks=state === nothing ? 0 : state.backtrack_steps,
       gap=NaN, gap_noise=NaN, mapping=NaN, map_noise=NaN, b_work_margin=NaN, membership=:pb_rounded,
       cap_refines=0, stop_refines=0, stop_checks=stats.mappings,
       feasibility_rejects=0, unresolved_rejects=0, smooth, composite,
       residual=have_result ? result.f_residual : NaN,
       increased=have_result && result.f_increased,
       native_residual=have_result ? result.g_residual : NaN, trial_writes=stats.trials)
end

function strict_control(d, f, g, method, a::Audit; profile=:ordinary, maxiter=320)
    x = copy(d.start)
    state, result = nothing, nothing
    status, detail = :unknown, ""
    trial = StrictAudit(g, a, x)
    function trace(row)
        accepted!(a, x, g, (; iteration=row.iteration, monitor=Float64(row.fg_x),
                  smooth=Float64(state.f_x), L=Float64(row.L)))
    end
    options = strict_options(d, profile, maxiter; callback=trace)
    try
        check_ball_problem(x, f, g, method)
        iszero(g(x)) || throw(ArgumentError("strict research control requires PB membership at start"))
        state = PS.initial_state(method, options, f, trial, x)
        result = PS._solve_gradient!(state, f, trial, method, options)
        status = result.converged ? :converged : result.stagnated ? :stagnated : :iteration_limit
    catch e
        expected = e isa ArgumentError || (e isa ErrorException &&
                   (startswith(e.msg, "line search failed") || occursin("finite objective", e.msg)))
        expected || rethrow()
        status = state === nothing ? :start_refused : startswith(sprint(showerror, e), "line search") ?
                 :line_search_error : :nonfinite_composite
        detail = sprint(showerror, e)
        @assert same_bits(x, a.last)
    end
    strict_result(state, result, x, a, status, detail)
end

function strict_options(d, profile, maxiter; callback=nothing)
    a = accuracy(d, profile)
    # Feed requested scales to the unmodified control, which retains STOP-01
    # and its own stationarity floor and relative scales.
    PS.ProximalOptions(; maxiter, allow_f_increases=true, ftol=a.objective_relative,
                       xtol=a.mapping_relative, gradtol=a.mapping_relative, callback)
end

function public_control(d, f, g, method; profile=:ordinary, maxiter=320)
    x = copy(d.start)
    try
        r = PS.solve!(x, f, g, method, strict_options(d, profile, maxiter))
        (; x, status=r.converged ? :converged : :nonconvergence, error="", result=r)
    catch e
        e isa Union{ArgumentError,ErrorException} || rethrow()
        (; x, status=e isa ArgumentError ? :refused : :failure, error=sprint(showerror,e), result=nothing)
    end
end

# Uninstrumented end-to-end control. The supported p=4 geometry enters
# through the public function, and unsupported geometries bypass its gate.
function native_A(d, f, g, method; profile=:ordinary, maxiter=320)
    if g isa L2 && length(d.start) == 4
        return public_control(d, f, g, method; profile, maxiter)
    end
    x = copy(d.start)
    opts = strict_options(d, profile, maxiter)
    try
        check_ball_problem(x, f, g, method)
        iszero(g(x)) || throw(ArgumentError("strict research control requires PB membership at start"))
        s = PS.initial_state(method, opts, f, g, x)
        r = PS._solve_gradient!(s, f, g, method, opts)
        (; x, status=r.converged ? :converged : :nonconvergence, error="", result=r)
    catch e
        e isa Union{ArgumentError,ErrorException} || rethrow()
        (; x, status=e isa ArgumentError ? :refused : :failure, error=sprint(showerror,e), result=nothing)
    end
end

mutable struct PolicyCounts
    trials::Int
    infeasible::Int
    unresolved::Int
    trial_refines::Int
    stop_refines::Int
    stop_checks::Int
    mappings::Int
end
PolicyCounts() = PolicyCounts(0, 0, 0, 0, 0, 0, 0)

function trial_value!(s, f, g, arm, cap, c, audit)
    PS._allfinite(s.xhat) || return eltype(s.x)(Inf)
    apply_projection!(s.x, g, s.xhat, one(s.L)/s.L, audit, :trial)
    s.prox_calls += 1
    c.trials += 1
    test = decision(arm, s.x, g, cap)
    c.trial_refines += test.refined
    c.infeasible += test.code === :over
    c.unresolved += test.code === :unresolved
    test.code === :pass || return eltype(s.x)(Inf)
    s.f_calls += 1
    PS._value!(s.x, f, s.model, s.z_x)
end

function step!(s::PS.ProximalGradientDescentState, f, g, m, arm, cap, c, audit)
    copyto!(s.x_previous, s.x)
    s.f_x_previous = s.f_x
    copyto!(s.grad_f_x_previous, s.grad_f_x)
    s.L *= m.ls.α
    s.verified_rejection = false
    for _ in 1:64
        PS._step!(s.xhat, s.x_previous, s.grad_f_x_previous, s.L)
        s.f_x = trial_value!(s, f, g, arm, cap, c, audit)
        # The production PGD line search compares smooth values and scores.
        # A rejected feasibility trial enters the nonfinite-trial retry branch.
        if PS.LineSearches.backtrack!(s, m.ls, f, g)
            if !PS.LineSearches.has_updated_gradient(s, m.ls)
                PS.LineSearches.value_and_gradient_at_x!(s, f)
                s.f_calls += 1
                s.grad_calls += 1
            end
            PS._allfinite(s.grad_f_x) || throw(NumericalFailure(:nonfinite_gradient))
            return
        end
    end
    throw(NumericalFailure(:trial_limit))
end

function accelerated_trial!(s::PS.AccProxGradDescentState{T}, f, g, beta, arm, cap, c, audit) where T
    f_y = PS._value_and_gradient!(s.grad_f_y, s.y, f, s.z_y, s.dz)
    s.f_calls += 1
    s.grad_calls += 1
    isfinite(f_y) && PS._allfinite(s.grad_f_y) || return false
    for _ in 1:64
        PS._step!(s.xhat, s.y, s.grad_f_y, s.L)
        s.f_x = trial_value!(s, f, g, arm, cap, c, audit)
        s.backtrack_steps += 1
        if isfinite(s.f_x)
            PS._sub!(s.xhat, s.x, s.y)
            sd, sx = PS._sumsq2(s.xhat, s.x)
            nx = PS._se_norm_onepass(T, sx, s.x)
            D = PS._se_norm_onepass(T, sd, s.xhat)
            if nx !== nothing && D !== nothing
                if iszero(D.s)
                    s.normx = nx
                    return true
                end
                ok, fresh = PS._bound_certified!(s.dz, s.model, s.z_y, s.z_x, s.xhat, D, s.L,
                                                 s.image_error_y, nx, s.rootα, s.bound, s.fresh_only)
                s.fallbacks += fresh
                if ok
                    s.normx = nx
                    return true
                end
            end
        end
        s.L = PS.LineSearches.next_curvature(s.L, beta)
    end
    throw(NumericalFailure(:trial_limit))
end

function step!(s::PS.AccProxGradDescentState{T}, f, g, m, arm, cap, c, audit) where T
    omega = T(s.k / (s.k + 3))
    s.L *= T(m.α)
    nx, np = s.normx, s.normx_previous
    s.normx_previous = nx
    s.image_error_y = PS._image_error_bound(s.bound, nx, np, omega > 0)
    PS._extrapolate_point!(s.y, s.x, s.x_previous, omega)
    zx, zp = s.z_x, s.z_previous
    @. s.z_y = zx + omega * (zx - zp)
    copyto!(s.x_previous, s.x)
    s.f_x_previous = s.f_x
    s.z_previous, s.z_x = s.z_x, s.z_previous
    ok = accelerated_trial!(s, f, g, T(m.β), arm, cap, c, audit)
    if omega > 0 && (!ok || s.f_x > s.f_x_previous)
        s.k = 0
        s.restarts += 1
        copyto!(s.y, s.x_previous)
        copyto!(s.z_y, s.z_previous)
        s.image_error_y = PS._image_error_bound(s.bound, nx, np, false)
        ok = accelerated_trial!(s, f, g, T(m.β), arm, cap, c, audit)
    end
    ok || throw(NumericalFailure(:nonfinite_extrapolation))
    s.k += 1
    PS._sub!(s.delta_x, s.x, s.x_previous)
    nothing
end

function projected_policy(arm, d, f, g, method, b, a::Accuracy, audit=nothing;
                          maxiter=320, callback=nothing, fault_after=0)
    T = eltype(d.start)
    x = copy(d.start)
    state = nothing
    c = PolicyCounts()
    n, identical = 0, 0
    gap = gap_noise = mapping = map_noise = NaN
    status, detail = :iteration_limit, ""
    smooth = residual = NaN
    increased = false
    check = (; code=:unresolved, membership=:unknown, margin=NaN, refined=false)
    success = false
    last_limited = false
    checked_iter = -1
    try
        check_ball_problem(x, f, g, method)
        all(isfinite, (b.cap, b.gap, b.mapping, b.curvature)) &&
            isfinite(T(b.curvature)) && T(b.curvature) > 0 ||
            throw(NumericalFailure(:unrepresentable_budget))
        check = decision(arm, x, g, b.cap)
        c.trial_refines += check.refined
        if check.code !== :pass
            throw(NumericalFailure(check.code === :over ? :start_refused : :start_unresolved))
        end
        # initial_state needs a g argument. B/C leave the unused composite
        # state field as NaN and use their own stopping, trace and result.
        state = PS.initial_state(method, nothing, f, _ -> T(NaN), x)
        smooth = Float64(state.f_x)
        work = StopWorkspace(d)
        for it in 1:maxiter
            try
                step!(state, f, g, method, arm, b.cap, c, audit)
                # Controlled failure after a candidate was produced, before commitment.
                it == fault_after && throw(NumericalFailure(:injected_trial_failure))
            catch
                PS._rollback_gradient_step!(state)
                rethrow()
            end
            n = it
            smooth = Float64(state.f_x)
            residual = PS.f_residual(state.f_x, state.f_x_previous, a.objective_relative)
            increased = state.f_x > state.f_x_previous
            identical = PS._unchanged(x, state.x_previous) ? identical + 1 : 0
            dx = maximum(abs, state.delta_x)
            # Progress tests propose checks. Only feasibility and accepted-point
            # stationarity can authorize success.
            proposed = n == maxiter || dx <= sqrt(a.mapping_relative) * maximum(abs, x) ||
                       residual <= a.objective_relative || identical > 0
            if proposed
                c.stop_checks += 1
                check = decision(arm, x, g, b.cap; stop=true)
                checked_iter = n
                c.stop_refines += check.refined
                if check.code === :pass
                    scores = stop_scores!(work, x, d, g, b, audit)
                    c.mappings += 1
                    gap, gap_noise, mapping, map_noise = scores.gap, scores.gap_noise, scores.mapping, scores.map_noise
                    success, last_limited = scores.pass, scores.limited
                else
                    last_limited = true
                end
            end
            composite = proposed && check.membership === :inside ? smooth :
                        proposed && check.membership === :outside ? Inf : missing
            row = (; iteration=n, monitor=smooth, smooth, composite, residual, increased, L=Float64(state.L))
            accepted!(audit, x, g, row)
            stop_requested = callback !== nothing && callback(row)
            if success
                status = check.membership === :inside ? :converged : :approximate_solution
                break
            elseif stop_requested
                status = :callback_stop
                break
            elseif identical >= 4
                status = :numerical_stagnation
                break
            elseif it == maxiter && last_limited
                status = :numerical_resolution
            end
        end
    catch e
        if e isa NumericalFailure
            status = e.reason
        elseif e isa ArgumentError && state === nothing
            status = :start_refused
        elseif e isa ErrorException && startswith(e.msg, "line search failed")
            status = :line_search_error
        else
            rethrow()
        end
        detail = e isa NumericalFailure ? string(status) : sprint(showerror,e)
        audit === nothing || @assert same_bits(x, audit.last)
    end
    final_check = checked_iter == n ? check : decision(arm, x, g, b.cap; stop=true)
    decoded = final_check.membership
    composite = decoded === :outside ? Inf : decoded === :inside ? smooth : missing
    line_failed = status in (:trial_limit, :line_search_error, :injected_trial_failure, :nonfinite_gradient, :nonfinite_extrapolation)
    (; x, status, error=detail, completed=state !== nothing && !line_failed, success,
       converged=success && decoded === :inside, iterations=n,
       gradients=(state === nothing ? 0 : state.grad_calls)+c.mappings,
       values=state === nothing ? 0 : state.f_calls,
       projections=(state === nothing ? 0 : state.prox_calls)+c.mappings,
       trials=c.trials, rejected=c.trials-n,
       restarts=state isa PS.AccProxGradDescentState ? state.restarts : 0,
       backtracks=state === nothing ? 0 : state.backtrack_steps,
       gap, gap_noise, mapping, map_noise, b_work_margin=final_check.margin, membership=decoded,
       cap_refines=c.trial_refines, stop_refines=c.stop_refines + (checked_iter != n && final_check.refined), stop_checks=c.stop_checks,
       feasibility_rejects=c.infeasible, unresolved_rejects=c.unresolved,
       smooth, composite, residual, increased, native_residual=NaN, trial_writes=c.trials)
end
