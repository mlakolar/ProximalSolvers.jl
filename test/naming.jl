module NamingTest

using Test, LinearAlgebra, ProximalBase, ProximalSolvers

@testset "option naming" begin
  @test ProximalOptions().print_every == 1
  @test ProximalOptions(; print_every=3).print_every == 3
  @test_throws ArgumentError ProximalOptions(; print_every=0)
  # the camelCase spellings were removed before the first release of this API
  @test_throws MethodError ProximalOptions(; printEvery=3)
  @test !hasproperty(ProximalOptions(), :printEvery)
  @test CondatVu(; norm_d=2.0).norm_d == 2.0
  @test_throws MethodError CondatVu(; normD=2.0)
  @test !hasproperty(CondatVu(), :normD)
end

end
