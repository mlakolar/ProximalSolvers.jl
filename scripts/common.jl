# Shared helpers for the #155/#156 study: load the oracle records, run the production solver, classify a
# returned point against the oracle, and call the production certificate on an arbitrary point.
using ProximalBase, ProximalSolvers, LinearAlgebra, Logging, Random, Serialization, Printf
const PS = ProximalSolvers
include(joinpath(@__DIR__, "matrix.jl"))
setprecision(BigFloat, 256)
const ORACLE = deserialize(joinpath(@__DIR__, "..", "out", "oracle.jls"))
oracle(id, T) = ORACLE.recs[(id, string(T))]
problem(id) = only(filter(p -> p.id == id, ORACLE.probs))
Pbig(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)
data(prob, ::Type{T}) where T = (T.(prob.X), T.(prob.y), T(prob.λ))

# run the production solver; returns (x::Vector{T}, result, seconds, bytes)
function ps_solve(X::Matrix{T}, y::Vector{T}, λ, β0; owner = false, maxpasses = 20_000, kw...) where T
  x = owner ? SparseIterate(T.(β0)) : T.(β0)
  local r
  st = @timed with_logger(NullLogger()) do
    r = solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; maxpasses, kw...))
  end
  (owner ? Vector(x) : x), r, st.time, st.bytes
end

# the production certificate (`_certify!`) at an arbitrary point β of T (no CD pass): (code, ratio)
function certify_at(X::Matrix{T}, y::Vector{T}, λ, β::AbstractVector) where T
  x = SparseIterate(T.(β))
  f = SqrtLeastSquaresLoss(y, X); g = NormL1(λ)
  m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  PS._certify!(m, x)
end

# classification of a returned point β (of T) for the T problem with oracle record o
function classify(X::Matrix{T}, y::Vector{T}, λ, β, o) where T
  P = Pbig(X, y, λ, β)
  excess = Float64((P - big(o.D)) / big(o.D))
  rr = Float64(norm(big.(y) - big.(X) * big.(β)) / norm(big.(y)))
  # rounding floor of the residual of a point stored in T: eps(T) times the row magnitudes
  floor = Float64(eps(T) * norm(abs.(big.(y)) + abs.(big.(X)) * abs.(big.(β))) / norm(big.(y)))
  (; excess, optimal = excess <= 1e-4, rrel = rr, atfloor = rr <= 4 * floor, nnz = count(!iszero, β))
end
