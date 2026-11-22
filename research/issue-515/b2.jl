# (B1 header, kept for reference.)
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
# B2: B1 plus two changes chosen from the #515 Stage 0 profile. Changes are marked "B2:".
# B2 does not change a feasibility test, a stopping threshold, the witness, the fresh
# Float64 gradient, the mapping, the projection or the status rules of B0/B1.
#
#   (a) Proposal pre-screen. In B0, progress tests propose a stop on most iterations of
#       small and medium correlated fits, and about 95% of the full stop checks fail (Stage 0).
#       Before a full check, B2 evaluates the support gap r||G||_inf + <x, G> with the
#       working-precision gradient G at the stored iterate: PGD's own gradient of the
#       accepted trial (no extra work). PGD only: an APG screen needs one extra product
#       X'(z_x - y) per proposal, which measured as a >5% regression against B0 where the
#       screen cannot reject (single-proposal solves, Float32 at large p), so APG keeps
#       B1's stopping path unchanged. The screen never uses a gradient at an
#       extrapolated point or at a rejected trial. With the same dot-product rounding
#       model that B0 uses for its stop noise (in the working precision), plus the
#       displacement to B0's radial witness, it bounds |gap(w) - computed working gap|.
#       It skips the full check only when the working gap minus that allowance exceeds
#       the gap budget, i.e. when the exact support gap at B0's witness exceeds the budget,
#       so B0's check would fail as well. A skipped proposal is never a success; the full,
#       unchanged B0/B1 check decides every stop. Proposals at maxiter or with an
#       unchanged iterate always get the full check.
#       Revision after the independent review (#515): the screen runs only with gradual
#       underflow (not when the thread flushes subnormals) and when the working loss is far
#       above the underflow range; the allowance includes the absolute underflow error of
#       the native products. A screened proposal reports its gap and mapping diagnostics as
#       unavailable (NaN) instead of keeping those of an older full check.
#   (b) Withdrawn after the review: budgets are B0's (bit-identical thresholds). The
#       one-pass design norms remain below as `budgets_onepass`, unused by the policy, for
#       a separate maintainer decision: they compute the same norms with different
#       rounding, which can move a stop threshold by an ulp.
#
module B2

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
    budget_scalars(alpha, ynorm, col, frob, Float64(d.r), a)
end

# Not used by the B2 policy (see (b) in the header): B0's budgets with one-pass norms.
function budgets_onepass(d, a)
    alpha = Float64(d.alpha)
    col, frob = design_norms(d.X)
    budget_scalars(alpha, norm2_64(d.y), col, frob, Float64(d.r), a)
end

function budget_scalars(alpha, ynorm, col, frob, r, a)
    yscaled = sqrt(alpha) * ynorm
    M = sqrt(alpha) * col
    cost = M * yscaled + 1.5 * M^2 * r
    scale = max(yscaled, sqrt(alpha) * col * r)^2 / 2
    gap = a.objective_relative * scale / 2
    cap = min(r, a.coefficient_absolute + a.coefficient_relative * r, iszero(cost) ? Inf : gap / cost)
    curvature = col > 0 ? alpha * col^2 : 1.0
    mapping = a.mapping_relative * sqrt(alpha) * col * max(yscaled, sqrt(alpha) * col * r)
    (; cap, gap, mapping, curvature, col, frob, objective_scale=scale, ynorm)
end

# (b), unused by the policy: largest column norm and Frobenius norm of X from one pass of Float64 column
# sums of squares. A column whose sum is not finite or is below 2^-968 (where squares may
# have underflowed) uses B0's scaled norm2_64, and then so does the Frobenius norm. For
# Float32 data every nonzero square is a normal Float64, so only zero columns fall back.
function design_norms(X::AbstractMatrix)
    n, p = size(X)
    colsq, total, scaled = 0.0, 0.0, false
    col = 0.0
    @inbounds for j in 1:p
        s = 0.0
        @simd for i in 1:n
            v = Float64(X[i, j])
            s += v * v
        end
        if isfinite(s) && s >= 0x1p-968
            colsq = max(colsq, s)
            total += s
        else
            scaled = true
            col = max(col, norm2_64(view(X, :, j)))
        end
    end
    col = max(col, sqrt(colsq))
    frob = scaled || !isfinite(total) ? norm2_64(X) : sqrt(total)
    col, frob
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

# B2 (a): working-precision gradient at the stored (accepted) iterate.
# PGD: step! leaves the solver's gradient of the accepted trial in grad_f_x (the line
# search refreshes it at state.x, or step! does after the search).
working_gradient(s::PS.ProximalGradientDescentState) = s.grad_f_x

