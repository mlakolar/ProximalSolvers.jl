using TOML, SHA, LinearAlgebra, ProximalBase
root = normpath(joinpath(@__DIR__,"..","..",".."))
dependency = pkgdir(ProximalBase)
files = ["src/solvers/slope.jl", "benchmark/slope/hybrid/prototype.jl",
         "benchmark/slope/hybrid/pilot.jl"]
metadata = Dict(
  "julia" => string(VERSION), "machine" => Sys.MACHINE, "cpu" => Sys.CPU_NAME,
  "os" => string(Sys.KERNEL), "threads" => Threads.nthreads(),
  "blas_threads" => BLAS.get_num_threads(), "blas" => sprint(show,BLAS.get_config()),
  "solver_base" => strip(read(`git -C $root rev-parse HEAD`,String)),
  "dependency_commit" => strip(read(`git -C $dependency rev-parse HEAD`,String)),
  "dependency_clean" => isempty(strip(read(`git -C $dependency status --porcelain`,String))),
  "flags" => "--startup-file=no --compiled-modules=existing --project=.master-test-env/v1.13",
  "sha256" => Dict(file => bytes2hex(sha256(read(joinpath(root,file)))) for file in files),
)
open(joinpath(@__DIR__,"evidence","environment.toml"),"w") do io
  TOML.print(io,metadata)
end
