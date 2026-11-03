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

# scenario (scratch PR, not for merging): fails on Julia 1 in the first run attempt, and always
# on Windows (which only full runs)
module NamingScenario
using Test
@testset "scenario: stale re-run of a failed run" begin
  @test !(VERSION >= v"1.11" && get(ENV, "GITHUB_RUN_ATTEMPT", "1") == "1")
  @test !Sys.iswindows()
end
end
