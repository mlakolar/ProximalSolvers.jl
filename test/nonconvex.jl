module NonconvexTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

const PS = ProximalSolvers
const SOLVERS = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

# least squares ‖y - Xβ‖²/(2n) with s nonzero coefficients and a strong signal,
# so that iterative hard thresholding finds the true support, whose
# least-squares fit is then the global minimizer over the ℓ0 ball
function sparse_regression(rng; n = 200, p = 400, s = 5)
  X = randn(rng, n, p)
  β0 = zeros(p); S = randperm(rng, p)[1:s]; β0[S] .= 3 .* rand(rng, (-1.0, 1.0), s)
  y = X * β0 + 0.1 * randn(rng, n)
  X, y, sort(S)
end

objective_trace(res) = [st.fg_x for st in res.trace]

@testset "iterative hard thresholding: $(summary(solver))" for solver in SOLVERS
  rng = MersenneTwister(1)
  X, y, S = sparse_regression(rng)
  n, p = size(X)
  f, g = Scaled(LeastSquaresLoss(y, X), 1 / n), IndBallL0(length(S))
  β = zeros(p)
  res = solve!(β, f, g, solver, ProximalOptions(; maxiter = 2000, store_trace = true))
  @test findall(!iszero, β) == S
  # the global minimizer: least squares on the true support
  βS = zeros(p); βS[S] = X[:, S] \ y
  @test res.minimum ≈ f(βS) rtol = 1e-6
  # the line search keeps the objective from increasing
  F = objective_trace(res)
  @test all(diff(F) .<= 1e-12 * abs(F[1]))
end

@testset "IHT on a SymmetricSparseIterate: $(summary(solver))" for solver in SOLVERS
  # the D-trace loss of a symmetric Δ with at most s off-diagonal entries in a
  # triangle: the iterates stay symmetric SymmetricSparseIterates
  rng = MersenneTwister(2)
  p, n, s = 12, 200, 4
  Ωx = Matrix(SymTridiagonal(fill(1.0, p), fill(0.3, p - 1)))
  Ωy = copy(Ωx); Ωy[2, 7] = Ωy[7, 2] = 0.25; Ωy[3, 9] = Ωy[9, 3] = -0.25; Ωy += 0.3I
  Σ(Ω) = (A = randn(rng, n, p) / cholesky(Symmetric(Ω)).U'; Matrix(Symmetric(A'A / n)))
  Σx, Σy = Σ(Ωx), Σ(Ωy)
  f, g = KronQuadratic(Σx, Σy, Σx - Σy), IndBallL0(s; diagonal = false)
  Δ = SymmetricSparseIterate(p)
  res = solve!(Δ, f, g, solver, ProximalOptions(; maxiter = 5000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12,
                                                 store_trace = true))
  @test res.minimizer === Δ
  D = Matrix(Δ)
  @test issymmetric(D)
  @test count(!iszero, D[i, j] for j in 1:p for i in j+1:p) <= s
  @test isfinite(res.minimum)
  F = objective_trace(res)
  @test all(diff(F) .<= 1e-12 * max(abs(F[1]), 1))
  # the solution is a fixed point of the hard-thresholding step on its support
  G = similar(D); gradient!(G, f, Δ)
  for j in 1:p, i in j:p
    D[i, j] != 0 && @test abs(G[i, j]) < 1e-4
  end
end

