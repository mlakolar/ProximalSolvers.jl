cdsolver() = CDSolver(; order = :cyclic, tol = 1e-13, relative = false)
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

