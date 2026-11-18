# The R5-APG and alpha = 1e-12 assertions of test/initial_curvature.jl, run as a probe at the worktree it is in.
using ProximalSolvers, ProximalBase, Random, Test
const PS = ProximalSolvers
println("# Julia ", VERSION, " PS ", pkgdir(PS))
include(joinpath(@__DIR__, "common.jl"))
DEFAULT = ProximalOptions()
bound(o, ::Type{T}) where T = max(o.gradtol, 64 * Float64(eps(T))) * (1 + 1e-6)
@testset "base check" begin
@testset "R5 start and APG (base check)" begin
  X, y, α = ones(5, 1), fill(1e160, 5), 1e-100
  for frac in (0.0, 0.1)
    λ = penalty(Float64, X, y, α, frac)
    f, g = lossof(α, y, X), NormL1(λ)
    c = curvature(X, α)
    for m in METHODS
      L0 = PS.initial_state(m, DEFAULT, f, g, zeros(1)).L
      @test c <= L0 <= 1.0001 * c
    end
    x = zeros(1)
    r = solve!(x, f, g, AccProxGradDescent(), DEFAULT)
    @test r.converged && r.iterations <= 12
    @test kkt_ratio(X, y, α, λ, 0, x) <= bound(DEFAULT, Float64)
  end
end
@testset "alpha = 1e-12 (base check)" begin
  X, y = standardized(Float64, 100, 20)
  α = 1e-12
  λ = penalty(Float64, X, y, α, 0.1)
  f, g = lossof(α, y, X), NormL1(λ)
  for m in METHODS
    x = zeros(20)
    r = solve!(x, f, g, m, DEFAULT)
    println(nameof(typeof(m)), " iterations=", r.iterations, " converged=", r.converged)
    @test r.converged
    @test kkt_ratio(X, y, α, λ, 0, x) <= bound(DEFAULT, Float64)
  end
end
end
