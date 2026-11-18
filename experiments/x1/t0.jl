include("trees.jl")
using ProximalBase
for (k, P) in pairs(TREES)
  println(k, " ", pathof(P) === nothing ? "" : "", P.SqrtLeastSquaresLoss === ProximalBase.SqrtLeastSquaresLoss, " ", isdefined(P, :solve!), " ", parentmodule(P.CDSolver))
end
