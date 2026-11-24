module PGDEvaluationLimitsTest

using Test, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

scalar_loss(::Type{T}, a, y=1) where {T} = LeastSquaresLoss(T[y], fill(T(a), 1, 1))
pgd(β=0.5) = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0, β=β))
budget_types() = (MaxObjectiveEvaluations, MaxGradientEvaluations, MaxProximalEvaluations)

@testset "Evaluation budget validation" begin
    for budget in budget_types()
        @test budget(big(1)).n == 1
        @test_throws ArgumentError budget(-1)
        @test_throws ArgumentError budget(big(typemax(Int)) + 1)
    end
    f, g, method = scalar_loss(Float64, 1), NormL1(0.0), pgd()
    x = [0.25]
    cap = MaxObjectiveEvaluations(0)
    for limits in ((), [cap], (cap, :unknown), (cap, MaxObjectiveEvaluations(1)),
                   (MaxIterations(0), MaxIterations(1)), (cap, MaxPasses(0)))
        @test_throws ArgumentError solve!(x, f, g, method; limits)
    end
    @test_throws ArgumentError solve!(x, f, g, method, ProximalOptions(maxiter=3);
                                      limits=(cap, MaxIterations(2)))
    for options in (ProximalOptions(f_calls_limit=1), ProximalOptions(grad_calls_limit=1),
                    ProximalOptions(prox_calls_limit=1))
        @test_throws ArgumentError solve!(x, f, g, method, options; limits=cap)
    end
    @test_throws ArgumentError solve!(x, f, g, method;
        stopping=AnyOf(UserStop(_ -> true), AllOf(ObjectiveChange(), cap)),
        limits=MaxIterations(0))
    @test_throws ArgumentError solve!(x, f, g, AccProxGradDescent(); limits=cap)
    @test_throws ArgumentError solve!(x, f, g, CDSolver(order=:cyclic, momentum=false); limits=cap)
    @test_throws ArgumentError solve!(x, SqrNormL2(1.0, [1.0]), g, ADMMSolver(); limits=cap)
    @test_throws ArgumentError solve!(x, LogisticLoss([1.0], ones(1, 1)), g, method; limits=cap)
    @test x == [0.25]

    X = ones(1, 1)
    Y = ones(1, 2)
    B = zeros(1, 2)
    @test_throws ArgumentError solve!(B, LeastSquaresLoss(Y, X), g, method; limits=cap)
    @test B == zeros(1, 2)
end

@testset "Zero and initialization caps ($T)" for T in (Float32, Float64)
    f, g, method = scalar_loss(T, 1), NormL1(zero(T)), pgd()
    rule = UserStop(_ -> error("a capped checkpoint must skip user predicates"))
    # Evaluating the loss here would overflow in working precision.
    x = T[floatmax(T) / 2]
    for budget in budget_types()
        cap = budget(0)
        for limits in (cap, (MaxIterations(0), cap))
            r = solve!(x, f, g, method; stopping=rule, limits)
            t = termination(r)
            @test r.minimizer === x && x == T[floatmax(T) / 2] && r.minimum === missing
            @test t.iteration == 0 && t.reason === :limit && !t.satisfied && !r.converged
            @test t.limit_reached && PS.call_limit_reached(r)
            @test PS.iteration_limit_reached(r) == (limits isa Tuple)
            @test t.evaluation_limits === t.reached_evaluation_limits === (cap,)
            @test only(t.observations).status === :not_checked && all(iszero, values(t.counts))
        end
    end
    # The positive budget permits the fused initialization and its penalty value.
    for budget in (MaxObjectiveEvaluations, MaxGradientEvaluations)
        cap = budget(1)
        r = solve!(T[0], f, g, method; stopping=rule, limits=cap)
        t = termination(r)
        @test r.minimum === T(0.5) && r.minimizer == T[0] && t.iteration == 0
        @test t.reason === :limit && t.limit_reached && !t.satisfied
        @test PS.call_limit_reached(r) && !PS.iteration_limit_reached(r)
        @test t.evaluation_limits === t.reached_evaluation_limits === (cap,)
        @test only(t.observations).status === :not_checked
        @test t.counts == (f_calls=1, grad_calls=1, g_calls=1, prox_calls=0,
                           backtrack_steps=0, rejected_trials=0)
    end
end

@testset "Rejected and incomplete value-mode trials ($T)" for T in (Float32, Float64)
    f, g, method = scalar_loss(T, 2), NormL1(zero(T)), pgd()
    # The first trial is x=2 and is rejected. The second trial at x=1/2
    # passes the line search and can be kept once its gradient is available.
    for (cap, calls, trials) in ((MaxObjectiveEvaluations(2), 2, 1),
                                 (MaxObjectiveEvaluations(3), 3, 2),
                                 (MaxProximalEvaluations(1), 2, 1))
        x = T[0]
        result = solve!(x, f, g, method; stopping=ObjectiveChange(atol=5), limits=cap)
        t = termination(result)
        @test t.reason === :limit && t.iteration == 0 && t.limit_reached && !t.satisfied
        @test result.minimizer === x && x == T[0] && result.minimum === T(0.5)
        @test only(t.observations).status === :not_checked && isempty(result.trace)
        @test t.reached_evaluation_limits === (cap,) && PS.call_limit_reached(result)
        @test t.counts == (f_calls=calls, grad_calls=1, g_calls=1 + trials, prox_calls=trials,
                           backtrack_steps=trials, rejected_trials=trials)
    end

    visited = Int[]
    rule = AnyOf(UserStop(c -> (push!(visited, c.iteration); false)),
                 ScaledKKT(rtol=0.0), IterateChange(atol=1), ObjectiveChange(atol=0.5))
    prox, grad, objective = MaxProximalEvaluations(2), MaxGradientEvaluations(2), MaxObjectiveEvaluations(4)
    r = solve!(T[0], f, g, method; stopping=rule, limits=(prox, MaxIterations(1), grad, objective))
    t = termination(r)
    @test r.minimizer == T[0.5] && r.minimum === zero(T) && t.iteration == 1
    @test t.satisfied && t.reason === :rule && !r.converged && t.limit_reached
    @test PS.call_limit_reached(r) && PS.iteration_limit_reached(r)
    @test t.evaluation_limits === t.reached_evaluation_limits === (prox, grad, objective)
    @test map(o -> o.status, t.observations) == (:not_checked, :not_checked, :not_checked, :pass)
    @test t.winning_branch == ((4,),) && visited == [0]
    @test t.counts == (f_calls=4, grad_calls=2, g_calls=3, prox_calls=2,
                       backtrack_steps=2, rejected_trials=1)
