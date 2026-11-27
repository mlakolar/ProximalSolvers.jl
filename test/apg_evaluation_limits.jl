module APGEvaluationLimitsTest

using Test, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

@testset "APG validates evaluation budgets before initialization" begin
    f, g, method = LeastSquaresLoss([2.0], ones(1, 1)), NormL1(1.0), AccProxGradDescent()
    x = [0.25]
    cap = MaxObjectiveEvaluations(0)
    for limits in ((), [cap], (cap, MaxObjectiveEvaluations(1)), (cap, MaxPasses(1)))
        @test_throws ArgumentError solve!(x, f, g, method; limits)
    end
    @test_throws ArgumentError solve!(x, f, g, method, ProximalOptions(grad_calls_limit=1); limits=cap)
    @test_throws ArgumentError solve!(x, f, g, method, ProximalOptions(maxiter=3);
                                      limits=(cap, MaxIterations(2)))
    @test_throws ArgumentError solve!(x, f, g, method;
                                      stopping=AnyOf(UserStop(_ -> true), cap), limits=MaxIterations(0))
    @test_throws ArgumentError solve!(x, LogisticLoss([1.0], ones(1, 1)), g, method; limits=cap)
    for solver in (ProximalGradientDescent(), method), n in (0, 1)
        @test_throws ArgumentError solve!(x, f, IndBallL1(1.0), solver;
                                         feasibility=NumericalFeasibility(),
                                         limits=MaxObjectiveEvaluations(n))
    end
    @test x == [0.25]
    B = fill(0.25, 1, 2)
    r = solve!(B, LeastSquaresLoss(ones(1, 2), ones(1, 1)), g, method; limits=cap)
    @test r.minimizer === B && r.minimum === missing
    @test all(iszero, values(termination(r).counts))
    @test B == fill(0.25, 1, 2)
end

@testset "APG initialization and first search admission ($T, scaled=$scaled)" for
        T in (Float32, Float64), scaled in (false, true)
    f = scaled ? T(0.25) * LeastSquaresLoss(T[2], fill(T(2), 1, 1)) :
                 LeastSquaresLoss(T[1], ones(T, 1, 1))
    g, method = NormL1(zero(T)), AccProxGradDescent(α=0.75, β=0.375)
    skip = UserStop(_ -> error("a capped initial checkpoint must skip user predicates"))
    x = T[floatmax(T) / 2]
    for cap in (MaxObjectiveEvaluations(0), MaxGradientEvaluations(0), MaxProximalEvaluations(0))
        r = solve!(x, f, g, method; stopping=skip, limits=cap)
        t = termination(r)
        @test r.minimizer === x && x == T[floatmax(T) / 2] && r.minimum === missing
        @test t.reason === :limit && t.iteration == 0 && t.limit_reached && !t.satisfied
        @test PS.call_limit_reached(r) && !PS.iteration_limit_reached(r)
        @test t.evaluation_limits === t.reached_evaluation_limits === (cap,)
        @test only(t.observations).status === :not_checked && all(iszero, values(t.counts))
    end

    for (cap, grads, trials) in ((1, 0, 0), (2, 1, 0), (3, 1, 1))
        limit = MaxObjectiveEvaluations(cap)
        r = solve!(T[0], f, g, method; limits=limit)
        t = termination(r)
        @test t.reason === :limit && t.iteration == 0 && t.limit_reached && !t.satisfied
        @test r.minimizer == T[0] && r.minimum === T(0.5)
        @test t.reached_evaluation_limits === (limit,)
        @test t.counts == (f_calls=cap, grad_calls=grads, g_calls=trials + 1,
                           prox_calls=trials, backtrack_steps=trials, rejected_trials=trials)
    end
    r = solve!(T[0], f, g, method; stopping=skip, limits=MaxObjectiveEvaluations(1))
    @test only(termination(r).observations).status === :not_checked

    # The search can reject a trial and retry with the gradient it already formed.
    grad = MaxGradientEvaluations(1)
    r = solve!(T[0], f, g, method; limits=grad)
    t = termination(r)
    @test r.minimizer == T[0.5] && r.minimum === T(0.125)
    @test t.reason === :limit && t.iteration == 1 && t.reached_evaluation_limits === (grad,)
    @test t.counts == (f_calls=4, grad_calls=1, g_calls=3, prox_calls=2,
                       backtrack_steps=2, rejected_trials=1)
    prox, value = MaxProximalEvaluations(2), MaxObjectiveEvaluations(4)
    r = solve!(T[0], f, g, method; stopping=ObjectiveChange(atol=0.5),
               limits=(grad, MaxIterations(1), prox, value))
    t = termination(r)
    @test t.reason === :rule && t.satisfied && !r.converged && t.limit_reached && t.iteration == 1
    @test t.evaluation_limits === t.reached_evaluation_limits === (grad, prox, value)
    @test PS.call_limit_reached(r) && PS.iteration_limit_reached(r)
end

