module TierSelectionTests

# The tier manifest (test/tiers.toml) and its selection (test/tiers.jl).

using Test
using ParallelTestRunner: find_tests

include(joinpath(@__DIR__, "tiers.jl"))
using .TestTiers
const TT = TestTiers

manifest(text) = TT.parse_manifest(text)
problems(f) = try
  f()
  String[]
catch e
  e isa TT.ManifestError || rethrow()
  e.problems
end

# whether one of the problems mentions `text`
mentions(problems, text) = any(p -> occursin(text, p), problems)

const SMALL = """
[tiers]
quick = ["a", "b"]
standard = ["c"]
full = ["d"]
[not_tests]
helpers = ["h"]
environments = ["env"]
"""

@testset "tiers are cumulative" begin
  m = manifest(SMALL)
  @test TT.select(m, "quick") == ["a", "b"]
  @test TT.select(m, "standard") == ["a", "b", "c"]
  @test TT.select(m, "full") == ["a", "b", "c", "d"]
  @test_throws ArgumentError TT.select(m, "nightly")
  @test TT.rank("quick") < TT.rank("standard") < TT.rank("full")
  @test TT.rank("unknown") == 0
end

@testset "manifest problems are errors" begin
  @test isempty(problems(() -> manifest(SMALL)))
  @test mentions(problems(() -> manifest(replace(SMALL, "full = " => "thorough = [\"x\"]\nfull = "))), "unknown tier `thorough`")
  @test mentions(problems(() -> manifest(replace(SMALL, "full = [\"d\"]" => "full = [\"a\"]"))), "`a` is listed in both `quick` and `full`")
  @test mentions(problems(() -> manifest(replace(SMALL, "standard = [\"c\"]" => "standard = []"))), "tier `standard` lists no test files")
  @test mentions(problems(() -> manifest(replace(SMALL, "helpers = [\"h\"]" => "helpers = [\"a\"]"))), "`a` is both a helper and in tier `quick`")
  e = try
    manifest(replace(SMALL, "full = [\"d\"]" => "full = [\"a\"]"))
  catch err
    err
  end
  @test occursin("test/tiers.toml has problems", sprint(showerror, e))
end

@testset "files on disk and in the manifest agree" begin
  m = manifest(SMALL)
  @test TT.check(m, ["a", "b", "c", "d", "h", "env/x"]) === nothing
  @test mentions(problems(() -> TT.check(m, ["a", "b", "c", "d", "h", "e"])), "`test/e.jl` has no tier")
  @test mentions(problems(() -> TT.check(m, ["a", "b", "c", "h"])), "`d` is in tier `full`, but test/d.jl does not exist")
  @test mentions(problems(() -> TT.check(m, ["a", "b", "c", "d"])), "helper `h` does not exist")
  # a file outside the environment directories needs a tier, even with a similar name
  @test mentions(problems(() -> TT.check(m, ["a", "b", "c", "d", "h", "envx"])), "`test/envx.jl` has no tier")
end

@testset "the package's tiers" begin
  m = TT.load(joinpath(@__DIR__, "tiers.toml"))
  discovered = collect(keys(find_tests(@__DIR__)))
  @test TT.check(m, discovered) === nothing
  regular = sort!(filter(name -> haskey(m.tier, name), discovered))
  quick, standard, full = (TT.select(m, t) for t in TIERS)
  @test full == regular
  @test issubset(quick, standard) && issubset(standard, full)
  @test length(quick) < length(standard) < length(full)
  # every regular file is in exactly one tier list
  @test sort!(vcat((filter(n -> m.tier[n] == t, full) for t in TIERS)...)) == full
  # the exhaustive companions stay deeper than their representative cases
  for (basics, rest) in (("coordinate_descent_basics", "coordinate_descent"),
                         ("float32_certificates_basics", "float32_certificates"),
                         ("symmetric_penalties_basics", "symmetric_penalties"),
                         ("audit_regressions_basics", "audit_regressions"))
    @test m.tier[basics] == "quick"
    @test TT.rank(m.tier[rest]) > TT.rank("quick")
  end
  @test m.tier["symmetric_penalty_combinations"] == "full"
  @test "tier_selection" in quick
  @test all(name -> !startswith(name, "oracles/"), full)
end

end
