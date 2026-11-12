module BenchmarkExploreTest

using Test

# The exploratory minimal-core benchmark (benchmark/minimal/explore.jl) runs on a small size and
# every case converges to a small KKT residual computed from the problem data. Timings are not checked.
const SCRIPT = joinpath(dirname(@__DIR__), "benchmark", "minimal", "explore.jl")

@testset "benchmark/minimal/explore.jl" begin
  m = Module(:Explore)
  Base.include(m, SCRIPT)
  rows = Base.invokelatest(m.main; samples = 2, sizes = ((40, 12),), io = devnull)
  @test length(rows) == 4
  @test sort!([(r.alg, string(r.type)) for r in rows]) ==
        [("cd", "Float32"), ("cd", "Float64"), ("pgd", "Float32"), ("pgd", "Float64")]
  for r in rows
    @test r.converged
    @test r.work > 0
    @test isfinite(r.median_s) && r.min_s > 0 && r.min_s <= r.median_s
    @test r.bytes >= 0
    # KKT from Float64 data: CD stops near its tolerance; PGD at default ProximalOptions is looser.
    @test r.kkt < (r.alg == "cd" ? (r.type == Float32 ? 1e-4 : 1e-6) : 1e-2)
  end
end

end
