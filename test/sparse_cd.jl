module SparseCD
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

# ---------------------------------------------------------------------------
# Helpers. The public state of an owner is its shape, its numbers of coordinates
# and active coordinates, the active IDs in slot order and the active values; a
# snapshot copies all of it. Values compare with isequal, so an active -0.0 is
# not an active 0.0 and a NaN equals itself. Never compare handles taken before
# a mutation: activevalues/activecoordinates are live views of an owner.
# ---------------------------------------------------------------------------
snapshot(x) = (size(x), ncoordinates(x), nactive(x), collect(activecoordinates(x)), copy(activevalues(x)))
same_state(a, b) = a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && isequal(a[5], b[5])

# An owner of p coordinates with the given active IDs, in this slot order, holding the
# given values; a zero value stays an active zero, including -0.0.
function owner(::Type{T}, p, ids, vals) where T
  x = SparseIterate(T, p)
  for (i, v) in zip(ids, vals)
    activate!(x, i)
    x[i] = v
  end
  x
end

# The relative change tolerance. Float32 may not resolve the default 1e-7 reliably in
# native arithmetic; the accuracy bounds below follow the tolerance that is used.
tolerance(::Type{T}) where T = T === Float32 ? 1e-5 : 1e-7
cdsolver(::Type{T}; kwargs...) where T = CDSolver(; tol = tolerance(T), kwargs...)

# A lasso with a sparse truth, a noise level below the penalty, and its Float64 parts.
function problem(::Type{T}, n, p; seed = 1, scaled = false, support = (1, 3), modify! = identity) where T
  rng = Xoshiro(seed)
  X = T.(randn(rng, n, p))
  modify!(X)
  beta = zeros(p)
  beta[collect(support)] .= (2.0, -1.5)[1:length(support)]
  y = T.(Float64.(X) * beta .+ 0.05 .* randn(rng, n))
  s = scaled ? one(T) / T(n) : one(T)
  lambda = scaled ? T(0.05) : T(0.05) * T(n)
  f = scaled ? s * LeastSquaresLoss(y, X) : LeastSquaresLoss(y, X)
  (; X, y, f, g = NormL1(lambda), s, lambda)
end

# Independent references, in Float64 from the exact (rounded) data.
objective64(X, y, z, lambda, s) =
  Float64(s) * sum(abs2, Float64.(y) .- Float64.(X) * Float64.(z)) / 2 + Float64(lambda) * sum(abs, Float64.(z))
