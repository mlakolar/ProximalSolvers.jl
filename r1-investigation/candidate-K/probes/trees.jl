# BASE (master bb20b6a) and CAND (this worktree) in one process.
module Base0; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end
module Cand;  include("<WORK>/ProximalSolvers.jl-issue353-r1/src/ProximalSolvers.jl"); end
const TREES = (base = Base0.ProximalSolvers, cand = Cand.ProximalSolvers)
