# Stage 2B (#110) environment probe: prints the environment inventory of the running Julia process as TOML on
# stdout, in the format of the Stage 2A probe (../pre06/campaign.py) plus the keys that MIGRATION_COMPARE_SPEC.md
# section 10 requires since PR 218-A. It reads the process and the active environment; it changes nothing and
# measures nothing. Run it in the environment of a stack, with the flags and the environment of the formal runs:
#
#   JULIA_NUM_THREADS=1 julia --startup-file=no --history-file=no --project=ENV environment_probe.jl > environment-inventory.toml
#
# Keys: julia, commit, bindir, cpu_name, cpu_model, threads, blas, load_path, depot_path, active_project,
# the Julia-observed realpaths depot_realpath (realpath of the first depot entry) and active_project_realpath
# (realpath of the directory of the active project file joined with the file's name: the file itself is not
# resolved, so a Project.toml that is a link to a shared template does not make two environments one),
# proximalbase_dir, proximalbase_version, proximalbase_loaded_tree (the git tree hash of the loaded ProximalBase
# directory), proximalsolvers_dir, proximalsolvers_loaded_tree (an extra key), and one [deps.NAME] table per
# Pkg.dependencies() entry with path, registry, repo, source, tree, uuid and version.
import Pkg, TOML, LinearAlgebra
import ProximalBase, ProximalSolvers

tree_of(directory) = (hash = Pkg.GitTools.tree_hash(directory); hash isa AbstractString ? String(hash) : bytes2hex(hash))

function inventory()
  deps = Dict{String, Any}()
  for (uuid, p) in Pkg.dependencies()
    deps[p.name] = Dict("uuid" => string(uuid), "version" => string(something(p.version, "")),
      "tree" => string(something(p.tree_hash, "")), "path" => p.is_tracking_path,
      "repo" => p.is_tracking_repo, "registry" => p.is_tracking_registry,
      "source" => string(something(p.source, "")))
  end
  base = realpath(pkgdir(ProximalBase))
  solvers = realpath(pkgdir(ProximalSolvers))
  project = Base.active_project()
  Dict{String, Any}("julia" => string(VERSION), "commit" => Base.GIT_VERSION_INFO.commit,
    "bindir" => Sys.BINDIR, "cpu_name" => Sys.CPU_NAME, "cpu_model" => Sys.cpu_info()[1].model,
    "threads" => Threads.nthreads(), "blas" => string(LinearAlgebra.BLAS.get_config()),
    "proximalbase_dir" => base, "proximalbase_loaded_tree" => tree_of(base),
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "proximalsolvers_dir" => solvers, "proximalsolvers_loaded_tree" => tree_of(solvers),
    "active_project" => project,
    "active_project_realpath" => joinpath(realpath(dirname(project)), basename(project)),
    "depot_realpath" => realpath(DEPOT_PATH[1]),
    "load_path" => LOAD_PATH, "depot_path" => DEPOT_PATH, "deps" => deps)
end

TOML.print(stdout, inventory(); sorted = true)
