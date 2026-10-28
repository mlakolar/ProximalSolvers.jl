module ActiveSetTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

# lasso with p ≫ n: f(x) = ‖Y - Xx‖² / (2n) = x'Ax/2 + b'x + const
n, p, s = 100, 2000, 10
X = randn(n, p)
β = zeros(p)
β[randperm(p)[1:s]] = randn(s) .+ 2 .* sign.(randn(s))
Y = X * β + 0.1 * randn(n)
A, b = X'X / n, -X'Y / n
f = QuadraticFunction(A, b)
λmax = norm(b, Inf)
λ = 0.2 * λmax

# the weighted lasso leaves two coordinates unpenalized
w = 0.5 .+ rand(p)
w[1:2] .= 0.
penalties = (lasso = NormL1(λ), weighted_lasso = NormL1(λ, w))
thresholds = (lasso = fill(λ, p), weighted_lasso = λ * w)

opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 5000)

@testset "ActiveAccProxGradDescent" begin

  @testset "$name" for name in keys(penalties)
    g, λj = penalties[name], thresholds[name]

    x_full = zeros(p)
    solve!(x_full, f, g, AccProxGradDescent(), opt)

    x = SparseIterate(p)
    res = solve!(x, f, g, ActiveAccProxGradDescent(), opt)
    @test res.minimizer === x
    @test res.converged
    @test res.inner_converged
    @test res.max_violation <= 0
    @test 1 <= res.outer_iterations <= res.inner_iterations
    @test nnz(x) == res.active_set_size == count(!iszero, Vector(x))    # no stored zeros
    @test res.minimum ≈ f(Vector(x)) + g(Vector(x))

    xv = Vector(x)
    @test xv ≈ x_full atol = 1e-4

    # KKT conditions: ∇f(x) = -λⱼ sign(xⱼ) on the support, |∇f(x)ⱼ| ≤ λⱼ off it
    grad = A * xv + b
    S = xv .!= 0
    @test 0 < count(S) < n
    @test grad[S] ≈ -λj[S] .* sign.(xv[S]) atol = 1e-4
    @test all(abs.(grad[.!S]) .<= λj[.!S] .+ 1e-4)

    # adding one violator per outer iteration reaches the same solution
    x1 = SparseIterate(p)
    res1 = solve!(x1, f, g, ActiveAccProxGradDescent(; max_add = 1, growth = 1), opt)
    @test res1.converged
    @test res1.outer_iterations >= nnz(x1)
    @test res1.outer_iterations > res.outer_iterations
    @test Vector(x1) ≈ xv atol = 1e-4

    # a dense starting point takes the same path, and is overwritten with the solution
    xd = zeros(p)
    resd = solve!(xd, f, g, ActiveAccProxGradDescent(), opt)
    @test resd.minimizer === xd
    @test xd == xv
    @test resd.outer_iterations == res.outer_iterations
    @test resd.inner_iterations == res.inner_iterations
    @test resd.minimum == res.minimum
  end

  g = penalties.lasso
  x_ref = zeros(p)
  solve!(x_ref, f, g, ActiveAccProxGradDescent(), opt)
  support = x_ref .!= 0

  @testset "starting points" begin
    # from zero, with λ ≥ λmax zero is the solution and no inner problem is solved
    x = SparseIterate(p)
    res = solve!(x, f, NormL1(λmax), ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test res.outer_iterations == res.inner_iterations == 0
    @test nnz(x) == 0
    @test res.minimum == 0.

    xd = zeros(p)
    res = solve!(xd, f, NormL1(λmax), ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test res.outer_iterations == 0
    @test xd == zeros(p)

    # stored zeros are dropped before the first iteration
    x = SparseIterate(p)
    for i in 1:p
      activate!(x, i)
    end
    solve!(x, f, g, ActiveAccProxGradDescent(), opt)
    @test Vector(x) == x_ref

    # a starting point that does not minimize over its support is solved, even
    # though no coordinate outside the support violates the KKT conditions
    x0 = copy(x_ref)
    x0[support] .+= 0.01 .* randn(count(support))
    grad0 = A * x0 + b
    @test all(abs.(grad0[.!support]) .< λ)
    @test norm(grad0[support] + λ * sign.(x0[support]), Inf) > 1e-3
    res = solve!(x0, f, g, ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test res.outer_iterations == 1
    @test x0 ≈ x_ref atol = 1e-4

    # a dense starting point: the first active set holds every coordinate
    x0 = randn(p)
    res = solve!(x0, f, g, ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test x0 ≈ x_ref atol = 1e-4
  end

  @testset "other functions" begin
    # ‖Y - Xx‖² / 2 = n f(x) + const, so the penalty scales by n
    x = SparseIterate(p)
    res = solve!(x, LeastSquaresLoss(Y, X), NormL1(n * λ), ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test Vector(x) ≈ x_ref atol = 1e-4

    y = randn(50)
    x = zeros(50)
    res = solve!(x, SqrNormL2(1, y), NormL1(1.), ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test x ≈ shrink.(y, 1.) atol = 1e-6
    @test res.minimum ≈ SqrNormL2(1, y)(x) + NormL1(1.)(x)

    x = zeros(50)
    res = solve!(x, SqrNormL2(1, y), ZeroFunction(), ActiveAccProxGradDescent(), opt)
    @test res.converged
    @test x ≈ y atol = 1e-6
  end

  @testset "inner iteration limit" begin
    # an inner solve stopped by maxiter is repeated, warm-started, until one converges
    x = SparseIterate(p)
    res = solve!(x, f, g, ActiveAccProxGradDescent(),
                 ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 10))
    @test res.converged
    @test !res.inner_converged
    @test Vector(x) ≈ x_ref atol = 1e-4
  end

  @testset "within rounding of λmax" begin
    # just below λmax the check can flag the coordinate (or group) that attains
    # λmax while the proximal step leaves it at zero; the solver stops after
    # that solve instead of adding it again until max_outer
    groups = [((k - 1) * 5 + 1):(k * 5) for k in 1:(p ÷ 5)]
    λgmax = maximum(norm(b[G]) / sqrt(5) for G in groups)
    for k in 0:8
      x = SparseIterate(p)
      res = solve!(x, f, NormL1(prevfloat(λmax, k)), ActiveAccProxGradDescent(), opt)
      @test res.converged && res.outer_iterations <= 2
      @test norm(Vector(x)) < 1e-8
      xg = zeros(p)
      res = solve!(xg, f, GroupNormL2(prevfloat(λgmax, k), groups), ActiveAccProxGradDescent(), opt)
      @test res.converged && res.outer_iterations <= 2
      @test norm(xg) < 1e-8
    end
  end

  @testset "outer iteration limit" begin
    x = SparseIterate(p)
    res = solve!(x, f, g, ActiveAccProxGradDescent(; max_add = 1, growth = 1, max_outer = 3), opt)
    @test !res.converged
    @test res.outer_iterations == 3
    @test res.max_violation > 0
    @test nnz(x) <= 3
  end

  @testset "growth of the active set" begin
    # at x = 0 many more coordinates than max_add violate the optimality conditions
    @test count(abs.(b) .> λ) > 100

    # an outer iteration adds at most max(max_add, (growth - 1) s) violators to
    # s nonzero entries, so with max_add = 1, three of them leave 1 ⋅ growth²
    # entries at most, or 3 for growth = 1
    for (growth, bound) in ((1, 3), (2, 4), (3, 9))
      x = SparseIterate(p)
      res = solve!(x, f, g, ActiveAccProxGradDescent(; max_add = 1, growth, max_outer = 3), opt)
      @test res.outer_iterations == 3
      @test 0 < nnz(x) <= bound
    end

    # without a limit, or with one that saturates, the solution is the same
    for method in (ActiveAccProxGradDescent(; max_add = typemax(Int)),
                   ActiveAccProxGradDescent(; max_add = 1, growth = typemax(Int)))
      x = SparseIterate(p)
      res = solve!(x, f, g, method, opt)
      @test res.converged
      @test Vector(x) ≈ x_ref atol = 1e-4
    end
  end

  @testset "show and arguments" begin
    x = SparseIterate(p)
    res = solve!(x, f, g, ActiveAccProxGradDescent(), opt)
    str = sprint(show, res)
    @test occursin(summary(ActiveAccProxGradDescent()), str)
    @test occursin("Outer iterations: $(res.outer_iterations)", str)
    @test occursin("Inner iterations: $(res.inner_iterations)", str)

    @test_throws ArgumentError ActiveAccProxGradDescent(; β = 1.)
    @test_throws ArgumentError ActiveAccProxGradDescent(; max_add = 0)
    @test_throws ArgumentError ActiveAccProxGradDescent(; growth = 0)
    @test_throws ArgumentError ActiveAccProxGradDescent(; max_outer = 0)
  end

end

function _check_float32_result(res, f, g, reference; cutoff = false)
  @test typeof(res.minimum) == Float32
  @test typeof(res.max_violation) == Float32
  @test eltype(res.minimizer) == Float32
  @test res.converged == !cutoff
  @test reference.converged == !cutoff
  objective = Float32(f(res.minimizer) + g(res.minimizer))
  @test abs(res.minimum - objective) <= eps(abs(objective))
  @test res.minimum ≈ reference.minimum rtol = 1e-4 atol = 1e-6
end

function _inactive_violation(f, g, x)
  grad = zeros(eltype(x), length(x))
  value_and_gradient!(grad, f, x)
  maximum((Float32(kkt_violation(g, grad, x, k)) for k in 1:ncoordinates(x)
           if !isactive(x, k)); init = -Inf32)
end

@testset "Float64 parameters on Float32 data (#130)" begin
  method = ActiveAccProxGradDescent()
  A = Float32[2 0.5 0; 0.5 1 0; 0 0 1]
  b = Float32[-1, 0.2, 0.05]
  f = QuadraticFunction(A, b)
  f64 = QuadraticFunction(Float64.(A), Float64.(b))
  g = NormL1(0.1)
  reference = solve!(SparseIterate(3), f64, g, method)

  @testset "Sparse and dense starts" begin
    for x in (SparseIterate(Float32, 3), zeros(Float32, 3))
      res = solve!(x, f, g, method)
      _check_float32_result(res, f, g, reference)
      @test res.active_set_size < length(x)
      if x isa SparseIterate
        @test isfinite(res.max_violation) && res.max_violation < 0
        @test res.max_violation == _inactive_violation(f, g, x)
      end
    end
  end

  rng = Xoshiro(7)
  n, p = 40, 8
  X = randn(rng, Float32, n, p)
  y = X[:, 1:2] * Float32[1, -2] + 0.1f0 * randn(rng, Float32, n)
  scale = 1f0 / n
  f_ls = scale * LeastSquaresLoss(y, X)
  f_ls64 = Float64(scale) * LeastSquaresLoss(Float64.(y), Float64.(X))

  @testset "Other separable penalties" begin
    for penalty in (ElasticNet(0.1, 0.5), MCP(0.1, 3.0))
      ref = solve!(SparseIterate(p), f_ls64, penalty, method)
      for x in (SparseIterate(Float32, p), zeros(Float32, p))
        res = solve!(x, f_ls, penalty, method)
        _check_float32_result(res, f_ls, penalty, ref)
      end
    end
  end

  @testset "Inactive coordinates and groups" begin
    weighted = NormL1(0.1f0, [1.0, 2.0, 1.0])
    x = SparseIterate(Float32, 3)
    res = solve!(x, f, weighted, method)
    ref = solve!(SparseIterate(3), f64, weighted, method)
    _check_float32_result(res, f, weighted, ref)
    @test res.active_set_size < length(x)
    @test res.max_violation == _inactive_violation(f, weighted, x)

    groups = [[1, 2], [3, 4], [5, 6]]
    A6 = Matrix(2f0 * I, 6, 6)
    b6 = Float32[-1, 0.2, 0.05, 0.03, -0.4, 0.01]
    fg = QuadraticFunction(A6, b6)
    fg64 = QuadraticFunction(Float64.(A6), Float64.(b6))
    gg = GroupNormL2(0.1, groups)
    ref = solve!(AtomIterate(6, groups), fg64, gg, method)
    for x in (AtomIterate(Float32, 6, groups), SparseIterate(Float32, 6), zeros(Float32, 6))
      res = solve!(x, fg, gg, method)
      _check_float32_result(res, fg, gg, ref)
      @test res.active_set_size < length(x)
      @test all(iszero, x[groups[2]])
      if x isa Union{SparseIterate, AtomIterate}
        @test res.max_violation == _inactive_violation(fg, gg, x)
      end
    end
  end

  @testset "Minimum without an inner solve" begin
    scaled = 1.1 * QuadraticFunction(Float32[1;;], Float32[0], 1f0)
    scaled64 = 1.1 * QuadraticFunction(Float64[1;;], Float64[0], 1.0)
    penalty = NormL1(0.1f0)
    res = solve!(SparseIterate(Float32, 1), scaled, penalty, method)
    ref = solve!(SparseIterate(1), scaled64, penalty, method)
    _check_float32_result(res, scaled, penalty, ref)
    @test res.outer_iterations == res.inner_iterations == 0
    expected = Float32(1.1 * 0.5 * 0 + 1.1 * 1)
    @test res.minimum === expected
  end

  @testset "Trace and gap options" begin
    res = redirect_stdout(devnull) do
      solve!(SparseIterate(Float32, 3), f, g, method, ProximalOptions(; show_trace = true))
    end
    _check_float32_result(res, f, g, reference)

    res = @test_logs (:warn, r"there is no duality gap .*gaptol is ignored") solve!(
      SparseIterate(Float32, 3), f, g, method, ProximalOptions(; gaptol = 1e-6))
    _check_float32_result(res, f, g, reference)

    options = ProximalOptions(; gaptol = 1e-6)
    x = SparseIterate(Float32, p)
    @test ProximalSolvers._gapevaluator(f_ls, g, x) !== nothing
    res = solve!(x, f_ls, g, method, options)
    ref = solve!(SparseIterate(p), f_ls64, g, method, options)
    _check_float32_result(res, f_ls, g, ref)
  end

  @testset "Positive violation at the outer limit" begin
    fc = QuadraticFunction(Matrix(2f0 * I, 3, 3), Float32[-1, -0.6, 0.05])
    fc64 = QuadraticFunction(Matrix(2.0 * I, 3, 3), Float64.(Float32[-1, -0.6, 0.05]))
    cutoff = ActiveAccProxGradDescent(; max_add = 1, growth = 1, max_outer = 1)
    x = SparseIterate(Float32, 3)
    res = solve!(x, fc, g, cutoff)
    # Use the same outer limit to compare the unfinished Float64 solve.
    ref = solve!(SparseIterate(3), fc64, g, cutoff)
    _check_float32_result(res, fc, g, ref; cutoff = true)
    @test res.outer_iterations == 1
    @test res.active_set_size == 1
    @test res.max_violation > 0
    @test res.max_violation == _inactive_violation(fc, g, x)
  end

  @testset "All coordinates active" begin
    fa = QuadraticFunction(Matrix(1f0 * I, 2, 2), Float32[-1, 0.6])
    fa64 = QuadraticFunction(Matrix(1.0 * I, 2, 2), Float64.(Float32[-1, 0.6]))
    x = SparseIterate(Float32, 2)
    res = solve!(x, fa, g, method)
    ref = solve!(SparseIterate(2), fa64, g, method)
    _check_float32_result(res, fa, g, ref)
    @test res.active_set_size == length(x)
    @test res.max_violation === -Inf32
  end

  @testset "Violation rounded after evaluation" begin
    fb = QuadraticFunction(Float32[1;;], Float32[0.1])
    fb64 = QuadraticFunction(Float64[1;;], Float64.(Float32[0.1]))
    x = SparseIterate(Float32, 1)
    res = solve!(x, fb, g, method)
    ref = solve!(SparseIterate(1), fb64, g, method)
    _check_float32_result(res, fb, g, ref)
    expected = Float32(abs(0.1f0) - 0.1)
    @test expected > 0
    @test res.max_violation === expected
    @test res.max_violation == _inactive_violation(fb, g, x)
    @test res.active_set_size == 0
  end
end

end
