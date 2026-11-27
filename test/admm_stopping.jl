module ADMMStoppingTest

using Test, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

both_residuals() = AllOf(DualResidual(), PrimalResidual())

@testset "Completed residual evidence and cap ties ($T)" for T in (Float32, Float64)
    f, g = SqrNormL2(1, T[3]), NormL1(1)
    method = ADMMSolver(abstol=0.5, abstol_dual=0.75, reltol=0)
    z, u = T[0], T[0]
    r = solve!(z, f, g, method; u, stopping=both_residuals(), limits=MaxIterations(1))
    t = termination(r)
    @test r isa PS.ADMMStoppingResult
    @test PS.minimizer(r) === z && PS.minimum(r) === T(3.625) && z == T[0.5]
    @test r.u === u && u == T[1] && r.ρ === one(T)
    @test PS.iterations(r) == r.iterations == t.iteration == 1
    @test !PS.converged(r) && !t.satisfied && t.reason === :limit && t.limit_reached
    @test map(o -> (o.status, o.value, o.threshold), t.observations) ==
        ((:pass, 0.5, 0.75), (:fail, 1.0, 0.5))
    @test map(o -> o.name, t.observations) == (:DualResidual, :PrimalResidual)
    @test all(o -> o.evidence === :residual && ismissing(o.scale), t.observations)
    @test t.counts == (f_calls=1, g_calls=1, prox_calls=2)
    @test PS.f_calls(r) == 1 && PS.grad_calls(r) == 0 && PS.prox_calls(r) == 2
    @test PS.iteration_limit_reached(r) && occursin("limit", sprint(show, r))

    r = solve!(T[0], f, g, method; stopping=AnyOf(DualResidual(), PrimalResidual()),
               limits=MaxIterations(1))
    t = termination(r)
    @test t.reason === :rule && t.satisfied && t.limit_reached && !r.converged
    @test map(o -> o.status, t.observations) == (:pass, :not_checked)
    @test t.winning_branch == ((1,),)

    r = solve!(T[0], f, g, method, ProximalOptions(maxiter=2); stopping=both_residuals())
    t = termination(r)
    @test r.minimizer == T[1.25] && r.u == T[1] && r.minimum === T(2.78125)
    @test t.reason === :rule && t.satisfied && t.limit.n == 2 && t.limit_reached && r.converged
    @test t.winning_branch == ((1,), (2,))
    @test map(o -> (o.value, o.threshold), t.observations) == ((0.75, 0.75), (0.0, 0.5))
    @test t.counts.prox_calls == 4

    loose = ADMMSolver(abstol=1, abstol_dual=0.25, reltol=0)
    r = solve!(T[0], f, g, loose; stopping=AllOf(PrimalResidual(), PrimalResidual()))
    @test termination(r).satisfied && !r.converged && r.iterations == 1
    relative = ADMMSolver(α=1.5, abstol=0.25, abstol_dual=1, reltol=0.25)
    r = solve!(T[0], f, g, relative; stopping=both_residuals(), limits=MaxIterations(1))
    @test r.converged && r.minimizer == T[1.25] && r.u == T[1]
    @test map(o -> (o.value, o.threshold), termination(r).observations) == ((1.25, 1.25), (0.25, 0.625))
end

@testset "Zero budget, stagnation and private return ($T)" for T in (Float32, Float64)
    f, g = SqrNormL2(1, T[1]), NormL1(0)
    z, u = T[floatmax(T)/4], T[0.25]
    r = solve!(z, f, g, ADMMSolver(); u, stopping=both_residuals(), limits=MaxIterations(0))
    t = termination(r)
    @test r.minimizer === z && r.u === u && r.minimum === missing
    @test z == T[floatmax(T)/4] && u == T[0.25]
    @test t.reason === :limit && t.limit_reached && !t.satisfied && !r.converged
    @test t.iteration == 0 && all(iszero, values(t.counts))
    @test all(o -> o.status === :not_checked, t.observations)
    r = solve!(T[2], f, g, ADMMSolver(); limits=MaxIterations(0))
    @test r.u == T[0] && r.minimum === missing && isempty(termination(r).observations)

    method = ADMMSolver(ρ=T(2)^100)
    r = solve!(T[2], f, g, method; stopping=both_residuals(), limits=MaxIterations(1))
    t = termination(r)
    @test r.minimizer == T[2] && t.reason === :stalled && t.limit_reached && !t.satisfied
    @test !r.converged && PS.stagnated(r) && all(o -> o.status === :not_checked, t.observations)
    @test t.counts.prox_calls == 2
    r = solve!(T[2], f, g, method; limits=MaxIterations(2))
    @test termination(r).reason === :limit && r.iterations == 2 && PS.prox_calls(r) == 4
    r = solve!(T[1], f, g, method; stopping=both_residuals(), limits=MaxIterations(1))
    @test r.converged && termination(r).reason === :rule && r.minimum === zero(T)

    z, u = T[floatmax(T)], T[-floatmax(T)]
    @test_throws r"nonfinite x-prox argument" solve!(z, f, g, ADMMSolver(); u, limits=MaxIterations(1))
    @test z == T[floatmax(T)] && u == T[-floatmax(T)]
    z, u = T[4sqrt(floatmax(T))], T[0]
    @test_throws r"nonfinite objective" solve!(z, f, g, ADMMSolver(); u, limits=MaxIterations(1))
    @test z == T[4sqrt(floatmax(T))] && u == T[0]
