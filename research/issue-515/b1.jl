# B1: the #514 B0 policy (../issue-514/{feasibility,stationarity,policies}.jl, arm B) with
# mechanical changes only. Every iterate, decision, diagnostic and status is meant to be
# bit-identical to B0; `parity.jl` checks this. Changes are marked "B1:".
#
#   1. norm2_64 annotates its maximum as Float64. Julia 1.10 inferred Union{Float32,Float64}
#      for Float32 input, so every call was dynamic and allocated (budgets: one call per
#      design column; stop check: 40 allocations).
#   2. The result is a concrete struct. B0's NamedTuple had a Union{Missing,Float64} field,
#      which made the whole tuple abstract and heap-boxed about 15 Float64s per solve.
#   3. The stop reuses the feasibility decision of the accepted trial (same vector, same cap,
#      same function), instead of evaluating norm_decision again, and the witness reuses
#      that decision's widened norm and noise instead of recomputing them.
#   4. budgets stores norm2_64(y), which B0 recomputed at every stop check.
#
# Ownership of the cached decision (change 3): `Counts.last` is written by every trial that
# projects into state.x, immediately after the projection, and describes that vector. Only
# trials write state.x, so after step! returns it describes the accepted iterate. After a
# propagated failure state.x is rolled back, and the final classification recomputes the
# decision exactly as B0 does (it never reads `last`).
module B1

import ProximalBase as PB
import ProximalSolvers as PS
using LinearAlgebra
import ..Main: Fixture, Accuracy, NumericalFailure, check_ball_problem, apply_projection!, accepted!,
               residual_score64!, estimate_gap, gamma64

const L1 = PB.IndBallL1

# B1 (1): concrete maximum.
function norm2_64(x)
    m = maximum(a -> abs(Float64(a)), x)::Float64
    (iszero(m) || !isfinite(m)) && return m
    m * sqrt(sum(a -> abs2(Float64(a) / m), x))
end

norm_64(x, ::L1) = sum(a -> abs(Float64(a)), x)
dual_64(x, ::L1) = maximum(abs, x)

# B0 budgets, ℓ1 only, plus the response norm (B1 (4)).
function budgets(d, a)
    alpha = Float64(d.alpha)
    ynorm = norm2_64(d.y)
    yscaled = sqrt(alpha) * ynorm
    col = maximum(norm2_64, eachcol(d.X))
    frob = norm2_64(d.X)
    M = sqrt(alpha) * col
    r = Float64(d.r)
    cost = M * yscaled + 1.5 * M^2 * r
    scale = max(yscaled, sqrt(alpha) * col * r)^2 / 2
    gap = a.objective_relative * scale / 2
    cap = min(r, a.coefficient_absolute + a.coefficient_relative * r, iszero(cost) ? Inf : gap / cost)
    curvature = col > 0 ? alpha * col^2 : 1.0
    mapping = a.mapping_relative * sqrt(alpha) * col * max(yscaled, sqrt(alpha) * col * r)
    (; cap, gap, mapping, curvature, col, frob, objective_scale=scale, ynorm)
end

norm_noise(x, g::L1, s) = gamma64(length(x) + 2) * max(s, Float64(g.r))

struct Decision
    code::Symbol
    membership::Symbol
    margin::Float64
    refined::Bool
    s::Float64      # B1 (3): widened norm, reused by the witness
    noise::Float64
end
const UNRESOLVED = Decision(:unresolved, :unknown, NaN, false, NaN, NaN)

function norm_decision(x, g::L1, cap)
    s = norm_64(x, g)
    r = Float64(g.r)
    m = s - r
    isfinite(m) || return Decision(:unresolved, :unknown, m, false, s, NaN)
    noise = norm_noise(x, g, s)
    membership = m > noise ? :outside : m < -noise ? :inside :
                 iszero(s) && r > 0 ? :inside : :unknown
    separation = m - cap
    code = separation < -noise ? :pass : separation > noise ? :over : :unresolved
    Decision(code, membership, m, false, s, noise)
end

struct StopWorkspace{T}
    witness::Vector{Float64}
    residual::Vector{Float64}
    gradient::Vector{Float64}
    trial::Vector{T}
    projected::Vector{T}
end
function StopWorkspace(d::Fixture{T}) where T
    n, p = size(d.X)
    StopWorkspace(zeros(p), zeros(n), zeros(p), zeros(T, p), zeros(T, p))
