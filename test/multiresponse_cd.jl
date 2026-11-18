module MultiresponseCD
# Matrix-response group-lasso coordinate descent (#396): `solve!(B::Matrix, f, g::GroupNormL2, CDSolver(...))` with the
# loss (s/2)‖Y − XB‖_F² and the row groups of B minimizes (s/2)‖Y − XB‖_F² + λ0 Σⱼ wⱼ ‖B[j, :]‖₂ from the original X and
# Y. The references are computed from the stored X, Y and the penalty, not from the solver's caches or formulas:
#  * an independent objective, in BigFloat (256 bits);
#  * an independent row-wise KKT check in Float64, with G = s Xᵀ(XB − Y): for a penalized row with B[j, :] ≠ 0 the
#    stationarity ‖G[j, :] + λ0 wⱼ B[j, :]/‖B[j, :]‖‖, for a penalized row at 0 the excess max(‖G[j, :]‖ − λ0 wⱼ, 0),
#    for an unpenalized row (λ0 wⱼ = 0) the norm ‖G[j, :]‖;
#  * λmax = s max_j ‖(XᵀY)[j, :]‖/wⱼ, at and above which B = 0 is the solution;
#  * the analytic row soft threshold for XᵀX = n I;
#  * the Kronecker formulation (the stacked design I ⊗ X with vec(Y)) through the existing vector BlockIterate path,
#    and the scalar lasso for one response, both as references.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
using Logging: with_logger, Warn
const PS = ProximalSolvers

# ---------------------------------------------------------------------------
# Tolerances and fixtures
# ---------------------------------------------------------------------------
const TYPES = (Float32, Float64)
# the residual of the independent KKT check, relative to λ0 max(w) + ‖G‖
kkt_bound(::Type{T}) where T = T === Float64 ? 1e-8 : 1e-4
solve_tol(::Type{T}) where T = T === Float64 ? 1e-12 : 1e-6
pass_limit(::Type{T}) where T = T === Float64 ? 100_000 : 20_000
# difference of two solutions of a strictly convex problem, relative to max(1, ‖B‖_F)
coef_rtol(::Type{T}) where T = T === Float64 ? 1e-8 : 1e-4

rowgroups(p, K) = [collect(j:p:p*K) for j in 1:p]
mkloss(Y, X, α) = α === nothing ? LeastSquaresLoss(Y, X) : α * LeastSquaresLoss(Y, X)
sval(α) = α === nothing ? 1.0 : Float64(α)
# the row-group penalty at level λ with the default weights √K or the weights w
penalty(::Type{T}, λ, p, K, w = nothing) where T =
  w === nothing ? GroupNormL2(T(λ), rowgroups(p, K)) : GroupNormL2(T(λ), rowgroups(p, K), T.(w))

# A seeded problem: the columns of X have the correlation ρ^|i − j|, the first `active` rows of B0 are nonzero, and
# Y = X B0 + noise.
function correlated(::Type{T}; n = 40, p = 8, K = 3, ρ = 0.5, seed = 1, active = 3, noise = 0.5) where T
  rng = Xoshiro(seed)
  Σ = [ρ^abs(i - j) for i in 1:p, j in 1:p]
  X = randn(rng, n, p) * cholesky(Symmetric(Σ)).U
  B0 = zeros(p, K)
  B0[1:active, :] .= randn(rng, active, K)
  Y = X*B0 .+ noise .* randn(rng, n, K)
  Matrix{T}(X), Matrix{T}(Y)
end

# The result of f() and its log records.
function logged(f)
  logger = Test.TestLogger()
  r = with_logger(f, logger)
  r, logger.logs
end
warned(logs) = length(logs) == 1 && logs[1].level == Warn && occursin("did not converge", string(logs[1].message))