end

@testset "Explicit ADMM and residual rule preflight" begin
    z, u = [0.5], [0.25]
    f, g, method = SqrNormL2(1, [3.0]), NormL1(1), ADMMSolver()
    for unsupported in (ScaledKKT(rtol=1e-6), MaxPasses(1), UserStop(_ -> true))
        @test_throws ArgumentError solve!(z, f, g, method; u,
            stopping=AnyOf(PrimalResidual(), AllOf(DualResidual(), unsupported)), limits=MaxIterations(0))
    end
    @test_throws ArgumentError solve!(z, f, g, method; u, limits=MaxPasses(1))
    @test_throws ArgumentError solve!(z, f, g, ADMMSolver(adaptive=true); u, limits=MaxIterations(0))
    @test_throws ArgumentError solve!(z, f, g, method, ProximalOptions(maxiter=2); u, limits=MaxIterations(3))
    for options in (ProximalOptions(prox_calls_limit=2), ProximalOptions(time_limit=0))
        @test_throws ArgumentError solve!(z, f, g, method, options; u, limits=MaxIterations(0))
    end
    @test_throws ArgumentError solve!(z, f, g, method; u=z, limits=MaxIterations(0))
    leastsquares = LeastSquaresLoss([3.0], ones(1, 1))
    @test_throws ArgumentError solve!(z, leastsquares, g, method; u, limits=MaxIterations(0))
    @test_throws ArgumentError solve!(ones(1, 1), LogDetLoss(ones(1, 1)), NormL1(1, ones(1, 1)),
                                      method; limits=MaxIterations(0))
    for other in (ProximalGradientDescent(), AccProxGradDescent())
        @test_throws ArgumentError solve!(z, leastsquares, g, other;
            stopping=AnyOf(UserStop(_ -> true), DualResidual()), limits=MaxIterations(0))
    end
    @test_throws ArgumentError solve!(z, leastsquares, g, CDSolver(order=:cyclic);
        stopping=PrimalResidual(), limits=MaxPasses(0))
    @test z == [0.5] && u == [0.25]
end

@testset "Fixed-budget parity and restart ($T, $α)" for T in (Float32, Float64), α in (0.5, 1, 1.5)
    f, g = SqrNormL2(1, T[3, -1]), NormL1(T(0.5))
    method = ADMMSolver(ρ=2, α=α, abstol=0, reltol=0)
    z, u = T[0, 0], T[0.25, -0.25]
    previous = solve!(copy(z), f, g, method, ProximalOptions(maxiter=4); u=copy(u))
    r = solve!(copy(z), f, g, method; u=copy(u), limits=MaxIterations(4))
    @test previous.iterations == r.iterations == 4
    @test isequal((previous.minimizer, previous.u, previous.minimum, previous.ρ),
                  (r.minimizer, r.u, r.minimum, r.ρ))
    @test termination(r).reason === :limit && PS.prox_calls(r) == 8
    first = solve!(z, f, g, method; u, limits=MaxIterations(1))
    resumed = solve!(first.minimizer, f, g, method; u=first.u, limits=MaxIterations(3))
    @test isequal((r.minimizer, r.u, r.minimum), (resumed.minimizer, resumed.u, resumed.minimum))
end

@testset "Proximal budgets admit complete ADMM pairs ($T)" for T in (Float32, Float64)
    f, g = SqrNormL2(1, T[3, -1]), NormL1(T(0.5))
    method = ADMMSolver(ρ=2, α=1.5)
    start, dual = T[0.5, -0.25], T[0.25, -0.25]
    for n in 0:7
        cap = MaxProximalEvaluations(n)
        steps = n ÷ 2
        expected = solve!(copy(start), f, g, method; u=copy(dual), limits=MaxIterations(steps))
        z, u = copy(start), copy(dual)
        r = solve!(z, f, g, method; u, limits=cap)
        t = termination(r)
        @test r.minimizer === z && r.u === u
        @test isequal((z, u, r.ρ, r.minimum),
                      (expected.minimizer, expected.u, expected.ρ, expected.minimum))
        @test t.counts == termination(expected).counts
        @test t.iteration == r.iterations == steps && PS.prox_calls(r) == 2 * steps
        @test 0 <= cap.n - PS.prox_calls(r) < 2
        @test t.reason === :limit && t.limit_reached && !t.satisfied
        @test t.evaluation_limits === t.reached_evaluation_limits === (cap,)
        @test t.limit.n == ProximalOptions().maxiter
        @test PS.call_limit_reached(r) && !PS.iteration_limit_reached(r)
    end

    cap = MaxProximalEvaluations(typemax(Int))
    r = solve!(copy(start), f, g, method; u=copy(dual), limits=(MaxIterations(1), cap))
    t = termination(r)
    @test t.reason === :limit && t.iteration == t.limit.n == 1 && t.limit_reached
    @test t.evaluation_limits === (cap,) && isempty(t.reached_evaluation_limits)
    @test PS.iteration_limit_reached(r) && !PS.call_limit_reached(r)

    # Even forming the first proximal argument would overflow at this start.
    f = SqrNormL2(1, T[3])
    z, u = T[floatmax(T)], T[-floatmax(T)]
    r = solve!(z, f, g, method; u, stopping=both_residuals(), limits=MaxProximalEvaluations(1))
    t = termination(r)
    @test r.minimizer === z && r.u === u && r.ρ === T(2)
    @test z == T[floatmax(T)] && u == T[-floatmax(T)] && ismissing(r.minimum)
    @test t.iteration == 0 && all(iszero, values(t.counts))
    @test all(o -> o.status === :not_checked, t.observations)
    @test_throws r"nonfinite x-prox argument" solve!(z, f, g, method; u, limits=MaxProximalEvaluations(2))
    @test z == T[floatmax(T)] && u == T[-floatmax(T)]
