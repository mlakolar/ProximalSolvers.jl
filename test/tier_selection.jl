module TierSelectionTests

# The tier manifest (test/tiers.toml), its selection and the CI risk rules (test/tiers.jl,
# .github/tier-rules.toml), and the nightly plan of scripts/ci_plan.jl.

using Test
using TOML
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
  @test mentions(problems(() -> manifest(replace(SMALL, "standard = [\"c\"]" => "standard = \"c\""))), "tier `standard` must be a list of file names")
  @test mentions(problems(() -> manifest(replace(SMALL, "standard = [\"c\"]" => "standard = [1]"))), "tier `standard` must be a list of file names")
  e = try
    manifest(replace(SMALL, "full = [\"d\"]" => "full = [\"a\"]"))
  catch err
    err
  end
  @test occursin("test/tiers.toml or .github/tier-rules.toml has problems", sprint(showerror, e))
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
  # the CI plan names the files as the runner does, without loading it
  @test TT.discover(@__DIR__) == sort(discovered)
  @test TT.check(m, discovered) === nothing
  regular = sort!(filter(name -> haskey(m.tier, name), discovered))
  quick, standard, full = (TT.select(m, t) for t in TIERS)
  @test full == regular
  @test issubset(quick, standard) && issubset(standard, full)
  @test length(quick) < length(standard) < length(full)
  # every regular file is listed exactly once across the tier lists of the file itself
  listed = vcat((TOML.parsefile(joinpath(@__DIR__, "tiers.toml"))["tiers"][t] for t in TIERS)...)
  @test sort(listed) == full
  # only these are not tests: a test file moved into either list would stop running
  @test sort(m.helpers) == ["tiers"]
  @test isempty(m.environments)
  @test sort(quick)==sort(["aqua","ci_gate","naming","tier_selection","minimal_core_characterization","core_contracts","paired_master"])
  @test m.tier["core_regressions"]=="standard"
  @test m.tier["examples"]=="full"
  @test "tier_selection" in quick
  @test all(name -> !startswith(name, "oracles/"), full)
end

# The CI rules (.github/tier-rules.toml) read with the tier lists, as scripts/ci_plan.jl does.
const ROOT = dirname(@__DIR__)
const RULES = joinpath(ROOT, ".github", "tier-rules.toml")
const CI = TT.load(joinpath(@__DIR__, "tiers.toml"), RULES)

@testset "rule problems are errors" begin
  rules(text) = problems(() -> manifest(SMALL * "\n" * text))
  @test isempty(rules("[timeouts]\nquick = 5\nstandard = 10\nfull = 20\n[[risk]]\ntier = \"none\"\npaths = [\"docs/**\"]\n"))
  @test mentions(rules("[[risk]]\ntier = \"thorough\"\npaths = [\"a\"]\n"), "risk rule 1 has tier `thorough`")
  @test mentions(rules("[[risk]]\ntier = \"quick\"\npaths = []\n"), "risk rule 1 has no paths")
  @test mentions(rules("[[risk]]\ntier = \"quick\"\npaths = \"a\"\n"), "must be lists of strings")
  @test mentions(rules("[[risk]]\ntier = \"quick\"\nfocus = [\"zz\"]\npaths = [\"a\"]\n"), "focus `zz`, which is in no tier")
  @test mentions(rules("[timeouts]\nquick = 0\nstandard = 10\nfull = 20\n"), "timeouts.quick = 0")
  @test mentions(rules("[timeouts]\nquick = 5\nfull = 20\n"), "timeouts.standard is missing")
  # the two files cannot both define a table
  mktempdir() do dir
    write(joinpath(dir, "a.toml"), SMALL)
    write(joinpath(dir, "b.toml"), "[tiers]\nquick = [\"x\"]\n")
    @test mentions(problems(() -> TT.load(joinpath(dir, "a.toml"), joinpath(dir, "b.toml"))), "`tiers` is in both")
  end
end

@testset "path patterns" begin
  matches(pattern, path) = occursin(TT.glob_regex(pattern), path)
  @test matches("src/**", "src/cd/gap.jl") && matches("src/**", "src/types.jl")
  @test matches("src/*.jl", "src/utils.jl") && !matches("src/*.jl", "src/cd/gap.jl")
  @test matches("**/*.md", "README.md") && matches("**/*.md", "test/TESTING.md") && !matches("**/*.md", "README.mdx")
  @test matches("docs/**", "docs/make.jl") && !matches("docs/**", "docsx/a")
  @test matches("test/tiers.jl", "test/tiers.jl") && !matches("test/tiers.jl", "test/tiersXjl")
  @test matches("a?c", "abc") && !matches("a?c", "a/c")
end

