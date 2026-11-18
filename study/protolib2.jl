# Loads the audited source twice (master and a control copy) and every prototype tree S<floor> found in
# PROTO (make_protos2.py's output), each compiled from source in this process, as separate modules.
# usage: include after setting PROTO.
using ProximalBase, LinearAlgebra, Printf, Logging, Random
module M0; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
module M0b; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
const SNAMES = sort([d for d in readdir(PROTO) if startswith(d, "S") && isdir(joinpath(PROTO, d, "src"))]; by = d -> parse(Int, d[2:end]))
for d in SNAMES
  @eval module $(Symbol("M", d)); include(joinpath(Main.PROTO, $d, "src", "ProximalSolvers.jl")); end
end
const MODS = (("master", M0.ProximalSolvers), ("control", M0b.ProximalSolvers), ((d, getfield(Main, Symbol("M", d)).ProximalSolvers) for d in SNAMES)...)
floor_of(P) = P._ABSORB_FLOOR
quiet(f) = with_logger(f, NullLogger())
