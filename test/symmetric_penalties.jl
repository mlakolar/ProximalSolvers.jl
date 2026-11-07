module SymmetricPenaltyTests

# The representative cases (asymmetric weights on an owner, independent and hand-computed
# optima, linear constraints) are in symmetric_penalties_basics.jl, in the quick tier (#121).

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

include("symmetric_penalty_helpers.jl")

@testset "representative families and wrappers" begin
  families, wrappers, parameters = exactness_table()
  W = [0.5 1.0; 3.0 0.75]
  Wbar = (W .+ W') ./ 2
  A = Matrix(1.0I, 2, 2)
  f = KronQuadratic(A, A, [-0.2 -0.4; -0.4 -0.1])
  points = ([0.15 0.25; 0.25 0.2], [0.6 0.1; 0.1 0.4])
  starts = (zeros(2, 2), [0.3 0.2; 0.2 0.1])
  for (family, make, _) in families, (wrapper, wrap) in wrappers
    # each family is checked directly; NormL1 exercises each wrapper once
    wrapper != "none" && family != "NormL1" && continue
    @testset "$family / $wrapper" begin
      check_exactness(f, wrap(make(W)), wrap(make(Wbar)), (W, Wbar, parameters...), points, starts)
    end
  end
end

@testset "strict parameters reject before mutation" begin
  model = cdmodel(probe(), SymmetricSparseIterate(2))
  cases, arrays = strict_cases()
  for (name, g, _, _) in cases
    @testset "$name" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
        rejects_symmetry(x) do
          solve!(x, model, g, cdsolver())
        end
      end
    end
  end
end

@testset "strict upper bounds reject at every entry point" begin
  f = probe()
  cases, arrays = strict_cases()
  for (name, g, valid, has_level) in cases
    # upper bounds exercise every applicable entry point, including paths
    name in ("IndBox u", "Constrained u") || continue
    @testset "$name" begin
      preserves_parameters(arrays) do
        x = warm_start()
        rejects_symmetry(x) do
          solve!(x, f, g, cdsolver(); continuation = 3)
        end
        if has_level
          rejects_symmetry(x) do
            solve_path(f, g, [0.2, 0.1], cdsolver(); x, gaptol = 0)
          end
          rejects_symmetry(x) do
            lambda_max(f, g, x)
          end
        end
        rejects_symmetry(x) do
          kkt_residual(f, g, x)
        end
        rejects_symmetry(x) do
          SolverWorkspace(x, f, g, cdsolver())
        end
        ws = SolverWorkspace(x, f, valid, cdsolver())
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
      # direct families and wrapped NormL1 cover the identity rule
      name != "none" && !(g isa NormL1) && continue
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
    family == "NormL1" || continue
    wrapper != "none" && continue
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
  # the pair has the penalty λ (w12 + w21)|z| = 4λ|z| on the loss z² - 0.5z
  closed(λ) = max(0.5 - 4λ, 0.0) / 2
  preserves_parameters((W, Wbar)) do
    @test lambda_max(f, gbar, SymmetricSparseIterate(2)) ≈ 0.125
    x = warm_start()
    rejects_symmetry(x) do
      lambda_max(f, g, x)
    end
  end
  for screening in (false, true)
    preserves_parameters((W, Wbar)) do
      x = warm_start()
      rejects_symmetry(x) do
        solve!(x, f, g, cdsolver(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      end
      levels = [0.15, 0.1, 0.05]
      rejects_symmetry(x) do
        solve_path(f, g, levels, cdsolver(); x, screening, gaptol = 0)
      end
      y = warm_start()
      rb = solve!(y, f, gbar, cdsolver(); continuation = 3, continuation_tol = 1e-13, screening, gaptol = 0)
      @test rb.converged
      @test Matrix(y) ≈ [0.0 closed(0.1); closed(0.1) 0.0] atol = 1e-10
      pb = solve_path(f, gbar, levels, cdsolver(); x = warm_start(), screening, gaptol = 0)
      @test pb.λ == levels
      @test all(pb.converged)
      for k in eachindex(levels)
        X = Matrix(pb.solutions[k])
        z = closed(levels[k])
        @test X ≈ [0.0 z; z 0.0] atol = 1e-10
        @test pb.values[k] ≈ f(X) + NormL1(levels[k], Wbar)(X) rtol = 1e-12
        # the raw weights give the same dense value: only an owner has pairs of variables
        @test pb.values[k] ≈ f(X) + NormL1(levels[k], W)(X) rtol = 1e-12
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
  solve!(reference, fk, NormL1(0.1, Wbar), cdsolver())
  @test symmetric_l1_violation(S * Matrix(reference) * S + S, Matrix(reference), 0.1, Wbar) <= 1e-8
  qref = zeros(3, 3)
  method = ProxNewton(; tol = 1e-11, inner = cdsolver())
  solve!(qref, fg, NormL1(0.1, Wbar), method)
  @test !iszero(qref[1, 2])
  @test symmetric_l1_violation(S - inv(qref), qref, 0.1, Wbar) <= 1e-4
  # CD takes an owner. QUIC takes an owner, with the weights checked, and a dense
  # matrix, whose asymmetric NormL1 weights are replaced by the means of their pairs.
  for weights in (W, Wbar, Int.(W), Int.(Wbar)), vector_weights in (false, true)
    # integer matrices cover integer acceptance; integer vectors stay in the full grid
    eltype(weights) <: Integer && vector_weights && continue
    w = vector_weights ? vec(copy(weights)) : copy(weights)
    g = NormL1(0.1, w)
    symmetric = issymmetric(reshape(w, 3, 3))
    preserves_parameters((w, W, Wbar)) do
      if symmetric
        @test PS._symmetric_penalty(g, SymmetricSparseIterate(3)) === g
        x = SymmetricSparseIterate(3)
        solve!(x, fk, g, cdsolver())
        @test Matrix(x) ≈ Matrix(reference) atol = 1e-12
        @test symmetric_l1_violation(S * Matrix(x) * S + S, Matrix(x), 0.1, Wbar) <= 1e-8
      else
        x = SymmetricSparseIterate(3)
        x[2, 1] = 0.3
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
        rejects_symmetry(x) do
          solve!(x, fk, g, cdsolver())
        end
      end
    end
    # integer weights are checked by CD here and by QUIC in the full grid
    eltype(w) <: Integer && continue
    # a dense matrix takes any weights; an owner only symmetric ones
    for x in (zeros(3, 3), SymmetricSparseIterate(3))
      preserves_parameters((w, W, Wbar)) do
        if x isa SymmetricSparseIterate && !symmetric
          x[3, 1] = 0.1
          rejects_symmetry(x) do
            solve!(x, fg, g, method)
          end
          rejects_symmetry(x) do
            duality_gap(fg, g, x)
          end
        else
          r = solve!(x, fg, g, method)
          @test r.converged
          @test Matrix(x) ≈ qref atol = 1e-10
          @test Matrix(x) == Matrix(x)'
          @test duality_gap(fg, g, x).gap <= 1e-8
        end
      end
    end
  end
end

@testset "infinite zero and large finite weights" begin
  f = probe()
  # asymmetric weights, rejected; their symmetric parts are explicit weights
  for (W, Wbar, z) in (([0.0 Inf; 1.0 0.0], [0.0 Inf; Inf 0.0], 0.0),
                       ([0.0 0.0; 4.0 0.0], [0.0 2.0; 2.0 0.0], 0.05))
    preserves_parameters((W, Wbar)) do
      x = warm_start()
      rejects_symmetry(x) do
        solve!(x, f, NormL1(0.1, W), cdsolver())
      end
      x = SymmetricSparseIterate(2)
      r = solve!(x, f, NormL1(0.1, Wbar), cdsolver())
      @test r.converged && isfinite(r.minimum)
      @test isfinite(f(Matrix(x)) + NormL1(0.1, Wbar)(Matrix(x)))
      @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
    end
  end
  M = floatmax(Float64)
  W = [M M; M / 2 M]
  preserves_parameters((W,)) do
    x = warm_start()
    rejects_symmetry(x) do
      PS._symmetric_penalty(NormL1(0.1, W), x)
    end
    # the dense boundary replaces asymmetric NormL1 weights by the means of the pairs
    mean = PS._dense_symmetric_weights(NormL1(0.1, W), 2)
    @test isfinite(mean.w[1, 2])
    @test mean.w[1, 2] == mean.w[2, 1] == 0.75M
    @test mean.w[1, 1] == mean.w[2, 2] == M
  end
  S = [1.0 0.5; 0.5 1.0]
  W = [0.0 1e308; 1e308 0.0]
  preserves_parameters((W,)) do
    for x in (zeros(2, 2),)
      r = solve!(x, LogDetLoss(S), NormL1(1e-309, W), ProxNewton(; tol = 1e-11, inner = cdsolver()))
      @test r.converged && !iszero(x[1, 2])
      @test isfinite(r.minimum) && r.minimum < 2
      @test Matrix(x) == Matrix(x)'
    end
  end
end

# closed forms of the probe problem z² - 0.5z with the pair penalty λ (w12 + w21)|z|
probe_pair(λ, wsum) = max(0.5 - λ * wsum, 0.0) / 2

@testset "workspace supplied penalties and reweighting" begin
  f = probe()
  for W in ([0.0 2.0; 2.0 0.0], [0 2; 2 0])
    Wsame = oftype(W, [0 3; 3 0])
    Wraw = oftype(W, [0 2; 4 0])
    g = NormL1(0.1, W)
    x = SymmetricSparseIterate(2)
    ws = SolverWorkspace(x, f, g, cdsolver())
    @test ws.g === g
    # a replacement with asymmetric weights is rejected, the workspace stays usable
    xw = warm_start()
    wsw = SolverWorkspace(xw, f, g, cdsolver())
    rejects_in_workspace(wsw) do
      solve!(wsw, NormL1(0.1, Wraw))
    end
    rejects_symmetry(xw) do
      SolverWorkspace(xw, f, NormL1(0.1, Wraw), cdsolver())
    end
    fresh = SymmetricSparseIterate(Matrix(xw))
    @test solve!(wsw).converged && solve!(fresh, f, g, cdsolver()).converged
    @test Matrix(xw) ≈ Matrix(fresh) atol = 1e-12
    for (k, penalty) in enumerate((g, NormL1(0.1, Wsame)))
      preserves_parameters((W, Wsame, Wraw)) do
        fresh = SymmetricSparseIterate(Matrix(x))
        reference = solve!(fresh, f, penalty, cdsolver())
        result = k == 1 ? solve!(ws) : solve!(ws, penalty)
        @test result.converged && reference.converged
        @test Matrix(x) ≈ Matrix(fresh) atol = 1e-12
        z = probe_pair(0.1, penalty.w[1, 2] + penalty.w[2, 1])
        @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
        @test result.minimum ≈ reference.minimum atol = 1e-14
        @test ws.g === g
      end
    end
  end
  Wsym = [0.0 2.0; 2.0 0.0]
  Wnext = [0.0 1.0; 1.0 0.0]
  Wraw = [0.0 0.0; 2.0 0.0]
  g, next = NormL1(0.1, Wsym), NormL1(0.1, Wnext)
  seen = Ref(0)
  update = function (supplied, x, model)
    seen[] += 1
    @test supplied === (seen[] == 1 ? g : next)
    (next, seen[] == 1 ? 1.0 : 0.0)
  end
  preserves_parameters((Wsym, Wnext, Wraw)) do
    result = reweight!(SymmetricSparseIterate(2), f, g, update, cdsolver(); maxiter = 2)
    @test seen[] == 2 && result.iterations == 2
    @test result.penalty === next && result.next === next
    @test result.cd_converged
    @test Matrix(result.minimizer) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-12
    # a stage with asymmetric weights is rejected when it is solved; an earlier stage has written
    @test_throws ArgumentError reweight!(SymmetricSparseIterate(2), f, g,
      (supplied, x, model) -> (NormL1(0.1, Wraw), 1.0), cdsolver(); maxiter = 2)
    # a first stage with asymmetric weights is rejected before anything is written
    x = warm_start()
    rejects_symmetry(x) do
      reweight!(x, f, NormL1(0.1, Wraw), update, cdsolver(); maxiter = 2)
    end
  end
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  preserves_parameters((W, Wbar)) do
    x = warm_start()
    rejects_symmetry(x) do
      solve!(x, f, CappedL1(0.1, 1.0, W), LLA(cdsolver()))
    end
    rejects_symmetry(x) do
      solve_path(f, CappedL1(0.1, 1.0, W), [0.2, 0.1], LLA(cdsolver()); x)
    end
    b = solve!(SymmetricSparseIterate(2), f, CappedL1(0.1, 1.0, Wbar), LLA(cdsolver()))
    @test b.cd_converged
    @test Matrix(b.minimizer) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-12
    @test issymmetric(reshape(b.penalty.w, 2, 2))
    @test issymmetric(reshape(b.next.w, 2, 2))
    @test reshape(b.penalty.w, 2, 2) == Wbar
  end
end

@testset "gradient solvers and block workspaces" begin
  f = probe()
  W, Wnext = [0.0 2.0; 2.0 0.0], [0.0 1.0; 1.0 0.0]
  Wraw, Wnextraw = [0.0 1.0; 3.0 0.0], [0.0 0.0; 2.0 0.0]
  for method in gradient_methods(), blocks in (false, true)
    x = SymmetricSparseIterate(2)
    initial = blocks ? (x,) : x
    loss = blocks ? SeparableSum(f) : f
    penalty = blocks ? SeparableSum(NormL1(0.1, W)) : NormL1(0.1, W)
    replacement = blocks ? SeparableSum(NormL1(0.1, Wnext)) : NormL1(0.1, Wnext)
    raw = blocks ? SeparableSum(NormL1(0.1, Wraw)) : NormL1(0.1, Wraw)
    rawnext = blocks ? SeparableSum(NormL1(0.1, Wnextraw)) : NormL1(0.1, Wnextraw)
    xw = warm_start()
    initialw = blocks ? (xw,) : xw
    preserves_parameters((W, Wnext, Wraw, Wnextraw)) do
      result = solve!(initial, loss, penalty, method, gradient_options())
      @test result.converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
      # raw asymmetric weights are rejected before the iterate, the workspace or the arrays change
      rejects_symmetry(xw) do
        solve!(initialw, loss, raw, method, gradient_options())
      end
      rejects_symmetry(xw) do
        SolverWorkspace(initialw, loss, raw, method, gradient_options())
      end
    end
    # one positive reuse case complements the full strict workspace checks
    method isa ProximalGradientDescent && !blocks || continue
    preserves_parameters((W, Wnext, Wraw, Wnextraw)) do
      ws = SolverWorkspace(initial, loss, penalty, method, gradient_options())
      @test ws.g === penalty
      @test solve!(ws).converged
      @test Matrix(x) ≈ [0.0 0.05; 0.05 0.0] atol = 1e-6
      before = Matrix(x)
      rejects_in_workspace(ws) do
        solve!(ws, rawnext)
      end
      @test Matrix(x) == before
      @test solve!(ws, replacement).converged
      @test Matrix(x) ≈ [0.0 0.15; 0.15 0.0] atol = 1e-6
      @test ws.g === penalty
    end
  end
  # a SeparableSum over a tuple is checked block by block: only a block with an owner has pairs
  xw = warm_start()
  g = SeparableSum(NormL1(0.1, Wraw), NormL1(0.2, [0.0 1.0; 3.0 0.0]))
  rejects_symmetry(xw) do
    PS._symmetric_penalty(g, (xw, zeros(2, 2)))
  end
  ok = SeparableSum(NormL1(0.1, W), NormL1(0.2, [0.0 1.0; 3.0 0.0]))
  @test PS._symmetric_penalty(ok, (xw, zeros(2, 2))) === ok
  @test PS._symmetric_penalty(ok, (xw, SparseIterate(2, 2))) === ok
end

# A pair is symmetric when its entries are equal (isequal, or == that is true), checked here by
# LinearFunction and SqrNormL2, whose constructors admit every value: the symmetry check, apart
# from any parameter domain of a penalty, which a symmetric pair does not satisfy by being symmetric.
@testset "boundary pairs of the symmetry check" begin
  pairs = ((1.0, 1.0, true), (1.0, 2.0, false), (0.0, -0.0, true), (-0.0, 0.0, true),
           (NaN, NaN, true), (NaN, 1.0, false), (1.0, NaN, false), (Inf, Inf, true),
           (Inf, -Inf, false), (-Inf, -Inf, true), (floatmin(Float64) / 2, 0.0, false))
  for (a, b, symmetric) in pairs
    W = [0.0 a; b 0.0]
    saved = copy(W)
    for g in (LinearFunction(W), SqrNormL2(0.5, W), Scaled(LinearFunction(W), 2.0),
              Translate(NormL1(0.1), W))
      x = warm_start()
      if symmetric
        @test PS._symmetric_penalty(g, x) === g
      else
        rejects_symmetry(x) do
          PS._symmetric_penalty(g, x)
        end
      end
    end
    @test isequal(W, saved)
  end
  # integer entries and a vector in column-major order
  x = warm_start()
  g = LinearFunction([0, 2, 2, 0])
  @test PS._symmetric_penalty(g, x) === g
  rejects_symmetry(x) do
    PS._symmetric_penalty(LinearFunction([0, 2, 3, 0]), x)
  end
end

@testset "symmetric by type" begin
  W = [0.5 1.0; 3.0 0.75]
  for uplo in (:L, :U)
    S = Symmetric(W, uplo)
    for g in (NormL1(0.1, S), LinearFunction(S), SqrNormL2(0.5, S), Tilt(NormL1(0.1), S, 0.25))
      @test PS._symmetric_penalty(g, warm_start()) === g
    end
  end
  # the lower triangle: the pair weight is 3 + 3, the upper triangle's is 1 + 1
  f = probe()
  lower, upper = [0.0 3.0; 3.0 0.0], [0.0 1.0; 1.0 0.0]
  for (uplo, Wsym) in ((:L, lower), (:U, upper))
    x, y = SymmetricSparseIterate(2), SymmetricSparseIterate(2)
    @test solve!(x, f, NormL1(0.1, Symmetric(W, uplo)), cdsolver()).converged
    @test solve!(y, f, NormL1(0.1, Wsym), cdsolver()).converged
    z = probe_pair(0.1, 2Wsym[1, 2])
    @test Matrix(x) ≈ [0.0 z; z 0.0] atol = 1e-12
    @test Matrix(x) ≈ Matrix(y) atol = 1e-12
  end
end

# a construction, a replacement penalty, a direct solve and a path that are rejected leave the
# workspace usable: a valid solve then equals the one of a workspace that never saw them
@testset "workspace integrity after a rejection" begin
  f = probe()
  W, Wbad = [0.0 2.0; 2.0 0.0], [0.0 1.0; 3.0 0.0]
  g, bad = NormL1(0.1, W), NormL1(0.1, Wbad)
  for method in (cdsolver(), ProximalGradientDescent())
    options = method isa CDSolver ? () : (gradient_options(),)
    x, xref = warm_start(), warm_start()
    ws = SolverWorkspace(x, f, g, method, options...)
    ref = SolverWorkspace(xref, f, g, method, options...)
    preserves_parameters((W, Wbad)) do
      rejects_in_workspace(ws) do
        solve!(ws, bad)
      end
      rejects_symmetry(x) do
        SolverWorkspace(x, f, bad, method, options...)
      end
      rejects_symmetry(x) do
        solve!(x, f, bad, method, options...)
      end
      if method isa CDSolver
        rejects_symmetry(x) do
          solve!(x, f, bad, method; continuation = 2)
        end
        rejects_symmetry(x) do
          solve_path(f, bad, [0.2, 0.1], method; x, gaptol = 0)
        end
        rejects_symmetry(x) do
          kkt_residual(f, bad, x)
        end
      end
      r, rr = solve!(ws), solve!(ref)
      @test r.converged && rr.converged
      @test Matrix(x) ≈ Matrix(xref) atol = 1e-12
      @test collect(activecoordinates(x)) == collect(activecoordinates(xref))
      @test r.minimum ≈ rr.minimum atol = 1e-14
      @test ws.g === g
    end
  end
end

# A penalty on a tuple of iterates is checked as supplied: with ProximalBase 0.6 by its public
# checker for every wrapper it declares, with earlier versions for a SeparableSum and Scaled
# around one. The rows are the supplied penalty, the closed form of the pair z at the
# explicit symmetric problem (the loss gives z² - 6z), and whether the row needs ProximalBase 0.6.
@testset "wrapped block penalties" begin
  A = Matrix(1.0I, 2, 2)
  f = SeparableSum(KronQuadratic(A, A, [0.0 -3.0; -3.0 0.0]))
  W = [0.0 1.0; 3.0 0.0]
  Wbar = (W .+ W') ./ 2
  saved = copy(W)
  explicit_scaled(g, a, b) = (s = Scaled{typeof(g), typeof(a)}(g, a); Scaled{typeof(s), typeof(b)}(s, b))
  # on a pair the penalty is the scale times 0.1 (w12 + w21)|z| = 0.4|z|
  rows = (("bare", identity, (6 - 0.4) / 2, false),
          ("Scaled", g -> Scaled(g, 2.0), (6 - 0.8) / 2, false),
          ("Scaled nested (public constructor)", g -> Scaled(Scaled(g, 2.0), 3.0), (6 - 2.4) / 2, false),
          ("Scaled nested (explicit type)", g -> explicit_scaled(g, 2.0, 3.0), (6 - 2.4) / 2, false),
          ("Conjugate", g -> Conjugate(g), 0.2, true),
          ("Scaled(Conjugate)", g -> Scaled(Conjugate(g), 2.0), 0.2, true),
          ("Conjugate(Scaled)", g -> Conjugate(Scaled(g, 2.0)), 0.4, true))
  for (name, wrap, z, needs_pb06) in rows
    needs_pb06 && !pb_checks_symmetry() && continue
    @testset "$name" begin
      bad, good = wrap(SeparableSum(NormL1(0.1, W))), wrap(SeparableSum(NormL1(0.1, Wbar)))
      @test typeof(bad) === typeof(good)
      xw = warm_start()
      @test PS._symmetric_penalty(good, (xw,)) === good
      rejects_symmetry((xw,)) do
        PS._symmetric_penalty(bad, (xw,))
      end
      for method in (ProximalGradientDescent(), AccProxGradDescent())
        xw = warm_start()
        xs = (xw,)
        rejects_symmetry(xs) do
          SolverWorkspace(xs, f, bad, method, gradient_options())
        end
        rejects_symmetry(xs) do
          solve!(xs, f, bad, method, gradient_options())
        end
        ws = SolverWorkspace(xs, f, good, method, gradient_options())
        @test ws.g === good
        xw[2, 1] = 0.05
        rejects_in_workspace(ws, xs) do
          solve!(ws, bad)
        end
        # the workspace is still usable: its solution is the one of a fresh workspace
        xf = warm_start()
        xf[2, 1] = 0.05
        fresh = SolverWorkspace((xf,), f, good, method, gradient_options())
        @test solve!(ws).converged && solve!(fresh).converged
        @test Matrix(xw) ≈ Matrix(xf) atol = 1e-12
        @test Matrix(xw) ≈ [0.0 z; z 0.0] atol = 1e-6
      end
      @test isequal(W, saved)
    end
  end
  # controls: ordinary tuples, and an owner beside ordinary blocks
  kron = KronQuadratic(A, A, [0.0 -3.0; -3.0 0.0])
  xw = warm_start()
  ordinary = (zeros(3), zeros(2, 2))
  for wrap in (identity, g -> Scaled(g, 2.0))
    g = wrap(SeparableSum(NormL1(0.1, [0.0 0.0 0.0; 1.0 0.0 0.0; 3.0 0.0 0.0]), NormL1(0.2, W)))
    @test PS._symmetric_penalty(g, ordinary) === g
    @test PS._symmetric_penalty(g, (SparseIterate(3, 3), SparseIterate(2, 2))) === g
  end
  # the asymmetric weights of an ordinary block beside a symmetric owner block are accepted
  g = SeparableSum(NormL1(0.1, Wbar), NormL1(0.2, W))
  @test PS._symmetric_penalty(g, (xw, zeros(2, 2))) === g
  f2 = SeparableSum(kron, SqrNormL2(1.0, ones(2, 2)))
  @test solve!((xw, zeros(2, 2)), f2, g, ProximalGradientDescent(), gradient_options()).converged
  # an asymmetric owner block is rejected in either position
  xw = warm_start()
  rejects_symmetry((xw, zeros(2, 2))) do
    PS._symmetric_penalty(SeparableSum(NormL1(0.1, W), NormL1(0.2, Wbar)), (xw, zeros(2, 2)))
  end
  rejects_symmetry((zeros(2, 2), xw)) do
    PS._symmetric_penalty(SeparableSum(NormL1(0.2, Wbar), NormL1(0.1, W)), (zeros(2, 2), xw))
  end
  # a penalty that couples the blocks is not inspected beyond what its declarations cover
  coupling = Scaled(NormL1(0.1, W), 2.0)
  @test PS._symmetric_penalty(coupling, (xw, zeros(2, 2))) === coupling
  @test isequal(W, saved)
end

# ProximalBase 0.6 checks more penalties than the transitional check of ProximalBase 0.5
pb_checks_symmetry() && @testset "penalties checked by ProximalBase 0.6" begin
  W = [0.0 1.0; 3.0 0.0]
  Y = [1.0 1.0; -1.0 1.0]
  a = [1.0 1.0; 0.0 1.0]
  rows = (("SqrHingeLoss w", SqrHingeLoss(Y, W)),
          ("Sum", Sum(NormL1(0.1, W), NormL1(0.1))),
          ("PointwiseMinimum", PointwiseMinimum(NormL1(0.1, W), NormL1(0.1))),
          ("IndHyperplane a", Constrained(NormL1(0.1), IndHyperplane(a, 0.0))))
  for (name, g) in rows
    @testset "$name" begin
      x = warm_start()
      rejects_symmetry(x) do
        PS._symmetric_penalty(g, x)
      end
    end
  end
end

end
