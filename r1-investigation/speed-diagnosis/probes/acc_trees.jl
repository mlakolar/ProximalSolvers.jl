module Base0; include("<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants/base/src/ProximalSolvers.jl"); end
module Cand;  include("<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants/cand/src/ProximalSolvers.jl"); end
module X1D;   include("<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants/x1d/src/ProximalSolvers.jl"); end
const TREES = (base = Base0.ProximalSolvers, cand = Cand.ProximalSolvers, x1d = X1D.ProximalSolvers)
