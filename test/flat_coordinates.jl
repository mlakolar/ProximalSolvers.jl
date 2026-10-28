module FlatCoordinateTests

using Test, LinearAlgebra, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PB = ProximalBase

solver() = CDSolver(; order = :cyclic, tol = 1e-12, maxpasses = 100)

# The objective comparisons and subgradients do not use the flat-step helper.
@noinline function check_solution(g, G, expected, subgradient; μ = 1.0, start = 0.7)
  @nospecialize g subgradient
  penalty = μ == 1 ? g : Scaled(g, μ)
  for (j, f) in enumerate((QuadraticFunction(zeros(1, 1), [G]),
                           KronQuadratic(zeros(1, 1), ones(1, 1), fill(G, 1, 1))))
    x = SparseIterate([start])
    if j == 1
      @test solve!(x, f, penalty, solver()).converged
    else
      m = cdmodel(f, x)
      PS.initialize!(m, x)
      PS.coordinate_step!(m, penalty, x, 1)
      @test iszero(PS.coordinate_step!(m, penalty, x, 1))
    end
    @test x[1] ≈ expected atol = 1e-12 rtol = 1e-12
    @test kkt_residual(f, penalty, x; relative = false) <= 1e-12
    lo, hi = subgradient(x[1])
    @test μ * lo - 1e-12 <= -G <= μ * hi + 1e-12
    objective(t) = G * t + μ * g([t])
    v = objective(x[1])
    @test isfinite(v)
    for δ in (0.01, 0.2, 1.0) .* max(abs(expected), 0.1), s in (-1, 1)
      @test v <= objective(x[1] + s * δ) + 1e-12 * max(1, abs(v))
    end
  end
end

@noinline function check_rejected(g, G; start = 0.7)
  @nospecialize g
  f = QuadraticFunction(zeros(1, 1), [G])
  x = SparseIterate([start])
  m = cdmodel(f, x)
  PS.initialize!(m, x)
  before = copy(m.u)
  @test_throws ArgumentError PS.coordinate_step!(m, g, x, 1)
  @test isequal(x[1], start)
  @test isequal(m.u, before)
  @test kkt_residual(m, g, x; relative = false) == Inf
end

@testset "closed forms and independent scalar conditions" begin
  for μ in (0.5, 2.0), G in (-1.0, 0.0, 1.0)
    for w in (nothing, [2.0])
      c = w === nothing ? 0.1 : 0.2
      z = -sign(G) * max(abs(G) / μ - c, 0) / 1.5
      check_solution(ElasticNet(0.1, 1.5, w), G, z,
        x -> iszero(x) ? (-c, c) : (1.5x + c * sign(x), 1.5x + c * sign(x)); μ)
      z = abs(G) / μ <= c ? 0.0 : -sign(G) * 2abs(G) / (μ * c)
      check_solution(PB.Berhu(0.1, 2.0, w), G, z,
        x -> iszero(x) ? (-c, c) : (c * x / 2, c * x / 2); μ)
    end
    for y in (nothing, [0.3])
      center = y === nothing ? 0.0 : 0.3
      check_solution(SqrNormL2(2.0, y), G, center - G / (2μ),
        x -> (2(x - center), 2(x - center)); μ)
    end
    check_solution(PB.NegEntropy(2.0), G, exp(-G / (2μ) - 1),
      x -> (2(log(x) + 1), 2(log(x) + 1)); μ)
    for q in (2.0, [2.0])
      check_solution(PB.KLDivergence(q; λ = 2.0), G, 2exp(-G / (2μ)),
        x -> (2log(x / 2), 2log(x / 2)); μ)
    end
    check_solution(PB.Regularize(NormL1(0.1), 2.0, [0.3]), G,
      sign(0.3 - G / (2μ)) * max(abs(0.3 - G / (2μ)) - 0.05, 0),
      x -> iszero(x) ? (-0.7, -0.5) : (2(x - 0.3) + 0.1sign(x), 2(x - 0.3) + 0.1sign(x)); μ)
  end
  for μ in (0.5, 2.0), G in (0.5, 2.0)
    check_solution(PB.NegLog(2.0), G, 2μ / G, x -> (-2 / x, -2 / x); μ)
  end
  for G in (-0.4, 0.4)
    check_solution(ElasticNet(0.1, 1.0, [2.0]), G, 0.0, x -> (-0.2, 0.2); μ = 2.0)
    check_solution(PB.Berhu(0.1, 1.0, [2.0]), G, 0.0, x -> (-0.2, 0.2); μ = 2.0)
  end
