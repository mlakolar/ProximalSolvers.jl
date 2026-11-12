using Pkg, TOML

const SHA1_HEX = r"^[0-9a-f]{40}$"

# The exact ProximalBase source pinned by the checkout's root Project.toml (url and full
# commit). A branch name or a short revision moves, so it is refused.
function pinned_base(package)
  source = get(get(package, "sources", Dict()), "ProximalBase", nothing)
  source isa AbstractDict && haskey(source, "url") && haskey(source, "rev") ||
    error("PROXIMALBASE_SPEC=pinned needs a [sources] ProximalBase url and rev in the checkout's Project.toml")
  occursin(SHA1_HEX, source["rev"]) ||
    error("the checkout pins ProximalBase to \"$(source["rev"])\", not a full commit; refusing a moving revision")
  String(source["url"]), String(source["rev"])
end

# The ProximalBase entry of a manifest (formats 1 and 2), or nothing.
function manifest_base(path)
  isfile(path) || return nothing
  manifest = TOML.parsefile(path)
  entries = get(get(manifest, "deps", manifest), "ProximalBase", nothing)
  entries isa AbstractVector && length(entries) == 1 ? only(entries) : nothing
end

# The checkout's own committed manifests that pin the same revision must agree on its tree.
function check_pinned_manifest(environment, source, url, rev)
  entry = manifest_base(joinpath(environment, "Manifest.toml"))
  entry !== nothing && get(entry, "repo-url", "") == url && get(entry, "repo-rev", "") == rev ||
    error("the new manifest does not record ProximalBase at $url#$rev")
  tree = get(entry, "git-tree-sha1", "")
  occursin(SHA1_HEX, tree) || error("the new manifest has no ProximalBase git-tree-sha1")
  for name in ("Manifest.toml", "Manifest-v$(VERSION.major).$(VERSION.minor).toml")
    committed = manifest_base(joinpath(source, name))
    (committed === nothing || get(committed, "repo-rev", "") != rev) && continue
    get(committed, "git-tree-sha1", "") == tree ||
      error("ProximalBase tree $tree differs from $(get(committed, "git-tree-sha1", "")) in the checkout's $name")
  end
  tree
end

function setup_environment(args)
  length(args) == 3 ||
    error("usage: julia benchmark/setup.jl PS_CHECKOUT NEW_ENV PROXIMALBASE_SPEC (a version, a ProximalBase checkout, or pinned)")
  source, environment, spec = realpath(args[1]), abspath(args[2]), args[3]
  project = TOML.parsefile(joinpath(@__DIR__, "Project.toml"))
  package = TOML.parsefile(joinpath(source, "Project.toml"))
  get(package, "name", "") == "ProximalSolvers" &&
    get(package, "uuid", "") == project["deps"]["ProximalSolvers"] ||
    error("PS_CHECKOUT must be a ProximalSolvers checkout")
  target = joinpath(environment, "Project.toml")
  ispath(target) && error("Refusing an existing NEW_ENV/Project.toml")
  pinned = spec == "pinned"
  base_path = !pinned && isdir(spec) ? realpath(spec) : nothing
  base_version = pinned || base_path !== nothing ? nothing : VersionNumber(spec)
  if base_path !== nothing
    base_project = TOML.parsefile(joinpath(base_path, "Project.toml"))
    get(base_project, "uuid", "") == project["deps"]["ProximalBase"] ||
      error("PROXIMALBASE_SPEC must name a version, a ProximalBase checkout or pinned")
  end
  if pinned
    # Current-core mode (#110): the checkout's exact ProximalBase source and compat, so the
    # environment never resolves to another release or a moving branch. benchmark/Project.toml
    # itself is unchanged, and the version and path modes still copy its compat.
    url, rev = pinned_base(package)
    base_compat = package["compat"]["ProximalBase"]
    delete!(project["compat"], "ProximalBase")
    # Both return below, by the add of the pinned source and by the develop; listed before
    # them, ProximalSolvers would resolve from the registry, which has no 0.6-compatible release.
    deps = copy(project["deps"])
    delete!(project["deps"], "ProximalSolvers")
    delete!(project["deps"], "ProximalBase")
  end
  # Explicit develop calls resolve local sources on Julia 1.10 as well.
  pop!(project, "sources", nothing)
  mkpath(environment)
  open(target, "w") do io
    TOML.print(io, project)
  end
  Pkg.activate(environment)
  # The pinned source goes first: the registry has no ProximalBase that the checkout accepts.
  pinned && Pkg.add(Pkg.PackageSpec(name = "ProximalBase", url = url, rev = rev))
  Pkg.develop(path = source)
  if pinned
    Pkg.compat("ProximalBase", base_compat)
  elseif base_path === nothing
    Pkg.add(name = "ProximalBase", version = base_version)
  else
    Pkg.develop(path = base_path)
  end
  Pkg.instantiate()
  packages = Pkg.dependencies()
  solver = only(p for p in values(packages) if p.name == "ProximalSolvers")
  base = only(p for p in values(packages) if p.name == "ProximalBase")
  println("ProximalSolvers path: ", realpath(solver.source))
  println("ProximalBase version: ", base.version)
  if pinned
    TOML.parsefile(target)["deps"] == deps ||
      error("the new environment's dependencies differ from benchmark/Project.toml")
    tree = check_pinned_manifest(environment, source, url, rev)
    println("ProximalBase source: ", url, "#", rev)
    println("ProximalBase git-tree-sha1: ", tree)
    println("ProximalBase path: ", realpath(base.source))
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  setup_environment(ARGS)
end
