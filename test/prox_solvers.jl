module ProxSolversTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

mutable struct StopAfter
  calls::Int
  limit::Int
end
(callback::StopAfter)(state) = (callback.calls += 1; callback.calls >= callback.limit)

@testset "callable callbacks" for solver in (ProximalGradientDescent(), AccProxGradDescent(),
                                            MonotoneAccProxGradDescent()), store_trace in (false, true)
  callback = StopAfter(0, 2)
  options = ProximalOptions(; callback, store_trace, print_every = 2,
                             ftol = 1e-300, xtol = 1e-300, gradtol = 1e-300)
  @test options.callback === callback
  f = QuadraticFunction(Matrix(Diagonal([1., 10., 100.])), [-1., -1., -1.])
  result = solve!(zeros(3), f, NormL1(0.1), solver, options)
  @test callback.calls == 2
  @test result.iterations == 4
  @test length(result.trace) == (store_trace ? 4 : 0)
end

opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 5000)

@testset "$(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())

  @testset "L2Loss + no penalty" begin
    x = randn(5)
    y = randn(5)

    solve!(x, SqrNormL2(), ZeroFunction(), solver, opt)
    @test norm(x) ≈ 0. atol = 1e-5

    solve!(x, SqrNormL2(1, y), ZeroFunction(), solver, opt)
    @test x ≈ y atol = 1e-5
  end

  @testset "L2Loss + l1 penalty" begin
    x = randn(5)
    y = randn(5) .+ 1.
    g = NormL1(0.1)

    solve!(x, SqrNormL2(1, y), g, solver, opt)
    @test x ≈ prox(g, y) atol = 1e-5
  end

  @testset "L2Loss + nuclear norm" begin
    x = randn(10, 10)
    y = randn(30, 10)
    y = y'y

    U, S, V = svd(y)
    S = max.(S .- 0.1, 0.)
    tx = U * Diagonal(S) * V'

    solve!(x, SqrNormL2(1, y), NuclearNorm(0.1), solver, opt)
    @test x ≈ tx atol = 1e-3
  end

  @testset "quadratic + no penalty" begin
    A = randn(20, 10)
    A = A'A / 20
    b = randn(10)
    f = QuadraticFunction(A, b, 1.)

    x = randn(10)
    solve!(x, f, ZeroFunction(), solver, opt)
    @test x ≈ -(A \ b) atol = 1e-4
  end

  @testset "ridge regression" begin
    n, p = 200, 30
    X = randn(n, p)
    Y = X * ones(p) + 0.1 * randn(n)
    f = QuadraticFunction(X'X / n, -X'Y / n)

    # SqrNormL2(2λ) is λ‖x‖², so the minimizer solves (X'X/n + 2λI) x = X'Y/n
    for λ in (0., 1.)
      hat_beta = zeros(p)
      solve!(hat_beta, f, SqrNormL2(2λ), solver, opt)
      @test hat_beta ≈ (X'X / n + 2λ * I) \ (X'Y / n) atol = 1e-4
    end
  end

  @testset "lasso" begin
    n, p = 100, 50
    X = randn(n, p)
    β = vcat(randn(5), zeros(p - 5))
    Y = X * β + 0.1 * randn(n)
    A, b = X'X / n, -X'Y / n
    λ = 0.1 * norm(b, Inf)

    x = zeros(p)
    res = solve!(x, QuadraticFunction(A, b), NormL1(λ), solver, opt)
    @test res.iterations < opt.maxiter

    # KKT conditions: ∇f(x) = -λ sign(x) on the support, |∇f(x)| ≤ λ off it
    grad = A * x + b
    S = abs.(x) .> 1e-8
    @test any(S)
    @test grad[S] ≈ -λ * sign.(x[S]) atol = 1e-4
    @test all(abs.(grad[.!S]) .<= λ + 1e-4)
  end

end

