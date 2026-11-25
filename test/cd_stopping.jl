module CDStoppingTest

using Test, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

function example(::Type{T}) where T
    f = LeastSquaresLoss(T[0, 2.5], T[1 1; 0 1])
    f, NormL1(T(0.5)), CDSolver(order=:cyclic, momentum=false)
end

@testset "Full and active passes with distinct stopping evidence ($T)" for T in (Float32, Float64)
    f, g, method = example(T)
    x = zeros(T, 2)
    checkpoints = Tuple{Int,T}[]
    watch(c) = (push!(checkpoints, (c.iteration, c.objective)); false)
    rule = AnyOf(UserStop(watch), ObjectiveChange())
    r = solve!(x, f, g, method; stopping=rule, limits=MaxPasses(2))
    t = termination(r)
    @test r isa PS.CoordinateDescentStoppingResult
    @test PS.minimizer(r) === x && x == T[0, 1] && PS.minimum(r) === T(2.125)
    @test PS.iterations(r) == r.passes == t.iteration == 2
    @test !PS.converged(r) && !r.converged && !t.satisfied && t.reason === :limit
    @test t.limit isa MaxPasses && t.limit.n == 2 && t.limit_reached
    @test t.winning_branch === nothing
    @test map(o -> o.status, t.observations) == (:not_checked, :not_checked)
    @test checkpoints == [(0, T(3.125)), (1, T(2.125))]
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=3, objective_evaluations=3)
    # At the returned point the inactive first coordinate has |X₁'r| = 1 > 0.5.
    @test abs((f.Y - f.X * x)[1]) == one(T)
    @test occursin("Coordinate Descent", summary(r))
    @test occursin("reason=limit", sprint(show, r))

    r = solve!(zeros(T, 2), f, g, method; stopping=ObjectiveChange(), limits=MaxPasses(2))
    t = termination(r)
    @test t.reason === :limit && t.observations[1].status === :not_checked
    @test r.minimum === T(2.125) && t.counts.objective_evaluations == 2

    r = solve!(zeros(T, 2), f, g, method;
               stopping=ObjectiveChange(atol=100), limits=MaxPasses(1))
    t = termination(r)
    @test t.reason === :limit && t.observations[1].status === :not_checked
    @test r.minimum === T(2.125) && t.counts.objective_evaluations == 1

    r = solve!(zeros(T, 2), f, g, method;
               stopping=ObjectiveChange(atol=3/16), limits=MaxPasses(3))
    t = termination(r)
    @test r.minimizer == T[-0.5, 1.25] && r.minimum === T(1.9375)
    @test t.reason === :rule && t.satisfied && t.limit_reached && t.iteration == 3
    @test t.winning_branch == ((),) && t.observations[1].value == 3/16
    @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=5, objective_evaluations=2)

    r = solve!(zeros(T, 2), f, g, method; limits=MaxPasses(3))
    t = termination(r)
    @test r.minimizer == T[-0.5, 1.25] && r.minimum === T(1.9375)
    @test t.reason === :limit && !t.satisfied && t.limit_reached && t.iteration == 3
    @test isempty(t.observations) && t.winning_branch === nothing
    @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=5, objective_evaluations=1)
end

