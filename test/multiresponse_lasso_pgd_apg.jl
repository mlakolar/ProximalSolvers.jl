module MultiresponseLassoGradientTests

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
const PB = ProximalBase
const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const PRECISIONS = (Float32, Float64)

accuracy(::Type{Float32}) = 3e-4
accuracy(::Type{Float64}) = 3e-7
options(T) = ProximalOptions(maxiter = 12_000, ftol = 0, xtol = 1e-14,
                             gradtol = T === Float32 ? 1e-6 : 1e-9, allow_f_increases = true)

loss(Y, X, s) = isone(s) ? LeastSquaresLoss(Y, X) : s * LeastSquaresLoss(Y, X)
soft(v, λ) = sign(v) * max(abs(v) - λ, zero(v))

function oracle(X, Y, B, s, λ)
  setprecision(BigFloat, 256) do
    A, C, b = BigFloat.(X), BigFloat.(Y), BigFloat.(B)
    residual = A*b - C
    G = BigFloat(s) * (A' * residual)
    level = BigFloat(λ)
    score = map(b, G) do x, g
      iszero(x) ? max(abs(g) - level, zero(g)) : abs(g + level * sign(x))
    end
    F = BigFloat(s) * sum(abs2, residual) / 2 + level * sum(abs, b)
    (; F, G, score, R = maximum(score), S = max(level, maximum(abs, BigFloat(s) * (A' * C))))
  end
end

function check_result(result, X, Y, B, s, λ, opts; stationary = true)
  T = eltype(B)
  ref = oracle(X, Y, B, s, T(λ))
  @test result.minimizer === B
  @test result.minimizer isa Matrix{T} && size(result.minimizer) == (size(X, 2), size(Y, 2))
  @test isfinite(result.minimum)
  @test abs(result.minimum - ref.F) <= 64eps(T) * max(1, ref.F)
  stationary && @test ref.R <= accuracy(T) * max(1, ref.S)
  if result.converged
    # Allow for the rounding of the native gradient and of the threshold.
    τ = max(opts.gradtol, 64eps(T))
    @test ref.S > 0 && ref.R <= (τ + 8eps(T) * size(X, 1)) * ref.S
  end
  ref
end

function orthogonal_data(T)
  X = T[1 1 1; 1 -1 1; 1 1 -1; 1 -1 -1]
  C = T[2 0.25 -1; 0 -2 0.5; 1 0.125 -0.25]
  X, X*C
end

@testset "matrix oracles and the orthogonal entrywise solution" begin
  for T in PRECISIONS
    X, Y = orthogonal_data(T)
    sample = T[0.25 1 -2; -1.5 0 1; 0.5 0.25 -0.5]
    Z, D, G = X*sample, similar(Y), similar(sample)
    rectangular = sample[:, 2:3]
    @test PS._norm_inf(rectangular) === T(2)
    @test PS._norm_diff(rectangular, -rectangular, Inf) === T(4)
    for s in (one(T), one(T)/T(size(X, 1)))
      # A literal of a different precision must use the validated working level.
      λ = Float64(s) * 2
      f, g = loss(Y, X, s), NormL1(λ)
      ref = oracle(X, Y, sample, s, T(λ))
      @test f(sample) == PB.value_from_predictor(f, Z) == T(s * sum(abs2, Z - Y)/2)
      @test PB.value_and_gradient_from_predictor!(G, D, f, Z) == f(sample)
      @test D == Z - Y && G == T.(ref.G)
      @test PB.kkt_violation(NormL1(T(λ)), G, sample) == T(ref.R)
      step = T(0.25)
      trial = similar(sample)
      expected = soft.(sample, T(λ)*step)
      @test PB.value_and_prox!(trial, NormL1(T(λ)), sample, step) == T(λ)*sum(abs, expected)
      @test trial == expected
      solution = soft.(s * (X' * Y), T(λ)) ./ (4s)
      @test !issymmetric(solution) && solution[1, 1] != (X' * Y)[1, 1]/4
      @test any(iszero, solution) && any(>(0), solution) && any(<(0), solution)
      @test any(row -> any(iszero, row) && any(!iszero, row), eachrow(solution))
      for method in METHODS
        B = copy(sample)
        opts = options(T)
        result = solve!(B, f, g, method, opts)
        fitted = check_result(result, X, Y, B, s, λ, opts)
        optimum = oracle(X, Y, solution, s, T(λ))
        @test iszero(optimum.R)
        @test maximum(abs, B - solution) <= accuracy(T)
        @test abs(fitted.F - optimum.F) <= accuracy(T)^2 * max(1, optimum.F)
        @test all(fitted.score .<= accuracy(T) * max(1, optimum.S))
      end
    end
  end
end

@testset "zero, threshold and above-threshold penalties" begin
  for T in PRECISIONS, method in METHODS
    X = T[1 2; 0 2; 2 0; 1 1; -2 1]
    Y = T[1 -3 2; -2 1 0; 2 0 -1; 1 2 0; 1 2 1]
    s = one(T)/T(5)
    f = loss(Y, X, s)
    qr_reference = setprecision(BigFloat, 256) do
      qr(BigFloat.(X)) \ BigFloat.(Y)
    end
    B = zeros(T, 2, 3)
    opts = options(T)
    r = solve!(B, f, NormL1(zero(T)), method, opts)
    fit = check_result(r, X, Y, B, s, 0, opts)
    @test maximum(abs, B - qr_reference) <= accuracy(T)
    @test abs(fit.F - oracle(X, Y, qr_reference, s, 0).F) <= accuracy(T)^2

    X, Y = orthogonal_data(T)
    s = T(0.25)
    λmax = T(oracle(X, Y, zeros(T, 3, 3), s, 0).S)
    for λ in (λmax, 2λmax)
      B = zeros(T, 3, 3)
      stop = ProximalOptions()
      result = solve!(B, loss(Y, X, s), NormL1(λ), method, stop)
      @test result.converged && iszero(B)
      @test iszero(check_result(result, X, Y, B, s, λ, stop).R)
    end
    B, Y = zeros(T, 3, 2), zeros(T, 4, 2)
    stop = ProximalOptions(maxiter = 3)
    result = solve!(B, loss(Y, X, s), NormL1(zero(T)), method, stop)
    ref = check_result(result, X, Y, B, s, 0, stop)
    @test iszero(ref.R) && iszero(ref.S) && !result.converged
    @test result.iteration_converged && result.iterations == 3
  end
end

@testset "rectangular shapes, wide design and one response" begin
  for T in PRECISIONS, method in METHODS
    for (X, Y) in ((T[2 0; 0 2], T[2 -2 4; -3 0 1]),                  # p < K
                   (T[2 0 0; 0 2 0], T[2 -2; -3 1]),                  # n < p, zero column
                   (T[2; 0;;], T[2 -2 4; -3 0 1]),                   # p = 1
                   (T[2 0; 0 2], T[2; -3;;]))                        # K = 1
      n, p = size(X)
      s, λ = one(T)/T(n), T(0.5)
      B = fill(T(-0.25), p, size(Y, 2))
      reference = soft.(s * (X' * Y), λ) ./ (4s)
      opts = options(T)
      r = solve!(B, loss(Y, X, s), NormL1(λ), method, opts)
      fit = check_result(r, X, Y, B, s, λ, opts)
      @test maximum(abs, B - reference) <= accuracy(T)
      @test iszero(oracle(X, Y, reference, s, λ).R)
      if size(Y, 2) == 1
        vector = fill(T(-0.25), p)
        v = solve!(vector, loss(Y[:, 1], X, s), NormL1(λ), method, opts)
        vref = oracle(X, Y, reshape(vector, p, 1), s, λ)
        @test maximum(abs, vec(B) - vector) <= accuracy(T)
        @test abs(fit.F - vref.F) <= accuracy(T)^2
        @test abs(r.minimum - v.minimum) <= 64eps(T) * max(1, fit.F)
        @test abs(fit.R - vref.R) <= accuracy(T) * max(1, fit.S)
      end
    end
  end
end

@testset "separate-response coordinate descent reference" begin
  for T in PRECISIONS
    rng = Xoshiro(469)
    n, p, K = 32, 5, 3
    X = T(0.55) .* randn(rng, T, n, 1) .+ randn(rng, T, n, p)
    C = T[1 0 -1; 0 -1 0; 0.25 0 0.5; 0 0.5 0; -1 0 0]
    Y = X*C + T(0.06) .* randn(rng, T, n, K)
    s, λ = one(T)/T(n), T(0.17)
    cd = CDSolver(order = :cyclic, momentum = false, tol = T === Float32 ? 1e-7 : 1e-12,
                  maxpasses = 20_000)
    independent = zeros(T, p, K)
    values = BigFloat[]
    for k in 1:K
      x = zeros(T, p)
      r = solve!(x, loss(Y[:, k], X, s), NormL1(λ), cd)
      independent[:, k] .= x
      ref = oracle(X, Y[:, k:k], reshape(x, p, 1), s, λ)
      @test ref.R <= accuracy(T) * max(1, ref.S)
      @test abs(r.minimum - ref.F) <= 64eps(T) * max(1, ref.F)
      push!(values, ref.F)
    end
    @test any(iszero, independent) && any(!iszero, independent)
    cd_ref = oracle(X, Y, independent, s, λ)
    for method in METHODS
      B = zeros(T, p, K)
      opts = options(T)
      fit = check_result(solve!(B, loss(Y, X, s), NormL1(λ), method, opts), X, Y, B, s, λ, opts)
      @test maximum(abs, B - independent) <= accuracy(T)
      for k in 1:K
        @test norm(X * (B[:, k] - independent[:, k]), Inf) <= 8accuracy(T)
        @test maximum(abs, fit.score[:, k] - cd_ref.score[:, k]) <= accuracy(T)
      end
      @test abs(fit.F - sum(values)) <= accuracy(T)^2 * max(1, fit.F)
      @info "Independent matrix lasso accuracy" T method=typeof(method) objective_error=Float64(abs(fit.F-sum(values))) kkt=Float64(fit.R)
    end
  end
end

snapshot(B) = copy(reinterpret(UInt8, vec(Matrix(B))))
function refused(E, message, B, f, g, method)
  original = snapshot(B)
  err = try
    solve!(B, f, g, method)
    nothing
  catch ex
    ex
  end
  @test err isa E && occursin(message, sprint(showerror, err))
  @test snapshot(B) == original
end

@testset "matrix preflight refuses without writes" begin
  for T in PRECISIONS, method in METHODS
    U = T === Float32 ? Float64 : Float32
    X, Y = orthogonal_data(T)
    B = T[1 -0.0 2; 0.5 -2 -1; 0 0.75 1]
    f, g = LeastSquaresLoss(Y, X), NormL1(T(0.5))
    refused(DimensionMismatch, "expected", B[:, 1:2], f, g, method)
    wrong_rows = LeastSquaresLoss(Y[1:3, :], X, f.tmp, f.V, f.s2, f.sUtY, f.w, f.output, f.svd_ready)
    refused(DimensionMismatch, "rows", B, wrong_rows, g, method)
    for (A, C) in ((zeros(T, 0, 3), zeros(T, 0, 3)),
                   (zeros(T, 4, 0), Y), (X, zeros(T, 4, 0)))
      refused(DimensionMismatch, "positive", copy(B), LeastSquaresLoss(C, A), g, method)
    end
    for (A, C) in ((X, U.(Y)), (U.(X), Y), (sparse(X), Y),
                   (X, sparse(Y)), (view(X, :, :), Y), (X, view(Y, :, :)))
      refused(ArgumentError, "dense Matrix", copy(B), LeastSquaresLoss(C, A), g, method)
    end
    for owner in (U.(B), Float16.(B))
      refused(ArgumentError, "same Float32 or Float64", owner, f, g, method)
    end
    for owner in (view(B, :, :), sparse(B))
      refused(ArgumentError, "dense Vector", owner, f, g, method)
    end
    for penalty in (NormL1(T(0.5), ones(T, 9)), NormL1(T(0.5), ones(T, 3, 3)),
                    GroupNormL2(T(0.5), [1:3, 4:6, 7:9]), ElasticNet(T(0.5), T(0.5)),
                    NormLinf(T(0.5)), IndNonnegative())
      refused(ArgumentError, "unweighted NormL1", B, f, penalty, method)
    end
    for λ in (T(Inf), big"1e-500", big"1e500")
      refused(ArgumentError, "penalty lambda", B, f, NormL1(λ), method)
    end
    @test_throws ArgumentError NormL1(T(-1))
    @test_throws ArgumentError NormL1(T(NaN))
    for s in (T(Inf), 1//3, Float16(0.5))
      refused(ArgumentError, "loss scale", B, Scaled(f, s), g, method)
    end
    refused(ArgumentError, "loss scale", B[:, 1:2], Scaled(f, 1//3), g, method)
    inner = T(0.25)*f
    for unsupported in (Scaled{typeof(inner), T}(inner, T(2)), zero(T)*f,
                        LeastSquaresLoss(Y[:, 1], X))
      refused(ArgumentError, "matrix response", B, unsupported, g, method)
    end
    refused(ArgumentError, "LogisticLoss", B, LogisticLoss(T[0, 1, 0, 1], X), g, method)
    @test_throws ArgumentError Scaled(f, T(-1))
    @test_throws ArgumentError Scaled(f, T(NaN))
    for v in (T(NaN), T(Inf))
      badX, badY, badB = copy(X), copy(Y), copy(B)
      badX[1] = badY[1] = badB[1] = v
      refused(ArgumentError, "finite", B, LeastSquaresLoss(Y, badX), g, method)
      refused(ArgumentError, "finite", B, LeastSquaresLoss(badY, X), g, method)
      refused(ArgumentError, "finite", badB, f, g, method)
    end
    A, C = copy(X[1:3, :]), copy(Y[1:3, :])
    alias_loss = LeastSquaresLoss(C, A)
    alias_loss.tmp .= T(0.25)
    for owner in (A, C, alias_loss.tmp)
      refused(ArgumentError, "must not alias", owner, T(0.5) * alias_loss, g, method)
    end
  end
end

@testset "APG preflight counts full matrix norm reductions" begin
  T = Float32
  X, Y = ones(T, 2, 1), zeros(T, 2, 1_048_574)
  m, g = AccProxGradDescent(), NormL1(0f0)
  f = LeastSquaresLoss(Y, X)
  B = fill(-0f0, 1, size(Y, 2))
  refused(ArgumentError, "max(nK, pK)", B, f, g, m)
  @test PS._check_bound_size(LeastSquaresLoss(Y[:, 1:end-1], X), B[:, 1:end-1]) === nothing
  # The coefficient-side limit is analogous, even when there are few observations.
  X, Y = ones(T, 1, 2), zeros(T, 1, 1_048_574)
  refused(ArgumentError, "max(nK, pK)", zeros(T, 2, size(Y, 2)), LeastSquaresLoss(Y, X), g, m)
  limit = Int(1/(4eps(Float64)))
  @test PS._bound_size_ok(Float64, limit - 5, 1, limit - 4)
  @test !PS._bound_size_ok(Float64, 1, limit - 4, 1)
  @test !PS._bound_size_ok(Float64, 1, 1, limit - 3)
  @test !PS._bound_size_ok(Float64, typemax(Int), 1, 1)
end

@testset "initial curvature depends on the design and scale" begin
  for T in PRECISIONS, method in METHODS
    X = T[0.125 0; 0 0.25; 0 0]
    s, g = T(0.5), NormL1(T(0.1))
    curvature = s * sum(abs2, X)
    v = PS.initial_state(method, options(T), loss(zeros(T, 3), X, s), g, zeros(T, 2))
    @test v.L ≈ curvature rtol = 16eps(T)
    for K in (1, 3)
      st = PS.initial_state(method, options(T), loss(zeros(T, 3, K), X, s), g, zeros(T, 2, K))
      @test st.L === v.L
      @test size(st.xhat) == (2, K) && size(st.delta_x) == (2, K)
      @test size(st.z_x) == (3, K) && size(st.dz) == (3, K)
    end
  end
end

@testset "matrix iterates, trace snapshots, callbacks and limits" begin
  for T in PRECISIONS, method in METHODS
    X = T[3 0; 0 1; 0 0]
    Y = T[2 -1 3; -1 2 0; 2 3 1]
    f, g = LeastSquaresLoss(Y, X), NormL1(T(0.25))
    start = fill(T(0.125), 2, 3)
    @test_throws ArgumentError ProximalOptions(maxiter = 0)
    @test_throws ArgumentError ProximalOptions(maxiter = 1)
    for opts in (ProximalOptions(maxiter = 2), ProximalOptions(prox_calls_limit = 1),
                 ProximalOptions(f_calls_limit = 1), ProximalOptions(grad_calls_limit = 1),
                 ProximalOptions(time_limit = -1.0))
      B = copy(start)
      r = solve!(B, f, g, method, opts)
      check_result(r, X, Y, B, one(T), g.λ0, opts; stationary = false)
      @test r.iterations == (opts.maxiter == 2 ? 2 : 1)
      @test r.iteration_converged == (opts.maxiter == 2)
      @test r.call_limit_reached == (opts.time_limit == Inf && opts.maxiter != 2)
      @test r.f_calls >= 1 && r.grad_calls >= 1 && r.prox_calls >= 1
    end
    observed = Int[]
    opts = ProximalOptions(store_trace = true, extended_trace = true, print_every = 2,
                           callback = t -> (push!(observed, last(t).iteration); length(observed) == 1))
    B = copy(start)
    r = solve!(B, f, g, method, opts)
    check_result(r, X, Y, B, one(T), g.λ0, opts; stationary = false)
    @test observed == [2] && r.iterations == length(r.trace) == 2
    gradient_key = method isa ProximalGradientDescent ? "grad_f(x)" : "grad_f(y)"
    @test all(t -> t.metadata["x"] !== B && t.metadata["x"] isa Matrix{T} &&
                   size(t.metadata[gradient_key]) == size(B) &&
                   t.metadata[gradient_key] isa Matrix{T}, r.trace)
    @test last(r.trace).metadata["x"] == B
    @test last(r.trace).fg_x == r.minimum
    @test norm(B - start) > 0
    saved = copy(B)
    B .= T(99)
    @test last(r.trace).metadata["x"] == saved
  end
end

# Inject an error only after the callback has recorded an accepted coefficient matrix.
mutable struct ThrowingProx{G}
  penalty::G
  armed::Bool
  fired::Bool
end
(g::ThrowingProx)(x) = g.penalty(x)
function PB.value_and_prox!(y::Matrix, g::ThrowingProx, x::Matrix, step::Real)
  if g.armed
    fill!(y, NaN)
    g.fired = true
    error("forced matrix trial error")
  end
  PB.value_and_prox!(y, g.penalty, x, step)
end

@testset "restore the last full accepted matrix on a failed trial" begin
  for T in PRECISIONS, method in METHODS
    X = T[3 0; 0 1; 0 0]
    Y = T[2 -1 3; -1 2 0; 2 3 1]
    f, g = LeastSquaresLoss(Y, X), ThrowingProx(NormL1(T(0.25)), false, false)
    accepted = Matrix{T}[]
    opts = ProximalOptions(ftol = 0, xtol = 1e-14, gradtol = 0, extended_trace = true,
                          callback = t -> (push!(accepted, t.metadata["x"]); g.armed = true; false))
    B = zeros(T, 2, 3)
    st = PS.initial_state(method, opts, f, g, B)
    @test_throws ErrorException("forced matrix trial error") PS._solve_gradient!(st, f, g, method, opts)
    @test g.fired && length(accepted) == 1
    @test !iszero(B) && snapshot(B) == snapshot(only(accepted))
  end
end

@testset "matrix curvature rejections and momentum restart" begin
  for T in PRECISIONS
    X = T[3 0; 0 2; 0 0]
    Y = T[2 1 -3; -1 4 0; 1 2 -1]
    f, g = LeastSquaresLoss(Y, X), NormL1(T(0.25))
    method = ProximalGradientDescent()
    for simple in (true, false)
      st = PS.initial_state(method, options(T), f, g, zeros(T, 2, 3))
      st.backtrack_simple = simple
      st.L = T(0.25)
      PS.update_state!(f, g, st, method)
      @test st.verifications >= 1 && st.backtrack_steps >= 2
      displacement = BigFloat.(st.x) - BigFloat.(st.x_previous)
      curvature = (simple ? 1 : 2) * sum(abs2, BigFloat.(X) * displacement) /
                  sum(abs2, displacement)
      @test st.L >= (1 - 16eps(T)) * curvature
      @test st.f_x + st.g_x < st.f_x_previous + st.g_x_previous
      @test st.z_x ≈ X*st.x
    end

    # Force a large finite first-accepted point history and a nonfinite extrapolated loss.
    X = Matrix{T}(I, 2, 2)
    f, g = LeastSquaresLoss(zeros(T, 2, 3), X), NormL1(zero(T))
    method = AccProxGradDescent()
    st = PS.initial_state(method, options(T), f, g, zeros(T, 2, 3))
    b = T(0.8) * sqrt(floatmax(T))
    st.x[1, 2] = b
    st.x_previous[1, 2] = -b
    st.z_x .= st.x
    st.z_previous .= st.x_previous
    st.f_x = b^2/2
    st.normx = PS._se_norm(T, st.x)
    st.normx_previous = PS._se_norm(T, st.x_previous)
    st.k = 1000
    grad_calls = st.grad_calls
    PS.update_state!(f, g, st, method)
    @test st.restarts == 1 && st.k == 1 && st.grad_calls == grad_calls + 2
    @test st.y == st.x_previous && st.z_y == st.z_previous
    @test isfinite(st.f_x) && st.f_x < st.f_x_previous
  end
end

@testset "Float32 checked curvature allowance spans all output columns" begin
  T = Float32
  X = fill(T(0.25)*floatmin(T), 2, 1)
  method = ProximalGradientDescent()
  g = NormL1(0f0)
  for K in (1, 3)
    f = LeastSquaresLoss(zeros(T, 2, K), X)
    st = PS.initial_state(method, options(T), f, g, zeros(T, 1, K))
    st.delta_x .= T(1e-20)
    st.dz .= X * st.delta_x
    @test iszero(st.dz)
    st.L = T(1e-39)
    fm = Float64(floatmin(T))
    d = Float64.(st.delta_x)
    w = 2sqrt(2K)*fm + sqrt(2)*fm*sum(abs, d)
    accepted, estimate = PS._step_curvature(st, 1)
    @test estimate ≈ T(w^2/sum(abs2, d)) rtol = 2eps(T)
    @test !accepted
    if K == 1
      vector = PS.initial_state(method, options(T), LeastSquaresLoss(zeros(T, 2), X), g, zeros(T, 1))
      vector.delta_x .= st.delta_x[:, 1]
      vector.dz .= 0
      vector.L = st.L
      @test (accepted, estimate) === PS._step_curvature(vector, 1)
    end
  end
end

se_value(x) = ldexp(BigFloat(x.s), x.e)

function trial_certificate(X, Y, x, xa, xb, ω, L, s; fresh_only = false)
  T = eltype(X)
  y = xa .+ ω .* (xa .- xb)
  za, zb, zx = X*xa, X*xb, X*x
  zy = za .+ ω .* (za .- zb)
  d = x - y
  constants = PS._bound_constants(T, X, PS._frobenius_upper(T, X), size(x, 2))
  Ey = PS._image_error_bound(constants, PS._se_norm(T, xa), PS._se_norm(T, xb), ω > 0)
  D, Nx = PS._se_norm(T, d), PS._se_norm(T, x)
  model = PS._image_model(loss(Y, X, s))
  decision = PS._bound_certified!(similar(Y), model, zy, zx, d, D, L, Ey, Nx,
                                  PS._root_scale(T, s), constants, fresh_only)
  exact = setprecision(BigFloat, 4096) do
    A, R = BigFloat.(X), BigFloat.(Y)
    ybig, xbig = BigFloat.(y), BigFloat.(x)
    d = xbig - ybig
    Ry = A*ybig - R
    Ftrial = BigFloat(s) * sum(abs2, A*xbig - R)/2
    model = BigFloat(s) * (sum(abs2, Ry)/2 + dot(A' * Ry, d))
    Ftrial <= model + (1 + 4BigFloat(eps(T)))^2 * BigFloat(L) * sum(abs2, d)/2
  end
  decision, exact
end

@testset "APG full Frobenius certificate and dimensional error terms" begin
  for T in PRECISIONS
    η = nextfloat(zero(T))
    X = T[1 0; 0 2; 0 0]
    normX = PS._frobenius_upper(T, X)
    n, p, K = 3, 2, 3
    c = PS._bound_constants(T, X, normX, K)
    one_column = PS._bound_constants(T, X, normX)
    @test one_column === PS._bound_constants(T, X, normX, 1)
    u = eps(T)/2
    γ(k) = (k*u)/(1-k*u)
    expected_norms = (inv((1-γ(n*K+4))*(1-u)), inv(1-γ(p*K+4)))
    @test se_value(c.upper_image) == first(expected_norms)
    @test se_value(c.upper_x) == last(expected_norms)
    @test se_value(c.product) ≈ BigFloat(γ(p)) * se_value(normX) rtol = 4eps(T)
    @test se_value(c.under_product) ≈ 2p * sqrt(big(n*K)) * big(η) rtol = 4eps(T)
    E = (8p * sqrt(big(n*K)) + 2sqrt(big(p*K)) * se_value(normX)) * big(η)
    @test se_value(c.under_extrapolation) ≈ E rtol = 4eps(T)

    Y = T[1 2 0; 0 -1 -1; 2 0 0]
    xa, xb = zeros(T, 2, K), T[0.125 0 0.25; -0.25 0 0.5]
    x = T[1 -0.25 1e-10; 0.5 0.25 -1]
    for ω in (zero(T), T(0.5)), fresh in (false, true)
      (accepted, used_fresh), exact = trial_certificate(X, Y, x, xa, xb, ω, T(25), T(0.5); fresh_only = fresh)
      @test exact && accepted && used_fresh == fresh
      (accepted, used_fresh), exact = trial_certificate(X, Y, x, xa, xb, ω, T(0.1), T(0.5); fresh_only = fresh)
      @test !exact && !accepted && used_fresh == fresh
    end
    # Images almost agree at a large common offset. The cached error bounds
    # leave the decision ambiguous, but the fresh product certifies the step.
    xa = fill(T(2)^20, 2, K)
    x = nextfloat.(xa)
    @test trial_certificate(X, Y, x, xa, xa, zero(T), T(16), one(T)) == ((true, true), true)
    xv, av = x[:, 1], xa[:, 1]
    @test trial_certificate(X, Y[:, 1], xv, av, av, zero(T), T(16), one(T)) ==
          trial_certificate(X, Y[:, 1:1], x[:, 1:1], xa[:, 1:1], xa[:, 1:1], zero(T), T(16), one(T))

    Xsmall = fill(T(0.5), 2, 1)
    x = T[η 3η -3η]
    base = zeros(T, 1, K)
    for L in (T(0.1), T(1024))
      for fresh in (false, true)
        (ok, _), exact = trial_certificate(Xsmall, zeros(T, 2, K), x, base, base,
                                            zero(T), L, one(T); fresh_only = fresh)
        @test ok == exact == (L > 1)
      end
    end
  end
end

@testset "Matrix progress measures all accepted entries ($T, $method)" for
    T in PRECISIONS, method in METHODS
  X = Matrix{T}(I, 2, 2)
  Y = T[3 0; 0 4]
  f, g = LeastSquaresLoss(Y, X), NormL1(zero(T))
  visits = Int[]
  watch(c) = (push!(visits, c.iteration); c.iteration == 1)
  B = zeros(T, 2, 2)
  opts = ProximalOptions(store_trace=true, extended_trace=true)
  r = solve!(B, f, g, method, opts;
             stopping=AnyOf(IterateChange(rtol=0.5), UserStop(watch)),
             limits=MaxIterations(3))
  t = termination(r)
  move = t.observations[1]
  expected = Float64(sqrt(sum(abs2, BigFloat.(B))))
  @test r.minimizer === B && r.minimum == r.trace[end].fg_x
  @test r.trace[1].metadata["x"] == B && r.trace[1].metadata["x"] !== B
  @test r.iterations == 1 && visits == [0, 1] && t.reason === :user && t.satisfied
  @test !r.converged && move.status === :fail && t.winning_branch == ((2,),)
  @test move.value ≈ expected rtol=4eps(Float64)
  @test move.scale ≈ expected rtol=4eps(Float64)
  @test move.threshold ≈ expected / 2 rtol=4eps(Float64)
  @test move.value > opnorm(Float64.(B))

  B = T[-0.0 0.0; 0.0 -0.0]
  lasso = NormL1(T(5))
  rule = AllOf(IterateChange(), ObjectiveChange())
  r = solve!(B, f, lasso, method; stopping=rule, limits=MaxIterations(3))
  t = termination(r)
  @test iszero(B) && r.iterations == 1
  @test t.reason === :rule && t.satisfied && !r.converged
  @test map(o -> o.value, t.observations) == (true, true)

  r = solve!(zeros(T, 2, 2), f, g, method;
             stopping=AnyOf(IterateChange(atol=1e3), ObjectiveChange(atol=1e3)),
             limits=MaxIterations(1))
  t = termination(r)
  @test t.limit_reached && t.reason === :rule && t.winning_branch == ((2,),)
  @test map(o -> o.status, t.observations) == (:not_checked, :pass)
end

@testset "Matrix preflight and no-work caps ($T, $method)" for T in PRECISIONS, method in METHODS
  X, Y = T[1 0; 0 1], T[2 -1; 0 3]
  f, g = LeastSquaresLoss(Y, X), NormL1(T(0.25))
  B = fill(floatmax(T) / 2, 2, 2)
  start = copy(B)
  user = UserStop(_ -> error("a zero cap skips predicates"))
  for limit in (MaxIterations(0), MaxObjectiveEvaluations(0),
                MaxGradientEvaluations(0), MaxProximalEvaluations(0))
    r = solve!(B, f, g, method; stopping=user, limits=limit)
    t = termination(r)
    @test B == start && r.minimizer === B && r.minimum === missing
    @test t.iteration == 0 && t.limit_reached && t.reason === :limit
    @test all(iszero, values(t.counts)) && only(t.observations).status === :not_checked
  end
  cap = MaxIterations(0)
  for rule in (PrimalResidual(), MaxIterations(5))
    @test_throws ArgumentError solve!(B, f, g, method;
        stopping=AnyOf(user, AllOf(ObjectiveChange(), rule)), limits=cap)
  end
  @test_throws ArgumentError solve!(B, f, NormL1(T(0.25), ones(T, 2)), method; limits=cap)
  @test_throws ArgumentError solve!(view(B, :, :), f, g, method; limits=cap)
  @test_throws DimensionMismatch solve!(zeros(T, 2, 1), f, g, method; limits=cap)
  @test_throws ArgumentError solve!(B, f, g, method, ProximalOptions(gradtol=0.01); limits=cap)
  @test B == start
end

@testset "Matrix PGD counts whole-matrix trials and rolls back ($T)" for T in PRECISIONS
  f = LeastSquaresLoss(ones(T, 1, 2), fill(T(2), 1, 1))
  g = NormL1(zero(T))
  method = ProximalGradientDescent(ls=PS.LineSearches.BackTracking(α=1.0, β=0.125))
  for (limit, f_calls, trials) in ((MaxObjectiveEvaluations(2), 2, 1),
                                  (MaxObjectiveEvaluations(3), 3, 2),
                                  (MaxProximalEvaluations(1), 2, 1))
    B = zeros(T, 1, 2)
    r = solve!(B, f, g, method; stopping=ObjectiveChange(atol=2), limits=limit)
    t = termination(r)
    @test r.minimizer === B && iszero(B) && r.minimum === one(T)
    @test t.iteration == 0 && t.reason === :limit && t.reached_evaluation_limits === (limit,)
    @test only(t.observations).status === :not_checked
    @test t.counts == (; f_calls, grad_calls=1, g_calls=1+trials, prox_calls=trials,
                       backtrack_steps=trials, rejected_trials=trials)
  end
  limits = (MaxObjectiveEvaluations(4), MaxGradientEvaluations(2), MaxProximalEvaluations(2))
  r = solve!(zeros(T, 1, 2), f, g, method; stopping=ObjectiveChange(atol=1), limits)
  t = termination(r)
  @test r.minimizer == fill(T(0.25), 1, 2) && r.minimum === T(0.25)
  @test t.reason === :rule && t.satisfied && t.reached_evaluation_limits === limits
  @test t.counts == (f_calls=4, grad_calls=2, g_calls=3, prox_calls=2,
                     backtrack_steps=2, rejected_trials=1)

  cap = MaxObjectiveEvaluations(5)
  r = solve!(zeros(T, 1, 2), f, g, method; limits=cap)
  t = termination(r)
  @test t.iteration == 1 && t.reason === :limit && t.reached_evaluation_limits === (cap,)
  @test r.minimizer == fill(T(0.25), 1, 2) && r.minimum === T(0.25)
  @test t.counts == (f_calls=5, grad_calls=2, g_calls=4, prox_calls=3,
                     backtrack_steps=3, rejected_trials=2)
end

@testset "Matrix APG counts one gradient across a search ($T)" for T in PRECISIONS
  f = T(0.25) * LeastSquaresLoss(fill(T(2), 1, 2), fill(T(2), 1, 1))
  g, method = NormL1(zero(T)), AccProxGradDescent(α=0.75, β=0.375)
  grad = MaxGradientEvaluations(1)
  baseline = solve!(zeros(T, 1, 2), f, g, method; limits=MaxIterations(1))
  r = solve!(zeros(T, 1, 2), f, g, method; limits=grad)
  t = termination(r)
  @test r.minimizer == baseline.minimizer && r.minimum === baseline.minimum
  @test t.iteration == 1 && t.reason === :limit && t.reached_evaluation_limits === (grad,)
  @test t.counts == (f_calls=4, grad_calls=1, g_calls=3, prox_calls=2,
                     backtrack_steps=2, rejected_trials=1)
  value_cap = MaxObjectiveEvaluations(3)
  r = solve!(zeros(T, 1, 2), f, g, method; limits=value_cap)
  t = termination(r)
  @test iszero(r.minimizer) && r.minimum === one(T) && t.iteration == 0
  @test t.reached_evaluation_limits === (value_cap,) && t.counts.rejected_trials == 1
end

@testset "Matrix APG restores the accepted point when a restart cannot run ($T)" for T in PRECISIONS
  f = LeastSquaresLoss(T[1 1; 0 0], T[0.5 0; 0 2])
  g, method = NormL1(zero(T)), AccProxGradDescent(α=1.0, β=0.5)
  options = ProximalOptions(store_trace=true, extended_trace=true)
  baseline = solve!(zeros(T, 2, 2), f, g, method, options; limits=MaxIterations(6))
  cap = MaxGradientEvaluations(7)
  visits = Int[]
  user = UserStop(c -> (push!(visits, c.iteration); false))
  r = solve!(zeros(T, 2, 2), f, g, method, options; stopping=user, limits=cap)
  t = termination(r)
  @test isequal(r.minimizer, baseline.minimizer) && r.minimum === baseline.minimum
  @test t.iteration == 6 && t.reason === :limit && t.reached_evaluation_limits === (cap,)
  @test visits == collect(0:6) && only(t.observations).status === :fail
  @test length(r.trace) == 6 && r.trace[end].metadata["x"] == r.minimizer
  @test t.counts == (f_calls=15, grad_calls=7, g_calls=8, prox_calls=7,
                     backtrack_steps=7, rejected_trials=1)
end

@testset "Matrix KKT reuses the entrywise scale and strict comparison ($T, $method)" for
    T in PRECISIONS, method in METHODS
  X = Matrix{T}(I, 2, 2)
  Y = T[2 2; 0 1]
  tight = ScaledKKT(rtol=0.5)
  loose = ScaledKKT(rtol=0.75)
  apg = method isa AccProxGradDescent
  for s in (one(T), 0.5)
    f, g = loss(Y, X, s), NormL1(Float64(s))
    B = zeros(T, 2, 2)
    independent = oracle(X, Y, B, s, T(g.λ0))
    @test independent.S == 2s && independent.R == s
    r = solve!(B, f, g, method; stopping=AnyOf(tight, loose))
    t = termination(r)
    @test r.minimizer === B && iszero(B) && r.iterations == 0
    @test r.converged && t.reason === :rule && t.winning_branch == ((2,),)
    @test map(o -> o.status, t.observations) == (:fail, :pass)
    @test t.counts == (f_calls=apg ? 2 : 1, grad_calls=2, g_calls=1, prox_calls=0,
                       backtrack_steps=0, rejected_trials=0)

    B = T[1 1; 0 0]
    @test iszero(oracle(X, Y, B, s, T(g.λ0)).R)
    r = solve!(B, f, g, method; stopping=ScaledKKT(rtol=0))
    @test r.minimizer === B && r.converged && r.iterations == 0

    r = solve!(copy(B), f, g, method; stopping=AnyOf(UserStop(_ -> true), tight))
    t = termination(r)
    @test t.reason === :user && t.observations[2].status === :not_checked
    @test t.counts.f_calls == 1 && t.counts.grad_calls == (apg ? 0 : 1)
  end

  f = LeastSquaresLoss(zeros(T, 2, 2), X)
  rule = AnyOf(loose, UserStop(_ -> true))
  for level in (zero(T), floatmin(T))
    r = solve!(zeros(T, 2, 2), f, NormL1(level), method; stopping=rule)
    t = termination(r)
    @test t.reason === :user && !r.converged && t.observations[1].status === :fail
  end
end

@testset "Matrix KKT shares the last admitted observation ($T, $method)" for
    T in PRECISIONS, method in METHODS
  f = LeastSquaresLoss(T[2 2; 0 1], Matrix{T}(I, 2, 2))
  g, tight, loose = NormL1(one(T)), ScaledKKT(rtol=0.5), ScaledKKT(rtol=0.75)
  cap = MaxGradientEvaluations(2)
  for (rule, reason, statuses) in ((AllOf(loose, loose), :rule, (:pass, :pass)),
                                   (AnyOf(tight, loose), :limit, (:fail, :not_checked)))
    r = solve!(zeros(T, 2, 2), f, g, method; stopping=rule, limits=cap)
    t = termination(r)
    @test t.iteration == 0 && t.reason === reason && t.limit_reached
    @test r.converged == t.satisfied == (reason === :rule)
    @test t.reached_evaluation_limits === (cap,) && t.counts.grad_calls == 2
    @test map(o -> o.status, t.observations) == statuses
    @test t.counts.f_calls == (method isa AccProxGradDescent ? 2 : 1)
  end

  # Initialization uses the last value. The fresh reference product is skipped.
  r = solve!(zeros(T, 2, 2), f, g, method; stopping=loose, limits=MaxObjectiveEvaluations(1))
  t = termination(r)
  @test t.reason === :limit && only(t.observations).status === :not_checked
  @test t.counts.grad_calls == (method isa AccProxGradDescent ? 0 : 1)
end

@testset "Matrix APG admits the reference and checkpoint gradient together ($T)" for T in PRECISIONS
  X, Y = fill(T(0.5), 1, 1), T[1 -1]
  f, g = LeastSquaresLoss(Y, X), NormL1(zero(T))
  method, kkt = AccProxGradDescent(α=1.0, β=0.5), ScaledKKT(rtol=0.75)
  r = solve!(zeros(T, 1, 2), f, g, method;
             stopping=AnyOf(kkt, UserStop(_ -> true)), limits=MaxGradientEvaluations(1))
  t = termination(r)
  @test t.reason === :user && !t.limit_reached && t.iteration == 0
  @test t.observations[1].status === :not_checked
  @test t.counts.f_calls == 1 && t.counts.grad_calls == t.counts.prox_calls == 0

  r = solve!(zeros(T, 1, 2), f, g, method; stopping=kkt, limits=MaxGradientEvaluations(1))
  t = termination(r)
  @test t.reason === :limit && t.limit_reached && t.iteration == 1
  @test t.counts.grad_calls == 1 && only(t.observations).status === :not_checked

  opts = ProximalOptions(store_trace=true, extended_trace=true)
  for budget in (MaxGradientEvaluations(4), MaxObjectiveEvaluations(6), MaxIterations(2))
    r = solve!(zeros(T, 1, 2), f, g, method, opts; stopping=kkt, limits=budget)
    t = termination(r)
    @test r.converged && t.reason === :rule && t.iteration == 1
    @test t.limit_reached == !(budget isa MaxIterations)
    @test t.counts == (f_calls=6, grad_calls=4, g_calls=3, prox_calls=2,
                       backtrack_steps=2, rejected_trials=1)
    score = oracle(X, Y, r.minimizer, one(T), zero(T))
    @test score.R < 0.75 * score.S
    @test PB.kkt_violation(g, r.trace[1].metadata["grad_f(y)"], r.minimizer) >= 0.75 * score.S
  end

  r = solve!(zeros(T, 1, 2), f, g, method;
             stopping=Every(1, kkt), limits=MaxIterations(2))
  plain = solve!(zeros(T, 1, 2), f, g, method; stopping=kkt, limits=MaxIterations(2))
  @test isequal(termination(r), termination(plain)) && r.minimizer == plain.minimizer

  rule = AnyOf(Every(2, kkt), UserStop(c -> c.iteration == 1))
  r = solve!(zeros(T, 1, 2), f, g, method; stopping=rule, limits=MaxIterations(2))
  t = termination(r)
  @test t.reason === :user && t.iteration == 1 && !r.converged
  @test t.observations[1].status === :not_checked && t.counts.grad_calls == 3
  @test t.counts.f_calls == 5

  r = solve!(zeros(T, 1, 2), f, g, method;
             stopping=Every(1, kkt), limits=MaxIterations(1))
  t = termination(r)
  @test r.minimizer == plain.minimizer && t.reason === :limit && !r.converged
  @test only(t.observations).status === :not_checked && t.counts.grad_calls == 3
end

end