@testset "APG interruption after a momentum trial ($T)" for T in (Float32, Float64)
    # Only the first column acts in the recurrence. Its curvature is below the
    # initial L = 1, and momentum overshoots enough at step 7 to require a restart.
    f = LeastSquaresLoss(T[1, 0], T[0.5 0; 0 2])
    g, method = NormL1(zero(T)), AccProxGradDescent(α=1.0, β=0.5)
    options = ProximalOptions(store_trace=true, extended_trace=true)
    baseline = solve!(zeros(T, 2), f, g, method, options; limits=MaxIterations(6))
    # First refuse the fresh gradient after the discarded extrapolated trial.
    # The last case can form that gradient but has no room for the retry's value.
    for (cap, f_calls, grad_calls) in ((MaxGradientEvaluations(7), 15, 7),
                                     (MaxProximalEvaluations(7), 15, 7),
                                     (MaxObjectiveEvaluations(16), 16, 8))
        visited = Int[]
        rule = AnyOf(ObjectiveChange(atol=0), UserStop(c -> (push!(visited, c.iteration); false)))
        x = zeros(T, 2)
        r = solve!(x, f, g, method, options; stopping=rule, limits=cap)
        t = termination(r)
        @test r.minimizer === x && x == baseline.minimizer && r.minimum === baseline.minimum
        @test !r.f_increased && t.iteration == 6 && t.reason === :limit && !t.satisfied
        @test t.limit_reached && t.reached_evaluation_limits === (cap,)
        @test visited == collect(0:6) && all(o -> o.status === :fail, t.observations)
        @test length(r.trace) == 6 && r.trace[end].fg_x == r.minimum
        @test map(s -> s.metadata, r.trace) == map(s -> s.metadata, baseline.trace)
        @test t.counts == (; f_calls, grad_calls, g_calls=8, prox_calls=7,
                           backtrack_steps=7, rejected_trials=1)
    end

    # With the remaining value, the restarted update is accepted.
    limit = MaxObjectiveEvaluations(17)
    r = solve!(zeros(T, 2), f, g, method; limits=limit)
    t = termination(r)
    @test t.reason === :limit && t.iteration == 7 && r.minimum < baseline.minimum
    @test t.counts == (f_calls=17, grad_calls=8, g_calls=9, prox_calls=8,
                       backtrack_steps=8, rejected_trials=1)
end

@testset "APG budget exhausted by a stationarity check ($T)" for T in (Float32, Float64)
    f = LeastSquaresLoss(T[0], ones(T, 1, 1))
    g, method = NormL1(one(T)), AccProxGradDescent(α=1.0)
    kkt, different = ScaledKKT(rtol=0), ScaledKKT(rtol=1e-6)
    for limit in (MaxObjectiveEvaluations(2), MaxGradientEvaluations(1))
        for (other, reason, status) in ((kkt, :rule, :pass), (different, :limit, :not_checked))
            r = solve!(T[0], f, g, method; stopping=AllOf(kkt, other), limits=limit)
            t = termination(r)
            @test r.converged == t.satisfied == (reason === :rule)
            @test t.reason === reason && t.iteration == 0 && t.limit_reached
            @test t.reached_evaluation_limits === (limit,)
            @test map(o -> o.status, t.observations) == (:pass, status)
            @test t.counts == (f_calls=2, grad_calls=1, g_calls=1, prox_calls=0,
                               backtrack_steps=0, rejected_trials=0)
        end
    end

    skip = UserStop(_ -> error("a checkpoint that reached the cap must skip later predicates"))
    r = solve!(T[1], f, g, method; stopping=AnyOf(kkt, skip), limits=MaxGradientEvaluations(1))
    t = termination(r)
    @test t.reason === :limit && t.iteration == 0 && !t.satisfied
    @test map(o -> o.status, t.observations) == (:fail, :not_checked)
    @test t.counts == (f_calls=2, grad_calls=1, g_calls=1, prox_calls=0,
                       backtrack_steps=0, rejected_trials=0)

    # The gradient used to take the step differs from the gradient at the accepted point.
    f = LeastSquaresLoss(T[0, 0, 1], T[0.875 0; 0 1; 0 0])
    g = NormL1(T(0.5))
    rule = AllOf(UserStop(c -> c.iteration == 1), kkt, kkt, ObjectiveChange(atol=1))
    r = solve!(T[1, 0], f, g, method; stopping=rule,
               limits=(MaxObjectiveEvaluations(4), MaxGradientEvaluations(2)))
    t = termination(r)
    @test r.minimizer == T[0, 0] && r.minimum === T(0.5) && r.converged
    @test t.iteration == 1 && t.reason === :rule && t.satisfied && t.limit_reached
    @test t.winning_branch == ((1,), (2,), (3,), (4,))
    @test t.reached_evaluation_limits === (MaxObjectiveEvaluations(4), MaxGradientEvaluations(2))
    @test map(o -> o.status, t.observations) == (:pass, :pass, :pass, :pass)
    @test t.counts == (f_calls=4, grad_calls=2, g_calls=2, prox_calls=1,
                       backtrack_steps=1, rejected_trials=0)

    r = solve!(T[1, 0], f, g, method; stopping=AnyOf(kkt, ObjectiveChange(atol=1)),
               limits=MaxProximalEvaluations(1))
    t = termination(r)
    @test r.minimizer == T[0, 0] && !r.converged && t.satisfied && t.reason === :rule
    @test t.winning_branch == ((2,),) && map(o -> o.status, t.observations) == (:not_checked, :pass)
    @test t.counts.grad_calls == 2 # initial KKT and the step's gradient at y
end

@testset "APG mathematical failure takes precedence over the evaluation budget" begin
    # The first smooth value is finite, but the first gradient overflows.
    x = Float32[0]
    f = LeastSquaresLoss(Float32[2], fill(2f38, 1, 1))
    @test_throws r"the gradient step did not produce a finite objective" solve!(
        x, f, NormL1(0f0), AccProxGradDescent(); limits=MaxGradientEvaluations(1))
    @test x == Float32[0]
end

end
