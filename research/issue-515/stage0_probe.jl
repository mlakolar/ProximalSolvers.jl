# Stage-instrumented copy of the #514 B0 driver (arm B, audit = nothing, callback = nothing).
# Each function mirrors the corresponding B0 function in ../issue-514/{policies,stationarity}.jl
# line for line, with disjoint wall-clock stage accumulators added. `stage0.jl` checks that
# the probe returns the same coefficient bits, status and counters as the uninstrumented B0.
# The timers cost roughly 20 ns per stage; the report subtracts the calibrated cost.

const STAGES = (:setup_budgets, :setup_checks, :setup_state, :setup_workspace,
                :pgd_copy, :trial_step, :trial_allfinite, :trial_prox, :trial_decision, :trial_value,
                :pgd_backtrack, :pgd_postgradient,
                :apg_extrapolate, :apg_grad_y, :apg_bound, :apg_restart, :apg_tail,
                :iter_bookkeeping, :row,
                :stop_decision, :stop_witness, :stop_gradient, :stop_noise, :stop_gap,
                :stop_map_trial, :stop_map_project, :stop_map_finish,
                :result)
const NST = length(STAGES)
const ST_NS = zeros(Int, NST)
const ST_N = zeros(Int, NST)
stage_index(s::Symbol) = findfirst(==(s), STAGES)

macro stage(name, ex)
    k = stage_index(name)
    k === nothing && error("unknown stage $name")
    quote
        local t0 = time_ns()
        local v = $(esc(ex))
        @inbounds ST_NS[$k] += Int(time_ns() - t0)
        @inbounds ST_N[$k] += 1
        v
    end
end

reset_stages!() = (fill!(ST_NS, 0); fill!(ST_N, 0))

# Per stop check: whether it passed, which test failed, and the gap ratio.
const STOPLOG = NamedTuple{(:iteration, :pass, :gap_ratio, :map_ratio, :gap_noise_ratio, :map_noise_ratio,
                            :working_gap_ratio), NTuple{7, Float64}}[]

function p_trial_value!(s, f, g, cap, c)
    ok = @stage trial_allfinite PS._allfinite(s.xhat)
    ok || return eltype(s.x)(Inf)
    @stage trial_prox PB.prox!(s.x, g, s.xhat, one(s.L)/s.L)
    s.prox_calls += 1
    c.trials += 1
    test = @stage trial_decision norm_decision(s.x, g, cap)
    c.trial_refines += test.refined
    c.infeasible += test.code === :over
    c.unresolved += test.code === :unresolved
    test.code === :pass || return eltype(s.x)(Inf)
    s.f_calls += 1
    @stage trial_value PS._value!(s.x, f, s.model, s.z_x)
end

function p_step!(s::PS.ProximalGradientDescentState, f, g, m, cap, c)
    @stage pgd_copy begin
        copyto!(s.x_previous, s.x)
        s.f_x_previous = s.f_x
        copyto!(s.grad_f_x_previous, s.grad_f_x)
        s.L *= m.ls.α
        s.verified_rejection = false
    end
    for _ in 1:64
        @stage trial_step PS._step!(s.xhat, s.x_previous, s.grad_f_x_previous, s.L)
        s.f_x = p_trial_value!(s, f, g, cap, c)
        accepted = @stage pgd_backtrack PS.LineSearches.backtrack!(s, m.ls, f, g)
        if accepted
            @stage pgd_postgradient begin
                if !PS.LineSearches.has_updated_gradient(s, m.ls)
                    PS.LineSearches.value_and_gradient_at_x!(s, f)
                    s.f_calls += 1
                    s.grad_calls += 1
                end
                PS._allfinite(s.grad_f_x) || throw(NumericalFailure(:nonfinite_gradient))
            end
            return
        end
    end
    throw(NumericalFailure(:trial_limit))
end

