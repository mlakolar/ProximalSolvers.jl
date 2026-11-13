module NamingTest

using Test, LinearAlgebra, ProximalBase, ProximalSolvers

@testset "option naming" begin
  @test ProximalOptions().print_every == 1
  @test ProximalOptions(; print_every=3).print_every == 3
  @test_throws ArgumentError ProximalOptions(; print_every=0)
  # the camelCase spellings were removed before the first release of this API
  @test_throws MethodError ProximalOptions(; printEvery=3)
  @test !hasproperty(ProximalOptions(), :printEvery)
end

end

# Planted failure (do not merge; #228 PR C failure injection): fails only on macOS.
using Test
@testset "planted macOS-only failure (#228 injection)" begin
  @test !Sys.isapple()
end
