# Load BASE, X2 and X3 source trees as separate modules in one process. Run with --project=<WORK>/ps-353
const ROOT = "<WORK>"
module BaseMod; include("<WORK>/ps-353/src/ProximalSolvers.jl"); end
module X2Mod;   include("<WORK>/ps-353-x2/src/ProximalSolvers.jl"); end
if isdir("<WORK>/ps-353-x3/src")
  @eval module X3Mod; include("<WORK>/ps-353-x3/src/ProximalSolvers.jl"); end
end
