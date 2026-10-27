module SymmetricPenaltyTests

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

cd() = CDSolver(; order = :cyclic, tol = 1e-13, relative = false)
gradient_methods() = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
gradient_options() = ProximalOptions(; maxiter = 500, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-10)

function probe()
  A = Matrix(1.0I, 2, 2)
  KronQuadratic(A, A, [0.0 -0.25; -0.25 0.0])
end

function preserves_parameters(action, arrays)
  @nospecialize action
  before = map(copy, arrays)
  try
    action()
  finally
    for (a, b) in zip(arrays, before)
      @test isequal(a, b)
    end
  end
end

# a stored zero detects premature dropzeros! as well as changes of values
function warm_start()
  x = SymmetricSparseIterate(2)
  x[2, 1] = 0.2
  x[2, 2] = 0.4
  x[1, 1] = 0.3
  x[2, 2] = 0.0
  x
end

function rejects_symmetry(action, x)
  @nospecialize action
  before = (Matrix(x), collect(coordinates(x)), collect(activecoordinates(x)), nnz(x), nactive(x))
  err = try
    action()
    nothing
  catch e
    e
  end
  @test err isa ArgumentError
  if err isa ArgumentError
    @test occursin("symmetric", lowercase(sprint(showerror, err)))
  end
  @test Matrix(x) == before[1]
  @test collect(coordinates(x)) == before[2]
  @test collect(activecoordinates(x)) == before[3]
  @test nnz(x) == before[4]
  @test nactive(x) == before[5]
end

@testset "asymmetric L1 reproduction" begin
  S = [1.0 0.5; 0.5 1.0]
  f = KronQuadratic(S, S, S)
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  x, y = SymmetricSparseIterate(2), SymmetricSparseIterate(2)
  preserves_parameters((W, Wbar)) do
    @test solve!(x, f, NormL1(0.1, W), cd()).converged
    @test solve!(y, f, NormL1(0.1, Wbar), cd()).converged
    @test Matrix(x) ≈ Matrix(y) atol = 1e-12
  end
end

# each row lists the wrappers whose symmetric-parameter CD problem is supported
function exactness_table()
  Y = [1.0 -1.0; -1.0 1.0]
  families = [
    ("NormL1", w -> NormL1(0.1, w), true),
    ("NormL1Nonneg", w -> NormL1Nonneg(0.1, w), true),
    ("ElasticNet", w -> ElasticNet(0.1, 0.2, w), true),
    ("CappedL1", w -> CappedL1(0.1, 1.0, w), false),
    ("LogPenalty", w -> LogPenalty(0.1, 1.0, w), false),
    ("NormLq", w -> NormLq(0.1, 0.5, w), false),
    ("Berhu", w -> Berhu(0.1, 1.0, w), true),
    ("CheckLoss", w -> CheckLoss(0.4, w), true),
    ("EpsInsensitiveLoss", w -> EpsInsensitiveLoss(0.1, w), true),
    ("HingeLoss", w -> HingeLoss(Y, w), true),
    ("Tilt coefficient", w -> Tilt(NormL1(0.1), w, 0.125), true),
    ("LinearFunction coefficient", w -> LinearFunction(w, 0.125), true),
  ]
  C = [0.01 -0.02; -0.02 0.01]
  b = [0.02 0.01; 0.01 0.02]
  l, u = fill(-0.8, 2, 2), fill(0.8, 2, 2)
  wrappers = [
    ("none", identity),
    ("Scaled", g -> Scaled(g, 1.25)),
    ("Tilt", g -> Tilt(g, C, 0.25)),
    ("Translate", g -> Translate(g, b)),
    ("Regularize", g -> Regularize(g, 0.2, C)),
    ("Constrained", g -> Constrained(g, IndBox(l, u))),
    ("Precompose", g -> Precompose(g, 0.5)),
  ]
  families, wrappers, (C, b, l, u, Y)
end