function p_accelerated_trial!(s::PS.AccProxGradDescentState{T}, f, g, beta, cap, c) where T
    f_y = @stage apg_grad_y PS._value_and_gradient!(s.grad_f_y, s.y, f, s.z_y, s.dz)
    s.f_calls += 1
    s.grad_calls += 1
    ok = @stage apg_grad_y (isfinite(f_y) && PS._allfinite(s.grad_f_y))
    ok || return false
    for _ in 1:64
        @stage trial_step PS._step!(s.xhat, s.y, s.grad_f_y, s.L)
        s.f_x = p_trial_value!(s, f, g, cap, c)
        s.backtrack_steps += 1
        if isfinite(s.f_x)
            done = @stage apg_bound begin
                PS._sub!(s.xhat, s.x, s.y)
                sd, sx = PS._sumsq2(s.xhat, s.x)
                nx = PS._se_norm_onepass(T, sx, s.x)
                D = PS._se_norm_onepass(T, sd, s.xhat)
                result = false
                if nx !== nothing && D !== nothing
                    if iszero(D.s)
                        s.normx = nx
                        result = true
                    else
                        ok2, fresh = PS._bound_certified!(s.dz, s.model, s.z_y, s.z_x, s.xhat, D, s.L,
                                                          s.image_error_y, nx, s.rootα, s.bound, s.fresh_only)
                        s.fallbacks += fresh
                        if ok2
                            s.normx = nx
                            result = true
                        end
                    end
                end
                result
            end
            done && return true
        end
        s.L = PS.LineSearches.next_curvature(s.L, beta)
    end
    throw(NumericalFailure(:trial_limit))
end

function p_step!(s::PS.AccProxGradDescentState{T}, f, g, m, cap, c) where T
    omega, nx, np = @stage apg_extrapolate begin
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
        (omega, nx, np)
    end
    ok = p_accelerated_trial!(s, f, g, T(m.β), cap, c)
    if omega > 0 && (!ok || s.f_x > s.f_x_previous)
        @stage apg_restart begin
            s.k = 0
            s.restarts += 1
            copyto!(s.y, s.x_previous)
            copyto!(s.z_y, s.z_previous)
            s.image_error_y = PS._image_error_bound(s.bound, nx, np, false)
        end
        ok = p_accelerated_trial!(s, f, g, T(m.β), cap, c)
    end
    ok || throw(NumericalFailure(:nonfinite_extrapolation))
    @stage apg_tail begin
        s.k += 1
        PS._sub!(s.delta_x, s.x, s.x_previous)
    end
    nothing
end

# B0 stop_scores! with stage timers; `working` is an optional, untimed diagnostic of the
# support gap evaluated with the solver's working gradient (PGD only).
function p_stop_scores!(work::StopWorkspace{T}, x, d, g, b, working) where T
    w, res, grad = work.witness, work.residual, work.gradient
    @stage stop_witness numerical_witness!(w, x, g)
    @stage stop_gradient begin
        residual_score64!(grad, res, d.X, d.y, w)
        grad .*= Float64(d.alpha)
    end
    n, p = size(d.X)
    alpha, r = Float64(d.alpha), Float64(d.r)
    dual, gap_noise, score_noise = @stage stop_noise begin
        dual = dual_64(grad, g)
        residual_noise = gamma64(p+2) * (b.frob * norm2_64(w) + norm2_64(d.y))
        score_noise = alpha * (residual_noise + gamma64(n+2) * norm2_64(res))
        gap_noise = 2r * (g isa L1 ? b.col : b.frob) * score_noise +
                    gamma64(2p+12) * (2r * dual) + norm_noise(w, g, r) * dual
        (dual, gap_noise, score_noise)
    end
    gap = @stage stop_gap estimate_gap(w, grad, g, dual)
    L = T(b.curvature)
    @stage stop_map_trial (@. work.trial = T(w) - T(grad) / L)
    @stage stop_map_project apply_projection!(work.projected, g, work.trial, one(T)/L, nothing, :mapping)
    mapping, map_noise, finite, pass, limited = @stage stop_map_finish begin
        mapping = Float64(L) * maximum(j -> abs(Float64(T(w[j])) - Float64(work.projected[j])), eachindex(w))
        map_noise = b.col * score_noise + Float64(eps(T)) * (Float64(L) * maximum(abs, w) + maximum(abs, grad))
        finite = all(isfinite, (gap, gap_noise, mapping, map_noise))
        pass = finite && gap + gap_noise <= b.gap && mapping + map_noise <= b.mapping
        limited = !finite || gap_noise > b.gap || map_noise > b.mapping
        (mapping, map_noise, finite, pass, limited)
    end
    wg = NaN
    if working !== nothing
        # Diagnostic only: B0's gap formula with the working-precision gradient at the stored x.
        xw = Float64.(x)
        gw = Float64.(working)
        wg = estimate_gap(xw, gw, g, Float64(maximum(abs, working))) / b.gap
    end
    push!(STOPLOG, (; iteration=0.0, pass=Float64(pass), gap_ratio=gap/b.gap, map_ratio=mapping/b.mapping,
                    gap_noise_ratio=gap_noise/b.gap, map_noise_ratio=map_noise/b.mapping, working_gap_ratio=wg))
    (; gap, gap_noise, mapping, map_noise, pass, limited)
end

working_gradient(s::PS.ProximalGradientDescentState) = s.grad_f_x
working_gradient(s) = nothing