gammaT(::Type{T}, k) where T = (c = k * (Float64(eps(T)) / 2); c < 1 ? c / (1 - c) : Inf)

# true when the exact support gap at B0's radial witness provably exceeds the gap budget
# under the rounding model below, so the full check cannot pass.
function prescreen_rejects(G, x::AbstractVector{T}, dec::Decision, d, g, b, f_x) where T
    n, p = size(d.X)
    r, alpha, s = Float64(g.r), Float64(d.alpha), dec.s
    # Range guard: the model below assumes gradual underflow, and ||d|| is read from the
    # working loss only where that loss is far above the underflow range. Otherwise the
    # full check decides.
    get_zero_subnormals() && return false
    eta = Float64(nextfloat(zero(T)))
    Float64(f_x) >= 0x1p20 * (n + 4) * Float64(floatmin(T)) * max(1.0, alpha) || return false
    dual = 0.0
    @inbounds for j in eachindex(G)
        dual = max(dual, abs(Float64(G[j])))
    end
    acc, x2 = 0.0, 0.0
    @inbounds for j in eachindex(x, G)
        xj, gj = Float64(x[j]), Float64(G[j])
        acc += abs(xj) * (dual + (signbit(xj) ? -gj : gj))
        x2 += xj * xj
    end
    # Working gap, B0's estimate_gap formula at x; equal to r||G|| + <x,G> when s <= r.
    gapw = max(0.0, r - s) * dual + acc
    # Error of the working gradient per coordinate: B0's stop noise model with T's unit
    # roundoff, plus the absolute error of underflowing products and sums (at most eta,
    # the least positive T, per operation), plus the final scaling:
    #   C alpha (gamma(p+2)(||X||_F ||x|| + ||y||) + sqrt(n) 2p eta + gamma(n+3)||d||)
    #   + alpha (2n + 1) eta + eta + u ||G||,
    # with ||d|| read from the working loss value (the guard above bounds the loss
    # rounding lost to underflow by 2^-20 relative).
    dnorm = sqrt(2 * Float64(f_x) / alpha) * (1 + gammaT(T, n + 4) + 0x1p-18)
    work_noise = b.col * alpha * (gammaT(T, p + 2) * (b.frob * sqrt(x2) + b.ynorm) +
                                  sqrt(n) * 2p * eta + gammaT(T, n + 3) * dnorm) +
                 alpha * (2n + 1) * eta + eta + gammaT(T, 1) * dual
    # Displacement to B0's witness w = factor x (rounded): ||x - w||_1 <= delta, and the
    # exact gradient moves by at most alpha C^2 delta in the max norm.
    factor = s + dec.noise < r ? 1.0 : min(1.0, (r - dec.noise) / s)
    delta = (1 - factor) * s + eps(Float64) * s
    Delta = work_noise + alpha * b.col^2 * delta
    # gap(w) = r||g*|| + <w,g*>; the terms bound r and <x,.> times the gradient error, the
    # displacement, the clipped max(0, r - s) when s > r, and the Float64 accumulation.
    allowance = (r + s) * Delta + delta * (dual + Delta) + max(0.0, s - r) * dual +
                gamma64(2p + 12) * 2 * (r + s) * dual + (4p + 24) * nextfloat(0.0)
    allowance *= 1 + 1e-6
    isfinite(gapw) && isfinite(allowance) && gapw - allowance > b.gap
end

mutable struct Counts
    trials::Int
    infeasible::Int
    unresolved::Int
    stop_checks::Int
    mappings::Int
    last::Decision       # B1 (3): decision of the vector last projected into state.x
    prescreens::Int      # B2 (a)
    prescreen_rejects::Int
end
Counts() = Counts(0, 0, 0, 0, 0, UNRESOLVED, 0, 0)

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
    prescreens::Int          # B2 (a)
    prescreen_rejects::Int
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
                screened = false
                if state isa PS.ProximalGradientDescentState && check.code === :pass &&
                   n != maxiter && identical == 0
                    # B2 (a), PGD only: skip a full check that cannot pass.
                    c.prescreens += 1
                    screened = prescreen_rejects(working_gradient(state), x, check, d, g, b, state.f_x)
                    c.prescreen_rejects += screened
                end
                if screened
                    # The full check did not run at this proposal: its diagnostics are unavailable.
                    success = false
                    gap = gap_noise = mapping = map_noise = NaN
                elseif check.code === :pass
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
              smooth, composite, residual, increased, NaN, c.trials,
              c.prescreens, c.prescreen_rejects)
end

end # module B2