@testset "gradient residual stops $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(),
                                                                   MonotoneAccProxGradDescent())
  # with ftol and xtol out of reach, only the FASTA residual can stop the solver;
  # it must reach zero at a lasso solution where ∇f(x) ≠ 0
  n, p = 100, 50
  X = randn(n, p)
  Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
  A, b = X'X / n, -X'Y / n
  λ = 0.1 * norm(b, Inf)

  x = zeros(p)
  opt = ProximalOptions(; ftol = 1e-300, xtol = 1e-300, gradtol = 1e-6, maxiter = 5000)
  res = solve!(x, QuadraticFunction(A, b), NormL1(λ), solver, opt)
  @test res.grad_converged
  @test res.iterations < opt.maxiter
  @test res.g_residual < 1e-5

  # the solver stopped near a solution: KKT conditions hold
  grad = A * x + b
  S = abs.(x) .> 1e-8
  @test grad[S] ≈ -λ * sign.(x[S]) atol = 1e-4
  @test all(abs.(grad[.!S]) .<= λ + 1e-4)
end

@testset "SparseIterate $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
  # the iterates stay SparseIterates, without stored zeros at the end, and give
  # the dense solution; ‖Y - Xx‖² / (2n) is the quadratic up to a constant
  n, p = 100, 50
  X = randn(n, p)
  Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
  A, b = X'X / n, -X'Y / n
  g = NormL1(0.1 * norm(b, Inf))
  for f in (QuadraticFunction(A, b), LeastSquaresLoss(Y / sqrt(n), X / sqrt(n)))
    xd, x = zeros(p), SparseIterate(p)
    solve!(xd, f, g, solver, opt)
    res = solve!(x, f, g, solver, opt)
    @test res.minimizer === x
    @test ProximalSolvers.converged(res)
    @test 0 < nnz(x) == count(!iszero, Vector(x)) < p
    @test Vector(x) ≈ xd atol = 1e-5
    @test res.minimum ≈ f(xd) + g(xd)
  end
end

