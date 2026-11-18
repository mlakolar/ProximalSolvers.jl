using ProximalSolvers, ProximalBase, Test
const PS = ProximalSolvers
include("optC2.jl"); include("optB.jl")
ARGS[1] == "C2" ? install_C2!() : install_B1!()
@testset "ALL" begin include("<WORK>/ps-353/test/sqrt_lasso.jl") end
