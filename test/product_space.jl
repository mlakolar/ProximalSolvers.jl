module ProductSpaceTest

using Test
using Random
using LinearAlgebra
using Statistics
using ProximalBase
using ProximalSolvers

# The fused graphical lasso penalty λ₁(‖A‖₁ + ‖B‖₁) + λ₂‖A - B‖₁ on a pair of
# matrices, with the diagonal left out of the λ₁ term, entry by entry through
# the closed form of NormL1Fused
struct PairFused{T} <: AbstractFunction
  λ1::T
  λ2::T
end
ProximalBase.isproximable(::Type{<:PairFused}) = true
ProximalBase.isconvex(::Type{<:PairFused}) = true

function (f::PairFused)(x::Tuple)
  A, B = x
  v = zero(eltype(A))
  for j in axes(A, 2), i in axes(A, 1)
    v += (i == j ? 0 : f.λ1) * (abs(A[i, j]) + abs(B[i, j])) + f.λ2 * abs(A[i, j] - B[i, j])
  end
  v
end

function ProximalBase.prox!(y::Tuple, f::PairFused, x::Tuple, γ::Real)
  (A, B), (U, V) = x, y
  for j in axes(A, 2), i in axes(A, 1)
    h = NormL1Fused(i == j ? zero(f.λ1) : f.λ1, f.λ2)
    U[i, j], V[i, j] = prox(h, (A[i, j], B[i, j]), γ)
  end
  y
end

ProximalBase.value_and_prox!(y::Tuple, f::PairFused, x::Tuple, γ::Real) = (prox!(y, f, x, γ); f(y))

# the sum of the Euclidean norms of the blocks, with a method for the difference
# of two tuples
struct BlockNorm end
(::BlockNorm)(x::Tuple) = sum(LinearAlgebra.norm, x)
(::BlockNorm)(x::Tuple, y::Tuple) = sum(map(norm_diff, x, y))

solvers = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

# A bound on the rounding error of one Float64 evaluation of F(x) = ½ xᵀAx + bᵀx + λ‖x‖₁ at
# any point with |x| ≤ a entrywise, for any order of its sums: the standard model
# |fl(Σᵢ aᵢ) - Σᵢ aᵢ| ≤ γₘ Σᵢ |aᵢ| with γₘ = m u / (1 - m u) (Higham, Accuracy and Stability of
# Numerical Algorithms, 2nd ed., §3.1). Ax and xᵀ(Ax) round each term at most 2p times, bᵀx and
# λ‖x‖₁ at most p + 1 times, and the three sums add three roundings.
_γ64(m) = (u = eps(Float64) / 2; m * u / (1 - m * u))
_objective_error(A, b, λ, a) =
  _γ64(2length(a) + 3) * (dot(a, abs.(A) * a) / 2 + dot(abs.(b), a) + λ * sum(a))

@testset "a tuple of one array is the array $(summary(method))" for method in (solvers..., ProximalGradientDescent(; normalized = true))
  rng = Xoshiro(1)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  A, b, λ = X'X / n, -X'y / n, 0.05
  f, g = QuadraticFunction(A, b), NormL1(λ)
  opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 2000)
  x = zeros(p)
  r1 = solve!(x, f, g, method, opt)
  xt = (zeros(p),)
  r2 = solve!(xt, SeparableSum(f), SeparableSum(g), method, opt)
  @test r2.minimizer === xt
  @test x == xt[1]
  @test (r1.iterations, r1.minimum, r1.f_calls, r1.prox_calls) == (r2.iterations, r2.minimum, r2.f_calls, r2.prox_calls)
  @test (r1.x_residual, r1.g_residual) == (r2.x_residual, r2.g_residual)
  # f_residual = |F(xₖ) - F(xₖ₋₁)| / (|F(xₖ)| + ftol) for F = f + g. The two solves take the
  # same iterates, but evaluate F by differently compiled code, whose sums can be associated
  # differently; on some AMD EPYC runners without coverage F(xₖ₋₁) differed by one ulp, so
  # f_residual by 1.2e-16 (#121). F(xₖ) is the minimum, bitwise equal above, so only the two
  # evaluations of F(xₖ₋₁) differ, each within the bound at a = |xₖ| + x_residual ≥ |xₖ₋₁|
  # (x_residual = ‖xₖ - xₖ₋₁‖₂ here, without a preconditioner).
  bound = 2 * _objective_error(A, b, λ, abs.(x) .+ r1.x_residual)
  @test abs(r1.f_residual - r2.f_residual) <= bound / (abs(r1.minimum) + opt.ftol)
  @test occursin("Minimizer", sprint(show, r2))
end

@testset "normalized steps use the support of the whole product space" begin
  PS = ProximalSolvers
  for T in (Float32, Float64)
    A = T[2 0; 0 5]
    f = SeparableSum(QuadraticFunction(A, T[-1, 2]), SqrNormL2(T(3), ones(T, 2, 1)))
    g = SeparableSum(ZeroFunction(), ZeroFunction())
    method = ProximalGradientDescent(; normalized = true)
    for x0 in ((zeros(T, 2), zeros(T, 2, 1)),
               (T[1, 0], zeros(T, 2, 1)),
               (zeros(T, 2), reshape(T[0.2, 0], 2, 1)))
      st = PS.initial_state(method, ProximalOptions(), f, g, map(copy, x0))
      foreach(copyto!, st.x_previous, st.x)
      foreach(copyto!, st.grad_f_x_previous, st.grad_f_x)
      st.f_x_previous = st.f_x
      st.L = T(2)
      whole = all(block -> all(iszero, block), x0)
      d = map((x, grad) -> map((v, a) -> whole || !iszero(v) ? a : zero(T), x, grad),
              x0, st.grad_f_x)
      dd = sum(block -> sum(abs2, block), d)
      curvature = dot(d[1], A * d[1]) + T(3) * sum(abs2, d[2])
      expected_trial = map((x, dk) -> x .- dk ./ T(2), x0, d)
      PS._normalized_step!(f, st)
      @test st.L ≈ curvature / dd rtol = (T === Float32 ? 2e-5 : 1e-12)
      @test st.xhat[1] ≈ expected_trial[1]
      @test st.xhat[2] ≈ expected_trial[2]
      # A wholly zero block does not expand an already nonempty support.
      !whole && all(iszero, x0[2]) && @test all(iszero, st.xhat[2])
    end
  end
end

@testset "a tuple of one array is the array: ADMM" begin
  rng = Xoshiro(2)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  f, g = LeastSquaresLoss(y, X), NormL1(0.5)
  for method in (ADMMSolver(), ADMMSolver(; α = 1.6, adaptive = true))
    x = zeros(p)
    r1 = solve!(x, f, g, method)
    xt = (zeros(p),)
    r2 = solve!(xt, SeparableSum(f), SeparableSum(g), method)
    @test x == xt[1]
    @test (r1.iterations, r1.ρ, r1.r_norm, r1.s_norm) == (r2.iterations, r2.ρ, r2.r_norm, r2.s_norm)
    @test r2.u isa Tuple{Vector{Float64}} && r2.u[1] == r1.u
  end
end

