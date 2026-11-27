module PGDStoppingPolicyTest

using Test, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

unit_loss(::Type{T}) where T = LeastSquaresLoss(T[1], fill(one(T), 1, 1))
unit_step() = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0))

@testset "Explicit policy skips the coordinatewise workspace ($T)" for T in (Float32, Float64)
    f, method, options = unit_loss(T), unit_step(), ProximalOptions(maxiter=3)
    for g in (NormL1(zero(T)), ElasticNet(T(0.25), T(0.5)))
        @test PS.initial_state(method, options, f, g, T[1]).scales isa PS._CoordinateScales
        @test PS.initial_state(method, options, f, g, T[1], Val(false)).scales === nothing
    end

    # Rule B's smooth scale is zero at this nontrivial exact fit. The selected
    # progress policy stops once the accepted iterate is unchanged.
    g = NormL1(zero(T))
    legacy = solve!(T[1], f, g, method, options)
    pilot = solve!(T[1], f, g, method; stopping=IterateChange(), limits=MaxIterations(3))
    @test legacy.iterations == 3 && !legacy.converged
    @test pilot.iterations == 1 && termination(pilot).satisfied && !pilot.converged
    @test legacy.minimizer == pilot.minimizer == T[1]
end

@testset "Initial checkpoint and caps ($T)" for T in (Float32, Float64)
    x = T[0]
    calls = Int[]
    user = UserStop(c -> (push!(calls, c.iteration); c.objective == T(0.5)))
    f, g, method = unit_loss(T), NormL1(zero(T)), unit_step()

    r = solve!(x, f, g, method, ProximalOptions(store_trace=true);
               stopping=AnyOf(IterateChange(), ObjectiveChange(), user))
    t = termination(r)
    @test t.reason == :user && t.satisfied && !r.converged && !t.limit_reached
    @test t.iteration == 0 && t.limit.n == 200 && t.winning_branch == ((3,),)
    @test map(o -> o.status, t.observations) == (:not_checked, :not_checked, :pass)
    @test calls == [0] && r.minimum === T(0.5) && PS.minimizer(r) === x
    @test isempty(r.trace)
    @test (PS.f_calls(r), PS.grad_calls(r), PS.prox_calls(r)) == (1, 1, 0)
    @test t.counts.g_calls == 1

    empty!(calls)
    r = solve!(x, f, g, method; stopping=user, limits=MaxIterations(0))
    t = termination(r)
    @test t.reason == :limit && t.limit_reached && !t.satisfied && !r.converged
    @test t.winning_branch === nothing && t.observations[1].status == :not_checked
    @test PS.minimum(r) === missing && PS.iterations(r) == 0 && PS.minimizer(r) === x
    @test all(iszero, values(t.counts)) && isempty(calls) && x == T[0]
    printed = sprint(show, r)
    @test PS.iteration_limit_reached(r) && occursin("Minimum: missing", printed)
    @test occursin(" * Convergence: false", printed)
    @test occursin(" * Stopping condition satisfied: false", printed)

    r = solve!(x, f, g, method; limits=MaxIterations(4))
    t = termination(r)
    @test t.reason == :limit && t.iteration == 4 && isempty(t.observations)
    @test r.prox_calls == 4 && x == T[1] && r.minimum === zero(T)
    r = solve!(x, f, g, method, ProximalOptions(maxiter=3); stopping=UserStop(_ -> false))
    @test termination(r).limit.n == r.iterations == 3
end

