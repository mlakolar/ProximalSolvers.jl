# Load the instrumented leastsquares.jl into the live ProximalSolvers module (process-local, no file edits).
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, SparseArrays, Printf
const PS = ProximalSolvers
Core.eval(PS, :(const _C = zeros(Int, 64)))
const IDS = split(read(joinpath(@__DIR__, "instr_ls.jl.ids"), String), "\n")
Base.include(PS, joinpath(@__DIR__, "instr_ls.jl"))
cnt_reset!() = fill!(PS._C, 0)
cnt_snapshot() = Dict(Symbol(IDS[i]) => PS._C[i] for i in eachindex(IDS) if PS._C[i] != 0)