@testset "Float32 $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent(),
                                                    ActiveAccProxGradDescent())
  # the iterates, the minimum and the arithmetic stay in Float32; the solution
  # agrees with Float64 to Float32 accuracy. The tolerances must be above the
  # precision of Float32, eps(Float32) ≈ 1.2e-7
  n, p = 60, 25
  X, Y = randn(n, p), randn(n)
  A, b = X'X / n, -X'Y / n
  for (f32, f64) in ((QuadraticFunction(Float32.(A), Float32.(b)), QuadraticFunction(A, b)),
                     (LeastSquaresLoss(Float32.(Y), Float32.(X)), LeastSquaresLoss(Y, X)))
    x32, x64 = zeros(Float32, p), zeros(p)
    res = solve!(x32, f32, NormL1(0.05f0), solver, ProximalOptions(; maxiter = 5000, ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
    solve!(x64, f64, NormL1(0.05), solver, ProximalOptions(; maxiter = 5000, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10))
    @test eltype(x32) == Float32
    @test res.minimum isa Float32
    @test ProximalSolvers.converged(res)
    @test x32 ≈ x64 atol = 1e-2
  end
end

# SymmetricSparseIterate (owner) iterates of the gradient solvers. An off-diagonal coordinate
# (r, c) of an owner is the pair of entries (r, c), (c, r) of its matrix.
const PS = ProximalSolvers
owner_solvers() = (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
owner_state(x) = (Matrix(x), collect(activecoordinates(x)), collect(activevalues(x)))
soft(v, t) = sign(v) * max(abs(v) - t, 0.0)
# the largest entry residual of the L1 optimality conditions at X, from the dense gradient G:
# max(|G| - λ, 0) at a zero entry and |G + λ sign(X)| at a nonzero one, over all p² entries
# Near a solution the objective can rise by rounding; that stops a solve with converged = false
# and f_increased = true, after which the tests check the returned point itself
stopped(r) = r.converged || r.f_increased
l1_residual(G, X, λ) = maximum(iszero(X[i]) ? max(abs(G[i]) - λ, 0.0) : abs(G[i] + λ * sign(X[i])) for i in eachindex(X))

# T07, proximal-gradient half (ProximalBase acceptance plan): (1) the separable problem
# ½‖Θ - B‖² + λ Σᵢⱼ |Θᵢⱼ|, whose solution is soft(B, λ) entry by entry, the off-diagonal pairs
# included; (2) the coupled problem ½tr(ΘSΘS) + ⟨C, Θ⟩ + λ Σᵢⱼ |Θᵢⱼ| from zero, with the
# solution Xstar = [1 -1; -1 0], against a reference written here.
# The step 1/L with L = 1, the curvature of the loss, reaches the solution in one step; the
# default backtracking starts from a smaller L and converges linearly, and the stopping rules end
# it at an objective change of a few ulps, where the iterate is within about 1e-8 of the solution.
unit_step_solvers() = (ProximalGradientDescent(PS.LineSearches.BackTracking(; α = 1.0, Lexact = 1.0)),
                       AccProxGradDescent(; α = 1.0), MonotoneAccProxGradDescent(; α = 1.0))
@testset "owner T07 separable closed form $(summary(solver)), step $(step)" for (step, tol) in
    (("1", 1e-14), ("backtracked", 1e-7)), solver in (step == "1" ? unit_step_solvers() : owner_solvers())
  p, λ = 4, 0.3
  B = [2.0 0.5 -1.2 0.1; 0.5 -0.2 0.0 0.9; -1.2 0.0 1.0 -0.35; 0.1 0.9 -0.35 0.25]
  f = KronQuadratic(Matrix(1.0I, p, p), Matrix(1.0I, p, p), -B)
  x = SymmetricSparseIterate(p)
  r = solve!(x, f, NormL1(λ), solver, ProximalOptions(; maxiter = 2000, ftol = 1e-15, xtol = 1e-15, gradtol = 1e-14))
  @test r.minimizer === x
  @test stopped(r)
  Xs = soft.(B, λ)
  @test Matrix(x) ≈ Xs atol = tol
  @test nactive(x) == count(!iszero, Xs[i, j] for j in 1:p for i in j:p)
end

# An independent solver of the coupled problem: ISTA on the q = 3 coordinates in orthonormal
# coordinates u[k] = √m[k] θ[k] (m = 2 off the diagonal), where ‖u‖ is the Frobenius norm of
# the matrix; the penalty λ Σᵢⱼ |Θᵢⱼ| is λ Σₖ √m[k] |u[k]|, and ∂f/∂u[k] = √m[k] G[r, c].
function ista_reference(S, C, λ; iterations = 5000)
  pos, m = ((1, 1), (2, 1), (2, 2)), (1.0, 2.0, 1.0)
  Lf = opnorm(kron(S, S))
  u = zeros(3)
  matrix(u) = [u[1] u[2]/sqrt(2); u[2]/sqrt(2) u[3]]
  for _ in 1:iterations
    G = S * matrix(u) * S + C
    u = [soft(u[k] - sqrt(m[k]) * G[pos[k]...] / Lf, λ * sqrt(m[k]) / Lf) for k in 1:3]
  end
  matrix(u)
end

@testset "owner T07 coupled problem from zero $(summary(solver))" for solver in owner_solvers()
  S, C, λ = [2.0 1.0; 1.0 2.0], [-0.5 3.5; 3.5 3.0], 0.5
  Xstar = [1.0 -1.0; -1.0 0.0]
  f, g = KronQuadratic(S, S, C), NormL1(λ)
  objective(X) = tr(X * S * X * S) / 2 + dot(C, X) + λ * sum(abs, X)
  Xref = ista_reference(S, C, λ)
  @test Xref ≈ Xstar atol = 1e-12
  @test S * Xstar * S + C ≈ [-0.5 0.5; 0.5 0.0] atol = 1e-14
  x = SymmetricSparseIterate(2)
  r = solve!(x, f, g, solver, ProximalOptions(; maxiter = 5000, ftol = 1e-16, xtol = 1e-16, gradtol = 1e-14))
  X = Matrix(x)
  @test stopped(r)
  @test r.iterations > 1
  # the stopping rules end the solve at an objective change of a few ulps, where the iterate is
  # within about 1e-7 of the solution
  @test X ≈ Xref atol = 1e-6
  @test r.minimum ≈ objective(Xstar) rtol = 1e-9
  @test r.minimum ≈ objective(X) rtol = 1e-12
  # stationarity at all four entries, from the gradient of the matrix at the returned point
  @test l1_residual(S * X * S + C, X, λ) <= 1e-6
  @test iszero(x[2, 2]) && !isactive(x, tril_index(2, 2, 2))
end

# The reported step is the Frobenius norm of the change of the matrix: one off-diagonal
# coordinate that moves by 0.1 changes two entries and gives 0.1√2, which the norm of the
# coordinates (0.1) does not. One iteration with the step 1 from zero: x[2, 1] = soft(0.11, 0.01).
@testset "owner step norm is the Frobenius norm $(summary(solver))" for solver in unit_step_solvers()
  f = KronQuadratic(Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2), [0.0 -0.11; -0.11 0.0])
  x = SymmetricSparseIterate(2)
  x0 = copy(x)
  # the limit of one proximal call stops the solve after the first iteration
  r = solve!(x, f, NormL1(0.01), solver, ProximalOptions(; prox_calls_limit = 1, store_trace = true))
  Δ = Matrix(x) - Matrix(x0)
  @test r.iterations == 1
  @test Δ[1, 1] == Δ[2, 2] == 0
  @test Δ[2, 1] == Δ[1, 2]
  @test Δ[2, 1] ≈ 0.1 atol = 1e-15
  @test r.x_residual ≈ norm(Δ) rtol = 1e-14
  @test r.x_residual ≈ 0.1 * sqrt(2) rtol = 1e-13
  @test r.x_residual ≈ sqrt(2) * norm(coordinates(x) - coordinates(x0)) rtol = 1e-14
  @test r.trace[end].dxx ≈ norm(Δ) / norm(Matrix(x)) rtol = 1e-14
end

# KronQuadratic(A, B, C) with A ≠ B: over symmetric matrices the gradient is the symmetric part
# (AΘB + BΘA)/2 + C, which ProximalBase returns at an owner point and not at a dense one. The
# gradients the solvers evaluate (traced with extended_trace) are exactly symmetric, and the
# solution meets the optimality conditions of the symmetric gradient.
@testset "owner gradient at owner points, A ≠ B $(summary(solver))" for solver in owner_solvers()
  A = [2.0 0.5 0.0; 0.5 1.5 0.3; 0.0 0.3 1.0]
  B = [1.0 0.2 -0.4; 0.2 2.0 0.4; -0.4 0.4 1.5]
  C = [-1.0 0.8 0.3; 0.8 0.5 -1.1; 0.3 -1.1 -0.6]
  λ = 0.2
  f = KronQuadratic(A, B, C)
  symgrad(X) = (A * X * B + B * X * A) / 2 + C
  # the fixture is one where a dense point gives an asymmetric gradient
  Gd = similar(C)
  gradient!(Gd, f, [0.3 0.1 0.0; 0.1 -0.2 0.4; 0.0 0.4 0.5])
  @test Gd != Gd'
  x = SymmetricSparseIterate(3)
  options = ProximalOptions(; maxiter = 5000, ftol = 1e-16, xtol = 1e-16, gradtol = 1e-13,
                            store_trace = true, extended_trace = true)
  r = solve!(x, f, NormL1(λ), solver, options)
  @test stopped(r)
  key = solver isa ProximalGradientDescent ? "grad_f(x)" : "grad_f(y)"
  @test length(r.trace) == r.iterations
  for state in r.trace
    G = state.metadata[key]
    @test G isa Matrix{Float64} && G == G'
    @test state.metadata["x"] isa SymmetricSparseIterate{Float64}
  end
  if solver isa ProximalGradientDescent
    # ∇f at the traced iterate
    @test all(s -> s.metadata["grad_f(x)"] ≈ symgrad(Matrix(s.metadata["x"])), r.trace)
  end
  X = Matrix(x)
  @test l1_residual(symgrad(X), X, λ) <= 1e-6
  @test count(!iszero, X) > 0 && count(iszero, X) > 0
end

@testset "owner results and traces $(summary(solver))" for solver in owner_solvers()
  f = KronQuadratic(Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2), [-1.0 -0.5; -0.5 0.2])
  x = SymmetricSparseIterate(2)
  r = solve!(x, f, NormL1(0.1), solver, ProximalOptions(; store_trace = true, extended_trace = true))
  @test r isa PS.OptimizationResults{<:Any, Float64, 2}
  @test r.minimizer === x
  # the traced iterates are copies: the last one is the solution, the first one is not
  @test Matrix(r.trace[end].metadata["x"]) == Matrix(x)
  @test r.trace[1].metadata["x"] !== x
  shown = sprint(show, r)
  @test occursin(" * Minimizer: [$(x[1, 1]),$(x[2, 1]), ...]", shown)
  @test occursin(summary(solver), shown)
end

# gaptol on an owner: the LogDet gap with NormL1 is computed and stops the gradient solvers
@testset "owner gaptol with LogDetLoss $(summary(solver))" for solver in owner_solvers()
  S = [1.0 0.3 0.0 0.1; 0.3 1.2 0.2 0.0; 0.0 0.2 0.9 0.25; 0.1 0.0 0.25 1.1]
  f, g = LogDetLoss(S), NormL1(0.1)
  ref = SymmetricSparseIterate(Matrix(1.0I, 4, 4))
  solve!(ref, f, g, ProxNewton(; tol = 1e-12))
  x = SymmetricSparseIterate(Matrix(1.0I, 4, 4))
  r = solve!(x, f, g, solver, ProximalOptions(; gaptol = 1e-8, gapevery = 5, maxiter = 20_000,
                                              ftol = 1e-300, xtol = 1e-300, gradtol = 1e-300))
  @test !isnan(r.gap)
  @test r.converged && r.gap <= 1e-8
  @test r.iterations % 5 == 0 && r.iterations < 20_000
  @test Matrix(x) ≈ Matrix(ref) atol = 1e-5
end

# T18 (ProximalBase acceptance plan): the debias support of a real ProximalGradientDescent
# state with debias = 1, on the problem ½‖Θ - B‖² + 0.5 Σᵢⱼ |Θᵢⱼ| whose solution has the
# support {(1,1), (3,1)}. The support compares the coordinates whose value is not zero, not the
# active ones: an active zero is outside it.
@testset "owner debias support (T18)" begin
  p = 3
  B = [2.0 0.0 1.5; 0.0 0.0 0.0; 1.5 0.0 0.0]
  f, g = KronQuadratic(Matrix(1.0I, p, p), Matrix(1.0I, p, p), -B), NormL1(0.5)
  k11, k21, k31 = tril_index(p, 1, 1), tril_index(p, 2, 1), tril_index(p, 3, 1)
  method = ProximalGradientDescent(; debias = 1)
  nonzero(x) = Set(k for k in activecoordinates(x) if !iszero(coordinates(x)[k]))
  # the same nonzero coordinates, and an active zero in x_previous that x does not have
  x = SymmetricSparseIterate(p)
  x[1, 1], x[3, 1] = 1.5, 1.0
  activate!(x, k21)
  ws = SolverWorkspace(x, f, g, method)
  state = ws.buffers.state
  @test state.x isa SymmetricSparseIterate && state.x_previous isa SymmetricSparseIterate
  @test state.xhat isa Matrix{Float64} && state.delta_x isa Matrix{Float64}
  @test state.stable == 0
  PS.update_state!(f, g, state, method)
  # the trial point x' - ∇f(x')/L of the accepted step is exactly symmetric
  @test state.xhat == state.xhat'
  @test isactive(state.x_previous, k21) && iszero(state.x_previous[2, 1])
  @test !isactive(state.x, k21)
  @test nonzero(state.x) == nonzero(state.x_previous) == Set([k11, k31])
  @test state.stable == 1
  @test state.refitted            # tried once the support was stable; the refit is worse here
  @test Matrix(state.x) ≈ [1.5 0.0 1.0; 0.0 0.0 0.0; 1.0 0.0 0.0] atol = 1e-12
  # the same active coordinates, and a coordinate that becomes nonzero: the counter resets
  y = SymmetricSparseIterate(p)
  y[1, 1] = 1.5
  activate!(y, k31)
  ws = SolverWorkspace(y, f, g, method)
  state = ws.buffers.state
  state.stable, state.refitted = 4, true
  PS.update_state!(f, g, state, method)
  @test state.xhat == state.xhat'
  @test Set(activecoordinates(state.x)) == Set(activecoordinates(state.x_previous)) == Set([k11, k31])
  @test nonzero(state.x_previous) == Set([k11])
  @test nonzero(state.x) == Set([k11, k31])
  @test state.stable == 0
  @test !state.refitted
end

# ADMM, the active-set solver and the diagonal preconditioner take independently stored entries:
# on an owner they throw an ArgumentError that names them, before anything is written
@testset "owner refusals" begin
  f, g = KronQuadratic(Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2), [-1.0 -0.5; -0.5 0.2]), NormL1(0.1)
  calls = (
    ("Active-Set Accelerated Proximal Gradient Descent", x -> solve!(x, f, g, ActiveAccProxGradDescent())),
    ("ADMM", x -> solve!(x, f, g, ADMMSolver())),
    ("ADMM", x -> SolverWorkspace(x, f, g, ADMMSolver())),
    ("diagonal preconditioning", x -> solve!(x, f, g, ProximalGradientDescent(; preconditioner = :diagonal))),
    ("diagonal preconditioning", x -> solve!(x, f, g, AccProxGradDescent(; preconditioner = :diagonal))),
    ("diagonal preconditioning", x -> SolverWorkspace(x, f, g, AccProxGradDescent(; preconditioner = :diagonal))),
  )
  for (name, call) in calls
    x = SymmetricSparseIterate(2)
    x[2, 1], x[1, 1] = 0.25, 0.5
    activate!(x, tril_index(2, 2, 2))
    before = owner_state(x)
    err = try
      call(x)
      nothing
    catch e
      e
    end
    @test err isa ArgumentError
    msg = err === nothing ? "" : sprint(showerror, err)
    @test occursin(name, msg)
    @test occursin("SymmetricSparseIterate", msg)
    @test isequal(owner_state(x), before)
  end
