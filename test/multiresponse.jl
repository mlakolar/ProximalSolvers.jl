module MultiResponseTests

using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Statistics, Test
const PS = ProximalSolvers

# the largest violation of the optimality conditions of λ ∑ₖ wₖ ‖B[k, :]‖₂ for
# the gradient G (p × q) of the loss
function kkt_rows(G, B, λ, w)
  maximum(axes(B, 1)) do k
    nb = norm(B[k, :])
    iszero(nb) ? max(norm(G[k, :]) - λ * w[k], 0.0) : norm(G[k, :] + λ * w[k] * B[k, :] / nb)
  end
end

@testset "multi-response least squares" begin
  rng = Xoshiro(31)
  n, p, q = 150, 40, 4
  X = randn(rng, n, p)
  B = zeros(p, q); B[1:5, :] .= randn(rng, 5, q)
  Y = 1.0 .+ X * B .+ 0.5 .* randn(rng, n, q)
  groups = [collect(k:p:p*q) for k in 1:p]
  w = ones(p)
  f = (1 / n) * LeastSquaresLoss(Y, X)
  s = CDSolver(; tol = 1e-10)

  # with an intercept: the optimality conditions of the rows and of the intercepts
  x = AtomIterate(Float64, p * q, groups)
  m = cdmodel(f, x; intercept = true)
  λmax = lambda_max(m, GroupNormL2(1.0, groups, w), x)
  Yc, Xc = Y .- mean(Y; dims = 1), X .- mean(X; dims = 1)
  @test λmax ≈ maximum(norm((Xc' * Yc / n)[k, :]) for k in 1:p)
  λ = 0.2 * λmax
  r = solve!(x, m, GroupNormL2(λ, groups, w), s)
  Bh = reshape(Vector(x), p, q)
  b0 = PS.intercept(m, x)
  R = Y .- b0' .- X * Bh
  @test r.converged
  @test PS.residuals(m) ≈ R
  @test norm(mean(R; dims = 1)) < 1e-12
  @test kkt_rows(-X' * R / n, Bh, λ, w) < 1e-8
  @test r.minimum ≈ sum(abs2, R) / (2n) + λ * sum(norm(Bh[k, :]) for k in 1:p)
  @test count(k -> norm(Bh[k, :]) > 0, 1:p) >= 5

  # without an intercept, the solution of accelerated proximal gradient on the
  # p × q matrix with the strided groups
  x0 = AtomIterate(Float64, p * q, groups)
  solve!(x0, f, GroupNormL2(λ, groups, w), s)
  Bg = zeros(p, q)
  solve!(Bg, f, GroupNormL2(λ, groups, w), AccProxGradDescent(),
         ProximalOptions(; maxiter = 20_000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12))
  @test reshape(Vector(x0), p, q) ≈ Bg atol = 1e-6

  # one response: the lasso
  y = Y[:, 1]
  x1 = AtomIterate(Float64, p, [[k] for k in 1:p])
  solve!(x1, (1 / n) * LeastSquaresLoss(reshape(y, n, 1), X), GroupNormL2(λ, [[k] for k in 1:p], w), s)
  xl = SparseIterate(p)
  solve!(xl, (1 / n) * LeastSquaresLoss(y, X), NormL1(λ), s)
  @test Vector(x1) ≈ Vector(xl) atol = 1e-8

  # paths: zero at λmax, screening gives the solutions without it
  λs = λmax * (1 + 1e-8) .* exp.(range(0, log(0.05); length = 15))
  b0s = Vector{Float64}[]
  path = solve_path(cdmodel(f, x; intercept = true), GroupNormL2(1.0, groups, w), λs, s;
                    x = AtomIterate(Float64, p * q, groups),
                    callback = (k, λ, x, m) -> (push!(b0s, PS.intercept(m, x)); false))
  @test nnz(path.solutions[1]) == 0
  @test all(path.converged) && all(path.kkt_checks .>= 1)
  path0 = solve_path(f, GroupNormL2(1.0, groups, w), λs, s; screening = false)
  path1 = solve_path(f, GroupNormL2(1.0, groups, w), λs, s)
  @test all(norm(path1.solutions[k] - path0.solutions[k]) < 1e-7 for k in eachindex(λs))
  @test b0s[end] ≈ vec(mean(Y .- X * reshape(Vector(path.solutions[end]), p, q); dims = 1))

  # it takes GroupNormL2 on the rows only
  @test_throws ArgumentError solve!(AtomIterate(Float64, p * q, groups), f, NormL1(λ), s)
  wrong = [collect((k - 1) * q + 1:k * q) for k in 1:p]          # the columns of B', not its rows
  @test_throws ArgumentError solve!(AtomIterate(Float64, p * q, wrong), f, GroupNormL2(λ, wrong, w), s)

  # the passes allocate nothing once the model and the state exist
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    fill!(x, 0.0); PS.initialize!(m, x)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for sv in (CDSolver(; order = :cyclic), CDSolver(; order = :random), CDSolver(; momentum = true))
    xa = AtomIterate(Float64, p * q, groups)
    @test passes_bytes(xa, cdmodel(f, xa; intercept = true), GroupNormL2(λ, groups, w), sv) == 0
  end

  # Float32
  x32 = AtomIterate(Float32, p * q, groups)
  r32 = solve!(x32, (1f0 / n) * LeastSquaresLoss(Float32.(Y), Float32.(X)), GroupNormL2(Float32(λ), groups, Float32.(w)),
               CDSolver(; tol = 1e-5))
  @test r32.converged
  @test Vector(x32) ≈ Vector(x0) atol = 1e-3
end

end