classify(paths...) = TT.classify(CI, collect(paths))[1:2]
pr(paths...; labels = String[]) = TT.pr_tier(CI, collect(paths), labels)[1:2]
const STANDARD = TT.select(CI, "standard")

@testset "risk rules" begin
  @test classify("docs/src/index.md","CONTRIBUTING.md","README.md","test/TESTING.md") == ("none",String[])
  @test classify("docs/make.jl","docs/Project.toml","LICENSE","codecov.yml") == ("none",String[])
  @test classify("benchmark/check_analysis.py","benchmark/compare.py") == ("none",String[])
  @test classify("benchmark/run.jl","benchmark/check_analysis.py") == ("quick",["benchmark_formal"])
  @test classify("benchmark/cases.jl")==("quick",["benchmark_formal"])
  @test classify("benchmark/minimal/explore.jl")==("quick",["benchmark_explore"])
  @test classify("benchmark/minimal/README.md")==("none",String[])
  @test classify("scripts/check_naming.py",".github/workflows/Documentation.yml") == ("none",String[])
  @test classify("test/core_contracts.jl")==("quick",["core_contracts"])
  @test classify("test/core_contracts.jl","test/minimal_core_characterization.jl")==("quick",["core_contracts","minimal_core_characterization"])
  @test classify("examples/01_cd_lasso.jl")==("quick",["examples"])
  @test classify("examples/README.md")==("none",String[])
  @test classify("test/removed_file.jl")==("quick",String[])
  for path in ("test/Project.toml","test/Manifest.toml","test/LocalPreferences.toml","test/data/x.csv",
    ".github/workflows/CI.yml",".github/tier-rules.toml","Project.toml","scripts/ci_plan.jl",
    "scripts/ci_gate.jl","scripts/ci_verdict.jl","scripts/ci_environment.jl","scripts/test.jl",
    "scripts/test_report.jl","test/runtests.jl","test/tiers.jl","test/tiers.toml",
    "Manifest.toml","a/new/file.txt",".github/workflows/New.yml","ext/SomeExt.jl")
    @test classify(path)[1]=="full"
  end
  for path in ("src/ProximalSolvers.jl","src/types.jl","src/solve.jl","src/blocks.jl","src/line_searches.jl",
    "src/precompile.jl","src/cd/models.jl","src/cd/solver.jl","src/cd/leastsquares.jl",
    "src/utils.jl","src/solvers/image_models.jl","src/solvers/proximal_gradient_descent.jl")
    @test classify(path)==("full",String[])
  end
  @test classify("docs/src/index.md","test/core_contracts.jl","src/cd/leastsquares.jl")[1]=="full"
  @test pr("src/cd/leastsquares.jl","test/core_contracts.jl")==("full",String[])
  @test pr("test/examples.jl")==("quick",["examples"])
  @test pr()==("quick",String[])
end

@testset "synthetic localized risk and focus policy" begin
  m=TT.parse_manifest(SMALL * """
[[risk]]
tier="quick"
paths=["test/h.jl"]
focus=["b","c","d"]
[[risk]]
tier="quick"
paths=["test/**/*.jl"]
[[risk]]
tier="standard"
paths=["src/local.jl"]
focus=["d"]
[[risk]]
tier="full"
paths=["src/shared.jl"]
[[risk]]
tier="none"
paths=["docs/**"]
""")
  @test TT.classify(m,["test/h.jl"])[1:2]==("quick",["b","c","d"])
  @test TT.classify(m,["src/local.jl","test/c.jl"])[1:2]==("standard",["c","d"])
  @test TT.pr_tier(m,["src/local.jl","test/c.jl"],String[])[1:2]==("standard",["d"])
  @test TT.pr_tier(m,["src/local.jl"],["test:full"])[1:2]==("full",String[])
  @test TT.pr_tier(m,["src/shared.jl"],["test:standard"])[1:2]==("full",String[])
  @test TT.pr_tier(m,["docs/x.md","test/a.jl"],String[])[1:2]==("quick",String[])
  @test TT.classify(m,["src/new.jl"])[1]=="full"
end

function julia_source_paths(root)
  paths = String[]
  for (dir, _, files) in walkdir(root), file in files
    endswith(file, ".jl") || continue
    push!(paths, replace(relpath(joinpath(dir, file), root), '\\' => '/'))
  end
  sort!(paths)
end

@testset "source inventory excludes generated coverage artifacts" begin
  mktempdir() do root
    mkpath(joinpath(root, "cd"))
    for file in ("solver.jl", "new_model.jl", "solver.jl.123.cov")
      write(joinpath(root, "cd", file), "# inventory fixture\n")
    end
    @test julia_source_paths(root) == ["cd/new_model.jl", "cd/solver.jl"]
    # A new Julia source remains visible and fails the explicit-rule requirement.
    @test !any(rule -> "src/cd/new_model.jl" in rule.patterns &&
                      rule.tier in ("standard", "full"), CI.rules)
  end
