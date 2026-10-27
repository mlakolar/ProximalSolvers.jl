using Pkg, TOML

function setup_environment(args)
  length(args) == 3 ||
    error("usage: julia benchmark/setup.jl PS_CHECKOUT NEW_ENV PROXIMALBASE_SPEC")
  source, environment, spec = realpath(args[1]), abspath(args[2]), args[3]
  project = TOML.parsefile(joinpath(@__DIR__, "Project.toml"))
  package = TOML.parsefile(joinpath(source, "Project.toml"))
  get(package, "name", "") == "ProximalSolvers" &&
    get(package, "uuid", "") == project["deps"]["ProximalSolvers"] ||
    error("PS_CHECKOUT must be a ProximalSolvers checkout")
  target = joinpath(environment, "Project.toml")
  ispath(target) && error("Refusing an existing NEW_ENV/Project.toml")
  base_path = isdir(spec) ? realpath(spec) : nothing
  base_version = base_path === nothing ? VersionNumber(spec) : nothing
  if base_path !== nothing
    base_project = TOML.parsefile(joinpath(base_path, "Project.toml"))
    get(base_project, "uuid", "") == project["deps"]["ProximalBase"] ||
      error("PROXIMALBASE_SPEC must name a version or a ProximalBase checkout")
  end
  # Explicit develop calls resolve local sources on Julia 1.10 as well.
  pop!(project, "sources", nothing)
  mkpath(environment)
  open(target, "w") do io
    TOML.print(io, project)
  end
  Pkg.activate(environment)
  Pkg.develop(path = source)
  if base_path === nothing
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
end

if abspath(PROGRAM_FILE) == @__FILE__
  setup_environment(ARGS)
end
