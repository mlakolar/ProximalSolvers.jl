# BASE (master bb20b6a) and the head worktree as modules in one process.
module BaseMod; include("<WORK>/ProximalSolvers.jl-issue353-base/src/ProximalSolvers.jl"); end
module X2Mod; include("<WORK>/ProximalSolvers.jl-issue353/src/ProximalSolvers.jl"); end
