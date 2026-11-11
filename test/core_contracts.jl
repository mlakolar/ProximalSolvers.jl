module CoreContracts
using Test, LinearAlgebra, SparseArrays, Random, ProximalBase, ProximalSolvers

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

end