end

@testset "ADMM residual and evaluation-cap ties ($T)" for T in (Float32, Float64)
    f, g = SqrNormL2(1, T[3]), NormL1(1)
    method = ADMMSolver(abstol=1, abstol_dual=0.5, reltol=0)
    for (limits, call_reached, iteration_reached) in (
        (MaxProximalEvaluations(3), true, false),
        (MaxProximalEvaluations(5), false, false),
        ((MaxProximalEvaluations(3), MaxIterations(1)), true, true),
        ((MaxIterations(1), MaxProximalEvaluations(5)), false, true),
    )
        r = solve!(T[0], f, g, method; stopping=both_residuals(), limits)
        t = termination(r)
        @test r.iterations == 1 && r.minimizer == T[0.5] && r.u == T[1]
        @test r.minimum === T(3.625) && r.converged
        @test t.reason === :rule && t.satisfied && t.limit_reached == (call_reached || iteration_reached)
        @test PS.call_limit_reached(r) == call_reached
        @test PS.iteration_limit_reached(r) == iteration_reached
        @test map(o -> (o.status, o.value, o.threshold), t.observations) ==
            ((:pass, 0.5, 0.5), (:pass, 1.0, 1.0))
        @test t.counts == (f_calls=1, g_calls=1, prox_calls=2)
    end

    f, g = SqrNormL2(1, T[1]), NormL1(0)
    cap = MaxProximalEvaluations(3)
    r = solve!(T[2], f, g, ADMMSolver(ρ=T(2)^100); stopping=both_residuals(), limits=cap)
    t = termination(r)
    @test r.minimizer == T[2] && t.reason === :stalled && PS.stagnated(r)
    @test t.reached_evaluation_limits === (cap,) && t.limit_reached && !t.satisfied
    @test PS.call_limit_reached(r) && !PS.iteration_limit_reached(r)
    @test PS.prox_calls(r) == 2 && all(o -> o.status === :not_checked, t.observations)

    z, u = T[4sqrt(floatmax(T))], T[0.25]
    @test_throws r"nonfinite objective" solve!(z, f, g, ADMMSolver(); u, limits=cap)
    @test z == T[4sqrt(floatmax(T))] && u == T[0.25]
end

@testset "ADMM proximal budget preflight" begin
    z, u = [0.5], [0.25]
    f, g, method = SqrNormL2(1, [3.0]), NormL1(1), ADMMSolver()
    cap = MaxProximalEvaluations(1)
    for limits in ((), [cap], (cap, cap), (MaxIterations(0), MaxIterations(1)),
                   (cap, MaxObjectiveEvaluations(0)), (cap, MaxGradientEvaluations(0)), (cap, MaxPasses(0)))
        @test_throws ArgumentError solve!(z, f, g, method; u, limits)
    end
    for options in (ProximalOptions(prox_calls_limit=1), ProximalOptions(time_limit=0))
        @test_throws ArgumentError solve!(z, f, g, method, options; u, limits=cap)
    end
    @test_throws ArgumentError solve!(z, f, g, method, ProximalOptions(maxiter=2);
                                      u, limits=(cap, MaxIterations(1)))
    @test_throws ArgumentError solve!(z, f, g, method; u, stopping=AllOf(PrimalResidual(), cap), limits=cap)
    @test_throws ArgumentError solve!(z, f, g, method; u=z, limits=cap)
    @test_throws ArgumentError solve!(z, f, g, ADMMSolver(adaptive=true); u, limits=cap)
    @test_throws ArgumentError solve!(z, LeastSquaresLoss([3.0], ones(1, 1)), g, method; u, limits=cap)
    matrix = ones(1, 1)
    @test_throws ArgumentError solve!(matrix, LogDetLoss(ones(1, 1)), NormL1(1, ones(1, 1)),
                                      method; limits=cap)
    @test z == [0.5] && u == [0.25] && matrix == ones(1, 1)
end

end
