module NamingTest

using Test, LinearAlgebra, ProximalBase, ProximalSolvers

@testset "option naming and compatibility" begin
  @test ProximalOptions().print_every == 1
  @test ProximalOptions(; print_every=0).print_every == 1
  old = @test_deprecated r"printEvery" ProximalOptions(; printEvery=3)
  new = ProximalOptions(; print_every=3)
  @test old.print_every == new.print_every == 3
  @test (@test_deprecated r"printEvery" old.printEvery) == 3
  @test hasproperty(old, :printEvery)
  @test_throws ArgumentError ProximalOptions(; print_every=2, printEvery=3)

  legacy = @test_deprecated r"normD" CondatVu(; normD=2.0)
  canonical = CondatVu(; norm_d=2.0)
  @test legacy == canonical
  @test (@test_deprecated r"normD" legacy.normD) == 2.0
  @test hasproperty(legacy, :normD)
  @test_throws ArgumentError CondatVu(; norm_d=1.0, normD=2.0)

  # Keyword compatibility preserves the traced solver's stopping behavior.
  f = QuadraticFunction(Matrix(Diagonal([1.0, 2.0])), [-1.0, -1.0])
  a = solve!(zeros(2), f, NormL1(0.1), ProximalGradientDescent(), old)
  b = solve!(zeros(2), f, NormL1(0.1), ProximalGradientDescent(), new)
  @test a.minimizer == b.minimizer
  @test a.iterations == b.iterations
end

end
