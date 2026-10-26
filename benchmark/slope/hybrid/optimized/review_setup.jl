using Pkg, TOML
Pkg.offline(true)
version=ARGS[1]
target=version=="1.13.2" ? "review-env" : "review-env110"
project=TOML.parsefile("review-source/Project.toml")
deps=merge(project["deps"],project["extras"])
deps["ProximalSolvers"]=project["uuid"]
mkpath(target)
open(joinpath(target,"Project.toml"),"w") do io
  TOML.print(io,Dict("deps"=>deps))
end
Pkg.activate(target)
Pkg.develop([PackageSpec(path="review-source"),PackageSpec(path="ProximalBase.jl")])
Pkg.instantiate()