@testset "IHT with LogDetLoss stays positive definite: $(summary(solver))" for solver in SOLVERS
  # the trial points off the cone have f = Inf and are rejected
  rng = MersenneTwister(3)
  p = 15
  Ω0 = Matrix(SymTridiagonal(fill(1.0, p), fill(0.45, p - 1)))
  A = randn(rng, 3p, p) / cholesky(Ω0).U'
  f = LogDetLoss(Matrix(Symmetric(A'A / 3p)))
  g = IndBallL0(p - 1; diagonal = false)
  X = SymmetricSparseIterate(p)
  for i in 1:p; X[i, i] = 1.0; end
  res = solve!(X, f, g, solver, ProximalOptions(; maxiter = 5000, store_trace = true))
  @test isposdef(Symmetric(Matrix(X)))
  @test isfinite(res.minimum) && res.minimum < f(Matrix(1.0I, p, p))
  F = objective_trace(res)
  @test all(isfinite, F)
  @test all(diff(F) .<= 1e-12 * abs(F[1]))
end

@testset "MonotoneAccProxGradDescent" begin
  @test_throws ArgumentError MonotoneAccProxGradDescent(; δ = 0)
  @test_throws ArgumentError MonotoneAccProxGradDescent(; β = 1)
  @test summary(MonotoneAccProxGradDescent()) == "Monotone Accelerated Proximal Gradient Descent"

  # on a convex lasso it agrees with AccProxGradDescent, and its objective never increases
  rng = MersenneTwister(4)
  n, p = 100, 60
  X = randn(rng, n, p)
  y = X * vcat(randn(rng, 5), zeros(p - 5)) + 0.1 * randn(rng, n)
  f, g = Scaled(LeastSquaresLoss(y, X), 1 / n), NormL1(0.05)
  opt = ProximalOptions(; maxiter = 10_000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, store_trace = true)
  x1, x2 = zeros(p), zeros(p)
  r1 = solve!(x1, f, g, AccProxGradDescent(), opt)
  r2 = solve!(x2, f, g, MonotoneAccProxGradDescent(), opt)
  @test x2 ≈ x1 atol = 1e-6
  @test r2.minimum ≈ r1.minimum rtol = 1e-10
  F = objective_trace(r2)
  @test all(diff(F) .<= 1e-14 * abs(F[1]))
  # the extrapolated step is kept on many iterations of a convex problem (how
  # many depends on rounding, so only that the accelerated branch is used)
  st = PS.initial_state(MonotoneAccProxGradDescent(), opt, f, g, zeros(p))
  for _ in 1:50
    PS.update_state!(f, g, st, MonotoneAccProxGradDescent())
  end
  @test st.accelerated >= 10

  # an iteration allocates nothing on a dense start
  m = MonotoneAccProxGradDescent()
  step!(st) = @allocated PS.update_state!(f, g, st, m)
  step!(st)
  @test step!(st) == 0
end

@testset "normalized IHT steps" begin
  rng = MersenneTwister(5)
  X, y, S = sparse_regression(rng)
  n, p = size(X)
  f, g = Scaled(LeastSquaresLoss(y, X), 1 / n), IndBallL0(length(S))
  # the first trial step is the exact line minimizer along the gradient on the support
  x = zeros(p); x[S] .= 1.0
  opt = ProximalOptions()
  st = PS.initial_state(ProximalGradientDescent(; normalized = true), opt, f, g, copy(x))
  copyto!(st.x_previous, st.x); st.f_x_previous = st.f_x; copyto!(st.grad_f_x_previous, st.grad_f_x)
  PS._normalized_step!(f, st)
  d = zeros(p); d[S] = st.grad_f_x[S]
  μ = sum(abs2, d) / (sum(abs2, X * d) / n)
  @test 1 / st.L ≈ μ rtol = 1e-8
  # at x = 0 the step uses the whole gradient
  st0 = PS.initial_state(ProximalGradientDescent(; normalized = true), opt, f, g, zeros(p))
  copyto!(st0.x_previous, st0.x); copyto!(st0.grad_f_x_previous, st0.grad_f_x); st0.f_x_previous = st0.f_x
  PS._normalized_step!(f, st0)
  d0 = st0.grad_f_x
  @test 1 / st0.L ≈ sum(abs2, d0) / (sum(abs2, X * d0) / n) rtol = 1e-8
  # the same solution as the default steps
  β1, β2 = zeros(p), zeros(p)
  r1 = solve!(β1, f, g, ProximalGradientDescent(), ProximalOptions(; maxiter = 2000))
  r2 = solve!(β2, f, g, ProximalGradientDescent(; normalized = true), ProximalOptions(; maxiter = 2000))
  @test findall(!iszero, β2) == S
  @test r2.minimum ≈ r1.minimum rtol = 1e-6
end

@testset "debiasing" begin
  rng = MersenneTwister(6)
  X, y, S = sparse_regression(rng; n = 100, p = 200)
  n, p = size(X)
  f, g = Scaled(LeastSquaresLoss(y, X), 1 / n), IndBallL0(length(S))
  @test_throws ArgumentError ProximalGradientDescent(; debias = -1)
  for x0 in (zeros(p), SparseIterate(p))
    β = x0
    res = solve!(β, f, g, ProximalGradientDescent(; debias = 3), ProximalOptions(; maxiter = 2000))
    b = Vector(β)
    @test findall(!iszero, b) == S
    # the refit: least squares on the support
    @test b[S] ≈ X[:, S] \ y rtol = 1e-6
  end
  # D-trace on a SymmetricSparseIterate: the refit zeroes the gradient on the support
  Σx = Matrix(Symmetric(randn(rng, 50, 8)' * randn(rng, 50, 8) / 50 + I))
  Σy = Σx + 0.1I
  fk = KronQuadratic(Σx, Σy, Σx - Σy)
  Δ = SymmetricSparseIterate(8)
  solve!(Δ, fk, IndBallL0(3; diagonal = false), ProximalGradientDescent(; debias = 2), ProximalOptions(; maxiter = 2000))
  G = zeros(8, 8); gradient!(G, fk, Δ)
  D = Matrix(Δ)
  @test all(abs(G[i, j]) < 1e-8 for j in 1:8 for i in j:8 if D[i, j] != 0)
  # losses that refit! does not support, and dense matrix iterates, are refused
  @test_throws ArgumentError solve!(Matrix(1.0I, 4, 4), LogDetLoss(Matrix(1.0I, 4, 4)), IndBallL0(2; diagonal = false),
                                    ProximalGradientDescent(; debias = 2))
end

end
