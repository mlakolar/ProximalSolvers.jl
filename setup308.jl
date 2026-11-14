# Build a probe environment for one Julia version (works on 1.10, whose Pkg ignores [sources]):
#   julia setup308.jl <env dir> <ProximalSolvers tree>
using Pkg, TOML
env, tree = abspath(ARGS[1]), abspath(ARGS[2])
src = TOML.parsefile(joinpath(tree, "Project.toml"))["sources"]["ProximalBase"]
Pkg.activate(env)
Pkg.add(url = src["url"], rev = src["rev"])
Pkg.develop(path = tree)
Pkg.add(["SHA", "Statistics", "PrecompileTools", "Printf", "Random", "SparseArrays", "LinearAlgebra", "TOML"])
Pkg.instantiate()
Pkg.status(; mode = Pkg.PKGMODE_MANIFEST)
Pkg.precompile()
m = TOML.parsefile(joinpath(env, "Manifest.toml"))
pb = only(m["deps"]["ProximalBase"])
println("PB_PIN_CHECK expected ", src["rev"], " manifest repo-rev ", get(pb, "repo-rev", "?"), " tree ", get(pb, "git-tree-sha1", "?"))
