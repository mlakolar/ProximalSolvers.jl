module AquaTest

using Test
using TOML
using ProximalSolvers
using Aqua

@testset "Aqua" begin
  Aqua.test_all(ProximalSolvers)
end

# The ProximalBase pin has two homes. Julia 1.11 and later read `[sources]` in Project.toml;
# Julia 1.10 ignores `[sources]` and uses the tracked Manifest-v1.10.toml, so Julia 1 runs
# do not notice a stale manifest. This test compares the two before the Nightly workflow's
# 1.10 run could show the difference.
#
# PIN_POLICY names the rule pin_problems checks: while `[sources]` exists, the manifest must
# carry the same revision and URL. If `[sources]` is removed, pin_problems reports a problem
# until this policy and the function are changed on purpose; a pin that is merely absent does
# not pass.
const PIN_POLICY = :sources_match_manifest_v1_10

const FULL_SHA = r"^[0-9a-f]{40}$"

"""
    pin_problems(project, manifest) -> Vector{String}

Problems found when `project` (parsed Project.toml) and `manifest` (parsed
Manifest-v1.10.toml) are compared under `PIN_POLICY`; empty when the ProximalBase pins agree.
Revisions and URLs are compared as written.
"""
function pin_problems(project::AbstractDict, manifest::AbstractDict)
  problems = String[]
  sources = get(project, "sources", nothing)
  entry = sources isa AbstractDict ? get(sources, "ProximalBase", nothing) : nothing
  if !(entry isa AbstractDict)
    push!(problems, "Project.toml has no [sources] entry for ProximalBase. The pin-validation " *
                    "policy must be updated explicitly (PIN_POLICY and pin_problems in test/aqua.jl).")
    return problems
  end
  url = get(entry, "url", nothing)
  rev = get(entry, "rev", nothing)
  url isa AbstractString || push!(problems, "[sources] ProximalBase has no string `url`.")
  if !(rev isa AbstractString)
    push!(problems, "[sources] ProximalBase has no string `rev`.")
  elseif !occursin(FULL_SHA, rev)
    push!(problems, "[sources] ProximalBase rev `$rev` is not a full 40-character lowercase hex SHA.")
  end

  deps = get(manifest, "deps", nothing)
  entries = deps isa AbstractDict ? get(deps, "ProximalBase", nothing) : nothing
  if !(entries isa AbstractVector) || length(entries) != 1 || !(only(entries) isa AbstractDict)
    push!(problems, "Manifest-v1.10.toml must have exactly one deps.ProximalBase entry.")
    return problems
  end
  pinned = only(entries)
  repo_rev = get(pinned, "repo-rev", nothing)
  repo_url = get(pinned, "repo-url", nothing)
  if !(repo_rev isa AbstractString) || !(repo_url isa AbstractString)
    push!(problems, "Manifest-v1.10.toml deps.ProximalBase has no repo-rev and repo-url " *
                    "(a registered version, not the pinned source).")
  else
    repo_rev == rev || push!(problems, "Manifest repo-rev `$repo_rev` differs from [sources] rev `$rev`.")
    repo_url == url || push!(problems, "Manifest repo-url `$repo_url` differs from [sources] url `$url`.")
  end

  project_deps = get(project, "deps", nothing)
  project_uuid = project_deps isa AbstractDict ? get(project_deps, "ProximalBase", nothing) : nothing
  manifest_uuid = get(pinned, "uuid", nothing)
  if manifest_uuid != project_uuid
    push!(problems, "Manifest uuid `$manifest_uuid` differs from the [deps] uuid `$project_uuid` " *
                    "of ProximalBase in Project.toml.")
  end
  return problems
end

@testset "ProximalBase pin: Julia 1.10 manifest agrees with [sources]" begin
  # dirname(@__DIR__): the test files run in place under Pkg.test, as test/ci_gate.jl assumes
  root = dirname(@__DIR__)
  project = TOML.parsefile(joinpath(root, "Project.toml"))
  manifest = TOML.parsefile(joinpath(root, "Manifest-v1.10.toml"))

  # compared with an empty list, not `isempty`, so that a failure shows the problems
  @test pin_problems(project, manifest) == String[]

  # each case below changes one field of copies of the real files
  function problems_after(change!)
    p, m = deepcopy(project), deepcopy(manifest)
    change!(p, m)
    return pin_problems(p, m)
  end
  pinned(m) = only(m["deps"]["ProximalBase"])
  flipped(rev) = string(rev[1] == '0' ? '1' : '0', rev[2:end])

  problems = problems_after((p, m) -> delete!(p, "sources"))
  @test length(problems) == 1 && occursin("PIN_POLICY", only(problems))
  problems = problems_after((p, m) -> delete!(p["sources"], "ProximalBase"))
  @test length(problems) == 1 && occursin("PIN_POLICY", only(problems))

  problems = problems_after((p, m) -> p["sources"]["ProximalBase"]["rev"] = "master")
  @test any(occursin("40-character", s) for s in problems)
  problems = problems_after((p, m) -> p["sources"]["ProximalBase"]["rev"] = uppercase(p["sources"]["ProximalBase"]["rev"]))
  @test any(occursin("40-character", s) for s in problems)
  problems = problems_after((p, m) -> delete!(p["sources"]["ProximalBase"], "url"))
  @test any(occursin("`url`", s) for s in problems)

  problems = problems_after((p, m) -> pinned(m)["repo-rev"] = flipped(pinned(m)["repo-rev"]))
  @test any(occursin("repo-rev", s) for s in problems)
  problems = problems_after((p, m) -> pinned(m)["repo-url"] *= ".git")
  @test any(occursin("repo-url", s) for s in problems)

  problems = problems_after((p, m) -> delete!(m["deps"], "ProximalBase"))
  @test any(occursin("exactly one", s) for s in problems)
  problems = problems_after((p, m) -> push!(m["deps"]["ProximalBase"], copy(pinned(m))))
  @test any(occursin("exactly one", s) for s in problems)
  problems = problems_after((p, m) -> delete!(pinned(m), "repo-rev"))
  @test any(occursin("no repo-rev", s) for s in problems)
  problems = problems_after((p, m) -> pinned(m)["uuid"] = "00000000-0000-0000-0000-000000000000")
  @test any(occursin("uuid", s) for s in problems)
end

end