end

@testset "Budget refusal within gradient-mode backtracking ($T)" for T in (Float32, Float64)
    f, g, method = T(0.5) * scalar_loss(T, 2), NormL1(zero(T)), pgd()
    # The first trial leaves the smooth value unchanged and switches modes.
    # The second needs a gradient in the mode selected on the first trial.
    for (cap, grad, trials, decisions) in ((2, 1, 1, 0), (4, 2, 2, 1))
        r = solve!(T[0], f, g, method; limits=MaxObjectiveEvaluations(cap))
        t = termination(r)
        @test t.reason === :limit && t.iteration == 0 && r.minimizer == T[0] && r.minimum === T(0.25)
        @test t.counts == (f_calls=cap, grad_calls=grad, g_calls=1 + trials, prox_calls=trials,
                           backtrack_steps=decisions, rejected_trials=trials)
    end
    # The switch refresh uses the last gradient call before the first
    # trial is rejected. No retry can start once that cap is reached.
    r = solve!(T[0], f, g, method; limits=MaxGradientEvaluations(2))
    t = termination(r)
    @test t.reason === :limit && t.iteration == 0 && r.minimizer == T[0] && r.minimum === T(0.25)
    @test t.counts == (f_calls=3, grad_calls=2, g_calls=2, prox_calls=1,
                       backtrack_steps=1, rejected_trials=1)

    # The first step 3 -> 1 switches modes at equal smooth values. In the
    # next trial the coordinate is unchanged and the fused refresh is refused.
    f, g = scalar_loss(T, 1, 2), NormL1(one(T))
    r = solve!(T[3], f, g, method; limits=MaxObjectiveEvaluations(4))
    t = termination(r)
    @test r.minimizer == T[1] && r.minimum === T(1.5) && t.iteration == 1 && t.reason === :limit
    @test t.counts == (f_calls=4, grad_calls=2, g_calls=3, prox_calls=2,
                       backtrack_steps=1, rejected_trials=1)
end

@testset "Interruption preserves the accepted checkpoint ($T)" for T in (Float32, Float64)
    f, g, method = scalar_loss(T, 2), NormL1(zero(T)), pgd(0.125)
    options = ProximalOptions(store_trace=true, extended_trace=true)
    visited = Int[]
    rule = AnyOf(ObjectiveChange(atol=0.125), IterateChange(atol=0.125),
                 UserStop(c -> (push!(visited, c.iteration); false)))
    x = T[0]
    r = solve!(x, f, g, method, options; stopping=rule, limits=MaxObjectiveEvaluations(5))
    t = termination(r)
    # One rejection, one complete step to x=1/4, and a trial at x=3/8 whose
    # gradient cannot be computed. The accepted trace and observations survive.
    @test r.minimizer === x && x == T[0.25] && r.minimum === T(0.125)
    @test t.iteration == 1 && t.reason === :limit && t.limit_reached && !t.satisfied
    @test PS.call_limit_reached(r) && !PS.iteration_limit_reached(r)
    @test visited == [0, 1] && map(o -> o.status, t.observations) == (:fail, :fail, :fail)
    @test map(o -> o.value, t.observations) == (0.375, 0.25, false)
    @test length(r.trace) == 1
    @test only(r.trace).fg_x == r.minimum && only(r.trace).metadata["x"] == x
    @test only(r.trace).metadata["grad_f(x)"] == T[-1]
    @test t.counts == (f_calls=5, grad_calls=2, g_calls=4, prox_calls=3,
                       backtrack_steps=3, rejected_trials=2)

    iter = MaxIterations(5)
    baseline = solve!(T[0], f, g, method, options; limits=iter)
    capped = solve!(T[0], f, g, method, options;
                   limits=(MaxObjectiveEvaluations(100), MaxGradientEvaluations(100),
                           iter, MaxProximalEvaluations(100)))
    @test capped.minimizer == baseline.minimizer && capped.minimum === baseline.minimum
    @test termination(capped).counts == termination(baseline).counts
    @test termination(capped).reason === :limit && capped.iterations == baseline.iterations == 5
    @test PS.iteration_limit_reached(capped) && !PS.call_limit_reached(capped)
    @test isempty(termination(capped).reached_evaluation_limits)
    @test map(s -> s.metadata, capped.trace) == map(s -> s.metadata, baseline.trace)
end

end
