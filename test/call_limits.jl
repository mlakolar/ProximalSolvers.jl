module CallLimitsTest

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

# wrappers that count their own calls, to check the counts the solvers report

mutable struct CountingFunction{F<:AbstractFunction} <: AbstractFunction
  f::F
  value_calls::Int
  value_and_gradient_calls::Int
  gradient_calls::Int
end

CountingFunction(f) = CountingFunction(f, 0, 0, 0)
ProximalBase.issmooth(::Type{<:CountingFunction}) = true

function (c::CountingFunction)(x)
  c.value_calls += 1
  c.f(x)
end

function ProximalBase.value_and_gradient!(hat_x, c::CountingFunction, x)
  c.value_and_gradient_calls += 1
  value_and_gradient!(hat_x, c.f, x)
end

function ProximalBase.gradient!(hat_x, c::CountingFunction, x)
  c.gradient_calls += 1
  gradient!(hat_x, c.f, x)
end

f_calls(c::CountingFunction) = c.value_calls + c.value_and_gradient_calls
grad_calls(c::CountingFunction) = c.value_and_gradient_calls + c.gradient_calls

mutable struct CountingProx{G<:AbstractFunction} <: AbstractFunction
  g::G
  value_calls::Int
  prox_calls::Int
end

CountingProx(g) = CountingProx(g, 0, 0)
ProximalBase.isproximable(::Type{<:CountingProx}) = true

function (c::CountingProx)(x)
  c.value_calls += 1
  c.g(x)
end

function ProximalBase.prox!(out_x, c::CountingProx, x, γ::Real)
  c.prox_calls += 1
  prox!(out_x, c.g, x, γ)
end

function ProximalBase.value_and_prox!(out_x, c::CountingProx, x, γ::Real)
  c.prox_calls += 1
  value_and_prox!(out_x, c.g, x, γ)
end

n, p = 100, 50
X = randn(n, p)
Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
A, b = X'X / n, -X'Y / n
λ = 0.1 * norm(b, Inf)
y = randn(p) .+ 1.

q = 10
Z = randn(50, q)
S = Symmetric(Z'Z / 50)

opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 5000)

@testset "exact counts $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent())

  @testset "$(nameof(typeof(f0)))" for f0 in (SqrNormL2(1, y), QuadraticFunction(A, b))
    f, g = CountingFunction(f0), CountingProx(NormL1(λ))
    res = solve!(zeros(p), f, g, solver, opt)
    @test ProximalSolvers.converged(res)
    @test !res.call_limit_reached
    @test res.f_calls == f_calls(f)
    @test res.grad_calls == grad_calls(f)
    @test res.prox_calls == g.prox_calls
    # the line search retried steps on the quadratic, whose Lipschitz constant exceeds 1
    f0 isa QuadraticFunction && @test res.prox_calls > res.iterations

    out = sprint(show, res)
    @test occursin("f(x) calls: $(res.f_calls)", out)
    @test occursin("∇f(x) calls: $(res.grad_calls)", out)
    @test occursin("prox calls: $(res.prox_calls)", out)
  end

end

@testset "exact counts in both line search modes" begin
  # the function value mode switches to the gradient mode, where backtrack!
  # evaluates gradients itself
  f, g = CountingFunction(QuadraticFunction(A, b)), CountingProx(NormL1(λ))
  method = ProximalGradientDescent()
  state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, zeros(p))
  simple = Bool[]
  for k in 1:100
    ProximalSolvers.update_state!(f, g, state, method)
    push!(simple, state.backtrack_simple)
    @test (state.f_calls, state.grad_calls, state.prox_calls) == (f_calls(f), grad_calls(f), g.prox_calls)
  end
  @test any(simple) && !all(simple)

  # in the gradient mode, a retried step that does not move x recomputes ∇f(x)
  f, g = CountingFunction(QuadraticFunction(ones(1, 1), [-1.])), CountingProx(ZeroFunction())
  state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, [1. + eps()])
  state.backtrack_simple = false
  state.L = 2.
  ProximalSolvers.update_state!(f, g, state, method)
  @test state.x == [1. + eps()]
  @test (state.f_calls, state.grad_calls, state.prox_calls) == (f_calls(f), grad_calls(f), g.prox_calls)
end

