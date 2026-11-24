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
    @test !PS.converged(r) && !r.converged && t.satisfied && t.reason === :rule
    @test t.limit isa MaxPasses && t.limit.n == 2 && t.limit_reached
    @test t.winning_branch == ((2,),)
    @test map(o -> o.status, t.observations) == (:not_checked, :pass)
    @test checkpoints == [(0, T(3.125)), (1, T(2.125))]
    @test t.counts == (full_passes=1, active_passes=1, coordinate_visits=3, objective_evaluations=3)
    # At the returned point the inactive first coordinate has |X₁'r| = 1 > 0.5.
    @test abs((f.Y - f.X * x)[1]) == one(T)
    @test occursin("Coordinate Descent", summary(r))
    @test occursin("rule", sprint(show, r))

    r = solve!(zeros(T, 2), f, g, method; limits=MaxPasses(3))
    t = termination(r)
    @test r.minimizer == T[-0.5, 1.25] && r.minimum === T(1.9375)
    @test t.reason === :limit && !t.satisfied && t.limit_reached && t.iteration == 3
    @test isempty(t.observations) && t.winning_branch === nothing
    @test t.counts == (full_passes=2, active_passes=1, coordinate_visits=5, objective_evaluations=1)
end

@testset "Composition and the initial checkpoint ($T)" for T in (Float32, Float64)
    f, g, method = example(T)
    rule = AllOf(UserStop(c -> c.iteration == 1), ObjectiveChange(atol=1))
    r = solve!(zeros(T, 2), f, g, method; stopping=rule, limits=MaxPasses(4))
    t = termination(r)
    @test t.reason === :rule && !t.limit_reached && t.winning_branch == ((1,), (2,))
    @test t.counts == (full_passes=1, active_passes=0, coordinate_visits=2, objective_evaluations=2)
    @test (t.observations[2].value, t.observations[2].threshold) == (1.0, 1.0)

    user = UserStop(c -> c.iteration == 0 && c.objective === T(3.125))
    r = solve!(zeros(T, 2), f, g, method; stopping=AnyOf(ObjectiveChange(), user))
    t = termination(r)
    @test r.passes == 0 && r.minimum === T(3.125) && t.reason === :user && !r.converged
    @test map(o -> o.status, t.observations) == (:not_checked, :pass)
    @test t.counts == (full_passes=0, active_passes=0, coordinate_visits=0, objective_evaluations=1)

    equal = CDSolver(order=:cyclic, maxpasses=2)
    r = solve!(zeros(T, 2), T(2) * f, NormL1(one(T)), equal;
               stopping=ObjectiveChange(), limits=MaxPasses(2))
    @test r.minimum === T(4.25) && termination(r).limit_reached && termination(r).satisfied
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
    @test_throws ArgumentError solve!(x, f, g, method; stopping=ObjectiveChange())
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

end
