using Pkg, TOML
Pkg.offline(true)
mkpath("env")
project=TOML.parsefile("source/Project.toml")
deps=merge(project["deps"],project["extras"])
deps["ProximalSolvers"]=project["uuid"]
open("env/Project.toml","w") do io
  TOML.print(io,Dict("deps"=>deps))
end
Pkg.activate("env")
Pkg.develop([PackageSpec(path="source"),PackageSpec(path="ProximalBase.jl")])
Pkg.instantiate()
println("Julia ",VERSION)
println("Active environment ",Base.active_project())