end

@testset "every rule decides the paths it names, and they exist" begin
  for rule in CI.rules, pattern in rule.patterns
    occursin('*', pattern) && continue
    @test isfile(joinpath(ROOT, pattern))
    i = findfirst(r -> any(re -> occursin(re, pattern), r.regexes), CI.rules)
    @test CI.rules[i] === rule
  end
  # every source file is named by a rule of its own (no glob), and a source file no rule names,
  # such as a new one, gets full
  # Finished coverage workers may already have written .cov files beside sources.
  for file in julia_source_paths(joinpath(ROOT, "src"))
    path = "src/" * file
    @test any(rule -> path in rule.patterns && rule.tier in ("standard", "full"), CI.rules)
  end
  @test classify("src/cd/new_model.jl") == ("full", String[])
  @test classify("src/new_dir/file.jl", "test/core_contracts.jl") == ("full", ["core_contracts"])
  # the focus files of a solver rule are full-only files: standard runs the others anyway
  for rule in CI.rules, name in rule.focus
    rule.tier == "standard" && @test CI.tier[name] == "full"
  end
  @test sort(collect(keys(CI.timeouts))) == sort(collect(TIERS))
end

# Explicit native calls in the package source. A file under src/ (or ext/) that makes one must be
# registered in a [[native]] entry of .github/tier-rules.toml, and an entry is accepted only when
# its `enforcement` names a pre-merge platform mechanism that this repository implements. The
# patterns match the text of a line that does not start with `#`; they do not parse Julia, so a
# docstring or string literal that contains such text is also a match (the guard fails closed).
# Generic linear algebra (`mul!`, `dot`) is not matched.
const NATIVE_PATTERNS = [
  r"\bccall\s*\(",
  r"@ccall\b",
  r"\b(?:LAPACK|BLAS)\.\w",
  r"^\s*(?:using|import)\b.*\b(?:LAPACK|BLAS|Libdl)\b",
  r"\bLibdl\.\w",
]
# the pre-merge platform enforcement mechanisms that this repository implements; empty until a
# PR adds one (a CI.yml plan/verdict job that runs the registered checks on the registered
# platforms) and names it here
const IMPLEMENTED_NATIVE_ENFORCEMENT = String[]
const NATIVE_KEYS = ["why", "paths", "checks", "platforms", "enforcement"]
const NATIVE_PLATFORMS = ["macos-latest", "windows-latest"]

# path => the line numbers (1-based) that match a pattern, for the files that have any
function native_hits(sources::AbstractDict{String, String})
  hits = Dict{String, Vector{Int}}()
  for (path, text) in sources, (i, line) in enumerate(split(text, '\n'))
    startswith(lstrip(line), "#") && continue
    any(re -> occursin(re, line), NATIVE_PATTERNS) && push!(get!(hits, path, Int[]), i)
  end
  return hits
end

isstringlist(v) = v isa AbstractVector && !isempty(v) && all(x -> x isa AbstractString, v)

# The problems of the sources and the [[native]] entries: a file with a native call that no entry
# lists, and an entry whose keys, paths, checks, platforms or enforcement do not describe a
# registration that is enforced (`why` is required but its text is not checked).
function native_problems(sources::AbstractDict{String, String}, entries::AbstractVector, tests, implemented)
  problems = String[]
  hits = native_hits(sources)
  registered = Set{String}()
  for (i, entry) in enumerate(entries)
    if !(entry isa AbstractDict)
      push!(problems, "native entry $i is not a table")
      continue
    end
    paths = get(entry, "paths", nothing)
    label = "native entry $i" * (isstringlist(paths) ? " ($(join(paths, ", ")))" : "")
    for key in NATIVE_KEYS
      haskey(entry, key) || push!(problems, "$label is missing the key `$key`")
    end
    for key in sort!(String.(collect(keys(entry))))
      key in NATIVE_KEYS || push!(problems, "$label has the unknown key `$key`")
    end
    if haskey(entry, "paths") && !isstringlist(paths)
      push!(problems, "$label: `paths` must be a non-empty list of strings")
    elseif haskey(entry, "paths")
      for path in paths
        push!(registered, path)
        if !haskey(sources, path)
          push!(problems, "$label: `$path` is not a source file under src/ or ext/")
        elseif !haskey(hits, path)
          push!(problems, "$label: `$path` has no explicit native call, so the registration is stale")
        end
      end
    end
    checks = get(entry, "checks", nothing)
    if haskey(entry, "checks") && !isstringlist(checks)
      push!(problems, "$label: `checks` must be a non-empty list of test names")
    elseif haskey(entry, "checks")
      for check in checks
        check in tests || push!(problems, "$label: check `$check` is not a test in the tier lists")
      end
    end
    platforms = get(entry, "platforms", nothing)
    if haskey(entry, "platforms") && !isstringlist(platforms)
      push!(problems, "$label: `platforms` must be a non-empty list of strings")
    elseif haskey(entry, "platforms")
      for platform in platforms
        platform in NATIVE_PLATFORMS ||
          push!(problems, "$label: platform `$platform` is not one of $(join(NATIVE_PLATFORMS, ", "))")
      end
    end
    if haskey(entry, "enforcement")
      enforcement = entry["enforcement"]
      enforcement isa AbstractString && enforcement in implemented ||
        push!(problems, "$label names no implemented pre-merge platform enforcement ($(repr(enforcement)); " *
          "implemented: $(isempty(implemented) ? "none" : join(implemented, ", "))). The PR that adds native " *
          "code must implement one in the plan and verdict of CI.yml and add it to " *
          "IMPLEMENTED_NATIVE_ENFORCEMENT in test/tier_selection.jl")
    end
  end
  for path in sort!(collect(keys(hits)))
    path in registered && continue
    push!(problems, "`$path` makes an explicit native call (line $(first(hits[path]))) and is not listed in " *
      "the `paths` of a [[native]] entry of .github/tier-rules.toml")
  end
  return problems
