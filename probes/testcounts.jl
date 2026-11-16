# #307: nested assertion counts of selected test files (each in a fresh module, global RNG seeded
# with Random.seed!(1) as ParallelTestRunner does), printed by a verbose top-level testset.
#   julia --project=. testcounts.jl file1 file2 ...   (paths relative to the worktree's test/)
using Test, Random
root = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
for f in ARGS
  m = Module(Symbol(f))
  Core.eval(m, :(using Test))
  Random.seed!(1)
  try
    @testset verbose = true "$f" begin
      Base.include(m, joinpath(root, "test", f * ".jl"))
    end
  catch e
    println("TESTSET ERROR in $f: ", sprint(showerror, e)[1:min(end, 300)])
  end
end