@testset "two separate problems as one $(summary(method))" for method in (solvers..., ADMMSolver(; adaptive = true))
  rng = Xoshiro(3)
  n = 80
  X1, X2 = randn(rng, n, 15), randn(rng, n, 25)
  y1, y2 = randn(rng, n), randn(rng, n)
  if method isa ADMMSolver
    f1, f2 = LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2)
    g1, g2 = NormL1(1.0), NormL1(2.0)
    opt = ProximalOptions(; maxiter = 20_000)
    method = ADMMSolver(; adaptive = true, abstol = 1e-10, reltol = 1e-10)
  else
    f1, f2 = (1 / n) * LeastSquaresLoss(y1, X1), (1 / n) * LeastSquaresLoss(y2, X2)
    g1, g2 = NormL1(0.05), NormL1(0.1)
    opt = ProximalOptions(; ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, maxiter = 20_000)
  end
  x1, x2 = zeros(15), zeros(25)
  solve!(x1, f1, g1, method, opt)
  solve!(x2, f2, g2, method, opt)
  xt = (zeros(15), zeros(25))
  r = solve!(xt, SeparableSum(f1, f2), SeparableSum(g1, g2), method, opt)
  @test xt[1] ≈ x1 rtol = 1e-6
  @test xt[2] ≈ x2 rtol = 1e-6
  @test r.minimum ≈ f1(x1) + g1(x1) + f2(x2) + g2(x2) rtol = 1e-9
end