end

# the .jl files under src/ and ext/ (if it exists), keyed by their repository-relative path with `/`
function native_sources(root)
  sources = Dict{String, String}()
  for dir in ("src", "ext")
    isdir(joinpath(root, dir)) || continue
    for (d, _, files) in walkdir(joinpath(root, dir)), file in files
      endswith(file, ".jl") || continue
      path = joinpath(d, file)
      sources[replace(relpath(path, root), '\\' => '/')] = read(path, String)
    end
  end
  return sources
end

@testset "explicit native calls in the package source are registered and enforced" begin
  sources = native_sources(ROOT)
  @test haskey(sources, "src/ProximalSolvers.jl")
  native = get(TOML.parsefile(RULES), "native", [])
  found = native isa AbstractVector ?
    native_problems(sources, native, Set(keys(CI.tier)), IMPLEMENTED_NATIVE_ENFORCEMENT) :
    ["`native` in .github/tier-rules.toml must be an array of tables ([[native]])"]
  @test found == String[]
end

@testset "native guard: synthetic sources and registrations" begin
  source(text) = Dict("src/f.jl" => text)
  unregistered(text) = native_problems(source(text), [], ["a", "b"], String[])
  # a call or import that is not registered
  for text in ("ccall(:f, Cvoid, ())", "x = 1\n  @ccall f()::Cvoid", "LAPACK.syevr!('V', 'U', A)",
               "y = BLAS.gemv!('N', 1.0, A, x, 0.0, y)", "using LinearAlgebra: LAPACK", "import LinearAlgebra.BLAS",
               "import LinearAlgebra: BLAS, mul!", "using Libdl", "h = Libdl.dlopen(\"x\")",
               "LinearAlgebra.BLAS.scal!(2, 3.0, x, 1)", "ccall (:f, Cvoid, ())")
    @test mentions(unregistered(text), "`src/f.jl` makes an explicit native call")
  end
  # text that is not a native call
  for text in ("# uses BLAS.gemv", "    # ccall(:f, Cvoid, ())", "  #  using LinearAlgebra: LAPACK",
               "(CPU, BLAS kernel, compilation) rather than on the accuracy of the point.",
               "mul!(y, A, x)", "using LinearAlgebra", "import LinearAlgebra: mul!, dot", "x = myccall(1)",
               "z = SBLAS.f(1)", "# Libdl.dlopen(\"x\")\nx = 1\n")
    @test unregistered(text) == String[]
  end
  # the line numbers of the matches (a comment line does not count)
  @test native_hits(source("a = 1\n# BLAS.gemv!(1)\nBLAS.gemv!(1)\n\nccall(:f, Cvoid, ())\n")) ==
        Dict("src/f.jl" => [3, 5])
  @test isempty(native_hits(source("a = 1\n")))
  # registrations
  src = source("x = 1\nccall(:f, Cvoid, ())\n")
  entry = Dict{String, Any}("why" => "a C routine", "paths" => ["src/f.jl"], "checks" => ["a"],
                            "platforms" => ["macos-latest", "windows-latest"], "enforcement" => "pre-merge-platform-job")
  with(; kw...) = merge(entry, Dict{String, Any}(String(k) => v for (k, v) in kw))
  without(key) = delete!(copy(entry), key)
  problems_of(e, implemented = ["pre-merge-platform-job"]) = native_problems(src, [e], ["a", "b"], implemented)
  # an entry that names an enforcement that is not implemented fails; the same entry passes once a PR implements it
  @test mentions(problems_of(entry, String[]), "names no implemented pre-merge platform enforcement")
  @test mentions(problems_of(entry, ["another-mechanism"]), "names no implemented pre-merge platform enforcement")
  @test mentions(problems_of(with(enforcement = "other"), ["pre-merge-platform-job"]), "names no implemented")
  @test mentions(problems_of(with(enforcement = ""), ["pre-merge-platform-job"]), "names no implemented")
  @test mentions(problems_of(with(enforcement = 3), ["pre-merge-platform-job"]), "names no implemented")
  @test problems_of(entry) == String[]
  @test problems_of(with(platforms = ["windows-latest"])) == String[]
  # the other fields
  @test mentions(problems_of(with(checks = String[])), "`checks` must be a non-empty list")
  @test mentions(problems_of(with(checks = ["a", "zz"])), "check `zz` is not a test in the tier lists")
  @test mentions(problems_of(with(checks = "a")), "`checks` must be a non-empty list")
  @test mentions(problems_of(with(paths = ["src/other.jl"])), "`src/other.jl` is not a source file")
  @test mentions(problems_of(with(paths = ["src/other.jl"])), "`src/f.jl` makes an explicit native call")
  @test mentions(problems_of(with(paths = String[])), "`paths` must be a non-empty list")
  @test mentions(native_problems(merge(src, Dict("src/g.jl" => "x = 1\n")), [with(paths = ["src/g.jl"])], ["a"],
                                 ["pre-merge-platform-job"]), "`src/g.jl` has no explicit native call")
  @test mentions(problems_of(with(platforms = ["linux"])), "platform `linux` is not one of")
  @test mentions(problems_of(with(platforms = ["macos-latest", "linux"])), "platform `linux` is not one of")
  @test mentions(problems_of(with(platforms = String[])), "`platforms` must be a non-empty list")
  for key in NATIVE_KEYS
    label = key == "paths" ? "native entry 1" : "native entry 1 (src/f.jl)"
    @test mentions(problems_of(without(key)), "$label is missing the key `$key`")
  end
  @test mentions(problems_of(with(extra = "x")), "has the unknown key `extra`")
  @test mentions(native_problems(src, [3], ["a"], String[]), "native entry 1 is not a table")
  # a registered path covers its file only, and a registration for one file does not hide another
  both = merge(src, Dict("src/g.jl" => "BLAS.gemv!(1)\n"))
  @test mentions(native_problems(both, [entry], ["a"], ["pre-merge-platform-job"]), "`src/g.jl` makes an explicit native call")
  @test native_problems(both, [with(paths = ["src/f.jl", "src/g.jl"])], ["a"], ["pre-merge-platform-job"]) == String[]
