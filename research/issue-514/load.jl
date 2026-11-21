using LinearAlgebra, Random, SHA
import ProximalBase as PB
import ProximalSolvers as PS

BLAS.set_num_threads(1)
@assert Threads.nthreads() == BLAS.get_num_threads() == 1
include("fixtures.jl")
include("feasibility.jl")
include("stationarity.jl")
include("policies.jl")
include("reference.jl")