@testset "Progress evidence, scope and history ($T)" for T in (Float32, Float64)
    f, g = LeastSquaresLoss(T[1], fill(T(2), 1, 1)), NormL1(zero(T))
    method = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0, β=0.1))
    x = T[0]
    r = solve!(x, f, g, method;
        stopping=AllOf(IterateChange(rtol=1), IterateChange(atol=1), ObjectiveChange(atol=1)),
        limits=MaxIterations(3))
    t = termination(r)
    @test t.reason == :rule && t.satisfied && !r.converged && t.iteration == 1
    @test t.winning_branch == ((1,), (2,), (3,))
    @test x[1] ≈ T(0.2) && abs(2x[1] - 1) > 0.5  # away from stationarity
    dx, dx2, change = t.observations
    @test dx.status == dx2.status == change.status == :pass
    @test dx.value == dx2.value == dx.scale == dx.threshold == Float64(x[1])
    @test change.value ≈ 0.5 - (2Float64(x[1]) - 1)^2 / 2 atol=eps(T)

    f, g = unit_loss(T), NormL1(T(0.25))
    policy = AllOf(AnyOf(UserStop(c -> (yield(); c.iteration == 1)), ObjectiveChange()),
                   UserStop(c -> c.iteration == 2))
    function run_policy(start)
        result = solve!(T[start], f, g, unit_step(); stopping=policy, limits=MaxIterations(4))
        termination(result), result.minimum
    end
    # The nested OR skips ObjectiveChange at k=1. At k=2 its predecessor must
    # still be k=1, whose composite objective is different from the start's.
    first_run = Threads.@spawn run_policy(0)
    second_run = Threads.@spawn run_policy(-1)
    for (result, value) in (run_policy(0), run_policy(-1), fetch(first_run), fetch(second_run))
        @test result.iteration == 2 && result.reason == :rule && result.satisfied
        @test result.winning_branch == ((1, 2), (2,))
        @test result.observations[2].value === true && value == T(0.21875)
    end

    x = T[0]
    r = solve!(x, unit_loss(T), NormL1(one(T)), unit_step(); stopping=IterateChange())
    @test r.iterations == 1 && termination(r).observations[1].value === true
    r = solve!(T[0], unit_loss(T), NormL1(zero(T)), unit_step();
        stopping=AnyOf(IterateChange(atol=floatmax(Float64), rtol=floatmax(Float64)),
                       UserStop(c -> c.iteration == 1)))
    @test termination(r).reason == :user
    @test termination(r).observations[1].status == :invalid
end

@testset "Exact change uses stored values with subnormal flushing" begin
    old = get_zero_subnormals()
    tiny = reinterpret(Float64, 0x0000000000000001)
    negative_tiny = reinterpret(Float64, 0x8000000000000001)
    try
        if set_zero_subnormals(true)
            state = (; x=[0.0], x_previous=[tiny])
            point = PS.ProximalGradientDescentStoppingPoint(state, 1, 0.0, 0.0)
            @test !PS.Stopping.same_iterate(point)
            state.x_previous[1] = -0.0
            @test PS.Stopping.same_iterate(point)
            point = (iteration=1, objective=tiny, previous_objective=0.0)
            @test PS.Stopping.assess(ObjectiveChange(), point, nothing, false).status == :fail
            @test_throws ArgumentError ObjectiveChange(atol=negative_tiny)
        end
    finally
        set_zero_subnormals(old)
    end
end

@testset "Composition and tie at the cap" begin
    f, g, method = unit_loss(Float64), NormL1(0.0), unit_step()
    for compose in (AnyOf, AllOf), a in (false, true), b in (false, true)
        policy = compose(UserStop(_ -> a), UserStop(_ -> b))
        r = solve!([0.0], f, g, method; stopping=policy, limits=MaxIterations(1))
        passes = compose === AnyOf ? a || b : a && b
        @test termination(r).satisfied == passes
        @test termination(r).reason == (passes ? :user : :limit)
        @test r.iterations == (passes ? 0 : 1)
    end

    calls = Int[]
    user = UserStop(c -> (push!(calls, c.iteration); false))
    movement = IterateChange(atol=10)
    objective = ObjectiveChange(rtol=1)
    for (policy, satisfied, statuses) in (
            (AnyOf(user, movement, objective), true, (:not_checked, :not_checked, :pass)),
            (AllOf(objective, movement, user), false, (:pass, :not_checked, :not_checked)))
        empty!(calls)
        r = solve!([0.0], f, g, method, ProximalOptions(store_trace=true);
                   stopping=policy, limits=MaxIterations(1))
        t = termination(r)
        @test t.limit_reached && t.satisfied == satisfied && !r.converged
        @test t.reason == (satisfied ? :rule : :limit)
        @test map(o -> o.status, t.observations) == statuses
        @test calls == (satisfied ? [0] : Int[])
        @test length(r.trace) == 1 && t.counts.f_calls == 3
    end
