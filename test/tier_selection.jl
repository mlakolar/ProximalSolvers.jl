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
  @test sort(m.helpers) == ["symmetric_penalty_helpers", "tiers"]
  @test m.environments == ["oracles"]
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
  # documentation and what the package tests do not use: no package tests
  @test classify("docs/src/index.md", "CONTRIBUTING.md", "README.md", "test/TESTING.md") == ("none", String[])
  @test classify("docs/make.jl", "docs/Project.toml", "LICENSE", "codecov.yml") == ("none", String[])
  @test classify("benchmark/run.jl", "benchmark/check_analysis.py", "test/oracles/runtests.jl") == ("none", String[])
  @test classify("scripts/check_naming.py", ".github/workflows/Documentation.yml") == ("none", String[])
  # a changed test file runs beside quick
  @test classify("test/glm.jl") == ("quick", ["glm"])
  @test classify("test/glm.jl", "test/prox_solvers.jl") == ("quick", ["glm", "prox_solvers"])
  @test classify("test/symmetric_penalty_helpers.jl") ==
        ("quick", ["symmetric_penalties", "symmetric_penalties_basics", "symmetric_penalty_combinations"])
  @test classify("examples/01_lasso.jl") == ("quick", ["examples"])
  @test classify("examples/README.md") == ("none", String[])
  # a deleted or renamed test file is no focus file; the runner rejects an unlisted one
  @test classify("test/removed_file.jl") == ("quick", String[])
  # localized solver code: standard and the full-only files that exercise it
  @test classify("src/solvers/admm.jl") == ("standard", ["examples"])
  @test classify("src/cd/leastsquares.jl", "test/glm.jl") == ("standard", ["examples", "float32_certificates", "glm"])
  @test classify("src/cd/quic.jl") == ("standard", ["symmetric_penalty_combinations"])
  @test classify("src/solvers/slope.jl") == ("standard", ["mixed_precision_extended"])
  @test classify("src/cd/multiresponse.jl") == ("standard", String[])
  # shared architecture, convergence and certification semantics: full
  for path in ("src/ProximalSolvers.jl", "src/types.jl", "src/solve.jl", "src/blocks.jl", "src/line_searches.jl",
               "src/workspaces.jl", "src/precompile.jl", "src/cd/models.jl", "src/cd/solver.jl",
               "src/utils.jl", "src/cd/gap.jl", "src/cd/sqrtdual.jl", "src/cd/path.jl")
    @test classify(path)[1] == "full"
  end
  # CI infrastructure, dependencies, the tier lists and paths no rule knows: full
  for path in (".github/workflows/CI.yml", ".github/tier-rules.toml", "Project.toml", "scripts/ci_plan.jl",
               "scripts/ci_gate.jl", "scripts/ci_verdict.jl", "scripts/ci_environment.jl", "scripts/test.jl",
               "scripts/test_report.jl", "test/runtests.jl", "test/tiers.jl", "test/tiers.toml",
               "Manifest.toml", "a/new/file.txt", ".github/workflows/New.yml", "ext/SomeExt.jl")
    @test classify(path)[1] == "full"
  end
  # the highest tier of the changed paths decides
  @test classify("docs/src/index.md", "test/glm.jl", "src/cd/glm.jl")[1] == "standard"
  @test classify("test/glm.jl", "src/cd/glm.jl", "Project.toml")[1] == "full"
  # focus files leave out what the tier runs anyway
  @test pr("src/cd/glm.jl", "test/glm.jl") == ("standard", ["examples", "float32_certificates"])
  @test pr("test/examples.jl") == ("quick", ["examples"])
  @test pr("src/types.jl", "test/glm.jl") == ("full", String[])
  # no changed files: quick
  @test pr() == ("quick", String[])
end

@testset "every rule decides the paths it names, and they exist" begin
  for rule in CI.rules, pattern in rule.patterns
    occursin('*', pattern) && continue
    @test isfile(joinpath(ROOT, pattern))
    i = findfirst(r -> any(re -> occursin(re, pattern), r.regexes), CI.rules)
    @test CI.rules[i] === rule
  end
  # every source file has a rule written for the package code, never the fallback for unknown paths
  for (dir, _, files) in walkdir(joinpath(ROOT, "src")), file in files
    path = replace(relpath(joinpath(dir, file), ROOT), '\\' => '/')
    t, = classify(path)
    @test t in ("standard", "full")
    @test TT.classify(CI, [path])[3][1][3] != "no rule matches this path"
  end
  # the focus files of a solver rule are full-only files: standard runs the others anyway
  for rule in CI.rules, name in rule.focus
    rule.tier == "standard" && @test CI.tier[name] == "full"
  end
  @test sort(collect(keys(CI.timeouts))) == sort(collect(TIERS))
end