# ---------------------------------------------------------------------------
# Independent references
# ---------------------------------------------------------------------------
# The objective (s/2)‖Y − XB‖_F² + λ0 Σⱼ wⱼ ‖B[j, :]‖ in BigFloat from the stored data and the penalty
function objective_big(X, Y, s, g, B)
  setprecision(BigFloat, 256) do
    Xr, Yr, Br = BigFloat.(X), BigFloat.(Y), BigFloat.(B)
    r = Yr - Xr*Br
    pen = zero(BigFloat)
    for j in axes(B, 1)
      pen += BigFloat(g.λ0)*BigFloat(g.w[j])*sqrt(sum(abs2, Br[j, :]))
    end
    Float64(BigFloat(s)/2*sum(abs2, r) + pen)
  end
end
# the scale (s/2)‖Y‖² + penalty at B against which a difference of objectives is measured
objective_scale(X, Y, s, g, B) = s/2*sum(abs2, Float64.(Y)) + objective_big(X, Y, 0.0, g, B) + 1e-300

# The independent row-wise KKT of B. `stat` is the largest stationarity of a penalized row with B[j, :] ≠ 0 or of an
# unpenalized row, `screen` the largest excess max(‖G[j, :]‖ − λ0 wⱼ, 0) of a penalized row at 0, and `scale` is
# λ0 max(w) + ‖G‖_F.
function kkt_report(X, Y, s, g, B)
  Xd, Yd, Bd = Float64.(X), Float64.(Y), Float64.(B)
  G = s .* (Xd' * (Xd*Bd .- Yd))
  λ = Float64(g.λ0)
  stat, screen = 0.0, 0.0
  for j in axes(Bd, 1)
    c = λ*Float64(g.w[j])
    gj, bj = G[j, :], Bd[j, :]
    if iszero(c)
      stat = max(stat, norm(gj))
    elseif all(iszero, bj)
      screen = max(screen, norm(gj) - c)
    else
      stat = max(stat, norm(gj .+ (c/norm(bj)) .* bj))
    end
  end
  (; stat, screen, scale = λ*maximum(Float64, g.w) + norm(G))
end

# λmax = max over the rows with wⱼ > 0 of ‖s (XᵀY)[j, :]‖/wⱼ: at λ0 ≥ λmax with all weights positive, B = 0 is
# optimal, because the gradient of the loss at 0 is −s XᵀY.
function lambda_max(X, Y, s, w)
  G0 = s .* (Float64.(X)' * Float64.(Y))
  maximum(j -> norm(G0[j, :]) / Float64(w[j]), filter(j -> w[j] > 0, eachindex(w)))
end

# The independent checks of a finished solve: the KKT residual, the result's fields and its reported minimum.
function check_solution(X, Y, α, g, B, res; converged = true)
  T = eltype(X)
  s = sval(α)
  n, p = size(X)
  K = size(Y, 2)
  rep = kkt_report(X, Y, s, g, B)
  @test rep.stat <= kkt_bound(T) * rep.scale
  @test rep.screen <= kkt_bound(T) * rep.scale
  @test res.minimizer === B
  @test B isa Matrix{T}
  @test typeof(res) == CDResults{typeof(B), T}
  @test res.kkt_checks == 0
  @test isnan(res.gap)
  @test res.passes >= 1
  if converged
    @test res.converged
    @test res.maxchange < res.tolerance
  end
  obj = objective_big(X, Y, s, g, B)
  @test abs(Float64(res.minimum) - obj) <= 16 * (n + p) * K * eps(T) * objective_scale(X, Y, s, g, B)
  rep
end

# A solve that converges without a warning, on B in place.
function run_solve(X, Y, α, g, B; order = :cyclic, tol = solve_tol(eltype(X)), maxpasses = pass_limit(eltype(X)), seed = 3)
  method = CDSolver(; order, momentum = false, tol, maxpasses, rng = Xoshiro(seed))
  res, logs = logged(() -> solve!(B, mkloss(Y, X, α), g, method))
  @test isempty(logs)
  res
end

# solve! throws an exception of type E whose message contains the fragment, B keeps its bits (signed zeros and NaNs
# included) and the RNG is not used.
function refused(E, fragment, B, f, g; momentum = nothing, method = nothing)
  before = copy(B)
  rng = Xoshiro(11)
  rng_before = copy(rng)
  m = method === nothing ? CDSolver(; order = :random, momentum, maxpasses = 100, rng) : method
  err = try
    solve!(B, f, g, m)
    nothing
  catch e
    e
  end
  @test err isa E
  @test err !== nothing && occursin(fragment, sprint(showerror, err))
  @test isequal(B, before)
  @test rng == rng_before
end

# A small problem (4 × 3, two responses) whose column 2 has a curvature that `solve!` refuses before the first pass,
# with the loss scale α and the fragment of the message. The values are powers of 2, so the sums are exact.
function curvature_case(::Type{T}, kind::Symbol) where T
  n, p, K = 4, 3, 2
  rng = Xoshiro(21)
  X = Matrix{T}(randn(rng, n, p))
  Y = Matrix{T}(randn(rng, n, K))
  f32 = T === Float32
  α, fragment = nothing, ""
  if kind === :overflow          # the squares overflow
    X[:, 2] .= ldexp(one(T), f32 ? 65 : 513)
    fragment = "row 2 (the squared norm of column 2 of X) is not finite"
  elseif kind === :underflow     # the squares are subnormal and their sum is below floatmin
    X[:, 2] .= ldexp(one(T), f32 ? -66 : -514)
    fragment = "row 2 (the squared norm of column 2 of X) is below floatmin"
  elseif kind === :band_low      # the curvature is normal, the loss scale times it is below floatmin
    X[:, 2] .= ldexp(one(T), f32 ? -63 : -511)
    α = ldexp(one(T), -4)
    fragment = "step of group 2"
  else                           # the curvature is normal, the loss scale times it overflows
    X[:, 2] .= ldexp(one(T), f32 ? 30 : 250)
    α = ldexp(one(T), f32 ? 70 : 600)
    fragment = "step of group 2"
  end
  X, Y, α, fragment
end
# the squared norm of column j of X, summed in order in T
sqnorm(X, j) = foldl((a, v) -> a + v*v, view(X, :, j); init = zero(eltype(X)))

@testset "multiresponse_cd" begin

for T in TYPES
  X, Y = correlated(T)
  n, p = size(X)
  K = size(Y, 2)
  w_supplied = [1.0, 0.0, 2.0, 0.5, 1.0, 3.0, 1.0, 0.25]    # a zero weight leaves row 2 unpenalized

  @testset "row-wise KKT and objective ($T)" begin
    for (α, weights) in ((nothing, nothing), (1/n, nothing), (T(1/n), nothing), (1/n, w_supplied), (nothing, w_supplied))
      s = sval(α)
      g0 = penalty(T, 1.0, p, K, weights)
      @test all(g0.w .== (weights === nothing ? fill(sqrt(T(K)), p) : T.(weights)))
      λ = 0.5 * lambda_max(X, Y, s, g0.w)
      g = penalty(T, λ, p, K, weights)
      for order in (:cyclic, :random)
        B = zeros(T, p, K)
        res = run_solve(X, Y, α, g, B; order)
        rep = check_solution(X, Y, α, g, B, res)
        # the reported tolerance is the change threshold tol √(s ‖Y‖²) in T
        @test isapprox(Float64(res.tolerance), solve_tol(T) * sqrt(s * sum(abs2, Float64.(Y))); rtol = 1e-4)
        zero_rows = count(j -> all(iszero, B[j, :]), 1:p)
        @test 0 < zero_rows < p
      end
    end
  end

  @testset "λmax: zero at the threshold, a nonzero row below it ($T)" begin
    for α in (nothing, 1/n)
      s = sval(α)
      w = Float64.(penalty(T, 1.0, p, K).w)
      λmax = lambda_max(X, Y, s, w)
      g = penalty(T, 1.001*λmax, p, K)
      B = zeros(T, p, K)
      res = run_solve(X, Y, α, g, B)
      @test all(iszero, B)
      check_solution(X, Y, α, g, B, res)
      g = penalty(T, 0.9*λmax, p, K)
      B = zeros(T, p, K)
      res = run_solve(X, Y, α, g, B)
      @test any(!iszero, B)
      check_solution(X, Y, α, g, B, res)
    end
  end

  @testset "orthogonal design: the analytic row soft threshold ($T)" begin
    n0, p0, K0 = 8, 5, 3
    H = [1 1; 1 -1]
    H = kron(H, kron(H, H))                        # a Hadamard matrix: HᵀH = 8 I
    X0 = Matrix{T}(H[:, 1:p0])
    Y0 = Matrix{T}(randn(Xoshiro(5), n0, K0))
    z = (Float64.(X0)' * Float64.(Y0)) ./ n0       # the least-squares solution, XᵀX = n0 I
    w = Float64.(penalty(T, 1.0, p0, K0).w)
    ratios = sort([norm(z[j, :]) / w[j] for j in 1:p0])
    λ = T((ratios[2] + ratios[3]) / 2)             # two rows are thresholded to 0 and three are shrunk
    g = penalty(T, λ, p0, K0)
    α = T(1/n0)
    B = zeros(T, p0, K0)
    res = run_solve(X0, Y0, α, g, B)
    Bref = zeros(p0, K0)
    for j in 1:p0
      Bref[j, :] = max(0.0, 1 - Float64(λ)*w[j]/norm(z[j, :])) .* z[j, :]
    end
    @test count(j -> all(iszero, Bref[j, :]), 1:p0) == 2
    @test norm(Float64.(B) - Bref) <= 64 * eps(T) * max(1, norm(Bref))
    check_solution(X0, Y0, α, g, B, res)
  end

  @testset "columns of different scale ($T)" begin
    Xs = X .* T.(10.0 .^ range(-1, 1; length = p))'
    g0 = penalty(T, 1.0, p, K)
    for α in (nothing, 1/n)
      λ = 0.3 * lambda_max(Xs, Y, sval(α), g0.w)
      g = penalty(T, λ, p, K)
      B = zeros(T, p, K)
      res = run_solve(Xs, Y, α, g, B)
      check_solution(Xs, Y, α, g, B, res)
      @test any(!iszero, B)
    end
  end

  @testset "nonzero warm start ($T)" begin
    α = 1/n
    g0 = penalty(T, 1.0, p, K)
    g = penalty(T, 0.3 * lambda_max(X, Y, α, g0.w), p, K)
    Bcold = zeros(T, p, K)
    run_solve(X, Y, α, g, Bcold)
    B0 = Matrix{T}(randn(Xoshiro(9), p, K))
    B = copy(B0)
    res = run_solve(X, Y, α, g, B)
    check_solution(X, Y, α, g, B, res)
    @test norm(Float64.(B) - Float64.(Bcold)) <= coef_rtol(T) * max(1, norm(Float64.(Bcold)))
    # a start at the solution stays at it
    B2 = copy(Bcold)
    res2 = run_solve(X, Y, α, g, B2)
    check_solution(X, Y, α, g, B2, res2)
    @test norm(Float64.(B2) - Float64.(Bcold)) <= coef_rtol(T) * max(1, norm(Float64.(Bcold)))
  end

  @testset "agreement with the Kronecker formulation ($T)" begin
    α = 1/n
    g0 = penalty(T, 1.0, p, K)
    g = penalty(T, 0.3 * lambda_max(X, Y, α, g0.w), p, K)
    B = zeros(T, p, K)
    res = run_solve(X, Y, α, g, B)
    # the reference: the stacked design I ⊗ X and vec(Y), solved through the vector BlockIterate path
    Xk = kron(Matrix{T}(I, K, K), X)
    xk = BlockIterate(T, p*K, g)
    method = CDSolver(order = :cyclic, momentum = false, tol = solve_tol(T), maxpasses = pass_limit(T))
    rk, logs = logged(() -> solve!(xk, mkloss(vec(Y), Xk, α), g, method))
    @test isempty(logs) && rk.converged
    Bk = reshape(Vector(xk), p, K)
    @test norm(Float64.(B) - Float64.(Bk)) <= coef_rtol(T) * max(1, norm(Float64.(Bk)))
    @test abs(Float64(res.minimum) - Float64(rk.minimum)) <= 16 * (n + p) * K * eps(T) * objective_scale(X, Y, α, g, B)
  end

  @testset "one response is the lasso ($T)" begin
    α = 1/n
    Y1 = Y[:, 1:1]
    λ = 0.3 * lambda_max(X, Y1, α, ones(p))
    g = penalty(T, λ, p, 1)
    B = zeros(T, p, 1)
    res = run_solve(X, Y1, α, g, B)
    check_solution(X, Y1, α, g, B, res)
    x = zeros(T, p)
    method = CDSolver(order = :cyclic, momentum = false, tol = solve_tol(T), maxpasses = pass_limit(T))
    solve!(x, mkloss(Y[:, 1], X, α), NormL1(T(λ)), method)
    @test norm(Float64.(B[:, 1]) - Float64.(x)) <= coef_rtol(T) * max(1, norm(Float64.(x)))
  end

  @testset "a zero column of X ($T)" begin
    Xz = copy(X)
    Xz[:, 2] .= 0
    α = 1/n
    g0 = penalty(T, 1.0, p, K)
    λ = 0.3 * lambda_max(Xz, Y, α, g0.w)
    B0 = Matrix{T}(randn(Xoshiro(2), p, K))
    # a positive level and weight: the row is 0 from a nonzero start
    B = copy(B0)
    res = run_solve(Xz, Y, α, penalty(T, λ, p, K), B)
    @test all(iszero, B[2, :])
    check_solution(Xz, Y, α, penalty(T, λ, p, K), B, res)
    # a zero weight: the loss does not depend on the row, and the row keeps its start
    w = ones(p)
    w[2] = 0.0
    g = penalty(T, λ, p, K, w)
    B = copy(B0)
    res = run_solve(Xz, Y, α, g, B)
    @test isequal(B[2, :], B0[2, :])
    check_solution(Xz, Y, α, g, B, res)
  end

  @testset "ownership, the BlockIterate route and incomplete runs ($T)" begin
    α = 1/n
    f = mkloss(Y, X, α)
    g0 = penalty(T, 1.0, p, K)
    g = penalty(T, 0.3 * lambda_max(X, Y, α, g0.w), p, K)
    B0 = Matrix{T}(randn(Xoshiro(4), p, K))
    B = copy(B0)
    res = run_solve(X, Y, α, g, B)
    @test res.minimizer === B && B isa Matrix{T}
    # the same loss and penalty on a BlockIterate over vec(B) with the same start
    x = BlockIterate(vec(copy(B0)), g.groups)
    method = CDSolver(order = :cyclic, momentum = false, tol = solve_tol(T), maxpasses = pass_limit(T))
    resx, logs = logged(() -> solve!(x, f, g, method))
    @test isempty(logs) && resx.converged && resx.minimizer === x
    Bx = reshape(Vector(x), p, K)
    rep = kkt_report(X, Y, α, g, Bx)
    @test rep.stat <= kkt_bound(T) * rep.scale && rep.screen <= kkt_bound(T) * rep.scale
    @test norm(Float64.(B) - Float64.(Bx)) <= coef_rtol(T) * max(1, norm(Float64.(Bx)))
    @test abs(Float64(res.minimum) - Float64(resx.minimum)) <= 16 * (n + p) * K * eps(T) * objective_scale(X, Y, α, g, B)
    # maxpasses = 0 visits nothing: B keeps its start and the minimum is the objective there
    B = copy(B0)
    res0, logs = logged(() -> solve!(B, f, g, CDSolver(order = :cyclic, momentum = false, maxpasses = 0)))
    @test isequal(B, B0) && res0.minimizer === B && res0.passes == 0 && !res0.converged && warned(logs)
    @test abs(Float64(res0.minimum) - objective_big(X, Y, α, g, B0)) <= 16 * (n + p) * K * eps(T) * objective_scale(X, Y, α, g, B0)
    # a run that stops at maxpasses is complete: B receives its final point and the warning is issued
    B = zeros(T, p, K)
    res1, logs = logged(() -> solve!(B, f, g, CDSolver(order = :cyclic, momentum = false, tol = solve_tol(T), maxpasses = 1)))
    @test res1.passes == 1 && !res1.converged && warned(logs) && res1.minimizer === B
    @test any(!iszero, B) && all(isfinite, B)
    @test abs(Float64(res1.minimum) - objective_big(X, Y, α, g, B)) <= 16 * (n + p) * K * eps(T) * objective_scale(X, Y, α, g, B)
  end

  @testset "refusals leave B and the RNG as they were ($T)" begin
    f = mkloss(Y, X, 1/n)
    g = penalty(T, 0.1, p, K)
    zerosB() = zeros(T, p, K)
    opposite = T === Float32 ? Float64 : Float32
    @test PS._check_matrix_problem(zerosB(), f, g, CDSolver(order = :cyclic, momentum = false)) === nothing
    # shapes
    refused(DimensionMismatch, "B is", zeros(T, p, K + 1), f, g)
    refused(DimensionMismatch, "B is", zeros(T, K, p), f, g)
    # groups that are not the rows of B, in order
    columns = [collect((c - 1)*p + 1:c*p) for c in 1:K]
    refused(DimensionMismatch, "groups but B has", zerosB(), f, GroupNormL2(T(0.1), columns))
    refused(DimensionMismatch, "groups but B has", zerosB(), f, GroupNormL2(T(0.1), rowgroups(p, K)[1:end-1]))
    refused(DimensionMismatch, "group 1 of the penalty is not row 1", zerosB(), f, GroupNormL2(T(0.1), reverse(rowgroups(p, K))))
    refused(DimensionMismatch, "group 1 of the penalty is not row 1", zerosB(), f,
            GroupNormL2(T(0.1), [collect((j - 1)*K + 1:j*K) for j in 1:p]))
    # a square B, where the columns are as many as the rows
    Xq = X[:, 1:3]
    refused(DimensionMismatch, "group 1 of the penalty is not row 1", zeros(T, 3, 3), mkloss(Y, Xq, 1/n),
            GroupNormL2(T(0.1), [collect(1:3), collect(4:6), collect(7:9)]))
    # momentum
    refused(ArgumentError, "momentum", zerosB(), f, g; momentum = true)
    # penalty
    refused(ArgumentError, "GroupNormL2", zerosB(), f, NormL1(T(0.1)))
    refused(ArgumentError, "GroupNormL2", zerosB(), f, ElasticNet(T(0.1), T(0.2)))
    refused(ArgumentError, "GroupNormL2", zerosB(), f, GroupNormL2(Float16(0.1), rowgroups(p, K)))
    refused(ArgumentError, "penalty lambda", zerosB(), f, GroupNormL2(Inf, rowgroups(p, K)))
    refused(ArgumentError, "group weight 2", zerosB(), f, GroupNormL2(T(0.1), rowgroups(p, K), T[1, Inf, 1, 1, 1, 1, 1, 1]))
    # other solvers and other loss shapes
    refused(ArgumentError, "dense Vector", zerosB(), f, g; method = ProximalGradientDescent())
    refused(ArgumentError, "dense Vector", zerosB(), f, g; method = AccProxGradDescent())
    refused(ArgumentError, "dense Vector", zerosB(), mkloss(Y[:, 1], X, 1/n), g)
    refused(ArgumentError, "dense Vector", zerosB(), SqrtLeastSquaresLoss(Y[:, 1], X), g)
    # element types and sparse designs
    refused(ArgumentError, "must be Matrix", zerosB(), mkloss(opposite.(Y), X, 1/n), g)
    refused(ArgumentError, "must be Matrix", zerosB(), mkloss(Y, sparse(X), 1/n), g)
    refused(ArgumentError, "must be Matrix", zeros(opposite, p, K), f, g)
    refused(ArgumentError, "Matrix{Float32} or Matrix{Float64}", zeros(Int, p, K), f, g)
    # nonfinite values
    Yn = copy(Y)
    Yn[1, 1] = T(NaN)
    refused(ArgumentError, "finite", zerosB(), mkloss(Yn, X, 1/n), g)
    Xn = copy(X)
    Xn[2, 3] = T(Inf)
    refused(ArgumentError, "finite", zerosB(), mkloss(Y, Xn, 1/n), g)
    Bn = zerosB()
    Bn[1] = T(NaN)
    refused(ArgumentError, "finite", Bn, f, g)
    # B aliasing X or Y
    Xa = Matrix{T}(randn(Xoshiro(1), 4, 4))
    Ya = Matrix{T}(randn(Xoshiro(2), 4, 4))
    refused(ArgumentError, "alias", Xa, mkloss(Ya, Xa, 1/4), penalty(T, 0.1, 4, 4))
    refused(ArgumentError, "alias", Ya, mkloss(Ya, Xa, 1/4), penalty(T, 0.1, 4, 4))
    # B sharing memory with the scratch that evaluating the loss writes (`f.tmp`, `f.f.tmp` for a scaled loss). The
    # response is large enough for the objective to overflow, so that an unchecked solve would write 0 into the
    # scratch, and then throw, with B changed
    big = T === Float32 ? T(1e30) : T(1e200)
    for α in (nothing, T(0.5))
      floss = LeastSquaresLoss(fill(big, 1, 1), zeros(T, 1, 1))
      Bs = floss.tmp
      fill!(Bs, T(7))
      refused(ArgumentError, "scratch of the loss", Bs, α === nothing ? floss : α * floss, GroupNormL2(T(1), [[1]]);
              method = CDSolver(maxpasses = 0, relative = false))
      @test all(==(T(7)), Bs)
    end
    # B sharing memory with the penalty weights (one response, one row)
    gw = GroupNormL2(T(1), [[1]], T[1])
    Bw = reshape(gw.w, 1, 1)
    refused(ArgumentError, "penalty weights", Bw, mkloss(fill(T(-3), 1, 1), ones(T, 1, 1), nothing), gw)
    @test gw.w == T[1] && Bw == fill(T(1), 1, 1)
    # a curvature or a step outside the normal range of T, refused before the first pass
    for kind in (:overflow, :underflow, :band_low, :band_high)
      Xc, Yc, αc, fragment = curvature_case(T, kind)
      a = sqnorm(Xc, 2)
      kind === :overflow && @test isinf(a)
      kind === :underflow && @test 0 < a < floatmin(T)
      kind === :band_low && @test floatmin(T) <= a && αc*a < floatmin(T)
      kind === :band_high && @test isfinite(a) && isinf(αc*a)
      refused(ArgumentError, fragment, zeros(T, 3, 2), mkloss(Yc, Xc, αc), penalty(T, 0.1, 3, 2))
    end
  end

  @testset "no Kronecker design is formed ($T)" begin
    n1, p1, K1 = 200, 50, 8
    X1, Y1 = correlated(T; n = n1, p = p1, K = K1, active = 5)
    α = 1/n1
    g0 = penalty(T, 1.0, p1, K1)
    g = penalty(T, 0.2 * lambda_max(X1, Y1, α, g0.w), p1, K1)
    f = mkloss(Y1, X1, α)
    method = CDSolver(order = :cyclic, momentum = false, tol = T === Float64 ? 1e-8 : 1e-5, maxpasses = pass_limit(T))
    solve!(zeros(T, p1, K1), f, g, method)          # compiles
    B = zeros(T, p1, K1)
    bytes = @allocated solve!(B, f, g, method)
    design = n1*K1*p1*K1*sizeof(Float64)            # one nK × pK design in Float64
    @test design > 4_000_000
    @test bytes < design ÷ 8
    rep = kkt_report(X1, Y1, α, g, B)
    @test rep.stat <= kkt_bound(T) * rep.scale && rep.screen <= kkt_bound(T) * rep.scale
    @test any(!iszero, B)
  end
end

end # @testset "multiresponse_cd"

end