@testset "the fused graphical lasso for two groups" begin
  rng = Xoshiro(4)
  p, nx, ny = 15, 200, 150
  Ω = Matrix(SymTridiagonal(fill(1.0, p), fill(0.4, p - 1)))
  Ωy = copy(Ω); Ωy[1, 3] = Ωy[3, 1] = 0.3
  Sx = cov(randn(rng, nx, p) / cholesky(Ω).U')
  Sy = cov(randn(rng, ny, p) / cholesky(Ωy).U')
  n = nx + ny
  f = SeparableSum((nx / n) * LogDetLoss(Sx), (ny / n) * LogDetLoss(Sy))
  g = PairFused(0.05, 0.05)

  x = (Matrix(1.0I, p, p), Matrix(1.0I, p, p))
  r = solve!(x, f, g, ADMMSolver(; α = 1.5, adaptive = true, abstol = 1e-9, reltol = 1e-9), ProximalOptions(; maxiter = 50_000))
  @test ProximalSolvers.converged(r)
  # x is a fixed point of the proximal gradient step, which characterizes the minimizer
  G = (zeros(p, p), zeros(p, p))
  value_and_gradient!(G, f, x)
  γ = 0.1
  step = prox!((zeros(p, p), zeros(p, p)), g, (x[1] - γ * G[1], x[2] - γ * G[2]), γ)
  @test max(norm(step[1] - x[1]), norm(step[2] - x[2])) / γ < 1e-6
  @test issymmetric(x[1]) && issymmetric(x[2])

  # the accelerated gradient method on the pair finds the same solution
  xa = (Matrix(1.0I, p, p), Matrix(1.0I, p, p))
  ra = solve!(xa, f, g, AccProxGradDescent(), ProximalOptions(; ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12, maxiter = 50_000))
  @test ra.minimum ≈ r.minimum rtol = 1e-8
  @test norm(xa[1] - x[1]) + norm(xa[2] - x[2]) < 1e-4

  # warm start from the result
  r2 = solve!(map(copy, x), f, g, ADMMSolver(; ρ = r.ρ, α = 1.5, abstol = 1e-9, reltol = 1e-9), ProximalOptions(; maxiter = 50_000); u = map(copy, r.u))
  @test r2.iterations < r.iterations

  # residuals in the sum of the norms of the blocks (the norm of CovarianceSelection's
  # fusedGraphicalLasso! loop), and the same norm with a method for differences
  blocknorm = x -> sum(LinearAlgebra.norm, x)
  admm(nrm) = ADMMSolver(; α = 1.5, adaptive = true, abstol = 1e-9, reltol = 1e-9, norm = nrm)
  rs = solve!((Matrix(1.0I, p, p), Matrix(1.0I, p, p)), f, g, admm(blocknorm), ProximalOptions(; maxiter = 50_000))
  @test ProximalSolvers.converged(rs)
  @test rs.minimum ≈ r.minimum rtol = 1e-8
  rd = solve!((Matrix(1.0I, p, p), Matrix(1.0I, p, p)), f, g, admm(BlockNorm()), ProximalOptions(; maxiter = 50_000))
  @test rd.iterations == rs.iterations
  @test rd.minimizer[1] ≈ rs.minimizer[1] rtol = 1e-12
end

@testset "a tuple of one array is the array: ADMM with a norm" begin
  rng = Xoshiro(7)
  n, p = 60, 20
  X, y = randn(rng, n, p), randn(rng, n)
  f, g = LeastSquaresLoss(y, X), NormL1(0.5)
  method = ADMMSolver(; adaptive = true, norm = x -> 2 * LinearAlgebra.norm(x))
  tmethod = ADMMSolver(; adaptive = true, norm = x -> 2 * LinearAlgebra.norm(x[1]))
  x = zeros(p)
  r1 = solve!(x, f, g, method)
  xt = (zeros(p),)
  r2 = solve!(xt, SeparableSum(f), SeparableSum(g), tmethod)
  @test x == xt[1]
  @test (r1.iterations, r1.ρ, r1.r_norm, r1.s_norm) == (r2.iterations, r2.ρ, r2.r_norm, r2.s_norm)
end

@testset "Float32 blocks" begin
  rng = Xoshiro(5)
  n = 50
  X1, X2 = randn(rng, Float32, n, 10), randn(rng, Float32, n, 12)
  y1, y2 = randn(rng, Float32, n), randn(rng, Float32, n)
  f = SeparableSum((1f0 / n) * LeastSquaresLoss(y1, X1), (1f0 / n) * LeastSquaresLoss(y2, X2))
  g = SeparableSum(NormL1(0.05f0), NormL1(0.05f0))
  for method in solvers
    xt = (zeros(Float32, 10), zeros(Float32, 12))
    r = solve!(xt, f, g, method, ProximalOptions(; ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
    @test r.minimum isa Float32 && eltype(xt[2]) == Float32
  end
  fa = SeparableSum(LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2))
  xt = (zeros(Float32, 10), zeros(Float32, 12))
  r = solve!(xt, fa, SeparableSum(NormL1(1f0), NormL1(1f0)), ADMMSolver(; adaptive = true))
  @test r.minimum isa Float32 && r.u isa Tuple{Vector{Float32}, Vector{Float32}}
end

@testset "no allocations per iteration" begin
  rng = Xoshiro(6)
  n = 50
  X1, X2 = randn(rng, n, 10), randn(rng, n, 12)
  y1, y2 = randn(rng, n), randn(rng, n)
  fq = SeparableSum(QuadraticFunction(X1'X1 / n, -X1'y1 / n), QuadraticFunction(X2'X2 / n, -X2'y2 / n))
  fl = SeparableSum(LeastSquaresLoss(y1, X1), LeastSquaresLoss(y2, X2))
  g = SeparableSum(NormL1(0.01), NormL1(0.01))
  x0 = (zeros(10), zeros(12))
  # an iteration of a gradient method, after a few
  function step_bytes(f, g, method, x0)
    state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, map(copy, x0))
    for _ in 1:5
      ProximalSolvers.update_state!(f, g, state, method)
    end
    @allocated ProximalSolvers.update_state!(f, g, state, method)
  end
  for method in (solvers..., ProximalGradientDescent(; normalized = true))
    @test step_bytes(fq, g, method, x0) == 0
  end
  # ADMM: the bytes of 40 iterations less those of 20, which never converge to
  # tolerances of 1e-300
  admm = ADMMSolver(; abstol = 1e-300, reltol = 1e-300)
  run(m) = (x = map(copy, x0); r = solve!(x, fl, g, admm, ProximalOptions(; maxiter = m)); r.iterations)
  run(20); run(40)
  b20 = @allocated i20 = run(20)
  b40 = @allocated i40 = run(40)
  @test (i20, i40) == (20, 40)
  @test b40 == b20
end

# Tuples with a SymmetricSparseIterate (owner) block: the blocks keep their types, and the
# solution of two separate problems is that of the pair
owner_state(x) = (Matrix(x), collect(activecoordinates(x)), collect(activevalues(x)))
function owner_problem(p, seed)
  rng = Xoshiro(seed)
  R = randn(rng, p, p)
  S = R'R / p + I
  C = randn(rng, p, p)
  KronQuadratic(S, S, (C + C') / 2)
end

@testset "a pair of an owner and a dense array $(summary(method))" for method in solvers
  f1, g1 = owner_problem(4, 11), NormL1(0.2)
  rng = Xoshiro(12)
  X2, y2 = randn(rng, 50, 6), randn(rng, 50)
  f2, g2 = (1 / 50) * LeastSquaresLoss(y2, X2), NormL1(0.05)
  opt = ProximalOptions(; ftol = 1e-15, xtol = 1e-15, gradtol = 1e-13, maxiter = 20_000)
  x1, x2 = SymmetricSparseIterate(4), zeros(6)
  solve!(x1, f1, g1, method, opt)
  solve!(x2, f2, g2, method, opt)
  xt = (SymmetricSparseIterate(4), zeros(6))
  r = solve!(xt, SeparableSum(f1, f2), SeparableSum(g1, g2), method, opt)
  @test r.minimizer === xt
  @test xt[1] isa SymmetricSparseIterate{Float64}
  @test Matrix(xt[1]) ≈ Matrix(x1) atol = 1e-6
  @test xt[2] ≈ x2 atol = 1e-6
  @test r.minimum ≈ f1(x1) + g1(x1) + f2(x2) + g2(x2) rtol = 1e-9
  @test 0 < nactive(xt[1]) < ncoordinates(xt[1])
  @test occursin("2 blocks of sizes 4×4, 6", sprint(show, r))
end

@testset "a pair of owners $(summary(method))" for method in solvers
  f1, f2 = owner_problem(3, 21), owner_problem(5, 22)
  g1, g2 = NormL1(0.2), NormL1(0.3)
  opt = ProximalOptions(; ftol = 1e-15, xtol = 1e-15, gradtol = 1e-13, maxiter = 20_000,
                        store_trace = true, extended_trace = true)
  x1, x2 = SymmetricSparseIterate(3), SymmetricSparseIterate(5)
  solve!(x1, f1, g1, method, opt)
  solve!(x2, f2, g2, method, opt)
  xt = (SymmetricSparseIterate(3), SymmetricSparseIterate(5))
  r = solve!(xt, SeparableSum(f1, f2), SeparableSum(g1, g2), method, opt)
  @test Matrix(xt[1]) ≈ Matrix(x1) atol = 1e-6
  @test Matrix(xt[2]) ≈ Matrix(x2) atol = 1e-6
  @test r.minimum ≈ f1(x1) + g1(x1) + f2(x2) + g2(x2) rtol = 1e-9
  # the traced iterates are copies of both owners
  traced = r.trace[end].metadata["x"]
  @test traced isa Tuple{SymmetricSparseIterate{Float64}, SymmetricSparseIterate{Float64}}
  @test traced[1] !== xt[1] && Matrix(traced[1]) == Matrix(xt[1])
end

# one owner as both blocks, or a starting block that is another block of the workspace, is
# refused before anything is written
@testset "a tuple whose blocks share an owner" begin
  f = SeparableSum(owner_problem(2, 31), owner_problem(2, 32))
  g = SeparableSum(NormL1(0.1), NormL1(0.1))
  x = SymmetricSparseIterate(2)
  x[2, 1], x[1, 1] = 0.25, 0.5
  activate!(x, tril_index(2, 2, 2))
  before = owner_state(x)
  for call in (() -> solve!((x, x), f, g, ProximalGradientDescent()),
               () -> SolverWorkspace((x, x), f, g, AccProxGradDescent()))
    err = try
      call()
      nothing
    catch e
      e
    end
    @test err isa ArgumentError
    @test err isa ArgumentError && occursin("separate storage", sprint(showerror, err))
    @test isequal(owner_state(x), before)
  end
  a, b = SymmetricSparseIterate(2), SymmetricSparseIterate(2)
  ws = SolverWorkspace((a, b), f, g, MonotoneAccProxGradDescent())
  solve!(ws)
  saved = map(owner_state, (a, b))
  @test_throws ArgumentError reinit!(ws, (copy(b), a))
  @test isequal(map(owner_state, (a, b)), saved)
  # a dense block that is a view of the owner block shares its storage
  @test ProximalSolvers._mightalias(x, matrixview(x)) && ProximalSolvers._mightalias(x, coordinates(x))
  @test !ProximalSolvers._mightalias(x, copy(x)) && !ProximalSolvers._mightalias(x, zeros(2, 2))
end

# An owner block whose penalty ProximalBase may have no proximal operator into an owner for
# (a linear constraint, an intersection, a pointwise minimum) is stepped through a dense matrix
# inside a tuple as it is alone: the pair solution is that of the separate problems
constraint_penalties() = (("linear constraint", () -> Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))),
                          ("intersection", () -> IndIntersection(IndBox(-1.0, 1.0), IndHyperplane(1.0, 0.0))),
                          ("pointwise minimum", () -> PointwiseMinimum(NormL1(0.1), NormL1(0.2))),
                          ("scaled linear constraint", () -> Scaled(Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0)), 0.7)))
@testset "an owner block with a $label $(summary(method))" for (label, make) in constraint_penalties(), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo, go = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2]), make()
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  xo, xd = SymmetricSparseIterate(2), zeros(1)
  ro = solve!(xo, fo, go, method, opt)
  rd = solve!(xd, SqrNormL2(), NormL1(0.1), method, opt)
  for (x, f, g) in (((SymmetricSparseIterate(2), zeros(1)), SeparableSum(fo, SqrNormL2()), SeparableSum(go, NormL1(0.1))),
                    ((SymmetricSparseIterate(2), SymmetricSparseIterate(2)), SeparableSum(fo, fo), SeparableSum(go, NormL1(0.1))))
    r = solve!(x, f, g, method, opt)
    @test isfinite(r.minimum)
    @test Matrix(x[1]) ≈ Matrix(xo) atol = 1e-6
    x[2] isa SymmetricSparseIterate || @test x[2] ≈ xd atol = 1e-8
    x[2] isa SymmetricSparseIterate && @test x[2][1, 1] ≈ 0.9 atol = 1e-6
  end
end

