using Pkg, InteractiveUtils, LinearAlgebra
Pkg.instantiate()
using ProximalBase, ProximalSolvers
for (u, d) in Pkg.dependencies()
  d.name == "ProximalBase" && println("ProximalBase loaded: version ", d.version, " tree ", d.tree_hash, " source ", d.git_source, " rev ", d.git_revision, " path ", Base.pkgdir(ProximalBase))
end
println("Julia ", VERSION, "; CPU ", Sys.cpu_info()[1].model, "; BLAS ", BLAS.get_config())