# limit, the count it limits, and that count from the wrappers
limits = ((:f_calls_limit,    :f_calls,    (f, _) -> f_calls(f)),
          (:grad_calls_limit, :grad_calls, (f, _) -> grad_calls(f)),
          (:prox_calls_limit, :prox_calls, (_, g) -> g.prox_calls))

@testset "$limit stops $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent()),
                                               (limit, count, calls) in limits
  f, g = CountingFunction(QuadraticFunction(A, b)), CountingProx(NormL1(λ))
  counts = Int[]    # calls after each iteration
  callback = _ -> (push!(counts, calls(f, g)); false)
  # with tight tolerances, the solvers need 17 (PGD) and 23 (APG) iterations, and the
  # limit stops them before the 10th
  opt = ProximalOptions(; ftol = 1e-300, xtol = 1e-300, gradtol = 1e-300, maxiter = 5000,
                        callback, limit => 10)
  res = solve!(zeros(p), f, g, solver, opt)

  @test res.call_limit_reached
  @test !res.x_converged && !res.f_converged && !res.grad_converged
  @test !res.iteration_converged && !res.f_increased
  # the solver stops after the first iteration that reaches the limit
  @test length(counts) == res.iterations
  @test getfield(res, count) == counts[end] >= 10
  @test counts[end - 1] < 10
  @test occursin("Reached a limit on the number of calls: true", sprint(show, res))
end

@testset "ADMM" begin

  @testset "exact counts" begin
    f, g = CountingProx(LogDetLoss(S)), CountingProx(NormL1(0.1))
    # the trace evaluates f every print_every iterations
    res = redirect_stdout(devnull) do
      solve!(Matrix(1.0I, q, q), f, g, ADMMSolver(),
             ProximalOptions(; maxiter = 5000, show_trace = true, print_every = 3))
    end
    @test res.converged
    @test !res.call_limit_reached
    @test res.prox_calls == f.prox_calls + g.prox_calls == 2 * res.iterations
    @test res.f_calls == f.value_calls == res.iterations ÷ 3 + 1
    @test res.grad_calls == 0

    out = sprint(show, res)
    @test occursin("f(x) calls: $(res.f_calls)", out)
    @test occursin("∇f(x) calls: 0", out)
    @test occursin("prox calls: $(res.prox_calls)", out)
  end

  @testset "prox_calls_limit stops ADMM" begin
    f, g = CountingProx(LogDetLoss(S)), CountingProx(NormL1(0.1))
    res = solve!(Matrix(1.0I, q, q), f, g, ADMMSolver(),
                 ProximalOptions(; maxiter = 5000, prox_calls_limit = 15))
    @test res.call_limit_reached
    @test !res.converged
    @test res.prox_calls == f.prox_calls + g.prox_calls
    # an iteration makes two calls
    @test 15 <= res.prox_calls < 15 + 2
    @test occursin("Reached a limit on the number of calls: true", sprint(show, res))
  end

  @testset "f_calls_limit and grad_calls_limit are ignored" begin
    res = solve!(Matrix(1.0I, q, q), LogDetLoss(S), NormL1(0.1), ADMMSolver(),
                 ProximalOptions(; maxiter = 5000, f_calls_limit = 1, grad_calls_limit = 1))
    @test res.converged
    @test !res.call_limit_reached
  end

end

@testset "zero limits $(summary(solver))" for (solver, f, g, x0) in (
    (ProximalGradientDescent(), QuadraticFunction(A, b), NormL1(λ), zeros(p)),
    (AccProxGradDescent(), QuadraticFunction(A, b), NormL1(λ), zeros(p)),
    (ADMMSolver(), LogDetLoss(S), NormL1(0.1), Matrix(1.0I, q, q)))
  zero_limits = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10, maxiter = 5000,
                                f_calls_limit = 0, grad_calls_limit = 0, prox_calls_limit = 0)
  x1, x2 = copy(x0), copy(x0)
  res1 = solve!(x1, f, g, solver, opt)
  res2 = solve!(x2, f, g, solver, zero_limits)
  @test ProximalSolvers.converged(res2)
  @test !res2.call_limit_reached
  @test x1 == x2
  @test res1.minimum == res2.minimum
  @test res1.iterations == res2.iterations
  @test (res1.f_calls, res1.grad_calls, res1.prox_calls) == (res2.f_calls, res2.grad_calls, res2.prox_calls)
end

end