end

# B1 (3): s and noise come from the accepted decision on the same x.
function numerical_witness!(w, x, g, s, noise)
    r = Float64(g.r)
    factor = s + noise < r ? 1.0 : min(1.0, (r - noise) / s)
    @. w = factor * Float64(x)
end

function stop_scores!(work::StopWorkspace{T}, x, dec::Decision, d, g, b, audit) where T
    w, res, grad = work.witness, work.residual, work.gradient
    numerical_witness!(w, x, g, dec.s, dec.noise)
    residual_score64!(grad, res, d.X, d.y, w)
    grad .*= Float64(d.alpha)
    dual = dual_64(grad, g)
    n, p = size(d.X)
    alpha, r = Float64(d.alpha), Float64(d.r)
    residual_noise = gamma64(p+2) * (b.frob * norm2_64(w) + b.ynorm)   # B1 (4)
    score_noise = alpha * (residual_noise + gamma64(n+2) * norm2_64(res))
    gap_noise = 2r * b.col * score_noise +
                gamma64(2p+12) * (2r * dual) + norm_noise(w, g, r) * dual
    gap = estimate_gap(w, grad, g, dual)
    L = T(b.curvature)
    @. work.trial = T(w) - T(grad) / L
    apply_projection!(work.projected, g, work.trial, one(T)/L, audit, :mapping)
    mapping = Float64(L) * maximum(j -> abs(Float64(T(w[j])) - Float64(work.projected[j])), eachindex(w))
    map_noise = b.col * score_noise + Float64(eps(T)) * (Float64(L) * maximum(abs, w) + maximum(abs, grad))
    finite = all(isfinite, (gap, gap_noise, mapping, map_noise))
    pass = finite && gap + gap_noise <= b.gap && mapping + map_noise <= b.mapping
    limited = !finite || gap_noise > b.gap || map_noise > b.mapping
    (; gap, gap_noise, mapping, map_noise, pass, limited)
end

mutable struct Counts
    trials::Int
    infeasible::Int
    unresolved::Int
    stop_checks::Int
    mappings::Int
    last::Decision       # B1 (3): decision of the vector last projected into state.x
end
Counts() = Counts(0, 0, 0, 0, 0, UNRESOLVED)

function trial_value!(s, f, g, cap, c, audit)
    PS._allfinite(s.xhat) || return eltype(s.x)(Inf)
    apply_projection!(s.x, g, s.xhat, one(s.L)/s.L, audit, :trial)
    s.prox_calls += 1
    c.trials += 1
    test = norm_decision(s.x, g, cap)
    c.last = test
    c.infeasible += test.code === :over
    c.unresolved += test.code === :unresolved
    test.code === :pass || return eltype(s.x)(Inf)
    s.f_calls += 1
    PS._value!(s.x, f, s.model, s.z_x)
end

function step!(s::PS.ProximalGradientDescentState, f, g, m, cap, c, audit)
    copyto!(s.x_previous, s.x)
    s.f_x_previous = s.f_x
    copyto!(s.grad_f_x_previous, s.grad_f_x)
    s.L *= m.ls.α
    s.verified_rejection = false
    for _ in 1:64
        PS._step!(s.xhat, s.x_previous, s.grad_f_x_previous, s.L)
        s.f_x = trial_value!(s, f, g, cap, c, audit)
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

function accelerated_trial!(s::PS.AccProxGradDescentState{T}, f, g, beta, cap, c, audit) where T
    f_y = PS._value_and_gradient!(s.grad_f_y, s.y, f, s.z_y, s.dz)
    s.f_calls += 1
    s.grad_calls += 1
    isfinite(f_y) && PS._allfinite(s.grad_f_y) || return false
    for _ in 1:64
        PS._step!(s.xhat, s.y, s.grad_f_y, s.L)
        s.f_x = trial_value!(s, f, g, cap, c, audit)
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

function step!(s::PS.AccProxGradDescentState{T}, f, g, m, cap, c, audit) where T
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
    ok = accelerated_trial!(s, f, g, T(m.β), cap, c, audit)
    if omega > 0 && (!ok || s.f_x > s.f_x_previous)
        s.k = 0
        s.restarts += 1
        copyto!(s.y, s.x_previous)
        copyto!(s.z_y, s.z_previous)
        s.image_error_y = PS._image_error_bound(s.bound, nx, np, false)
        ok = accelerated_trial!(s, f, g, T(m.β), cap, c, audit)
    end
    ok || throw(NumericalFailure(:nonfinite_extrapolation))
    s.k += 1
    PS._sub!(s.delta_x, s.x, s.x_previous)
    nothing
