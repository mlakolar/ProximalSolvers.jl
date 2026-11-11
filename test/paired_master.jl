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
  workflow = read(joinpath(PM.ROOT, ".github", "workflows", "CI.yml"), String)
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
end
"""

@testset "always-run paired-master policy controls" begin
  script = joinpath(dirname(@__DIR__), "scripts", "paired_master_diagnostics.jl")
  command = `$(Base.julia_cmd()) --startup-file=no --project=@stdlib -e $CONTROLS $script`
  @test success(pipeline(addenv(command, "JULIA_LOAD_PATH" => "@stdlib"); stdout = stdout, stderr = stderr))
end

end
