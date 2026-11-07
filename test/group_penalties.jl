# Block coordinate descent on an AtomIterate with penalties other than
# GroupNormL2: the group norms of ProximalBase through their own block step, and
# separable penalties entry by entry after the group's gradient step.

module GroupPenaltiesTests

using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase
using ProximalSolvers
const PS = ProximalSolvers

function groupdata(; n = 80, p = 60, seed = 21)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  β = zeros(p); β[1:4] .= [2, -1.5, 1, -1]; β[11:13] .= [1, 1, -1]
  X, X * β + 0.3 * randn(rng, n)
end

# a reference solution by accelerated proximal gradient to high accuracy
function reference(f, g, x0)
  res = solve!(copy(x0), f, g, AccProxGradDescent(), ProximalOptions(; maxiter = 50_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-12))
  res.minimizer
end

@testset "GroupNormLinf" begin
  X, y = groupdata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  λ = 0.1 * maximum(G -> norm(X[:, G]' * y, 1), groups) / n
  g = GroupNormLinf(λ, groups)
  for f in ((1 / n) * LeastSquaresLoss(y, X), QuadraticFunction(X' * X / n, -X' * y / n))
    for order in (:cyclic, :random)
      x = AtomIterate(Float64, p, groups)
      r = solve!(x, f, g, CDSolver(; order, tol = 1e-12))
      @test r.converged
      xref = reference(f, g, zeros(p))
      @test Vector(x) ≈ xref atol = 1e-6
      @test f(Vector(x)) + g(Vector(x)) ≈ f(xref) + g(xref) rtol = 1e-10
      # optimality of the zero groups: ‖∇_G f‖₁ ≤ λ wₖ
      grad = gradient(f, Vector(x))
      for (k, G) in enumerate(groups)
        all(iszero, Vector(x)[G]) && @test norm(grad[G], 1) <= λ + 1e-8
      end
    end
  end
  # a dense vector becomes an AtomIterate with the groups of g
  f = (1 / n) * LeastSquaresLoss(y, X)
  xd = zeros(p)
  solve!(xd, f, g, CDSolver(; tol = 1e-12))
  @test xd ≈ reference(f, g, zeros(p)) atol = 1e-6
  # the iterate must have the groups of g
  @test_throws ArgumentError solve!(SparseIterate(p), f, g, CDSolver())
  @test_throws ArgumentError solve!(AtomIterate(Float64, p, [1:p]), f, g, CDSolver())
end

@testset "separable penalties on an AtomIterate" begin
  X, y = groupdata(; seed = 22)
  n, p = size(X)
  groups = [i:i+2 for i in 1:3:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  λ = 0.1 * norm(X' * y, Inf) / n
  for g in (NormL1(λ), ElasticNet(λ, 0.1), IndBox(-0.5, 0.5))
    xa = AtomIterate(Float64, p, groups)
    solve!(xa, f, g, CDSolver(; tol = 1e-12))
    xs = SparseIterate(p)
    solve!(xs, f, g, CDSolver(; tol = 1e-12))
    @test Vector(xa) ≈ Vector(xs) atol = 1e-7
  end
end

@testset "a group that f does not depend on" begin
  X, y = groupdata(; seed = 23)
  n, p = size(X)
  X[:, 6:10] .= 0
  groups = [i:i+4 for i in 1:5:p]
  f = (1 / n) * LeastSquaresLoss(y, X)
  x = AtomIterate(ones(p), groups)
  solve!(x, f, GroupNormLinf(0.01, groups), CDSolver(; tol = 1e-10))
  @test all(iszero, Vector(x)[6:10])             # the minimizer of the penalty
  x = AtomIterate(ones(p), groups)
  solve!(x, f, GroupNormLinf(0.01, groups, [1, 0, ones(length(groups) - 2)...]), CDSolver(; tol = 1e-10))
  @test all(==(1), Vector(x)[6:10])              # an unpenalized group keeps its values
end

@testset "weighted gradients after large group steps" begin
  # The specialized L2 step needs |G| entries and the generic Linf step needs
  # 2|G|. Both can exceed the n entries of the weighted-gradient workspace.
  n = 12
  for T in (Float32, Float64), sparse_design in (false, true), fit_intercept in (false, true),
      (penalty, groups) in ((GroupNormL2, [1:15, 16:18]), (GroupNormLinf, [1:7, 8:10]))
    rng = Xoshiro(59)
    p = last(last(groups))
    X = randn(rng, T, n, p)
    X[rand(rng, n, p) .< 0.5] .= 0
    A = sparse_design ? sparse(X) : X
    y = randn(rng, T, n)
    w = rand(rng, T, n) .+ T(0.5)
    offset = T(0.1) .* randn(rng, T, n)
    f = (one(T) / n) * GLMLoss(ProximalBase.Squared(), y, A; weights = w, offset)
    x = AtomIterate(T(0.1) .* randn(rng, T, p), groups)
    m = cdmodel(f, x; intercept = fit_intercept)
    g = penalty(T(0.05), groups, ones(T, length(groups)))
    PS.initialize!(m, x)
    grad = zeros(T, p)
    atol = T === Float32 ? 2f-6 : 1e-13
    rtol = T === Float32 ? 2f-5 : 1e-12
    for _ in 1:2, k in eachindex(groups)
      PS._groupstep!(m, g, x, k, false)
      PS.gradient!(grad, m, x)
      b0 = fit_intercept ? PS.intercept(m, x) : zero(T)
      residual = y .- offset .- b0 .- A * Vector(x)
      expected = -(transpose(A) * (w .* residual)) / n
      @test grad ≈ expected atol = atol rtol = rtol
      @test PS.residuals(m) ≈ residual atol = atol rtol = rtol
    end
  end
end

@testset "weighted paths with a group larger than n" begin
  n, p = 12, 18
  groups = [1:15, 16:18]
  for T in (Float32, Float64), sparse_design in (false, true), fit_intercept in (false, true)
    rng = Xoshiro(60)
    X = randn(rng, T, n, p)
    X[rand(rng, n, p) .< 0.5] .= 0
    A = sparse_design ? sparse(X) : X
    y = A[:, 1] .+ T(0.2) .* randn(rng, T, n) .+ T(0.5)
    w = rand(rng, T, n) .+ T(0.5)
    f = (one(T) / n) * GLMLoss(ProximalBase.Squared(), y, A; weights = w)
    g = GroupNormL2(one(T), groups, ones(T, length(groups)))
    x = AtomIterate(T, p, groups)
    m = cdmodel(f, x; intercept = fit_intercept)
    λmax = lambda_max(m, g, x)
    λs = λmax .* T[1.01, 0.6, 0.3]
    tol = T === Float32 ? 2e-5 : 1e-10
    method = CDSolver(; order = :cyclic, tol)
    screened = solve_path(m, g, λs, method; x, gaptol = 0)
    xplain = AtomIterate(T, p, groups)
    plain = solve_path(cdmodel(f, xplain; intercept = fit_intercept), g, λs, method;
                       x = xplain, screening = false, gaptol = 0)
    @test all(screened.converged) && all(plain.converged)
    @test all(screened.kkt_checks .>= 1)
    @test iszero(norm(screened.solutions[1]))
    @test norm(screened.solutions[end]) > 0
    @test screened.values ≈ plain.values rtol = (T === Float32 ? 5e-4 : 1e-8)
  end
end

@testset "allocations" begin
  X, y = groupdata()
  n, p = size(X)
  groups = [i:i+4 for i in 1:5:p]
  # the group curvatures, which initialize! resets, are kept from the first run:
  # computing them allocates (ProximalSolvers #20), the steps must not
  function passes_bytes(x, m, g, s)
    PS.initialize!(m, x)
    st = PS._CDState(Float64, x, s.random)
    PS._cd!(x, m, g, st, s)
    L = copy(m.L)
    fill!(x, 0.0); PS.initialize!(m, x)
    copyto!(m.L, L)
    @allocated PS._cd!(x, m, g, st, s)
  end
  for f in ((1 / n) * LeastSquaresLoss(y, X), QuadraticFunction(X' * X / n, -X' * y / n)),
      g in (GroupNormLinf(0.05, groups), NormL1(0.05)),
      s in (CDSolver(; order = :cyclic), CDSolver(; order = :random), CDSolver(; momentum = true))
    x = AtomIterate(Float64, p, groups)
    @test passes_bytes(x, cdmodel(f, x), g, s) == 0
  end
  # a weighted model whose groups need more scratch space than its n entries
  Xw, yw = X[1:20, :], y[1:20]
  big = [1:15, 16:30, 31:45, 46:60]
  fw = GLMLoss(ProximalBase.Squared(), yw, Xw; weights = rand(Xoshiro(3), 20) .+ 0.5)
  for g in (GroupNormL2(0.5, big), GroupNormLinf(0.5, big), SparseGroupNormL2(0.2, 0.5, big)),
      s in (CDSolver(), CDSolver(; momentum = true))
    x = AtomIterate(Float64, p, big)
    @test passes_bytes(x, cdmodel(fw, x), g, s) == 0
  end
end

# LSModel kept the scratch space of the group steps in the buffer of the weighted
# gradient, which then no longer had n entries (ProximalSolvers #59)
@testset "weighted models with groups larger than n" begin
  rng = Xoshiro(59)
  n, p = 20, 60
  X, y = randn(rng, n, p), randn(rng, n)
  w = rand(rng, n) .+ 0.5
  f = GLMLoss(ProximalBase.Squared(), y, X; weights = w)
  wgrad(β) = -X' * (w .* (y - X * β))

  # the reproduction of the issue: the strong rule takes the gradient after the
  # group steps
  groups = [1:30, 31:60]
  λmax = lambda_max(f, GroupNormL2(1.0, groups), AtomIterate(p, groups))
  λs = λmax .* [1.0, 0.5, 0.25, 0.1]
  path = solve_path(f, GroupNormL2(1.0, groups), λs, CDSolver(; tol = 1e-12); x = AtomIterate(p, groups), gaptol = 0)
  @test all(path.converged)
  plain = solve_path(f, GroupNormL2(1.0, groups), λs, CDSolver(; tol = 1e-12); x = AtomIterate(p, groups), screening = false, gaptol = 0)
  @test all(norm(Vector(a) - Vector(b)) <= 1e-8 * (1 + norm(Vector(b))) for (a, b) in zip(path.solutions, plain.solutions))
  @test path.values ≈ plain.values rtol = 1e-12
  # duality gaps and gap-safe screening also take the gradient
  for s in (CDSolver(; gaptol = 1e-10), CDSolver(; tol = 1e-12, gapsafe = true))
    x = AtomIterate(Float64, p, groups)
    r = solve!(x, f, GroupNormL2(λs[3], groups), s)
    @test r.converged
    @test Vector(x) ≈ Vector(plain.solutions[3]) atol = 1e-6
  end

  # the generic block step, which takes 2|G| entries, along warm-started levels
  # on one model, whose gradient must stay right
  groups = [1:12, 13:24, 25:36, 37:48, 49:60]
  for g0 in (GroupNormLinf(1.0, groups), SparseGroupNormL2(0.5, 0.5, groups))
    x = AtomIterate(Float64, p, groups)
    m = cdmodel(f, x)
    λ0 = maximum(G -> norm(wgrad(zeros(p))[G], Inf), groups)
    for λ in λ0 .* [0.5, 0.2, 0.1]
      g = g0 isa GroupNormLinf ? GroupNormLinf(λ, groups) : SparseGroupNormL2(λ / 2, λ / 2, groups)
      r = solve!(x, m, g, CDSolver(; tol = 1e-12))
      @test r.converged
      grad = zeros(p)
      PS.gradient!(grad, m, x)
      @test grad ≈ wgrad(Vector(x)) atol = 1e-10
      xref = reference(f, g, zeros(p))
      @test f(Vector(x)) + g(Vector(x)) ≈ f(xref) + g(xref) rtol = 1e-9
    end
    @test length(m.tmp) == n
  end
end

# FT28 (#165): block trials without private writes. The group step builds its trial point in the model's buffer
# and the penalty's five-argument prox_coordinate! stores the result, so only that call writes the iterate.
#
# Recorded steps, from the base commit 412063d8ac24b84a10ccde09cf072bb396109ffd (the audited behaviour, which
# staged the trial point in the entries of the iterate) on ProximalBase 0.5.4, Julia 1.13.3, Float64. Each key is
# "model/penalty/layout/curvature" for the data of `ft28_setup` (seeds 23 and 3), each entry the string
# "h ‖x‖² ‖cache‖₁ active" of one step, h = the returned scaled change, ‖x‖² = sum(abs2, x), ‖cache‖₁ = the
# residuals of the least-squares model, or Ax of the quadratic one, active = activecoordinates(x) after the step
# ("-" for none); floats are the hex digits of the bit pattern. The steps visit groups 2, 3, 4, 5, 6, 1 from a start
# in which groups 1 and 3 are active (a stored zero in group 3), at the penalty level `mid` = 0.03 max ‖X_G' y‖ / n
# without and with scaling, and at `big` = 40 times that (every prox result zero), in this order:
# (mid, unscaled), (big, unscaled), then (mid, scaled) for GroupNormLinf only.
const FT28 = Dict{String,Vector{String}}(
  "LS/Linf/contig/std" => [
    "3fd49d46d9415331 3ffad19a16c800f4 404a08317a6d98da 1,3,2",
    "3fe292b16a3e44b2 3ff2d1af5b905c49 4045b5db8f09ff53 1,3,2",
    "3fc89044946664d4 3ff3b264619d426f 40448ef6fabe9aea 1,3,2,4",
    "3fcf9f575d1607b0 3ff5b0f72212094b 40433606fec3deba 1,3,2,4,5",
    "3fcb11af88e8df02 3ff6bec59bbc5c60 404232acb3c2c0d8 1,3,2,4,5,6",
    "3fd1087a5fa152f0 3ff2a4b867013d0c 40401954e1d2ad9d 1,3,2,4,5,6",
    "3f8a69fdf90b51e8 3ff8dca920ca79d4 404c586670532ed8 1,3,2",
    "3fe2298915303812 3fee70210e3f3499 4048295cdf599565 1,3,2",
    "3fa6782e6e53b542 3feebf041e442e33 4047716bf3c4601c 1,3,2,4",
    "3fb1e440817b2ca7 3fef732f5872df38 40461b0a4f0e3d6d 1,3,2,4,5",
    "0 3fef732f5872df38 40461b0a4f0e3d6d 1,3,2,4,5",
    "3fd99f30f38fb518 3fce1f679885e598 40416f6848a9eaf0 1,3,2,4,5",
    "3fd4bd73104e54d1 3ffad19a16c800f4 404a08317a6d98da 1,3,2",
    "3fe223a905560aba 3ff2d1af5b905c49 4045b5db8f09ff53 1,3,2",
    "3fc637a8c002e59d 3ff3b264619d426f 40448ef6fabe9aea 1,3,2,4",
    "3fd2b6cf34d8d095 3ff5b0f72212094b 40433606fec3deba 1,3,2,4,5",
    "3fcc940901fafdcf 3ff6bec59bbc5c60 404232acb3c2c0d8 1,3,2,4,5,6",
    "3fd54da01e2dbba8 3ff2a4b867013d0c 40401954e1d2ad9d 1,3,2,4,5,6"],
  "LS/Linf/contig/zerocurv" => [
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe3e03fec62817c 3ff150e49a81119e 40476290e5f64a50 1,3",
    "3fc81883d784c857 3ff287192ba17168 40454f930a5eb5e8 1,3,4",
    "3fca6e28aff52ce6 3ff46cdcd855070c 404362bd9e346b4d 1,3,4,5",
    "3fd1a5d5c1e01069 3ff5c9ece886a08e 4042f679402c8783 1,3,4,5,6",
    "3fd040919146b960 3ff0dff3969ba1d3 4040e83d80682a54 1,3,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe22c5a8620b784 3fee6a5e688bd9bc 404857f5f102910c 1,3",
    "3fa72b2864aece3e 3feebe3dbde74a04 40479a4bdf2229c7 1,3,4",
    "3fb1b82d9c179c3d 3fef6f412c2d6ece 404646d273a512af 1,3,4,5",
    "0 3fef6f412c2d6ece 404646d273a512af 1,3,4,5",
    "3fd9bf6d45473da4 3fcd828244033435 404179b3ff21a989 1,3,4,5",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe3696d77f2453a 3ff150e49a81119e 40476290e5f64a50 1,3",
    "3fcbb6d308432ad2 3ff287192ba17168 40454f930a5eb5e8 1,3,4",
    "3fcec108f8dfb194 3ff46cdcd855070c 404362bd9e346b4d 1,3,4,5",
    "3fd2a1b78eacf78b 3ff5c9ece886a08e 4042f679402c8783 1,3,4,5,6",
    "3fd4539992aad605 3ff0dff3969ba1d3 4040e83d80682a54 1,3,4,5,6"],
  "LS/Linf/strided/std" => [
    "3fb2f503f6d2a2d0 3ff8fdbd76b52a13 404b42b58dec6f4f 1,3,2",
    "3fd9653af0e05770 3ff1f238370dc616 40453765175293d0 1,3,2",
    "3fc069006f6d1b2b 3ff29864b9bd02e8 4044293c25a4145a 1,3,2,4",
    "3fcc131559becaec 3ff44d74db23a58c 40433f056e63b1c7 1,3,2,4,5",
    "3fc673e18b5d1ddf 3ff5159584edd6bd 4041f26f42875b78 1,3,2,4,5,6",
    "3fc403dd369a5ad2 3fee732d4afb4e8d 4040e9f26b1d9ac4 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fdca5c2d6c2d683 3feee76b1da0f174 40463df143228459 1,3",
    "3f757eac0c46adcd 3feee88be1f1d585 40462f72155cfeb1 1,3,4",
    "3fa821211d963e02 3fef326aa564de43 4045c26fc22b9419 1,3,4,5",
    "0 3fef326aa564de43 4045c26fc22b9419 1,3,4,5",
    "3fda610f57b29a6e 3fd04142306a1788 40434fd140af5530 1,3,4,5",
    "3fb3129a097fefd5 3ff8fdbd76b52a13 404b42b58dec6f4f 1,3,2",
    "3fdb9d2f7eb95acd 3ff1f238370dc616 40453765175293d0 1,3,2",
    "3fbfeeea01ce175c 3ff29864b9bd02e8 4044293c25a4145a 1,3,2,4",
    "3fd09d4dcd9011e8 3ff44d74db23a58c 40433f056e63b1c7 1,3,2,4,5",
    "3fc7ab1faf459073 3ff5159584edd6bd 4041f26f42875b78 1,3,2,4,5,6",
    "3fc414891f50ae80 3fee732d4afb4e8d 4040e9f26b1d9ac4 1,3,2,4,5,6"],
  "LS/Linf/strided/zerocurv" => [
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fd94ec9cd16c134 3ff1c76396fae8c7 40453a4c70ae0657 1,3",
    "3fbd3a4e949b1f4b 3ff2522dcbabc9ac 404447332bd7f0aa 1,3,4",
    "3fcdc5f990feff13 3ff44b6068a2e7d9 404356da5cd0b631 1,3,4,5",
    "3fc66379064b2830 3ff50f98c9e1e4e2 40421389e8e40a71 1,3,4,5,6",
    "3fc47b15d64f8eca 3fee0f2241c4eeca 4040e95c1b575e5c 1,3,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fdca5c2d6c2d683 3feee76b1da0f174 40463df143228459 1,3",
    "3f757eac0c46adcd 3feee88be1f1d585 40462f72155cfeb1 1,3,4",
    "3fa821211d963e02 3fef326aa564de43 4045c26fc22b9419 1,3,4,5",
    "0 3fef326aa564de43 4045c26fc22b9419 1,3,4,5",
    "3fda610f57b29a6e 3fd04142306a1788 40434fd140af5530 1,3,4,5",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fdb84c873f15e63 3ff1c76396fae8c7 40453a4c70ae0657 1,3",
    "3fbc7013400c72d2 3ff2522dcbabc9ac 404447332bd7f0aa 1,3,4",
    "3fd19eac0595e597 3ff44b6068a2e7d9 404356da5cd0b631 1,3,4,5",
    "3fc799d3b5daff6c 3ff50f98c9e1e4e2 40421389e8e40a71 1,3,4,5,6",
    "3fc38dbbdd8519c6 3fee0f2241c4eeca 4040e95c1b575e5c 1,3,4,5,6"],
  "LS/Linf/vecperm/std" => [
    "3faf914b21a5a16c 3ff90ab9502b1984 40489567813ee6e1 1,3,2",
    "3fdd23a1895257c4 3ff2dc832f2fbbfb 40446720738ecb16 1,3,2",
    "3fcfaf7cb0dc787c 3ff4da481d47e07e 4042f6850a0d47ec 1,3,2,4",
    "3fc4cc0310891c3f 3ff611d31bb8480a 404205499681f028 1,3,2,4,5",
    "3fc834ccd236e3f6 3ff6ea59b99c3e56 4041d1b08a974efc 1,3,2,4,5,6",
    "3fd0a9e645702b3d 3ff0fecc55960d7d 404055123f07be72 1,3,2,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fdd76dd3d19cb93 3fef3c7556a0c218 404594085b9ec17d 1,3",
    "3fa7520e5533a78d 3fef916f39b48cc1 40451c9c94e76008 1,3,4",
    "3f917920ef4b5bb3 3fef9d5c5693dd4b 4044d9b62b78ebf5 1,3,4,5",
    "3f9646b119d1e043 3fefb0be9a2d8c67 4044bfe8a8e34a66 1,3,4,5,6",
    "3fdd0dc098e29614 3fca7f4da3d4f381 4040a7c0784a2700 1,3,4,5,6",
    "3fb129a47ac1196c 3ff90ab9502b1984 40489567813ee6e1 1,3,2",
    "3fdf2f6e6206b572 3ff2dc832f2fbbfb 40446720738ecb16 1,3,2",
    "3fcfe0f03dcdc269 3ff4da481d47e07e 4042f6850a0d47ec 1,3,2,4",
    "3fc6ebfbd7f17645 3ff611d31bb8480a 404205499681f028 1,3,2,4,5",
    "3fc951954160b13a 3ff6ea59b99c3e56 4041d1b08a974efc 1,3,2,4,5,6",
    "3fd3b91ab6eb7902 3ff0fecc55960d7d 404055123f07be72 1,3,2,4,5,6"],
  "LS/Linf/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fdd76dd3d19cb93 3ff2cb9d9a1dd2c7 40449f66ce21bb05 1,3",
    "3fcc7bed94b2ec2f 3ff4bd2a578e5633 4043172c8ec85f75 1,3,4",
    "3fc745fd0791fa2f 3ff6414cdd4c0824 4041e417b1c77bd8 1,3,4,5",
    "3fc9f04b9d51536b 3ff7280ca0903847 4041c62ffec70757 1,3,4,5,6",
    "3fd1a1cc31f5557c 3ff0f4925c9703ba 40402f77b2eb08c9 1,3,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fdd76dd3d19cb93 3fef3c7556a0c218 404594085b9ec17d 1,3",
    "3fa7520e5533a78d 3fef916f39b48cc1 40451c9c94e76008 1,3,4",
    "3f917920ef4b5bb3 3fef9d5c5693dd4b 4044d9b62b78ebf5 1,3,4,5",
    "3f9646b119d1e043 3fefb0be9a2d8c67 4044bfe8a8e34a66 1,3,4,5,6",
    "3fdd0dc098e29614 3fca7f4da3d4f381 4040a7c0784a2700 1,3,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fdf888244d52629 3ff2cb9d9a1dd2c7 40449f66ce21bb05 1,3",
    "3fcca8620ce8a66b 3ff4bd2a578e5633 4043172c8ec85f75 1,3,4",
    "3fc9a6bc53228985 3ff6414cdd4c0824 4041e417b1c77bd8 1,3,4,5",
    "3fcb2175b47e056e 3ff7280ca0903847 4041c62ffec70757 1,3,4,5,6",
    "3fd4de8408fa02a9 3ff0f4925c9703ba 40402f77b2eb08c9 1,3,4,5,6"],
  "LS/SGL/contig/std" => [
    "3fd432a8ddcf1104 3ffab177e37b4eb6 404a19de74288a92 1,3,2",
    "3fe24ed61a995296 3ff286612ccaa16c 4045a98da25608fb 1,3,2",
    "3fc857e9f7a3f146 3ff35a7e106b812c 40447ef9b5445246 1,3,2,4",
    "3fcf1bd5d2e26af0 3ff53a4dee7cf9a3 4043318605bec32b 1,3,2,4,5",
    "3fca69de138a731e 3ff62558ab8c9e30 40423db34c9f0692 1,3,2,4,5,6",
    "3fd0004b74b4783e 3ff15e191243e8e8 403fce3991cba662 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SGL/contig/zerocurv" => [
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe38b07a32d209b 3ff11bb2c24a6617 404764eded30643a 1,3",
    "3fc7fcfbb686448d 3ff23cd6ffb1caf7 4045698bb06a885b 1,3,4",
    "3fcaf22db947432b 3ff4027c7bfa42c1 4043781d8fc3f0cc 1,3,4,5",
    "3fd0e85fbc407063 3ff5385d58d00041 4042f91acfdfc324 1,3,4,5,6",
    "3fceb675f7db4009 3fef5695493a92fe 4040b3c747144b7b 1,3,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SGL/strided/std" => [
    "3fb1dee7bc2a388e 3ff8f5ae623935ce 404b4b56bd1b8895 1,3,2",
    "3fd9df5e67289192 3ff1c4baeb6af6b8 4045325e825629c2 1,3,2",
    "3fc00be02601a2c3 3ff252c753409709 40443d74cecee6ba 1,3,2,4",
    "3fcbafbce534c388 3ff3e11a13e012fd 404354c009d9b3c0 1,3,2,4,5",
    "3fc5c00b38d037e4 3ff48bdecbb16646 4042199a460a2b32 1,3,2,4,5,6",
    "3fc59136bc6302b0 3fec67eb4dd4744f 40410e86f0087587 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SGL/strided/zerocurv" => [
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fd9dec62bf55ce0 3ff1a1ffa19d9c5f 40452ae049c88892 1,3",
    "3fbc9bc13d29fd5d 3ff217040e75eb51 404450cd3f755beb 1,3,4",
    "3fcd2d8f8d7ad9cf 3ff3dd541bd1c352 40434e0388b3174b 1,3,4,5",
    "3fc594437bebd22e 3ff48402b69938ba 40422660590b3c18 1,3,4,5,6",
    "3fc5458a44a01f44 3fec04d5c55a4ddd 404103889597c146 1,3,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SGL/vecperm/std" => [
    "3fae95c7c8b31cb1 3ff8fe1e0b9fd735 40489f282e6d7c4b 1,3,2",
    "3fddb8d2c375cc32 3ff2a0a1b947f611 404467831e3c45ca 1,3,2",
    "3fced44a4447ebcf 3ff46bfb35662f3d 404305e1c1be8c21 1,3,2,4",
    "3fc4846c480bc79c 3ff579bdee0c597e 4042105ae8ec9fcf 1,3,2,4,5",
    "3fc7ee933da46397 3ff639bcc0887f6e 4041f0f111b39493 1,3,2,4,5,6",
    "3fd21d27d5233bde 3fef6e5fc1467a33 40404811e1b7c139 1,3,2,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SGL/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fddfa873b9e61b4 3ff2917b04886aad 4044a00e59482abc 1,3",
    "3fcc3694a8af5d07 3ff44de09b69dc36 404337ee799ad75c 1,3,4",
    "3fc6756ee7e28b43 3ff596406ad3a99e 404200c561a3b2c1 1,3,4,5",
    "3fc93f4cfff31d6a 3ff661fd04928049 4041e9da6e918c12 1,3,4,5,6",
    "3fd2ff75a597cb73 3fef4c120c804f6f 40403cc8c11eeb62 1,3,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/L1/contig/std" => [
    "3fd49d46d9415331 3ffabef007121ea4 404a12acd77f42b5 1,3,2",
    "3fe21d60f5a168cc 3ff29a42bd4f93c9 4045a8567447ddd5 1,3,2",
    "3fc8f59a5afc702f 3ff373b393bcf22c 4044812348299254 1,3,2,4",
    "3fcfa200bada89a8 3ff55efaf17b4a84 4043336a722daffc 1,3,2,4,5",
    "3fcb1c7109de066b 3ff6517d4bd0c5de 40423eb66cee472d 1,3,2,4,5,6",
    "3fcfd11e6f7a4f9b 3ff196c1ab288bf4 403fc41827e8163e 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/L1/contig/zerocurv" => [
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe36ea92d6937aa 3ff122c1eefd241a 40476103b841ea08 1,3",
    "3fc861f5d2cb5959 3ff248539ac02f6f 4045636297a3d63f 1,3,4",
    "3fcb651d7e5acab8 3ff416a0e990df75 404374923f5f1b34 1,3,4,5",
    "3fd15adb56401bcb 3ff558d4e6f76f2d 4042f5183d98443a 1,3,4,5,6",
    "3fce6f4187f17fdb 3fefa95c4a2a0fe7 4040b318940ffe0c 1,3,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/L1/strided/std" => [
    "3fb2f503f6d2a2d0 3ff8f7e98301d58c 404b4cbcd35452da 1,3,2",
    "3fd9ef45a32e4984 3ff1d0eb71c48102 40452a8396b58beb 1,3,2",
    "3fc084b960a8c906 3ff262b05d463a9b 40443735c483d2e4 1,3,2,4",
    "3fcc28130793845a 3ff3f7f3956bca06 404352b0ea7faf73 1,3,2,4,5",
    "3fc65b38063f83b8 3ff4a504a184b1f6 40420e43abf30b1e 1,3,2,4,5,6",
    "3fc562288eb88806 3fecb5b87c955132 4041101c50acebaa 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe42b97e9870bd0 3f146fb693daf7da 4043f460dede513e 1,3"],
  "LS/L1/strided/zerocurv" => [
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fd9f6adb7fd12b6 3ff1ac04df6f9740 40451d3a3ce1c196 1,3",
    "3fbd4d47cc19484b 3ff22309a8759b6c 404448506290979b 1,3,4",
    "3fcd951fbb99d99f 3ff3f13e0c8b8570 4043472b0f0c4f14 1,3,4,5",
    "3fc61c6e966f77d9 3ff498f20f5d7f46 404219131f18a5f3 1,3,4,5,6",
    "3fc509ab0d294a6a 3fec42c469ace471 4040fdcc50e27ebd 1,3,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe42b97e9870bd0 3f146fb693daf7da 4043f460dede513e 1,3"],
  "LS/L1/vecperm/std" => [
    "3faf914b21a5a16c 3ff8fe8a9d66c6e7 4048a06e45fbd549 1,3,2",
    "3fddfbe20af14a00 3ff2adc0db9c8fe7 40446a7d5e39593e 1,3,2",
    "3fcf5f3ddc73f666 3ff47e60cdb77dd8 404308d5a83cdf18 1,3,2,4",
    "3fc4ae6b5dd285bb 3ff58fe79a847321 40421952442ffaaa 1,3,2,4,5",
    "3fc857f5845dbaa8 3ff650adf87203a0 4041fd1ae94421d9 1,3,2,4,5,6",
    "3fd1e3eb213a4290 3fefba0d1177fb55 404052e543e2aa8f 1,3,2,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 3f7ad2001594d8a9 404375dfbc339c83 1,3"],
  "LS/L1/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fde40fd19d9295e 3ff29c5253bd31be 4044a4c01f88e62c 1,3",
    "3fccb592dd584afe 3ff45c25a2da5355 40433d36f55cbe8d 1,3,4",
    "3fc699edb9cb8867 3ff5a8de3ee11793 40420a88ba78bbdc 1,3,4,5",
    "3fc9b63119b2f379 3ff675ce83997cb7 4041f46b4728abdf 1,3,4,5,6",
    "3fd2d020ce1bf152 3fef9163ea682fc8 40404bb02e1b1904 1,3,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 3f7ad2001594d8a9 404375dfbc339c83 1,3"],
  "LS/MCP/contig/std" => [
    "3fd563026c85091a 3ffaf20b15897e8f 4049f4af227da71c 1,3,2",
    "3fe287182faa9f47 3ff30c4588e45abc 4045b54d605e597b 1,3,2",
    "3fc9e47c0b307faf 3ff3fc661c712a8d 4044905b0295c5bc 1,3,2,4",
    "3fd0a002cffa38a6 3ff610f2f3364452 404332756c02098d 1,3,2,4,5",
    "3fccc721e923e267 3ff73928df9377e0 40422d7f065f3888 1,3,2,4,5,6",
    "3fd0e299c4390ce4 3ff36d56a7478834 4040232353be69da 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/MCP/strided/std" => [
    "3fb49aeedfd0d413 3ff900be154d2cf7 404b44f01f6bd789 1,3,2",
    "3fd954489952c72f 3ff214b0361bceff 40452f43a238f71e 1,3,2",
    "3fc20df54ad70b88 3ff2ca14d0fd6fd7 40441ada81305f89 1,3,2,4",
    "3fcd7c6c8c8ddb6d 3ff490e615abbcbc 40433dcb68a52a8f 1,3,2,4,5",
    "3fc7d9e881e9dfce 3ff567f9d54cc6b8 4041e28f3b939002 1,3,2,4,5,6",
    "3fc3ba9af293ffd2 3fef891322c0dc84 4040ef997ef0583c 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/MCP/vecperm/std" => [
    "3fb1aa717a1f03e6 3ff90cbbca324ffc 4048922c3202f174 1,3,2",
    "3fdd2723f1e2d69a 3ff30954f47b85a1 40446edc8c37a8cd 1,3,2",
    "3fd0ab94423a6305 3ff525d27308d8d1 4042fcf516568f74 1,3,2,4",
    "3fc592cbf0b05a5f 3ff66dbf62950e62 404216d68cc135aa 1,3,2,4,5",
    "3fc957e048c55924 3ff750ae77cbc9b1 4041ebaf39e3f6b9 1,3,2,4,5,6",
    "3fd022b37d766786 3ff1ab3e703f43a0 4040685cf5d6a371 1,3,2,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SCAD/contig/std" => [
    "3fd563026c85091a 3ffaf20b15897e8f 4049f4af227da71c 1,3,2",
    "3fe287182faa9f47 3ff30c4588e45abc 4045b54d605e597b 1,3,2",
    "3fc9e47c0b307faf 3ff3fc661c712a8d 4044905b0295c5bc 1,3,2,4",
    "3fd0a002cffa38a6 3ff610f2f3364452 404332756c02098d 1,3,2,4,5",
    "3fccc721e923e267 3ff73928df9377e0 40422d7f065f3888 1,3,2,4,5,6",
    "3fd0e299c4390ce4 3ff36d56a7478834 4040232353be69da 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404c84298f4a44f7 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "0 3fee33e917e06a97 4048ab20333c8ab8 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SCAD/strided/std" => [
    "3fb302d79203ae53 3ff8fadf0159515e 404b47700ee9edd3 1,3,2",
    "3fd953dbc35bd4ec 3ff20e13b635b7fd 40452efdd0c33a47 1,3,2",
    "3fc1e7029bb300f5 3ff2c0c26a9ebd8d 40441b4ea01dcf19 1,3,2,4",
    "3fcd9ec138030201 3ff48cd340b8ea84 40433f3ba1dceeb7 1,3,2,4,5",
    "3fc7d7180f55a44e 3ff5636f08c1e1ff 4041e24c45bb7067 1,3,2,4,5,6",
    "3fc3b09e1f86d462 3fef784c463fc449 4040ee90d2d29f17 1,3,2,4,5,6",
    "0 3ff8d944e5404803 404b832cff1b7e41 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "0 3fee33e917e06a97 404630a56fc63684 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "LS/SCAD/vecperm/std" => [
    "3fb08dc3b122f1a3 3ff9067553e55357 404896f513e4081e 1,3,2",
    "3fdd2c28ab641a00 3ff304d55d36b6ca 40447250b42363a6 1,3,2",
    "3fd0916e23dd290d 3ff51ff5524b1677 4042feba6aa3fb85 1,3,2,4",
    "3fc5ba81e7e26ae5 3ff66c84d957c628 404213b123ec42cf 1,3,2,4,5",
    "3fc972a8125b2c89 3ff75045eaf44c0d 4041eaf4123f972d 1,3,2,4,5,6",
    "3fd0339ee69d8fb3 3ff1a5c165e7ae3f 4040655472624d87 1,3,2,4,5,6",
    "0 3ff8d944e5404803 4048de2ed3c3a6bc 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "0 3fee33e917e06a97 40468ea303a7df7f 1,3",
    "3fe473ec8a986522 0 4043f1b009a255d9 1,3"],
  "Quad/Linf/contig/std" => [
    "3fd49d46d9415332 3ffad19a16c800f4 4019794902718862 1,3,2",
    "3fe292b16a3e44b3 3ff2d1af5b905c49 4010738143822b94 1,3,2",
    "3fc89044946664d9 3ff3b264619d426f 400c4ddc85f888dd 1,3,2,4",
    "3fcf9f575d1607ae 3ff5b0f72212094b 400ce9a4e13506b9 1,3,2,4,5",
    "3fcb11af88e8defc 3ff6bec59bbc5c5f 400814a3339ac088 1,3,2,4,5,6",
    "3fd1087a5fa152ec 3ff2a4b867013d0b 400eb65c86ffc28b 1,3,2,4,5,6",
    "3f8a69fdf90b51e8 3ff8dca920ca79d4 401b976c7b806b58 1,3,2",
    "3fe2298915303812 3fee70210e3f3499 4012a65b48b10332 1,3,2",
    "3fa6782e6e53b545 3feebf041e442e34 4011a52248d03969 1,3,2,4",
    "3fb1e440817b2ca3 3fef732f5872df38 400ec640fa8603ae 1,3,2,4,5",
    "0 3fef732f5872df38 400ec640fa8603ae 1,3,2,4,5",
    "3fd99f30f38fb518 3fce1f679885e598 3ffc77b0e2085b5d 1,3,2,4,5",
    "3fd4bd73104e54d2 3ffad19a16c800f4 4019794902718862 1,3,2",
    "3fe223a905560aba 3ff2d1af5b905c49 4010738143822b94 1,3,2",
    "3fc637a8c002e5a1 3ff3b264619d426f 400c4ddc85f888dd 1,3,2,4",
    "3fd2b6cf34d8d094 3ff5b0f72212094b 400ce9a4e13506b9 1,3,2,4,5",
    "3fcc940901fafdc7 3ff6bec59bbc5c5f 400814a3339ac088 1,3,2,4,5,6",
    "3fd54da01e2dbba4 3ff2a4b867013d0b 400eb65c86ffc28b 1,3,2,4,5,6"],
  "Quad/Linf/contig/zerocurv" => [
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe3e03fec62817d 3ff150e49a81119e 4011638e576469a5 1,3",
    "3fc81883d784c85b 3ff287192ba17168 400a73b1ae66fd10 1,3,4",
    "3fca6e28aff52ce0 3ff46cdcd855070d 400a5deda2c6d369 1,3,4,5",
    "3fd1a5d5c1e01068 3ff5c9ece886a08e 4003ef37c6d2413f 1,3,4,5,6",
    "3fd040919146b95c 3ff0dff3969ba1d3 4009f7d25b052c5e 1,3,4,5,6",
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe22c5a8620b784 3fee6a5e688bd9bc 4010492599ea822a 1,3",
    "3fa72b2864aece42 3feebe3dbde74a04 400ef119cbc92f22 1,3,4",
    "3fb1b82d9c179c39 3fef6f412c2d6ecd 400a99c88f6998bd 1,3,4,5",
    "0 3fef6f412c2d6ecd 400a99c88f6998bd 1,3,4,5",
    "3fd9bf6d45473da4 3fcd828244033435 3ffa016061fe99c3 1,3,4,5",
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe3696d77f2453a 3ff150e49a81119e 4011638e576469a5 1,3",
    "3fcbb6d308432ad9 3ff287192ba17168 400a73b1ae66fd10 1,3,4",
    "3fcec108f8dfb194 3ff46cdcd855070d 400a5deda2c6d369 1,3,4,5",
    "3fd2a1b78eacf789 3ff5c9ece886a08e 4003ef37c6d2413f 1,3,4,5,6",
    "3fd4539992aad601 3ff0dff3969ba1d3 4009f7d25b052c5e 1,3,4,5,6"],
  "Quad/Linf/strided/std" => [
    "3fb2f503f6d2a2cb 3ff8fdbd76b52a13 401abdb9aba01ef5 1,3,2",
    "3fd9653af0e05772 3ff1f238370dc616 4012828b204081a7 1,3,2",
    "3fc069006f6d1b2a 3ff29864b9bd02e8 4016c2481b0d7ad4 1,3,2,4",
    "3fcc131559becae6 3ff44d74db23a58b 401381cf4a33b8fe 1,3,2,4,5",
    "3fc673e18b5d1de2 3ff5159584edd6bd 40116280c367bb1d 1,3,2,4,5,6",
    "3fc403dd369a5ad4 3fee732d4afb4e8a 400e16e39f4007c9 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401b490622d3b3ad 1,3",
    "3fdca5c2d6c2d685 3feee76b1da0f173 4010ccd4d0b508eb 1,3",
    "3f757eac0c46ae00 3feee88be1f1d585 4010ecec545abdce 1,3,4",
    "3fa821211d963dfe 3fef326aa564de43 40100eb84042d399 1,3,4,5",
    "0 3fef326aa564de43 40100eb84042d399 1,3,4,5",
    "3fda610f57b29a70 3fd04142306a1784 3fff97bdc4d306a3 1,3,4,5",
    "3fb3129a097fefd0 3ff8fdbd76b52a13 401abdb9aba01ef5 1,3,2",
    "3fdb9d2f7eb95ad1 3ff1f238370dc616 4012828b204081a7 1,3,2",
    "3fbfeeea01ce175a 3ff29864b9bd02e8 4016c2481b0d7ad4 1,3,2,4",
    "3fd09d4dcd9011e4 3ff44d74db23a58b 401381cf4a33b8fe 1,3,2,4,5",
    "3fc7ab1faf459076 3ff5159584edd6bd 40116280c367bb1d 1,3,2,4,5,6",
    "3fc414891f50ae81 3fee732d4afb4e8a 400e16e39f4007c9 1,3,2,4,5,6"],
  "Quad/Linf/strided/zerocurv" => [
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fd94ec9cd16c137 3ff1c76396fae8c7 401104fb2f4c9345 1,3",
    "3fbd3a4e949b1f4a 3ff2522dcbabc9ac 40143793960498f2 1,3,4",
    "3fcdc5f990feff0f 3ff44b6068a2e7d8 4010c7381c89a2a3 1,3,4,5",
    "3fc66379064b2831 3ff50f98c9e1e4e1 400d893ff3935e85 1,3,4,5,6",
    "3fc47b15d64f8ece 3fee0f2241c4eec6 4009d29aa1234512 1,3,4,5,6",
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fdca5c2d6c2d685 3feee76b1da0f173 400d173e8318f6c2 1,3",
    "3f757eac0c46ae00 3feee88be1f1d585 400d4c9bf8f97c2c 1,3,4",
    "3fa821211d963dfe 3fef326aa564de43 400bdf6105bf7262 1,3,4,5",
    "0 3fef326aa564de43 400bdf6105bf7262 1,3,4,5",
    "3fda610f57b29a70 3fd04142306a1784 3ffbe513860b72c9 1,3,4,5",
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fdb84c873f15e68 3ff1c76396fae8c7 401104fb2f4c9345 1,3",
    "3fbc7013400c72d1 3ff2522dcbabc9ac 40143793960498f2 1,3,4",
    "3fd19eac0595e595 3ff44b6068a2e7d8 4010c7381c89a2a3 1,3,4,5",
    "3fc799d3b5daff6d 3ff50f98c9e1e4e1 400d893ff3935e85 1,3,4,5,6",
    "3fc38dbbdd8519cb 3fee0f2241c4eec6 4009d29aa1234512 1,3,4,5,6"],
  "Quad/Linf/vecperm/std" => [
    "3faf914b21a5a16b 3ff90ab9502b1984 401a3809aadaa6ba 1,3,2",
    "3fdd23a1895257c5 3ff2dc832f2fbbfb 40122db602e1eae0 1,3,2",
    "3fcfaf7cb0dc7880 3ff4da481d47e07e 401437fb06bab4ca 1,3,2,4",
    "3fc4cc0310891c3e 3ff611d31bb8480a 40141f703d118b9f 1,3,2,4,5",
    "3fc834ccd236e3f4 3ff6ea59b99c3e56 40128e225de63ba8 1,3,2,4,5,6",
    "3fd0a9e645702b40 3ff0fecc55960d7d 4012190955b28807 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401c102ccf43d9de 1,3",
    "3fdd76dd3d19cb95 3fef3c7556a0c218 4015958792a9c4d3 1,3",
    "3fa7520e5533a78d 3fef916f39b48cc1 401586ce8d1bdd3b 1,3,4",
    "3f917920ef4b5bb3 3fef9d5c5693dd4a 4015153f68a6e69b 1,3,4,5",
    "3f9646b119d1e040 3fefb0be9a2d8c66 4014c9b81cc2709e 1,3,4,5,6",
    "3fdd0dc098e29619 3fca7f4da3d4f377 3ffe05cd729febe9 1,3,4,5,6",
    "3fb129a47ac1196d 3ff90ab9502b1984 401a3809aadaa6ba 1,3,2",
    "3fdf2f6e6206b571 3ff2dc832f2fbbfb 40122db602e1eae0 1,3,2",
    "3fcfe0f03dcdc26d 3ff4da481d47e07e 401437fb06bab4ca 1,3,2,4",
    "3fc6ebfbd7f17644 3ff611d31bb8480a 40141f703d118b9f 1,3,2,4,5",
    "3fc951954160b137 3ff6ea59b99c3e56 40128e225de63ba8 1,3,2,4,5,6",
    "3fd3b91ab6eb7905 3ff0fecc55960d7d 4012190955b28807 1,3,2,4,5,6"],
  "Quad/Linf/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fdd76dd3d19cb95 3ff2cb9d9a1dd2c7 4011208f7cbf10cf 1,3",
    "3fcc7bed94b2ec33 3ff4bd2a578e5633 4012ab129dddc944 1,3,4",
    "3fc745fd0791fa30 3ff6414cdd4c0824 40122022f9e3c02d 1,3,4,5",
    "3fc9f04b9d51536b 3ff7280ca0903847 4010f5c2d46ed724 1,3,4,5,6",
    "3fd1a1cc31f5557c 3ff0f4925c9703ba 400f8943c8efae95 1,3,4,5,6",
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fdd76dd3d19cb95 3fef3c7556a0c218 4012c9bf62a038bb 1,3",
    "3fa7520e5533a78d 3fef916f39b48cc1 4012db9c8d55d2bd 1,3,4",
    "3f917920ef4b5bb3 3fef9d5c5693dd4a 401286a9a01b297f 1,3,4,5",
    "3f9646b119d1e040 3fefb0be9a2d8c66 40123afcb63275e1 1,3,4,5,6",
    "3fdd0dc098e29619 3fca7f4da3d4f377 3ffaf93ab0b6148d 1,3,4,5,6",
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fdf888244d52629 3ff2cb9d9a1dd2c7 4011208f7cbf10cf 1,3",
    "3fcca8620ce8a66f 3ff4bd2a578e5633 4012ab129dddc944 1,3,4",
    "3fc9a6bc53228986 3ff6414cdd4c0824 40122022f9e3c02d 1,3,4,5",
    "3fcb2175b47e056e 3ff7280ca0903847 4010f5c2d46ed724 1,3,4,5,6",
    "3fd4de8408fa02a9 3ff0f4925c9703ba 400f8943c8efae95 1,3,4,5,6"],
  "Quad/SGL/contig/std" => [
    "3fd432a8ddcf1105 3ffab177e37b4eb6 40197782b457ccea 1,3,2",
    "3fe24ed61a995296 3ff286612ccaa16d 4010780c58e59645 1,3,2",
    "3fc857e9f7a3f148 3ff35a7e106b812d 400bc98f96c07f57 1,3,2,4",
    "3fcf1bd5d2e26aec 3ff53a4dee7cf9a3 400ba4692b899575 1,3,2,4,5",
    "3fca69de138a7317 3ff62558ab8c9e30 4006f11bf02431d2 1,3,2,4,5,6",
    "3fd0004b74b4783a 3ff15e191243e8e7 400d822312d0e103 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401bf2d275b7a3d5 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "3fe473ec8a986522 0 3cc3a60000000000 1,3"],
  "Quad/SGL/contig/zerocurv" => [
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe38b07a32d209c 3ff11bb2c24a6618 40113b541eab029d 1,3",
    "3fc7fcfbb6864490 3ff23cd6ffb1caf8 4009e1d05f0b3bf5 1,3,4",
    "3fcaf22db9474321 3ff4027c7bfa42c1 400969d5d2bde566 1,3,4,5",
    "3fd0e85fbc407061 3ff5385d58d00041 40037d013f257ae5 1,3,4,5,6",
    "3fceb675f7db4001 3fef5695493a92fd 40093f299ad122f3 1,3,4,5,6",
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "3fe473ec8a986522 0 3cc2f60000000000 1,3"],
  "Quad/SGL/strided/std" => [
    "3fb1dee7bc2a3889 3ff8f5ae623935ce 401aa1097318e827 1,3,2",
    "3fd9df5e67289194 3ff1c4baeb6af6b8 40123ae463c2406a 1,3,2",
    "3fc00be02601a2c3 3ff252c753409709 40160e622e9accb2 1,3,2,4",
    "3fcbafbce534c37f 3ff3e11a13e012fc 4012dcce83d68613 1,3,2,4,5",
    "3fc5c00b38d037e7 3ff48bdecbb16646 401123f3fb1bd53a 1,3,2,4,5,6",
    "3fc59136bc6302b2 3fec67eb4dd4744b 400d42aa88a7566f 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401b490622d3b3ad 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "3fe473ec8a986522 0 3cc9e00000000000 1,3"],
  "Quad/SGL/strided/zerocurv" => [
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fd9dec62bf55ce2 3ff1a1ffa19d9c5f 4010bfcf53741125 1,3",
    "3fbc9bc13d29fd5f 3ff217040e75eb51 4013abb68f18db42 1,3,4",
    "3fcd2d8f8d7ad9c7 3ff3dd541bd1c351 40106da52fec4029 1,3,4,5",
    "3fc594437bebd22e 3ff48402b69938b9 400d7243e9f9ebf2 1,3,4,5,6",
    "3fc5458a44a01f48 3fec04d5c55a4dda 40096ab2631ab3b0 1,3,4,5,6",
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "3fe473ec8a986522 0 3cc8c00000000000 1,3"],
  "Quad/SGL/vecperm/std" => [
    "3fae95c7c8b31cb0 3ff8fe1e0b9fd735 401a7e8acf733f9c 1,3,2",
    "3fddb8d2c375cc36 3ff2a0a1b947f611 401215e86ce126f0 1,3,2",
    "3fced44a4447ebd5 3ff46bfb35662f3d 4013b6a3b4a37918 1,3,2,4",
    "3fc4846c480bc797 3ff579bdee0c597e 4014070363d36807 1,3,2,4,5",
    "3fc7ee933da46394 3ff639bcc0887f6f 4012799608a00998 1,3,2,4,5,6",
    "3fd21d27d5233be2 3fef6e5fc1467a31 4011c8aa73a507e0 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401c102ccf43d9de 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "3fe473ec8a986522 0 3ccd290000000000 1,3"],
  "Quad/SGL/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fddfa873b9e61b6 3ff2917b04886aad 4011071c4843e4e3 1,3",
    "3fcc3694a8af5d0b 3ff44de09b69dc37 40124c9a39f59ff8 1,3,4",
    "3fc6756ee7e28b44 3ff596406ad3a99f 401209f33c504184 1,3,4,5",
    "3fc93f4cfff31d69 3ff661fd0492804a 4010e772c512d30e 1,3,4,5,6",
    "3fd2ff75a597cb76 3fef4c120c804f6f 400f2819daee9f12 1,3,4,5,6",
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "3fe473ec8a986522 0 3cc8690000000000 1,3"],
  "Quad/L1/contig/std" => [
    "3fd49d46d9415332 3ffabef007121ea4 4019852b9221756c 1,3,2",
    "3fe21d60f5a168cc 3ff29a42bd4f93c9 4010790eeaf2c8d7 1,3,2",
    "3fc8f59a5afc702f 3ff373b393bcf22c 400ba49413312eb6 1,3,2,4",
    "3fcfa200bada89a6 3ff55efaf17b4a83 400b805fc0f31a60 1,3,2,4,5",
    "3fcb1c7109de0669 3ff6517d4bd0c5de 4006c045b925e72e 1,3,2,4,5,6",
    "3fcfd11e6f7a4f99 3ff196c1ab288bf3 400d99c3dd103f1c 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401bf2d275b7a3d5 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "3fe473ec8a986522 0 3cc3a60000000000 1,3"],
  "Quad/L1/contig/zerocurv" => [
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe36ea92d6937ab 3ff122c1eefd241a 40113f06efadbc31 1,3",
    "3fc861f5d2cb595c 3ff248539ac02f6f 4009d1b0ced7fe57 1,3,4",
    "3fcb651d7e5acab6 3ff416a0e990df75 400953769a09b609 1,3,4,5",
    "3fd15adb56401bc7 3ff558d4e6f76f2c 400374ada2512c14 1,3,4,5,6",
    "3fce6f4187f17fd9 3fefa95c4a2a0fe6 40097c1b2246baa1 1,3,4,5,6",
    "0 3ff8d944e5404803 401905d698f5214b 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "0 3fee33e917e06a97 4010af6b9f3ac07d 1,3",
    "3fe473ec8a986522 0 3cc2f60000000000 1,3"],
  "Quad/L1/strided/std" => [
    "3fb2f503f6d2a2cb 3ff8f7e98301d58c 401a88245d076760 1,3,2",
    "3fd9ef45a32e4986 3ff1d0eb71c48102 401225b14cb63e6c 1,3,2",
    "3fc084b960a8c906 3ff262b05d463a9c 401603398e7098de 1,3,2,4",
    "3fcc281307938451 3ff3f7f3956bca05 4012c5bc5be4ae83 1,3,2,4,5",
    "3fc65b38063f83b9 3ff4a504a184b1f6 40112b9d6bf93b8e 1,3,2,4,5,6",
    "3fc562288eb8880a 3fecb5b87c95512f 400d62fc2a739376 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401b490622d3b3ad 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "3fe42b97e9870bd2 3f146fb693daf670 3fa5a59ac3821960 1,3"],
  "Quad/L1/strided/zerocurv" => [
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fd9f6adb7fd12b8 3ff1ac04df6f9740 4010b8d506178817 1,3",
    "3fbd4d47cc19484e 3ff22309a8759b6c 4013aa96bed12320 1,3,4",
    "3fcd951fbb99d995 3ff3f13e0c8b856f 401068bad986720a 1,3,4,5",
    "3fc61c6e966f77db 3ff498f20f5d7f45 400da3df421cd21d 1,3,4,5,6",
    "3fc509ab0d294a70 3fec42c469ace46d 4009a4c22583f6be 1,3,4,5,6",
    "0 3ff8d944e5404803 40176f0c29760d34 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "0 3fee33e917e06a97 400c0ce7d507c489 1,3",
    "3fe42b97e9870bd2 3f146fb693daf670 3fa353735990d7c5 1,3"],
  "Quad/L1/vecperm/std" => [
    "3faf914b21a5a16b 3ff8fe8a9d66c6e7 401a7fcb9a6eea83 1,3,2",
    "3fddfbe20af14a04 3ff2adc0db9c8fe6 401219fad4958492 1,3,2",
    "3fcf5f3ddc73f66c 3ff47e60cdb77dd8 4013ada90f46fd20 1,3,2,4",
    "3fc4ae6b5dd285bc 3ff58fe79a847321 40142933f08d9288 1,3,2,4,5",
    "3fc857f5845dbaa7 3ff650adf87203a1 4012820eeaeb05fc 1,3,2,4,5,6",
    "3fd1e3eb213a4297 3fefba0d1177fb53 4011f275b415a1d2 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401c102ccf43d9de 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "3fe473ec8a986522 3f7ad2001594d895 3fd6fdd277ceb931 1,3"],
  "Quad/L1/vecperm/zerocurv" => [
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fde40fd19d92960 3ff29c5253bd31be 40110d634358a7e6 1,3",
    "3fccb592dd584b02 3ff45c25a2da5356 401241dbcd6d55ff 1,3,4",
    "3fc699edb9cb8869 3ff5a8de3ee11793 401223ac43706f3b 1,3,4,5",
    "3fc9b63119b2f378 3ff675ce83997cb8 4010eb96ab5106a6 1,3,4,5,6",
    "3fd2d020ce1bf157 3fef9163ea682fc7 400f6f462096bab8 1,3,4,5,6",
    "0 3ff8d944e5404803 401946ea43500b78 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "0 3fee33e917e06a97 4013ee2a6c786bfe 1,3",
    "3fe473ec8a986522 3f7ad2001594d895 3fd3dbbe5464af74 1,3"],
  "Quad/MCP/contig/std" => [
    "3fd563026c85091b 3ffaf20b15897e90 401989378e572f60 1,3,2",
    "3fe287182faa9f47 3ff30c4588e45abd 401084d467fba533 1,3,2",
    "3fc9e47c0b307fb3 3ff3fc661c712a8e 400c697bb85e68f0 1,3,2,4",
    "3fd0a002cffa38a5 3ff610f2f3364453 400d340604ee0699 1,3,2,4,5",
    "3fccc721e923e261 3ff73928df9377e0 400862721a94d128 1,3,2,4,5,6",
    "3fd0e299c4390ce0 3ff36d56a7478834 400f0907db14f688 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401bf2d275b7a3d5 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "3fe473ec8a986522 0 3cc3a60000000000 1,3"],
  "Quad/MCP/strided/std" => [
    "3fb49aeedfd0d40e 3ff900be154d2cf7 401aa07baa8559b6 1,3,2",
    "3fd954489952c733 3ff214b0361bceff 401283d68d5266b4 1,3,2",
    "3fc20df54ad70b86 3ff2ca14d0fd6fd8 4016e3bc94711e05 1,3,2,4",
    "3fcd7c6c8c8ddb66 3ff490e615abbcbb 4013aa071c8b1cc7 1,3,2,4,5",
    "3fc7d9e881e9dfce 3ff567f9d54cc6b7 401194d2ee48aa07 1,3,2,4,5,6",
    "3fc3ba9af293ffd6 3fef891322c0dc80 400eb988a515c062 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401b490622d3b3ad 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "3fe473ec8a986522 0 3cc9e00000000000 1,3"],
  "Quad/MCP/vecperm/std" => [
    "3fb1aa717a1f03e5 3ff90cbbca324ffc 401a39e7766b2115 1,3,2",
    "3fdd2723f1e2d69b 3ff30954f47b85a1 40122d515336084e 1,3,2",
    "3fd0ab94423a6307 3ff525d27308d8d2 401441dcce14aa74 1,3,2,4",
    "3fc592cbf0b05a60 3ff66dbf62950e63 40143eb35bd88a17 1,3,2,4,5",
    "3fc957e048c55922 3ff750ae77cbc9b1 4012a86efcf8924f 1,3,2,4,5,6",
    "3fd022b37d766788 3ff1ab3e703f43a1 40125a3f38c290bf 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401c102ccf43d9de 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "3fe473ec8a986522 0 3ccd290000000000 1,3"],
  "Quad/SCAD/contig/std" => [
    "3fd563026c85091b 3ffaf20b15897e90 401989378e572f60 1,3,2",
    "3fe287182faa9f47 3ff30c4588e45abd 401084d467fba533 1,3,2",
    "3fc9e47c0b307fb3 3ff3fc661c712a8e 400c697bb85e68f0 1,3,2,4",
    "3fd0a002cffa38a5 3ff610f2f3364453 400d340604ee0699 1,3,2,4,5",
    "3fccc721e923e261 3ff73928df9377e0 400862721a94d128 1,3,2,4,5,6",
    "3fd0e299c4390ce0 3ff36d56a7478834 400f0907db14f688 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401bf2d275b7a3d5 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "0 3fee33e917e06a97 4013835e38a5a732 1,3",
    "3fe473ec8a986522 0 3cc3a60000000000 1,3"],
  "Quad/SCAD/strided/std" => [
    "3fb302d79203ae4f 3ff8fadf0159515e 401aad85a89d2062 1,3,2",
    "3fd953dbc35bd4ef 3ff20e13b635b7fd 40129030182c4a9b 1,3,2",
    "3fc1e7029bb300f4 3ff2c0c26a9ebd8d 4016e89b8c8242ff 1,3,2,4",
    "3fcd9ec1380301fe 3ff48cd340b8ea84 4013a97536e9f49c 1,3,2,4,5",
    "3fc7d7180f55a44e 3ff5636f08c1e1ff 401196f4b87ca5d2 1,3,2,4,5,6",
    "3fc3b09e1f86d464 3fef784c463fc449 400ebadbc5e8ab0f 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401b490622d3b3ad 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "0 3fee33e917e06a97 40106587b15aeced 1,3",
    "3fe473ec8a986522 0 3cc9e00000000000 1,3"],
  "Quad/SCAD/vecperm/std" => [
    "3fb08dc3b122f1a1 3ff9067553e55356 401a54fea5a58591 1,3,2",
    "3fdd2c28ab641a03 3ff304d55d36b6cb 40123733f490cedf 1,3,2",
    "3fd0916e23dd290f 3ff51ff5524b1677 401443534c7b23e8 1,3,2,4",
    "3fc5ba81e7e26ae6 3ff66c84d957c628 4014461bd75eec7c 1,3,2,4,5",
    "3fc972a8125b2c83 3ff75045eaf44c0e 4012aab7e14ab478 1,3,2,4,5,6",
    "3fd0339ee69d8fb5 3ff1a5c165e7ae3f 401252b66f2b7f7c 1,3,2,4,5,6",
    "0 3ff8d944e5404803 401c102ccf43d9de 1,3",
    "3fe101a627cd0bd5 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "0 3fee33e917e06a97 40170a2683a6f998 1,3",
    "3fe473ec8a986522 0 3ccd290000000000 1,3"],
)

ft28_vec(s) = [reinterpret(Float64, parse(UInt64, w; base = 16)) for w in split(s)]

ft28_layout(name, p) = name == "contig" ? [i:i+4 for i in 1:5:p] :
  name == "strided" ? [k:6:p for k in 1:6] : (perm = randperm(Xoshiro(3), p); [perm[i:i+4] for i in 1:5:p])

function ft28_setup(kind, layout, zerocurv)
  n, p = 40, 30
  rng = Xoshiro(23)
  X = randn(rng, n, p); y = randn(rng, n)
  groups = ft28_layout(layout, p)
  zerocurv && for j in groups[2]
    X[:, j] .= 0
  end
  A = Matrix(X' * X) / n
  b = -(X' * y) / n
  zerocurv && for j in groups[2]
    b[j] = 0
  end
  f = kind == "LS" ? (1 / n) * LeastSquaresLoss(y, X) : QuadraticFunction(A, b)
  λscale = 0.03 * maximum(G -> norm((X' * y)[G]), groups) / n
  # the Hessian of f, from the gradients of the quadratic
  g0 = gradient(f, zeros(p))
  H = reduce(hcat, [gradient(f, [i == j ? 1.0 : 0.0 for i in 1:p]) .- g0 for j in 1:p])
  (; X, y, A, f, H, groups, λscale, n, p)
end

ft28_penalty(pen, λ, groups) = pen == "Linf" ? GroupNormLinf(λ, groups) :
  pen == "SGL" ? SparseGroupNormL2(λ / 2, λ / 2, groups) :
  pen == "L1" ? NormL1(λ) :
  pen == "MCP" ? GroupMCP(λ, groups; a = 3.0) : GroupSCAD(λ, groups; a = 3.7)

# the iterate of the recorded runs: groups 1 and 3 active, a stored zero in group 3
function ft28_start(groups, p)
  x = AtomIterate(Float64, p, groups)
  for k in (1, 3)
    x[groups[k]] .= 0.4 .* randn(Xoshiro(100 + k), length(groups[k]))
  end
  x[groups[3][2]] = 0.0
  x
end

# the new entries of group k by hand: the gradient step with the curvature of the group from the Hessian, then
# the dense proximal operator of the penalty at the trial point, with step 1/L (the group goes to the
# minimizer of the penalty when L = 0)
function ft28_reference(f, H, g, G, xold)
  L = max(eigmax(Symmetric(H[G, G])), 0.0)
  z = copy(xold)
  γ = floatmax(Float64)
  if !iszero(L)
    z[G] .= xold[G] .- gradient(f, xold)[G] ./ L
    γ = inv(L)
  end
  ProximalBase.prox(g, z, γ)[G]
end

ft28_cache(kind, m) = kind == "LS" ? copy(PS.residuals(m)) : copy(m.u)

@testset "FT28: block steps equal the recorded runs and a step by hand" begin
  nsteps = nzero = nzeroinactive = nactivated = nzerowasactive = nzeroactive = 0
  for key in sort!(collect(keys(FT28)))
    kind, pen, layout, curv = split(key, '/')
    d = ft28_setup(kind, layout, curv == "zerocurv")
    groups, p, K = d.groups, d.p, length(d.groups)
    recorded = FT28[key]
    runs = [(1.0, false), (40.0, false), (1.0, true)][1:length(recorded) ÷ K]
    for (r, (factor, scaled)) in enumerate(runs)
      g = ft28_penalty(pen, factor * d.λscale, groups)
      x = ft28_start(groups, p)
      m = cdmodel(d.f, x); PS.initialize!(m, x)
      for (i, k) in enumerate(vcat(2:K, 1))
        G = groups[k]
        xold, activeold, wasactive = Vector(x), collect(activecoordinates(x)), isactive(x, k)
        h = PS._groupstep!(m, g, x, k, scaled)
        xnew = Vector(x)
        h_rec, x2_rec, c1_rec, act_rec = split(recorded[(r - 1) * K + i], ' ')
        tag = "$key, $(factor == 1 ? "mid" : "big"), scaled = $scaled, group $k"
        # the recorded run
        @test isapprox(h, ft28_vec(h_rec)[1]; rtol = 1e-12, atol = 1e-14)
        @test isapprox(sum(abs2, xnew), ft28_vec(x2_rec)[1]; rtol = 1e-12)
        @test isapprox(sum(abs, ft28_cache(kind, m)), ft28_vec(c1_rec)[1]; rtol = 1e-12)
        @test collect(activecoordinates(x)) == (act_rec == "-" ? Int[] : parse.(Int, split(act_rec, ',')))
        # the step by hand
        want = ft28_reference(d.f, d.H, g, G, xold)
        @test isapprox(xnew[G], want; rtol = 1e-9, atol = 1e-12)
        @test xnew[setdiff(1:p, G)] == xold[setdiff(1:p, G)]
        scaled || @test isapprox(h, maximum(abs, xnew[G] .- xold[G]); rtol = 1e-9, atol = 1e-14)
        @test isapprox(ft28_cache(kind, m), kind == "LS" ? d.y .- d.X * xnew : d.A * xnew; rtol = 1e-9, atol = 1e-10)
        # the working set: an active group stays active (also at zero, until dropzeros!), the other groups are
        # untouched, and an inactive group joins when its entries are not all zero
        @test collect(activecoordinates(x))[1:length(activeold)] == activeold
        @test isactive(x, k) == (wasactive || any(!iszero, xnew[G]))
        @test length(activecoordinates(x)) == length(activeold) + (!wasactive && isactive(x, k))
        nsteps += 1
        nzero += all(iszero, xnew[G])
        nzeroinactive += !wasactive && all(iszero, xnew[G])
        nactivated += !wasactive && isactive(x, k)
        nzerowasactive += wasactive && all(iszero, xnew[G])
      end
      # an active group that is zero stays active until dropzeros!, which removes exactly those
      zeroactive = count(k -> all(iszero, x[groups[k]]), activecoordinates(x))
      before = nactive(x)
      dropzeros!(x)
      @test nactive(x) == before - zeroactive
      nzeroactive += zeroactive
    end
  end
  @test nsteps == sum(length, values(FT28))
  # the scenarios occurred: a first activation, a zero prox result for an inactive group (it stays inactive) and
  # for an active one (it stays active), and an active group at zero at the end of a run
  @test nactivated > 0 && nzeroinactive > 0 && nzerowasactive > 0 && nzeroactive > 0
end

# a step that throws, because the groups of the penalty are not those of the iterate, validates before it writes:
# the iterate (entries and working set) and the cache are as they were, and the next valid step is the step of a
# freshly built model
@testset "FT28: a rejected group step leaves no trace" begin
  n, p = 40, 30
  rng = Xoshiro(29)
  X = randn(rng, n, p); y = randn(rng, n)
  groups = [i:i+4 for i in 1:5:p]
  other = [k:6:p for k in 1:6]
  for kind in ("LS", "Quad")
    f = kind == "LS" ? (1 / n) * LeastSquaresLoss(y, X) : QuadraticFunction(Matrix(X' * X) / n, -(X' * y) / n)
    for scaled in (false, true), pen in ("Linf", "SGL")
      x = AtomIterate(Float64, p, groups)
      x[groups[1]] .= 0.5
      m = cdmodel(f, x); PS.initialize!(m, x)
      cache0, x0, act0 = ft28_cache(kind, m), Vector(x), collect(activecoordinates(x))
      bad = ft28_penalty(pen, 0.01, other)
      for k in (2, 1)
        @test_throws DimensionMismatch PS._groupstep!(m, bad, x, k, scaled)
        @test Vector(x) == x0 && collect(activecoordinates(x)) == act0 && nactive(x) == 1
        @test ft28_cache(kind, m) == cache0
        @test all(j -> isactive(x, j) == (j in act0), 1:ncoordinates(x))
      end
      good = ft28_penalty(pen, 0.01, groups)
      h = PS._groupstep!(m, good, x, 2, scaled)
      xf = AtomIterate(Float64, p, groups); xf[groups[1]] .= 0.5
      mf = cdmodel(f, xf); PS.initialize!(mf, xf)
      @test h == PS._groupstep!(mf, good, xf, 2, scaled)
      @test Vector(x) == Vector(xf) && collect(activecoordinates(x)) == collect(activecoordinates(xf))
      @test ft28_cache(kind, m) == ft28_cache(kind, mf)
    end
  end
end

# the groups of the iterate are looked up through atomindices, whatever the index type
@testset "FT28: group steps on Int32 and vector-backed groups" begin
  n, p = 30, 12
  rng = Xoshiro(31)
  X = randn(rng, n, p); y = randn(rng, n)
  f = (1 / n) * LeastSquaresLoss(y, X)
  ranges = [1:3, 4:6, 7:9, 10:12]
  vecs = [collect(r) for r in ranges]
  vec32 = [Int32.(r) for r in ranges]
  for pen in ("Linf", "SGL", "L1")
    results = map((ranges, vecs, vec32)) do groups
      x = AtomIterate(Float64, p, groups)
      m = cdmodel(f, x); PS.initialize!(m, x)
      g = ft28_penalty(pen, 0.05, groups)
      hs = [PS._groupstep!(m, g, x, k, false) for k in (3, 1, 2, 4, 3)]
      (hs, Vector(x), collect(activecoordinates(x)), copy(PS.residuals(m)))
    end
    @test results[1] == results[2] == results[3]
  end
end

end
