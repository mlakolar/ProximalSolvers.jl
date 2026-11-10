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
# the pure block oracle computes the result, and the solver writes through the public group view.
#
# Recorded steps, from the base commit 412063d8ac24b84a10ccde09cf072bb396109ffd (the audited behaviour, which
# staged the trial point in the entries of the iterate) on ProximalBase 0.5.4, Julia 1.13.3, Float64, with the data
# of the generator `ft28_stream`, which is the same on every Julia version. Each key is
# "model/penalty/layout/curvature" for the data of `ft28_setup` (seeds 23 and 3), each entry the string
# "h ‖x‖² ‖cache‖₁ active" of one step, h = the returned scaled change, ‖x‖² = sum(abs2, x), ‖cache‖₁ = the
# residuals of the least-squares model, or Ax of the quadratic one, active = activecoordinates(x) after the step
# ("-" for none); floats are the hex digits of the bit pattern. The steps visit groups 2, 3, 4, 5, 6, 1 from a start
# in which groups 1 and 3 are active (a stored zero in group 3), at the penalty level `mid` = 0.03 max ‖X_G' y‖ / n
# without and with scaling, and at `big` = 40 times that (every prox result zero), in this order:
# (mid, unscaled), (big, unscaled), then (mid, scaled) for GroupNormLinf only.
const FT28 = Dict{String,Vector{String}}(
  "LS/Linf/contig/std" => [
    "3fd300476cc80957 3feb320725b0a1bf 40363b3730db9c4c 1,3,2",
    "3fd18171b022be20 3fe543503a9a4c37 4034e19479c56711 1,3,2",
    "3fc269605691acb5 3fe65258296d4d60 4034749ec1417932 1,3,2,4",
    "3fc85d85196cc905 3fe7f921ccbea87e 40340cf5d5fbf5cc 1,3,2,4,5",
    "3fcecd11f37e4dc4 3feb30fb4f13bc8e 40322fbe41e83f6e 1,3,2,4,5,6",
    "3fd12dbac92ec92b 3fe01744c51b56d6 402cbd598de2af67 1,3,2,4,5,6",
    "3fc4bf5dffe88a4b 3fe696fa4c128ea2 4036255d0b238d10 1,3,2",
    "3fd7a70533333334 3fe0184f74e5f15a 4034e4ddcbe46c27 1,3,2",
    "3f7388e67c786fc0 3fe0193df6098de1 4034d8c2002b947b 1,3,2,4",
    "3fa76b5706a6d465 3fe05103377261a7 4034c0d18464ac82 1,3,2,4,5",
    "3fa842201cc82a88 3fe09acaeab00b37 403414184bd44a17 1,3,2,4,5,6",
    "3fd79103c192a9e2 3fb89aae3ca131ed 402f57fd2618f71f 1,3,2,4,5,6",
    "3fc6518418993a15 3feb320725b0a1bf 40363b3730db9c4c 1,3,2",
    "3fc3cd868f1061a2 3fe543503a9a4c37 4034e19479c56711 1,3,2",
    "3fb55830b64ecfd8 3fe65258296d4d60 4034749ec1417932 1,3,2,4",
    "3fbde2c24f0e5958 3fe7f921ccbea87e 40340cf5d5fbf5cc 1,3,2,4,5",
    "3fc22d1aa569bc6e 3feb30fb4f13bc8e 40322fbe41e83f6e 1,3,2,4,5,6",
    "3fc64521dcb35889 3fe01744c51b56d6 402cbd598de2af67 1,3,2,4,5,6"],
  "LS/Linf/contig/zerocurv" => [
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd2b169be97f29f 3fdcb72b77a15bd8 403765fd1d2119b1 1,3",
    "3fb6f1c601c399a9 3fde7e1d2b703964 40370d0452cbb46a 1,3,4",
    "3fcabfd8306aacbd 3fe2766098323fc9 40362e7fc20d8128 1,3,4,5",
    "3fd2e35b1d3b8f76 3fe59a1ee3aacfd7 4034222ea93e2eed 1,3,4,5,6",
    "3fd3fa2104d83d3b 3fd27944986f8541 4030075b64db120e 1,3,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "3f965338b005e9b6 3fdb45a797536fc8 4037218d2f350bd4 1,3,4",
    "3fb887d1264a2b40 3fdd4bfec627d8d6 4036c32bc05edc16 1,3,4,5",
    "3fa3b4bc9a83dc26 3fddada91a99dcdc 40363067e0f0caf2 1,3,4,5,6",
    "3fd8cc2cc5c853d1 3fa4880601996ee9 403054bcf97ec2b1 1,3,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fc5256218e3eda4 3fdcb72b77a15bd8 403765fd1d2119b1 1,3",
    "3fab7082ea663a19 3fde7e1d2b703964 40370d0452cbb46a 1,3,4",
    "3fc067aec01ffe84 3fe2766098323fc9 40362e7fc20d8128 1,3,4,5",
    "3fc64ad6e2049e19 3fe59a1ee3aacfd7 4034222ea93e2eed 1,3,4,5,6",
    "3fc9e5dbcf91fa88 3fd27944986f8541 4030075b64db120e 1,3,4,5,6"],
  "LS/Linf/strided/std" => [
    "3fb5ceffb5ec6c9e 3fe47d3803e3e1b6 403871deca0e91ea 1,3,2",
    "3fd083b8af5dbe02 3fdf0ae36872510f 40358c8bbab38ad3 1,3,2",
    "3fd0bfafa83b4548 3fe3f86e0efaf799 4032f7c8ac270ed3 1,3,2,4",
    "3fabab4ce523ee89 3fe4322d73f5e8bf 4032a518198e0d3e 1,3,2,4,5",
    "3fbf51be64a160f5 3fe4e003244918bc 40324953c5026a86 1,3,2,4,5,6",
    "3fcd2d915c14d6c0 3fd4de5954ecccd1 40302416cb1283f9 1,3,2,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7167fb8dbfa9f 3fdb22b34b3663ed 4036790dc57830a8 1,3",
    "3fb968c029b32110 3fddafe3f26d7430 4034bdc7209d5b8a 1,3,4",
    "3f5d7e9578f22166 3fddb027e8e695c8 4034b70327e1f355 1,3,4,5",
    "0 3fddb027e8e695c8 4034b70327e1f355 1,3,4,5",
    "3fd7b786af8d4f2f 3fa4e2c21594c43b 402fec13ac849057 1,3,4,5",
    "3fab97d685ab9c77 3fe47d3803e3e1b6 403871deca0e91ea 1,3,2",
    "3fc1958d8112dfef 3fdf0ae36872510f 40358c8bbab38ad3 1,3,2",
    "3fc4ac815a78d818 3fe3f86e0efaf799 4032f7c8ac270ed3 1,3,2,4",
    "3fa0f8159208cf0a 3fe4322d73f5e8bf 4032a518198e0d3e 1,3,2,4,5",
    "3fb3f87c0300c432 3fe4e003244918bc 40324953c5026a86 1,3,2,4,5,6",
    "3fbe9f2cbec072dc 3fd4de5954ecccd1 40302416cb1283f9 1,3,2,4,5,6"],
  "LS/Linf/strided/zerocurv" => [
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fce86c22716be5c 3fde34453e139814 4035dd8c799c5fc7 1,3",
    "3fd093bec7cd8897 3fe35a4ae5718c58 40338a4227639007 1,3,4",
    "3fa9d8dc03dda640 3fe38eb7333143dc 403337da0c46f5a9 1,3,4,5",
    "3fbe39afa6fdfa59 3fe453d8b1f3f3a9 4032ef83bf5fc242 1,3,4,5,6",
    "3fcd2500acde7bbd 3fd4299e775cf6c9 4030a9851b1caf3c 1,3,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7167fb8dbfa9f 3fdb22b34b3663ed 4036790dc57830a8 1,3",
    "3fb968c029b32110 3fddafe3f26d7430 4034bdc7209d5b8a 1,3,4",
    "3f5d7e9578f22166 3fddb027e8e695c8 4034b70327e1f355 1,3,4,5",
    "0 3fddb027e8e695c8 4034b70327e1f355 1,3,4,5",
    "3fd7b786af8d4f2f 3fa4e2c21594c43b 402fec13ac849057 1,3,4,5",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fc1f0ca4ea0909c 3fde34453e139814 4035dd8c799c5fc7 1,3",
    "3fc476444d852cb6 3fe35a4ae5718c58 40338a4227639007 1,3,4",
    "3f9f5c198933b341 3fe38eb7333143dc 403337da0c46f5a9 1,3,4,5",
    "3fb345e820981cac 3fe453d8b1f3f3a9 4032ef83bf5fc242 1,3,4,5,6",
    "3fbe962f901c31f6 3fd4299e775cf6c9 4030a9851b1caf3c 1,3,4,5,6"],
  "LS/Linf/vecperm/std" => [
    "3fc4054fc6b39d06 3fe51477435c98fe 403390eeba62e840 1,3,2",
    "3fd87e5627399ecb 3fe0c0d76222687a 4031b59a92667524 1,3,2",
    "3fc42cb2106c371d 3fe1c6a983571362 40315393b5e9aa12 1,3,2,4",
    "3fc0fd533f5f11fe 3fe2c5aa971e640a 40314dbe069bccca 1,3,2,4,5",
    "3fbe32b1de7e0394 3fe33f05eb062b98 4030fc0daad27b8d 1,3,2,4,5,6",
    "3fca2d03331be5a3 3fd5859cdb75ed97 402d57ed710db9de 1,3,2,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd81fd5e4cbbaad 3fdb249647831a9f 4033ca308b26fb5c 1,3",
    "3f949787b04111b3 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "0 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "0 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "3fd366a7e0a42e6e 3fa12f5db022a2c8 4030e027e3dd03b6 1,3,4",
    "3fb51f07a86110b0 3fe51477435c98fe 403390eeba62e840 1,3,2",
    "3fcce872df90630a 3fe0c0d76222687a 4031b59a92667524 1,3,2",
    "3fb7b26196d4102f 3fe1c6a983571362 40315393b5e9aa12 1,3,2,4",
    "3fb457a790f0ec3f 3fe2c5aa971e640a 40314dbe069bccca 1,3,2,4,5",
    "3fb15c42e8e6ecbd 3fe33f05eb062b98 4030fc0daad27b8d 1,3,2,4,5,6",
    "3fbf5229da00c0fa 3fd5859cdb75ed97 402d57ed710db9de 1,3,2,4,5,6"],
  "LS/Linf/vecperm/zerocurv" => [
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd81fd5e4cbbaad 3fde16e95d1557bf 4032bafd35eba985 1,3",
    "3fc6026e505c2882 3fe025aa11a947cf 40322734efe78ead 1,3,4",
    "3fc32edfd158bba6 3fe15d37d2d9282b 40322c0e761964a5 1,3,4,5",
    "3fbf35bf49e77d3a 3fe1dc0851990b53 4031d3faaa8c28ca 1,3,4,5,6",
    "3fc9db4f5411892f 3fd3c82f7e004734 402ed8c71a04cc6b 1,3,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd81fd5e4cbbaad 3fdb249647831a9f 4033ca308b26fb5c 1,3",
    "3f949787b04111b3 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "0 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "0 3fdb45b6d164ead8 40338d123ea4fa94 1,3,4",
    "3fd366a7e0a42e6e 3fa12f5db022a2c8 4030e027e3dd03b6 1,3,4",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fcc78ea680f32ce 3fde16e95d1557bf 4032bafd35eba985 1,3",
    "3fb9da203f4998fb 3fe025aa11a947cf 40322734efe78ead 1,3,4",
    "3fb6f8062a9d29dd 3fe15d37d2d9282b 40322c0e761964a5 1,3,4,5",
    "3fb1f12fce9fafc7 3fe1dc0851990b53 4031d3faaa8c28ca 1,3,4,5,6",
    "3fbef066c1bbb9fd 3fd3c82f7e004734 402ed8c71a04cc6b 1,3,4,5,6"],
  "LS/SGL/contig/std" => [
    "3fd2e26ef37f6edc 3fead9c4a0805e8e 40363243c5ca8da0 1,3,2",
    "3fd1c383ed0ad4c8 3fe4d5420a325d80 4034c1f0999d30b6 1,3,2",
    "3fc1d39b29c2cd7b 3fe5c6c14b921dae 4034532eaf5b6243 1,3,2,4",
    "3fc7beb5826a6189 3fe752815a3158f7 4034039eeed97519 1,3,2,4,5",
    "3fcded887e5f32cd 3fea3d33e4710fcf 40323ef5f86b0960 1,3,2,4,5,6",
    "3fd1ffd8fee0cac3 3fdde0362c73c325 402cc04e0ee7358a 1,3,2,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SGL/contig/zerocurv" => [
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd32c545c90beb6 3fdc8b23dd687fdb 40376737e17186b7 1,3",
    "3fb6a0ce1c268cbc 3fde1b9371761c1d 403713f9801d5489 1,3,4",
    "3fca0c390ebe7129 3fe20992b027a611 40363eae3efcd12d 1,3,4,5",
    "3fd2729e56be52e2 3fe4fdbd2098ab01 403438f16604910b 1,3,4,5,6",
    "3fd48b259f7d4881 3fd0f6891d86dcdf 403002287aaea52d 1,3,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SGL/strided/std" => [
    "3fb5005758699a80 3fe469feff7cd2df 40387a30ae0bb716 1,3,2",
    "3fd029514c8efc0f 3fde973076f0de0d 4035965b1454f1a7 1,3,2",
    "3fd07dcfbcdfbab1 3fe37cefa4bcb8ea 4033063969651290 1,3,2,4",
    "3fa94f9186abd9f5 3fe3a9f9f3081be3 4032bb824ae2a002 1,3,2,4,5",
    "3fbd8e097a721f0f 3fe43a43501c36cc 40326ad9c7348134 1,3,2,4,5,6",
    "3fcefe97c3ea14e8 3fd2eb20aeb4433a 40300b0c6635712b 1,3,2,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SGL/strided/zerocurv" => [
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fcf424b4cf3ab32 3fddebed6a836d96 4035ce2d7cb33bbf 1,3",
    "3fd0659f73d4300c 3fe2f322e75528b6 40338806afbfa6aa 1,3,4",
    "3fa8e61afa7f17da 3fe31c6e504f88e0 40333c10ea40bdde 1,3,4,5",
    "3fbca68f177d6b64 3fe3bc8081466e35 4032f62486f825a3 1,3,4,5,6",
    "3fcee13abe3016aa 3fd23b8b61809b57 4030875fd61f1e7f 1,3,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SGL/vecperm/std" => [
    "3fc376f69f432164 3fe4faf97d264ad9 4033a9c3574c6883 1,3,2",
    "3fd834c532300fcf 3fe071078daae1c3 4031c8139343e99f 1,3,2",
    "3fc42467ec92f3ae 3fe16b25176364f4 4031551af1a9d753 1,3,2,4",
    "3fc0c305a6ce1dce 3fe24c4784b7c829 40315844e2d64e56 1,3,2,4,5",
    "3fbde31e748878c2 3fe2bfc546db02e8 40311149f3ec489a 1,3,2,4,5,6",
    "3fcaf1557a00037d 3fd3bce70297041f 402d6ced5f6f562c 1,3,2,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SGL/vecperm/zerocurv" => [
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7d6ed987f0773 3fddd0b83e936a24 4032c88bf06b0697 1,3",
    "3fc5d3f4f8a1a9d9 3fdfecaa281d32d0 403227eaf5e9d2c8 1,3,4",
    "3fc2c11c02c7a767 3fe10762b75c6609 40322d5155a4774a 1,3,4,5",
    "3fbed851abb41b37 3fe180e2a6222830 4031e459f8bd422a 1,3,4,5,6",
    "3fcabe1181f27eee 3fd233ac55e9033e 402ecb5b83fca117 1,3,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/contig/std" => [
    "3fd300476cc80957 3feae93177bdc85c 403635e71f2a9e74 1,3,2",
    "3fd1942673dcc0fc 3fe4ea818125e936 4034c8b1a546e3d6 1,3,2",
    "3fc26b2341cdf47f 3fe5e3c6fcba8417 403455969abce41e 1,3,2,4",
    "3fc836190eb37a29 3fe776122290b552 4034074f18a1299f 1,3,2,4,5",
    "3fce45120e7dd3b9 3fea6b8c43939a2f 403241857766b8d1 1,3,2,4,5,6",
    "3fd1fe75f63f2a5f 3fde5e412e5c27d4 402ccb969d66eb9d 1,3,2,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/contig/zerocurv" => [
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd3295eb421afe6 3fdc94851fc0f1d5 40376b1f4467041d 1,3",
    "3fb6cdd9bc8dd7e2 3fde26a4f2038780 403717255fd0ff7d 1,3,4",
    "3fca279e21ae6bbf 3fe20efc333049a7 40364206e409dadd 1,3,4,5",
    "3fd2cbce1f228260 3fe51799bc1893e1 4034392d4c3207b3 1,3,4,5,6",
    "3fd482f50c26a5d8 3fd1346282973694 402ffd264d682129 1,3,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/strided/std" => [
    "3fb5ceffb5ec6c9e 3fe46e6b0201ea2e 40387929fa897241 1,3,2",
    "3fcfe99859a8b851 3fdeae6d685da6dc 40359a7616a45e05 1,3,2",
    "3fd0ad72b66cf391 3fe395c9b128aefd 403303205ecaa9f3 1,3,2,4",
    "3faa6bf99308e7ae 3fe3c4ec1984f2ed 4032ba4977c5e0fd 1,3,2,4,5",
    "3fbecf6415d50675 3fe45b85e112d3b7 4032640d02617ae5 1,3,2,4,5,6",
    "3fcf1458d7da792a 3fd34cc7c7777e6c 40300eca97771250 1,3,2,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/strided/zerocurv" => [
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fcf128c6b70f525 3fddfdf5664d394f 4035c9c9802254df 1,3",
    "3fd09334abf47809 3fe3049f19458227 403383f6717a73e8 1,3,4",
    "3fa9efebdccb8bd0 3fe32f91ca1ea5c3 403335e3488871b0 1,3,4,5",
    "3fbdc7fd4b2399f1 3fe3d6acb03f7e11 4032ed0366b1b5a7 1,3,4,5,6",
    "3fced6c7be928b76 3fd28dc856163a42 40308d63fb9ddf85 1,3,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/vecperm/std" => [
    "3fc4054fc6b39d06 3fe5038a62bd4fca 4033aa793acdd5ca 1,3,2",
    "3fd7fb0082eec6aa 3fe084ab48d76c13 4031bfb28ee83138 1,3,2",
    "3fc4b3b9c9299f75 3fe187fcd94d3f2d 40315372cd3c8622 1,3,2,4",
    "3fc1a1775d132b7c 3fe2761adc633c5a 40314e9a48185d9d 1,3,2,4,5",
    "3fbed9605e2dd5ea 3fe2efcb29d0a734 40310b67dffa8139 1,3,2,4,5,6",
    "3fcac8bf2eb0db90 3fd437a57f5830b8 402d5f6319816b94 1,3,2,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/L1/vecperm/zerocurv" => [
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdde0e960b81d07 4032c56445253d5f 1,3",
    "3fc66cbc1912a5d2 3fe007985633c37a 4032251b047bafff 1,3,4",
    "3fc399c4c5ab5ab8 3fe122b2003c2ccf 403229a0180cd76f 1,3,4,5",
    "3fbff9d1d1fd1f00 3fe1a45555659647 4031e1fac20147bf 1,3,4,5,6",
    "3fcaa95c97882023 3fd2a4848b189a74 402ed8c6d300a1e6 1,3,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/MCP/contig/std" => [
    "3fd38a8991ab05e4 3feb5ba8b9b21ceb 40363bd4410cc516 1,3,2",
    "3fd0f1d8a96eedfb 3fe579cb2ec4697e 4034e7ef2fa1e615 1,3,2",
    "3fc39e8a2de97218 3fe69c2e38ae66c6 403472baf45dbf1a 1,3,2,4",
    "3fc978d97b511a1f 3fe85c21e49fb487 40341547f0cb078f 1,3,2,4,5",
    "3fcfbba5e4c61742 3febb9788abb0c9e 40322e9c00508a4c 1,3,2,4,5,6",
    "3fd10a19203a9c80 3fe0c6ec32621aa3 402cd8bb0d2489ce 1,3,2,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/MCP/strided/std" => [
    "3fb8043540b390b3 3fe489dd9b129a81 40386a7387c5482d 1,3,2",
    "3fd0a04834986636 3fdf5277ab924ff5 4035884f0e6a1f43 1,3,2",
    "3fd1421fc36bce76 3fe44238ffd6a869 4032eae7f603b5d0 1,3,2,4",
    "3fae29b989d411e8 3fe480f11c1013eb 403293e1168164f5 1,3,2,4,5",
    "3fc0fa9e2753106e 3fe545a1ad63b631 40322a036c91bfa0 1,3,2,4,5,6",
    "3fccf8f8d5a1a04f 3fd6118b8ed302f3 40303376fd4fde11 1,3,2,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/MCP/vecperm/std" => [
    "3fc52230ffb65466 3fe52b5d473bdcaf 40338ac66e87f860 1,3,2",
    "3fd884382a412518 3fe0fe2a0e5ef5a7 4031a57668aad932 1,3,2",
    "3fc50a29457b7395 3fe215de49d118be 4031526abe9a8e04 1,3,2,4",
    "3fc2a53ed04235cc 3fe331aeeb92e78c 40313d065feb4cb6 1,3,2,4,5",
    "3fbf638dd3924282 3fe3b4feed613519 4030ed7c0748c701 1,3,2,4,5,6",
    "3fc9ec721bbdc880 3fd6d151f5a4319d 402d458e1e5c4543 1,3,2,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SCAD/contig/std" => [
    "3fd38a8991ab05e4 3feb5ba8b9b21ceb 40363bd4410cc516 1,3,2",
    "3fd0f1d8a96eedfb 3fe579cb2ec4697e 4034e7ef2fa1e615 1,3,2",
    "3fc39e8a2de97218 3fe69c2e38ae66c6 403472baf45dbf1a 1,3,2,4",
    "3fc978d97b511a1f 3fe85c21e49fb487 40341547f0cb078f 1,3,2,4,5",
    "3fcfbba5e4c61742 3febb9788abb0c9e 40322e9c00508a4c 1,3,2,4,5,6",
    "3fd10a19203a9c80 3fe0c6ec32621aa3 402cd8bb0d2489ce 1,3,2,4,5,6",
    "0 3fe40e068addb815 40377a86ea6c9598 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "0 3fdb1eb76762359a 403747130c761a20 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SCAD/strided/std" => [
    "3fb8043540b390b3 3fe489dd9b129a81 40386a7387c5482d 1,3,2",
    "3fd0a04834986636 3fdf5277ab924ff5 4035884f0e6a1f43 1,3,2",
    "3fd1421fc36bce76 3fe44238ffd6a869 4032eae7f603b5d0 1,3,2,4",
    "3fae29b989d411e8 3fe480f11c1013eb 403293e1168164f5 1,3,2,4,5",
    "3fc0fa9e2753106e 3fe545a1ad63b631 40322a036c91bfa0 1,3,2,4,5,6",
    "3fccf8f8d5a1a04f 3fd6118b8ed302f3 40303376fd4fde11 1,3,2,4,5,6",
    "0 3fe40e068addb815 4038d5ccb840a4ba 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "0 3fdb1eb76762359a 40367eefb60f46ee 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "LS/SCAD/vecperm/std" => [
    "3fc52230ffb65466 3fe52b5d473bdcaf 40338ac66e87f860 1,3,2",
    "3fd884382a412518 3fe0fe2a0e5ef5a7 4031a57668aad932 1,3,2",
    "3fc50a29457b7395 3fe215de49d118be 4031526abe9a8e04 1,3,2,4",
    "3fc2a53ed04235cc 3fe331aeeb92e78c 40313d065feb4cb6 1,3,2,4,5",
    "3fbf638dd3924282 3fe3b4feed613519 4030ed7c0748c701 1,3,2,4,5,6",
    "3fc9ec721bbdc880 3fd6d151f5a4319d 402d458e1e5c4543 1,3,2,4,5,6",
    "0 3fe40e068addb815 4034edef32999148 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "0 3fdb1eb76762359a 4033e126d341ec77 1,3",
    "3fd8748fcccccccd 0 40316e9288000000 1,3"],
  "Quad/Linf/contig/std" => [
    "3fd300476cc80957 3feb320725b0a1bf 3ffc26027b293774 1,3,2",
    "3fd18171b022be22 3fe543503a9a4c37 3ff73632d7b0c7da 1,3,2",
    "3fc269605691acb9 3fe65258296d4d61 3ff5f3fd0fb9909c 1,3,2,4",
    "3fc85d85196cc905 3fe7f921ccbea87e 3ff73a354a785ddf 1,3,2,4,5",
    "3fcecd11f37e4dca 3feb30fb4f13bc90 3ff5f1c7f8de3201 1,3,2,4,5,6",
    "3fd12dbac92ec929 3fe01744c51b56d8 3ff079017bc229e1 1,3,2,4,5,6",
    "3fc4bf5dffe88a4e 3fe696fa4c128ea2 3ffbe45956816959 1,3,2",
    "3fd7a70533333334 3fe0184f74e5f15a 3ff3206ca9e09d9b 1,3,2",
    "3f7388e67c786fda 3fe0193df6098de1 3ff3354d611c5e8f 1,3,2,4",
    "3fa76b5706a6d465 3fe05103377261a8 3ff3bfd2184c02bc 1,3,2,4,5",
    "3fa842201cc82a92 3fe09acaeab00b38 3ff2c73e1cc61c13 1,3,2,4,5,6",
    "3fd79103c192a9e0 3fb89aae3ca131f5 3fe750d453c9aff6 1,3,2,4,5,6",
    "3fc6518418993a15 3feb320725b0a1bf 3ffc26027b293774 1,3,2",
    "3fc3cd868f1061a3 3fe543503a9a4c37 3ff73632d7b0c7da 1,3,2",
    "3fb55830b64ecfdc 3fe65258296d4d61 3ff5f3fd0fb9909c 1,3,2,4",
    "3fbde2c24f0e5958 3fe7f921ccbea87e 3ff73a354a785ddf 1,3,2,4,5",
    "3fc22d1aa569bc70 3feb30fb4f13bc90 3ff5f1c7f8de3201 1,3,2,4,5,6",
    "3fc64521dcb35887 3fe01744c51b56d8 3ff079017bc229e1 1,3,2,4,5,6"],
  "Quad/Linf/contig/zerocurv" => [
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd2b169be97f2a3 3fdcb72b77a15bd8 3ff4b12dfaaf1e4b 1,3",
    "3fb6f1c601c399a7 3fde7e1d2b703963 3ff3dbe87368838e 1,3,4",
    "3fcabfd8306aacb8 3fe2766098323fc8 3ff47cef1f1e55ab 1,3,4,5",
    "3fd2e35b1d3b8f7c 3fe59a1ee3aacfd8 3ff31de14ed9ff6a 1,3,4,5,6",
    "3fd3fa2104d83d39 3fd27944986f8543 3fe8e7fc20bb66fd 1,3,4,5,6",
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "3f965338b005e9b3 3fdb45a797536fc8 3ff36f82ce595466 1,3,4",
    "3fb887d1264a2b40 3fdd4bfec627d8d6 3ff1bc8c41593a23 1,3,4,5",
    "3fa3b4bc9a83dc2a 3fddada91a99dcdc 3ff11ae3185235d6 1,3,4,5,6",
    "3fd8cc2cc5c853d1 3fa4880601996eea 3fd968c17dfe4865 1,3,4,5,6",
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fc5256218e3eda7 3fdcb72b77a15bd8 3ff4b12dfaaf1e4b 1,3",
    "3fab7082ea663a19 3fde7e1d2b703963 3ff3dbe87368838e 1,3,4",
    "3fc067aec01ffe81 3fe2766098323fc8 3ff47cef1f1e55ab 1,3,4,5",
    "3fc64ad6e2049e1e 3fe59a1ee3aacfd8 3ff31de14ed9ff6a 1,3,4,5,6",
    "3fc9e5dbcf91fa85 3fd27944986f8543 3fe8e7fc20bb66fd 1,3,4,5,6"],
  "Quad/Linf/strided/std" => [
    "3fb5ceffb5ec6c9c 3fe47d3803e3e1b6 3ff072b0e5b67ad3 1,3,2",
    "3fd083b8af5dbe01 3fdf0ae36872510e 3fed221c9ace92f8 1,3,2",
    "3fd0bfafa83b454c 3fe3f86e0efaf79b 3ff30ba6acbb3f74 1,3,2,4",
    "3fabab4ce523ee89 3fe4322d73f5e8c1 3ff36a05f8219256 1,3,2,4,5",
    "3fbf51be64a160f9 3fe4e003244918be 3ff1e5ff84e6eb96 1,3,2,4,5,6",
    "3fcd2d915c14d6b7 3fd4de5954ecccd7 3feebd0efb533818 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff01fad6760e6d6 1,3",
    "3fd7167fb8dbfa9d 3fdb22b34b3663ed 3ff03d44dbc9abfd 1,3",
    "3fb968c029b32111 3fddafe3f26d7430 3ff0d392d3f5fb34 1,3,4",
    "3f5d7e9578f22100 3fddb027e8e695c8 3ff0bee6dda36c44 1,3,4,5",
    "0 3fddb027e8e695c8 3ff0bee6dda36c44 1,3,4,5",
    "3fd7b786af8d4f2d 3fa4e2c21594c43e 3fde68cb1b6f08ec 1,3,4,5",
    "3fab97d685ab9c74 3fe47d3803e3e1b6 3ff072b0e5b67ad3 1,3,2",
    "3fc1958d8112dfef 3fdf0ae36872510e 3fed221c9ace92f8 1,3,2",
    "3fc4ac815a78d81c 3fe3f86e0efaf79b 3ff30ba6acbb3f74 1,3,2,4",
    "3fa0f8159208cf0a 3fe4322d73f5e8c1 3ff36a05f8219256 1,3,2,4,5",
    "3fb3f87c0300c434 3fe4e003244918be 3ff1e5ff84e6eb96 1,3,2,4,5,6",
    "3fbe9f2cbec072d2 3fd4de5954ecccd7 3feebd0efb533818 1,3,2,4,5,6"],
  "Quad/Linf/strided/zerocurv" => [
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fce86c22716be58 3fde34453e139815 3fe85fc7887df797 1,3",
    "3fd093bec7cd8898 3fe35a4ae5718c59 3ff07727d0bd0b5a 1,3,4",
    "3fa9d8dc03dda63c 3fe38eb7333143dd 3ff114130de76240 1,3,4,5",
    "3fbe39afa6fdfa61 3fe453d8b1f3f3aa 3fef21c17f41066c 1,3,4,5,6",
    "3fcd2500acde7bb8 3fd4299e775cf6ce 3fec03ecc8b9209c 1,3,4,5,6",
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fd7167fb8dbfa9d 3fdb22b34b3663ed 3fec9a945977c6ff 1,3",
    "3fb968c029b32111 3fddafe3f26d7430 3fecf20a2dfc1c38 1,3,4",
    "3f5d7e9578f22100 3fddb027e8e695c8 3feccfb2ea80b9ea 1,3,4,5",
    "0 3fddb027e8e695c8 3feccfb2ea80b9ea 1,3,4,5",
    "3fd7b786af8d4f2d 3fa4e2c21594c43e 3fdacc234c79df28 1,3,4,5",
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fc1f0ca4ea0909b 3fde34453e139815 3fe85fc7887df797 1,3",
    "3fc476444d852cb7 3fe35a4ae5718c59 3ff07727d0bd0b5a 1,3,4",
    "3f9f5c198933b33c 3fe38eb7333143dd 3ff114130de76240 1,3,4,5",
    "3fb345e820981cb1 3fe453d8b1f3f3aa 3fef21c17f41066c 1,3,4,5,6",
    "3fbe962f901c31f0 3fd4299e775cf6ce 3fec03ecc8b9209c 1,3,4,5,6"],
  "Quad/Linf/vecperm/std" => [
    "3fc4054fc6b39d05 3fe51477435c98fe 3ff4be74ac342972 1,3,2",
    "3fd87e5627399eca 3fe0c0d76222687a 3ff2c6711c1073a2 1,3,2",
    "3fc42cb2106c371b 3fe1c6a983571362 3ff48eb42a648ade 1,3,2,4",
    "3fc0fd533f5f11fe 3fe2c5aa971e640a 3ff29576838c50fd 1,3,2,4,5",
    "3fbe32b1de7e0394 3fe33f05eb062b97 3ff3bfac61076f3a 1,3,2,4,5,6",
    "3fca2d03331be59f 3fd5859cdb75ed99 3fee2be044cbfa6f 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff4d67c82617b03 1,3",
    "3fd81fd5e4cbbaab 3fdb249647831a9f 3ff2ccf5a9c6b2d9 1,3",
    "3f949787b04111b0 3fdb45b6d164ead8 3ff324e591588ceb 1,3,4",
    "0 3fdb45b6d164ead8 3ff324e591588ceb 1,3,4",
    "0 3fdb45b6d164ead8 3ff324e591588ceb 1,3,4",
    "3fd366a7e0a42e6d 3fa12f5db022a2d2 3fd5ac5908ef479d 1,3,4",
    "3fb51f07a86110af 3fe51477435c98fe 3ff4be74ac342972 1,3,2",
    "3fcce872df906307 3fe0c0d76222687a 3ff2c6711c1073a2 1,3,2",
    "3fb7b26196d4102d 3fe1c6a983571362 3ff48eb42a648ade 1,3,2,4",
    "3fb457a790f0ec3f 3fe2c5aa971e640a 3ff29576838c50fd 1,3,2,4,5",
    "3fb15c42e8e6ecbd 3fe33f05eb062b97 3ff3bfac61076f3a 1,3,2,4,5,6",
    "3fbf5229da00c0f5 3fd5859cdb75ed99 3fee2be044cbfa6f 1,3,2,4,5,6"],
  "Quad/Linf/vecperm/zerocurv" => [
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd81fd5e4cbbaab 3fde16e95d1557be 3ff16c1fcdc2c76b 1,3",
    "3fc6026e505c287d 3fe025aa11a947ce 3ff2924968abf25a 1,3,4",
    "3fc32edfd158bba5 3fe15d37d2d9282a 3fefa47f7e9d529e 1,3,4,5",
    "3fbf35bf49e77d3e 3fe1dc0851990b53 3ff0da056112e8fe 1,3,4,5,6",
    "3fc9db4f5411892c 3fd3c82f7e004735 3fea35a1a37c7cd4 1,3,4,5,6",
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd81fd5e4cbbaab 3fdb249647831a9f 3ff0a18c5d91a4f8 1,3",
    "3f949787b04111b0 3fdb45b6d164ead8 3ff0eeff7028b031 1,3,4",
    "0 3fdb45b6d164ead8 3ff0eeff7028b031 1,3,4",
    "0 3fdb45b6d164ead8 3ff0eeff7028b031 1,3,4",
    "3fd366a7e0a42e6d 3fa12f5db022a2d2 3fd3f656b600fb91 1,3,4",
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fcc78ea680f32ca 3fde16e95d1557be 3ff16c1fcdc2c76b 1,3",
    "3fb9da203f4998f5 3fe025aa11a947ce 3ff2924968abf25a 1,3,4",
    "3fb6f8062a9d29db 3fe15d37d2d9282a 3fefa47f7e9d529e 1,3,4,5",
    "3fb1f12fce9fafc9 3fe1dc0851990b53 3ff0da056112e8fe 1,3,4,5,6",
    "3fbef066c1bbb9fa 3fd3c82f7e004735 3fea35a1a37c7cd4 1,3,4,5,6"],
  "Quad/SGL/contig/std" => [
    "3fd2e26ef37f6edc 3fead9c4a0805e8e 3ffc02c013fa9bbd 1,3,2",
    "3fd1c383ed0ad4c8 3fe4d5420a325d80 3ff6d209f3c2c769 1,3,2",
    "3fc1d39b29c2cd7c 3fe5c6c14b921daf 3ff561fa5eeb542c 1,3,2,4",
    "3fc7beb5826a6189 3fe752815a3158f8 3ff6942eeabfeb40 1,3,2,4,5",
    "3fcded887e5f32d6 3fea3d33e4710fd1 3ff56256028e3257 1,3,2,4,5,6",
    "3fd1ffd8fee0cabd 3fdde0362c73c32b 3fefd5a7d769ac9f 1,3,2,4,5,6",
    "0 3fe40e068addb815 4000deb202974250 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "3fd8748fcccccccd 0 3ca8980000000000 1,3"],
  "Quad/SGL/contig/zerocurv" => [
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd32c545c90beb9 3fdc8b23dd687fda 3ff497e4bfbc3b43 1,3",
    "3fb6a0ce1c268cbe 3fde1b9371761c1c 3ff3ce79f9a484db 1,3,4",
    "3fca0c390ebe7125 3fe20992b027a611 3ff45d2a89bae716 1,3,4,5",
    "3fd2729e56be52e8 3fe4fdbd2098ab03 3ff3035f6127a610 1,3,4,5,6",
    "3fd48b259f7d4880 3fd0f6891d86dce2 3fe85c1d958bec87 1,3,4,5,6",
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "3fd8748fcccccccd 0 3ca5d80000000000 1,3"],
  "Quad/SGL/strided/std" => [
    "3fb5005758699a7e 3fe469feff7cd2df 3ff0592ba56463de 1,3,2",
    "3fd029514c8efc0e 3fde973076f0de0d 3fecb669682dc450 1,3,2",
    "3fd07dcfbcdfbab2 3fe37cefa4bcb8eb 3ff26084ecf2d4e9 1,3,2,4",
    "3fa94f9186abd9f2 3fe3a9f9f3081be3 3ff2a662ac88f1ba 1,3,2,4,5",
    "3fbd8e097a721f16 3fe43a43501c36cc 3ff134070c32d4b4 1,3,2,4,5,6",
    "3fcefe97c3ea14e1 3fd2eb20aeb4433e 3fed8c3ce6113b9b 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff01fad6760e6d6 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "3fd8748fcccccccd 0 3ca171c000000000 1,3"],
  "Quad/SGL/strided/zerocurv" => [
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fcf424b4cf3ab2f 3fddebed6a836d96 3fe814ac6ebcdf00 1,3",
    "3fd0659f73d4300e 3fe2f322e75528b7 3ff0041ce9036519 1,3,4",
    "3fa8e61afa7f17dc 3fe31c6e504f88e1 3ff076e2a98ddeea 1,3,4,5",
    "3fbca68f177d6b67 3fe3bc8081466e36 3fee1cd9e1a0ed71 1,3,4,5,6",
    "3fcee13abe3016a4 3fd23b8b61809b5d 3feada0879f79b2e 1,3,4,5,6",
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "3fd8748fcccccccd 0 3c9e438000000000 1,3"],
  "Quad/SGL/vecperm/std" => [
    "3fc376f69f432163 3fe4faf97d264ad9 3ff4ab23247d4211 1,3,2",
    "3fd834c532300fce 3fe071078daae1c3 3ff2949a66b8a4be 1,3,2",
    "3fc42467ec92f3ab 3fe16b25176364f4 3ff446ad13c98b58 1,3,2,4",
    "3fc0c305a6ce1dcf 3fe24c4784b7c829 3ff267159b060c8c 1,3,2,4,5",
    "3fbde31e748878c6 3fe2bfc546db02e8 3ff35f8c0f5c22c3 1,3,2,4,5,6",
    "3fcaf1557a00037a 3fd3bce702970420 3fecdc7a47a3b1d3 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff4d67c82617b03 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "3fd8748fcccccccd 0 3ca4300000000000 1,3"],
  "Quad/SGL/vecperm/zerocurv" => [
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd7d6ed987f0771 3fddd0b83e936a24 3ff13e35315573e9 1,3",
    "3fc5d3f4f8a1a9d6 3fdfecaa281d32d0 3ff24c551209536c 1,3,4",
    "3fc2c11c02c7a769 3fe10762b75c6609 3fef742e6d15543b 1,3,4,5",
    "3fbed851abb41b3b 3fe180e2a6222830 3ff0843e1035088a 1,3,4,5,6",
    "3fcabe1181f27ee6 3fd233ac55e9033f 3fe9139f3f97e07b 1,3,4,5,6",
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "3fd8748fcccccccd 0 3ca1700000000000 1,3"],
  "Quad/L1/contig/std" => [
    "3fd300476cc80957 3feae93177bdc85c 3ffc0afa49b0b389 1,3,2",
    "3fd1942673dcc0fe 3fe4ea818125e936 3ff6e31da6219e5f 1,3,2",
    "3fc26b2341cdf480 3fe5e3c6fcba8417 3ff552fa54e48537 1,3,2,4",
    "3fc836190eb37a26 3fe776122290b552 3ff66c3a4172fab4 1,3,2,4,5",
    "3fce45120e7dd3c2 3fea6b8c43939a31 3ff538176c9d5fd3 1,3,2,4,5,6",
    "3fd1fe75f63f2a5d 3fde5e412e5c27d8 3fefb9fbf46da811 1,3,2,4,5,6",
    "0 3fe40e068addb815 4000deb202974250 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "3fd8748fcccccccd 0 3ca8980000000000 1,3"],
  "Quad/L1/contig/zerocurv" => [
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd3295eb421afea 3fdc94851fc0f1d4 3ff49bc6e6613e57 1,3",
    "3fb6cdd9bc8dd7e4 3fde26a4f2038780 3ff3cfedcca42acd 1,3,4",
    "3fca279e21ae6bbd 3fe20efc333049a7 3ff470eccaa18cfb 1,3,4,5",
    "3fd2cbce1f228265 3fe51799bc1893e2 3ff30fee3e3c41d3 1,3,4,5,6",
    "3fd482f50c26a5d5 3fd1346282973697 3fe8981b243dc494 1,3,4,5,6",
    "0 3fe40e068addb815 3ffdb700e0bda2a2 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "0 3fdb1eb76762359a 3ff3b757f684d30f 1,3",
    "3fd8748fcccccccd 0 3ca5d80000000000 1,3"],
  "Quad/L1/strided/std" => [
    "3fb5ceffb5ec6c9c 3fe46e6b0201ea2e 3ff0633107bbd2b6 1,3,2",
    "3fcfe99859a8b84f 3fdeae6d685da6dd 3feceaef34db2f62 1,3,2",
    "3fd0ad72b66cf392 3fe395c9b128aefe 3ff24d2a30a9badd 1,3,2,4",
    "3faa6bf99308e7b1 3fe3c4ec1984f2ed 3ff296dcd07bd1a4 1,3,2,4,5",
    "3fbecf6415d5066f 3fe45b85e112d3b7 3ff113f0b6596886 1,3,2,4,5,6",
    "3fcf1458d7da7921 3fd34cc7c7777e71 3feda622928bf680 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff01fad6760e6d6 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "3fd8748fcccccccd 0 3ca171c000000000 1,3"],
  "Quad/L1/strided/zerocurv" => [
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fcf128c6b70f522 3fddfdf5664d3950 3fe8238c2a063870 1,3",
    "3fd09334abf4780a 3fe3049f19458228 3ff0006c84378284 1,3,4",
    "3fa9efebdccb8bd4 3fe32f91ca1ea5c4 3ff071ebf709fc29 1,3,4,5",
    "3fbdc7fd4b2399f7 3fe3d6acb03f7e12 3fedfcf4f21291bd 1,3,4,5,6",
    "3fced6c7be928b6e 3fd28dc856163a48 3fead10502341343 1,3,4,5,6",
    "0 3fe40e068addb815 3fedba89cf3ba408 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "0 3fdb1eb76762359a 3fed198ffb648a15 1,3",
    "3fd8748fcccccccd 0 3c9e438000000000 1,3"],
  "Quad/L1/vecperm/std" => [
    "3fc4054fc6b39d05 3fe5038a62bd4fca 3ff4b08d91940bcf 1,3,2",
    "3fd7fb0082eec6a9 3fe084ab48d76c12 3ff28f105ffc2f6f 1,3,2",
    "3fc4b3b9c9299f6f 3fe187fcd94d3f2c 3ff44fd1285b29b3 1,3,2,4",
    "3fc1a1775d132b7d 3fe2761adc633c59 3ff25e8f23bd903e 1,3,2,4,5",
    "3fbed9605e2dd5ee 3fe2efcb29d0a733 3ff36924be2f3c6d 1,3,2,4,5,6",
    "3fcac8bf2eb0db8e 3fd437a57f5830b8 3fed0778945313ee 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff4d67c82617b03 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "3fd8748fcccccccd 0 3ca4300000000000 1,3"],
  "Quad/L1/vecperm/zerocurv" => [
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd7a70533333334 3fdde0e960b81d07 3ff1376472b908bc 1,3",
    "3fc66cbc1912a5ce 3fe007985633c379 3ff240c3450030b7 1,3,4",
    "3fc399c4c5ab5ab8 3fe122b2003c2cce 3fef48115473ca2f 1,3,4,5",
    "3fbff9d1d1fd1f02 3fe1a45555659646 3ff07cb339861d9e 1,3,4,5,6",
    "3fcaa95c97882021 3fd2a4848b189a74 3fe91d5e8ce8ccd2 1,3,4,5,6",
    "0 3fe40e068addb815 3ff34773377f84e2 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "0 3fdb1eb76762359a 3ff08daa05fcff51 1,3",
    "3fd8748fcccccccd 0 3ca1700000000000 1,3"],
  "Quad/MCP/contig/std" => [
    "3fd38a8991ab05e4 3feb5ba8b9b21ceb 3ffc25f8d5cef0fc 1,3,2",
    "3fd0f1d8a96eedfc 3fe579cb2ec4697e 3ff751dfcac3143b 1,3,2",
    "3fc39e8a2de97217 3fe69c2e38ae66c6 3ff5ef29d5f066c8 1,3,2,4",
    "3fc978d97b511a1d 3fe85c21e49fb487 3ff73ccf5b4f4633 1,3,2,4,5",
    "3fcfbba5e4c61749 3febb9788abb0ca0 3ff5fa93cc6227b8 1,3,2,4,5,6",
    "3fd10a19203a9c7d 3fe0c6ec32621aa5 3ff0b3a45a47af21 1,3,2,4,5,6",
    "0 3fe40e068addb815 4000deb202974250 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "3fd8748fcccccccd 0 3ca8980000000000 1,3"],
  "Quad/MCP/strided/std" => [
    "3fb8043540b390b1 3fe489dd9b129a81 3ff07ad73efb0c37 1,3,2",
    "3fd0a04834986634 3fdf5277ab924ff5 3fed3376d130a1d2 1,3,2",
    "3fd1421fc36bce78 3fe44238ffd6a86a 3ff30ce75bda2fd6 1,3,2,4",
    "3fae29b989d411ea 3fe480f11c1013ec 3ff35e037bce5090 1,3,2,4,5",
    "3fc0fa9e27531070 3fe545a1ad63b633 3ff1dca422dfdd77 1,3,2,4,5,6",
    "3fccf8f8d5a1a046 3fd6118b8ed302f9 3fef44384b2792de 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff01fad6760e6d6 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "3fd8748fcccccccd 0 3ca171c000000000 1,3"],
  "Quad/MCP/vecperm/std" => [
    "3fc52230ffb65465 3fe52b5d473bdcaf 3ff4bf416f809280 1,3,2",
    "3fd884382a412516 3fe0fe2a0e5ef5a6 3ff2cc5515e5421d 1,3,2",
    "3fc50a29457b7392 3fe215de49d118bd 3ff4afa74ac7c223 1,3,2,4",
    "3fc2a53ed04235c7 3fe331aeeb92e78b 3ff2a424c5f1742f 1,3,2,4,5",
    "3fbf638dd3924286 3fe3b4feed613518 3ff3faebe3adf568 1,3,2,4,5,6",
    "3fc9ec721bbdc87c 3fd6d151f5a4319d 3feedb0fd82d9409 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff4d67c82617b03 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "3fd8748fcccccccd 0 3ca4300000000000 1,3"],
  "Quad/SCAD/contig/std" => [
    "3fd38a8991ab05e4 3feb5ba8b9b21ceb 3ffc25f8d5cef0fc 1,3,2",
    "3fd0f1d8a96eedfc 3fe579cb2ec4697e 3ff751dfcac3143b 1,3,2",
    "3fc39e8a2de97217 3fe69c2e38ae66c6 3ff5ef29d5f066c8 1,3,2,4",
    "3fc978d97b511a1d 3fe85c21e49fb487 3ff73ccf5b4f4633 1,3,2,4,5",
    "3fcfbba5e4c61749 3febb9788abb0ca0 3ff5fa93cc6227b8 1,3,2,4,5,6",
    "3fd10a19203a9c7d 3fe0c6ec32621aa5 3ff0b3a45a47af21 1,3,2,4,5,6",
    "0 3fe40e068addb815 4000deb202974250 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "0 3fdb1eb76762359a 3ff7c5a2590b0621 1,3",
    "3fd8748fcccccccd 0 3ca8980000000000 1,3"],
  "Quad/SCAD/strided/std" => [
    "3fb8043540b390b1 3fe489dd9b129a81 3ff07ad73efb0c37 1,3,2",
    "3fd0a04834986634 3fdf5277ab924ff5 3fed3376d130a1d2 1,3,2",
    "3fd1421fc36bce78 3fe44238ffd6a86a 3ff30ce75bda2fd6 1,3,2,4",
    "3fae29b989d411ea 3fe480f11c1013ec 3ff35e037bce5090 1,3,2,4,5",
    "3fc0fa9e27531070 3fe545a1ad63b633 3ff1dca422dfdd77 1,3,2,4,5,6",
    "3fccf8f8d5a1a046 3fd6118b8ed302f9 3fef44384b2792de 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff01fad6760e6d6 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "0 3fdb1eb76762359a 3ff078475009878c 1,3",
    "3fd8748fcccccccd 0 3ca171c000000000 1,3"],
  "Quad/SCAD/vecperm/std" => [
    "3fc52230ffb65465 3fe52b5d473bdcaf 3ff4bf416f809280 1,3,2",
    "3fd884382a412516 3fe0fe2a0e5ef5a6 3ff2cc5515e5421d 1,3,2",
    "3fc50a29457b7392 3fe215de49d118bd 3ff4afa74ac7c223 1,3,2,4",
    "3fc2a53ed04235c7 3fe331aeeb92e78b 3ff2a424c5f1742f 1,3,2,4,5",
    "3fbf638dd3924286 3fe3b4feed613518 3ff3faebe3adf568 1,3,2,4,5,6",
    "3fc9ec721bbdc87c 3fd6d151f5a4319d 3feedb0fd82d9409 1,3,2,4,5,6",
    "0 3fe40e068addb815 3ff4d67c82617b03 1,3",
    "3fd7a70533333334 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "0 3fdb1eb76762359a 3ff2c2769c35d054 1,3",
    "3fd8748fcccccccd 0 3ca4300000000000 1,3"],
)

ft28_vec(s) = [reinterpret(Float64, parse(UInt64, w; base = 16)) for w in split(s)]

ft28_layout(name, p) = name == "contig" ? [i:i+4 for i in 1:5:p] :
  name == "strided" ? [k:6:p for k in 1:6] : (perm = sortperm(ft28_stream(p; seed = 3)); [perm[i:i+4] for i in 1:5:p])

# the numbers k / 2^23 in [-1, 1) of a linear congruential generator, the same on every Julia version
function ft28_stream(dims...; seed)
  s = UInt64(seed)
  A = Array{Float64}(undef, dims...)
  for i in eachindex(A)
    s = s * 0x5851f42d4c957f2d + 0x14057b7ef767814f
    A[i] = (Int64(s >> 40) - 2^23) / 2^23
  end
  A
end

function ft28_setup(kind, layout, zerocurv)
  n, p = 40, 30
  X = ft28_stream(n, p; seed = 23); y = ft28_stream(n; seed = 24)
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
    x[groups[k]] .= 0.4 .* ft28_stream(length(groups[k]); seed = 100 + k)
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
      @test isapprox(h, PS._groupstep!(mf, good, xf, 2, scaled); rtol = 1e-12, atol = 1e-14)
      @test collect(activecoordinates(x)) == collect(activecoordinates(xf))
      @test isapprox(Vector(x), Vector(xf); rtol = 1e-12, atol = 1e-14)
      @test isapprox(ft28_cache(kind, m), ft28_cache(kind, mf); rtol = 1e-12, atol = 1e-13)
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

@testset "shared group prox retains finite extreme shrinkage" begin
  groups = [1:2]
  g = GroupNormL2(1e155, groups, [1.])
  x = AtomIterate(2, groups)
  f = QuadraticFunction(Matrix(2.0I, 2, 2), [-2e155,0.])
  m = cdmodel(f, x)
  PS.initialize!(m, x)
  h = PS._groupstep!(m, g, x, 1, false)
  @test Vector(x) ≈ [5e154,0.]
  @test h ≈ 5e154
end

end
