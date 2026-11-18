using Pkg, InteractiveUtils, LinearAlgebra
import ProximalSolvers, ProximalBase
println("julia ", VERSION)
versioninfo()
println("BLAS: ", BLAS.get_config()); println("BLAS threads: ", BLAS.get_num_threads(), "  julia threads: ", Threads.nthreads())
println("PS pkgdir: ", pkgdir(ProximalSolvers))
println("PB pkgdir: ", pkgdir(ProximalBase))
for (u, p) in Pkg.dependencies()
    p.name == "ProximalBase" && println("PB manifest: version=", p.version, " tree=", p.tree_hash, " rev=", p.git_revision, " source=", p.source)
end
println("PB src/numerical_kernels.jl sha256: ", bytes2hex(open(Pkg.Types.sha256, joinpath(pkgdir(ProximalBase), "src", "numerical_kernels.jl"))))