@testset "exact family and wrapper table" begin
  families, wrappers, parameters = exactness_table()
  W = [0.5 1.0; 3.0 0.75]
  Wbar = (W .+ W') ./ 2
  A = Matrix(1.0I, 2, 2)
  f = KronQuadratic(A, A, [-0.2 -0.4; -0.4 -0.1])
  points = ([0.15 0.25; 0.25 0.2], [0.6 0.1; 0.1 0.4])
  starts = (zeros(2, 2), [0.3 0.2; 0.2 0.1])
  for (family, make, box_supported) in families, (wrapper, wrap) in wrappers
    # CappedL1, LogPenalty and NormLq on a box are excluded: ProximalBase
    # allows convex functions and MCP/SCAD/NormL0, not these three families.
    wrapper == "Constrained" && !box_supported && continue
    @testset "$family / $wrapper" begin
      g, gbar = wrap(make(W)), wrap(make(Wbar))
      arrays = (W, Wbar, parameters...)
      for X in points
        # both triangles share Xrc, so wrc φ(Xrc) + wcr φ(Xrc) = 2w̄rc φ(Xrc)
        preserves_parameters(arrays) do
          @test isfinite(g(X)) && isfinite(gbar(X))
          @test g(X) ≈ gbar(X) rtol = 1e-12
        end
      end
      preserves_parameters(arrays) do
        @test PS._symmetric_penalty(gbar, SymmetricSparseIterate(2)) === gbar
      end
      for start in starts
        x, y = SymmetricSparseIterate(start), SymmetricSparseIterate(start)
        # solve the explicitly averaged problem first to verify support
        preserves_parameters(arrays) do
          @test solve!(y, f, gbar, cd()).converged
        end
        preserves_parameters(arrays) do
          r = solve!(x, f, g, cd())
          @test r.converged
          @test Matrix(x) ≈ Matrix(y) atol = 1e-12
          @test r.minimum ≈ f(Matrix(x)) + g(Matrix(x)) rtol = 1e-12 atol = 1e-14
        end
      end
    end
  end
end

@testset "independent optimality from the supplied weights" begin
  rng = Xoshiro(113)
  p = 5
  R = randn(rng, p, p)
  S = R'R / p + I
  C = randn(rng, p, p)
  C = (C + C') / 2
  W = 0.2 .+ rand(rng, p, p)
  f = KronQuadratic(S, S, C)
  λ = 0.1
  for ridge in (0.0, 0.2)
    g = iszero(ridge) ? NormL1(λ, W) : ElasticNet(λ, ridge, W)
    x = SymmetricSparseIterate(p)
    preserves_parameters((W,)) do
      @test solve!(x, f, g, cd()).converged
      X = Matrix(x)
      G = S * X * S + C
      @test any(iszero, X) && any(!iszero, X)
      # pair derivatives are 2Grc + 2ρz; diagonal derivatives have multiplicity one
      for c in 1:p, r in c:p
        z = X[r, c]
        h = r == c ? G[r, c] + ridge * z : 2G[r, c] + 2ridge * z
        threshold = λ * (r == c ? W[r, c] : W[r, c] + W[c, r])
        if iszero(z)
          @test abs(h) <= threshold + 1e-8
        else
          @test abs(h + threshold * sign(z)) <= 1e-8
        end
      end
      @test kkt_residual(f, g, x; relative = false) <= 1e-8
    end
  end
end

@testset "hand computed optima" begin
  f = probe()
  W = [0.0 1.0; 3.0 0.0]
  C = [0.0 0.5; -0.5 0.0]
  L = [0.0 0.0; -1.0 0.0]
  # z² - 0.5z + c|z| gives z = (0.5-c)/2 when 0 ≤ c < 0.5.
  # c is 0.4 for L1/capped/boxed L1 and 0.2 after precomposition by 0.5.
  # the antisymmetric tilt cancels; the linear coefficient adds -z, giving 0.75.
  cases = ((NormL1(0.1, W), 0.05), (CappedL1(0.1, 1.0, W), 0.05),
           (Constrained(NormL1(0.1, W), IndBox(-1.0, 1.0)), 0.05),
           (Precompose(NormL1(0.1, W), 0.5), 0.15),
           (Tilt(NormL1(0.1), C), 0.15), (LinearFunction(L), 0.75))
  for (g, z) in cases
    preserves_parameters((W, C, L)) do
      x = SymmetricSparseIterate(2)
      result = solve!(x, f, g, cd())
      @test result.converged
      @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
      @test result.minimum ≈ f(Matrix(x)) + g(Matrix(x)) atol = 1e-14
      if g === cases[1][1]
        @test result.minimum ≈ -0.0025 atol = 1e-14
      end
    end
  end
end

function strict_cases()
  W = [1.0 1.0; 3.0 1.0]
  Wbar = (W .+ W') ./ 2
  l, u = -W, W
  P = Bool[1 1; 0 1]
  Y = [1.0 1.0; -1.0 1.0]
  # only the box-constrained L1 rows have a path level; Scaled does not
  # preserve that path API. All rows support ordinary CD and gradient solves.
  cases = [
    ("IndBox l", IndBox(l, 4.0), IndBox(-Wbar, 4.0), false),
    ("IndBox u", IndBox(-4.0, u), IndBox(-4.0, Wbar), false),
    ("Constrained l", Constrained(NormL1(0.1), IndBox(l, 4.0)),
      Constrained(NormL1(0.1), IndBox(-Wbar, 4.0)), true),
    ("Constrained u", Constrained(NormL1(0.1), IndBox(-4.0, u)),
      Constrained(NormL1(0.1), IndBox(-4.0, Wbar)), true),
    ("IndPattern P", IndPattern(P), IndPattern(trues(2, 2)), false),
    ("SqrNormL2 y", SqrNormL2(0.2, W), SqrNormL2(0.2, Wbar), false),
    ("Regularize c", Regularize(NormL1(0.1), 0.2, W),
      Regularize(NormL1(0.1), 0.2, Wbar), false),
    ("Translate b", Translate(NormL1(0.1), W), Translate(NormL1(0.1), Wbar), false),
    ("HingeLoss y", HingeLoss(Y), HingeLoss(ones(2, 2)), false),
    ("KLDivergence q", KLDivergence(W), KLDivergence(Wbar), false),
    ("MoreauEnvelope weights", MoreauEnvelope(NormL1(0.1, W), 0.5),
      MoreauEnvelope(NormL1(0.1, Wbar), 0.5), false),
    ("Conjugate weights", Conjugate(NormL1(0.1, W)), Conjugate(NormL1(0.1, Wbar)), false),
  ]
  cases, (W, Wbar, l, u, P, Y)
end

@testset "strict parameters reject before mutation" begin
  f = probe()
  cases, arrays = strict_cases()
  for (name, bad, good, has_level) in cases, wrapped in (false, true)
    g = wrapped ? Scaled(bad, 1.25) : bad
    valid = wrapped ? Scaled(good, 1.25) : good
    @testset "$name / wrapped=$wrapped" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
        rejects_symmetry(x) do
          solve!(x, f, g, cd())
        end
        rejects_symmetry(x) do
          solve!(x, f, g, cd(); continuation = 3)
        end
        if has_level && !wrapped
          rejects_symmetry(x) do
            solve_path(f, g, [0.2, 0.1], cd(); x, gaptol = 0)
          end
          rejects_symmetry(x) do
            lambda_max(f, g, x)
          end
        end
        rejects_symmetry(x) do
          kkt_residual(f, g, x)
        end
        rejects_symmetry(x) do
          SolverWorkspace(x, f, g, cd())
        end
        ws = SolverWorkspace(x, f, valid, cd())
        rejects_symmetry(x) do
          solve!(ws, g)
        end
        for method in gradient_methods()
          rejects_symmetry(x) do
            solve!(x, f, g, method, gradient_options())
          end
          rejects_symmetry(x) do
            SolverWorkspace(x, f, g, method, gradient_options())
          end
          wg = SolverWorkspace(x, f, valid, method, gradient_options())
          rejects_symmetry(x) do
            solve!(wg, g)
          end
        end
      end
    end
  end
end

@testset "identity for absent parameters and other storage" begin
  families, wrappers, arrays = exactness_table()
  x = SymmetricSparseIterate(2)
  absent = (NormL1(0.1), NormL1Nonneg(0.1), ElasticNet(0.1, 0.2), CappedL1(0.1, 1.0),
            LogPenalty(0.1, 1.0), NormLq(0.1, 0.5), Berhu(0.1, 1.0), CheckLoss(0.4),
            EpsInsensitiveLoss(0.1), HingeLoss(), ZeroFunction(), SqrNormL2(0.2),
            IndBox(-1.0, 1.0), KLDivergence(1.0))
  preserves_parameters(arrays) do
    for g in absent, (name, wrap) in wrappers
      # the same nonconvex box exclusions as the exactness table
      name == "Constrained" && g isa Union{CappedL1, LogPenalty, NormLq} && continue
      penalty = wrap(g)
      @test PS._symmetric_penalty(penalty, x) === penalty
    end
  end
  cases, strict_arrays = strict_cases()
  preserves_parameters(strict_arrays) do
    for (_, _, g, _) in cases
      @test PS._symmetric_penalty(g, x) === g
      wrapped = Scaled(g, 1.25)
      @test PS._symmetric_penalty(wrapped, x) === wrapped
    end
  end
  W = [0.0 1.0; 3.0 0.0]
  other_storage = (SparseIterate(2, 2), AtomIterate(4, [1:2, 3:4]), zeros(2, 2), zeros(4))
  for (family, make, box_supported) in families, (wrapper, wrap) in wrappers
    wrapper == "Constrained" && !box_supported && continue
    g = wrap(make(W))
    preserves_parameters((W, arrays...)) do
      for y in other_storage
        @test PS._symmetric_penalty(g, y) === g
      end
    end
  end
  g = SeparableSum(NormL1(0.1, [0.0 2.0; 2.0 0.0]), NormL1(0.2))
  @test PS._symmetric_penalty(g, (SymmetricSparseIterate(2), zeros(3))) === g
end

@testset "paths continuation and supplied objective" begin
  f = probe()
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  g, gbar = NormL1(0.1, W), NormL1(0.1, Wbar)
  preserves_parameters((W, Wbar)) do
    @test lambda_max(f, g, SymmetricSparseIterate(2)) ≈ 0.125
  end
  for screening in (false, true)
    preserves_parameters((W, Wbar)) do
      x, y = warm_start(), warm_start()
      ra = solve!(x, f, g, cd(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      rb = solve!(y, f, gbar, cd(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      @test ra.converged && rb.converged
      @test Matrix(x) ≈ Matrix(y) atol = 1e-10
      levels = [0.15, 0.1, 0.05]
      pa = solve_path(f, g, levels, cd(); x = warm_start(), screening, gaptol = 0)
      pb = solve_path(f, gbar, levels, cd(); x = warm_start(), screening, gaptol = 0)
      @test pa.λ == pb.λ == levels
      @test all(pa.converged) && all(pb.converged)
      for k in eachindex(levels)
        X = Matrix(pa.solutions[k])
        @test X ≈ Matrix(pb.solutions[k]) atol = 1e-10
        @test pa.values[k] ≈ f(X) + NormL1(levels[k], W)(X) rtol = 1e-12
      end
    end
  end
end

@testset "weight shapes and integer arrays" begin
  S = [1.0 0.5 0.0; 0.5 1.0 0.0; 0.0 0.0 1.2]
  W = [0.0 1.0 1.0; 3.0 0.0 1.0; 1.0 1.0 0.0]
  Wbar = (W .+ W') ./ 2
  fk, fg = KronQuadratic(S, S, S), LogDetLoss(S)
  reference = SymmetricSparseIterate(3)
  solve!(reference, fk, NormL1(0.1, Wbar), cd())
  qref = zeros(3, 3)
  method = ProxNewton(; tol = 1e-11, inner = cd())
  solve!(qref, fg, NormL1(0.1, Wbar), method)
  @test !iszero(qref[1, 2])
  # CD's matrix API uses SymmetricSparseIterate; QUIC also takes dense matrices.
  for weights in (W, Wbar, Int.(W), Int.(Wbar)), vector_weights in (false, true)
    w = vector_weights ? vec(copy(weights)) : copy(weights)
    preserves_parameters((w,)) do
      prepared = PS._symmetric_penalty(NormL1(0.1, w), SymmetricSparseIterate(3))
      @test size(prepared.w) == size(w)
      @test reshape(prepared.w, 3, 3) == Wbar
      if !issymmetric(reshape(w, 3, 3))
        @test eltype(prepared.w) <: AbstractFloat
      end
    end
    preserves_parameters((w, W, Wbar)) do
      x = SymmetricSparseIterate(3)
      solve!(x, fk, NormL1(0.1, w), cd())
      @test Matrix(x) ≈ Matrix(reference) atol = 1e-12
    end
    for x in (zeros(3, 3), SymmetricSparseIterate(3))
      preserves_parameters((w, W, Wbar)) do
        r = solve!(x, fg, NormL1(0.1, w), method)
        @test r.converged
        @test Matrix(x) ≈ qref atol = 1e-10
        @test Matrix(x) == Matrix(x)'
        @test duality_gap(fg, NormL1(0.1, w), x).gap <= 1e-8
      end
    end
  end
end

@testset "infinite zero and large finite weights" begin
  f = probe()
  for W in ([0.0 Inf; 1.0 0.0], [0.0 0.0; 4.0 0.0])
    preserves_parameters((W,)) do
      x = SymmetricSparseIterate(2)
      r = solve!(x, f, NormL1(0.1, W), cd())
      @test r.converged && isfinite(r.minimum)
      @test isfinite(f(Matrix(x)) + NormL1(0.1, W)(Matrix(x)))
      z = isinf(W[1, 2]) ? 0.0 : 0.05
      @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
      if isfinite(W[1, 2])
        y = SymmetricSparseIterate(2)
        solve!(y, f, NormL1(0.1, [0.0 2.0; 2.0 0.0]), cd())
        @test Matrix(x) ≈ Matrix(y) atol = 1e-12
      end
    end
  end
  M = floatmax(Float64)
  W = [M M; M / 2 M]
  preserves_parameters((W,)) do
    normalized = PS._symmetric_penalty(NormL1(0.1, W), SymmetricSparseIterate(2))
    @test isfinite(normalized.w[1, 2])
    @test normalized.w[1, 2] == normalized.w[2, 1] == 0.75M
    @test normalized.w[1, 1] == normalized.w[2, 2] == M
  end
  S = [1.0 0.5; 0.5 1.0]
  W = [0.0 1e308; 1e308 0.0]
  preserves_parameters((W,)) do
    for x in (zeros(2, 2), SymmetricSparseIterate(2))
      r = solve!(x, LogDetLoss(S), NormL1(1e-309, W), ProxNewton(; tol = 1e-11, inner = cd()))
      @test r.converged && !iszero(x[1, 2])
      @test isfinite(r.minimum) && r.minimum < 2
      @test Matrix(x) == Matrix(x)'
    end
  end
end

@testset "workspace supplied penalties and reweighting" begin
  f = probe()
  for W in ([0.0 1.0; 3.0 0.0], [0 1; 3 0])
    Wbar = oftype(W, [0 2; 2 0])
    Wother = oftype(W, [0 2; 4 0])
    g = NormL1(0.1, W)
    x = SymmetricSparseIterate(2)
    ws = SolverWorkspace(x, f, g, cd())
    @test ws.g === g
    for (k, penalty) in enumerate((g, NormL1(0.1, Wbar), NormL1(0.1, Wother)))
      preserves_parameters((W, Wbar, Wother)) do
        fresh = SymmetricSparseIterate(Matrix(x))
        reference = solve!(fresh, f, penalty, cd())
        result = k == 1 ? solve!(ws) : solve!(ws, penalty)
        @test result.converged && reference.converged
        @test Matrix(x) ≈ Matrix(fresh) atol = 1e-12
        @test result.minimum ≈ reference.minimum atol = 1e-14
        @test ws.g === g
      end
    end
  end
  W = [0.0 1.0; 3.0 0.0]
  Wnext = [0.0 0.0; 2.0 0.0]
  g, next = NormL1(0.1, W), NormL1(0.1, Wnext)
  seen = Ref(0)
  update = function (supplied, x, model)
    seen[] += 1
    @test supplied === (seen[] == 1 ? g : next)
    (next, seen[] == 1 ? 1.0 : 0.0)
  end
  preserves_parameters((W, Wnext)) do
    result = reweight!(SymmetricSparseIterate(2), f, g, update, cd(); maxiter = 2)
    @test seen[] == 2 && result.iterations == 2
    @test result.penalty === next && result.next === next
    @test result.cd_converged
    @test Matrix(result.minimizer) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-12
  end
  Wbar = (W .+ W') ./ 2
  preserves_parameters((W, Wbar)) do
    a = solve!(SymmetricSparseIterate(2), f, CappedL1(0.1, 1.0, W), LLA(cd()))
    b = solve!(SymmetricSparseIterate(2), f, CappedL1(0.1, 1.0, Wbar), LLA(cd()))
    @test a.cd_converged && b.cd_converged
    @test Matrix(a.minimizer) ≈ Matrix(b.minimizer) atol = 1e-12
    @test issymmetric(reshape(a.penalty.w, 2, 2))
    @test issymmetric(reshape(a.next.w, 2, 2))
    @test reshape(a.penalty.w, 2, 2) == Wbar
  end
end

@testset "gradient solvers and block workspaces" begin
  f = probe()
  W, Wnext = [0.0 1.0; 3.0 0.0], [0.0 0.0; 2.0 0.0]
  for method in gradient_methods(), blocks in (false, true)
    x = SymmetricSparseIterate(2)
    initial = blocks ? (x,) : x
    loss = blocks ? SeparableSum(f) : f
    penalty = blocks ? SeparableSum(NormL1(0.1, W)) : NormL1(0.1, W)
    replacement = blocks ? SeparableSum(NormL1(0.1, Wnext)) : NormL1(0.1, Wnext)
    preserves_parameters((W, Wnext)) do
      result = solve!(initial, loss, penalty, method, gradient_options())
      @test result.converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
      ws = SolverWorkspace(initial, loss, penalty, method, gradient_options())
      @test ws.g === penalty
      @test solve!(ws).converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
      @test solve!(ws, replacement).converged
      @test Matrix(x) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-6
      @test ws.g === penalty
    end
  end
end

end
