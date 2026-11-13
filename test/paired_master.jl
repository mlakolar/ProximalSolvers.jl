module PairedMasterTests

using Test

# Keep Pkg/SHA in a standalone standard-library process, rather than expanding
# the package/test dependency surface just for CI's exact-source control.
const CONTROLS = raw"""
using Test, TOML
include(ARGS[1])
const PM = PairedMasterDiagnostics
@testset "paired controls: exact source and fail-closed records" begin
  @test PM.exact_sha(PM.PB_A, "baseline") == PM.PB_A
  for invalid in ("master", "0.6", PM.PB_A[1:12], uppercase(PM.PB_A), nothing)
    @test_throws ArgumentError PM.exact_sha(invalid, "revision")
  end
  records = Dict(key => Dict("value" => "unchanged") for key in PM.expected_record_keys())
  document = Dict("format" => 1, "records" => records)
  @test length(PM.expected_record_keys()) == 288
  @test PM.compare_records(document, deepcopy(document)) == 288
  missing = deepcopy(document)
  delete!(missing["records"], first(PM.expected_record_keys()))
  @test_throws ErrorException PM.compare_records(document, missing)
  changed = deepcopy(document)
  changed["records"][first(PM.expected_record_keys())]["value"] = "changed"
  @test_throws ErrorException PM.compare_records(document, changed)
  @test_throws ErrorException PM.checked_records(Dict("format" => 2, "records" => records))
  @test_throws ErrorException PM.checked_records(Dict("format" => 1, "records" => Dict()))
  mktempdir() do root
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Fixture.jl"), "module Fixture\nend\n")
    open(joinpath(root, "Project.toml"), "w") do io
      TOML.print(io, Dict("sources" => Dict("ProximalBase" => Dict("url" => PM.PB_URL, "rev" => PM.PB_A))))
    end
    @test PM.pinned_revision(root) == PM.PB_A
    run(`git init --quiet $root`)
    run(`git -C $root add .`)
    run(`git -C $root -c user.name=Fixture -c user.email=fixture@example.invalid commit --quiet -m fixture`)
    sha = readchomp(`git -C $root rev-parse HEAD`)
    identity = PM.checkout_identity(root, sha)
    @test identity["commit"] == sha
    @test length(identity["source_sha256"]) == 64
    @test_throws ErrorException PM.checkout_identity(root, "0000000000000000000000000000000000000000")
    @test_throws ErrorException PM.checkout_identity(root, sha; digest = repeat("0", 64))
    open(io -> println(io, "# source changed"), joinpath(root, "src", "Fixture.jl"), "a")
    @test PM.source_digest(root) != identity["source_sha256"]
    @test_throws ErrorException PM.checkout_identity(root, sha)
  end
end
@testset "paired controls: always-run gated Linux job" begin
  workflow = replace(read(joinpath(PM.ROOT, ".github", "workflows", "CI.yml"), String), "\r\n" => "\n")
  analysis = split(split(workflow, "  analysis:\n"; limit = 2)[2], "  verdict:\n"; limit = 2)[1]
  @test occursin("name: Benchmark analysis controls", analysis)
  @test occursin("runs-on: ubuntu-latest", analysis)
  @test occursin("julia-actions/setup-julia@v3", analysis)
  @test occursin("version: '1'", analysis)
  @test occursin("arch: x64", analysis)
  @test occursin("--project=@stdlib scripts/paired_master_diagnostics.jl", analysis)
  @test occursin("python benchmark/check_analysis.py", analysis)
  @test !occursin(r"(?m)^\s*if:", analysis)
  @test !occursin("continue-on-error", analysis)
  @test occursin("needs: [plan, test, analysis]", workflow)
  @test occursin("fail-fast: false", analysis)
  @test occursin("part: [comparator, campaign, controls]", analysis)
  @test occursin("name: Benchmark analysis controls (\${{ matrix.part }})", analysis)
  # Per-step structure of the dispatch steps. Each table row names a step, its owner leg and the
  # commands that the owner arm of the step's `case` must contain; the other two legs must share a
  # no-op arm and any other leg name must reach an error arm. The step text is split at the list-item
  # marker of the steps, and the arms at the arm terminator, which no command in these steps contains.
  # A new dispatch step must be added to the table, because the number of steps with a `case` on the
  # part name is compared with the table size. The quote character is built with a char literal
  # because this script text is a raw string.
  dq = string('"')
  dispatch = string("case ", dq, "\$PART", dq, " in")
  legs = ("comparator", "campaign", "controls")
  unittest_steps = (
    "Stage 2B migration comparator tests",
    "Stage 2B file and fixture tests",
    "Stage 2B campaign-driver tests (including pinned-commit fingerprints)",
    "Stage 2B reset-probe checker tests",
  )
  table = [
    ("Check repository hygiene (required through analysis verdict)", "controls",
      ["python3 scripts/test_repo_hygiene.py", "python3 scripts/check_repo_hygiene.py --base 'HEAD^1'"]),
    ("Check the benchmark analysis", "controls", ["python benchmark/check_analysis.py"]),
    ("Check the sparse coordinate descent analysis", "controls",
      ["python -I benchmark/sparse_cd/check_analysis.py"]),
    ("Check the coordinatedescent comparison analysis", "controls",
      ["python -B benchmark/external/coordinatedescent/check_analysis.py"]),
    ("Pinned Stage 2B commits are in the checkout", "campaign",
      ["benchmark/campaigns/stage2b/test_stage2b_campaign.py", "git cat-file -e"]),
    ("Stage 2B migration comparator tests", "comparator",
      ["python3 -B benchmark/campaigns/stage2b/test_migration_compare.py"]),
    ("Stage 2B file and fixture tests", "controls",
      ["python3 -B benchmark/campaigns/stage2b/test_stage2b_files.py"]),
    ("Stage 2B campaign-driver tests (including pinned-commit fingerprints)", "campaign",
      ["python3 -B benchmark/campaigns/stage2b/test_stage2b_campaign.py"]),
    ("Stage 2B reset-probe checker tests", "controls",
      ["python3 -B benchmark/campaigns/stage2b/probes/test_check_reset_probes.py"]),
    ("Exact-source paired-master diagnostics", "controls",
      ["julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl"]),
  ]
  steps = split(analysis, "\n      - ")
  @test count(step -> occursin(dispatch, step), steps) == length(table)
  for (name, owner, commands) in table
    matching = [step for step in steps if startswith(step, string("name: ", name, "\n"))]
    @test length(matching) == 1
    isempty(matching) && continue
    step = first(matching)
    @test occursin(dispatch, step)
    arms = [strip(arm) for arm in split(last(split(step, dispatch; limit = 2)), ";;")]
    own = join(filter(arm -> startswith(arm, string(owner, ")")), arms), "\n")
    @test length(filter(arm -> startswith(arm, string(owner, ")")), arms)) == 1
    for command in commands
      @test occursin(command, own)
    end
    if name in unittest_steps
      @test occursin("skipped=", own)
      @test occursin("Ran [1-9][0-9]* tests? in", own)
      @test occursin("grep -qx 'OK'", own)
    end
    others = setdiff(legs, (owner,))
    noop_prefixes = (string(others[1], "|", others[2], ")"), string(others[2], "|", others[1], ")"))
    noop = filter(arm -> any(prefix -> startswith(arm, prefix), noop_prefixes), arms)
    @test length(noop) == 1
    @test occursin("Not part of the", join(noop, "\n"))
    fallback = filter(arm -> startswith(arm, "*)"), arms)
    @test length(fallback) == 1
    @test occursin("::error::Unknown analysis leg", join(fallback, "\n"))
    @test occursin("exit 1", join(fallback, "\n"))
  end
end
"""

@testset "always-run paired-master policy controls" begin
  script = joinpath(dirname(@__DIR__), "scripts", "paired_master_diagnostics.jl")
  command = `$(Base.julia_cmd()) --startup-file=no --project=@stdlib -e $CONTROLS $script`
  @test success(pipeline(addenv(command, "JULIA_LOAD_PATH" => "@stdlib"); stdout = stdout, stderr = stderr))
end

end
