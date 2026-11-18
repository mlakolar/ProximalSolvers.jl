# Build a probe environment: ProximalBase at the pin of the PS checkout `ref` (url and full rev from
# its [sources]), the checkout developed, plus the standard libraries the probes load.
using Pkg, TOML
ref, envdir = abspath(ARGS[1]), abspath(ARGS[2])
pkg = TOML.parsefile(joinpath(ref, "Project.toml"))
src = pkg["sources"]["ProximalBase"]
url, rev = String(src["url"]), String(src["rev"])
occursin(r"^[0-9a-f]{40}$", rev) || error("not a full commit: $rev")
mkpath(envdir)
Pkg.activate(envdir)
Pkg.add(Pkg.PackageSpec(name = "ProximalBase", url = url, rev = rev))
Pkg.develop(path = ref)
Pkg.add(["LinearAlgebra", "SparseArrays", "Random", "SHA", "Printf", "Statistics", "TOML", "InteractiveUtils"])
Pkg.instantiate()
man = TOML.parsefile(joinpath(envdir, "Manifest.toml"))
pb = only(get(man, "deps", man)["ProximalBase"])
println("PS ref: ", ref)
println("PB: ", url, "#", pb["repo-rev"], " tree ", pb["git-tree-sha1"])
