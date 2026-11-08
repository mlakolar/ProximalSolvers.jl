# Duality gaps: weak duality at arbitrary points and a zero gap at accurate
# solutions, gap stopping in every solver, gap-safe screening, the KKT residual,
# and allocations.

module GapTests

using Test, LinearAlgebra, Random, SparseArrays, Statistics
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function lassodata(; n = 80, p = 200, seed = 1)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:5] .= [2, -1.5, 1, -1, 0.5]
  X, X * β + 0.3 * randn(rng, n), β
end

# a sparse point with random signs, for weak duality
randpoint(rng, p; nonneg = false) = SparseIterate((nonneg ? rand(rng, p) : randn(rng, p)) .* (rand(rng, p) .< 0.1))

relgap(dg) = dg.gap / abs(dg.primal)

@testset "weak duality, and a zero gap at the solution" begin
  X, y, β = lassodata()
  n, p = size(X)
  rng = Xoshiro(7)
  w = rand(rng, n) .+ 0.5
  o = 0.1 * randn(rng, n)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  wls = GLMLoss(ProximalBase.Squared(), y, X; weights = w ./ n, offset = o)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  yb = Float64.(rand(rng, n) .< 1 ./ (1 .+ exp.(-X * β)))
  logit = (1 / n) * GLMLoss(ProximalBase.Logistic(), yb, X)
  huber = (1 / n) * GLMLoss(ProximalBase.Huber(0.5), y, X)
  λl = lambda_max(logit, NormL1(1.0), SparseIterate(p))
  cases = Any[(ls, NormL1(0.1λmax)), (ls, NormL1(0.1λmax, rand(rng, p) .+ 0.5)), (ls, NormL1Nonneg(0.1λmax)),
              (ls, ElasticNet(0.1λmax, 0.05)), (ls, ElasticNet(0.1λmax, 0.0)), (wls, NormL1(0.05λmax)),
              (logit, NormL1(0.2λl)), (logit, ElasticNet(0.2λl, 0.01)), (huber, NormL1(0.1λmax))]
  for (f, g) in cases
    x = SparseIterate(p)
    solve!(x, f, g, CDSolver(; tol = 1e-14))
    dg = duality_gap(f, g, x)
    @test dg.gap ≈ dg.primal - dg.dual
    @test dg.primal ≈ f(x) + g(x)
    @test abs(relgap(dg)) < 1e-10
    Pstar = dg.primal
    for _ in 1:5
      xr = randpoint(rng, p; nonneg = g isa NormL1Nonneg)
      d = duality_gap(f, g, xr)
      @test d.gap >= d.primal - Pstar - 1e-10 * abs(Pstar)
      @test d.dual <= Pstar + 1e-10 * abs(Pstar)
      # a dense vector gives the same gap
      @test duality_gap(f, g, Vector(xr)).gap ≈ d.gap
    end
  end
  # with negative entries the nonnegative lasso is infinite at x
  @test duality_gap(ls, NormL1Nonneg(0.1λmax), SparseIterate([-1.0; zeros(p - 1)])).gap == Inf

  # an intercept, through the model
  m = cdmodel(ls, SparseIterate(p); intercept = true)
  x = SparseIterate(p)
  solve!(x, m, NormL1(0.1λmax), CDSolver(; tol = 1e-14))
  dg = duality_gap(m, NormL1(0.1λmax), x)
  @test abs(relgap(dg)) < 1e-10
  @test duality_gap(m, NormL1(0.1λmax), SparseIterate(p)).gap > 0

  # a sparse design with an intercept, whose model keeps a shift of the
  # residuals apart: the same gap as the dense design
  Xs = sparse(X .* (rand(rng, n, p) .< 0.3))
  xr = randpoint(rng, p)
  for (fs, fd) in (((1 / n) * LeastSquaresLoss(y, Xs), (1 / n) * LeastSquaresLoss(y, Matrix(Xs))),
                   (GLMLoss(ProximalBase.Squared(), y, Xs; weights = w ./ n, offset = o),
                    GLMLoss(ProximalBase.Squared(), y, Matrix(Xs); weights = w ./ n, offset = o)))
    ds = duality_gap(cdmodel(fs, SparseIterate(p); intercept = true), NormL1(0.1λmax), xr)
    dd = duality_gap(cdmodel(fd, SparseIterate(p); intercept = true), NormL1(0.1λmax), xr)
    @test ds.primal ≈ dd.primal
    @test ds.dual ≈ dd.dual
  end

  # Poisson, by proximal Newton
  ycount = Float64.(rand(rng, 0:3, n))
  fp = (1 / n) * GLMLoss(ProximalBase.Poisson(), ycount, X ./ 4)
  x = SparseIterate(p)
  solve!(x, fp, NormL1(0.05), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-12)))
  @test abs(relgap(duality_gap(fp, NormL1(0.05), x))) < 1e-10
  @test duality_gap(fp, NormL1(0.05), randpoint(rng, p)).gap > 0

  # the group lasso on an AtomIterate
  groups = [((k - 1) * 4 + 1):(k * 4) for k in 1:50]
  gg = GroupNormL2(0.1λmax, groups)
  xa = AtomIterate(p, groups)
  solve!(xa, ls, gg, CDSolver(; tol = 1e-14))
  dg = duality_gap(ls, gg, xa)
  @test abs(relgap(dg)) < 1e-10
  @test duality_gap(ls, gg, Vector(xa)).gap ≈ dg.gap atol = 1e-12
  xr = AtomIterate(Vector(randpoint(rng, p)), groups)
  @test duality_gap(ls, gg, xr).gap >= duality_gap(ls, gg, xr).primal - dg.primal - 1e-10