@testset "labels only raise the tier" begin
  @test pr("test/glm.jl"; labels = ["test:standard"]) == ("standard", String[])
  @test pr("test/glm.jl"; labels = ["test:full"]) == ("full", String[])
  @test pr("test/glm.jl"; labels = ["test:standard", "test:full", "bug"]) == ("full", String[])
  @test pr("docs/src/index.md"; labels = ["test:standard"]) == ("standard", String[])
  @test pr("docs/src/index.md"; labels = ["documentation"]) == ("none", String[])
  # a label below the path tier changes nothing
  @test pr("src/types.jl"; labels = ["test:standard"]) == ("full", String[])
  @test pr("src/cd/quic.jl"; labels = ["test:standard"]) == ("standard", ["symmetric_penalty_combinations"])
  # the focus files of a raised tier leave out what it runs
  @test pr("src/cd/quic.jl"; labels = ["test:full"]) == ("full", String[])
  # a test: label that names no tier above quick stops the plan
  @test_throws ArgumentError pr("test/glm.jl"; labels = ["test:quick"])
  @test_throws ArgumentError pr("test/glm.jl"; labels = ["test:thorough"])
  notes = TT.pr_tier(CI, ["test/glm.jl"], ["test:full"])[4]
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
  @test TT.manifest_additions(old, replace(old, "# ADMM and primal-dual splitting" => "# ADMM, primal-dual"), String[]) ==
        (String[], String[])
  swapped = replace(old, "  \"aqua\",\n  \"ci_gate\",\n" => "  \"ci_gate\",\n  \"aqua\",\n")
  @test swapped != old && TT.manifest_additions(old, swapped, String[]) == (String[], String[])
  # anything else needs full
  a, p = TT.manifest_additions(old, add(old, "quick", "solver_new"), String[])
  @test a === nothing && occursin("not a new file of this change", only(p))
  moved = add(replace(old, "  \"workspaces\",\n" => ""; count = 1), "standard", "workspaces")
  a, p = TT.manifest_additions(old, moved, String[])
  @test a === nothing && only(p) == "`workspaces` moves from `quick` to `standard`"
  a, p = TT.manifest_additions(old, replace(old, "  \"workspaces\",\n" => ""; count = 1), String[])
  @test a === nothing && only(p) == "`workspaces` is removed from tier `quick`"
  renamed = add(replace(old, "  \"workspaces\",\n" => ""; count = 1), "quick", "workspaces2")
  @test TT.manifest_additions(old, renamed, ["workspaces2"])[2] == ["`workspaces` is removed from tier `quick`"]
  a, p = TT.manifest_additions(old, replace(old, "\"symmetric_penalty_helpers\", \"tiers\"]" =>
                                                 "\"symmetric_penalty_helpers\", \"tiers\", \"glm\"]"), String[])
  @test a === nothing # a test file moved into the helpers stops running: problems either way
  a, p = TT.manifest_additions(old, replace(old, "environments = [\"oracles\"]" => "environments = []"), String[])
  @test a === nothing && occursin("outside [tiers]", only(p))
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
    @test TT.pr_tier(m, [paths; "src/cd/glm.jl"], String[]; manifest_additions = ["solver_new"])[1:2] ==
          ("standard", ["examples", "float32_certificates", "solver_new"])
    @test TT.pr_tier(m, [paths; "src/cd/gap.jl"], String[]; manifest_additions = ["solver_new"])[1] == "full"
    # an unlisted test file still stops the plan
    @test_throws TT.ManifestError TT.check(m, [TT.discover(@__DIR__); "unlisted_new"])
  end
end

# The planner (scripts/ci_plan.jl) with a fake GitHub CLI. Pushes run full. The nightly run skips
# the full tier only after a successful non-PR full run on the same commit in the last 24 hours
# whose verdict and four full test jobs passed and which recorded the same resolved test
# environments; an API failure, a malformed answer or an unknown environment runs full.
module CIPlan
include(joinpath(dirname(@__DIR__), "scripts", "ci_plan.jl"))
end

const SHA = "a" ^ 40
const NOW = 1_800_000_000.0 # Unix time
const ENVS = ["environment-1.10-0123456789abcdef", "environment-1-fedcba9876543210"]
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
  quick = Dict(name => "success" for name in [CIPlan.VERDICT; "Julia 1.10 - ubuntu-latest - x64 - quick"])
  @test nightly_tier(single("21"; jobs = quick)) == "full"
  for name in CIPlan.FULL_JOBS, c in ("failure", "cancelled", "skipped", "")
    @test nightly_tier(single("22"; jobs = merge(PASSED, Dict(name => c)))) == "full"
  end
  @test nightly_tier(single("23"; jobs = delete!(copy(PASSED), "Julia 1 - windows-latest - x64 - full"))) == "full"
  @test nightly_tier(single("24"; jobs = merge(PASSED, Dict(CIPlan.VERDICT => "failure")))) == "full"
  # the verdict of a pull request run has another name and does not count
  @test nightly_tier(single("25"; jobs = merge(delete!(copy(PASSED), CIPlan.VERDICT), Dict("PR required jobs" => "success")))) == "full"
  # other dependencies: no record, a record of one version only, or other digests
  @test nightly_tier(single("31"; artifacts = String[])) == "full"
  @test nightly_tier(single("32"; artifacts = ENVS[1:1])) == "full"
  @test nightly_tier(single("33"; artifacts = ["environment-1.10-0000000000000000", ENVS[2]])) == "full"
  result, lines = nightly(single("34"; artifacts = ENVS[2:2]))
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