end

@testset "labels only raise the tier" begin
  @test pr("test/core_contracts.jl"; labels = ["test:standard"]) == ("standard", String[])
  @test pr("test/core_contracts.jl"; labels = ["test:full"]) == ("full", String[])
  @test pr("test/core_contracts.jl"; labels = ["test:standard", "test:full", "bug"]) == ("full", String[])
  @test pr("docs/src/index.md"; labels = ["test:standard"]) == ("standard", String[])
  @test pr("docs/src/index.md"; labels = ["documentation"]) == ("none", String[])
  # a label below the path tier changes nothing
  @test pr("src/types.jl"; labels = ["test:standard"]) == ("full", String[])
  @test pr("src/cd/solver.jl"; labels = ["test:standard"]) == ("full", String[])
  # the focus files of a raised tier leave out what it runs
  @test pr("src/cd/solver.jl"; labels = ["test:full"]) == ("full", String[])
  # a test: label that names no tier above quick stops the plan
  @test_throws ArgumentError pr("test/core_contracts.jl"; labels = ["test:quick"])
  @test_throws ArgumentError pr("test/core_contracts.jl"; labels = ["test:thorough"])
  notes = TT.pr_tier(CI, ["test/core_contracts.jl"], ["test:full"])[4]
  @test only(notes) == "Label `test:full` asks for at least full."
end

