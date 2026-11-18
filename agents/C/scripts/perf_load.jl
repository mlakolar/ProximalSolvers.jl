# Load several copies of ProximalSolvers (pristine and prototype variants) into ONE process under wrapper modules.
# PERT_VARS (env) selects the copies; names old/ctl/v1/v1b/v2/v2b/fb map to proto/<dir>/src.
using ProximalBase, LinearAlgebra, Random
const PROTO = joinpath(@__DIR__, "..", "proto")
const VARS = String.(split(get(ENV, "PERT_VARS", "old,ctl,v1,v1b,v2,v2b"), ","))
const SRC = Dict("old" => "old", "ctl" => "ctl", "v1" => "v1", "v1b" => "v1", "v2" => "v2", "v2b" => "v2", "fb" => "fb")
for v in VARS
  @eval module $(Symbol("M_", v))
    include($(joinpath(PROTO, SRC[v], "src", "ProximalSolvers.jl")))
  end
end
mod(v) = getfield(getfield(Main, Symbol("M_", v)), :ProximalSolvers)