end

@testset "zero parameters and wrapper composition" begin
  for g in (PB.Berhu(0.0, 1.0), PB.Berhu(1.0, 1.0, [0.0]), SqrNormL2(0.0))
    check_solution(g, 0.0, 0.0, x -> (0.0, 0.0))
    check_rejected(g, -1.0)
  end
  for ρ in (0.0, 1.0)
    g = PB.Regularize(NormL1(0.1), ρ)
    check_solution(g, -0.05, 0.0, x -> (-0.1, 0.1))
  end
  base = ElasticNet(0.1, 1.0)
  cases = ((Scaled(Tilt(base, [0.2]), 2.0), 0.2, x -> (2x + 0.6, 2x + 0.6)),
           (Tilt(Scaled(base, 2.0), [0.2]), 0.3, x -> (2x + 0.4, 2x + 0.4)),
           (PB.Translate(Scaled(base, 2.0), [3.0]), 3.4, x -> (2(x - 3) + 0.2, 2(x - 3) + 0.2)),
           (PB.BoxConstrained(base, IndBox(0.0, 0.5)), 0.5, x -> (0.6, Inf)),
           (PB.BoxConstrained(Tilt(NormL1(0.25), [-2.0]), IndBox(-1.0, 1.0)), 1.0, x -> (-1.75, Inf)))
  for (g, z, condition) in cases
    check_solution(g, g === cases[end][1] ? 1.0 : -1.0, z, condition)
  end
  # The entropy domain includes zero; this box meets it only at its upper end.
  g = PB.BoxConstrained(PB.NegEntropy(1.0), IndBox(-1.0, 0.0))
  check_solution(g, 1.0, 0.0, x -> (-Inf, Inf))
  # An open domain rejects a clamped point at zero, including through wrappers.
  check_rejected(PB.BoxConstrained(PB.NegLog(1.0), IndBox(-2.0, -1.0)), 1.0)
  check_rejected(PB.BoxConstrained(Scaled(PB.NegLog(1.0), 2.0), IndBox(-1.0, 0.0)), 1.0)
end

@testset "boxed penalties without an inner minimizer" begin
  for G in (0.0, -1.0)
    g = PB.BoxConstrained(PB.NegLog(1.0), IndBox(1.0, Inf))
    check_rejected(g, G; start = 1.5)
    x = SparseIterate([1.5])
    @test_throws ArgumentError solve!(x, QuadraticFunction(zeros(1, 1), [G]), g, solver())
    @test x[1] === 1.5
    g = PB.BoxConstrained(PB.NegLog(1.0), IndBox(1.0, 5.0))
    check_solution(g, G, 5.0, x -> (-1 / x, Inf); start = 1.5)
    @test PS._coordinate_minimizer(g, 1.5, G, 0.0, 1) === 5.0
  end
  g = PB.BoxConstrained(ElasticNet(0.1, 1.0), IndBox(1.0, 2.0))
  check_solution(g, 0.0, 1.0, x -> (-Inf, 0.1 + x))
  @test PS._coordinate_minimizer(g, 1.5, 0.0, 0.0, 1) === 1.0
  g = PB.BoxConstrained(SqrNormL2(0.0), IndBox(-Inf, 2.0))
  @test PS._coordinate_minimizer(g, 1.5, -1.0, 0.0, 1) === 2.0
  g = PB.BoxConstrained(SqrNormL2(0.0), IndBox(-2.0, Inf))
  @test PS._coordinate_minimizer(g, 1.5, 1.0, 0.0, 1) === -2.0
end