end

@testset "Two rejected trials, one accepted checkpoint" begin
    # From x = 0, the trials are 2^520 (overflowing loss), 2^260
    # (insufficient curvature), and 1 (minimum of (x - 1)^2 / 2).
    method = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=2.0^-520, β=2.0^-260))
    f, g = unit_loss(Float64), NormL1(0.0)
    visited = Tuple{Int,Float64}[]
    user = UserStop(c -> (push!(visited, (c.iteration, c.objective)); c.iteration == 1))
    x = [0.0]
    r = solve!(x, f, g, method, ProximalOptions(store_trace=true, extended_trace=true);
               stopping=AllOf(user, ObjectiveChange(atol=0.5)),
               limits=MaxIterations(2))
    t = termination(r)
    @test visited == [(0, 0.5), (1, 0.0)]
    @test t.iteration == 1 && t.reason == :rule && t.satisfied && !r.converged
    @test t.counts == (f_calls=5, grad_calls=2, g_calls=4, prox_calls=3, backtrack_steps=3, rejected_trials=2)
    @test t.observations[2].value == t.observations[2].threshold == 0.5
    @test x == [1.0] && r.minimum == (x[1] - 1)^2 / 2
    @test length(r.trace) == 1
    @test r.trace[1].iteration == 1 && r.trace[1].fg_x == r.minimum
    @test r.trace[1].metadata["x"] == x
end

@testset "ScaledKKT at the initial point ($T)" for T in (Float32, Float64)
    X = reshape(T[1, 0, 0, 0], 2, 2)
    y = T[1, 1]
    f, method = LeastSquaresLoss(y, X), unit_step()
    kkt = ScaledKKT(rtol=0)

    # The zero-weight first coordinate has a zero score at x₁ = 1. With
    # the scaled loss and ridge term below, the zero score is at x₁ = 1/2.
    for (loss, penalty, x) in ((f, NormL1(T(0.25), T[0, 1]), T[1, 0]),
                               (T(2) * f, ElasticNet(T(0.25), T(2), T[0, 1]), T[0.5, 0]))
        start = copy(x)
        r = solve!(x, loss, penalty, method; stopping=kkt, limits=MaxIterations(1))
        t = termination(r)
        @test r.converged && t.satisfied && t.reason === :rule && !t.limit_reached
        @test t.iteration == 0 && t.winning_branch == ((),)
        @test only(t.observations) === (; path=(), name=:ScaledKKT, evidence=:stationarity,
                                        status=:pass, value=true, threshold=true, scale=missing)
        @test t.counts == (f_calls=1, grad_calls=1, g_calls=1, prox_calls=0,
                           backtrack_steps=0, rejected_trials=0)
        @test r.minimizer === x && x == start
    end

    g = NormL1(zero(T))
    exact = solve!(T[1], unit_loss(T), g, method; stopping=kkt, limits=MaxIterations(1))
    @test !exact.converged && termination(exact).reason === :limit
    zero_fit = LeastSquaresLoss(T[0], fill(one(T), 1, 1))
    trivial = solve!(T[0], zero_fit, g, method; stopping=kkt, limits=MaxIterations(1))
    @test trivial.converged && trivial.iterations == 0

    # At x = 0 the first score is 1 and its scale is sqrt(2); the
    # second column has zero scale and zero score.
    for rtol in (0.0, nextfloat(0.0), Float64(floatmin(T)), 0.5, 0.75, floatmax(Float64))
        tau = T(max(rtol, 64 * Float64(eps(T))))
        threshold = T(BigFloat(tau) * sqrt(BigFloat(2)))
        expected = isfinite(threshold) && threshold >= floatmin(T) && one(T) < threshold
        r = solve!(zeros(T, 2), f, g, method;
                   stopping=ScaledKKT(; rtol), limits=MaxIterations(1))
        @test r.converged == expected
        @test r.iterations == (expected ? 0 : 1)
    end
end

