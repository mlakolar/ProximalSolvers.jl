# Three source trees of ProximalSolvers (BASE, X1A, X1B) loaded into wrapper modules of ONE process.
# Run with --project=<WORK>/ps-353. Gives Base0.ProximalSolvers, X1A.ProximalSolvers, X1B.ProximalSolvers.
const ROOT = "<WORK>"
module Base0; include("<WORK>/ps-353/src/ProximalSolvers.jl"); end
module X1A;   include("<WORK>/ps-353-x1a/src/ProximalSolvers.jl"); end
module X1B;   include("<WORK>/ps-353-x1b/src/ProximalSolvers.jl"); end
const TREES = (base = Base0.ProximalSolvers, x1a = X1A.ProximalSolvers, x1b = X1B.ProximalSolvers)
