# Loads the audited source twice (master and a control copy) and the prototypes, each compiled from
# source in this process, as separate modules. usage: include after setting PROTO (the directory of
# make_protos.py's output).
using ProximalBase, LinearAlgebra, Printf, Logging, Random
module M0; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
module M0b; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
module MA; include(joinpath(Main.PROTO, "A", "src", "ProximalSolvers.jl")); end
module MR; include(joinpath(Main.PROTO, "R", "src", "ProximalSolvers.jl")); end
module MF; include(joinpath(Main.PROTO, "F", "src", "ProximalSolvers.jl")); end
const MODS = (("master", M0.ProximalSolvers), ("control", M0b.ProximalSolvers), ("A", MA.ProximalSolvers), ("R", MR.ProximalSolvers),
              ("F", MF.ProximalSolvers))
floor_of(P) = P._ABSORB_FLOOR
quiet(f) = with_logger(f, NullLogger())