end

# A smooth loss with a value and a gradient at an owner only, as a user type may have: the
# normalized step evaluates it at an owner that holds its dense trial point, alone and as an owner
# block of a tuple, with the values and iterations of the KronQuadratic it delegates to
struct OwnerQuadratic{F} <: AbstractFunction
  f::F
end
ProximalBase.issmooth(::Type{<:OwnerQuadratic}) = true
ProximalBase.isconvex(::Type{<:OwnerQuadratic}) = true
(f::OwnerQuadratic)(x::SymmetricSparseIterate) = f.f(x)
ProximalBase.value_and_gradient!(G::AbstractMatrix, f::OwnerQuadratic, x::SymmetricSparseIterate) = value_and_gradient!(G, f.f, x)
ProximalBase.gradient!(G::AbstractMatrix, f::OwnerQuadratic, x::SymmetricSparseIterate) = gradient!(G, f.f, x)

@testset "owner-only loss $(normalized ? "normalized " : "")Proximal Gradient Descent" for normalized in (false, true)
  kron = KronQuadratic(Matrix(1.0I, 2, 2), Matrix(1.0I, 2, 2), [-1.0 -0.5; -0.5 0.2])
  method, options = ProximalGradientDescent(; normalized), ProximalOptions(; maxiter = 300)
  x, xk = SymmetricSparseIterate(2), SymmetricSparseIterate(2)
  r = solve!(x, OwnerQuadratic(kron), NormL1(0.1), method, options)
  rk = solve!(xk, kron, NormL1(0.1), method, options)
  # the normalized step is exact for this quadratic; the plain step stops about 2e-9 short of it
  @test r.minimum ≈ -0.57 rtol = (normalized ? 1e-12 : 1e-8)
  @test (r.minimum, r.iterations, r.f_calls) == (rk.minimum, rk.iterations, rk.f_calls)
  @test Matrix(x) == Matrix(xk)
  # an owner block of a tuple, beside a dense block
  xt = (SymmetricSparseIterate(2), zeros(1))
  rt = solve!(xt, SeparableSum(OwnerQuadratic(kron), SqrNormL2()), SeparableSum(NormL1(0.1), NormL1(0.1)),
              method, options)
  @test Matrix(xt[1]) ≈ Matrix(xk) atol = 1e-8
  @test xt[2] == [0.0]
  @test rt.minimum ≈ -0.57 rtol = 1e-8
end

end