@testset "range and conversion checks" begin
  g = ElasticNet(0.1, floatmax(Float64))
  z = PS._coordinate_minimizer(g, 0.0, -floatmax(Float64), 0.0, 1)
  oracle = (BigFloat(floatmax(Float64)) - BigFloat(0.1)) / BigFloat(floatmax(Float64))
  @test z == Float64(oracle) == 1.0
  g = PB.KLDivergence(1e300)
  z = PS._coordinate_minimizer(g, 0.0, 750.0, 0.0, 1)
  oracle = exp(log(BigFloat(1e300)) - 750)
  @test z ≈ Float64(oracle) rtol = 1e-12
  @test z > 0
  # The product μλ overflows, although the minimizer μλ/G is representable.
  g = Scaled(PB.NegLog(floatmax(Float64)), 2.0)
  z = PS._coordinate_minimizer(g, 0.0, floatmax(Float64), 0.0, 1)
  @test z == Float64(2BigFloat(floatmax(Float64)) / BigFloat(floatmax(Float64))) == 2.0
  @test PS._coordinate_minimizer(SqrNormL2(1e-300, [2.0]), 0.7, 0.0, 0.0, 1) == 2.0
  check_rejected(PB.Translate(PB.NegLog(1.0), [1e20]), 1.0)
  @test BigFloat(1e20) + 1 > BigFloat(1e20)
  check_rejected(PB.NegEntropy(1.0), 1000.0)
  @test exp(-BigFloat(1001)) > 0
  check_rejected(PB.KLDivergence(2.0), 1000.0)
  check_rejected(SqrNormL2(1e-300), -floatmax(Float64))
  check_rejected(SqrNormL2(1.0, [floatmax(Float64)]), 0.0; start = -floatmax(Float64))
  for g in (PB.NegLog(1.0),), G in (-1.0, 0.0)
    check_rejected(g, G)
  end
  check_rejected(ElasticNet(0.1, 0.0), -1.0)
  for native in (true, false)
    p = native ? Float32 : Float64
    cases = ((ElasticNet(p(0.1), p(1)), -1f0, 0.9f0),
             (SqrNormL2(p(2)), -1f0, 0.5f0),
             (PB.Berhu(p(0.1), p(1)), -1f0, 10f0),
             (PB.NegLog(p(1)), 2f0, 0.5f0),
             (PB.NegEntropy(p(1)), 1f0, Float32(exp(-2))),
             (PB.KLDivergence(p(2); λ = p(1)), 1f0, Float32(2exp(-1))),
             (PB.Regularize(NormL1(p(0.1)), p(1)), -1f0, 0.9f0))
    for (g, G, expected) in cases
      x = SparseIterate(Float32[0.7])
      f = QuadraticFunction(zeros(Float32, 1, 1), [G])
      m = cdmodel(f, x)
      PS.initialize!(m, x)
      PS.coordinate_step!(m, g, x, 1)
      @test iszero(PS.coordinate_step!(m, g, x, 1))
      @test x[1] isa Float32
      @test x[1] ≈ expected rtol = 3eps(Float32)
    end
  end
  # Wider centers are also converted after computing the scalar minimizer.
  @test PS._coordinate_minimizer(SqrNormL2(2.0, [0.3]), 0.7f0, -1f0, 0f0, 1) === 0.8f0
  # Conversion to the iterate type can overflow or underflow a finite Float64 answer.
  @test PS._flat_minimizer(PB.NegEntropy(1.0), 0f0, 200f0, 1, 1f0) === nothing
  @test PS._flat_minimizer(SqrNormL2(1e-40), 0f0, -1f0, 1, 1f0) === nothing
end

