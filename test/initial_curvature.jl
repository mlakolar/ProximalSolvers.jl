module InitialCurvatureTests
# The curvature estimate with which ProximalGradientDescent (PGD) and AccProxGradDescent (APG) start,
# for the loss f(x) = (α/2)‖y - X x‖² (α = 1 for a raw LeastSquaresLoss): min(1, α‖X‖_F²), with ‖X‖_F the
# solvers' upper bound, which is 1 when that product is at least 1 or X = 0 (#321). The start is read
# through `ProximalSolvers.initial_state`. Where a solve is run, its quality is checked by the exact KKT
# residual of the returned point, computed here in 256-bit BigFloat from the raw data, against the
# solver's bound max(gradtol, 64 eps(T)) max(λ, λmax). The bits of a trajectory are not asserted; an
# iteration count appears as the loose limit that a case states. `converged` is a stopping flag, which a case
# asserts where it says so.
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

const METHODS = (ProximalGradientDescent(), AccProxGradDescent())
const DEFAULT = ProximalOptions()

start(method, f, g, x0, options = DEFAULT) = PS.initial_state(method, options, f, g, x0).L
lossof(α, y, X) = Scaled(LeastSquaresLoss(y, X), α)

# α‖X‖_F² and α‖Xᵀy‖∞ in 256-bit BigFloat from the data as given
curvature(X, α) = setprecision(BigFloat, 256) do
  BigFloat(α) * sum(abs2, BigFloat.(X))