@testset "ScaledKKT evidence follows the winning branch" begin
    f = LeastSquaresLoss([1.0, 1.0], reshape([1.0, 0.0], 2, 1))
    g, method = NormL1(0.0), unit_step()
    kkt, yes, no = ScaledKKT(rtol=1e-5), UserStop(_ -> true), UserStop(_ -> false)
    for (rule, converged, reason, branches, statuses) in (
        (AllOf(yes, kkt), true, :rule, ((1,), (2,)), (:pass, :pass)),
        (AnyOf(yes, kkt), false, :user, ((1,),), (:pass, :not_checked)),
        (AnyOf(AllOf(kkt, no), yes), false, :user, ((2,),), (:pass, :fail, :pass)),
    )
        r = solve!([1.0], f, g, method; stopping=rule)
        t = termination(r)
        @test r.iterations == 0 && r.converged == converged && t.satisfied
        @test t.reason === reason && t.winning_branch == branches
        @test map(o -> o.status, t.observations) == statuses
        printed = sprint(show, r)
        @test occursin(" * Convergence: $converged", printed)
        @test occursin(" * Stopping condition satisfied: true", printed)
    end
    for (rule, reason, statuses) in (
        (kkt, :limit, (:not_checked,)),
        (AnyOf(kkt, ObjectiveChange(atol=0.5)), :rule, (:not_checked, :pass)),
    )
        r = solve!([0.0], f, g, method; stopping=rule, limits=MaxIterations(1))
        t = termination(r)
        @test r.minimizer == [1.0] && r.iterations == 1
        @test !r.converged && t.limit_reached && t.reason === reason
        @test t.satisfied == (reason === :rule)
        @test map(o -> o.status, t.observations) == statuses
    end

    x = [0.0]
    r = solve!(x, f, g, method; stopping=kkt, limits=MaxIterations(0))
    @test r.minimizer === x && x == [0.0] && r.minimum === missing && !r.converged
    @test all(iszero, values(termination(r).counts))
    @test only(termination(r).observations).status === :not_checked
    for cap in (0, 2)
        @test_throws ArgumentError solve!(x, f, NormL2(0.0), method;
            stopping=AnyOf(yes, AllOf(no, kkt)), limits=MaxIterations(cap))
        @test x == [0.0]
    end
    for rtol in (-1, Inf, NaN, -nextfloat(0.0))
        @test_throws ArgumentError ScaledKKT(; rtol)
    end
end

@testset "ScaledKKT shares identical observations within a checkpoint" begin
    loose, tight = ScaledKKT(rtol=0.5), ScaledKKT(rtol=0.25)
    scans = Tuple{Int,Float64}[]
    provider(point, rtol) = (push!(scans, (point.iteration, rtol)); true)
    stopping = PS.Stopping
    monitor = stopping.with_stationarity(
        stopping.prepare(AllOf(loose, tight, loose), MaxIterations(2), Float64), provider)
    @test stopping.check!(monitor, (; iteration=0)) === :rule
    @test stopping.check!(monitor, (; iteration=1)) === :rule
    @test stopping.check!(monitor, (; iteration=2)) === :limit
    @test scans == [(0, 0.5), (0, 0.25), (1, 0.5), (1, 0.25)]
    @test all(o -> o.status === :not_checked, stopping.observations(monitor.root, 2, ()))
end

@testset "ScaledKKT uses the accepted gradient after rejected trials" begin
    method = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=2.0^-520, β=2.0^-260))
    f = LeastSquaresLoss([1.0, 1.0], reshape([1.0, 0.0], 2, 1))
    g, kkt = NormL1(0.0), ScaledKKT(rtol=1e-5)
    visited = Tuple{Int,Float64}[]
    record = UserStop(c -> (push!(visited, (c.iteration, c.objective)); true))
    r = solve!([0.0], f, g, method; stopping=AllOf(record, kkt), limits=MaxIterations(2))
    t = termination(r)
    @test visited == [(0, 1.0), (1, 0.5)]
    @test r.minimizer == [1.0] && r.minimum == 0.5 && r.converged
    @test t.reason === :rule && t.winning_branch == ((1,), (2,))
    @test t.counts == (f_calls=5, grad_calls=2, g_calls=4, prox_calls=3,
                       backtrack_steps=3, rejected_trials=2)
end

