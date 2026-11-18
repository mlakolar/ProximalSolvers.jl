# b1x (early exit) must give exactly the L0 of b1 on every control problem
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
include(joinpath(@__DIR__, "ref.jl")); const R = Ref321
include(joinpath(@__DIR__, "problems.jl"))
println("# Julia ", VERSION, " | ", Sys.CPU_NAME)
bad = 0; nl = 0
for pr in probs
  f = (pr.α == 1.0 && startswith(pr.name, "ord-raw")) ? LeastSquaresLoss(pr.y, pr.X) : pr.α * LeastSquaresLoss(pr.y, pr.X)
  a = PS._probe_L0(:b1, pr.T, f); b = PS._probe_L0(:b1x, pr.T, f)
  global nl += 1
  a == b || (global bad += 1; println("MISMATCH ", pr.name, " ", a, " ", b))
end
println("problems: ", nl, " mismatches: ", bad)