# whether ProximalBase steps IndBallL0 into an owner block of a tuple (decided as the solvers do)
l0_tuple_owner() = try
  value_and_prox!((SymmetricSparseIterate(2), zeros(1)), SeparableSum(IndBallL0(1; diagonal = false), NormL1(0.1)),
                  (SymmetricSparseIterate([1.0 0.5; 0.5 1.0]), [1.0]), 1.0)
  true
catch e
  e isa MethodError || rethrow()
  false
end

# the scratch of an owner block without the dense-matrix role: an owner output and an owner input
# (and, with input = true, an owner input, which a block with IndBallL0 takes)
osc(p, T = Float64; input = false) =
  ProximalSolvers._OwnerScratch(SymmetricSparseIterate(T, p), input ? SymmetricSparseIterate(T, p) : nothing)

# the dense proximal points of such owner blocks are checked before any block is written: an
# asymmetric trial point for the second block leaves the first block unchanged
@testset "a tuple step checks the dense owner blocks before writing" begin
  g = SeparableSum(NormL1(0.1), Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0)))
  z = ([0.5 0.2; 0.2 0.1], [1.0 0.3; 0.8 -0.4])
  w = zeros(2, 2)
  value_and_prox!(w, g.fs[2], z[2], 1.0)
  @test w != w'
  x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
  x[1][2, 1] = 0.7
  before = map(owner_state, x)
  err = try
    ProximalSolvers._metric_prox!(x, g, z, 1.0, nothing, (osc(2), zeros(2, 2)))
    nothing
  catch e
    e
  end
  @test err isa ArgumentError && occursin("symmetric", sprint(showerror, err))
  @test isequal(map(owner_state, x), before)
end

# The dense route of a tuple: a SeparableSum, also inside Scaled (nested too), with an owner block
# whose penalty is a linear constraint, an intersection or a pointwise minimum, scaled or not.
# ProximalBase takes the step of the whole penalty into dense buffers; the solution is the one of
# the same problem with dense matrices in place of the owners.
const PSR = ProximalSolvers
route_wrappers() = (("bare", g -> g), ("Scaled", g -> Scaled(g, 0.7)), ("Scaled(Scaled)", g -> Scaled(Scaled(g, 0.7), 1.3)))
@testset "the dense route, $wlabel sum with a $label $(summary(method))" for (wlabel, wrap) in route_wrappers(),
    (label, make) in constraint_penalties(), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  f, g = SeparableSum(fo, SqrNormL2()), wrap(SeparableSum(make(), NormL1(0.1)))
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  x = (SymmetricSparseIterate(2), zeros(1))
  @test PSR._dense_route(x, g)
  r = solve!(x, f, g, method, opt)
  xd = (zeros(2, 2), zeros(1))
  rd = solve!(xd, f, g, method, opt)
  @test x[1] isa SymmetricSparseIterate{Float64}
  @test Matrix(x[1]) ≈ xd[1] atol = 1e-6
  @test x[2] ≈ xd[2] atol = 1e-6
  @test r.minimum ≈ rd.minimum rtol = 1e-8 atol = 1e-10
  @test Matrix(x[1]) == Matrix(x[1])'
end

# the owner in each position of three blocks, and two owners, with the sum scaled as a whole
@testset "the dense route with the owner in position $k $(summary(method))" for k in 1:3, method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  fs = ntuple(j -> j == k ? fo : SqrNormL2(1.0, [0.5, -0.3]), 3)
  gs = ntuple(j -> j == k ? Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0)) : NormL1(0.1), 3)
  f, g = SeparableSum(fs...), Scaled(SeparableSum(gs...), 0.7)
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  x = ntuple(j -> j == k ? SymmetricSparseIterate(2) : zeros(2), 3)
  xd = ntuple(j -> j == k ? zeros(2, 2) : zeros(2), 3)
  @test PSR._dense_route(x, g)
  r, rd = solve!(x, f, g, method, opt), solve!(xd, f, g, method, opt)
  for j in 1:3
    @test (j == k ? Matrix(x[j]) : x[j]) ≈ xd[j] atol = 1e-6
  end
  @test r.minimum ≈ rd.minimum rtol = 1e-8
  # two owners, both taking the dense route, and one owner beside it with an L1 penalty
  for g2 in (Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0)), NormL1(0.1))
    y = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
    yd = (zeros(2, 2), zeros(2, 2))
    gy = Scaled(SeparableSum(PointwiseMinimum(NormL1(0.1), NormL1(0.2)), g2), 0.7)
    @test PSR._dense_route(y, gy)
    ry, ryd = solve!(y, SeparableSum(fo, fo), gy, method, opt), solve!(yd, SeparableSum(fo, fo), gy, method, opt)
    @test Matrix(y[1]) ≈ yd[1] atol = 1e-6
    @test Matrix(y[2]) ≈ yd[2] atol = 1e-6
    @test ry.minimum ≈ ryd.minimum rtol = 1e-8
  end
end

# An analytic solution: ½‖Θ - B‖² on the owner with the constraint Σᵢⱼ Θᵢⱼ = 0 (and an L1 weight
# of zero) is the projection Θ = B - mean(B), and ½‖u‖² - ⟨u0, u⟩ with no penalty gives u = u0;
# a scale of the sum leaves both unchanged.
@testset "the dense route against the closed form, $wlabel $(summary(method))" for wlabel in ("bare", "Scaled"),
    method in solvers
  p = 3
  B = [1.0 0.4 -0.2; 0.4 2.0 0.3; -0.2 0.3 -0.5]
  u0 = [0.7, -1.2]
  f = SeparableSum(KronQuadratic(Matrix(1.0I, p, p), Matrix(1.0I, p, p), -B), QuadraticFunction(Matrix(1.0I, 2, 2), -u0))
  g0 = SeparableSum(Constrained(NormL1(0.0), IndHyperplane(1.0, 0.0)), ZeroFunction())
  g = wlabel == "bare" ? g0 : Scaled(g0, 0.7)
  Θ, u = B .- sum(B) / p^2, u0
  x = (SymmetricSparseIterate(p), zeros(2))
  @test PSR._dense_route(x, g)
  r = solve!(x, f, g, method, ProximalOptions(; maxiter = 2000, ftol = 1e-15, xtol = 1e-15, gradtol = 1e-13))
  @test Matrix(x[1]) ≈ Θ atol = 1e-7
  @test x[2] ≈ u atol = 1e-7
  @test abs(sum(Matrix(x[1]))) <= 1e-9
  @test r.minimum ≈ f((Θ, u)) + g((Θ, u)) rtol = 1e-9 atol = 1e-12
end

