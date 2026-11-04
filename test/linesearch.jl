module LineSearchTest
# demonstration (disposable PR, not for merging): branch protection on master

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

Random.seed!(1)

n, p = 100, 50
X = randn(n, p)
Y = X * vcat(randn(5), zeros(p - 5)) + 0.1 * randn(n)
A, b = X'X / n, -X'Y / n
λ = 0.1 * norm(b, Inf)

@testset "solver reuse $(summary(solver))" for solver in (ProximalGradientDescent(), AccProxGradDescent())
  # without a penalty, ProximalGradientDescent reaches the gradient mode of the
  # line search, so state carried over from the first solve would change the second
  f = QuadraticFunction(A, b)
  opt = ProximalOptions(; ftol = 1e-300, xtol = 1e-300, gradtol = 1e-12, maxiter = 5000,
                        store_trace = true, extended_trace = true)

  x1, x2 = zeros(p), zeros(p)
  res1 = solve!(x1, f, ZeroFunction(), solver, opt)
  res2 = solve!(x2, f, ZeroFunction(), solver, opt)
  @test x1 == x2
  @test res1.iterations == res2.iterations
  @test res1.backtrack_steps == res2.backtrack_steps
  @test [s.metadata["x"] for s in res1.trace] == [s.metadata["x"] for s in res2.trace]

  @test res1.backtrack_steps >= res1.iterations
  @test occursin("Backtracking steps: $(res1.backtrack_steps)", sprint(show, res1))
end

@testset "TFOCS backtracking switches to gradients near convergence" begin
  f, g = QuadraticFunction(A, b), NormL1(λ)
  method = ProximalGradientDescent()
  state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, zeros(p))

  simple, rel = Bool[], Float64[]
  grad_f_x = similar(state.x)
  fresh_gradient = true
  for k in 1:100
    ProximalSolvers.update_state!(f, g, state, method)
    push!(simple, state.backtrack_simple)
    push!(rel, abs(state.f_x - state.f_x_previous) / max(abs(state.f_x), abs(state.f_x_previous)))
    value_and_gradient!(grad_f_x, f, state.x)
    fresh_gradient &= grad_f_x == state.grad_f_x
  end

  # the function values are compared while they are far apart ...
  @test all(simple[1:10])
  @test all(rel[simple] .>= 1e-10)
  # ... and the gradients for good once they are close
  k = findfirst(!, simple)
  @test k !== nothing
  @test all(.!simple[k:end])
  @test rel[k] < 1e-10
  # the gradient at x is current after every iteration, also when the mode switches
  @test fresh_gradient
end

@testset "gradient is current when a retried step does not move x" begin
  # f(x) = x²/2 - x, so ∇f(x) = x - 1. In the gradient mode, the first trial step
  # from x' = 1 + eps() rounds to x = 1 and evaluates ∇f there; it is rejected,
  # and the retry with a larger L rounds back to x'
  f, g = QuadraticFunction(ones(1, 1), [-1.]), ZeroFunction()
  method = ProximalGradientDescent()
  state = ProximalSolvers.initial_state(method, ProximalOptions(), f, g, [1. + eps()])
  state.backtrack_simple = false
  state.L = 2.

  ProximalSolvers.update_state!(f, g, state, method)
  @test state.backtrack_steps == 1
  @test state.x == [1. + eps()]
  @test state.grad_f_x == [eps()]
end

# counts the points off the domain of f where it is evaluated, by value or with
# the gradient
struct OffDomain{F} <: ProximalBase.AbstractFunction
  f::F
  values::Base.RefValue{Int}
  gradients::Base.RefValue{Int}
end
OffDomain(f) = OffDomain(f, Ref(0), Ref(0))
ProximalBase.issmooth(::Type{<:OffDomain}) = true
function (c::OffDomain)(X)
  v = c.f(X)
  isfinite(v) || (c.values[] += 1)
  v
end
function ProximalBase.value_and_gradient!(G, c::OffDomain, X)
  v = value_and_gradient!(G, c.f, X)
  isfinite(v) || (c.gradients[] += 1)
  v
end

@testset "the graphical lasso: trial points off the cone" begin
  # f = Inf off the positive definite cone. ProximalGradientDescent rejects such
  # trial points and shrinks the step; it used to set L = Inf, so that the next
  # trial returned X0 as if converged. AccProxGradDescent restarts when the
  # extrapolated point is off the cone, where it used to backtrack forever on a
  # NaN gradient. Both now reach the minimum found by ADMM.
  opt = ProximalOptions(; ftol = 1e-12, xtol = 1e-12, gradtol = 1e-12, maxiter = 20_000)
  for (q, s) in ((5, 100.), (10, 10.), (20, 50.))
    rng = Random.MersenneTwister(q)
    A = randn(rng, 2q, q)
    S = s * (A' * A / 2q)
    f, g = LogDetLoss(S), NormL1(0.1, ones(q, q) - I)
    ref = Matrix(1.0I, q, q)
    solve!(ref, f, g, ADMMSolver(; abstol = 1e-12, reltol = 1e-12), ProximalOptions(; maxiter = 100_000))
    Fref = f(ref) + g(ref)
    for solver in (ProximalGradientDescent(), AccProxGradDescent())
      c = OffDomain(f)
      X = Matrix(1.0I, q, q)
      res = solve!(X, c, g, solver, opt)
      @test ProximalSolvers.converged(res)
      @test res.iterations > 1
      @test isposdef(X)
      @test res.minimum ≈ Fref rtol = 1e-7
      @test c.values[] > 0          # trial points off the cone were rejected
      if solver isa AccProxGradDescent
        @test c.gradients[] > 0     # extrapolated points off the cone restarted
      end
    end
  end

  # no step exists from a point off the domain
  S = [2. 1.; 1. 2.]
  for solver in (ProximalGradientDescent(), AccProxGradDescent())
    @test_throws ArgumentError solve!([1. 2.; 2. 1.], LogDetLoss(S), NormL1(0.1), solver)
  end
end

end

# demonstration (disposable PR, not for merging): a deliberate failing assertion
module LinesearchDemoFailure
using Test
@testset "demo: deliberate failure" begin
  @test 1 + 1 == 3
end
end
