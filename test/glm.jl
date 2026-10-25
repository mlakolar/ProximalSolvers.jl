module GLMTests

using ProximalSolvers, ProximalBase, LinearAlgebra, Random, SparseArrays, Statistics, Test
logistic(z) = 1 / (1 + exp(-z))
function kkt_l1(grad, x, λ)
  maximum(i -> x[i] == 0 ? max(abs(grad[i]) - λ, 0.0) : abs(grad[i] + λ * sign(x[i])), eachindex(x))
end
rng = Xoshiro(3)
n, p = 300, 500
X = randn(rng, n, p); β = zeros(p); β[1:5] .= [1.5, -1, 1, -0.8, 0.6]
y = Float64.(rand(rng, n) .< logistic.(X * β))
f = (1 / n) * LogisticLoss(y, X)
gradf(b) = X' * (logistic.(X * b) .- y) / n
λ = 0.1 * maximum(abs, gradf(zeros(p)))
@testset "generalized linear losses" begin
  x1 = SparseIterate(p)
  r1 = solve!(x1, f, NormL1(λ), CDSolver(; tol = 1e-10, maxpasses = 10^6))
  @test r1.converged
  @test kkt_l1(gradf(Vector(x1)), Vector(x1), λ) < 1e-6
  x2 = SparseIterate(p)
  r2 = solve!(x2, f, NormL1(λ), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
  @test r2.converged
  @test kkt_l1(gradf(Vector(x2)), Vector(x2), λ) < 1e-6
  @test Vector(x1) ≈ Vector(x2) atol = 1e-5
  # Poisson: unbounded curvature, ProxNewton only
  yp = Float64.([rand(rng) < 0.5 ? 0 : rand(rng, 0:4) for _ in 1:n])
  fp = (1 / n) * PoissonLoss(yp, X)
  @test_throws ArgumentError solve!(SparseIterate(p), fp, NormL1(0.1), CDSolver())
  gp(b) = X' * (exp.(X * b) .- yp) / n
  λp = 0.2 * maximum(abs, gp(zeros(p)))
  x3 = SparseIterate(p)
  r3 = solve!(x3, fp, NormL1(λp), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
  @test r3.converged
  @test kkt_l1(gp(Vector(x3)), Vector(x3), λp) < 1e-6
  # Poisson counts around 50: from zero, the first Newton steps overshoot, and
  # the line search shortens them
  ηtrue = 4 .+ 0.3 .* (X[:, 1:3] * [1.0, -1.0, 0.5])
  yc = Float64.(round.(exp.(ηtrue)))
  fc = (1 / n) * PoissonLoss(yc, X)
  gc(b) = X' * (exp.(X * b) .- yc) / n
  λc = 0.05 * maximum(abs, gc(zeros(p)))
  x5 = SparseIterate(p)
  r5 = solve!(x5, fc, NormL1(λc), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
  @test r5.converged
  @test kkt_l1(gc(Vector(x5)), Vector(x5), λc) < 1e-6 * maximum(abs, gc(zeros(p)))
  # warm starts: proximal Newton and coordinate descent with the curvature bound
  x6 = SparseIterate(Vector(x2) .+ 0.1 .* randn(rng, p))
  solve!(x6, f, NormL1(λ), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
  @test Vector(x6) ≈ Vector(x2) atol = 1e-6
  x7 = SparseIterate(Vector(x2) .+ 0.1 .* randn(rng, p))
  solve!(x7, f, NormL1(λ), CDSolver(; tol = 1e-10, maxpasses = 10^6))
  @test Vector(x7) ≈ Vector(x2) atol = 1e-5
  # an unscaled loss: the same solution at the penalty level scaled by n
  x8 = SparseIterate(p)
  solve!(x8, LogisticLoss(y, X), NormL1(n * λ), ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10)))
  @test Vector(x8) ≈ Vector(x2) atol = 1e-6
  # Huber
  yh = X * β + randn(rng, n) .* 2; yh[1:10] .+= 30
  fh = (1 / n) * HuberLoss(yh, X, 1.0)
  x4 = SparseIterate(p)
  r4 = solve!(x4, fh, NormL1(0.05), CDSolver(; tol = 1e-10, maxpasses = 10^6))
  @test r4.converged
  ψ(r) = clamp(r, -1.0, 1.0)
  @test kkt_l1(X' * ψ.(X * Vector(x4) - yh) / n, Vector(x4), 0.05) < 1e-6
end

@testset "proximal Newton: an intercept, and paths" begin
  rng = Xoshiro(7)
  n, p = 200, 50
  X = randn(rng, n, p); β = zeros(p); β[1:4] .= [1.0, -1.0, 0.8, -0.5]
  y = Float64.(rand(rng, n) .< logistic.(0.5 .+ X * β))
  f = (1 / n) * LogisticLoss(y, X)
  newton = ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10))
  m = ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true)

  # λmax with an intercept: the gradient at the fit with only the intercept,
  # logit of the mean response
  λmax = lambda_max(m, NormL1(1.0), SparseIterate(p))
  ȳ = mean(y)
  @test λmax ≈ maximum(abs, X' * (logistic(log(ȳ / (1 - ȳ))) .- y) / n) rtol = 1e-10
  x0 = SparseIterate(p)
  solve!(x0, m, NormL1(λmax * (1 + 1e-8)), newton)
  @test nnz(x0) == 0
  @test ProximalSolvers.intercept(m, x0) ≈ log(ȳ / (1 - ȳ)) rtol = 1e-8

  # the solution: the optimality conditions of β and of the intercept
  λ = 0.1 * λmax
  x = SparseIterate(p)
  r = solve!(x, m, NormL1(λ), newton)
  b = ProximalSolvers.intercept(m, x)
  μ = logistic.(b .+ X * Vector(x))
  @test r.converged
  @test abs(sum(μ .- y)) / n < 1e-9
  @test kkt_l1(X' * (μ .- y) / n, Vector(x), λ) < 1e-7
  @test r.minimum ≈ f.α * sum(log1p.(exp.(b .+ X * Vector(x))) .- y .* (b .+ X * Vector(x))) + λ * norm(Vector(x), 1)
  # the linear predictor and the deviances of the model
  ηx = b .+ X * Vector(x)
  @test ProximalSolvers.linear_predictor(m) ≈ ηx
  @test ProximalSolvers.deviance(m) ≈ 2 * sum(log1p.(exp.(ηx)) .- y .* ηx)
  @test ProximalSolvers.nulldeviance(m) ≈ -2n * (ȳ * log(ȳ) + (1 - ȳ) * log(1 - ȳ))
  @test ProximalSolvers.linear_predictor(m) ≈ ηx          # untouched by nulldeviance

  # the same as a column of ones with a zero penalty weight
  x1 = SparseIterate(p + 1)
  solve!(x1, (1 / n) * LogisticLoss(y, [ones(n) X]), NormL1(λ, [0.0; ones(p)]), newton)
  @test x1[1] ≈ b atol = 1e-6
  @test Vector(x1)[2:end] ≈ Vector(x) atol = 1e-6

  # a warm start from the solution and its intercept takes one step
  r2 = solve!(x, m, NormL1(λ), newton)
  @test ProximalSolvers.intercept(m, x) ≈ b atol = 1e-10
  @test r2.passes <= r.passes

  # coordinate descent does not fit the intercept, nor take an unbounded curvature
  @test_throws ArgumentError solve!(SparseIterate(p), m, NormL1(λ), CDSolver())
  @test_throws ArgumentError solve!(SparseIterate(p), ProximalSolvers.cdmodel((1 / n) * PoissonLoss(y, X), x),
                                    NormL1(λ), CDSolver())

  # weights and an offset: integer weights give the solution on replicated rows
  wt = Float64.(rand(rng, 1:3, n)); o = 0.3 .* randn(rng, n)
  mw = ProximalSolvers.cdmodel((1 / sum(wt)) * LogisticLoss(y, X; weights = wt, offset = o), x; intercept = true)
  xw = SparseIterate(p)
  solve!(xw, mw, NormL1(λ), newton)
  idx = reduce(vcat, [fill(i, Int(wt[i])) for i in 1:n])
  mr = ProximalSolvers.cdmodel((1 / length(idx)) * LogisticLoss(y[idx], X[idx, :]; offset = o[idx]), x; intercept = true)
  xr = SparseIterate(p)
  solve!(xr, mr, NormL1(λ), newton)
  @test Vector(xw) ≈ Vector(xr) atol = 1e-6
  @test ProximalSolvers.intercept(mw, xw) ≈ ProximalSolvers.intercept(mr, xr) atol = 1e-6

  # Poisson with an intercept and an offset
  yp = Float64.(rand.(rng, [0:k for k in rand(rng, 0:5, n)]))
  op = 0.2 .* randn(rng, n)
  mp = ProximalSolvers.cdmodel((1 / n) * PoissonLoss(yp, X; offset = op), x; intercept = true)
  λp = 0.2 * lambda_max(mp, NormL1(1.0), SparseIterate(p))
  xp = SparseIterate(p)
  rp = solve!(xp, mp, NormL1(λp), newton)
  bp = ProximalSolvers.intercept(mp, xp)
  μp = exp.(bp .+ X * Vector(xp) .+ op)
  @test rp.converged
  @test abs(sum(μp .- yp)) / n < 1e-9
  @test kkt_l1(X' * (μp .- yp) / n, Vector(xp), λp) < 1e-7
  @test ProximalSolvers.deviance(mp) ≈ 2 * sum(yp .* log.(max.(yp, 1e-300) ./ μp) .- (yp .- μp))

  # a path: the solutions and intercepts satisfy the optimality conditions, and
  # screening gives the solutions of the path without it
  λs = λmax * (1 + 1e-8) .* exp.(range(0, log(0.05); length = 20))     # above λmax, so rounding can't make it nonzero
  b0s = Float64[]
  # gaptol = 0: the rule on the objective with the tight tol of newton, for near-exact optimality
  path = solve_path(ProximalSolvers.cdmodel(f, x; intercept = true), NormL1(1.0), λs, newton; devmax = 1.0,
                    gaptol = 0, callback = (k, λ, x, m) -> (push!(b0s, ProximalSolvers.intercept(m, x)); false))
  @test length(path.λ) == 20 && all(path.converged)
  @test nnz(path.solutions[1]) == 0
  for k in (2, 10, 20)
    βk = Vector(path.solutions[k])
    μk = logistic.(b0s[k] .+ X * βk)
    @test abs(sum(μk .- y)) / n < 1e-8
    @test kkt_l1(X' * (μk .- y) / n, βk, λs[k]) < 1e-6
  end
  @test all(path.kkt_checks .>= 1)
  path0 = solve_path(ProximalSolvers.cdmodel(f, x; intercept = true), NormL1(1.0), λs, newton; devmax = 1.0, gaptol = 0,
                     screening = false)
  @test all(norm(path.solutions[k] - path0.solutions[k]) < 1e-6 for k in eachindex(λs))
  @test path.values ≈ path0.values rtol = 1e-8
  # without an intercept, the path from a GLMLoss
  pathf = solve_path(f, NormL1(1.0), λs[5:end], newton; devmax = 1.0, gaptol = 0)
  xk = SparseIterate(p)
  solve!(xk, f, NormL1(λs[end]), newton)
  @test Vector(pathf.solutions[end]) ≈ Vector(xk) atol = 1e-6

  # the deviance stop: on separable data the logistic fit explains all the
  # deviance as λ decreases, and the path stops once 99.9% is explained
  ys = Float64.(X[:, 1] .+ 0.5 .* X[:, 2] .> 0)
  ms = ProximalSolvers.cdmodel((1 / n) * LogisticLoss(ys, X), x; intercept = true)
  λss = lambda_max(ms, NormL1(1.0), SparseIterate(p)) .* exp.(range(0, log(1e-6); length = 60))
  b0s = Float64[]
  ps = solve_path(ms, NormL1(1.0), λss, ProxNewton(; maxiter = 500);
                  callback = (k, λ, x, m) -> (push!(b0s, ProximalSolvers.intercept(m, x)); false))
  @test length(ps.λ) < 60
  ηs = b0s[end] .+ X * Vector(ps.solutions[end])
  devs = 2 * sum(log1p.(exp.(ηs)) .- ys .* ηs)
  ȳs = mean(ys)
  dev0 = -2n * (ȳs * log(ȳs) + (1 - ȳs) * log(1 - ȳs))
  @test 1 - devs / dev0 >= 0.999
  @test length(solve_path(ms, NormL1(1.0), λss[1:20], ProxNewton(); devmax = 1.0).λ) == 20

  # Float32
  m32 = ProximalSolvers.cdmodel((1 / n) * LogisticLoss(Float32.(y), Float32.(X)), SparseIterate(Float32, p);
                                intercept = true)
  x32 = SparseIterate(Float32, p)
  r32 = solve!(x32, m32, NormL1(Float32(λ)), ProxNewton(; tol = 1e-6, inner = CDSolver(; tol = 1e-6)))
  @test r32.converged && eltype(r32.minimum) == Float32
  @test Vector(x32) ≈ Vector(x) atol = 1e-3
end

@testset "proximal Newton with an intercept: columns centered when screening admits them" begin
  # Along a screened path, each Newton step centers only the candidates of the
  # strong rule; a column that a check of the optimality conditions adds is
  # centered from the next step on. Column 3 is correlated with column 1 but
  # orthogonal to the weighted residuals of the fit with the intercept alone,
  # so its gradient is zero at λmax and the strong rule leaves it out at the
  # next level. Its small penalty weight then makes it violate the optimality
  # conditions there once column 1 enters: it enters through the check.
  rng = Xoshiro(11)
  n, p = 150, 40
  X = randn(rng, n, p)
  y = Float64.(rand(rng, n) .< logistic.(0.4 .+ 2.0 .* X[:, 1] .- 0.7 .* X[:, 2]))
  wt = Float64.(rand(rng, 1:3, n))
  d = wt .* (y .- sum(wt .* y) / sum(wt))
  u = X[:, 1] .+ 0.5 .* randn(rng, n)
  X[:, 3] .= u .- (dot(u, d) / dot(d, d)) .* d
  X[:, 4] .= 2.0                                   # a constant column
  ω = ones(p); ω[3] = 0.02
  g = NormL1(1.0, ω)
  newton = ProxNewton(; tol = 1e-14, inner = CDSolver(; tol = 1e-10, rng = Xoshiro(1)))
  gradient(A, β, b) = A' * (wt .* (logistic.(b .+ A * β) .- y)) / sum(wt)

  for A in (X, sparse(X))
    f = (1 / sum(wt)) * LogisticLoss(y, A; weights = wt)
    λmax = lambda_max(ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true), g, SparseIterate(p))
    λs = λmax * (1 + 1e-8) .* [1.0, 0.9, 0.7, 0.5, 0.3]
    paths = map((true, false)) do screening
      b0s = Float64[]
      # gaptol = 0: the rule on the objective with tol = 1e-14, for near-exact solutions to compare
      path = solve_path(ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true), g, λs, newton; devmax = 1.0,
                        gaptol = 0, screening, callback = (k, λ, x, m) -> (push!(b0s, ProximalSolvers.intercept(m, x)); false))
      (path = path, b0s = b0s)
    end
    path, b0s = paths[1]
    @test length(path.λ) == length(λs) && all(path.converged)
    # column 3 enters at the second level, through the check
    @test nnz(path.solutions[1]) == 0 && path.solutions[2][3] != 0
    @test abs(gradient(A, Vector(path.solutions[1]), b0s[1])[3]) < (2λs[2] - λs[1]) * ω[3]
    @test path.kkt_checks[2] >= 2
    # the solutions satisfy the optimality conditions of β and of the intercept,
    # and agree with those of the path without screening, which centers every
    # column at every step
    for k in eachindex(λs)
      βk = Vector(path.solutions[k])
      μk = logistic.(b0s[k] .+ A * βk)
      @test abs(sum(wt .* (μk .- y))) / sum(wt) < 1e-10
      @test kkt_l1(gradient(A, βk, b0s[k]) ./ ω, βk, λs[k]) < 1e-8
      @test norm(path.solutions[k] - paths[2].path.solutions[k]) < 1e-9
      @test b0s[k] ≈ paths[2].b0s[k] atol = 1e-9
    end
    @test path.values ≈ paths[2].path.values rtol = 1e-12
  end

  # the means themselves: a step centers the candidates at its weights, the
  # constant column at its value exactly, and leaves the other columns alone
  # until a later call admits them
  f = (1 / sum(wt)) * LogisticLoss(y, X; weights = wt)
  λl = 0.5 * lambda_max(ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true), g, SparseIterate(p))
  gl = NormL1(λl, ω)
  means(ws, cols) = X[:, cols]' * ws.v ./ sum(ws.v)
  m = ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true)
  x = SparseIterate(p)
  ProximalSolvers.initialize!(m, x)
  ws = ProximalSolvers._NewtonWorkspace(m, x, newton.inner)
  ProximalSolvers._proxnewton!(x, m, gl, newton, ws, [1, 2, 4])
  @test ws.model.xbar[[1, 2]] ≈ means(ws, [1, 2]) atol = 1e-12
  @test ws.model.xbar[4] == 2.0
  @test all(iszero, ws.model.xbar[[3; 5:p]])
  ProximalSolvers._proxnewton!(x, m, gl, newton, ws, [1, 2, 3, 4])
  @test ws.model.xbar[[1, 2, 3]] ≈ means(ws, [1, 2, 3]) atol = 1e-12
  @test all(iszero, ws.model.xbar[5:p])
  # the solution over the candidates, with its intercept
  β, b = Vector(x), ProximalSolvers.intercept(m, x)
  @test β[3] != 0
  @test abs(sum(wt .* (logistic.(b .+ X * β) .- y))) / sum(wt) < 1e-10
  @test kkt_l1(gradient(X, β, b)[1:4] ./ ω[1:4], β[1:4], λl) < 1e-8
  # centering allocates nothing, over some columns or all of them
  centerbytes(ws, cols) = @allocated ProximalSolvers._center!(ws, cols)
  cols = [1, 2, 3, 4]
  centerbytes(ws, cols); centerbytes(ws, nothing)
  @test centerbytes(ws, cols) == 0
  @test centerbytes(ws, nothing) == 0
  # the duality gaps of gaptol and gapsafe in the inner solves are those of the
  # problem restricted to the candidates, which read only their means; every
  # column with candidates for more than half of the columns of a dense X
  others = [k for k in 1:p if k != 4]
  for (inner, cand, cols) in ((CDSolver(; tol = 1e-10, gapsafe = true, rng = Xoshiro(1)), [1, 2, 4], [1, 2]),
                              (CDSolver(; gaptol = 1e-10, rng = Xoshiro(1)), [1, 2, 4], [1, 2]),
                              (newton.inner, collect(1:div(p, 2) + 1), others))
    method = ProxNewton(; tol = 1e-14, inner)
    m = ProximalSolvers.cdmodel(f, SparseIterate(p); intercept = true)
    x = SparseIterate(p)
    ProximalSolvers.initialize!(m, x)
    ws = ProximalSolvers._NewtonWorkspace(m, x, method.inner)
    ProximalSolvers._proxnewton!(x, m, gl, method, ws, cand)
    @test ws.model.xbar[cols] ≈ means(ws, cols) atol = 1e-12
    @test ws.model.xbar[4] == 2.0
    cols === others || @test all(iszero, ws.model.xbar[setdiff(others, cols)])
    β, b = Vector(x), ProximalSolvers.intercept(m, x)
    @test kkt_l1(gradient(X, β, b)[cand] ./ ω[cand], β[cand], λl) < 1e-7
  end
end

end