function kkt64(X, y, z, lambda, s)
  A, b, w = Float64.(X), Float64.(y), Float64.(z)
  d = Float64(s) * (A' * (A * w - b))
  maximum(iszero(w[j]) ? max(abs(d[j]) - Float64(lambda), 0.0) : abs(d[j] + Float64(lambda) * sign(w[j])) for j in eachindex(w))
end
# A practical accuracy budget for these fixtures, not a certificate: the KKT violation of
# a returned point is compared with (p + 1) times the larger of the relative change
# tolerance and 100 eps of the working precision, scaled by the input magnitude
# s * max_j norm(X_j) * norm(y). The converged flag is a stopping status only; the
# independent Float64 KKT calculation below decides accuracy.
function kkt_bound(::Type{T}, X, y, s) where T
  scale = Float64(s) * maximum(norm(Float64.(X[:, j])) for j in axes(X, 2)) * norm(Float64.(y))
  (size(X, 2) + 1) * max(tolerance(T), 100eps(T)) * scale
end

function check_solution(::Type{T}, prob, x, r) where T
  z = Vector(x)
  @test r isa CDResults && r.minimizer === x
  @test r.converged
  @test kkt64(prob.X, prob.y, z, prob.lambda, prob.s) <= kkt_bound(T, prob.X, prob.y, prob.s)
  # the cached residual of the run drifts slightly from the exact one
  @test r.minimum ≈ objective64(prob.X, prob.y, z, prob.lambda, prob.s) rtol = 1000eps(T)
  # a pass compacts: no active zeros remain after a completed run
  @test all(!iszero, activevalues(x))
  @test nactive(x) == count(!iszero, z)
end

# A refused call changes neither the owner, nor the borrowed data, nor the RNG.
function refused(x, f, g, make = rng -> CDSolver(; rng); kind = ArgumentError, kwargs...)
  before = snapshot(x)
  rng, twin = Xoshiro(2024), Xoshiro(2024)
  @test_throws kind solve!(x, f, g, make(rng); kwargs...)
  @test same_state(before, snapshot(x))
  @test rand(rng) == rand(twin)
end

# What a failing solve leaves behind in its private working copy: the coordinates the
# run moved before the error (the public call must not have exposed them).
function private_run(x, f, g, solver)
  work = copy(x)
  m = PS.cdmodel(f, work)
  PS.initialize!(m, work)
  state = PS._CDState(eltype(work), work, solver)
  try
    PS._cd!(work, m, g, state, solver)
  catch
    nothing
  end
  work
end

@testset "orthogonal lasso has an exact analytic optimum" begin
  H = [1 1 1 1; 1 -1 1 -1; 1 1 -1 -1; 1 -1 -1 1]
  for T in (Float64, Float32), scaled in (false, true), order in (:cyclic, :random)
    X = T.(H .* [1 2 .5 4])
    y = T[3, -1, 2.5, .75]
    f = scaled ? (one(T) / T(4)) * LeastSquaresLoss(y, X) : LeastSquaresLoss(y, X)
    g = NormL1(scaled ? T(.25) : one(T))
    # minimize s*(a*x^2/2 - b*x) + lambda*abs(x) per column: soft threshold lambda/s, divide by a
    A, b = Float64.(X), Float64.(X)' * Float64.(y)
    a = vec(sum(abs2, A; dims = 1))
    analytic = @. sign(b) * max(abs(b) - 1.0, 0.0) / a
    @test analytic == [1.0625, .65625, 0.0, .125]
    objective = objective64(X, y, analytic, Float64(g.λ0), scaled ? .25 : 1.0)
    starts = (owner(T, 4, Int[], T[]),
              owner(T, 4, [3, 1, 4, 2], [0.0, -0.0, .5, -.25]),
              owner(T, 4, [4, 2], [.125, .65625]))
    for start in starts
      x = copy(start)
      r = solve!(x, f, g, cdsolver(T; order, rng = Xoshiro(3)))
      @test r.converged && r.minimizer === x && r.passes == 3
      @test Vector(x) == T.(analytic)
      @test Set(activecoordinates(x)) == Set([1, 2, 4])
      @test all(!iszero, activevalues(x))
      @test r.minimum ≈ objective rtol = 8eps(T)
    end
    # Cyclic full pass: coordinates enter in visiting order and zeros never enter.
    x = owner(T, 4, Int[], T[])
    solve!(x, f, g, cdsolver(T; order = :cyclic))
    @test collect(activecoordinates(x)) == [1, 2, 4]

    # At the optimum in an unsorted slot order a full pass changes nothing: converged in
    # one pass and the same slots, which a normal pass keeps.
    at_optimum = owner(T, 4, [4, 1, 2], T.(analytic)[[4, 1, 2]])
    before = snapshot(at_optimum)
    r = solve!(at_optimum, f, g, cdsolver(T; order, rng = Xoshiro(3)))
    @test r.converged && r.passes == 1 && same_state(before, snapshot(at_optimum))
  end
end

@testset "dense and owner solves agree from the same state" begin
  options = ((order = :cyclic,), (order = :random,), (order = :random, momentum = false))
  for T in (Float64, Float32), scaled in (false, true), kw in options
    prob = problem(T, 12, 5; scaled)
    for start in (zeros(T, 5), T[.5, 0, -.25, 0, .1])
      xd = copy(start)
      rngd, rngo = Xoshiro(11), Xoshiro(11)
      rd = solve!(xd, prob.f, prob.g, cdsolver(T; kw..., rng = rngd))
      xo = SparseIterate(start)
      ro = solve!(xo, prob.f, prob.g, cdsolver(T; kw..., rng = rngo))
      @test ro.minimizer === xo
      @test isequal(Vector(xo), xd)
      @test ro.minimum === rd.minimum
      @test ro.passes == rd.passes && ro.converged == rd.converged
      @test isequal(ro.maxchange, rd.maxchange) && isequal(ro.tolerance, rd.tolerance)
      # the same RNG schedule: both consumed exactly the same draws
      @test rand(rngo) == rand(rngd)
      check_solution(T, prob, xo, ro)
    end
  end
end

@testset "independent objective and KKT for varied designs and states" begin
  designs = (
    "independent" => identity,
    "correlated" => (X -> (X[:, 2] .= X[:, 1] .+ eltype(X)(.1) .* X[:, 2])),
    "duplicate and null columns" => (X -> (X[:, 4] .= X[:, 1]; X[:, 5] .= 0)))
  for T in (Float64, Float32), scaled in (false, true), (name, modify!) in designs
    prob = problem(T, 12, 5; scaled, modify!)
    starts = (owner(T, 5, Int[], T[]),
              owner(T, 5, [4, 1], [.3, -.2]),
              owner(T, 5, [5, 3, 1, 4, 2], [0.0, -0.0, .1, 0.0, -.2]),
              owner(T, 5, [2, 5], [-0.0, 0.0]))
    for start in starts, order in (:cyclic, :random)
      x = copy(start)
      r = solve!(x, prob.f, prob.g, cdsolver(T; order, rng = Xoshiro(5)))
      check_solution(T, prob, x, r)
      if name == "duplicate and null columns"
        # a null column's penalty minimizer is zero, and zeros are compacted away
        @test iszero(x[5]) && !isactive(x, 5)
      end
    end
    # a lasso with a sparse truth really leaves some coordinates out
    x = owner(T, 5, Int[], T[])
    solve!(x, prob.f, prob.g, cdsolver(T; order = :cyclic))
    @test 0 < nactive(x) < 5
  end
end

@testset "slot order changes the trajectory, not the accuracy" begin
  for T in (Float64, Float32), scaled in (false, true)
    prob = problem(T, 12, 5; scaled)
    warm = [4, 1, 5, 2]
    values = T[.3, -.2, .1, .05]
    ascending, descending = sortperm(warm), reverse(sortperm(warm))
    xa = owner(T, 5, warm[ascending], values[ascending])
    xb = owner(T, 5, warm[descending], values[descending])
    ra = solve!(xa, prob.f, prob.g, cdsolver(T; order = :cyclic))
    rb = solve!(xb, prob.f, prob.g, cdsolver(T; order = :cyclic))
    check_solution(T, prob, xa, ra)
    check_solution(T, prob, xb, rb)
    # full column rank: the minimizer is unique and the KKT bound limits the distance
    A = Float64.(prob.X)
    mu = Float64(prob.s) * eigmin(Symmetric(A' * A))
    bound = kkt_bound(T, prob.X, prob.y, prob.s)
    @test norm(Vector(xa) - Vector(xb)) <= 2 * sqrt(5) * bound / mu
    fa = objective64(prob.X, prob.y, Vector(xa), prob.lambda, prob.s)
    fb = objective64(prob.X, prob.y, Vector(xb), prob.lambda, prob.s)
    @test fa ≈ fb rtol = T === Float64 ? 1e-8 : 1e-4
  end
end

@testset "pass semantics: zero passes, limits, activation and compaction" begin
  H = [1 1 1 1; 1 -1 1 -1; 1 1 -1 -1; 1 -1 -1 1]
  for T in (Float64, Float32), scaled in (false, true)
    X = T.(H .* [1 2 .5 4])
    y = T[3, -1, 2.5, .75]
    f = scaled ? (one(T) / T(4)) * LeastSquaresLoss(y, X) : LeastSquaresLoss(y, X)
    s, lambda = scaled ? (.25, T(.25)) : (1.0, one(T))
    g = NormL1(lambda)

    # maxpasses = 0 is a no-op: the exact entry state, signed zeros and slot order included
    for start in (owner(T, 4, [3, 1, 4], [-0.0, .5, 0.0]), owner(T, 4, Int[], T[]),
                  owner(T, 4, [2, 4, 1, 3], [-0.0, -0.0, 0.0, 0.0]))
      x = copy(start)
      before = snapshot(x)
      r = @test_logs (:warn, r"maxpasses = 0 passes") solve!(x, f, g, CDSolver(maxpasses = 0))
      @test r.minimizer === x && r.passes == 0 && !r.converged && isnan(r.maxchange)
      @test same_state(before, snapshot(x))
      @test r.minimum ≈ objective64(X, y, Vector(x), lambda, s) rtol = 8eps(T)
    end

    # a limit of one pass is a finite incomplete run: warning, then the state after that pass
    for order in (:cyclic, :random)
      xd, xo = zeros(T, 4), owner(T, 4, Int[], T[])
      rd = @test_logs (:warn, r"maxpasses = 1 passes") solve!(xd, f, g, CDSolver(maxpasses = 1, order = order, rng = Xoshiro(2)))
      ro = @test_logs (:warn, r"maxpasses = 1 passes") solve!(xo, f, g, CDSolver(maxpasses = 1, order = order, rng = Xoshiro(2)))
      @test ro.passes == 1 && !ro.converged && ro.minimizer === xo
      @test isequal(Vector(xo), xd) && ro.minimum === rd.minimum
      @test Set(activecoordinates(xo)) == Set([1, 2, 4])
      @test nactive(xo) == 3 && all(!iszero, activevalues(xo))
    end

    # a normal pass compacts the zeros of the entry state exactly as dropzeros! would
    entry = owner(T, 4, [4, 3, 1, 2], [.125, 0.0, 1.0625, .65625])
    expected = copy(entry)
    SparseArrays.dropzeros!(expected)
    x = copy(entry)
    r = solve!(x, f, g, CDSolver(order = :cyclic))
    @test r.converged && r.passes == 1
    @test same_state(snapshot(expected), snapshot(x)) && !isactive(x, 3)

    # when the optimum is zero every entry value is driven to zero and compacted away; the
    # entry state is not resurrected
    big = NormL1(T(1e6))
    x = owner(T, 4, [3, 1], [.4, -.2])
    r = solve!(x, f, big, CDSolver(order = :cyclic))
    @test r.converged && nactive(x) == 0 && Vector(x) == zeros(T, 4) && r.minimizer === x
  end

  # warn first, then refuse a nonfinite objective, leaving the owner as it was
  x = owner(Float64, 2, [2, 1], [-1e308, 1e308])
  before = snapshot(x)
  @test_logs (:warn, r"maxpasses = 0") begin
    @test_throws r"nonfinite objective" solve!(x, LeastSquaresLoss([0.], fill(1e308, 1, 2)), NormL1(0.),
                                              CDSolver(maxpasses = 0))
  end
  @test same_state(before, snapshot(x))
end

@testset "finite pass limits commit a nonconverged state" begin
  for T in (Float64, Float32), scaled in (false, true), order in (:cyclic, :random)
    prob = problem(T, 12, 5; scaled)
    for start in (zeros(T, 5), T[.5, 0, -.25, 0, .1])
      xd, xo = copy(start), SparseIterate(start)
      rd = @test_logs (:warn, r"maxpasses = 2 passes") solve!(xd, prob.f, prob.g, cdsolver(T; maxpasses = 2, order, rng = Xoshiro(4)))
      ro = @test_logs (:warn, r"maxpasses = 2 passes") solve!(xo, prob.f, prob.g, cdsolver(T; maxpasses = 2, order, rng = Xoshiro(4)))
      @test !ro.converged && ro.passes == 2 && ro.minimizer === xo
      @test isequal(Vector(xo), xd) && ro.minimum === rd.minimum
      @test all(!iszero, activevalues(xo))
    end
  end
end

@testset "zero columns and curvature underflow" begin
  for T in (Float64, Float32)
    # a flat column has no loss slope: its coordinate goes to the penalty's minimizer, zero
    X = T[1 0; 2 0; 0 0]
    y = T[1, 1, 1]
    for lambda in (T(.1), zero(T))
      x = owner(T, 2, [2, 1], [.7, -.3])
      r = solve!(x, LeastSquaresLoss(y, X), NormL1(lambda), cdsolver(T; order = :cyclic))
      @test r.converged && iszero(x[2]) && !isactive(x, 2)
      @test kkt64(X, y, Vector(x), lambda, 1) <= kkt_bound(T, X, y, 1)
    end

    # a nonzero column whose squared norm underflows is an error, after the earlier
    # column was already moved in the private copy
    tiny = T === Float32 ? T(1e-30) : T(1e-200)
    X = T[1 0; 0 tiny]
    y = T[1, 1]
    g = NormL1(T(.1))
    x = owner(T, 2, [1], [.25])
    before = snapshot(x)
    solver = cdsolver(T; order = :cyclic)
    @test_throws r"curvature underflows" solve!(x, LeastSquaresLoss(y, X), g, solver)
    @test same_state(before, snapshot(x))
    @test private_run(x, LeastSquaresLoss(y, X), g, solver)[1] ≈ T(.9) atol = 4eps(T)
    # companion with a finite flat second column: the same call completes and moved coordinate 1
    flat = T[1 0; 0 0]
    r = solve!(x, LeastSquaresLoss(y, flat), g, solver)
    @test r.converged
    @test x[1] ≈ T(.9) atol = 4eps(T)
    @test !isactive(x, 2)
  end
end

@testset "nonfinite updates and objectives leave the owner unchanged" begin
  for T in (Float64, Float32)
    g = NormL1(T(.1))
    solver = cdsolver(T; order = :cyclic)
    # The failing column is last. Its step overflows (b/a with a huge response), after
    # coordinate 1 already moved in the private copy.
    huge = T === Float32 ? T(3e38) : T(1e308)
    X = T[1 0; 0 1e-3]
    y = T[1, huge]
    f = LeastSquaresLoss(y, X)
    x = owner(T, 2, [1], [.25])
    before = snapshot(x)
    @test_throws r"not finite" solve!(x, f, g, solver)
    @test same_state(before, snapshot(x))
    work = private_run(x, f, g, solver)
    @test work[1] ≈ T(.9) atol = 4eps(T)
    @test x[1] == T(.25)
    # companion: the same data with a moderate response completes, so the earlier
    # coordinate does move when nothing fails
    r = solve!(x, LeastSquaresLoss(T[1, 1], X), g, solver)
    @test r.converged
    @test x[1] ≈ T(.9) atol = 4eps(T)
  end

  # Float32 residual overflow: coordinate 1 moves, then the loss is not finite
  X = Float32[1; 0;;]
  g = NormL1(.1f0)
  f = LeastSquaresLoss(Float32[1, 1f20], X)
  x = owner(Float32, 1, [1], [.25])
  before = snapshot(x)
  solver = cdsolver(Float32; order = :cyclic)
  @test_throws r"nonfinite objective" solve!(x, f, g, solver)
  @test same_state(before, snapshot(x))
  @test private_run(x, f, g, solver)[1] ≈ .9f0 atol = 4eps(Float32)
  r = solve!(x, LeastSquaresLoss(Float32[1, 1f10], X), g, solver)
  @test r.converged
  @test x[1] ≈ .9f0 atol = 4eps(Float32)
  @test isfinite(r.minimum)
  # and from the empty state
  e = owner(Float32, 1, Int[], Float32[])
  @test_throws r"nonfinite objective" solve!(e, f, g, CDSolver(order = :random, rng = Xoshiro(1)))
  @test nactive(e) == 0 && iszero(e[1])
end

@testset "owner refusals happen before copying, mutation or RNG draws" begin
  for T in (Float64, Float32)
    X, y = T[1 0; 0 2], T[1, -1]
    f, g = LeastSquaresLoss(y, X), NormL1(T(.1))
    x = owner(T, 2, [2, 1], [-.2, .3])
    opposite = T === Float32 ? Float64 : Float32

    # representation of the iterate
    refused(SparseIterate(T, 2, 1), f, g)
    refused(SparseIterate(T, 1, 2), f, g)
    refused(SparseIterate(Int, 2), f, g)
    refused(SparseIterate(Float16, 2), f, g)
    refused(SparseIterate(opposite, 2), f, g)
    # not owners at all: refused without a snapshot
    @test_throws ArgumentError solve!(sparse(T[0, 0]), f, g, CDSolver())
    @test_throws ArgumentError solve!(view(zeros(T, 2), :), f, g, CDSolver())
    @test_throws ArgumentError solve!(reshape(zeros(T, 2), 2, 1), f, g, CDSolver())
    for bad in (T(NaN), T(Inf), T(-Inf))
      refused(owner(T, 2, [2, 1], [bad, .3]), f, g)
      refused(owner(T, 2, [1], [bad]), f, g)
    end

    # data and loss
    refused(x, LeastSquaresLoss(y, sparse(X)), g)
    refused(x, LeastSquaresLoss(y, view(X, :, :)), g)
    refused(x, LeastSquaresLoss(reshape(y, 2, 1), X), g)
    refused(x, LeastSquaresLoss(opposite.(y), X), g)
    refused(x, LeastSquaresLoss(y, opposite.(X)), g)
    refused(x, QuadraticFunction(Matrix{T}(I, 2, 2), zeros(T, 2)), g)
    refused(x, Scaled(Scaled(f, 1e-200), 1e-200), g)
    refused(x, Scaled(f, 0.), g)
    refused(x, Scaled(f, Inf), g)
    for data in (T[NaN, 0], T[Inf, 0])
      refused(x, LeastSquaresLoss(data, X), g)
      badX = copy(X)
      badX[1, 1] = data[1]
      refused(x, LeastSquaresLoss(y, badX), g)
    end

    # penalty and scalars
    refused(x, f, NormL1(T(.1), ones(T, 2)))
    refused(x, f, SqrNormL2(T(.1)))
    refused(x, f, NormL1(Inf))
    if T === Float32
      for a in (1e-50, 1e40)
        refused(x, Scaled(f, a), g)
        refused(x, f, NormL1(a))
      end
    end

    # shapes: DimensionMismatch
    # PB checks the row counts when the loss is built, so shrink the borrowed response
    # afterwards: it is the caller's public vector.
    short_y = copy(y)
    short_loss = LeastSquaresLoss(short_y, X)
    resize!(short_y, 1)
    refused(x, short_loss, g; kind = DimensionMismatch)
    refused(owner(T, 3, [1], [.5]), f, g; kind = DimensionMismatch)
    refused(SparseIterate(T, 0), LeastSquaresLoss(y, zeros(T, 2, 0)), g; kind = DimensionMismatch)
    refused(x, LeastSquaresLoss(T[], zeros(T, 0, 2)), g; kind = DimensionMismatch)

    # keywords and solver options (the deferred ones are only reachable by position)
    for keyword in (:intercept, :offset, :continuation, :screening)
      refused(x, f, g; keyword => true)
    end
    refused(x, f, g, rng -> CDSolver(100, 1e-7, true, true, 1, nothing, rng, 0., false))
    refused(x, f, g, rng -> CDSolver(100, 1e-7, true, true, 0, nothing, rng, .1, false))
    refused(x, f, g, rng -> CDSolver(100, 1e-7, true, true, 0, nothing, rng, 0., true))
    refused(x, f, g, rng -> CDSolver(100, 1e-7, false, true, 0, true, rng, 0., false))
    refused(x, f, g, rng -> CDSolver(-1, 1e-7, true, true, 0, nothing, rng, 0., false))
    refused(x, f, g, rng -> CDSolver(100, NaN, true, true, 0, nothing, rng, 0., false))
    refused(x, f, g, rng -> CDSolver(100, -1., true, true, 0, nothing, rng, 0., false))

    # the refusals above left the caller's data unchanged
    @test X == T[1 0; 0 2] && y == T[1, -1]
    @test same_state(snapshot(x), snapshot(owner(T, 2, [2, 1], [-.2, .3])))

    # proximal gradient descent still refuses every owner
    refused(x, f, g, rng -> ProximalGradientDescent())
    @test_throws ArgumentError solve!(SparseIterate(T, 2), f, g, ProximalGradientDescent())
  end
end

@testset "buffers of the owner cannot be borrowed as data" begin
  for T in (Float64, Float32), active in (0, 2)
    p = 3
    g = NormL1(T(.1))
    x = active == 0 ? SparseIterate(T, p) : owner(T, p, [2, 1], [.5, -.25])
    backing = parent(activevalues(x))      # the whole value storage, whatever nactive is
    @test length(backing) == p
    identity_matrix = Matrix{T}(I, p, p)
    before = copy(backing)
    refused(x, LeastSquaresLoss(backing, identity_matrix), g)                       # y aliases x
    refused(x, LeastSquaresLoss(T[1], reshape(backing, 1, p)), g)                    # X aliases x
    refused(x, Scaled(LeastSquaresLoss(backing, identity_matrix), T(.5)), g)
    @test isequal(backing, before) && identity_matrix == Matrix{T}(I, p, p)
    # a copy is not an alias
    r = solve!(x, LeastSquaresLoss(copy(backing), identity_matrix), g, cdsolver(T; order = :cyclic))
    @test r.converged && r.minimizer === x
  end
end

@testset "the result is the caller's owner, with an independent state" begin
  for T in (Float64, Float32)
    prob = problem(T, 12, 5)
    X0, y0 = copy(prob.X), copy(prob.y)
    x = owner(T, 5, [4, 2], [.1, 0.0])
    r = solve!(x, prob.f, prob.g, cdsolver(T; order = :cyclic))
    @test r.minimizer === x
    check_solution(T, prob, x, r)
    @test prob.X == X0 && prob.y == y0
    @test !Base.mightalias(x, prob.X) && !Base.mightalias(x, prob.y)
    # handles are taken again after the state replacement and describe the whole state
    ids, vals = collect(activecoordinates(x)), copy(activevalues(x))
    z = Vector(x)
    @test length(ids) == nactive(x) && all(!iszero, vals)
    @test z[ids] == vals && count(!iszero, z) == length(ids)
    # a copy is independent of the caller's owner in both directions
    other = copy(x)
    other[1] = 123
    @test Vector(x) == z && other[1] == T(123)
    x[2] = T(-7)
    @test r.minimizer[2] == T(-7) && other[2] == z[2]
    # a later write by the caller is what a later solve starts from
    r2 = solve!(x, prob.f, prob.g, cdsolver(T; order = :cyclic))
    @test r2.minimizer === x
    check_solution(T, prob, x, r2)
  end
end

@testset "sparse and dense occupancy strategies of the state copies" begin
  for T in (Float64, Float32), scaled in (false, true)
    # few active coordinates in many: the sparse branches of copy and commit
    prob = problem(T, 30, 40; scaled)
    x = owner(T, 40, Int[], T[])
    r = solve!(x, prob.f, prob.g, cdsolver(T; order = :cyclic))
    check_solution(T, prob, x, r)
    @test 4 * nactive(x) < ncoordinates(x)
    # the dense-occupancy entry state and its sparse result, replaced in place
    full = owner(T, 40, collect(40:-1:1), fill(T(.01), 40))
    r = solve!(full, prob.f, prob.g, cdsolver(T; order = :cyclic))
    check_solution(T, prob, full, r)
  end
end

end