@testset "Composition and the initial checkpoint ($T)" for T in (Float32, Float64)
    f, g, method = example(T)
    rule = AllOf(UserStop(c -> c.iteration == 3), ObjectiveChange(atol=3/16))
    r = solve!(zeros(T, 2), f, g, method; stopping=rule, limits=MaxPasses(4))
    t = termination(r)
    @test t.reason === :rule && !t.limit_reached && t.winning_branch == ((1,), (2,))
    @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=5, objective_evaluations=4)
    @test (t.observations[2].value, t.observations[2].threshold) == (3/16, 3/16)

    rule = AnyOf(ObjectiveChange(atol=100), UserStop(c -> c.iteration == 2))
    r = solve!(zeros(T, 2), f, g, method; stopping=rule, limits=MaxPasses(3))
    t = termination(r)
    @test r.passes == 2 && t.reason === :user && t.winning_branch == ((2,),)
    @test map(o -> o.status, t.observations) == (:not_checked, :pass)
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=3, objective_evaluations=3)

    user = UserStop(c -> c.iteration == 0 && c.objective === T(3.125))
    r = solve!(zeros(T, 2), f, g, method; stopping=AnyOf(ObjectiveChange(), user))
    t = termination(r)
    @test r.passes == 0 && r.minimum === T(3.125) && t.reason === :user && !r.converged
    @test map(o -> o.status, t.observations) == (:not_checked, :pass)
    @test t.counts == (full_passes=0, active_passes=0, coordinate_visits=0, objective_evaluations=1)

    equal = CDSolver(order=:cyclic, maxpasses=3)
    r = solve!(zeros(T, 2), T(2) * f, NormL1(one(T)), equal;
               stopping=ObjectiveChange(atol=3/8), limits=MaxPasses(3))
    @test r.minimum === T(3.875) && termination(r).limit_reached && termination(r).satisfied
end

@testset "An active objective cannot replace the full-sweep predecessor ($T)" for T in (Float32, Float64)
    f = LeastSquaresLoss(T[2, 1], T[1 1; 0 1])
    g = NormL1(T(0.5))
    method = CDSolver(order=:cyclic, relative=false, tol=1)
    seen = Tuple{Int,T}[]
    observe(c) = (push!(seen, (c.iteration, c.objective)); false)
    rule = AnyOf(ObjectiveChange(atol=1/16), UserStop(observe))
    r = solve!(zeros(T, 2), f, g, method; stopping=rule, limits=MaxPasses(3))
    t = termination(r)
    @test seen == [(0, T(2.5)), (1, T(1.125)), (2, T(0.9375))]
    @test r.minimizer == T[0.75, 0.875] && r.minimum === T(0.890625)
    @test t.reason === :limit && t.limit_reached && !t.satisfied
    @test map(o -> o.status, t.observations) == (:fail, :not_checked)
    @test t.observations[1].value == 15/64 && t.observations[1].threshold == 1/16
    @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=6, objective_evaluations=4)
end

@testset "Zero cap, conflicts and all-leaf preflight" begin
    f, g, _ = example(Float64)
    rng = Xoshiro(27)
    method = CDSolver(rng=rng, momentum=false)
    reference = copy(rng)
    calls = Ref(0)
    user = UserStop(c -> (calls[] += 1; true))
    x = [1.0, 0.0]
    r = solve!(x, f, g, method; stopping=user, limits=MaxPasses(0))
    t = termination(r)
    @test r.minimizer === x && x == [1, 0] && r.minimum === missing && r.passes == 0
    @test t.reason === :limit && t.limit_reached && !r.converged && !t.satisfied
    @test t.observations[1].status === :not_checked && all(iszero, values(t.counts))
    @test occursin("missing", sprint(show, r))
    r = solve!(x, f, g, CDSolver(order=:cyclic, maxpasses=0); stopping=user)
    @test termination(r).limit.n == 0 && r.minimum === missing
    @test calls[] == 0

    for unsupported in (IterateChange(), ScaledKKT(rtol=1e-5), MaxPasses(1))
        @test_throws ArgumentError solve!(x, f, g, method;
            stopping=AnyOf(user, AllOf(ObjectiveChange(), unsupported)), limits=MaxPasses(0))
    end
    @test_throws ArgumentError solve!(x, f, g, method; stopping=UserStop(() -> true))
    @test_throws ArgumentError solve!(x, f, g, method; limits=MaxIterations(0))
    @test_throws ArgumentError solve!(x, f, g, ProximalGradientDescent(); limits=MaxPasses(0))
    @test_throws ArgumentError solve!(x, f, g, CDSolver(order=:cyclic, maxpasses=3); limits=MaxPasses(2))
    @test_throws ArgumentError solve!(x, f, NormL1(0.5, ones(2)), method; limits=MaxPasses(0))
    @test_throws ArgumentError solve!(PS.SparseIterate(x), f, g, method; limits=MaxPasses(0))
    @test_throws ArgumentError solve!(x, SqrtLeastSquaresLoss(f.Y, f.X), g, method; limits=MaxPasses(0))
    @test_throws ArgumentError solve!(x, f, g, CDSolver(rng=rng); limits=MaxPasses(0))
    @test_throws ArgumentError solve!([NaN, 0.0], f, g, method; limits=MaxPasses(0))
    @test_throws ArgumentError MaxPasses(-1)
    @test_throws ArgumentError MaxPasses(big(typemax(Int)) + 1)
    @test x == [1, 0] && calls[] == 0 && rand(rng, UInt64) == rand(reference, UInt64)