@testset "additive changes to the tier lists" begin
  # the edits below work on LF text; a Windows checkout has CRLF line endings
  old = replace(read(joinpath(@__DIR__, "tiers.toml"), String), "\r\n" => "\n")
  add(text, tier, name) = replace(text, "\n$tier = [\n" => "\n$tier = [\n  \"$name\",\n"; count = 1)
  # new files only: their names, which then run as changed test files
  @test TT.manifest_additions(old, add(old, "quick", "solver_new"), ["solver_new"]) == (["solver_new"], String[])
  @test TT.manifest_additions(old, replace(add(old, "quick", "solver_new"), "\n" => "\r\n"), ["solver_new"]) ==
        (["solver_new"], String[])
  two = add(add(old, "full", "b_new"), "standard", "a_new")
  @test TT.manifest_additions(old, two, ["a_new", "b_new"]) == (["a_new", "b_new"], String[])
  # comments and order alone change nothing
  commented = replace(old, "# Cumulative" => "# Edited cumulative"; count = 1)
  @test commented != old && TT.manifest_additions(old, commented, String[]) == (String[], String[])
  # the names come from the manifest itself, so that a PR that moves a file still passes here
  line(name) = "  \"$name\",\n"
  adjacent = match(r"\n  \"([^\"]+)\",\n  \"([^\"]+)\",\n", old) # two consecutive entries of one list
  q1, q2 = adjacent.captures
  @test TT.parse_manifest(old).tier[q1] == "quick"
  swapped = replace(old, line(q1) * line(q2) => line(q2) * line(q1))
  @test swapped != old && TT.manifest_additions(old, swapped, String[]) == (String[], String[])
  # anything else needs full
  a, p = TT.manifest_additions(old, add(old, "quick", "solver_new"), String[])
  @test a === nothing && occursin("not a new file of this change", only(p))
  moved = add(replace(old, line(q1) => ""; count = 1), "standard", q1)
  a, p = TT.manifest_additions(old, moved, String[])
  @test a === nothing && only(p) == "`$q1` moves from `quick` to `standard`"
  a, p = TT.manifest_additions(old, replace(old, line(q1) => ""; count = 1), String[])
  @test a === nothing && only(p) == "`$q1` is removed from tier `quick`"
  renamed = add(replace(old, line(q1) => ""; count = 1), "quick", q1 * "_renamed")
  @test TT.manifest_additions(old, renamed, [q1 * "_renamed"])[2] == ["`$q1` is removed from tier `quick`"]
  changed_helpers=replace(old, """helpers = ["tiers"]""" => """helpers = ["tiers", "core_contracts"]""")
  @test changed_helpers!=old
  a,p=TT.manifest_additions(old,changed_helpers,String[])
  @test a===nothing
  changed_environments=replace(old,"environments = []"=>"""environments = ["new_env"]""")
  @test changed_environments!=old
  a,p=TT.manifest_additions(old,changed_environments,String[])
  @test a===nothing && occursin("outside [tiers]",only(p))
  a, p = TT.manifest_additions(old, "not toml [", String[])
  @test a === nothing && occursin("could not be compared", only(p))
  # the plan: additions give quick and run the new file; otherwise the tier lists need full
  mktempdir() do dir
    path = joinpath(dir, "tiers.toml")
    write(path, add(old, "full", "solver_new"))
    m = TT.load(path, RULES)
    paths = ["test/solver_new.jl", "test/tiers.toml"]
    @test TT.pr_tier(m, paths, String[]; manifest_additions = ["solver_new"])[1:2] == ("quick", ["solver_new"])
    @test TT.pr_tier(m, paths, String[])[1:2] == ("full", String[])
    @test TT.pr_tier(m, [paths; "src/cd/leastsquares.jl"], String[]; manifest_additions = ["solver_new"])[1:2] ==
          ("full", String[])
    @test TT.pr_tier(m, [paths; "src/cd/gap.jl"], String[]; manifest_additions = ["solver_new"])[1] == "full"
    # an unlisted test file still stops the plan
    @test_throws TT.ManifestError TT.check(m, [TT.discover(@__DIR__); "unlisted_new"])
  end
end

# The planner (scripts/ci_plan.jl) with a fake GitHub CLI. Pushes run full. The nightly run skips
# the full tier only after a successful non-PR full run on the same commit in the last 24 hours
# whose verdict and Linux full test job passed and which recorded the same resolved test
# environment and CI policy; an API failure, malformed answer or unknown record runs full.
module CIPlan
include(joinpath(dirname(@__DIR__), "scripts", "ci_plan.jl"))
end

const SHA = "a" ^ 40
const NOW = 1_800_000_000.0 # Unix time
# Run environment-record checks in a standard-library-only process: Pkg and SHA belong
# to the CI script, not to the package's runtime or test dependency declarations.
const POLICY_SCRIPT = raw"""
using Test
include(ARGS[1])
const CE = CIEnvironment
lines = ["julia 1.13.3", "ProximalBase uuid 0.6.0-DEV"]
mktempdir() do root
  for path in CE.POLICY_FILES
    target = joinpath(root, path)
    mkpath(dirname(target))
    cp(joinpath(CE.ROOT, path), target)
  end
  original = CE.environment_name(lines; channel="1", root)
  @test original == CE.environment_name(reverse(lines); channel="1", root)
  @test original != CE.environment_name([lines; "new dependency"]; channel="1", root)
  @test original != CE.environment_name(lines; channel="other", root)
  for path in CE.POLICY_FILES
    target = joinpath(root, path)
    content = replace(read(target, String), "\r\n" => "\n")
    write(target, content * "\n# changed policy\n")
    @test original != CE.environment_name(lines; channel="1", root)
    write(target, replace(content, "\n" => "\r\n"))
    @test original == CE.environment_name(lines; channel="1", root)
    write(target, content)
  end
  rm(joinpath(root, first(CE.POLICY_FILES)))
  @test_throws SystemError CE.environment_name(lines; channel="1", root)
end
print(CE.policy_digest())
"""
const POLICY = readchomp(addenv(`$(Base.julia_cmd()) --startup-file=no --project=@stdlib -e $POLICY_SCRIPT $(joinpath(dirname(@__DIR__), "scripts", "ci_environment.jl"))`,
                               "JULIA_LOAD_PATH" => "@stdlib"))