# Pairs that keep the step of ProximalBase on the whole tuple: no owner, owners whose penalties
# ProximalBase takes, sums with a penalty count that differs from the block count, coupled tuple
# penalties, and wrappers around a sum whose blocks do not take the dense route
@testset "pairs outside the dense route" begin
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  o = SymmetricSparseIterate(2)
  @test !PSR._dense_route((zeros(2, 2), zeros(1)), SeparableSum(lc, NormL1(0.1)))
  @test !PSR._dense_route((o, zeros(1)), SeparableSum(NormL1(0.1), lc))
  @test !PSR._dense_route((o, zeros(1)), Scaled(SeparableSum(NormL1(0.1), NormL1(0.1)), 0.7))
  @test !PSR._dense_route((o, zeros(1)), SeparableSum(lc))
  @test !PSR._dense_route((o, o), PairFused(0.05, 0.05))
  @test !PSR._dense_route((o, zeros(1)), Translate(SeparableSum(NormL1(0.1), NormL1(0.1)), ([0.1 0.0; 0.0 0.1], [0.2])))
  @test PSR._dense_route(o, Scaled(lc, 0.5)) && !PSR._dense_route(o, Scaled(NormL1(0.1), 0.5))
  # a dense tuple with a constraint block, and an owner with an L1 block, solve as before
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  for method in solvers
    xd = (zeros(2, 2), zeros(1))
    rd = solve!(xd, SeparableSum(fo, SqrNormL2()), SeparableSum(lc, NormL1(0.1)), method)
    xo = SymmetricSparseIterate(2)
    solve!(xo, fo, lc, method)
    @test xd[1] ≈ Matrix(xo) atol = 1e-5
    x = (SymmetricSparseIterate(2), zeros(1))
    solve!(x, SeparableSum(fo, SqrNormL2()), Scaled(SeparableSum(NormL1(0.1), NormL1(0.1)), 0.7), method)
    y = SymmetricSparseIterate(2)
    solve!(y, fo, Scaled(NormL1(0.1), 0.7), method)
    @test Matrix(x[1]) ≈ Matrix(y) atol = 1e-5
  end
end

# Translate and Tilt inside the blocks: around the constraint of the owner block and around the
# penalty of a dense block
@testset "the dense route with Translate and Tilt inside the blocks $(summary(method))" for method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  for g in (SeparableSum(Translate(lc, [0.1 0.05; 0.05 -0.1]), Translate(NormL1(0.1), [0.2])),
            SeparableSum(Tilt(lc, [0.1 -0.2; -0.2 0.05]), Tilt(NormL1(0.1), [0.3])),
            Scaled(SeparableSum(Translate(lc, [0.1 0.05; 0.05 -0.1]), Tilt(NormL1(0.1), [0.3])), 0.7))
    x = (SymmetricSparseIterate(2), zeros(1))
    @test PSR._dense_route(x, g)
    r = solve!(x, SeparableSum(fo, SqrNormL2()), g, method, opt)
    xd = (zeros(2, 2), zeros(1))
    rd = solve!(xd, SeparableSum(fo, SqrNormL2()), g, method, opt)
    @test Matrix(x[1]) ≈ xd[1] atol = 1e-6
    @test x[2] ≈ xd[2] atol = 1e-6
    @test r.minimum ≈ rd.minimum rtol = 1e-8 atol = 1e-10
  end
end

# ProximalBase refuses Translate and Tilt around a whole tuple that has an owner block, when the
# solver evaluates the penalty at the start point: the iterate is unchanged
@testset "ProximalBase refuses Translate and Tilt around a tuple with an owner $(summary(method))" for method in solvers
  A = Matrix(1.0I, 2, 2)
  f = SeparableSum(KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2]), SqrNormL2())
  sum0 = SeparableSum(Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0)), NormL1(0.1))
  b, c = ([0.1 0.05; 0.05 -0.1], [0.2]), ([0.1 -0.2; -0.2 0.05], [0.3])
  for g in (Translate(sum0, b), Tilt(sum0, c, 0.25), Scaled(Translate(sum0, b), 0.7), Translate(Scaled(sum0, 0.7), b),
            Tilt(Scaled(sum0, 0.7), c, 0.0))
    x = (SymmetricSparseIterate(2), [0.4])
    x[1][2, 1], x[1][1, 1] = 0.25, 0.5
    before = (owner_state(x[1]), copy(x[2]))
    err = try
      solve!(x, f, g, method)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError
    @test err isa ArgumentError && occursin("do not support a SymmetricSparseIterate as a block", sprint(showerror, err))
    @test isequal((owner_state(x[1]), copy(x[2])), before)
  end
end

# The refusals of the dense route, before any block of the iterate is written: a later owner block
# with asymmetric weights on the second of three owners (refused by ProximalBase in its step into
# the owner scratch), a later owner-scratch block whose trial point is not symmetric, a later
# dense-matrix owner block whose proximal point is not symmetric, and scratch blocks of the wrong
# role, shape or element type or with shared storage. The first two blocks take owner scratch (L1
# penalties), the third a dense matrix (a linear constraint).
@testset "the dense route refuses before writing ($T)" for T in (Float32, Float64)
  lc = Constrained(NormL1(T(0.1)), IndHyperplane(T(1), T(0)))
  g = SeparableSum(NormL1(T(0.1)), NormL1(T(0.1), T[0 1; 3 0]), lc)
  zs = ntuple(_ -> T[0.5 0.4; 0.4 0.2], 3)
  function owners()
    x = ntuple(_ -> SymmetricSparseIterate(T, 2), 3)
    for (k, xk) in enumerate(x)
      xk[1, 1], xk[2, 1] = T(k), T(-k) / 2
    end
    x
  end
  refused(call, x, needle) = begin
    before = map(owner_state, x)
    err = try
      call()
      nothing
    catch e
      e
    end
    @test err isa ArgumentError
    @test err isa ArgumentError && occursin(needle, sprint(showerror, err))
    @test isequal(map(owner_state, x), before)
  end
  scratch() = (osc(2, T), osc(2, T), zeros(T, 2, 2))
  x = owners()
  @test PSR._dense_route(x, g)
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, scratch()), x, "must be symmetric")
  x = owners()
  g2 = SeparableSum(NormL1(T(0.1)), NormL1(T(0.1)), lc)
  refused(() -> PSR._metric_prox!(x, g2, (zs[1], T[1 0.3; 0.8 -0.4], zs[3]), T(1), nothing, scratch()), x, "must be symmetric")
  x = owners()
  g3 = SeparableSum(NormL1(T(0.1)), lc, lc)
  refused(() -> PSR._metric_prox!(x, g3, (zs[1], zs[2], T[1 0.3; 0.8 -0.4]), T(1), nothing,
                                   (osc(2, T), zeros(T, 2, 2), zeros(T, 2, 2))), x, "must be symmetric")
  x = owners()
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, (zeros(T, 2, 2), osc(2, T), zeros(T, 2, 2))), x,
          "must match the iterate blocks")
  x = owners()
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, (osc(2, T), SymmetricSparseIterate(T, 2), zeros(T, 2, 2))), x,
          "must match the iterate blocks")
  x = owners()
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, (osc(2, T), osc(3, T), zeros(T, 2, 2))), x,
          "must match the iterate blocks")
  x = owners()
  S = T === Float64 ? Float32 : Float64
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, (osc(2, T), osc(2, S), zeros(T, 2, 2))), x,
          "must match the iterate blocks")
  x = owners()
  shared = SymmetricSparseIterate(T, 2)
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing,
                                   (PSR._OwnerScratch(shared, nothing), PSR._OwnerScratch(shared, nothing), zeros(T, 2, 2))), x,
          "storage of their own")
  # an owner input where the block takes none, and an IndBallL0 block whose output and input are one
  # owner (refused for its storage where ProximalBase has the IndBallL0 step, before it otherwise)
  x = owners()
  refused(() -> PSR._metric_prox!(x, g, zs, T(1), nothing, (osc(2, T; input = true), osc(2, T), zeros(T, 2, 2))), x,
          "must match the iterate blocks")
  x = owners()
  gl0 = SeparableSum(IndBallL0(1; diagonal = false), NormL1(T(0.1)), lc)
  refused(() -> PSR._metric_prox!(x, gl0, zs, T(1), nothing, (PSR._OwnerScratch(shared, shared), osc(2, T), zeros(T, 2, 2))), x,
          l0_tuple_owner() ? "storage of their own" : "does not provide the proximal operator of IndBallL0")
  # a later dense-matrix owner block whose proximal point is not symmetric at a symmetric trial point
  # (a hyperplane normal that is not symmetric, which solve! would reject at its start)
  x = owners()
  gn = SeparableSum(NormL1(T(0.1)), lc, Constrained(NormL1(T(0.1)), IndHyperplane(T[1 1; 0 1], T(0))))
  refused(() -> PSR._metric_prox!(x, gn, zs, T(1), nothing, (osc(2, T), zeros(T, 2, 2), zeros(T, 2, 2))), x, "must be symmetric")
  x = owners()
  zcopy = map(copy, zs)
  refused(() -> PSR._metric_prox!(x, g, zcopy, T(1), nothing, (osc(2, T), osc(2, T), zcopy[3])), x, "storage of their own")