end

@testset "Private CD state on checkpoint failure and an empty active pass" begin
    f, g, method = example(Float64)
    x = [2.0, 0.0]
    after_first(c) = c.iteration == 1 ? error("checkpoint failure") : false
    @test_throws r"checkpoint failure" solve!(x, f, g, method;
        stopping=UserStop(after_first), limits=MaxPasses(3))
    @test_throws ArgumentError solve!(x, f, g, method; stopping=UserStop(_ -> 1))
    @test x == [2, 0]
    x = [floatmax(Float64) / 2, 0.0]
    @test_throws ArgumentError solve!(x, f, g, method; stopping=UserStop(_ -> false))
    @test x == [floatmax(Float64) / 2, 0]

    f = LeastSquaresLoss([0.0], ones(1, 1))
    r = solve!([1.0], f, g, CDSolver(order=:cyclic, relative=false); limits=MaxPasses(2))
    @test r.minimizer == [0.0] && r.passes == 2
    @test termination(r).counts == (full_passes=1, active_passes=1, coordinate_visits=1, objective_evaluations=1)
end

@testset "Budget-only trajectory and seeded order ($T, $order)" for T in (Float32, Float64), order in (:cyclic, :random)
    f, g, _ = example(T)
    state = Xoshiro(19)
    other = copy(state)
    x, y = T[0.75, -0.5], T[0.75, -0.5]
    baseline = CDSolver(order=order, momentum=false, tol=0, maxpasses=48, rng=state)
    configured = CDSolver(order=order, momentum=false, tol=0, rng=other)
    legacy = solve!(x, f, g, baseline)
    r = solve!(y, f, g, configured; limits=MaxPasses(48))
    @test legacy isa CDResults && isequal(legacy.minimizer, r.minimizer)
    @test legacy.passes == r.passes == 48 && isequal(legacy.minimum, r.minimum)
    @test rand(state, UInt64) == rand(other, UInt64)
    t = termination(r)
    @test t.counts.full_passes > 1 && t.counts.active_passes > 0
    @test t.counts.full_passes + t.counts.active_passes == 48
end