@testset "exact directions and balanced ranges" begin
  check_rejected(PB.BoxConstrained(PB.NegLog(1.0), IndBox(1e20, Inf)), 0.0; start = 1e20)
  check_rejected(PB.BoxConstrained(PB.NegEntropy(1.0), IndBox(0.0, 1.0)), 1000.0; start = 0.5)
  g = PB.BoxConstrained(PB.NegLog(1.0), IndBox(1e20, 2e20))
  @test PS._coordinate_minimizer(g, 1e20, 0.0, 0.0, 1) === 2e20
  for g in (SqrNormL2(0.0), PB.Berhu(0.0, 1.0))
    for G in (-1.0, 1.0)
      boxed = PB.BoxConstrained(g, IndBox(-2.0, 3.0))
      @test PS._coordinate_minimizer(boxed, 0.0, G, 0.0, 1) === (G < 0 ? 3.0 : -2.0)
    end
  end
  tiny, scale = nextfloat(0.0), floatmax(Float64)
  denominator = BigFloat(tiny) * BigFloat(scale)
  for G in (-1e-16, 1e-16)
    ratio = BigFloat(G) / denominator
    cases = ((Scaled(SqrNormL2(tiny), scale), -ratio),
             (Scaled(PB.NegEntropy(tiny), scale), exp(-ratio - 1)),
             (Scaled(PB.KLDivergence(2.0; λ = tiny), scale), 2exp(-ratio)),
             (Scaled(ElasticNet(0.0, tiny), scale), -ratio))
    for (g, oracle) in cases
      @test PS._coordinate_minimizer(g, 0.0, G, 0.0, 1) ≈ Float64(oracle) rtol = 2e-15
    end
  end
  for G in (-1e-14, 1e-14)
    ratio = abs(BigFloat(G)) / denominator
    g = Scaled(PB.Berhu(tiny, 1.0), scale)
    @test PS._coordinate_minimizer(g, 0.0, G, 0.0, 1) ≈ Float64(-sign(G) * ratio) rtol = 2e-15
    g = Scaled(ElasticNet(tiny, tiny, [2.0]), scale)
    @test PS._coordinate_minimizer(g, 0.0, G, 0.0, 1) ≈ Float64(-sign(G) * (ratio - 2)) rtol = 2e-15
  end
  g = Scaled(PB.NegLog(tiny), scale)
  @test PS._coordinate_minimizer(g, 0.0, 1e-14, 0.0, 1) ≈ Float64(denominator / BigFloat(1e-14)) rtol = 2e-15
  g = ElasticNet(1e-250, 1e-300, [1e-250])
  @test PS._coordinate_minimizer(g, 0.0, 1e-200, 0.0, 1, scale) === 0.0
  G, threshold = 1.9, prevfloat(1.9)
  g = ElasticNet(threshold, 1e-300)
  oracle = -(BigFloat(G) - BigFloat(threshold)) / BigFloat(1e-300)
  @test PS._coordinate_minimizer(g, 0.0, G, 0.0, 1) ≈ Float64(oracle) rtol = 2e-15
  g = PB.Berhu(1e-250, 1e-200)
  oracle = -BigFloat(1e100) * BigFloat(1e-200) / BigFloat(1e-250)
  @test PS._coordinate_minimizer(g, 0.0, 1e100, 0.0, 1) ≈ Float64(oracle) rtol = 2e-15
  # A subnormal regularization parameter still makes this closed form unavailable.
  check_rejected(PB.Regularize(SqrNormL2(1.0), 1e-320), 1.0; start = 0.0)
  F = floatmax(Float32)
  @test PS._coordinate_minimizer(PB.KLDivergence(F), 0f0, 0f0, 0f0, 1) === F
  g = PB.Translate(SqrNormL2(0.5), [-Float64(F)])
  @test PS._coordinate_minimizer(g, 0f0, -F, 0f0, 1) === F
  z = PS._coordinate_minimizer(SqrNormL2(big"2.0"), big"0.0", big"1.0", big"0.0", 1)
  @test z isa BigFloat
  @test z == big"-0.5"
end