end

# Scratch roles of the owner blocks of a tuple on the dense route, beside a constrained owner.
# IndBallL1, IndBallL2, IndSimplex and IndSphereL2 take a dense matrix: their solution on the owner
# block with ½‖Θ - B‖² is the Frobenius projection of B onto the set over all p² entries (a mirrored
# off-diagonal pair counts twice, as in the owner's norm), computed here independently.
proj_simplex(v, r) = begin
  u = sort(v; rev = true)
  c = cumsum(u)
  ρ = findlast(j -> u[j] - (c[j] - r) / j > 0, eachindex(u))
  max.(v .- (c[ρ] - r) / ρ, 0.0)
end
proj_l1ball(v, r) = sum(abs, v) <= r ? copy(v) : sign.(v) .* proj_simplex(abs.(v), r)
set_families() = (
  ("IndBallL1", () -> IndBallL1(1.0), B -> reshape(proj_l1ball(vec(B), 1.0), size(B)), X -> sum(abs, X) <= 1 + 1e-12),
  ("IndBallL2", () -> IndBallL2(1.0), B -> B * min(1.0, 1.0 / norm(B)), X -> norm(X) <= 1 + 1e-12),
  ("IndSimplex", () -> IndSimplex(1.0), B -> reshape(proj_simplex(vec(B), 1.0), size(B)), X -> all(>=(0), X) && abs(sum(X) - 1) <= 1e-12),
  ("IndSphereL2", () -> IndSphereL2(1.0), B -> B / norm(B), X -> abs(norm(X) - 1) <= 1e-12))
has_owner_value(h) = try
  h(SymmetricSparseIterate(2))
  true
catch e
  e isa MethodError || rethrow()
  false
end
role_wrappers() = (("bare", g -> g, h -> h), ("Scaled", g -> Scaled(g, 0.7), h -> h), ("Scaled(Scaled)", g -> Scaled(Scaled(g, 0.7), 1.3), h -> h),
                   ("inner Scaled", g -> g, h -> Scaled(h, 0.5)), ("inner and outer Scaled", g -> Scaled(g, 0.7), h -> Scaled(h, 0.5)))
@testset "a dense-matrix owner block with $name, $wlabel, set block $k $(summary(method))" for (name, make, proj, feasible) in set_families(),
    (wlabel, wrap, inner) in role_wrappers(), k in (1, 2), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  B = [1.2 0.9; 0.9 -0.4]
  fs = KronQuadratic(A, A, -B)
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  f = k == 1 ? SeparableSum(fs, fo) : SeparableSum(fo, fs)
  g = wrap(k == 1 ? SeparableSum(inner(make()), lc) : SeparableSum(lc, inner(make())))
  x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
  # some ProximalBase revisions have no value of these sets at an owner, which every solve needs
  # (at the start point), with or without a tuple: the solve is run only where the value exists;
  # the proximal step of the route is tested at points below on every revision
  if has_owner_value(make())
    opt = ProximalOptions(; maxiter = 2000, ftol = 1e-15, xtol = 1e-15, gradtol = 1e-13)
    r = solve!(x, f, g, method, opt)
    xd = (zeros(2, 2), zeros(2, 2))
    rd = solve!(xd, f, g, method, opt)
    X = Matrix(x[k])
    @test X == X'
    @test feasible(X)
    @test X ≈ proj(B) atol = 1e-7
    @test Matrix(x[3 - k]) ≈ xd[3 - k] atol = 1e-6
    @test r.minimum ≈ rd.minimum rtol = 1e-8 atol = 1e-10
  end
  @test PSR._dense_route(x, g)
  @test PSR._owner_scratch(x, g) === nothing
end

# The same step at chosen points, directly: a point outside, inside and on the set, mirrored
# off-diagonal entries, zero (for IndSphereL2 every unit matrix is a projection: only feasibility is
# asserted) and nonfinite entries. The result is the independent projection and, where both run,
# the proximal point of the single-owner step.
@testset "the dense-matrix role at chosen points: $name" for (name, make, proj, feasible) in set_families()
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  zB = [0.5 0.4; 0.4 0.2]
  inside = name == "IndSimplex" ? [0.25 0.25; 0.25 0.25] : name == "IndSphereL2" ? [0.6 0.4; 0.4 -0.2] / norm([0.6 0.4; 0.4 -0.2]) :
           [0.1 0.05; 0.05 -0.1]
  points = (("outside", [1.2 0.9; 0.9 -0.4]), ("inside", inside), ("mirrored", [0.0 0.8; 0.8 0.0]), ("zero", zeros(2, 2)),
            ("NaN", [NaN 0.1; 0.1 0.2]), ("Inf pair", [0.3 Inf; Inf 0.1]))
  for (wrap, inner) in ((g -> g, h -> h), (g -> Scaled(g, 0.7), h -> Scaled(h, 0.5)))
    g = wrap(SeparableSum(lc, inner(make())))
    for (label, zk) in points
      x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
      x[2][1, 1] = 0.3
      before = map(owner_state, x)
      v = NaN
      err = try
        v = PSR._metric_prox!(x, g, (zB, zk), 1.0, nothing, (zeros(2, 2), zeros(2, 2)))
        nothing
      catch e
        e
      end
      single = SymmetricSparseIterate(2)
      serr = try
        value_and_prox!(single, make(), zk, 1.0)
        nothing
      catch e
        e
      end
      if label == "Inf pair"
        # one infinite mirrored pair: the owner step projects its direction, the dense step would give
        # NaN, so the route refuses it before writing
        @test err isa ArgumentError && occursin("does not reproduce the finite limiting projection", sprint(showerror, err))
        @test isequal(map(owner_state, x), before)
        continue
      elseif label == "NaN"
        # NaN gives the result of the single-owner step (where that runs)
        @test err === nothing
        serr === nothing && @test isequal(Matrix(x[2]), Matrix(single))
        continue
      end
      @test err === nothing
      err === nothing || continue
      X = Matrix(x[2])
      @test X == X'
      @test feasible(X)
      if name == "IndSphereL2" && label == "zero"
        continue
      end
      @test X ≈ proj(zk) atol = 1e-12
      label == "inside" && @test X ≈ zk atol = 1e-14
      serr === nothing && @test X ≈ Matrix(single) atol = 1e-12
    end
  end