end
λmax(X, y, α) = setprecision(BigFloat, 256) do
  BigFloat(α) * maximum(abs, BigFloat.(X)' * BigFloat.(y))
end

# λ = frac λmax in T, from the exact value
function penalty(::Type{T}, X, y, α, frac) where T
  iszero(frac) && return zero(T)
  max(T(frac * λmax(X, y, α)), nextfloat(zero(T)))
end

# The exact residual of the KKT conditions 0 ∈ α Xᵀ(X x - y) + λ2 x + λ1 ∂‖x‖₁ relative to
# S = max(λ1, λmax): the ℓ∞ norm of the minimal-norm element, divided by S. Float64 data.
function kkt_ratio(X, y, α, λ1, λ2, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, a = BigFloat.(X), BigFloat.(y), BigFloat.(x), BigFloat(α)
    g = a .* (Xb' * (Xb * xb - yb)) .+ BigFloat(λ2) .* xb
    l = BigFloat(λ1)
    G = maximum(j -> iszero(xb[j]) ? max(abs(g[j]) - l, zero(l)) : abs(g[j] + l * sign(xb[j])), eachindex(xb))
    S = max(l, maximum(abs, a .* (Xb' * yb)))
    Float64(G / S)
  end
end

# the solver's bound on that ratio, with an allowance of 1e-6 relative for the rounding of the solver's
# own residual (the rounding is of order (n + p) eps, far below it)
bound(options, ::Type{T}) where T = max(options.gradtol, 64 * Float64(eps(T))) * (1 + 1e-6)

# A seeded design with unit-variance, zero-mean columns, and a response from a sparse coefficient vector
# plus noise.
function standardized(::Type{T}, n, p; seed = 321) where T
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  X .-= sum(X; dims = 1) ./ n
  X ./= sqrt.(sum(abs2, X; dims = 1) ./ (n - 1))
  β = zeros(p); β[1:min(p, 4)] .= (2.0, -1.5, 1.0, 0.5)[1:min(p, 4)]
  y = X * β .+ 0.1 .* randn(rng, n)
  T.(X), T.(y)
end

@testset "R5 and the #327 case: the start is the curvature, APG converges, PGD stops at its range limit" begin
  R5 = (ones(5, 1), fill(1e160, 5), 1e-100)
  cases = (("R5, λ = 0", R5..., 0.0),
           ("R5, λ = 0.1 λmax", R5..., 0.1),
           ("#327", [1.0;;], [1e160], 5e-100, 0.0))
  for (name, X, y, α, frac) in cases
    @testset "$name" begin
      λ = penalty(Float64, X, y, α, frac)
      f, g = lossof(α, y, X), NormL1(λ)
      c = curvature(X, α)
      @test c < 1e-90
      for method in METHODS
        L0 = start(method, f, g, zeros(1))
        @test c <= L0 <= 1.0001 * c
      end

      x = zeros(1)
      r = solve!(x, f, g, AccProxGradDescent(), DEFAULT)
      @test r.converged && r.iterations <= 12
      @test kkt_ratio(X, y, α, λ, 0, x) <= bound(DEFAULT, Float64)
      # APG counts every trial, so a count above the iterations means that a trial was rejected
      @test r.backtrack_steps > r.iterations

      # PGD ends at the objective increase. Its backtracking test forms the squared step norm, which overflows
      # for a step beyond about 1.3e154, and the iterate is within 0.4% of the minimizer. This documents
      # that range limit (#TBD); a range-safe line search would change these assertions.
      x = zeros(1)
      r = solve!(x, f, g, ProximalGradientDescent(), DEFAULT)
      xstar = setprecision(BigFloat, 256) do
        (BigFloat(α) * (BigFloat.(X)' * BigFloat.(y))[1] - BigFloat(λ)) / c
      end
      @test !r.converged && r.f_increased && !r.iteration_converged && !r.stagnated
      @test abs(x[1] - xstar) / xstar < 0.004
    end
  end
end

@testset "a moderate loss scale, α = 1e-12, converges at the default maxiter" begin
  X, y = standardized(Float64, 100, 20)
  α = 1e-12
  λ = penalty(Float64, X, y, α, 0.1)
  f, g = lossof(α, y, X), NormL1(λ)
  @test curvature(X, α) < 1e-8
  for method in METHODS
    x = zeros(20)
    r = solve!(x, f, g, method, DEFAULT)
    @test r.converged
    @test kkt_ratio(X, y, α, λ, 0, x) <= bound(DEFAULT, Float64)
  end
end

@testset "α‖X‖_F² at least 1: the start is one(T) (T = $T)" for T in (Float32, Float64)
  X, y = standardized(T, 100, 8)
  n = 100
  for method in METHODS
    @test start(method, LeastSquaresLoss(y, X), NormL1(T(0.1)), zeros(T, 8)) === one(T)
    @test start(method, lossof(one(T) / T(n), y, X), NormL1(T(0.1)), zeros(T, 8)) === one(T)
    # a single column with α‖X‖_F² = 4 (1/4) = 1: the rounded-up bound is not below 1
    f1 = lossof(T(1) / T(4), T[1, 2, 3, 4], ones(T, 4, 1))
    @test start(method, f1, NormL1(T(0.1)), zeros(T, 1)) === one(T)
    # large curvature
    @test start(method, lossof(T(1e30), y, X), NormL1(T(0.1)), zeros(T, 8)) === one(T)
  end
end

@testset "X = 0: the start is one(T) and the solve is the one of the unchanged start (T = $T)" for T in (Float32, Float64)
  X, y = zeros(T, 5, 3), ones(T, 5)
  g = NormL1(T(0.5))
  for method in METHODS
    f = lossof(T(1), y, X)
    @test start(method, f, g, zeros(T, 3)) === one(T)
    x = zeros(T, 3)
    r = solve!(x, f, g, method, DEFAULT)
    @test r.converged && x == zeros(T, 3) && r.minimum == T(2.5)
    @test r.iterations <= 3
  end
end

@testset "a start that underflows T is floored at floatmin(T)" begin
  # Float32 data and a Float64 scale whose Float32 value is subnormal and nonzero, which the loss-scale check accepts
  let T = Float32, α = 1e-40
    @test 0 < T(α) < floatmin(T)
    @test PS._check_loss_scale(α, T) === nothing
    X, y = fill(T(1e-10), 4, 1), fill(T(1e-10), 4)
    @test 0 < curvature(X, α) < floatmin(T)
    f, g = lossof(α, y, X), NormL1(zero(T))
    for method in METHODS
      @test start(method, f, g, zeros(T, 1)) === floatmin(T)
      x = zeros(T, 1)
      r = solve!(x, f, g, method, DEFAULT)
      @test isfinite(r.minimum) && all(isfinite, x)
    end
  end
  # the same in Float64: α = 1e-300 is accepted and the bound is below floatmin(Float64)
  let T = Float64, α = 1e-300
    @test PS._check_loss_scale(α, T) === nothing
    X, y = fill(1e-10, 4, 1), fill(1e-10, 4)
    @test 0 < curvature(X, α) < floatmin(T)
    f, g = lossof(α, y, X), NormL1(zero(T))
    for method in METHODS
      @test start(method, f, g, zeros(T, 1)) === floatmin(T)
      x = zeros(T, 1)
      r = solve!(x, f, g, method, DEFAULT)
      @test isfinite(r.minimum) && all(isfinite, x)
    end
  end
end

@testset "squares that overflow in Float64 give the start 1 without an error" begin
  X, y = fill(1e200, 5, 2), ones(5)
  @test !isfinite(sum(abs2, X))
  for method in METHODS, α in (1.0, 1e-3)
    f, g = lossof(α, y, X), NormL1(1e-3)
    @test start(method, f, g, zeros(2)) === 1.0
  end
end

@testset "an Integer or Bool loss scale gives the start one(T) (T = $T)" for T in (Float32, Float64)
  # an integer or Bool scale is at least 1, so the tiny-scale branch is not reachable with one
  X, y = standardized(T, 100, 8)
  for method in METHODS, α in (2, true, Int8(3), UInt16(5))
    @test start(method, lossof(α, y, X), NormL1(T(0.1)), zeros(T, 8)) === one(T)
  end
end

@testset "ElasticNet at R5-like scale: the start is the curvature and APG converges" begin
  X, y, α = ones(5, 1), fill(1e160, 5), 1e-100
  λ1, λ2 = 0.1 * 5e60, 1e-101
  f, g = lossof(α, y, X), ElasticNet(λ1, λ2)
  c = curvature(X, α)
  for method in METHODS
    L0 = start(method, f, g, zeros(1))
    @test c <= L0 <= 1.0001 * c
  end
  x = zeros(1)
  r = solve!(x, f, g, AccProxGradDescent(), DEFAULT)
  @test r.converged
  @test kkt_ratio(X, y, α, λ1, λ2, x) <= bound(DEFAULT, Float64)
end

# the function barrier gives the call concrete argument types
alloc_scan(::Type{T}, X, α) where T = @allocated PS._scanned_initial_curvature(T, X, α)
alloc_apg(::Type{T}, X, α) where T = @allocated PS._initial_curvature(T, PS._root_scale(T, α), PS._frobenius_upper(T, X))

@testset "the start has type T and a warmed start allocates nothing" begin
  inputs = Any[]
  for T in (Float32, Float64)
    Xs, _ = standardized(T, 100, 8)
    push!(inputs, ("early exit", T, Xs, 1 / 100))                      # exits after 2 columns
    push!(inputs, ("full pass", T, T(1e-3) .* Xs, 1 / 100))            # α‖X‖_F² < 1
  end
  push!(inputs, ("overflow", Float64, fill(1e200, 5, 2), 1.0))
  for (name, T, X, α0) in inputs, α in (Float32(α0), Float64(α0))
    @testset "$name, T = $T, α::$(typeof(α))" begin
      @test @inferred(PS._scanned_initial_curvature(T, X, α)) isa T
      @test @inferred(PS._initial_curvature(T, PS._root_scale(T, α), PS._frobenius_upper(T, X))) isa T
      @test alloc_scan(T, X, α) == 0
      @test alloc_apg(T, X, α) == 0
      # the two starts agree in branch
      L = PS._scanned_initial_curvature(T, X, α)
      @test (L === one(T)) == (PS._initial_curvature(T, PS._root_scale(T, α), PS._frobenius_upper(T, X)) === one(T))
    end
  end
end

end
