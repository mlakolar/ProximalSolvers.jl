# Proximal Newton for the graphical lasso (QUIC): agreement with ADMM and with
# the optimality conditions, block screening, starting points, and the U = ΘB
# model it runs on.

module QUICTests

using Test, LinearAlgebra, Random, Statistics
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

# a sample covariance from a tridiagonal precision matrix
function glassodata(p, n; seed = 1, ρ = 0.45)
  rng = Xoshiro(seed)
  Ω0 = Matrix(SymTridiagonal(fill(1.0, p), fill(ρ, p - 1)))
  A = randn(rng, n, p) / cholesky(Ω0).U'
  A'A / n
end

offdiag(λ, p) = (W = fill(λ, p, p); W[diagind(W)] .= 0; W)

# a random sparse symmetric matrix with a dominant diagonal
sprandsym(q) = (A = 0.3 .* randn(Xoshiro(21), q, q) .* (rand(Xoshiro(22), q, q) .< 0.2); A + A' + 3I)

# largest violation of 0 ∈ w (S - X⁻¹) + Λ̄ ∂|X|, with Λ̄ the symmetrized penalty
function kkt(X, S, Λ, w)
  G = w .* (S .- inv(Symmetric(X)))
  L = (Λ .+ Λ') ./ 2
  v = 0.0
  for j in axes(X, 2), i in axes(X, 1)
    v = max(v, X[i, j] == 0 ? max(abs(G[i, j]) - L[i, j], 0.0) : abs(G[i, j] + L[i, j] * sign(X[i, j])))
  end
  v
end

admm(f, g, p) = solve!(Matrix(1.0I, p, p), f, g, ADMMSolver(; adaptive = true),
                       ProximalOptions(; maxiter = 50_000, gaptol = 1e-12)).minimizer

@testset "agreement with ADMM and the optimality conditions" begin
  for (p, n, λ, w) in ((15, 200, 0.1, 1.0), (40, 300, 0.05, 1.0), (40, 300, 0.2, 2.5))
    S = glassodata(p, n; seed = p)
    Λ = offdiag(λ, p)
    f, g = LogDetLoss(S, w), NormL1(1.0, Λ)
    X = SymmetricSparseIterate(p)
    r = solve!(X, f, g, ProxNewton(; tol = 1e-11))
    @test r.converged && r.gap <= 1e-11
    @test r.minimum ≈ f(Matrix(X)) + g(Matrix(X)) rtol = 1e-12
    dg = duality_gap(f, g, Matrix(X))
    @test dg.gap / abs(dg.primal) <= 1e-11 * (1 + 1e-6)
    @test kkt(Matrix(X), S, Λ, w) < 1e-6
    Xa = admm(f, g, p)
    @test norm(Matrix(X) - Xa) <= 1e-5 * norm(Xa)
    @test r.minimum <= f(Xa) + g(Xa) + 1e-10 * abs(r.minimum)
  end
  # a penalized diagonal with a scalar λ, on a dense matrix, and a scaled loss
  p = 25
  S = Matrix(Symmetric(cov(randn(Xoshiro(3), 120, p))))
  g = NormL1(0.15)
  Xm = zeros(p, p)
  r = solve!(Xm, LogDetLoss(S), g, ProxNewton(; tol = 1e-11))
  @test r.converged && r.minimizer === Xm && issymmetric(Xm)
  @test kkt(Xm, S, fill(0.15, p, p), 1.0) < 1e-6
  Xs = zeros(p, p)
  rs = solve!(Xs, 2.0 * LogDetLoss(S), g, ProxNewton(; tol = 1e-11))
  Xw = zeros(p, p)
  rw = solve!(Xw, LogDetLoss(S, 2.0), g, ProxNewton(; tol = 1e-11))
  @test Xs ≈ Xw && rs.minimum ≈ rw.minimum
end

@testset "components" begin
  # two blocks and two isolated variables: the solution is block diagonal,
  # and an isolated variable has the closed form 1/(Sᵢᵢ + λᵢᵢ/w)
  rng = Xoshiro(8)
  S1, S2 = glassodata(6, 200; seed = 1), glassodata(5, 200; seed = 2)
  p = 13
  S = zeros(p, p)
  S[1:6, 1:6] = S1; S[7:11, 7:11] = S2; S[12, 12] = 1.3; S[13, 13] = 0.7
  S[1, 7] = S[7, 1] = 0.01                  # below the penalty: no edge
  λ = 0.1
  Λ = fill(λ, p, p); Λ[diagind(Λ)] .= 0.05
  f, g = LogDetLoss(S), NormL1(1.0, Λ)
  @test length(PS._glasso_components(S, g, 1.0)) == 4
  X = SymmetricSparseIterate(p)
  r = solve!(X, f, g, ProxNewton(; tol = 1e-11))
  Xd = Matrix(X)
  @test r.converged && r.gap <= 1e-11
  @test all(iszero, Xd[1:6, 7:end]) && all(iszero, Xd[7:11, 12:13]) && Xd[12, 13] == 0
  @test Xd[12, 12] ≈ 1 / (1.3 + 0.05) && Xd[13, 13] ≈ 1 / (0.7 + 0.05)
  @test kkt(Xd, S, Λ, 1.0) < 1e-6
  Xa = admm(f, g, p)
  @test norm(Xd - Xa) <= 1e-5 * norm(Xa)
end

@testset "starting points" begin
  p = 30
  S = glassodata(p, 250; seed = 5)
  g = NormL1(1.0, offdiag(0.08, p))
  f = LogDetLoss(S)
  X = SymmetricSparseIterate(p)
  solve!(X, f, g, ProxNewton(; tol = 1e-11))
  # a warm start from a neighboring penalty takes fewer passes (the cyclic
  # order makes the counts deterministic)
  g2 = NormL1(1.0, offdiag(0.06, p))
  m = ProxNewton(; tol = 1e-11, inner = CDSolver(; tol = 1e-8, order = :cyclic))
  Xw = SymmetricSparseIterate(Matrix(X))
  rw = solve!(Xw, f, g2, m)
  Xc = SymmetricSparseIterate(p)
  rc = solve!(Xc, f, g2, m)
  @test norm(Matrix(Xw) - Matrix(Xc)) <= 1e-6 * norm(Matrix(Xc))
  @test rw.passes <= rc.passes
  # a start that is not positive definite falls back to the diagonal solution
  Xn = SymmetricSparseIterate(-Matrix(1.0I, p, p))
  rn = solve!(Xn, f, g2, ProxNewton(; tol = 1e-11))
  @test rn.converged && norm(Matrix(Xn) - Matrix(Xc)) <= 1e-6 * norm(Matrix(Xc))
end

@testset "Float32" begin
  p = 20
  S = Float32.(glassodata(p, 200; seed = 9))
  X = SymmetricSparseIterate(Float32, p)
  r = solve!(X, LogDetLoss(S), NormL1(1f0, Float32.(offdiag(0.1, p))), ProxNewton(; tol = 1e-5))
  @test r.converged && r.minimum isa Float32 && r.gap <= 1e-5
end

@testset "the U = ΘB model agrees with KronModel" begin
  q = 12
  Sx, Sy = cov(randn(Xoshiro(15), 60, q)), cov(randn(Xoshiro(16), 60, q))
  fk = KronQuadratic(Sx, Sy, Sx - Sy)
  for s in (CDSolver(; tol = 1e-12), CDSolver(; tol = 1e-12, order = :cyclic), CDSolver(; tol = 1e-12, momentum = true))
    x1, x2 = SymmetricSparseIterate(q), SymmetricSparseIterate(q)
    solve!(x1, fk, NormL1(0.05), s)
    mu = PS.KronUModel(Matrix(Sx), Matrix(Sy), Matrix(Sx - Sy), 1.0)
    r2 = solve!(x2, mu, NormL1(0.05), s)
    @test norm(Matrix(x1) - Matrix(x2)) <= 1e-8 * max(1, norm(Matrix(x1)))
    @test r2.minimum ≈ fk(Matrix(x2)) + NormL1(0.05)(Matrix(x2)) rtol = 1e-10
  end
  # derivatives, values and gradients at a point
  x = SymmetricSparseIterate(Matrix(Symmetric(sprandsym(q))))
  mk, mu = cdmodel(fk, x), PS.KronUModel(Matrix(Sx), Matrix(Sy), Matrix(Sx - Sy), 1.0)
  PS.initialize!(mk, x); PS.initialize!(mu, x)
  for k in 1:ncoordinates(x)
    @test all(PS.coordinate_derivatives(mu, x, k) .≈ PS.coordinate_derivatives(mk, x, k))
  end
  @test PS.loss_value(mu, x) ≈ PS.loss_value(mk, x)
  G1, G2 = zeros(q, q), zeros(q, q)
  PS.gradient!(G1, mk, x); PS.gradient!(G2, mu, x)
  @test G1 ≈ G2
  # the passes allocate nothing
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    fill!(coordinates(x), 0.0); PS.initialize!(m, x)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for s in (CDSolver(), CDSolver(; order = :cyclic), CDSolver(; momentum = true))
    @test passes_bytes(SymmetricSparseIterate(q), PS.KronUModel(Matrix(Sx), Matrix(Sy), Matrix(Sx - Sy), 1.0), NormL1(0.05), s) == 0
  end
end

end