const ENVS = ["environment-1-$POLICY-fedcba9876543210"]
const PASSED = Dict(name => "success" for name in [CIPlan.VERDICT; CIPlan.FULL_JOBS; "Test plan"; "CI result"])
# A line of `gh run list` as recent_full_run asks for it: id, event, created (Unix time), conclusion, commit.
runline(id, event; hours = 2, conclusion = "success", sha = SHA) =
  join([id, event, string(NOW - hours * 3600), conclusion, sha], '\t')

# A fake `gh`: the run list, the jobs (name => conclusion) and artifact names of each run; `fail`
# makes every call throw, as the real CLI does on an API error. `calls` records the arguments.
function fakegh(runs, jobs = Dict{String, Dict{String, String}}(), artifacts = Dict{String, Vector{String}}();
                fail = false, calls = Vector{String}[])
  return function (args)
    push!(calls, String.(args))
    fail && error("gh: HTTP 502")
    args[1:2] == ["run", "list"] && return runs
    m = match(r"^repos/owner/name/actions/runs/(\d+)/(jobs|artifacts)", args[2])
    m === nothing && error("unexpected gh call: $args")
    id = m.captures[1]
    m.captures[2] == "jobs" && return ["$k\t$v" for (k, v) in get(() -> error("gh: run $id not found"), jobs, id)]
    return get(artifacts, id, String[])
  end
end

nightly(gh; envs = ENVS) =
  CIPlan.plan(Dict("event" => "schedule", "sha" => SHA, "repo" => "owner/name", "environments" => join(envs, ",")); gh, at = NOW)
nightly_tier(args...; kw...) = nightly(args...; kw...)[1].tier
single(id, event = "push"; jobs = PASSED, artifacts = ENVS, calls = Vector{String}[], kw...) =
  fakegh([runline(id, event; kw...)], Dict(id => jobs), Dict(id => artifacts); calls)