end

@testset "no gap" begin
  X, y, _ = lassodata()
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  q = QuadraticFunction(X'X / n, -X'y / n)
  @test_throws ArgumentError duality_gap(q, NormL1(0.1), SparseIterate(p))
  @test_throws ArgumentError duality_gap(ls, MCP(0.1), SparseIterate(p))
  @test_throws ArgumentError duality_gap(cdmodel(q, SparseIterate(p)), NormL1(0.1), SparseIterate(p))
  # a coordinate without penalty and a nonzero gradient
  w = ones(p); w[1] = 0
  @test_throws ArgumentError duality_gap(ls, NormL1(0.1, w), SparseIterate(p))
  # gaptol without a gap: the rule on the changes applies
  r = @test_logs (:warn, r"no duality gap") match_mode = :any solve!(SparseIterate(p), q, NormL1(0.1), CDSolver(; gaptol = 1e-8))
  @test r.converged && isnan(r.gap)
  @test isnan(solve!(SparseIterate(p), ls, NormL1(0.1), CDSolver()).gap)
end

@testset "gaptol in coordinate descent" begin
  X, y, β = lassodata()
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  rng = Xoshiro(3)
  yb = Float64.(rand(rng, n) .< 1 ./ (1 .+ exp.(-X * β)))
  logit = (1 / n) * GLMLoss(ProximalBase.Logistic(), yb, X)
  λl = lambda_max(logit, NormL1(1.0), SparseIterate(p))
  for gaptol in (1e-4, 1e-8, 1e-11), (f, g) in ((ls, NormL1(0.05λmax)), (logit, NormL1(0.1λl)))
    for s in (CDSolver(; gaptol), CDSolver(; gaptol, momentum = false), CDSolver(; gaptol, order = :cyclic),
              CDSolver(; gaptol, order = :cyclic, anderson = 5), CDSolver(; gaptol, gapsafe = true))
      x = SparseIterate(p)
      r = solve!(x, f, g, s)
      @test r.converged
      @test r.gap <= gaptol
      @test relgap(duality_gap(f, g, x)) <= gaptol * (1 + 1e-6) + 1e-14
    end
  end
  # a tolerance at or below the precision ends the run once tol cannot be
  # tightened further, converged only if rounding made the gap zero
  r = Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
    solve!(SparseIterate(p), ls, NormL1(0.05λmax), CDSolver(; gaptol = 1e-30))
  end
  @test r.passes < 10_000
  @test r.converged == (r.gap <= 1e-30)
  # groups
  groups = [((k - 1) * 4 + 1):(k * 4) for k in 1:50]
  gg = GroupNormL2(0.1λmax, groups)
  for gapsafe in (false, true)
    xa = AtomIterate(p, groups)
    r = solve!(xa, ls, gg, CDSolver(; gaptol = 1e-9, gapsafe))
    @test r.gap <= 1e-9
    @test relgap(duality_gap(ls, gg, xa)) <= 1e-9 * (1 + 1e-6)
  end
  # through continuation and paths, which run the same passes
  x = SparseIterate(p)
  r = solve!(x, ls, NormL1(0.05λmax), CDSolver(; gaptol = 1e-9); continuation = 10)
  @test r.converged && r.gap <= 1e-9
  @test relgap(duality_gap(ls, NormL1(0.05λmax), x)) <= 1e-9 * (1 + 1e-6)
  # the levels before the target take continuation_tol and no gap rule; every
  # other field of the solver is kept
  s = CDSolver(; tol = 1e-9, order = :cyclic, anderson = 3, gaptol = 1e-9, gapsafe = true, maxpasses = 77)
  s2 = PS._with_tol(s, 1e-4)
  @test s2.tol == 1e-4 && s2.gaptol == 0
  @test all(getfield(s2, f) == getfield(s, f) for f in fieldnames(CDSolver) if f ∉ (:tol, :gaptol))
  λs = λmax .* 10 .^ range(0, -1.5; length = 12)
  path = solve_path(ls, NormL1(1.0), λs, CDSolver(; gaptol = 1e-9, gapsafe = true))
  ref = solve_path(ls, NormL1(1.0), λs, CDSolver(; tol = 1e-12))
  for k in eachindex(λs)
    @test norm(path.solutions[k] - ref.solutions[k]) <= 1e-4 * max(1, norm(ref.solutions[k]))
    @test path.values[k] <= ref.values[k] * (1 + 1e-8)
  end
