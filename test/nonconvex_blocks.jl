# Sparse plus low-rank IHT in a product space: S is a symmetric sparse matrix
# and U is rectangular, with a coupled smooth loss of S + UU'.
module NonconvexBlocksTests

using Test, LinearAlgebra, Random
using ProximalBase
using ProximalSolvers

const METHODS = (ProximalGradientDescent(), ProximalGradientDescent(; normalized = true),
                 AccProxGradDescent(), MonotoneAccProxGradDescent())

theta(x) = Matrix(x[1]) + x[2] * transpose(x[2])

mutable struct LatentLogdet{T} <: AbstractFunction
  Σ::Matrix{T}
  rejected::Int
end
ProximalBase.issmooth(::Type{<:LatentLogdet}) = true

function checked_factor(f::LatentLogdet, x)
  Θ = theta(x)
  F = cholesky(Symmetric(Θ); check = false)
  if !issuccess(F)
    f.rejected += 1
    return Θ, nothing
  end
  Θ, F
end

function (f::LatentLogdet{T})(x::Tuple) where {T}
  Θ, F = checked_factor(f, x)
  F === nothing ? T(Inf) : dot(f.Σ, Θ) - logdet(F)
end

function ProximalBase.value_and_gradient!(G::Tuple, f::LatentLogdet{T}, x::Tuple) where {T}
  Θ, F = checked_factor(f, x)
  if F === nothing
    foreach(g -> fill!(g, T(NaN)), G)
    return T(Inf)
  end
  # An inverse is computed only after the Cholesky factor proves feasibility.
  G[1] .= f.Σ .- inv(F)
  mul!(G[2], G[1], x[2])
  G[2] .*= T(2)
  dot(f.Σ, Θ) - logdet(F)
end

struct LatentDTrace{F} <: AbstractFunction
  loss::F
end
ProximalBase.issmooth(::Type{<:LatentDTrace}) = true
(f::LatentDTrace)(x::Tuple) = f.loss(theta(x))

function ProximalBase.value_and_gradient!(G::Tuple, f::LatentDTrace, x::Tuple)
  Θ = theta(x)
  raw = gradient(f.loss, Θ)
  G[1] .= (raw .+ transpose(raw)) ./ 2
  mul!(G[2], G[1], x[2])
  G[2] .*= 2
  f.loss(Θ)
end

function initial_blocks(::Type{T}) where {T}
  S = SymmetricSparseIterate(Matrix{T}(I, 4, 4))
  U = reshape(T[0.12, -0.08, 0.06, 0.1], 4, 1)
  S, U
end

function check_directional_gradient(f)
  rng = Xoshiro(24)
  x = initial_blocks(Float64)
  A = randn(rng, 4, 4)
  D = Matrix(Symmetric(A))
  V = randn(rng, 4, 1)
  G = (zeros(4, 4), zeros(4, 1))
  value_and_gradient!(G, f, x)
  h = 1e-6
  xp = (SymmetricSparseIterate(Matrix(x[1]) + h * D), x[2] + h * V)
  xm = (SymmetricSparseIterate(Matrix(x[1]) - h * D), x[2] - h * V)
  @test (f(xp) - f(xm)) / (2h) ≈ dot(G[1], D) + dot(G[2], V) rtol = 1e-6 atol = 1e-7
end

@testset "the coupled losses have both block gradients" begin
  Σ = Matrix(SymTridiagonal([4.0, 3.0, 2.5, 3.5], [0.25, -0.2, 0.15]))
  check_directional_gradient(LatentLogdet(Σ, 0))
  A = Matrix(SymTridiagonal([1.0, 1.5, 2.0, 1.2], [0.1, -0.1, 0.15]))
  B = Matrix(Diagonal([1.2, 0.8, 1.6, 1.0]))
  C = -Matrix(SymTridiagonal([1.0, 1.2, 0.9, 1.1], [0.15, -0.1, 0.2]))
  check_directional_gradient(LatentDTrace(KronQuadratic(A, B, C)))
end

@testset "latent log-det IHT rejects points outside the cone" begin
  for method in METHODS
    Σ = Matrix(SymTridiagonal([4.0, 3.0, 2.5, 3.5], [0.25, -0.2, 0.15]))
    f = LatentLogdet(Σ, 0)
    x = initial_blocks(Float64)
    g = SeparableSum(IndBallL0(1; diagonal = false), ZeroFunction())
    F0 = f(x) + g(x)
    r = solve!(x, f, g, method,
               ProximalOptions(; maxiter = 100, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-9,
                               store_trace = true, extended_trace = true))
    @test r.minimizer === x
    @test x[1] isa SymmetricSparseIterate && size(x[2]) == (4, 1)
    @test f.rejected > 0
    @test isfinite(r.minimum) && r.minimum < F0 - 1e-4
    @test r.minimum ≈ f(x) + g(x)
    values = [F0; [s.fg_x for s in r.trace]]
    @test all(isfinite, values)
    @test all(diff(values) .<= 1e-9 * max(1, abs(F0)))
    for state in r.trace
      saved = state.metadata["x"]
      @test isposdef(Symmetric(theta(saved)))
      @test isfinite(g(saved))
      @test count(!iszero, Matrix(saved[1])[i, j] for j in 1:4 for i in j+1:4) <= 1
    end
  end
end

@testset "latent D-trace IHT on mixed block shapes" begin
  A = Matrix(SymTridiagonal([1.0, 1.5, 2.0, 1.2], [0.1, -0.1, 0.15]))
  B = Matrix(Diagonal([1.2, 0.8, 1.6, 1.0]))
  C = -Matrix(SymTridiagonal([1.0, 1.2, 0.9, 1.1], [0.15, -0.1, 0.2]))
  for method in METHODS
    f = LatentDTrace(KronQuadratic(A, B, C))
    x = initial_blocks(Float64)
    g = SeparableSum(IndBallL0(1; diagonal = false), ZeroFunction())
    F0 = f(x)
    r = solve!(x, f, g, method,
               ProximalOptions(; maxiter = 100, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-9,
                               store_trace = true, extended_trace = true))
    @test r.minimizer === x
    @test isfinite(r.minimum) && r.minimum < F0 - 1e-4
    @test r.minimum ≈ f(x) + g(x)
    values = [F0; [s.fg_x for s in r.trace]]
    @test all(isfinite, values)
    @test all(diff(values) .<= 1e-9 * max(1, abs(F0)))
    for state in r.trace
      saved = state.metadata["x"]
      @test saved[1] isa SymmetricSparseIterate && size(saved[2]) == (4, 1)
      @test isfinite(g(saved))
    end
  end
end

end
