# Replay only, outside A/B/C. Retain PS #508's old stationarity policy on
# the same production PB projection and the historical default proposals.
mutable struct HistoricalGuard{Mode,G}
    ball::G
    cap::Float64
    col_sq::Float64
    gap::Float64
    lo::Float64
    hi::Float64
    score::Float64
end
HistoricalGuard(::Val{M}, g, cap, col_sq, gap) where M =
    HistoricalGuard{M,typeof(g)}(g, cap, col_sq, gap, -Inf, Inf, NaN)
(g::HistoricalGuard)(x) = zero(eltype(x))

function PB.value_and_prox!(y, g::HistoricalGuard{M}, x, step) where M
    strict = PB.value_and_prox!(y, g.ball, x, step)
    if M === :H4eps
        T = eltype(y)
        mass = PB._linf_sum(y, PB._AbsRead{T}(), T)
        return Float64(mass)-Float64(g.ball.r) <= 4Float64(eps(T))*Float64(g.ball.r) ? zero(T) : strict
    end
    bounds = Enclosure1138.compensated(y, g.ball.r)
    bounds !== nothing && bounds[2] <= g.cap || throw(NumericalFailure(:historical_cap))
    g.lo, g.hi = bounds
    zero(eltype(y))
end

function PS._stationary!(state, f, g::HistoricalGuard{:Hworking}, options::PS.ProximalOptions)
    grad = PS._gradient_at_x!(state, f)
    dual, r = Float64(maximum(abs, grad)), Float64(g.ball.r)
    score = dual*max(-g.lo, 0.0) + 2r*g.col_sq*max(g.hi, 0.0)
    for j in eachindex(grad)
        xj, gj = Float64(state.x[j]), Float64(grad[j])
        score += abs(xj) * (dual + (signbit(xj) ? -gj : gj))
    end
    g.score = score
    isfinite(score) && score <= g.gap
end

function historical(arm, d, f, g, method, b)
    x = copy(d.start)
    guard = HistoricalGuard(arm, g, b.cap, b.curvature, b.gap)
    options = PS.ProximalOptions(; maxiter=320, allow_f_increases=true, ftol=1e-6, xtol=1e-8, gradtol=1e-5)
    state = PS.initial_state(method, options, f, guard, x)
    r = PS._solve_gradient!(state, f, guard, method, options)
    (; x, converged=r.converged, iterations=r.iterations, score=guard.score,
       gradients=r.grad_calls, projections=r.prox_calls)
end