end

# B1 (2): concrete result with B0's fields. `composite` is stored inline (isbits union).
struct Result{T}
    x::Vector{T}
    status::Symbol
    error::String
    completed::Bool
    success::Bool
    converged::Bool
    iterations::Int
    gradients::Int
    values::Int
    projections::Int
    trials::Int
    rejected::Int
    restarts::Int
    backtracks::Int
    gap::Float64
    gap_noise::Float64
    mapping::Float64
    map_noise::Float64
    b_work_margin::Float64
    membership::Symbol
    cap_refines::Int
    stop_refines::Int
    stop_checks::Int
    feasibility_rejects::Int
    unresolved_rejects::Int
    smooth::Float64
    composite::Union{Missing, Float64}
    residual::Float64
    increased::Bool
    native_residual::Float64
    trial_writes::Int
end

# Reporting adapter (untimed): B0's NamedTuple shape for the correctness tables.
as_namedtuple(r::Result) = NamedTuple{fieldnames(Result)}(ntuple(i -> getfield(r, i), fieldcount(Result)))

function projected_policy(d, f, g, method, b, a::Accuracy, audit=nothing;
                          maxiter=320, callback=nothing, fault_after=0)
    T = eltype(d.start)
    x = copy(d.start)
    state = nothing
    c = Counts()
    n, identical = 0, 0
    gap = gap_noise = mapping = map_noise = NaN
    status, detail = :iteration_limit, ""
    smooth = residual = NaN
    increased = false
    check = UNRESOLVED
    success = false
    last_limited = false
    checked_iter = -1
    try
        check_ball_problem(x, f, g, method)
        all(isfinite, (b.cap, b.gap, b.mapping, b.curvature)) &&
            isfinite(T(b.curvature)) && T(b.curvature) > 0 ||
            throw(NumericalFailure(:unrepresentable_budget))
        check = norm_decision(x, g, b.cap)
        if check.code !== :pass
            throw(NumericalFailure(check.code === :over ? :start_refused : :start_unresolved))
        end
        state = PS.initial_state(method, nothing, f, _ -> T(NaN), x)
        smooth = Float64(state.f_x)
        work = StopWorkspace(d)
        for it in 1:maxiter
            try
                step!(state, f, g, method, b.cap, c, audit)
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
            proposed = n == maxiter || dx <= sqrt(a.mapping_relative) * maximum(abs, x) ||
                       residual <= a.objective_relative || identical > 0
            if proposed
                c.stop_checks += 1
                # B1 (3): B0 recomputed norm_decision(x, g, b.cap) here. x is the accepted
                # trial, whose decision is c.last; accepted trials always pass the cap.
                check = c.last
                checked_iter = n
                if check.code === :pass
                    scores = stop_scores!(work, x, check, d, g, b, audit)
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
        detail = e isa NumericalFailure ? string(status) : sprint(showerror, e)
        audit === nothing || @assert reinterpret(UInt8, x) == reinterpret(UInt8, audit.last)
    end
    final_check = checked_iter == n ? check : norm_decision(x, g, b.cap)
    decoded = final_check.membership
    composite = decoded === :outside ? Inf : decoded === :inside ? smooth : missing
    line_failed = status in (:trial_limit, :line_search_error, :injected_trial_failure, :nonfinite_gradient, :nonfinite_extrapolation)
    Result{T}(x, status, detail, state !== nothing && !line_failed, success,
              success && decoded === :inside, n,
              (state === nothing ? 0 : state.grad_calls) + c.mappings,
              state === nothing ? 0 : state.f_calls,
              (state === nothing ? 0 : state.prox_calls) + c.mappings,
              c.trials, c.trials - n,
              state isa PS.AccProxGradDescentState ? state.restarts : 0,
              state === nothing ? 0 : state.backtrack_steps,
              gap, gap_noise, mapping, map_noise, final_check.margin, decoded,
              0, 0, c.stop_checks, c.infeasible, c.unresolved,
              smooth, composite, residual, increased, NaN, c.trials)
end

end # module B1