@testset "Visit caps at full and active checkpoints ($T)" for T in (Float32, Float64)
    f, g, method = example(T)
    for (capacity, passes, visits) in ((2, 1, 2), (3, 2, 3), (4, 2, 3))
        cap = MaxCoordinateVisits(capacity)
        checkpoints = Int[]
        watch(c) = (push!(checkpoints, c.iteration); false)
        rule = AnyOf(UserStop(watch), ObjectiveChange(atol=3/16))
        x = zeros(T, 2)
        r = solve!(x, f, g, method; stopping=rule, limits=cap)
        t = termination(r)
        @test r.minimizer === x && x == T[0, 1] && r.minimum === T(2.125)
        @test t.reason === :limit && t.limit_reached && !t.satisfied && !r.converged
        @test t.iteration == r.passes == passes && t.limit.n == method.maxpasses
        @test t.evaluation_limits === (cap,) && t.reached_evaluation_limits === (cap,)
        @test map(o -> o.status, t.observations) == (:not_checked, :not_checked)
        @test checkpoints == collect(0:passes - 1)
        @test t.counts == (full_passes=1, active_passes=passes - 1, coordinate_visits=visits,
                           objective_evaluations=passes + 1)
    end

    cap = MaxCoordinateVisits(6)
    for (limits, pass_limit) in ((cap, method.maxpasses), ((cap, MaxPasses(3)), 3))
        checkpoints = Int[]
        rule = AnyOf(UserStop(c -> (push!(checkpoints, c.iteration); false)), ObjectiveChange(atol=3/16))
        r = solve!(zeros(T, 2), f, g, method; stopping=rule, limits)
        t = termination(r)
        @test r.minimizer == T[-0.5, 1.25] && r.minimum === T(1.9375)
        @test t.reason === :rule && t.limit_reached && t.satisfied && !r.converged
        @test t.limit.n == pass_limit && t.iteration == 3 && t.reached_evaluation_limits === (cap,)
        @test checkpoints == [0, 1, 2] && t.winning_branch == ((2,),)
        @test map(o -> o.status, t.observations) == (:not_checked, :pass)
        @test t.observations[2].value == 3/16
        @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=5, objective_evaluations=4)
    end

    cap = MaxCoordinateVisits(7)
    r = solve!(zeros(T, 2), f, g, method; stopping=ObjectiveChange(atol=3/16), limits=cap)
    t = termination(r)
    @test t.reason === :rule && t.satisfied && t.iteration == 3 && !t.limit_reached
    @test t.evaluation_limits === (cap,) && isempty(t.reached_evaluation_limits)
    @test t.counts.coordinate_visits == 5

    cap = MaxCoordinateVisits(typemax(Int))
    r = solve!(zeros(T, 2), f, g, method; limits=(MaxPasses(2), cap))
    t = termination(r)
    @test t.reason === :limit && t.limit_reached && t.iteration == t.limit.n == 2
    @test t.evaluation_limits === (cap,) && isempty(t.reached_evaluation_limits)
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=3, objective_evaluations=1)
end

@testset "A blocked full sweep returns the current active objective ($T)" for T in (Float32, Float64)
    f = LeastSquaresLoss(T[2, 1], T[1 1; 0 1])
    g = NormL1(T(0.5))
    method = CDSolver(order=:cyclic, relative=false, tol=1)
    r = solve!(zeros(T, 2), f, g, method; stopping=ObjectiveChange(), limits=MaxCoordinateVisits(5))
    t = termination(r)
    @test r.minimizer == T[1, 0.75] && r.minimum === T(0.9375)
    @test t.reason === :limit && t.iteration == 2 && only(t.observations).status === :not_checked
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=4, objective_evaluations=2)

    # The active sweep visits both coordinates even though the first becomes zero.
    f = LeastSquaresLoss(T[0.75, 2.25], T[1 1; 0 1])
    method = CDSolver(order=:cyclic, relative=false, tol=0.01)
    r = solve!(zeros(T, 2), f, g, method; limits=MaxCoordinateVisits(4))
    @test r.minimizer == T[0, 1.25] && r.passes == 2 && r.minimum === T(1.25)
    @test termination(r).counts.coordinate_visits == 4
    r = solve!(zeros(T, 2), f, g, method; limits=MaxCoordinateVisits(5))
    @test r.minimizer == T[0, 1.25] && r.passes == 3 && termination(r).counts.coordinate_visits == 5
end

@testset "Visit caps respect empty and forced sweeps ($T)" for T in (Float32, Float64)
    f = LeastSquaresLoss(T[0], ones(T, 1, 1))
    g = NormL1(T(0.5))
    cap = MaxCoordinateVisits(1)
    r = solve!(T[1], f, g, CDSolver(order=:cyclic, relative=false); limits=cap)
    t = termination(r)
    @test r.minimizer == T[0] && r.passes == 2 && t.reached_evaluation_limits === (cap,)
    @test t.reason === :limit && t.limit_reached
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=1, objective_evaluations=1)

    r = solve!(T[1], f, g, CDSolver(order=:cyclic, relative=false, tol=0);
               limits=(MaxPasses(3), cap))
    t = termination(r)
    @test t.reason === :limit && t.limit_reached && r.passes == t.limit.n == 3
    @test isempty(t.reached_evaluation_limits)
    @test t.counts == (full_passes=1, active_passes=2, coordinate_visits=1, objective_evaluations=1)

    f, g, _ = example(T)
    cap = MaxCoordinateVisits(43)
    r = solve!(zeros(T, 2), f, g, CDSolver(order=:cyclic, tol=0); limits=cap)
    t = termination(r)
    @test r.minimizer == T[0, 1] && r.passes == 41 && t.reached_evaluation_limits === (cap,)
    @test t.counts == (full_passes=1, active_passes=40, coordinate_visits=42, objective_evaluations=1)
