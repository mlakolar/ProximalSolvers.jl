using Pkg, TOML
Pkg.offline(true)
version=ARGS[1]
target=version=="1.13.2" ? "integration-env" : "integration-env110"
project=TOML.parsefile("integration-source/Project.toml")
deps=merge(project["deps"],project["extras"])
deps["ProximalSolvers"]=project["uuid"]
mkpath(target)
open(joinpath(target,"Project.toml"),"w") do io
  TOML.print(io,Dict("deps"=>deps))
end
Pkg.activate(target)
Pkg.develop([PackageSpec(path="integration-source"),PackageSpec(path="ProximalBase.jl")])
Pkg.instantiate()
