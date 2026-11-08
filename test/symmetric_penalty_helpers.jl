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

# ProximalBase 0.6 has the public checker; earlier versions are covered by the
# transitional check of ProximalSolvers
pb_checks_symmetry() = isdefined(ProximalBase, :check_symmetric_parameters)

# everything a rejected call must leave alone in an owner
snapshot(x) = (Matrix(x), collect(coordinates(x)), collect(activecoordinates(x)), nactive(x),
               isdefined(ProximalBase, :activevalues) ? collect(ProximalBase.activevalues(x)) : nothing)

# a tuple of block iterates: the snapshot of each block
snapshot(x::Tuple) = map(snapshot, x)
snapshot(x::Array) = copy(x)

# reason: the part of the message of ProximalBase's parameter check that names the
# rejection, by default its symmetry rule
function rejects_symmetry(action, x; reason = "must be symmetric on a SymmetricSparseIterate")
  @nospecialize action
  before = snapshot(x)
  err = try
    action()
    nothing
  catch e
    e
  end
  @test err isa ArgumentError
  if err isa ArgumentError
    msg = sprint(showerror, err)
    @test occursin(reason, msg)
    # the reason is the symmetry rule, not the type of the replacement penalty of a workspace
    @test !occursin("a workspace needs a penalty of type", msg)
  end
  @test isequal(snapshot(x), before)
end

# a copy of a value held by the state of a workspace (iterates, gradients, values, counters)
state_value(a::SymmetricSparseIterate) = snapshot(a)
state_value(a::AbstractArray) = copy(a)
state_value(a::Tuple) = map(state_value, a)
state_value(a) = a
state_snapshot(ws) = hasproperty(ws.buffers, :state) ?
  map(n -> state_value(getfield(ws.buffers.state, n)), fieldnames(typeof(ws.buffers.state))) : nothing

# the same for a workspace: its penalty, its iterate and the buffers of its state (the caches of
# the loss and the gradient among them) stay as they were
function rejects_in_workspace(action, ws, x = ws.x)
  @nospecialize action
  g = ws.g
  state = state_snapshot(ws)
  rejects_symmetry(action, x)
  @test ws.g === g
  @test isequal(state_snapshot(ws), state)
end

# whether the objective obj of a symmetric matrix does not decrease along the
# coordinates of the owner (an entry, or a pair of transposed entries) on both
# sides of X: a check by the dense objective alone, with no solver
function coordinatewise_minimum(obj, X; steps = (1e-4, 1e-2), slack = 1e-10)
  @nospecialize obj
  base = obj(X)
  ok = isfinite(base)
  for c in axes(X, 2), r in c:size(X, 1), t in steps, s in (-1, 1)
    Y = copy(X)
    Y[r, c] += s * t
    r == c || (Y[c, r] += s * t)
    ok &= !(obj(Y) < base - slack)
  end
  ok
end

# the largest violation of the optimality conditions of an L1 problem on a
# symmetric matrix X with the gradient G of the loss on the full matrix and the
# supplied weights W: a pair (r, c) moves two entries, with the derivative 2G
# and the threshold λ (W[r,c] + W[c,r]), a diagonal entry has G and λ W[r,r]
function symmetric_l1_violation(G, X, λ, W)
  v = 0.0
  for c in axes(X, 2), r in c:size(X, 1)
    z = X[r, c]
    h = r == c ? G[r, c] : 2G[r, c]
    t = λ * (r == c ? W[r, c] : W[r, c] + W[c, r])
    v = max(v, iszero(z) ? max(abs(h) - t, 0.0) : abs(h + t * sign(z)))
  end
  v
end

function check_parameters(arrays, before)
  for (a, b) in zip(arrays, before)
    @test isequal(a, b)
  end
end

# one row of an exactness table: the raw penalty g, with asymmetric parameters, is
# rejected on an owner before anything is written, at every entry point checked
# here; the explicitly symmetric penalty gbar goes on as the same object, and its
# solution is checked by the dense objective, never by another solve
@noinline function check_exactness(f, g, gbar, arrays, points, starts)
  @nospecialize g gbar
  model = cdmodel(f, SymmetricSparseIterate(2))
  before = map(copy, arrays)
  for X in points
    # both triangles share Xrc, so wrc φ(Xrc) + wcr φ(Xrc) = 2w̄rc φ(Xrc): a dense
    # identity, a reference only; the raw penalty is never evaluated on an owner
    @test isfinite(g(X)) && isfinite(gbar(X))
    @test g(X) ≈ gbar(X) rtol = 1e-12
  end
  @test PS._symmetric_penalty(gbar, SymmetricSparseIterate(2)) === gbar
  xw = warm_start()
  rejects_symmetry(xw) do
    PS._symmetric_penalty(g, xw)
  end
  rejects_symmetry(xw) do
    solve!(xw, model, g, cdsolver())
  end
  rejects_symmetry(xw) do
    SolverWorkspace(xw, f, g, cdsolver())
  end
  if ProximalBase.isproximable(g)
    rejects_symmetry(xw) do
      solve!(xw, f, g, ProximalGradientDescent(), gradient_options())
    end
    rejects_symmetry(xw) do
      SolverWorkspace(xw, f, g, ProximalGradientDescent(), gradient_options())
    end
  end
  ws = SolverWorkspace(xw, f, gbar, cdsolver())
  rejects_in_workspace(ws) do
    solve!(ws, g)
  end
  check_parameters(arrays, before)
  obj(X) = f(X) + gbar(X)
  for start in starts
    y = SymmetricSparseIterate(start)
    r = solve!(y, model, gbar, cdsolver())
    @test r.converged
    Y = Matrix(y)
    @test r.minimum ≈ obj(Y) rtol = 1e-12 atol = 1e-14
    @test coordinatewise_minimum(obj, Y)
    check_parameters(arrays, before)
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