end

@testset "Visit limits preserve seeded random prefixes ($T)" for T in (Float32, Float64)
    f = T(2) * LeastSquaresLoss(T[2, -2, 3], T[3 0 0; 0 2 0; 0 0 1])
    g = NormL1(one(T))
    rng = Xoshiro(493)
    reference = copy(rng)
    r = solve!(zeros(T, 3), f, g, CDSolver(rng=rng, momentum=false, tol=0); limits=MaxCoordinateVisits(8))
    prefix = solve!(zeros(T, 3), f, g, CDSolver(rng=reference, momentum=false, tol=0); limits=MaxPasses(r.passes))
    t = termination(r)
    @test r.passes == 2 && t.reason === :limit && t.counts.coordinate_visits == 6
    @test isequal((r.minimizer, r.minimum), (prefix.minimizer, prefix.minimum))
    @test t.counts == termination(prefix).counts
    @test rand(rng, UInt64) == rand(reference, UInt64)
end

@testset "Blocked first sweep and visit-cap validation" begin
    f, g, _ = example(Float64)
    rng = Xoshiro(241)
    reference = copy(rng)
    method = CDSolver(rng=rng, momentum=false)
    x = [floatmax(Float64)/2, 0.0]
    must_skip = UserStop(_ -> error("a blocked first sweep must skip the user predicate"))
    for capacity in 0:1
        cap = MaxCoordinateVisits(capacity)
        r = solve!(x, f, g, method; stopping=must_skip, limits=cap)
        t = termination(r)
        @test r.minimizer === x && x == [floatmax(Float64)/2, 0.0] && r.minimum === missing
        @test t.reason === :limit && r.passes == 0 && t.limit_reached && !t.satisfied
        @test t.reached_evaluation_limits === (cap,)
        @test only(t.observations).status === :not_checked && all(iszero, values(t.counts))
    end

    cap = MaxCoordinateVisits(1)
    r = solve!(x, f, g, method; stopping=must_skip, limits=(MaxPasses(0), cap))
    @test r.minimum === missing && termination(r).limit.n == 0
    @test termination(r).reached_evaluation_limits === (cap,)
    for limits in ((), [cap], (cap, cap), (MaxPasses(0), MaxPasses(1)),
                   (cap, MaxIterations(1)), (cap, MaxProximalEvaluations(1)))
        @test_throws ArgumentError solve!(x, f, g, method; limits)
    end
    @test_throws ArgumentError solve!(x, f, g, CDSolver(order=:cyclic, maxpasses=3);
                                      limits=(MaxPasses(2), cap))
    @test_throws ArgumentError solve!(x, f, g, method;
                                      stopping=AnyOf(must_skip, AllOf(ObjectiveChange(), cap)), limits=cap)
    @test_throws ArgumentError solve!(x, f, g, CDSolver(rng=rng); limits=cap)
    @test_throws ArgumentError solve!(PS.SparseIterate(zeros(2)), f, g, method; limits=cap)
    @test_throws ArgumentError solve!(x, f, NormL1(0.5, ones(2)), method; limits=cap)
    @test_throws ArgumentError solve!(x, f, g, ProximalGradientDescent(); limits=cap)
    @test_throws ArgumentError solve!(zeros(2), SqrNormL2(1.0, ones(2)), g, ADMMSolver(); limits=cap)
    @test_throws ArgumentError MaxCoordinateVisits(-1)
    @test_throws ArgumentError MaxCoordinateVisits(big(typemax(Int)) + 1)
    @test x == [floatmax(Float64)/2, 0.0] && rand(rng, UInt64) == rand(reference, UInt64)
end

end
