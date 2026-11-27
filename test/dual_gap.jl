module DualGapTest

using LinearAlgebra, Random, Test
using ProximalBase, ProximalSolvers

const PS = ProximalSolvers

pgd() = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0))
scalar_loss(::Type{T}, y=2) where {T} = LeastSquaresLoss(T[y], ones(T, 1, 1))
gap_observation(r) = first(termination(r).observations)
statuses(r) = map(o -> o.status, termination(r).observations)

function exact_residual_ray(X, y, x, level)
    A, b, w = Rational{BigInt}.(X), Rational{BigInt}.(y), Rational{BigInt}.(x)
    λ = Rational{BigInt}(level)
    r = b - A * w
    r2 = dot(r, r)
    (; r2, ry=dot(r, b), primal=r2 / 2 + λ * sum(abs, w), radius=maximum(abs, A' * r), λ)
end

function exact_relative_gap(ray, κ)
    dual = κ * ray.ry - κ^2 * ray.r2 / 2
    (ray.primal - dual) / ray.primal
end

function best_ray_gap(ray)
    cap = ray.radius <= ray.λ ? one(ray.λ) : ray.λ / ray.radius
    κ = iszero(ray.r2) ? cap : clamp(ray.ry / ray.r2, zero(cap), cap)
    exact_relative_gap(ray, κ)
end

@testset "Outward dual feasibility and relative gap against exact arithmetic" begin
    # A nearest-rounded ratio of 1/10 would give an infeasible exact product.
    κ = PS._dual_gap_shrinkage(1.0, 10.0)
    @test 0 < Rational{BigInt}(κ) <= 1 // 10
    @test PS._dual_gap_shrinkage(1.0, 1.0) == 1.0

    rng = Xoshiro(320)
    work = PS._DualGapWorkspace(5, 3)
    for power in (-120, -30, 0, 30, 120), _ in 1:4
        X = ldexp.(Float32.(rand(rng, -31:31, 5, 3)), power)
        y = ldexp.(Float32.(rand(rng, -31:31, 5)), power)
        x = Float32[1.25, -0.375, 0]
        level = ldexp(1.0, power)
        ray = exact_residual_ray(X, y, x, level)

        bound = PS._relative_dual_gap_upper!(work, X, y, x, level)
        @test bound isa Float64 && isfinite(bound)
        PS._dual_gap_residual_bounds!(work, X, y, x)
        radius = PS._dual_gap_correlation_bounds!(work, X, x)
        κ = Rational{BigInt}(PS._dual_gap_shrinkage(level, radius))
        @test Rational{BigInt}(radius) >= ray.radius
        @test 0 <= κ <= 1 && κ * ray.radius <= ray.λ
        @test Rational{BigInt}(bound) >= exact_relative_gap(ray, κ)
    end
end

@testset "Dual gap uses the stored problem's exact objective" begin
    # The leading and trailing products cancel across a much smaller one.
    large = 2f0^60
    cases = (
        (reshape(Float32[large, 1, -large], 3, 1), ones(Float32, 3), Float32[0], 0.125f0, 0.5),
        (ones(Float32, 1, 1), Float32[2f0^-80], Float32[0], 2f0^-81, 0.2),
        (Float32[large -1; 0 0; -large -1], Float32[large, 1, -large], Float32[1, 1], 2f0^-20, 0.1),
    )
    for (X, y, start, level, rtol) in cases
        ray = exact_residual_ray(X, y, start, level)
        reference = best_ray_gap(ray)
        @test reference > Rational{BigInt}(rtol)
        x = copy(start)
        r = solve!(x, LeastSquaresLoss(y, X), NormL1(level), pgd();
                   stopping=AnyOf(DualGap(rtol=rtol), UserStop(_ -> true)))
        t, o = termination(r), gap_observation(r)
        @test r.minimizer === x && x == start && r.iterations == 0
        @test t.reason === :user && !r.converged && t.winning_branch == ((2,),)
        @test o.name === :DualGap && o.evidence === :gap_bound && o.status === :fail
        @test o.value isa Float64 && o.threshold === rtol && ismissing(o.scale)
        @test Rational{BigInt}(o.value) >= reference
        if level == 2f0^-81
            @test r.minimum === 0f0 && reference == 1 // 4
            @test o.value <= 0.25 + 1e-12
        end
    end

    f, g = scalar_loss(Float32), NormL1(1f0)
    x = Float32[1]
    r = solve!(x, f, g, pgd(); stopping=DualGap(rtol=1e-12))
    t, o = termination(r), gap_observation(r)
    @test r.minimizer === x && x == Float32[1] && r.minimum === 1.5f0
    @test r.iterations == 0 && r.converged && t.satisfied && t.reason === :rule
    @test t.winning_branch == ((),) && o.status === :pass
    @test 0 <= o.value <= o.threshold == 1e-12
    @test t.counts == (; f_calls=2, grad_calls=2, g_calls=2, prox_calls=0,
                        backtrack_steps=0, rejected_trials=0)

    r = solve!(Float32[-0.0], scalar_loss(Float32, -0.0), g, pgd();
               stopping=DualGap(rtol=0))
    @test r.converged && gap_observation(r).value === 0.0 && r.iterations == 0
    @test termination(r).counts == t.counts
end

@testset "Dual gap and KKT supply distinct evidence" begin
    f, g = scalar_loss(Float32), NormL1(1f0)
    fallback = UserStop(_ -> true)
    # At the first start KKT's native floor permits a stop, while the gap exceeds
    # the requested tolerance. At the second start the gap passes and KKT fails.
    for (start, rtol, first_rule, second_rule) in (
        (1f0 + 2f0^-21, 1e-7, ScaledKKT, DualGap),
        (0f0, 0.375, DualGap, ScaledKKT),
    )
        rule = AnyOf(AllOf(first_rule(rtol=rtol), second_rule(rtol=rtol)), fallback)
        r = solve!(Float32[start], f, g, pgd(); stopping=rule)
        t = termination(r)
        @test statuses(r) == (:pass, :fail, :pass)
        @test t.reason === :user && t.winning_branch == ((2,),) && !r.converged
        @test t.counts.grad_calls == t.counts.f_calls == t.counts.g_calls == 2
    end

    loose = DualGap(rtol=0.3)
    tight = DualGap(rtol=0.1)
    r = solve!(Float32[0], f, g, pgd(); stopping=AnyOf(tight, loose))
    t = termination(r)
    @test r.converged && t.winning_branch == ((2,),)
    @test statuses(r) == (:fail, :pass)
    @test t.observations[1].value === t.observations[2].value
    @test t.counts.f_calls == t.counts.grad_calls == t.counts.g_calls == 2
end

@testset "Dual gap obeys hard evaluation budgets" begin
    f, g, method = scalar_loss(Float32), NormL1(1f0), pgd()
    rule = DualGap(rtol=1e-6)
    for cap in (MaxIterations(0), MaxObjectiveEvaluations(0), MaxGradientEvaluations(0),
                MaxProximalEvaluations(0), MaxObjectiveEvaluations(1), MaxGradientEvaluations(1))
        r = solve!(Float32[1], f, g, method; stopping=rule, limits=cap)
        t = termination(r)
        @test t.reason === :limit && r.iterations == 0 && !r.converged
        @test statuses(r) == (:not_checked,) && ismissing(gap_observation(r).value)
        @test t.counts.f_calls == t.counts.grad_calls == t.counts.g_calls == cap.n
        @test ismissing(r.minimum) == iszero(cap.n)
    end

    limits = (MaxGradientEvaluations(2), MaxObjectiveEvaluations(2))
    same = AllOf(rule, Every(1, rule))
    new_tolerance = AllOf(rule, DualGap(rtol=1e-5))
    kkt = ScaledKKT(rtol=1e-6)
    for (policy, expected) in ((same, (:pass, :pass)),
                               (new_tolerance, (:pass, :not_checked)),
                               (AllOf(kkt, rule), (:pass, :pass)),
                               (AllOf(rule, kkt), (:pass, :not_checked)))
        r = solve!(Float32[1], f, g, method; stopping=policy, limits)
        t = termination(r)
        @test statuses(r) == expected
        @test t.limit_reached && t.reached_evaluation_limits == limits
        @test r.converged == t.satisfied == (last(expected) === :pass)
        @test t.reason === (r.converged ? :rule : :limit)
        @test t.counts.f_calls == t.counts.grad_calls == t.counts.g_calls == 2
        @test t.counts.prox_calls == t.counts.rejected_trials == 0
    end

    stop = solve!(Float32[0], f, g, method; stopping=rule)
    counts = termination(stop).counts
    for (make_limit, used) in ((MaxObjectiveEvaluations, counts.f_calls),
                               (MaxGradientEvaluations, counts.grad_calls))
        for n in (used - 1, used)
            cap = make_limit(n)
            r = solve!(Float32[0], f, g, method; stopping=rule, limits=cap)
            t = termination(r)
            passes = n == used
            @test r.iterations == stop.iterations == 1 && r.minimizer == stop.minimizer
            @test t.reached_evaluation_limits == (cap,) && t.limit_reached
            @test t.reason === (passes ? :rule : :limit) && r.converged == passes
            @test statuses(r) == (passes ? :pass : :not_checked,)
        end
    end
end

@testset "Dual gap schedule and accepted trajectory" begin
    f, g, method = scalar_loss(Float32), NormL1(1f0), pgd()
    rule = DualGap(rtol=1e-6)
    bare = solve!(Float32[0], f, g, method; stopping=rule)
    scheduled = solve!(Float32[0], f, g, method; stopping=Every(1, rule))
    @test bare.iterations == scheduled.iterations == 1 && bare.converged && scheduled.converged
    @test bare.minimizer == scheduled.minimizer && bare.minimum === scheduled.minimum
    t = termination(bare)
    @test isequal(termination(scheduled), (; t..., observations=((; only(t.observations)..., interval=1),)))

    for cap in (MaxIterations(2), MaxIterations(3), MaxProximalEvaluations(2))
        r = solve!(Float32[0], f, g, method; stopping=Every(2, rule), limits=cap)
        t, o = termination(r), gap_observation(r)
        passes = cap == MaxIterations(3)
        @test r.iterations == 2 && r.minimizer == Float32[1]
        @test r.converged == passes && t.limit_reached == !passes
        @test t.reason === (passes ? :rule : :limit)
        @test o.name === :DualGap && o.interval == 2 && o.status === (passes ? :pass : :not_checked)
    end

    at_one = UserStop(c -> c.iteration == 1)
    r = solve!(Float32[0], f, g, method;
               stopping=AnyOf(AllOf(at_one, rule, Every(2, rule)), at_one))
    @test r.iterations == 1 && !r.converged && termination(r).winning_branch == ((2,),)
    @test statuses(r) == (:pass, :pass, :not_checked, :pass)

    f = LeastSquaresLoss(Float32[1, 1], Float32[0.5 0; 0 2])
    g = NormL1(0.125f0)
    options = ProximalOptions(store_trace=true, extended_trace=true)
    limit = MaxIterations(6)
    plain = solve!(zeros(Float32, 2), f, g, method, options; limits=limit)
    measured = solve!(zeros(Float32, 2), f, g, method, options; limits=limit,
                stopping=AllOf(Every(2, DualGap(rtol=2)), UserStop(_ -> false)))
    @test plain.iterations == measured.iterations == 6
    @test plain.minimizer == measured.minimizer && plain.minimum === measured.minimum
    @test [entry.metadata["x"] for entry in plain.trace] ==
          [entry.metadata["x"] for entry in measured.trace]
    a, b = termination(plain).counts, termination(measured).counts
    @test a.prox_calls == b.prox_calls && a.backtrack_steps == b.backtrack_steps
    @test a.rejected_trials == b.rejected_trials > 0
    @test b.f_calls - a.f_calls == b.grad_calls - a.grad_calls == b.g_calls - a.g_calls == 3
end

@testset "Dual gap validates the route before initialization" begin
    for rtol in (-1, Inf, NaN, big(typemax(Int))^100)
        @test_throws ArgumentError DualGap(rtol=rtol)
    end
    f, method = scalar_loss(Float32), pgd()
    gap = DualGap(rtol=1e-6)
    @test_throws ArgumentError Every(0, gap)
    @test_throws ArgumentError Every(2, Every(2, gap))

    for (x, loss, g, solver, limit) in (
        (Float32[1], f, NormL1(0f0), method, MaxIterations(0)),
        (Float32[1], f, NormL1(0.1), method, MaxIterations(0)),
        (Float32[1], f, NormL1(1), method, MaxIterations(0)),
        (Float32[1], f, NormL1(1f0, Float32[1]), method, MaxIterations(0)),
        (Float32[1], f, ElasticNet(1f0, 0f0), method, MaxIterations(0)),
        (Float32[1], f, NormLinf(1f0), method, MaxIterations(0)),
        (Float32[1], 2f0 * f, NormL1(1f0), method, MaxIterations(0)),
        ([1.0], scalar_loss(Float64), NormL1(1.0), method, MaxIterations(0)),
        (ones(Float32, 1, 2), LeastSquaresLoss(ones(Float32, 1, 2), ones(Float32, 1, 1)),
         NormL1(1f0), method, MaxIterations(0)),
        (Float32[1], f, NormL1(1f0), AccProxGradDescent(), MaxIterations(0)),
        (Float32[1], f, NormL1(1f0), CDSolver(order=:cyclic), MaxPasses(0)),
        (Float32[1], SqrNormL2(1f0, Float32[2]), NormL1(1f0), ADMMSolver(), MaxIterations(0)),
    )
        before = copy(x)
        @test_throws ArgumentError solve!(x, loss, g, solver;
            stopping=AnyOf(UserStop(_ -> true), Every(2, gap)), limits=limit)
        @test x == before
    end
    @test solve!(Float32[1], f, NormL1(1.0), method; stopping=gap).converged

    level = nextfloat(0f0)
    r = solve!(Float32[0], scalar_loss(Float32, level), NormL1(Float64(level)), method; stopping=gap)
    @test r.converged && r.iterations == 0 && gap_observation(r).value <= 1e-12
end

@testset "Dual gap rejects a flushing floating-point mode" begin
    previous = Base.get_zero_subnormals()
    try
        if Base.set_zero_subnormals(true)
            rule = AnyOf(DualGap(rtol=1e-6), UserStop(_ -> true))
            r = solve!(Float32[1], scalar_loss(Float32), NormL1(1f0), pgd(); stopping=rule)
            t, o = termination(r), gap_observation(r)
            @test t.reason === :user && r.iterations == 0 && !r.converged
            @test o.status === :invalid && o.threshold === 1e-6 && ismissing(o.value)
            @test t.counts.f_calls == t.counts.grad_calls == t.counts.g_calls == 1
        end
    finally
        Base.set_zero_subnormals(previous)
    end
    @test Base.get_zero_subnormals() == previous
end

end
