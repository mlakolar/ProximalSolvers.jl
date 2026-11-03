# Test tiers: which test files a tier runs (test/tiers.toml), adapted from ProximalBase.jl.
# test/runtests.jl uses this module to select files, and test/tier_selection.jl tests it.

module TestTiers

import TOML

export TIERS

# Each tier runs its own files and the files of every tier before it.
const TIERS = ("quick", "standard", "full")

rank(tier::AbstractString) = something(findfirst(==(tier), TIERS), 0)

"""
    Manifest

The parsed tiers.toml: the lowest tier of each test file, the helper files that are not tests,
and the directories with environments of their own.
"""
struct Manifest
  tier::Dict{String, String}
  helpers::Vector{String}
  environments::Vector{String}
end

struct ManifestError <: Exception
  problems::Vector{String}
end

function Base.showerror(io::IO, e::ManifestError)
  print(io, "test/tiers.toml has problems:")
  foreach(p -> print(io, "\n  - ", p), e.problems)
end

load(path::AbstractString) = parse_manifest(TOML.parsefile(path))
parse_manifest(text::AbstractString) = parse_manifest(TOML.parse(text))

function parse_manifest(data::AbstractDict)
  problems = String[]
  tier = Dict{String, String}()
  tables = get(data, "tiers", Dict{String, Any}())
  for name in keys(tables)
    name in TIERS || push!(problems, "unknown tier `$name` in [tiers]; the tiers are $(join(TIERS, ", "))")
  end
  for t in TIERS
    files = get(tables, t, String[])
    isempty(files) && push!(problems, "tier `$t` lists no test files")
    for file in files
      if haskey(tier, file)
        push!(problems, "`$file` is listed in both `$(tier[file])` and `$t`")
      else
        tier[file] = t
      end
    end
  end
  other = get(data, "not_tests", Dict{String, Any}())
  helpers = String[get(other, "helpers", String[])...]
  environments = String[get(other, "environments", String[])...]
  for file in helpers
    haskey(tier, file) && push!(problems, "`$file` is both a helper and in tier `$(tier[file])`")
  end
  isempty(problems) || throw(ManifestError(problems))
  return Manifest(tier, helpers, environments)
end

isenvironment(m::Manifest, name) = any(dir -> startswith(name, dir * "/"), m.environments)

"""
    check(manifest, discovered)

Check the manifest against the test file names found on disk (as ParallelTestRunner's
`find_tests` names them): every file has a tier, is a helper, or lies in an environment
directory, and every name in the manifest exists. Throws a `ManifestError` listing every
problem.
"""
function check(m::Manifest, discovered)
  found = Set{String}(discovered)
  problems = String[]
  for name in sort!(collect(found))
    haskey(m.tier, name) || name in m.helpers || isenvironment(m, name) ||
      push!(problems, "`test/$name.jl` has no tier: add it to one tier in test/tiers.toml")
  end
  for name in sort!(collect(keys(m.tier)))
    name in found || push!(problems, "`$name` is in tier `$(m.tier[name])`, but test/$name.jl does not exist")
  end
  for name in m.helpers
    name in found || push!(problems, "helper `$name` does not exist")
  end
  isempty(problems) || throw(ManifestError(problems))
  return nothing
end

"""
    select(manifest, tier) -> Vector{String}

The test files that `tier` runs, sorted: every file whose lowest tier is `tier` or lower.
"""
function select(m::Manifest, tier::AbstractString)
  r = rank(tier)
  r > 0 || throw(ArgumentError("unknown test tier `$tier`; the tiers are $(join(TIERS, ", "))"))
  return sort!([name for (name, t) in m.tier if rank(t) <= r])
end

end
