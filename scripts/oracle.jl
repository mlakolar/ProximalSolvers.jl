# Offline oracle for the #155/#156 matrix: Clarabel solves of the primal (SOCP) and of the dual, then
# BigFloat validation. For each problem and each data type T ∈ (Float64, Float32) — the T problem is
# T.(X), T.(y), T(λ), solved exactly as data — it records
#   U = P(β*) in BigFloat (an upper bound on P*), D = t θ*ᵀy in BigFloat with θ* scaled into exact
#   feasibility (a lower bound on P*), β*, θ*, ‖r*‖/‖y‖, and whether the optimum is an exact fit
#   (‖r*‖/‖y‖ < 1e-8).
# Research-only; not a proposed dependency.
using JuMP, Clarabel, LinearAlgebra, Serialization, Printf
include(joinpath(@__DIR__, "matrix.jl"))
setprecision(BigFloat, 256)

Pbig(X, y, λ, b) = norm(big.(y) - big.(X) * big.(b)) + big(λ) * norm(big.(b), 1)
function primal(X, y, λ)
  n, p = size(X)
  m = Model(Clarabel.Optimizer); set_silent(m)
  set_attribute(m, "tol_gap_abs", 1e-13); set_attribute(m, "tol_gap_rel", 1e-13); set_attribute(m, "tol_feas", 1e-13)
  set_attribute(m, "max_iter", 500)
  @variable(m, b[1:p]); @variable(m, u[1:p] >= 0); @variable(m, t)
  @constraint(m, u .>= b); @constraint(m, u .>= -b)
  @constraint(m, [t; y .- X * b] in SecondOrderCone())
  @objective(m, Min, t + λ * sum(u))
  optimize!(m)
  value.(b), string(termination_status(m))
end
function dual(X, y, λ)
  n, p = size(X)
  m = Model(Clarabel.Optimizer); set_silent(m)
  set_attribute(m, "tol_gap_abs", 1e-13); set_attribute(m, "tol_gap_rel", 1e-13); set_attribute(m, "tol_feas", 1e-13)
  set_attribute(m, "max_iter", 500)
  @variable(m, θ[1:n])
  @constraint(m, [1.0; θ] in SecondOrderCone())
  @constraint(m, X' * θ .<= λ); @constraint(m, X' * θ .>= -λ)
  @objective(m, Max, dot(y, θ))
  optimize!(m)
  value.(θ), string(termination_status(m))
end
# scale θ into exact feasibility in BigFloat and return the dual value (a valid lower bound on P*)
function dual_lower(X, y, λ, θ)
  θb = big.(θ); Xb = big.(X)
  t = min(big(1), 1 / norm(θb), big(λ) / maximum(abs, Xb' * θb))
  t * dot(θb, big.(y)), t .* θb
end

function oracle_record(prob, ::Type{T}) where T
  X, y, λ = Float64.(T.(prob.X)), Float64.(T.(prob.y)), Float64(T(prob.λ))
  β, sp = primal(X, y, λ)
  θ, sd = dual(X, y, λ)
  U = Pbig(X, y, λ, β)
  D, θf = dual_lower(X, y, λ, θ)
  rrel = Float64(norm(big.(y) - big.(X) * big.(β)) / norm(big.(y)))
  (; id = prob.id, T = string(T), β, θ = Float64.(θf), U = Float64(U), D = Float64(D),
     relwidth = Float64((U - D) / D), rrel, exactfit = rrel < 1e-8, nnz = count(abs.(β) .> 1e-9 * norm(β, Inf)),
     status = (sp, sd))
end

if abspath(PROGRAM_FILE) == @__FILE__
  probs = problems()
  recs = Dict{Tuple{String, String}, Any}()
  for prob in probs, T in (Float64, Float32)
    r = oracle_record(prob, T)
    recs[(prob.id, string(T))] = r
    @printf "%-22s %-7s n=%3d p=%3d λ=%.3e  P*∈[%.10e, %.10e] width %.1e  ‖r*‖/‖y‖=%.1e exact=%s nnz=%d %s\n" prob.id r.T size(prob.X, 1) size(prob.X, 2) prob.λ r.D r.U r.relwidth r.rrel r.exactfit r.nnz r.status
  end
  serialize(joinpath(@__DIR__, "..", "out", "oracle.jls"), (; probs, recs))
end
