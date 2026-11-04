# The Julia and package versions that a test run of this checkout resolves to, as a digest.
#
#   julia --startup-file=no scripts/ci_environment.jl
#
# Resolves, in a temporary environment, this package (developed from the checkout) with its
# test dependencies, without precompiling, and prints the Julia version and every resolved
# package version, then `name=environment-<julia>-<digest>` (also to $GITHUB_OUTPUT when set),
# where <julia> is $JULIA_CHANNEL (the CI matrix version) or the running version. Full runs that
# are not for a pull request record that name as an artifact; a scheduled run computes it again
# and skips the full tier only if an earlier passing full run on the same commit recorded the
# same names (scripts/ci_plan.jl). Only the standard libraries are needed.

using Pkg, SHA, TOML

const ROOT = dirname(@__DIR__)

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
  digest = bytes2hex(sha256(join(lines, '\n')))[1:16]
  channel = get(ENV, "JULIA_CHANNEL", string(VERSION))
  name = "environment-$channel-$digest"
  foreach(println, lines)
  println("name=", name)
  haskey(ENV, "GITHUB_OUTPUT") && open(io -> println(io, "name=", name), ENV["GITHUB_OUTPUT"], "a")
  return nothing
end

main()
