module WeightedElasticNetTests

using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PG_METHODS = (ProximalGradientDescent(), AccProxGradDescent())

function methods(T)
  cd = CDSolver(order = :cyclic, tol = T === Float32 ? 1e-6 : 1e-10)
  ((cd, false), (cd, true), (PG_METHODS[1], false), (PG_METHODS[2], false))
end

options(T) = ProximalOptions(maxiter = 5_000, ftol = 1e-14, xtol = 1e-12,
  gradtol = T === Float32 ? 2e-5 : 1e-10, allow_f_increases = true)

run!(x, f, g, method::CDSolver, opts) = solve!(x, f, g, method)
run!(x, f, g, method, opts) = solve!(x, f, g, method, opts)
steps(r::CDResults) = r.passes
steps(r) = r.iterations
start(b, sparse) = sparse ? SparseIterate(copy(b)) : copy(b)
snapshot(x) = copy(x)
snapshot(x::SparseIterate) = (collect(activecoordinates(x)), collect(activevalues(x)), collect(x))

function reference_at(X, y, s, coefficients, ridge, x)
  setprecision(BigFloat, 256) do
    A, d, b, c, r, α = big.(X), big.(y), big.(x), big.(coefficients), big(ridge), big(s)
    residual = A * b - d
    gradient = α * (A' * residual)
    objective = (α * sum(abs2, residual) + r * sum(abs2, b)) / 2 + dot(c, abs.(b))
    scores = map(eachindex(b)) do j
      iszero(b[j]) ? max(abs(gradient[j]) - c[j], 0) :
        abs(gradient[j] + r * b[j] + c[j] * sign(b[j]))
    end
    λmax = norm(α * (A' * d), Inf)
    (; objective, gradient, scores, kkt = maximum(scores), scale = max(maximum(c), λmax),
      entry_scales = max.(c, λmax))
  end
end

function exact_coefficients(a, w)
  setprecision(BigFloat, 256) do
    big(a) .* big.(w)
  end
end

function fit_and_check(X::Matrix{T}, y, s, a, b, w, x0, expected, method, sparse) where T
  opts = options(T)
  x = start(x0, sparse)
  loss = s * LeastSquaresLoss(y, X)
  saved_weights = copy(w)
  result = run!(x, loss, ElasticNet(a, b, w), method, opts)
  @test result.minimizer === x
  @test w == saved_weights
  @test result.converged
  v = collect(x)
  reference = reference_at(X, y, s, exact_coefficients(a, w), b, v)
  @test result.minimum ≈ Float64(reference.objective) rtol=32eps(T) atol=8eps(T)
  @test gradient(loss, v) ≈ T.(reference.gradient) rtol=16eps(T) atol=16eps(T)
  @test v ≈ expected rtol=0 atol=(T === Float32 ? 6e-4 : 5e-9)
  if method isa CDSolver
    @test result.maxchange < result.tolerance
    @test result.kkt_checks == 0
    @test reference.kkt < 32eps(T) * max(reference.scale, 1) + 1e-8
  else
    @test result.x_converged || result.f_converged || result.grad_converged
    # A small allowance covers the difference between the native and independent products.
    @test all(reference.scores .< max(opts.gradtol, 64eps(T)) .* reference.entry_scales .+ 32eps(T))
  end
  v
end

@testset "Weighted ElasticNet objective, solution and stopping ($T)" for T in (Float32, Float64)
  # Orthogonal columns include a zero column and a coordinate whose support changes.
  X = Matrix(Diagonal(T[1, 2, 0, 1]))
  y, w = T[2, -1, 0.4, 0.5], T[0, 2, 0, 1]
  s, b = T(0.75), T(0.5)
  for (method, sparse) in methods(T)
    x0 = T[0, 1, 0.5, -1]
    for a in T[0.125, 0.75]
      corr = s .* (X' * y)
      curvature = s .* vec(sum(abs2, X; dims=1))
      expected = sign.(corr) .* max.(abs.(corr) .- a .* w, zero(T)) ./ (curvature .+ b)
      x0 = fit_and_check(X, y, s, a, b, w, x0, expected, method, sparse)
      @test (!iszero(x0[4])) == (a == T(0.125))
    end
  end

  # Correlated wide design. Choose the residual to satisfy the active equations
  # and strict off-support inequalities at the specified solution.
  X = T[1 0 1 0 1; 0 1 1 1 0; 1 1 0 1 -1]
  expected, w = T[1, -1, 0, 0, 0], T[1, 2, 4, 4, 4]
  y = X * expected - T[-1, 1.5, 0]
  a = T(0.5)
  @test iszero(reference_at(X, y, one(T), exact_coefficients(a, w), b, expected).kkt)
  for (method, sparse) in methods(T)
    fit_and_check(X, y, one(T), a, b, w, zeros(T, 5), expected, method, sparse)
  end
end

@testset "Weighted ElasticNet endpoints and mixed levels ($T)" for T in (Float32, Float64)
  X, y, w = Matrix{T}(I, 3, 3), T[2, -1, 0.25], T[0, 2, 1]
  a, b = T(0.25), T(0.5)
  f, x0 = LeastSquaresLoss(y, X), T[1, 0.5, -1]
  W = T === Float32 ? Float64 : BigFloat
  mixed = ElasticNet(one(W) / W(10), one(W) / W(3), w)
  native = ElasticNet(T(mixed.λ1), T(mixed.λ2), w)
  @test PS._converted_penalty(mixed, T).w === w
  @test PS._converted_penalty(native, T) === native

  for (method, sparse) in methods(T)
    for (g, control) in ((ElasticNet(a, zero(T), w), NormL1(a, w)),
                         (ElasticNet(a, b, ones(T, 3)), ElasticNet(a, b)),
                         (ElasticNet(a, b, zeros(T, 3)), ElasticNet(zero(T), b)),
                         (ElasticNet(a, nextfloat(zero(T)), w), NormL1(a, w)))
      x, z = start(x0, sparse), start(x0, sparse)
      r = run!(x, f, g, method, options(T))
      q = run!(z, f, control, method, options(T))
      @test r.converged && q.converged
      @test collect(x) ≈ collect(z) rtol=64eps(T) atol=64eps(T)
      @test r.minimum ≈ q.minimum rtol=64eps(T) atol=64eps(T)
    end
    fit_and_check(X, y, one(T), zero(T), zero(T), w, x0, y, method, sparse)
    x, z = start(x0, sparse), start(x0, sparse)
    r = run!(x, f, mixed, method, options(T))
    q = run!(z, f, native, method, options(T))
    @test r.converged && q.converged
    @test (collect(x), r.minimum, steps(r)) == (collect(z), q.minimum, steps(q))
    mixed_scale = T === Float32 ? 0.75 : T(0.75)
    corr = mixed_scale .* y
    expected = T.(sign.(corr) .* max.(abs.(corr) .- a .* w, 0) ./ (mixed_scale + b))
    fit_and_check(X, y, mixed_scale, a, b, w, x0, expected, method, sparse)
  end
end

@testset "The PG stop uses per-coordinate ElasticNet thresholds ($T)" for
    T in (Float32, Float64), method in PG_METHODS
  X = Matrix{T}(I, 2, 2)
  for (y, x, a, b, w, gradtol, expected) in (
      (T[0.9, 0], T[0.5, 0], one(T), T(0.25), T[1, 1000], 0.01, false),
      (T[0, 100], T[0, 0.25], T(2), T(0.25), T[0.5, 500], 0.95, true),
      (T[1, 0], T[0.25, 0], one(T), one(T), T[0, 1000], 0.5, false),
      (T[1, 0], T[0, 0], T(0.5), T(0.25), T[0, 1], 0.6, false),
      (T[1, 0], T[0.5, 0], T(0.5), T(0.25), T[0, 1], 0.2, false),
      (T[1, 0], T[0.8, 0], T(0.5), T(0.25), T[0, 1], 0.2, true))
    g, f = ElasticNet(a, b, w), LeastSquaresLoss(y, X)
    opts = ProximalOptions(; gradtol)
    state = PS.initial_state(method, opts, f, g, copy(x))
    ref = reference_at(X, y, one(T), exact_coefficients(a, w), b, x)
    @test all(ref.scores .< gradtol .* ref.entry_scales) == expected
    @test PS._stationary!(state, f, g, opts) == expected
    @test state.λmax == maximum(abs, y)
    @test PS._l1_level(g) == a * maximum(w)
    if maximum(w) > 1
      @test ref.kkt < gradtol * ref.scale
      @test ref.kkt >= gradtol * maximum(abs, y)
    else
      unweighted = reference_at(X, y, one(T), fill(a, 2), b, x)
      @test (unweighted.kkt < gradtol * unweighted.scale) != expected
    end
  end

  f = LeastSquaresLoss(zeros(T, 2), X)
  opts = ProximalOptions()
  for w in (T[0, 0], T[0, 1000])
    g = ElasticNet(one(T), T(0.5), w)
    state = PS.initial_state(method, opts, f, g, zeros(T, 2))
    @test !PS._stationary!(state, f, g, opts)
  end
  g = ElasticNet(one(T), T(0.5), T[0, 1])
  grad, x = zeros(T, 2), zeros(T, 2)
  @test !PS._entry_thresholds_hold(g, grad, x, T(0.5), floatmin(T))
  @test PS._entry_thresholds_hold(g, grad, x, T(0.5), T(2) * floatmin(T))
end

@testset "Weighted ElasticNet public PG result flags ($T)" for T in (Float32, Float64), method in PG_METHODS
  X, y = T[1 0; 0 2], T[2, 0]
  f = LeastSquaresLoss(y, X)
  x = zeros(T, 2)
  opts = ProximalOptions(maxiter = 2, gradtol = 0.01, ftol = 100, prox_calls_limit = 1)
  for w in (T[0, 1000], T[0.125, 1e6])
    fill!(x, zero(T))
    result = solve!(x, f, ElasticNet(one(T), one(T), w), method, opts)
    at_x = reference_at(X, y, one(T), w, one(T), x)
    @test result.iterations == 1 && result.call_limit_reached && !result.converged
    @test !(result.x_converged || result.f_converged || result.grad_converged)
    @test at_x.kkt < opts.gradtol * at_x.scale
    @test at_x.scores[1] > opts.gradtol * at_x.entry_scales[1]

    expected = T[(y[1] - w[1]) / 2, 0]
    fit_and_check(X, y, one(T), one(T), one(T), w, zeros(T, 2), expected, method, false)
  end

  fill!(x, zero(T))
  zero_loss = LeastSquaresLoss(zeros(T, 2), X)
  result = solve!(x, zero_loss, ElasticNet(one(T), one(T), zeros(T, 2)), method,
                  ProximalOptions(maxiter = 2, gradtol = 0.01, ftol = 100))
  @test iszero(x) && result.iteration_converged && !result.converged
  @test !(result.x_converged || result.f_converged || result.grad_converged)
end

@testset "CD exceptional band uses the checked L1 coefficient ($T)" for T in (Float32, Float64)
  λ = floatmin(T)
  f = (λ / T(4)) * LeastSquaresLoss(T[8], fill(one(T), 1, 1))
  method = CDSolver(order = :cyclic, relative = false)
  for sparse in (false, true), (w, expected) in ((one(T), T(4)), (zero(T), T(8)), (prevfloat(one(T)), T(4)))
    x = start(T[1], sparse)
    r = solve!(x, f, ElasticNet(λ, zero(T), T[w]), method)
    @test r.converged && collect(x) == T[expected]
    x = start(T[1], sparse)
    before = snapshot(x)
    @test_throws ArgumentError solve!(x, f, ElasticNet(λ, nextfloat(zero(T)), T[w]), method)
    @test isequal(snapshot(x), before)
  end
end

@testset "CD overflowed step product and private rollback ($T)" for T in (Float32, Float64)
  scale = floatmax(T)
  method = CDSolver(order = :cyclic, relative = false)
  for sparse in (false, true)
    x = start(T[0.25], sparse)
    f = scale * LeastSquaresLoss(T[2], fill(T(2), 1, 1))
    r = solve!(x, f, ElasticNet(scale, zero(T), T[0.5]), method)
    @test r.converged && x[1] == T(0.875) && isfinite(r.minimum)

    # The first coordinate takes a normal step from 0.25 to 2. The second
    # coordinate has a finite curvature and an overflowing scale product.
    X = Matrix(Diagonal(T[0.25, 2]))
    f = scale * LeastSquaresLoss(T[0.5, 0.25], X)
    x = start(T[0.25, 0.25], sparse)
    g = ElasticNet(one(T), one(T), T[1, 2])
    before = snapshot(x)
    error = try
      solve!(x, f, g, method)
      nothing
    catch err
      err
    end
    @test error isa ArgumentError && occursin("coordinate 2 is outside the normal range", error.msg)
    @test isequal(snapshot(x), before)

    # This ordinary step has an overlarge step-times-level product and zero weight.
    x = start(T[0.25], sparse)
    f = T(0.25) * LeastSquaresLoss(T[2], fill(one(T), 1, 1))
    r = solve!(x, f, ElasticNet(scale, T(0.25), T[0]), method)
    @test r.converged && x[1] == one(T)
  end
end

function refuse(E, x, f, g, method, opts)
  before = snapshot(x)
  @test_throws E run!(x, f, g, method, opts)
  @test isequal(snapshot(x), before)
end

@testset "Weighted ElasticNet validation precedes mutation ($T)" for T in (Float32, Float64)
  X, y, x0 = Matrix{T}(I, 2, 2), T[2, -1], T[1, 2]
  f, opts = LeastSquaresLoss(y, X), options(T)
  a, b, tiny = T(0.5), T(0.25), nextfloat(zero(T))
  W = T === Float32 ? Float64 : BigFloat
  wrong_weight_type = T === Float32 ? Float64 : Float32
  mutable_w = T[1, 2]
  mutable_g = ElasticNet(a, b, mutable_w)
  rng = Xoshiro(456)
  saved_rng = copy(rng)
  for (method, sparse) in ((CDSolver(rng=rng), false), (CDSolver(rng=rng), true),
                           (PG_METHODS[1], false), (PG_METHODS[2], false))
    x = start(x0, sparse)
    refuse(DimensionMismatch, x, f, ElasticNet(a, b, T[1]), method, opts)
    for g in (ElasticNet(a, b, ones(wrong_weight_type, 2)),
              ElasticNet(a, b, reshape(T[1, 2], 1, 2)),
              ElasticNet(a, b, view(T[1, 2, 3], 1:2)),
              ElasticNet(T(Inf), b, T[1, 2]),
              ElasticNet(a, T(Inf), T[1, 2]),
              ElasticNet(tiny, b, T[1, 2]),
              ElasticNet(W(floatmax(T)) * 2, W(b), T[1, 2]),
              ElasticNet(W(a), W(floatmax(T)) * 2, T[1, 2]),
              ElasticNet(W(tiny) / 4, W(b), T[1, 2]),
              ElasticNet(W(a), W(tiny) / 4, T[1, 2]),
              ElasticNet(floatmax(T), b, T[2, 1]),
              ElasticNet(floatmin(T), b, T[tiny, 1]),
              ElasticNet(floatmin(T), b, T[prevfloat(prevfloat(one(T))), 1]),
              Scaled(ElasticNet(a, b, T[1, 2]), 2))
      refuse(ArgumentError, x, f, g, method, opts)
    end
    for bad_value in T[-1, Inf, NaN]
      mutable_w[1] = bad_value
      refuse(ArgumentError, x, f, mutable_g, method, opts)
      @test isequal(mutable_w[1], bad_value)
    end
    mutable_w[1] = one(T)
    weights = sparse ? parent(activevalues(x)) : x
    @assert length(weights) == length(x) && Base.mightalias(x, weights)
    refuse(ArgumentError, x, f, ElasticNet(a, b, weights), method, opts)
    @test rng == saved_rng
  end

  mutable_w[1] = zero(T)
  g_updated = ElasticNet(a, b, copy(mutable_w))
  g_original = ElasticNet(a, b, T[1, 2])
  for (method, sparse) in methods(T)
    x, z, old = (start(x0, sparse) for _ in 1:3)
    r = run!(x, f, mutable_g, method, opts)
    q = run!(z, f, g_updated, method, opts)
    run!(old, f, g_original, method, opts)
    @test (collect(x), r.minimum) == (collect(z), q.minimum)
    @test collect(x) != collect(old)
  end
end

@testset "Weighted ElasticNet remains on the scalar least-squares routes ($T)" for T in (Float32, Float64)
  X, y, x0 = Matrix{T}(I, 2, 2), T[1, 0], T[0.5, 0.5]
  f, g = LeastSquaresLoss(y, X), ElasticNet(T(0.2), T(0.1), T[0, 1])
  cd = CDSolver()
  for method in (cd, PG_METHODS...)
    refuse(ArgumentError, copy(x0), SqrtLeastSquaresLoss(y, X), g, method, options(T))
    Y, B = hcat(y, y), ones(T, 2, 2)
    refuse(ArgumentError, B, LeastSquaresLoss(Y, X), g, method, options(T))
    refuse(ArgumentError, view(copy(x0), :), f, g, method, options(T))
    if T === Float64
      refuse(ArgumentError, copy(x0), LogisticLoss(y, X), g, method, options(T))
    end
  end
  for method in PG_METHODS
    refuse(ArgumentError, SparseIterate(copy(x0)), f, g, method, options(T))
  end
  groups = [[1], [2]]
  block = BlockIterate(T, 2, groups)
  @test_throws ArgumentError solve!(block, f, g, cd)
  @test all(iszero, block)
  x = copy(x0)
  @test_throws ArgumentError solve!(x, f, g, ADMMSolver())
  @test x == x0
end

end
