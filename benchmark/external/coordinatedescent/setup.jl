using Pkg, TOML, SHA

# Usage: julia setup.jl SIDE HDM_REV OUTDIR. Locked copies avoid a fresh resolution.

function write_environment(side, revision, output)
  side in ("legacy", "current", "current-AA") || error("unknown side $side")
  VERSION == v"1.13.3" || error("the locked environments require Julia 1.13.3")
  source = joinpath(@__DIR__, side == "legacy" ? "legacy" : "current")
  output = abspath(output)
  ispath(output) && (!isdir(output) || !isempty(readdir(output))) &&
    error("use a fresh environment directory")
  mkpath(output)
  output = realpath(output)
  project = TOML.parsefile(joinpath(source, "Project.toml"))
  manifest = TOML.parsefile(joinpath(source, "Manifest.toml"))
  if side != "legacy"
    hdm = only(manifest["deps"]["HighDimensionalModels"])
    occursin(r"^[0-9a-fA-F]{40}$", hdm["repo-rev"]) || error("HighDimensionalModels must pin a commit")
    occursin(r"^[0-9a-fA-F]{40}$", hdm["git-tree-sha1"]) || error("invalid HighDimensionalModels tree hash")
    revision == hdm["repo-rev"] || error("revision differs from the locked current manifest")
  end
  root = realpath(joinpath(@__DIR__, "..", "..", ".."))
  rebased = false
  if side != "legacy"
    # A/A copies at the same depth preserve both lockfiles byte for byte.
    path = relpath(root, output)
    if path != "../../../.."
      side == "current-AA" && error("A/A must use a sibling of the current environment")
      project["sources"]["ProximalSolvers"]["path"] = path
      manifest["deps"]["ProximalSolvers"][1]["path"] = path
      rebased = true
    end
  end
  for (name, content) in (("Project.toml", project), ("Manifest.toml", manifest))
    if side == "legacy" || get(project["sources"]["ProximalSolvers"], "path", "") == "../../../.."
      cp(joinpath(source, name), joinpath(output, name))
    else
      open(io -> TOML.print(io, content; sorted = true), joinpath(output, name), "w")
    end
  end
  lock_path = joinpath(output, "Manifest.toml")
  if rebased
    # Julia 1.13 Pkg hashes source paths. Rebasing changes only the project hash,
    # with no resolver call or dependency-version change.
    cache = Pkg.Types.EnvCache(joinpath(output, "Project.toml"))
    manifest["project_hash"] = Pkg.Types.project_resolve_hash(cache, VERSION)
    open(io -> TOML.print(io, manifest; sorted = true), lock_path, "w")
  end
  lock_path
end

function setup(side, revision, output)
  lock_path = write_environment(side, revision, output)
  before = read(lock_path)
  Pkg.activate(dirname(lock_path))
  Pkg.instantiate()
  read(lock_path) == before || error("instantiation changed the locked manifest")
  deps = Pkg.dependencies()
  for (name, version) in (side == "legacy" ?
      (("CoordinateDescent", v"0.6.1"), ("ProximalBase", v"0.4.1")) :
      (("HighDimensionalModels", v"0.1.0"), ("ProximalBase", v"0.5.4"), ("ProximalSolvers", v"0.2.0")))
    only(d.version for d in values(deps) if d.name == name) == version || error("wrong $name version")
  end
  println("MANIFEST_SHA256 ", bytes2hex(sha256(read(lock_path))))
end

if abspath(PROGRAM_FILE) == @__FILE__
  length(ARGS) == 3 || error("usage: setup.jl SIDE HDM_REV OUTDIR")
  setup(ARGS...)
end
