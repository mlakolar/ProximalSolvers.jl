module CoreContracts
using Test, LinearAlgebra, SparseArrays, Random, ProximalBase, ProximalSolvers

# A real callable composition, independent of PB's deferred Translate wrapper.
struct ShiftedLoss{F, V} <: ProximalBase.AbstractFunction
  loss::F
  shift::V
end
(f::ShiftedLoss)(x) = f.loss(x .+ f.shift)

@testset "CD refuses nonfinite final objectives before scatter" begin
  x = Float32[.5]
  @test_throws r"nonfinite objective" solve!(x,
    1e-10 * LeastSquaresLoss(Float32[1e20], zeros(Float32, 1, 1)),
    NormL1(0f0), CDSolver())
  @test x == Float32[.5]
  x = [1e308, -1e308]
  @test_logs (:warn, r"maxpasses = 0") begin
    @test_throws r"nonfinite objective" solve!(x,
      LeastSquaresLoss([0.], fill(1e308, 1, 2)), NormL1(0.), CDSolver(maxpasses = 0))
  end
  @test x == [1e308, -1e308]
end

function refused(x, f, g, method; options = nothing, kwargs...)
  original = copy(x)
  @test_throws ArgumentError options === nothing ? solve!(x, f, g, method; kwargs...) :
    solve!(x, f, g, method, options; kwargs...)
  @test isequal(x, original)
end

@testset "narrow public boundary refuses before mutation" begin
  for T in (Float64, Float32), method in (CDSolver(), ProximalGradientDescent())
    X, y, x = T[1 0; 0 2], T[1, -1], T[.3, -.2]
    f, g = LeastSquaresLoss(y, X), NormL1(T(.1))
    for bad in (SparseIterate(x), sparse(x), reshape(copy(x), 1, 2), view(x, :))
      refused(bad, f, g, method)
    end
    refused(Int[0, 0], f, g, method)
    refused(Float16[0, 0], f, g, method)
    refused(zeros(T === Float32 ? Float64 : Float32, 2), f, g, method)
    refused(x, LeastSquaresLoss(y, sparse(X)), g, method)
    refused(x, LeastSquaresLoss(y, view(X, :, :)), g, method)
    refused(x, LeastSquaresLoss(reshape(y, 2, 1), X), g, method)
    refused(x, QuadraticFunction(Matrix{T}(I, 2, 2), zeros(T, 2)), g, method)
    refused(x, ShiftedLoss(f, ones(T, 2)), g, method)
    refused(x, Scaled(Scaled(f, 1e-200), 1e-200), g, method)
    refused(x, Scaled(f, 0.), g, method) # PB produces ZeroFunction, PS refuses it.
    opposite = T === Float32 ? Float64 : Float32
    refused(x, LeastSquaresLoss(opposite.(y), X), g, method)
    for badscale in (-1., NaN)
      @test_throws ArgumentError Scaled(f, badscale)
    end
    refused(x, f, NormL1(T(.1), ones(T, 2)), method)
    refused(x, f, SqrNormL2(T(.1)), method)
    for keyword in (:intercept, :offset, :continuation, :screening)
      refused(x, f, g, method; keyword => true)
    end
    for data in (T[NaN, 0], T[Inf, 0])
      refused(data, f, g, method)
      refused(x, LeastSquaresLoss(data, X), g, method)
      badX = copy(X)
      badX[1, 1] = data[1]
      refused(x, LeastSquaresLoss(y, badX), g, method)
    end
    refused(y, LeastSquaresLoss(y, X), g, method)
    alias_x = copy(x)
    refused(alias_x, LeastSquaresLoss(T[1], reshape(alias_x, 1, 2)), g, method)
    for n in (0, 1, 3)
      z = zeros(T, n)
      before = copy(z)
      @test_throws DimensionMismatch solve!(z, f, g, method)
      @test z == before
    end
    @test_throws DimensionMismatch solve!(T[],
      LeastSquaresLoss(T[], zeros(T, 0, 0)), NormL1(zero(T)), method)
    if T === Float32
      for a in (1e-50, 1e40)
        refused(x, Scaled(f, a), g, method)
        refused(x, f, NormL1(a), method)
      end
    end
    refused(x, Scaled(f, Inf), g, method)
    refused(x, f, NormL1(Inf), method)
    @test x == T[.3, -.2] && X == T[1 0; 0 2] && y == T[1, -1]
  end
end

@testset "retained constructor validation" begin
  for kw in (:ftol, :xtol), v in (0., -1., Inf, NaN)
    @test_throws ArgumentError ProximalOptions(; kw => v)
  end
  for kw in (:gradtol, :gaptol), v in (-1., Inf, NaN)
    @test_throws ArgumentError ProximalOptions(; kw => v)
  end
  @test_throws ArgumentError ProximalOptions(maxiter = 1)
  @test_throws ArgumentError CDSolver(tol = NaN)
  @test_throws ArgumentError CDSolver(order = :unknown)
end

@testset "deferred options cannot hide in positional constructors" begin
  for (keyword, value) in ((:anderson, 1), (:gaptol, .1), (:gapsafe, true))
    @test_throws ArgumentError CDSolver(; keyword => value)
  end
  @test_throws ArgumentError ProximalGradientDescent(normalized = true)
  @test_throws ArgumentError ProximalGradientDescent(debias = 1)
  @test_throws ArgumentError ProximalGradientDescent(preconditioner = :diagonal)
  @test_throws ArgumentError ProximalGradientDescent(ls = nothing)
  f, g = LeastSquaresLoss([1.], ones(1, 1)), NormL1(.1)
  refused([0.], f, g, ProximalGradientDescent(); options = ProximalOptions(gaptol = .1))
  refused([0.], f, g,
    ProximalGradientDescent(ProximalSolvers.LineSearches.BackTracking(), true, 0, nothing))
  refused([0.], f, g, CDSolver(100, 1e-7, true, true, 1, nothing, Xoshiro(1), 0., false))
end
@testset "auto positional options are validated before mutation" begin
  f, g = LeastSquaresLoss([1.], ones(1, 1)), NormL1(.1)
  valid = ProximalOptions()
  for (field, bad) in ((:maxiter, 1), (:ftol, NaN), (:xtol, 0.), (:gradtol, -1.),
       (:f_calls_limit, -1), (:grad_calls_limit, -1), (:prox_calls_limit, -1),
       (:print_every, 0), (:gapevery, 0), (:time_limit, NaN), (:gaptol, .1))
    values = Any[getfield(valid, n) for n in fieldnames(typeof(valid))]
    values[findfirst(n -> n == field, fieldnames(typeof(valid)))] = bad
    options = typeof(valid)(values...)
    refused([0.], f, g, ProximalGradientDescent(); options)
  end
  r = solve!([0.], f, g, ProximalGradientDescent(), ProximalOptions(time_limit = -1.))
  @test r.iterations == 1
  x, z = [0.], [0.]
  a = solve!(x, f, g, ProximalGradientDescent())
  b = solve!(z, f, g, ProximalGradientDescent(), ProximalOptions(gapevery = 17))
  @test x == z && a.iterations == b.iterations && isnan(b.gap)
end
end
