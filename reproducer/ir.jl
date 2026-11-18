using ProximalSolvers, ProximalBase, InteractiveUtils
const PS = ProximalSolvers
λ = 1152921573326323713 // 1152921504606846976
g = ElasticNet(λ, λ)
code_llvm(stdout, PS._converted_penalty, (typeof(g), Type{Float32}); debuginfo=:none)
println("==== NormL1")
code_llvm(stdout, PS._converted_penalty, (typeof(NormL1(λ)), Type{Float32}); debuginfo=:none)