end

# The refusal of one infinite mirrored pair in the trial block of a direct set, in both block orders,
# bare and scaled: nothing is written, and the next step from a finite trial point runs; trial blocks
# with other infinite patterns go to the step (two infinite pairs, an infinite pair with an infinite
# diagonal entry, an infinite diagonal entry alone), as does NaN
@testset "the dense route refuses one infinite mirrored pair of $name" for (name, make, proj, feasible) in set_families()
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  zB = [0.5 0.4 0.0; 0.4 0.2 0.1; 0.0 0.1 -0.3]
  pair = [0.3 Inf 0.0; Inf 0.2 0.3; 0.0 0.3 -0.1]
  finite = [1.2 0.9 0.0; 0.9 -0.4 0.2; 0.0 0.2 0.1]
  others = ([0.3 Inf 0.0; Inf 0.2 Inf; 0.0 Inf -0.1], [Inf Inf 0.0; Inf 0.2 0.3; 0.0 0.3 -0.1], [Inf 0.1 0.0; 0.1 0.2 0.3; 0.0 0.3 -0.1],
            [NaN 0.1 0.0; 0.1 0.2 0.3; 0.0 0.3 -0.1])
  for k in (1, 2), wrap in (h -> h, h -> Scaled(h, 0.5)), outer in (g -> g, g -> Scaled(g, 0.7))
    g = outer(k == 1 ? SeparableSum(wrap(make()), lc) : SeparableSum(lc, wrap(make())))
    zt(zk) = k == 1 ? (zk, zB) : (zB, zk)
    x = (SymmetricSparseIterate(3), SymmetricSparseIterate(3))
    x[k][2, 1], x[3 - k][1, 1] = 0.3, 0.2
    before = map(owner_state, x)
    err = try
      PSR._metric_prox!(x, g, zt(pair), 1.0, nothing, (zeros(3, 3), zeros(3, 3)))
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("does not reproduce the finite limiting projection", sprint(showerror, err))
    @test isequal(map(owner_state, x), before)
    PSR._metric_prox!(x, g, zt(finite), 1.0, nothing, (zeros(3, 3), zeros(3, 3)))
    @test Matrix(x[k]) ≈ proj(finite) atol = 1e-12
    for zk in others
      y = (SymmetricSparseIterate(3), SymmetricSparseIterate(3))
      @test (PSR._metric_prox!(y, g, zt(zk), 1.0, nothing, (zeros(3, 3), zeros(3, 3))); true)
    end
  end
end

# The input roles of owner-scratch blocks: an owner input for a block with IndBallL0 (also inside
# Scaled, Translate and Tilt), a dense input for any other penalty
@testset "the input roles of the owner blocks" begin
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  B = [0.1 0.0; 0.0 0.2]
  for (h, owner_input) in ((IndBallL0(1; diagonal = false), true), (Scaled(IndBallL0(1), 0.5), true),
                           (Translate(IndBallL0(1; diagonal = false), B), true), (NormL1(0.1), false),
                           (NuclearNorm(0.1), false), (IndBallRank(1), false), (ElasticNet(0.1, 0.2), false))
    s = PSR._owner_scratch((SymmetricSparseIterate(2), SymmetricSparseIterate(2)), SeparableSum(lc, h))
    @test s[1] === nothing && s[2] isa PSR._OwnerScratch
    @test (s[2].z isa SymmetricSparseIterate) == owner_input
  end
end

# NuclearNorm and IndBallRank owner blocks beside a constrained owner, with their dense input:
# the solution of the same problem with dense matrices
@testset "an owner block with $name beside a constrained owner, block $k $(summary(method))" for (name, h) in
    (("NuclearNorm", NuclearNorm(0.3)), ("IndBallRank", IndBallRank(1))), k in (1, 2), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  fs = KronQuadratic(A, A, -[1.2 0.9; 0.9 -0.4])
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  f = k == 1 ? SeparableSum(fs, fo) : SeparableSum(fo, fs)
  g = k == 1 ? SeparableSum(h, lc) : SeparableSum(lc, h)
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
  r = solve!(x, f, g, method, opt)
  xd = (zeros(2, 2), zeros(2, 2))
  rd = solve!(xd, f, g, method, opt)
  @test Matrix(x[1]) ≈ xd[1] atol = 1e-6
  @test Matrix(x[2]) ≈ xd[2] atol = 1e-6
  @test r.minimum ≈ rd.minimum rtol = 1e-8
end

# Owner-scratch blocks beside a constrained owner: a penalty with an owner-only proximal operator,
# and IndBallL0, for which a dense-matrix scratch can change the meaning of the budget. The owner-only penalty
# solves as the same problem with dense matrices and NormL1.
struct OwnerOnlyL1 <: AbstractFunction
  λ::Float64
end
ProximalBase.isproximable(::Type{OwnerOnlyL1}) = true
ProximalBase.isconvex(::Type{OwnerOnlyL1}) = true
(g::OwnerOnlyL1)(x::SymmetricSparseIterate) = NormL1(g.λ)(x)
ProximalBase.value_and_prox!(y::SymmetricSparseIterate, g::OwnerOnlyL1, x::Union{AbstractMatrix, SymmetricSparseIterate}, t::Real) =
  value_and_prox!(y, NormL1(g.λ), x, t)
@testset "an owner block with an owner-only penalty, $wlabel, block $k $(summary(method))" for (wlabel, wrap) in route_wrappers(),
    k in (1, 2), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  g = wrap(k == 1 ? SeparableSum(OwnerOnlyL1(0.1), lc) : SeparableSum(lc, OwnerOnlyL1(0.1)))
  gd = wrap(k == 1 ? SeparableSum(NormL1(0.1), lc) : SeparableSum(lc, NormL1(0.1)))
  x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
  opt = ProximalOptions(; maxiter = 2000, ftol = 1e-14, xtol = 1e-14, gradtol = 1e-12)
  r = solve!(x, SeparableSum(fo, fo), g, method, opt)
  xd = (zeros(2, 2), zeros(2, 2))
  rd = solve!(xd, SeparableSum(fo, fo), gd, method, opt)
  @test Matrix(x[1]) ≈ xd[1] atol = 1e-6
  @test Matrix(x[2]) ≈ xd[2] atol = 1e-6
  @test r.minimum ≈ rd.minimum rtol = 1e-8
  wlabel == "bare" && @test Matrix(x[k]) ≈ [0.9 0.4; 0.4 -0.1] atol = 1e-6
  s = PSR._owner_scratch(x, g)
  @test s isa Tuple && s[k] isa SymmetricSparseIterate && s[3 - k] === nothing
end