@testset "nonconvex affine subproblems" begin
  for base in (MCP(0.1), SCAD(0.1))
    for g in (base, Scaled(base, 2.0), Tilt(base, [0.01]), PB.Translate(base, [2.0]),
              PB.Regularize(base, 1.0), PB.BoxConstrained(base, IndBox(-1.0, 1.0)))
      check_rejected(g, -0.05)
    end
  end
  g = Tilt(MCP(0.1), [0.05])
  x = SparseIterate([0.7])
  @test solve!(x, QuadraticFunction(zeros(1, 1), [-0.05]), g, solver()).converged
  @test x[1] == 0.0
  for g in (CappedL1(0.1, 1.0), LogPenalty(0.1, 1.0), NormLq(0.1, 0.5))
    @test_throws ArgumentError PB.BoxConstrained(g, IndBox(-1.0, 1.0))
  end
end

@testset "least squares flat columns" begin
  t = [-2.0, -1.0, 1.0, 2.0]
  offset = [0.1, -0.2, 0.3, -0.4]
  w = [1.0, 2.0, 2.0, 1.0]
  g = Tilt(ElasticNet(0.1, 2.0), [-1.0, 0.0])
  for intercept in (false, true), sparse_storage in (false, true), weighted in (false, true)
    X = hcat(fill(intercept ? 3.0 : 0.0, 4), t)
    sparse_storage && (X = sparse(X))
    weights = weighted ? w : nothing
    y = 2t + offset .+ (intercept ? 4.0 : 0.0)
    f = GLMLoss(PB.Squared(), y, X; weights, offset)
    x = SparseIterate([0.7, -0.2])
    m = cdmodel(f, x; intercept)
    @test solve!(x, m, g, solver()).converged
    @test x[1] ≈ 0.45 atol = 1e-12
    a = sum((weighted ? w : ones(4)) .* t.^2)
    @test x[2] ≈ (2a - 0.1) / (a + 2) atol = 1e-10
    r = y - offset - PS.intercept(m, x) * ones(4) - X * Vector(x)
    @test PS.residuals(m) ≈ r atol = 1e-12
    @test abs(2x[1] + 0.1 - 1) <= 1e-12
    @test kkt_residual(m, g, x; relative = false) <= 1e-10
    bad = PB.NegLog(1.0)
    PS.initialize!(m, x)
    before = (copy(m.r), copy(m.a), m.δ, x[1])
    @test_throws ArgumentError PS.coordinate_step!(m, bad, x, 1)
    @test isequal((m.r, m.a, m.δ, x[1]), before)
    @test kkt_residual(m, bad, x; relative = false) == Inf
  end
end

@testset "least squares curvature underflow" begin
  for sparse_storage in (false, true)
    X = fill(1f-23, 1, 1)
    sparse_storage && (X = sparse(X))
    f = LeastSquaresLoss(Float32[1f15], X)
    x = SparseIterate(Float32[0])
    m = cdmodel(f, x)
    PS.initialize!(m, x)
    @test PS._column_dot(m, 1) == (0f0, 1f-8)
    before = (copy(m.r), copy(m.a), m.δ)
    err = try
      PS.coordinate_step!(m, NormL1(0f0), x, 1)
    catch e
      e
    end
    @test err isa ArgumentError
    @test occursin("rescale", sprint(showerror, err))
    @test x[1] === 0f0
    @test isequal((m.r, m.a, m.δ), before)
    @test kkt_residual(m, NormL1(0f0), x) == Inf
    @test_throws ArgumentError solve!(x, f, NormL1(0f0), solver())
    # The same column with an intercept is genuinely constant and retains zero.
    m = cdmodel(f, x; intercept = true)
    @test solve!(x, m, NormL1(0f0), solver()).converged
    @test x[1] === 0f0
    @test kkt_residual(m, NormL1(0f0), x) == 0f0
    # A working model may set its centering means after construction.
    m = cdmodel(f, x)
    m.xbar[1] = X[1, 1]
    @test PS._flat_column(m, 1)
  end
  # Implicit zeros and zero-weight rows both matter for sparse flatness.
  for sparse_storage in (false, true)
    X = reshape(Float32[0, 1f-23], 2, 1)
    sparse_storage && (X = sparse(X))
    x = SparseIterate(Float32[0])
    f = LeastSquaresLoss(Float32[0, 1f15], X)
    m = cdmodel(f, x; intercept = true)
    PS.initialize!(m, x)
    @test !PS._flat_column(m, 1)
    @test_throws ArgumentError PS.coordinate_step!(m, NormL1(0f0), x, 1)
    f = GLMLoss(PB.Squared(), Float32[0, 1f15], X; weights = Float32[0, 1])
    m = cdmodel(f, x; intercept = true)
    @test PS._flat_column(m, 1)
    @test solve!(x, m, NormL1(0f0), solver()).converged
    @test x[1] === 0f0
    f = GLMLoss(PB.Squared(), Float32[0, 1f15], X; weights = Float32[1, 1])
    m = cdmodel(f, x; intercept = true)
    @test !PS._flat_column(m, 1)
  end
