# The Julia and package versions that a test run of this checkout resolves to, as a digest.
#
#   julia --startup-file=no scripts/ci_environment.jl
#
# Resolves, in a temporary environment, this package (developed from the checkout) with its
# test dependencies, without precompiling, and prints the Julia version and every resolved
# package version, then `name=environment-<julia>-<policy>-<digest>` (also to $GITHUB_OUTPUT),
# where <julia> is $JULIA_CHANNEL (the CI matrix version) or the running version. Full runs that
# are not for a pull request record that name as an artifact; a scheduled run computes it again
# and skips the full tier only if an earlier passing full run on the same commit recorded the
# same names (scripts/ci_plan.jl). The policy digest prevents evidence from an older CI
# configuration, including a re-run of that checkout, from standing in for the new policy.
# Only the standard libraries are needed.

module CIEnvironment

using Pkg, SHA, TOML

const ROOT = dirname(@__DIR__)

const POLICY_FILES = (".github/workflows/CI.yml", "scripts/ci_plan.jl",
                      "scripts/ci_verdict.jl", "scripts/ci_gate.jl", "scripts/ci_environment.jl")

function policy_digest(root = ROOT)
  # Normalize checkout line endings; the policy must have the same identity on every host.
  contents = [path * "\n" * replace(read(joinpath(root, path), String), "\r\n" => "\n") for path in POLICY_FILES]
  return bytes2hex(sha256(join(contents, '\0')))[1:16]
end

function environment_name(lines; channel = get(ENV, "JULIA_CHANNEL", string(VERSION)), root = ROOT)
  digest = bytes2hex(sha256(join(sort(lines), '\n')))[1:16]
  return "environment-$channel-$(policy_digest(root))-$digest"
end

function resolved_lines()
  project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
  # The test extras with the package's [compat] bounds, as Pkg.test's sandbox applies them.
  compat = get(project, "compat", Dict{String, Any}())
  extras = [Pkg.PackageSpec(; name, uuid = Base.UUID(project["extras"][name]),
                            version = haskey(compat, name) ? Pkg.Types.semver_spec(compat[name]) : Pkg.Types.VersionSpec())
            for name in project["targets"]["test"]]
  withenv("JULIA_PKG_PRECOMPILE_AUTO" => "0") do
    Pkg.activate(; temp = true, io = devnull)
    Pkg.develop(Pkg.PackageSpec(; path = ROOT); io = devnull)
    Pkg.add(extras; io = devnull)
  end
  lines = ["julia $(VERSION)"]
  for (uuid, info) in Pkg.dependencies()
    info.name == project["name"] && continue
    push!(lines, "$(info.name) $(uuid) $(info.version)")
  end
  return sort!(lines)
end

function main()
  lines = resolved_lines()
  name = environment_name(lines)
  foreach(println, lines)
  println("name=", name)
  haskey(ENV, "GITHUB_OUTPUT") && open(io -> println(io, "name=", name), ENV["GITHUB_OUTPUT"], "a")
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
  CIEnvironment.main()
end