end

@testset "gap-safe screening" begin
  X, y, β = lassodata(; n = 60, p = 400, seed = 11)
  n, p = size(X)
  rng = Xoshiro(12)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  yb = Float64.(rand(rng, n) .< 1 ./ (1 .+ exp.(-X * β)))
  logit = (1 / n) * GLMLoss(ProximalBase.Logistic(), yb, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  λl = lambda_max(logit, NormL1(1.0), SparseIterate(p))
  # the screened coordinates are zero in a solution to 1e-14
  for (f, g) in ((ls, NormL1(0.3λmax)), (ls, NormL1(0.1λmax, rand(rng, p) .+ 0.5)), (ls, NormL1Nonneg(0.2λmax)),
                 (ls, ElasticNet(0.2λmax, 0.1)), (logit, NormL1(0.3λl)))
    xref = SparseIterate(p)
    solve!(xref, f, g, CDSolver(; tol = 1e-14))
    for s in (CDSolver(; gapsafe = true), CDSolver(; gapsafe = true, gaptol = 1e-10), CDSolver(; gapsafe = true, order = :cyclic))
      x = SparseIterate(p)
      m = cdmodel(f, x)
      PS.initialize!(m, x)
      st = PS._CDState(Float64, x, s.random)
      PS._cd!(x, m, g, st, s)
      screened = findall(!, st.gap.keep)
      # a gap below gaptol at the first check certifies before any screening
      s.gaptol > 0 || @test !isempty(screened)
      @test all(k -> iszero(xref[k]) && iszero(x[k]), screened)
      @test st.candidates === nothing      # restored after the run
      @test norm(Vector(x) - Vector(xref)) <= 1e-5 * max(1, norm(Vector(xref)))
    end
  end
  # groups
  groups = [((k - 1) * 4 + 1):(k * 4) for k in 1:100]
  gg = GroupNormL2(0.25λmax, groups)
  xref = AtomIterate(p, groups)
  solve!(xref, ls, gg, CDSolver(; tol = 1e-14))
  x = AtomIterate(p, groups)
  m = cdmodel(ls, x)
  PS.initialize!(m, x)
  st = PS._CDState(Float64, x, true)
  PS._cd!(x, m, gg, st, CDSolver(; gapsafe = true, tol = 1e-12))
  screened = findall(!, st.gap.keep)
  @test !isempty(screened)
  @test all(k -> !isactive(xref, k) || all(iszero, atom(xref, k)), screened)
  @test norm(Vector(x) - Vector(xref)) <= 1e-5 * max(1, norm(Vector(xref)))
  # groups on a sparse design with an intercept, whose model keeps a shift of
  # the residuals apart
  Xs = sparse(X .* (rand(rng, n, p) .< 0.3))
  fs, fd = (1 / n) * LeastSquaresLoss(y, Xs), (1 / n) * LeastSquaresLoss(y, Matrix(Xs))
  gs = GroupNormL2(0.08λmax, groups)
  xs, xd = AtomIterate(p, groups), AtomIterate(p, groups)
  solve!(xs, cdmodel(fs, xs; intercept = true), gs, CDSolver(; gapsafe = true, gaptol = 1e-10))
  solve!(xd, cdmodel(fd, xd; intercept = true), gs, CDSolver(; tol = 1e-14))
  @test count(!iszero, Vector(xd)) > 0
  @test norm(Vector(xs) - Vector(xd)) <= 1e-5 * max(1, norm(Vector(xd)))
  # screening keeps to the candidates of the strong rule, and restores them
  x = SparseIterate(p)
  m = cdmodel(ls, x)
  PS.initialize!(m, x)
  st = PS._CDState(Float64, x, true)
  base = collect(1:2:p)
  st.candidates = base
  PS._cd!(x, m, NormL1(0.3λmax), st, CDSolver(; gapsafe = true))
  @test st.candidates === base
end

@testset "gradient result convergence follows the selected criterion" begin
  # Two different curvatures leave a nonzero gap after two steps. Loose ftol
  # passes much earlier than the gap test; its diagnostic must not certify it.
  X, y = [1.0 0.0; 0.0 3.0], [1.0, 1.0]
  f, g = LeastSquaresLoss(y, X), NormL1(0.1)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    for gapevery in (1, 3)
      options = ProximalOptions(; maxiter = 2, ftol = 1.0, gaptol = 1e-14, gapevery)
      r = solve!(zeros(2), f, g, method, options)
      @test r.iterations == options.maxiter
      @test r.f_converged
      @test r.gap > options.gaptol
      @test !PS.converged(r)
      @test !r.converged
      @test occursin("* Convergence: false", sprint(show, r))
    end

    # Conversely, a satisfied gap does not need any residual test to pass.
    # gapevery = 3 exercises the final check after the iteration limit, too.
    for gapevery in (1, 3)
      options = ProximalOptions(; maxiter = 2, ftol = 1e-300, xtol = 1e-300,
                               gradtol = 1e-300, gaptol = 1e6, gapevery)
      r = solve!(zeros(2), f, g, method, options)
      @test r.gap <= options.gaptol
      @test !(r.x_converged || r.f_converged || r.grad_converged)
      @test PS.converged(r)
      @test r.converged
      @test r.iterations == (gapevery == 1 ? 1 : options.maxiter)
    end

    # A call limit also triggers a final gap check before its scheduled check.
    for gaptol in (1e-14, 1e6)
      options = ProximalOptions(; maxiter = 2, ftol = 1.0, gaptol,
                               gapevery = 3, prox_calls_limit = 1)
      r = solve!(zeros(2), f, g, method, options)
      @test r.iterations == 1
      @test r.call_limit_reached
      @test r.converged == PS.converged(r) == (r.gap <= gaptol) == (gaptol == 1e6)
    end

    # A known gap may be unavailable at the returned point: a zero penalty
    # weight leaves no feasible dual scaling while its gradient is nonzero.
    # In that case the residual tests remain in charge, as for no gap.
    options = ProximalOptions(; maxiter = 2, ftol = 1.0, gaptol = 1e-14, gapevery = 3)
    r = solve!(zeros(2), f, NormL1(0.1, [0.0, 1.0]), method, options)
    @test isnan(r.gap)
    @test r.f_converged
    @test PS.converged(r)

    q = QuadraticFunction(X'X, -X'y)
    r = @test_logs (:warn, r"no duality gap") match_mode = :any solve!(zeros(2), q, g, method, options)
    @test isnan(r.gap)
    @test PS.converged(r) == (r.x_converged || r.f_converged || r.grad_converged)
    @test PS.converged(r)
  end
end

@testset "ADMM result convergence uses the final gap" begin
  X, y = [1.0 0.0; 0.0 3.0], [1.0, 1.0]
  f, g = LeastSquaresLoss(y, X), NormL1(0.1)
  method = ADMMSolver(; abstol = 1e-14, reltol = 1e-14)
  for cutoff in (:iterations, :prox_calls), gaptol in (1e-14, 1e6)
    options = ProximalOptions(; maxiter = 2, gaptol, gapevery = 3,
                             prox_calls_limit = cutoff === :prox_calls ? 2 : 0)
    r = solve!(zeros(2), f, g, method, options)
    @test r.iterations == (cutoff === :prox_calls ? 1 : options.maxiter)
    @test r.call_limit_reached == (cutoff === :prox_calls)
    @test r.r_norm > r.eps_pri || r.s_norm > r.eps_dual
    @test r.converged == PS.converged(r) == (r.gap <= gaptol) == (gaptol == 1e6)
  end

  # With an unpenalized coordinate the dual scaling can be unavailable.
  # Both passing and failing residual tests must still be reported correctly.
  g = NormL1(0.1, [0.0, 1.0])
  options = ProximalOptions(; maxiter = 2, gaptol = 1e-14, gapevery = 3)
  for abstol in (1e-14, 10.0)
    r = solve!(zeros(2), f, g, ADMMSolver(; abstol, reltol = 0.0), options)
    @test isnan(r.gap)
    @test r.converged == (r.r_norm <= r.eps_pri && r.s_norm <= r.eps_dual) == (abstol == 10.0)
  end

  # No iteration means the infinite residual placeholders certify nothing.
  options = ProximalOptions(; maxiter = 2, gaptol = 1e-14, time_limit = -1.0)
  r = solve!(zeros(2), f, g, method, options)
  @test r.iterations == 0
  @test isnan(r.gap)
  @test !r.converged
end

@testset "gaptol in the gradient solvers and ADMM" begin
  X, y, _ = lassodata()
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  g = NormL1(0.02λmax)
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    r = solve!(zeros(p), ls, g, method, ProximalOptions(; maxiter = 50_000, gaptol = 1e-8))
    @test r.gap <= 1e-8
    @test relgap(duality_gap(ls, g, r.minimizer)) <= 1e-8 * (1 + 1e-6)
    r = solve!(SparseIterate(p), ls, g, method, ProximalOptions(; maxiter = 50_000, gaptol = 1e-8, gapevery = 3))
    @test r.gap <= 1e-8
    @test isnan(solve!(zeros(p), ls, g, method).gap)
  end
  # without a gap the other tests apply
  q = QuadraticFunction(X'X / n, -X'y / n)
  r = @test_logs (:warn, r"no duality gap") match_mode = :any solve!(zeros(p), q, g, AccProxGradDescent(), ProximalOptions(; gaptol = 1e-8))
  @test isnan(r.gap) && (r.f_converged || r.x_converged || r.grad_converged)

  # the graphical lasso by ADMM
  rng = Xoshiro(5)
  q = 15
  Ω0 = Matrix(SymTridiagonal(fill(1.0, q), fill(0.45, q - 1)))
  A = randn(rng, 200, q) / cholesky(Ω0).U'
  S = A'A / 200
  W = fill(0.1, q, q); W[diagind(W)] .= 0
  fd, gd = LogDetLoss(S), NormL1(1.0, W)
  r = solve!(Matrix(1.0I, q, q), fd, gd, ADMMSolver(; adaptive = true), ProximalOptions(; maxiter = 10_000, gaptol = 1e-9))
  @test r.converged && r.gap <= 1e-9
  dg = duality_gap(fd, gd, r.minimizer)
  @test relgap(dg) <= 1e-9 * (1 + 1e-6)
  # weak duality at positive definite points, and no dual value off the cone
  for _ in 1:5
    B = randn(rng, q, q)
    Xr = Symmetric(B * B' / q + 0.5I)
    d = duality_gap(fd, gd, Matrix(Xr))
    @test d.gap >= d.primal - dg.primal - 1e-8
  end
  @test duality_gap(fd, gd, -Matrix(1.0I, q, q)).gap == Inf
  # a scaled likelihood, and a penalty on the diagonal
  fw = LogDetLoss(S, 2.0)
  r = solve!(Matrix(1.0I, q, q), fw, NormL1(0.1), ADMMSolver(; adaptive = true), ProximalOptions(; maxiter = 10_000, gaptol = 1e-9))
  @test relgap(duality_gap(fw, NormL1(0.1), r.minimizer)) <= 1e-9 * (1 + 1e-6)
end

# the graphical-lasso gap on a SymmetricSparseIterate equals, within rounding, the gap of its
# matrix (both triangles, stored zeros as zeros), and asymmetric weights are rejected with the
# iterate unchanged
@testset "graphical-lasso gap on a SymmetricSparseIterate" begin
  rng = Xoshiro(17)
  q = 6
  A = randn(rng, 150, q)
  S = A'A / 150
  W = fill(1.0, q, q); W[diagind(W)] .= 0
  f, g = LogDetLoss(S), NormL1(0.1, W)
  same(a, b) = isapprox(a.primal, b.primal; rtol = 1e-12) && isapprox(a.dual, b.dual; rtol = 1e-12) &&
               isapprox(a.gap, b.gap; rtol = 1e-10, atol = 1e-12)
  # a positive definite point away from the solution, with an explicit stored zero
  X = SymmetricSparseIterate(Matrix(SymTridiagonal(fill(1.0, q), fill(0.2, q - 1))))
  X[q, 1] = 0.1; X[q, 1] = 0.0
  d = duality_gap(f, g, X)
  @test isfinite(d.gap) && d.gap > 1e-3
  @test same(d, duality_gap(f, g, matrixview(X)))
  @test same(d, duality_gap(f, g, Matrix(X)))
  @test PS._gapevaluator(f, g, X) !== nothing
  # a Float32 iterate with a Float64 likelihood: the gap of its Float32 matrix
  X32 = SymmetricSparseIterate(Float32.(Matrix(X)))
  @test same(duality_gap(f, g, X32), duality_gap(f, g, Matrix(X32)))
  # off the cone: no dual value
  N = SymmetricSparseIterate(-Matrix(1.0I, q, q))
  @test duality_gap(f, g, N).gap == Inf
  @test duality_gap(f, g, matrixview(N)).gap == Inf
  # asymmetric weights: rejected by the symmetry rule, the iterate unchanged
  Wa = copy(W); Wa[2, 1] = 3.0
  before = (Matrix(X), collect(coordinates(X)), collect(activecoordinates(X)), nactive(X))
  err = try
    duality_gap(f, NormL1(0.1, Wa), X)
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("must be symmetric on a SymmetricSparseIterate", sprint(showerror, err))
  @test (Matrix(X), collect(coordinates(X)), collect(activecoordinates(X)), nactive(X)) == before
  # at the QUIC solution the gap is finite and small, from QUIC and from the evaluator
  Xq = SymmetricSparseIterate(q)
  r = solve!(Xq, f, g, ProxNewton(; tol = 1e-9))
  @test r.converged && isfinite(r.gap) && r.gap <= 1e-9
  dq = duality_gap(f, g, Xq)
  @test isfinite(dq.gap) && relgap(dq) <= 1e-8
  @test same(dq, duality_gap(f, g, Matrix(Xq)))
  ev = PS._gapevaluator(f, g, Xq)
  @test ev !== nothing
  rg = PS._relgap!(ev, f, g, Xq)
  @test isfinite(rg) && rg <= 1e-8
end

@testset "kkt_residual" begin
  X, y, _ = lassodata()
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  λmax = lambda_max(ls, NormL1(1.0), SparseIterate(p))
  q = QuadraticFunction(X'X / n, -X'y / n)
  for (f, g) in ((ls, NormL1(0.1λmax)), (q, NormL1(0.1λmax)), (ls, MCP(0.2λmax)), (q, ElasticNet(0.1λmax, 0.2)))
    x = SparseIterate(p)
    solve!(x, f, g, CDSolver(; tol = 1e-14))
    @test kkt_residual(f, g, x) < 1e-12
    @test kkt_residual(f, g, SparseIterate(p)) > 1e-3
    @test kkt_residual(f, g, SparseIterate(p); relative = false) ≈
          kkt_residual(f, g, SparseIterate(p)) * PS.response_scale(cdmodel(f, SparseIterate(p)), SparseIterate(p))
  end
  Sx, Sy = cov(randn(Xoshiro(15), 50, 10)), cov(randn(Xoshiro(16), 50, 10))
  fk = KronQuadratic(Sx, Sy, Sx - Sy)
  for x in (SymmetricSparseIterate(10), SparseIterate(100))
    solve!(x, fk, NormL1(0.05), CDSolver(; tol = 1e-14))
    @test kkt_residual(fk, NormL1(0.05), x) < 1e-11
  end
  @test_throws ArgumentError kkt_residual(SqrtLeastSquaresLoss(y, X), NormL1(0.1), SparseIterate(p))
end

@testset "Float32" begin
  X, y, _ = lassodata()
  n, p = size(X)
  X32, y32 = Float32.(X), Float32.(y)
  ls = (1f0 / n) * LeastSquaresLoss(y32, X32)
  λmax = lambda_max(ls, NormL1(1f0), SparseIterate(Float32, p))
  x = SparseIterate(Float32, p)
  r = solve!(x, ls, NormL1(0.1f0 * λmax), CDSolver(; gaptol = 1e-5, gapsafe = true))
  @test r.gap isa Float32 && r.gap <= 1f-5
  dg = duality_gap(ls, NormL1(0.1f0 * λmax), x)
  @test dg.gap isa Float32 && relgap(dg) <= 2f-5
end

@testset "allocations" begin
  X, y, β = lassodata()
  n, p = size(X)
  ls = (1 / n) * LeastSquaresLoss(y, X)
  yb = Float64.(rand(Xoshiro(9), n) .< 1 ./ (1 .+ exp.(-X * β)))
  logit = (1 / n) * GLMLoss(ProximalBase.Logistic(), yb, X)
  # a run with the gap allocates nothing once the state holds the gap buffers
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    fill!(x, 0.0); PS.initialize!(m, x)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for s in (CDSolver(; gaptol = 1e-9), CDSolver(; gaptol = 1e-9, gapsafe = true),
            CDSolver(; gapsafe = true, order = :cyclic), CDSolver(; gaptol = 1e-9, momentum = false))
    @test passes_bytes(SparseIterate(p), cdmodel(ls, SparseIterate(p)), NormL1(0.1), s) == 0
    @test passes_bytes(SparseIterate(p), cdmodel(logit, SparseIterate(p)), NormL1(0.02), s) == 0
  end
end

end