function probe_policy(d, f, g, method, a::Accuracy; maxiter=320, log_working=false)
    T = eltype(d.start)
    x = copy(d.start)
    b = @stage setup_budgets budgets(d, a)
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
        @stage setup_checks begin
            check_ball_problem(x, f, g, method)
            all(isfinite, (b.cap, b.gap, b.mapping, b.curvature)) &&
                isfinite(T(b.curvature)) && T(b.curvature) > 0 ||
                throw(NumericalFailure(:unrepresentable_budget))
            check = norm_decision(x, g, b.cap)
            c.trial_refines += check.refined
            if check.code !== :pass
                throw(NumericalFailure(check.code === :over ? :start_refused : :start_unresolved))
            end
        end
        state = @stage setup_state PS.initial_state(method, nothing, f, _ -> T(NaN), x)
        smooth = Float64(state.f_x)
        work = @stage setup_workspace StopWorkspace(d)
        for it in 1:maxiter
            try
                p_step!(state, f, g, method, b.cap, c)
            catch
                PS._rollback_gradient_step!(state)
                rethrow()
            end
            n = it
            proposed = @stage iter_bookkeeping begin
                smooth = Float64(state.f_x)
                residual = PS.f_residual(state.f_x, state.f_x_previous, a.objective_relative)
                increased = state.f_x > state.f_x_previous
                identical = PS._unchanged(x, state.x_previous) ? identical + 1 : 0
                dx = maximum(abs, state.delta_x)
                n == maxiter || dx <= sqrt(a.mapping_relative) * maximum(abs, x) ||
                    residual <= a.objective_relative || identical > 0
            end
            if proposed
                c.stop_checks += 1
                check = @stage stop_decision norm_decision(x, g, b.cap)
                checked_iter = n
                c.stop_refines += check.refined
                if check.code === :pass
                    scores = p_stop_scores!(work, x, d, g, b, log_working ? working_gradient(state) : nothing)
                    c.mappings += 1
                    gap, gap_noise, mapping, map_noise = scores.gap, scores.gap_noise, scores.mapping, scores.map_noise
                    success, last_limited = scores.pass, scores.limited
                else
                    last_limited = true
                end
            end
            @stage row begin
                composite = proposed && check.membership === :inside ? smooth :
                            proposed && check.membership === :outside ? Inf : missing
                row = (; iteration=n, monitor=smooth, smooth, composite, residual, increased, L=Float64(state.L))
                accepted!(nothing, x, g, row)
            end
            stop_requested = false
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
    end
    final_check = @stage result (checked_iter == n ? check : norm_decision(x, g, b.cap))
    begin
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
end

# Ablation: B0 (arm B, no audit/callback) with the stop check run only at `stop_at` (the
# iteration at which B0 ran its last check) and at maxiter. Same trajectory; used to price
# the failed proposals without per-stage timers. Not a candidate policy.
function oracle_policy(d, f, g, method, b, a::Accuracy, stop_at::Int; maxiter=320)
    T = eltype(d.start)
    x = copy(d.start)
    state = nothing
    c = PolicyCounts()
    n, identical = 0, 0
    status = :iteration_limit
    success = false
    check = (; code=:unresolved, membership=:unknown, margin=NaN, refined=false)
    try
        check_ball_problem(x, f, g, method)
        check = norm_decision(x, g, b.cap)
        check.code === :pass || throw(NumericalFailure(:start_refused))
        state = PS.initial_state(method, nothing, f, _ -> T(NaN), x)
        work = StopWorkspace(d)
        for it in 1:maxiter
            try
                step!(state, f, g, method, Val(:B), b.cap, c, nothing)
            catch
                PS._rollback_gradient_step!(state)
                rethrow()
            end
            n = it
            residual = PS.f_residual(state.f_x, state.f_x_previous, a.objective_relative)
            identical = PS._unchanged(x, state.x_previous) ? identical + 1 : 0
            dx = maximum(abs, state.delta_x)
            proposed = n == maxiter || dx <= sqrt(a.mapping_relative) * maximum(abs, x) ||
                       residual <= a.objective_relative || identical > 0
            if proposed && (n == stop_at || n == maxiter)
                c.stop_checks += 1
                check = norm_decision(x, g, b.cap)
                if check.code === :pass
                    success = stop_scores!(work, x, d, g, b, nothing).pass
                end
            end
            if success
                status = :success
                break
            elseif identical >= 4
                status = :numerical_stagnation
                break
            end
        end
    catch e
        e isa NumericalFailure || rethrow()
        status = e.reason
    end
    (; x, status, iterations=n, stop_checks=c.stop_checks, success)
end
