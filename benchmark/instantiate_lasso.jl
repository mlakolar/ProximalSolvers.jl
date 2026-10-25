# Instantiate both environments before running under a Slurm allocation.
using Pkg, TOML

# Julia 1.10.8+ selects a minor-version manifest when the file already exists.
# Keep each runtime's locks separate: a shared manifest can otherwise retain a
# Statistics version that the next Julia runtime cannot resolve.
function activate_lasso_environment(path)
  VERSION >= v"1.10.8" || error("Lasso benchmark setup requires Julia 1.10.8 or later.")
  manifest = joinpath(path, "Manifest-v$(VERSION.major).$(VERSION.minor).toml")
  if !isfile(manifest)
    shared = joinpath(path, "Manifest.toml")
    previous = isfile(shared) ? get(TOML.parsefile(shared), "julia_version", nothing) : nothing
    same_runtime = previous !== nothing &&
      (VersionNumber(previous).major, VersionNumber(previous).minor) == (VERSION.major, VERSION.minor)
    if same_runtime
      cp(shared, manifest)
    else
      # Preserve any foreign shared lock; Pkg fills this valid empty manifest
      # from Project.toml on the first setup for the current Julia minor.
      open(manifest, "w") do io
        TOML.print(io, Dict("julia_version" => string(VERSION),
                            "manifest_format" => "2.0", "deps" => Dict{String, Any}()))
      end
    end
  end
  Pkg.activate(path)
end

# The modern comparison always uses the same recursively developed master
# dependency stack as the package, docs and CI, including on Julia 1.10.
include(joinpath(@__DIR__, "..", "scripts", "master_dependencies.jl"))
activate_lasso_environment(@__DIR__)
instantiate_master(@__DIR__; workspace=dirname(dirname(@__DIR__)),
                    owner=dirname(@__DIR__))

# Preserve the independently pinned historical worker environment.
activate_lasso_environment(joinpath(@__DIR__, "legacy_cd"))
Pkg.resolve()
Pkg.instantiate()