end

@testset "symmetric multiplicities and original pair objective" begin
  W = [1.0 1.0; 3.0 1.0]
  C = [0.0 0.1; 0.3 0.0]
  A = zeros(2, 2)
  f = KronQuadratic(A, Matrix(1.0I, 2, 2), [0.0 -1.0; -1.0 0.0])
  before = (copy(W), copy(C))
  base = ElasticNet(0.1, 1.0, W)
  cases = ((base, 0.8, 1.0, 0.0),
           (Scaled(Tilt(base, C), 2.0), 0.1, 2.0, 0.8),
           (Tilt(Scaled(base, 2.0), C), 0.2, 2.0, 0.4))
  for (g, expected, scale, tilt) in cases
    x = SymmetricSparseIterate([0.0 0.7; 0.7 0.0])
    @test solve!(x, f, g, solver()).converged
    z = x[2, 1]
    @test z ≈ expected atol = 1e-12
    # The original entries contribute λ₁(w₂₁ + w₁₂)|z| + λ₂z².
    objective(v) = -2v + scale * (0.1 * (W[2, 1] + W[1, 2]) * abs(v) + v^2) + tilt * v
    @test abs(-2 + scale * (0.4 + 2z) + tilt) <= 1e-12
    @test f(Matrix(x)) + g(Matrix(x)) ≈ objective(z) atol = 1e-12
    for δ in (0.001, 0.1, 1.0), s in (-1, 1)
      @test objective(z) <= objective(z + s * δ)
    end
    @test kkt_residual(f, g, x; relative = false) <= 1e-12
    @test isequal((W, C), before)
  end
  center = [0.0 1.0; 2.0 0.0]
  saved = copy(center)
  x = SymmetricSparseIterate([0.0 0.7; 0.7 0.0])
  @test_throws ArgumentError solve!(x, f, SqrNormL2(1.0, center), solver())
  @test x[2, 1] == 0.7
  @test isequal(center, saved)
end

@testset "previously supported values" begin
  cases = ((NormL1(0.1), -0.05, 0.0), (NormL1(0.1), -0.1, 0.0),
           (NormL1Nonneg(0.1), 1.0, 0.0), (IndBox(-1.0, 1.0), -1.0, 1.0),
           (IndBox(-1.0, 1.0), 1.0, -1.0), (PB.CheckLoss(0.3), -0.2, 0.0),
           (PB.HingeLoss(), 0.5, 1.0),
           (PB.Translate(IndBox(-2.0, 2.0), [1.0]), 0.0, 0.0),
           (PB.BoxConstrained(ElasticNet(0.1, 1.0), IndBox(0.0, 0.5)), -1.0, 0.5),
           (PB.BoxConstrained(Tilt(NormL1(0.25), [-2.0]), IndBox(-1.0, 1.0)), 1.0, 1.0),
           (PB.BoxConstrained(NormL1(0.1), IndBox(-0.5, 0.5)), -1.0, 0.5))
  for (g, G, expected) in cases
    @test PS._coordinate_minimizer(g, 0.7, G, 0.0, 1) === expected
    # Positive curvature keeps the same proximal expression, bit for bit.
    @test PS._coordinate_minimizer(g, 0.7, G, 2.0, 1) === prox_entry(g, 0.7 - G * inv(2.0), 1, inv(2.0))
  end
end

end
