module ExamplesTest

using Test

# Every `.jl` script under examples/, in subfolders too, runs to its end, which includes its own
# checks of the result, each in a fresh module and with its printed output discarded.
const DIR = joinpath(dirname(@__DIR__), "examples")

# Paths of the scripts relative to examples/, with "/" as the separator.
function example_files(dir)
  files = String[]
  for (root, _, names) in walkdir(dir)
    for name in names
      endswith(name, ".jl") &&
        push!(files, replace(relpath(joinpath(root, name), dir), '\\' => '/'))
    end
  end
  sort!(files)
end

@testset "examples" begin
  files = example_files(DIR)
  # An empty or misplaced folder must fail here instead of passing with no testset.
  @test any(startswith("problems/"), files)
  @test any(startswith("comparisons/"), files)
  for file in files
    @testset "$file" begin
      m = Module(Symbol(replace(splitext(file)[1], r"[^A-Za-z0-9_]" => "_")))
      ok = redirect_stdout(devnull) do
        Base.include(m, joinpath(DIR, normpath(file)))
        true
      end
      @test ok
    end
  end
end

end