# IndBallL0(budget; diagonal = false) on an owner block beside a constrained owner, with the target
# T of ½‖Θ - T‖², from zero. Where ProximalBase provides the IndBallL0 step into an owner block of a
# tuple (the ProximalBase commit of Project.toml), the block takes its trial point as an owner and
# the budget counts mirrored pairs once, as the solvers on master do there: p = 3, budget 2 keeps
# Θ12 = 3 and Θ13 = 2 (value -13), p = 2, budget 1 keeps Θ12 = 2 (value -4); the objective is that
# value plus the solution of the constrained block alone (-13.25 and -4.25 unscaled). Where
# ProximalBase does not provide it, the solvers refuse before writing anything, and the same tuple
# with an L1 block then solves.
@testset "an IndBallL0 owner block, p = $p, $wlabel, block $k $(summary(method))" for p in (2, 3),
    (wlabel, wrap) in route_wrappers(), k in (1, 2), method in solvers
  A = Matrix(1.0I, 2, 2)
  fo = KronQuadratic(A, A, [-1.0 -0.5; -0.5 0.2])
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  target = p == 2 ? [0.0 2.0; 2.0 0.0] : [0.0 3.0 2.0; 3.0 0.0 1.0; 2.0 1.0 0.0]
  fi = KronQuadratic(Matrix(1.0I, p, p), Matrix(1.0I, p, p), -target)
  gi = IndBallL0(p == 2 ? 1 : 2; diagonal = false)
  f = k == 1 ? SeparableSum(fi, fo) : SeparableSum(fo, fi)
  g = wrap(k == 1 ? SeparableSum(gi, lc) : SeparableSum(lc, gi))
  newx() = k == 1 ? (SymmetricSparseIterate(p), SymmetricSparseIterate(2)) : (SymmetricSparseIterate(2), SymmetricSparseIterate(p))
  x = newx()
  opt = ProximalOptions(; maxiter = 1000, ftol = 1e-13, xtol = 1e-13, gradtol = 1e-11)
  if l0_tuple_owner()
    r = solve!(x, f, g, method, opt)
    expected = p == 2 ? [0.0 2.0; 2.0 0.0] : [0.0 3.0 2.0; 3.0 0.0 0.0; 2.0 0.0 0.0]
    @test Matrix(x[k]) ≈ expected atol = 1e-6
    @test count(!iszero, Matrix(x[k])[i, j] for j in 1:p for i in j+1:p) <= (p == 2 ? 1 : 2)
    xs = SymmetricSparseIterate(2)
    rs = solve!(xs, fo, wlabel == "bare" ? lc : wlabel == "Scaled" ? Scaled(lc, 0.7) : Scaled(Scaled(lc, 0.7), 1.3), method, opt)
    @test r.minimum ≈ (p == 2 ? -4.0 : -13.0) + rs.minimum atol = 1e-8
    wlabel == "bare" && @test r.minimum ≈ (p == 2 ? -4.25 : -13.25) atol = 1e-8
    @test Matrix(x[3 - k]) ≈ Matrix(xs) atol = 1e-6
  else
    x[k][2, 1] = 0.5
    before = map(owner_state, x)
    err = try
      solve!(x, f, g, method, opt)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError && occursin("does not provide the proximal operator of IndBallL0", sprint(showerror, err))
    @test isequal(map(owner_state, x), before)
    gl = wrap(k == 1 ? SeparableSum(NormL1(0.1), lc) : SeparableSum(lc, NormL1(0.1)))
    r = solve!(x, f, gl, method, opt)
    xd = k == 1 ? (zeros(p, p), zeros(2, 2)) : (zeros(2, 2), zeros(p, p))
    rd = solve!(xd, f, gl, method, opt)
    @test Matrix(x[1]) ≈ xd[1] atol = 1e-6
    @test Matrix(x[2]) ≈ xd[2] atol = 1e-6
    @test r.minimum ≈ rd.minimum rtol = 1e-8
  end
  @test PSR._dense_route(x, g)
  @test PSR._owner_scratch(x, g)[k] isa SymmetricSparseIterate
  @test PSR._l0_tuple_owner() == l0_tuple_owner()
end

# The owner scratch, reused across steps, gives its block the matrix, the active coordinates in
# their order and the values that a new owner scratch gives: after a step with nonzero results,
# after one with zeros where there were nonzeros, after a refused step (an asymmetric trial point of
# the constrained block), and after the next step. The constrained block, whose proximal point the
# reference computes with a second call on the same penalty object, is compared to rounding.
@testset "a reused owner scratch acts as a new one" begin
  lc = Constrained(NormL1(0.1), IndHyperplane(1.0, 0.0))
  g = SeparableSum(lc, NormL1(0.3))
  x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
  s = osc(2)
  w = (zeros(2, 2), s)
  zs = (([0.5 0.4; 0.4 0.2], [1.0 -0.8; -0.8 0.6]), ([0.3 0.1; 0.1 0.4], [0.1 0.9; 0.9 -0.2]),
        ([1.0 0.3; 0.8 -0.4], [0.5 0.5; 0.5 0.5]), ([0.2 0.0; 0.0 0.1], [-0.7 0.0; 0.0 0.9]))
  for (step, z) in enumerate(zs)
    fresh = map(copy, x)
    before = map(owner_state, x)
    err = try
      PSR._metric_prox!(x, g, z, 1.0, nothing, w)
      nothing
    catch e
      e
    end
    if step == 3
      @test err isa ArgumentError
      @test isequal(map(owner_state, x), before)
      continue
    end
    @test err === nothing
    PSR._metric_prox!(fresh, g, z, 1.0, nothing, (zeros(2, 2), osc(2)))
    @test isequal(owner_state(x[2]), owner_state(fresh[2]))
    @test Matrix(x[1]) ≈ Matrix(fresh[1]) atol = 1e-14
  end
  @test nactive(x[2]) < ncoordinates(x[2])     # the second step set coordinates of the L1 block to zero
  # the owner output and owner input of an IndBallL0 block, where ProximalBase has its step
  if l0_tuple_owner()
    g0 = SeparableSum(lc, IndBallL0(1; diagonal = false))
    x = (SymmetricSparseIterate(2), SymmetricSparseIterate(2))
    s0 = osc(2; input = true)
    for z in (([0.5 0.4; 0.4 0.2], [1.0 -0.8; -0.8 0.6]), ([0.3 0.1; 0.1 0.4], [0.1 0.9; 0.9 -0.2]),
              ([0.2 0.0; 0.0 0.1], [-0.7 0.0; 0.0 0.9]))
      fresh = map(copy, x)
      PSR._metric_prox!(x, g0, z, 1.0, nothing, (zeros(2, 2), s0))
      PSR._metric_prox!(fresh, g0, z, 1.0, nothing, (zeros(2, 2), osc(2; input = true)))
      @test isequal(owner_state(x[2]), owner_state(fresh[2]))
      @test count(!iszero, Matrix(x[2])[i, j] for j in 1:2 for i in j+1:2) <= 1
    end
  end
end

@testset "errors" begin
  f = SeparableSum(SqrNormL2(), SqrNormL2())
  g = SeparableSum(NormL1(0.1), NormL1(0.1))
  @test_throws DimensionMismatch solve!((zeros(3), zeros(4)), f, g, ADMMSolver(); u = (zeros(3), zeros(5)))
  @test_throws DimensionMismatch solve!((zeros(3), zeros(4)), f, g, ADMMSolver(); u = (zeros(3),))
  @test_throws ArgumentError solve!((zeros(3), zeros(4)), f, g, ProximalGradientDescent(; debias = 1))
end

end
