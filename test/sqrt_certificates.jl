module SqrtCertificates

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

quiet(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())
pair(y, X) = (SqrtLeastSquaresLoss(y, X), SqrtQuadraticFunction(X'X, -X'y, dot(y, y)))

function bounds_optimum(r, optimum)
  T = typeof(r.gap)
  rounding = 512eps(T) * max(abs(r.minimum), abs(optimum), floatmin(T))
  @test isfinite(r.gap) && r.gap >= 0
  @test r.minimum - optimum <= r.gap * max(r.minimum, floatmin(T)) + rounding
end

@testset "square-root certificates" begin
  @testset "residual recomputation retains cancelled coefficients" begin
    for T in (Float64, Float32)
      M = T(2)^(T === Float64 ? 55 : 26)
      u, v = T[1, -1, 1, -1], T[1, 1, -1, -1]
      X, y = hcat(u, u, u, v), v
      g = NormL1(T(0.1), T[0, 0, 0, 1])
      for design in (X, sparse(X)), centered in (false, true)
        x = SparseIterate(T[M, 1, -M, 1])
        m = cdmodel(SqrtLeastSquaresLoss(y, design), x; intercept = centered)
        r = quiet(() -> solve!(x, m, g, CDSolver(order = :cyclic)))
        xb = big.(Vector(x))
        residual = big.(y) - big.(X) * xb
        centered && (residual .-= sum(residual) / length(residual))
        P = norm(residual) + big(g.λ0) * abs(xb[4])
        optimum = big(g.λ0)
        @test P ≈ 2 + optimum
        @test !r.converged && isfinite(r.gap)
        @test P - optimum <= big(r.gap) * P + 512eps(T) * P
        data = PS._sqrt_dualdata(m, x)
        @test big(data.f) >= norm(residual)
        # A cached zero objective needs the same upper residual check.
        z = SparseIterate(T[M, 1, -M, 1])
        rz = quiet(() -> solve!(z, cdmodel(SqrtLeastSquaresLoss(y, design), z; intercept = centered),
                                 NormL1(zero(T)), CDSolver(order = :cyclic)))
        @test !rz.converged && rz.gap >= 1 - 512eps(T)
      end
      # The sufficient-statistic cancellation has a larger, explicit budget.
      x = SparseIterate(T[M, 1, -M, 1])
      f = SqrtQuadraticFunction(X'X, -X'y, dot(y, y))
      m = cdmodel(f, x)
      data = PS._sqrt_dualdata(m, x)
      @test big(data.q) + big(data.δq) >= 4
      @test data.f >= 2
      r = quiet(() -> solve!(x, m, g, CDSolver(maxpasses = 0)))
      @test !r.converged && r.gap >= (2 - 512eps(T)) / T(2.1)
    end
  end

  @testset "zero unrestricted correlations need no inverse" begin
    for T in (Float64, Float32), design in (T[1 2; 0 0], sparse(T[1 2; 0 0]))
      for f in pair(T[1, 1], design)
        r = solve!(SparseIterate(T, 2), f, NormL1(zero(T)), CDSolver(order = :cyclic))
        @test r.converged && r.minimum ≈ 1
        @test r.gap <= 512eps(T)
        bounds_optimum(r, one(T))
      end
    end
  end

  @testset "rounded correlations retain small penalized constraints" begin
    for T in (Float64, Float32)
      τ = T === Float64 ? T(2)^-60 : T(2)^-30
      X = T[1 0 τ 0; 1 1 1 1; -1 1 1 -1]
      y = T[1, 1, -1]
      g = NormL1(one(T), T[0.3, τ / 1024, τ / 1024, 0.2])
      better = T[0, -inv(τ), inv(τ), 1]
      @test X * better == y
      bettervalue = g(better)
      for design in (X, sparse(X))
        r = quiet(() -> solve!(SparseIterate(T[1, 0, 0, 0]), SqrtLeastSquaresLoss(y, design), g,
                                CDSolver(order = :cyclic)))
        @test !r.converged && isfinite(r.gap)
        @test r.minimum - bettervalue <= r.gap * r.minimum + 64eps(T) * r.minimum
      end
    end
  end

  @testset "unrestricted leakage needs a projection bound" begin
    for T in (Float64, Float32)
      M = T === Float64 ? T(2)^26 : T(2)^11
      X, y = T[M M-1; 1 1], T[0, 1]
      @test X * T[1-M, M] == y
      for design in (X, sparse(X)), f in pair(y, design)
        r = quiet(() -> solve!(SparseIterate(T, 2), f, NormL1(zero(T)), CDSolver(order = :cyclic)))
        @test !r.converged && r.gap >= 1 - 16eps(T)
        bounds_optimum(r, zero(T))
      end
    end
  end

  @testset "fast certificates retain conservative objective bounds" begin
    for T in (Float64, Float32)
      λ, c = T(0.9), one(T) + eps(T)
      f = SqrtQuadraticFunction(ones(T, 1, 1), T[-1], c)
      x = SparseIterate(T[1 - λ * sqrt(7eps(T))])
      r = quiet(() -> solve!(x, f, NormL1(λ), CDSolver(maxpasses = 0)))
      optimum = big(λ) + sqrt(big(c) - 1) * sqrt(1 - big(λ)^2)
      deficit = (big(r.minimum) - optimum) / big(r.minimum)
      @test big(r.gap) + 64eps(T) >= deficit
      T === Float64 && @test big(r.gap) >= deficit > big(1e-9)
      @test !r.converged && isfinite(r.gap)
    end
  end

  @testset "rank decisions are invariant to column units" begin
    for T in (Float64, Float32)
      τ = T === Float64 ? T(2)^-30 : T(2)^-15
      X, y, start = T[1 0; 0 τ], ones(T, 2), T[1, inv(τ)]
      target = T === Float64 ? 1e-8 : 256eps(T)
      for design in (X, sparse(X)), f in pair(y, design)
        x = SparseIterate(start)
        r = solve!(x, f, NormL1(T(0.1), T[1, τ]), CDSolver(; order = :cyclic, gaptol = target))
        @test r.converged && 4eps(T) <= r.gap <= target
        @test Vector(x) ≈ start
        bounds_optimum(r, T(0.2))
      end
    end
  end

  @testset "analytic exact fits and rank-deficient supports" begin
    for T in (Float64, Float32), λ in (T(0.1), T(0.4)),
        (X, start, optimum) in ((reshape(T[1, 2], 1, 2), T[0, 0.5], λ / 2),
                                (reshape(T[1, 1], 1, 2), T[0.5, 0.5], λ))
      y = T[1]
      target = T === Float64 ? 1e-8 : 256eps(T)
      for f in pair(y, X)
        x = SparseIterate(start)
        r = @test_logs solve!(x, f, NormL1(λ), CDSolver(; order = :cyclic, gaptol = target))
        @test r.converged && r.gap <= target
        @test r.gap >= 4eps(T)
        @test Vector(x) ≈ start
        bounds_optimum(r, optimum)
      end
    end
    for f in pair([1.0], reshape([1.0, 2.0], 1, 2))
      x = SparseIterate([1.0, 0.0])
      r = quiet(() -> solve!(x, f, NormL1(0.1), CDSolver(order = :cyclic)))
      @test !r.converged && r.gap >= 0.5 - 1e-12
      bounds_optimum(r, 0.05)
    end
  end

  @testset "coordinatewise traps and incomplete witnesses" begin
    X = [1.0 1.0; 0.0 0.01]
    start = [1.0, -1.0]
    for f in pair(X * start, X)
      x = SparseIterate(start)
      r = quiet(() -> solve!(x, f, NormL1(0.1), CDSolver(order = :cyclic)))
      @test !r.converged && r.gap >= 0.95 - 1e-12
      bounds_optimum(r, 0.01)
    end
    # The least-norm support point misses θ = (0.1, -0.1), a feasible
    # optimum. A loose certificate must not accept this exact minimizer.
    X = [1.0 2.0; 0.0 1.0]
    for f in pair([1.0, 0.0], X)
      x = SparseIterate([1.0, 0.0])
      r = quiet(() -> solve!(x, f, NormL1(0.1), CDSolver(order = :cyclic)))
      @test !r.converged
      @test r.gap ≈ 0.5 atol = 1e-12
      bounds_optimum(r, 0.1)
    end
    # Opposite signs on identical columns give inconsistent support targets.
    for f in pair([0.0], ones(1, 2))
      r = quiet(() -> solve!(SparseIterate([1.0, -1.0]), f, NormL1(0.1), CDSolver(order = :cyclic)))
      @test !r.converged && r.gap >= 1 - 1e-12
      bounds_optimum(r, 0.0)
    end
  end

  @testset "unpenalized directions and analytic references" begin
    # Eliminating the first, unpenalized coordinate leaves
    # sqrt((1 - x₂)^2 + δ²) + λ|x₂|, with optimum λ + δ sqrt(1 - λ²).
    X = [1.0 1.0; 0.0 1.0; 0.0 0.0]
    λ = 0.2
    for δ in (0.0, 1e-8, 1.0), f in pair([2.0, 1.0, δ], X)
      x = SparseIterate(2)
      r = quiet(() -> solve!(x, f, NormL1(λ, [0.0, 1.0]), CDSolver(; order = :cyclic, tol = 1e-10, maxpasses = 1000)))
      bounds_optimum(r, λ + δ * sqrt(1 - λ^2))
      δ == 1.0 && @test r.converged && r.gap <= 1e-4
      r.converged && @test r.gap <= 1e-4
    end
    # Zero level imposes equality on every finite-loading column.
    for f in pair([2.0, 1.0, 0.5], X)
      r = solve!(SparseIterate(2), f, NormL1(0.0), CDSolver(; order = :cyclic, tol = 1e-10))
      @test r.converged && r.gap <= 1e-4
      bounds_optimum(r, 0.5)
    end
    # Two identical unpenalized columns must not require an invertible Gram.
    X = [1.0 1.0 1.0; 0.0 0.0 1.0; 0.0 0.0 0.0]
    for f in pair([2.0, 1.0, 0.5], X)
      r = solve!(SparseIterate(3), f, NormL1(λ, [0.0, 0.0, 1.0]), CDSolver(; order = :cyclic, tol = 1e-10))
      @test r.converged && r.gap <= 1e-4
      bounds_optimum(r, λ + 0.5sqrt(1 - λ^2))
    end
    # An independent unpenalized coordinate does not repair the audit trap.
    X = [1.0 1.0 0.0; 0.0 0.01 0.0; 0.0 0.0 1.0]
    start = [1.0, -1.0, 2.0]
    for f in pair(X * start, X)
      r = quiet(() -> solve!(SparseIterate(start), f, NormL1(0.1, [1.0, 1.0, 0.0]), CDSolver(order = :cyclic)))
      @test !r.converged && r.gap >= 0.95 - 1e-10
      bounds_optimum(r, 0.01)
    end
  end

  @testset "weights, sparse shifts and sufficient statistics" begin
    # The ignored row may have an arbitrary residual and design.
    X = [1.0 2.0; 2.0 4.0; 999.0 -333.0]
    y, w = [1.0, 2.0, 99.0], [1.0, 1.0, 0.0]
    for design in (X, sparse(X))
      r = solve!(SparseIterate([0.0, 0.5]), SqrtLeastSquaresLoss(y, design; weights = w), NormL1(0.1), CDSolver(order = :cyclic))
      @test r.converged && r.gap <= 1e-8
      bounds_optimum(r, 0.05)
    end
    X = [1.0 2.0; 3.0 6.0; 0.0 0.0]
    y, w = [4.0, 6.0, 3.0], [1.0, 1.0, 2.0]
    for design in (X, sparse(X))
      x = SparseIterate([0.0, 0.5])
      m = cdmodel(SqrtLeastSquaresLoss(y, design; weights = w), x; intercept = true)
      r = solve!(x, m, NormL1(0.1), CDSolver(order = :cyclic))
      @test r.converged && r.gap <= 1e-8
      @test PS.intercept(m, x) ≈ 3.0
      design isa SparseMatrixCSC && @test !iszero(m.δ)
      bounds_optimum(r, 0.05)
      Xc = X .- transpose(m.xbar)
      yc = y .- m.ybar
      q = SqrtQuadraticFunction(Xc' * (w .* Xc), -Xc' * (w .* yc), dot(yc, w .* yc))
      rq = solve!(SparseIterate([0.0, 0.5]), q, NormL1(0.1), CDSolver(order = :cyclic))
      @test rq.converged && rq.gap <= 1e-8
      @test rq.gap ≈ r.gap atol = 1e-12
      bounds_optimum(rq, 0.05)
    end
    # Centering removes the constants. Eliminating the unpenalized column
    # leaves 2sqrt((1 - x₂)^2 + 1/4) + λ|x₂|, including an ignored row.
    for T in (Float64, Float32)
      X = T[3 3; 1 1; 3 1; 1 -1; 111 -222]
      y, w, λ = T[6.5, 1.5, 3.5, 0.5, 123], T[1, 1, 1, 1, 0], T(0.2)
      target = T === Float64 ? 1e-8 : 8sqrt(eps(T))
      tol = T === Float64 ? 1e-10 : 1e-6
      for design in (X, sparse(X))
        x = SparseIterate(T, 2)
        m = cdmodel(SqrtLeastSquaresLoss(y, design; weights = w), x; intercept = true)
        g = NormL1(λ, T[0, 1])
        r = solve!(x, m, g, CDSolver(; order = :cyclic, tol, gaptol = target, maxpasses = 1000))
        @test r.converged && r.gap <= target
        design isa SparseMatrixCSC && @test !iszero(m.δ)
        bounds_optimum(r, λ + T(0.5) * sqrt(4 - λ^2))
        Xc, yc = X .- transpose(m.xbar), y .- m.ybar
        q = SqrtQuadraticFunction(Xc' * (w .* Xc), -Xc' * (w .* yc), dot(yc, w .* yc))
        rq = solve!(SparseIterate(T, 2), q, g, CDSolver(; order = :cyclic, tol, gaptol = target, maxpasses = 1000))
        @test rq.converged && rq.gap <= target
        bounds_optimum(rq, λ + T(0.5) * sqrt(4 - λ^2))
        if T === Float32
          # Compensated statistics retain a certificate at the stricter target.
          strict = quiet(() -> solve!(SparseIterate(Vector(rq.minimizer)), q, g,
                                      CDSolver(; order = :cyclic, tol, gaptol = 1e-4, maxpasses = 1000)))
          @test strict.converged && strict.gap <= 1e-4
          bounds_optimum(strict, λ + T(0.5) * sqrt(4 - λ^2))
        end
      end
    end
    # Dividing the loss and the penalty by √n preserves the relative gap.
    X = [1.0 1.0; 0.0 0.015625; 0.0 0.0; 0.0 0.0]
    y = X * [1.0, -1.0]
    r = quiet(() -> solve!(SparseIterate([1.0, -1.0]), SqrtLeastSquaresLoss(y, X), NormL1(0.1), CDSolver(order = :cyclic)))
    q = SqrtQuadraticFunction(X'X / 4, -X'y / 4, dot(y, y) / 4)
    rq = quiet(() -> solve!(SparseIterate([1.0, -1.0]), q, NormL1(0.05), CDSolver(order = :cyclic)))
    @test rq.gap ≈ r.gap atol = 1e-9
    @test rq.minimum ≈ r.minimum / 2
    bounds_optimum(rq, 0.0078125)
  end

  @testset "empty supports, rank cutoff and size cap" begin
    for f in pair([1.0, 1.0], Matrix{Float64}(I, 2, 2))
      r = solve!(SparseIterate(2), f, NormL1(10.0), CDSolver())
      @test r.converged && r.gap <= 1e-8
      bounds_optimum(r, sqrt(2.0))
    end
    for f in pair(zeros(2), ones(2, 2))
      r = solve!(SparseIterate(2), f, NormL1(0.1), CDSolver())
      @test r.converged && iszero(r.minimum) && iszero(r.gap)
    end
    r = solve!(SparseIterate(2), SqrtLeastSquaresLoss([1.0], ones(1, 2); weights = [0.0]), NormL1(0.1), CDSolver())
    @test r.converged && iszero(r.gap)
    for τ in (sqrt(eps()) / 4, 16sqrt(eps()))
      X = [1.0 0.0; 0.0 τ]
      for f in pair([1.0, τ], X)
        r = quiet(() -> solve!(SparseIterate(ones(2)), f, NormL1(0.1, [1.0, τ]), CDSolver(maxpasses = 0)))
        bounds_optimum(r, 0.1 * (1 + τ))
      end
    end
    p = PS._SQRT_DUAL_MAXSUPPORT + 1
    # Certification must cap the support before allocating its Gram matrix.
    r = quiet(() -> solve!(SparseIterate(ones(p)), SqrtLeastSquaresLoss([Float64(p)], ones(1, p)), NormL1(0.1), CDSolver(maxpasses = 0)))
    @test !r.converged && r.gap == 1
    bounds_optimum(r, 0.1p)
    r = quiet(() -> solve!(SparseIterate(p), SqrtLeastSquaresLoss([1.0], ones(1, p)), NormL1(0.0), CDSolver(maxpasses = 0)))
    @test !r.converged && r.gap == 1
    bounds_optimum(r, 0.0)
  end

  @testset "fixed coordinates and rejected certificates" begin
    X = [1.0 100.0; 0.0 1.0; 0.0 0.0]
    for λ in (0.0, 0.1), f in pair([1.0, 0.0, 0.5], X)
      x = SparseIterate(2)
      r = solve!(x, f, NormL1(λ, [1.0, Inf]), CDSolver(; order = :cyclic, tol = 1e-10))
      @test r.converged && r.gap <= 1e-4 && iszero(x[2])
      bounds_optimum(r, λ + 0.5sqrt(1 - λ^2))
    end
    for f in pair(X[:, 2], X)
      r = quiet(() -> solve!(SparseIterate([0.0, 1.0]), f, NormL1(0.0, [1.0, Inf]), CDSolver(maxpasses = 0)))
      @test !r.converged && r.gap == Inf
    end
    # A negative quadratic beyond the budget cannot produce a certificate.
    f = SqrtQuadraticFunction(ones(1, 1), [0.0], -1.0)
    r = quiet(() -> solve!(SparseIterate(1), f, NormL1(0.1), CDSolver(maxpasses = 0)))
    @test !r.converged && r.gap == Inf
    # A stale zero residual must not conceal an ordinary nonoptimal point.
    for f in pair([2.0, 1.0, 0.5], [1.0 1.0; 0.0 1.0; 0.0 0.0])
      x = SparseIterate([2.0, 0.0])
      m = cdmodel(f, x)
      PS.initialize!(m, x)
      if m isa PS.SqrtLSModel
        fill!(m.r, 0.0)
      else
        m.q = 0.0
        fill!(m.u, 0.0)
      end
      method = CDSolver()
      st = PS._CDState(Float64, x, method)
      @test !PS._certified!(st, m, NormL1(0.2, [0.0, 1.0]), x, method)
      P = sqrt(1.25)
      @test st.relgap * P >= P - (0.2 + 0.5sqrt(0.96)) - 1e-12
    end
  end

  @testset "paths, continuation, reuse and exhausted passes" begin
    X, y = reshape([2.0, 1.0], 1, 2), [1.0]
    method = CDSolver(; order = :cyclic, gaptol = 1e-8)
    for f in pair(y, X)
      path = solve_path(f, NormL1(1.0), [0.4, 0.2, 0.1], method; x = SparseIterate(2), screening = false)
      @test all(path.converged) && all(gap -> gap <= 1e-8, path.gap)
      @test path.values ≈ path.λ / 2
      r = solve!(SparseIterate(2), f, NormL1(0.1), method; continuation = 3, screening = false)
      @test r.converged && r.gap <= 1e-8
      ws = SolverWorkspace(SparseIterate([0.5, 0.0]), f, NormL1(0.1), method)
      for start in ([0.0, 1.0], [0.5, 0.0], [0.0, 1.0], [0.5, 0.0])
        reinit!(ws, SparseIterate(start))
        r = quiet(() -> solve!(ws))
        @test isfinite(r.gap)
        @test r.converged == (start[1] == 0.5)
        bounds_optimum(r, 0.05)
      end
      r = quiet(() -> solve!(SparseIterate([0.5, 0.0]), f, NormL1(0.1), CDSolver(maxpasses = 0)))
      @test !r.converged && r.passes == 0 && r.gap <= 1e-8
      @test !PS._hasgap(cdmodel(f, SparseIterate(2)), NormL1(0.1))
      @test_throws ArgumentError duality_gap(f, NormL1(0.1), SparseIterate(2))
    end
    # The joint workspace grows and then serves smaller supports too.
    for f in pair(ones(3), Matrix{Float64}(I, 3, 3))
      ws = SolverWorkspace(SparseIterate([1.0, 0.0, 0.0]), f, NormL1(0.1), CDSolver(maxpasses = 0))
      for start in ([1.0, 0.0, 0.0], ones(3), [0.0, 1.0, 0.0], zeros(3), ones(3))
        reinit!(ws, SparseIterate(start))
        r = quiet(() -> solve!(ws))
        @test !r.converged && r.passes == 0
        bounds_optimum(r, 0.3)
        all(isone, start) && @test r.gap <= 1e-8
      end
    end
  end
end

end