@testset "plan: pushes, manual runs and the nightly run" begin
  # a push to master or a release tag runs full, whatever changed
  @test CIPlan.plan(Dict("event" => "push"))[1] == (; tier = "full", focus = "", run_tests = true, timeout = 60)
  @test CIPlan.plan(Dict("event" => "workflow_dispatch", "tier" => "quick"))[1].tier == "quick"
  @test CIPlan.plan(Dict("event" => "workflow_dispatch"))[1].tier == "full"
  @test_throws ErrorException CIPlan.plan(Dict("event" => "workflow_dispatch", "tier" => "thorough"))
  @test_throws ErrorException CIPlan.plan(Dict("event" => "release"))
  @test_throws ErrorException CIPlan.options(["--labels"])
  @test_throws ErrorException CIPlan.options(["--color=yes"])
  # no earlier run: full
  @test nightly_tier(fakegh(String[])) == "full"
  # a verified full run on this commit, from the nightly, a push or a manual run: skip
  for event in ("schedule", "push", "workflow_dispatch")
    result, lines = nightly(single("11", event))
    @test result == (; tier = "none", focus = "", run_tests = false, timeout = 0)
    @test any(occursin("Run 11 passed the full tier on this commit", l) for l in lines)
  end
  # the first qualifying run decides; others before it are passed over
  runs = [runline("12", "pull_request"), runline("13", "schedule"; conclusion = "failure"), runline("14", "push")]
  @test nightly_tier(fakegh(runs, Dict("14" => PASSED), Dict("14" => ENVS))) == "none"
  # a run of a smaller tier, or one whose full job is missing, failed, cancelled or re-run and failed
  quick = Dict(name => "success" for name in [CIPlan.VERDICT; "Julia 1 - ubuntu-latest - x64 - quick"])
  @test nightly_tier(single("21"; jobs = quick)) == "full"
  for name in CIPlan.FULL_JOBS, c in ("failure", "cancelled", "skipped", "")
    @test nightly_tier(single("22"; jobs = merge(PASSED, Dict(name => c)))) == "full"
  end
  @test CIPlan.FULL_JOBS == ["Julia 1 - ubuntu-latest - x64 - full"]
  @test nightly_tier(single("23"; jobs = delete!(copy(PASSED), only(CIPlan.FULL_JOBS)))) == "full"
  @test nightly_tier(single("24"; jobs = merge(PASSED, Dict(CIPlan.VERDICT => "failure")))) == "full"
  # the verdict of a pull request run has another name and does not count
  @test nightly_tier(single("25"; jobs = merge(delete!(copy(PASSED), CIPlan.VERDICT), Dict("PR required jobs" => "success")))) == "full"
  # other dependencies: no record, a record of one version only, or other digests
  @test nightly_tier(single("31"; artifacts = String[])) == "full"
  @test nightly_tier(single("32"; artifacts = ["environment-1-1111111111111111"])) == "full"
  @test nightly_tier(single("33"; artifacts = ["environment-1.10-0123456789abcdef"])) == "full"
  # An older workflow (including a re-run of its checkout) has a different policy
  # artifact even if its dependency versions, commit and all latest jobs match.
  @test nightly_tier(single("36"; artifacts = ["environment-1-fedcba9876543210"])) == "full"
  @test nightly_tier(single("37"; artifacts = ["environment-1-oldpolicy-fedcba9876543210"])) == "full"
  @test nightly_tier(single("38"; jobs = merge(PASSED, Dict("Julia 1 - macos-latest - aarch64 - full" => "failure")))) == "full"
  duplicate = function (args)
    occursin("/jobs?", args[2]) && return [["$k\t$v" for (k, v) in PASSED]; "$(only(CIPlan.FULL_JOBS))\tfailure"]
    return single("39")(args)
  end
  @test nightly_tier(duplicate) == "full"
  result, lines = nightly(single("34"; artifacts = ["environment-1-0000000000000000"]))
  @test result.tier == "full" && any(occursin("run 34 tested other dependencies", l) for l in lines)
  # the nightly run could not resolve its own environments: full, and nothing is asked
  calls = Vector{String}[]
  result, lines = nightly(single("35"; calls); envs = String[])
  @test result.tier == "full" && any(occursin("environments of this run are unknown", l) for l in lines)
  # another commit (the CLI is asked for this commit, but the answer is checked)
  @test nightly_tier(single("41"; sha = "b" ^ 40)) == "full"
  # older than 24 hours, or created after the plan's time: full; just inside the window: skip
  @test nightly_tier(single("42"; hours = 25)) == "full"
  @test nightly_tier(single("43"; hours = -1)) == "full"
  @test nightly_tier(single("44"; hours = 23.9)) == "none"
  # a failed, cancelled or unfinished run, or a pull request run on the same commit
  for conclusion in ("failure", "cancelled", "timed_out", "")
    @test nightly_tier(single("51"; conclusion)) == "full"
  end
  @test nightly_tier(single("52", "pull_request")) == "full"
  # only push, schedule and manual runs count (an allowlist, not "anything but a PR")
  @test nightly_tier(single("53", "workflow_run")) == "full" && nightly_tier(single("54", "merge_group")) == "full"
  # the API fails or answers something else: full, and the plan says why
  result, lines = nightly(fakegh(String[]; fail = true))
  @test result.tier == "full" && any(occursin("could not check for an earlier full run", l) for l in lines)
  for bad in (["11\tschedule\tsuccess"], ["11\tschedule\tyesterday\tsuccess\t$SHA"], ["garbage"])
    @test nightly_tier(fakegh(bad, Dict("11" => PASSED), Dict("11" => ENVS))) == "full"
  end
  @test nightly_tier(fakegh([runline("61", "schedule")])) == "full" # its jobs cannot be listed
  @test nightly_tier(fakegh([runline("62", "schedule")], Dict("62" => Dict("bad\tline\twith tabs" => "x")))) == "full"
  # the CLI is asked for this workflow's successful runs on this commit, then the run's latest jobs
  calls = Vector{String}[]
  nightly(single("81", "schedule"; calls))
  list = first(calls)
  @test list[1:2] == ["run", "list"] &&
        all(in(list), ["--repo", "owner/name", "--workflow", "CI.yml", "--commit", SHA, "--status", "success"])
  @test calls[2][2] == "repos/owner/name/actions/runs/81/jobs?filter=latest&per_page=100"
  @test calls[3][2] == "repos/owner/name/actions/runs/81/artifacts?per_page=100"
  # without the commit and repository the nightly plan runs full and asks nothing
  calls = Vector{String}[]
  @test CIPlan.plan(Dict("event" => "schedule"); gh = fakegh(String[]; calls))[1].tier == "full" && isempty(calls)
end

end
