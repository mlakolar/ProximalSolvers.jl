# Load BASE and the five-item bundle X2b (X2 with `response_scale` as on master) as modules in one process.
const ROOT = "<WORK>"
module BaseMod; include("<WORK>/ps-353/src/ProximalSolvers.jl"); end
module X2Mod;   include(joinpath(@__DIR__, "x2b_tree/src/ProximalSolvers.jl")); end