@testset "Absolute movement requires a finite distance" begin
    # The two unobserved coefficients stay fixed. Their Euclidean norm
    # overflows, but the displacement is exactly 1 in the first coordinate.
    f = LeastSquaresLoss([1.0], [1.0 0.0 0.0])
    x = [0.0, 1.5e308, 1.5e308]
    r = solve!(x, f, IndNonnegative(), unit_step();
               stopping=AnyOf(IterateChange(rtol=1), IterateChange(atol=2)),
               limits=MaxIterations(2))
    t = termination(r)
    @test t.iteration == 1 && t.satisfied && x == [1.0, 1.5e308, 1.5e308]
    relative, absolute = t.observations
    @test relative.status == :invalid && isinf(relative.scale)
    @test absolute.status == :pass && absolute.value == 1 && absolute.threshold == 2
    @test ismissing(absolute.scale)
end

@testset "An accepted objective increase leaves the selected policy in charge" begin
    # Lexact admits the larger step. The first two accepted points are 2 and -4.
    method = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0, Lexact=1.0))
    f, g = LeastSquaresLoss([1.0], fill(2.0, 1, 1)), NormL1(0.0)
    x = [0.0]
    r = solve!(x, f, g, method; stopping=UserStop(c -> c.iteration == 2), limits=MaxIterations(3))
    @test r.iterations == 2 && r.f_increased && x == [-4.0] && r.minimum == 40.5
    @test termination(r).reason == :user && !r.converged
end

@testset "Preflight conflicts and failure rollback" begin
    f, g, method = unit_loss(Float64), NormL1(0.0), unit_step()
    x = [0.25]
    function refuses(f, g, method, options=ProximalOptions(); kwargs...)
        @test_throws ArgumentError solve!(x, f, g, method, options; kwargs...)
        @test x == [0.25]
    end
    for kw in ((ftol=0.0,), (xtol=1e-4,), (gradtol=1e-4,), (allow_f_increases=true,),
               (f_calls_limit=1,), (grad_calls_limit=1,), (prox_calls_limit=1,), (time_limit=0.5,),
               (callback=_ -> false,), (callback=missing,))
        refuses(f, g, method, ProximalOptions(; kw...); stopping=IterateChange())
    end
    refuses(f, g, method, ProximalOptions(maxiter=4); limits=MaxIterations(3))
    refuses(f, g, method; stopping=AnyOf(IterateChange(), AllOf(MaxIterations(1))))
    refuses(f, g, method; stopping=UserStop(() -> true))
    refuses(f, g, method; stopping=UserStop(_ -> 1))
    refuses(f, g, method; limits=(time=0,))
    refuses(f, IndBallL1(1.0), method; limits=MaxIterations(0))
    refuses(f, g, method; stopping=IterateChange(), feasibility=NumericalFeasibility())
    refuses(f, g, AccProxGradDescent(); stopping=IterateChange())
    refuses(LogisticLoss([1.0], ones(1, 1)), g, method; stopping=IterateChange())
    @test_throws ArgumentError solve!(zeros(1, 1), LeastSquaresLoss(ones(1, 1), ones(1, 1)),
                                     g, method; limits=MaxIterations(0))
    @test_throws ArgumentError MaxIterations(-1)
    @test_throws ArgumentError MaxIterations(big(typemax(Int)) + 1)
    for rule in (IterateChange, ObjectiveChange), invalid in (-1, Inf, NaN, big"1e-1000")
        @test_throws ArgumentError rule(atol=invalid)
        @test_throws ArgumentError rule(rtol=invalid)
    end

    xf = Float32[0]
    failed = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1e-50))
    @test_throws r"curvature estimate cannot increase finitely" solve!(
        xf, unit_loss(Float32), NormL1(0f0), failed; limits=MaxIterations(1))
    @test xf == Float32[0]
    xlarge = [1.0, 1e200]
    flat = LeastSquaresLoss([2.0], [2.0 0.0])
    overflow_penalty = NormL2(1e110)
    @test_throws r"composite objective is finite" solve!(
        xlarge, flat, overflow_penalty, method; limits=MaxIterations(1))
    @test ismissing(solve!(xlarge, flat, overflow_penalty, method; limits=MaxIterations(0)).minimum)
    @test xlarge == [1.0, 1e200]
    @test solve!(x, f, g, method) isa PS.OptimizationResults
end

end
