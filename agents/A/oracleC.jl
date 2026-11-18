# Offline oracle C: for each point, does the point's (effective) support admit an exact support-equation
# certificate?  min ‖θ‖ s.t. X_Sᵀθ = λ s, |X_{S^c}ᵀθ| ≤ λ (Clarabel SOCP). Reports status and τ* = ‖θ*‖.
# τ* ≤ 1 with feasibility  <=>  (up to the dropped support mass) the point is an optimal exact fit.
include(joinpath(@__DIR__, "lib.jl"))
using JuMP, Clarabel
include(joinpath(@__DIR__, "pts.jl"))
function oracleC(X, y, λ, β; εdrop = 1e-6)
  n, p = size(X); S = effsupport(β, εdrop); Sc = setdiff(1:p, S)
  isempty(S) && return (; status = "emptysupport", τ = NaN, θ = nothing)
  s = sign.(β[S])
  m = Model(Clarabel.Optimizer); set_silent(m)
  set_attribute(m, "tol_gap_abs", 1e-12); set_attribute(m, "tol_gap_rel", 1e-12); set_attribute(m, "tol_feas", 1e-12)
  @variable(m, θ[1:n]); @variable(m, τ)
  @constraint(m, [τ; θ] in SecondOrderCone())
  @constraint(m, X[:, S]'*θ .== λ .* s)
  isempty(Sc) || (@constraint(m, X[:, Sc]'*θ .<= λ); @constraint(m, X[:, Sc]'*θ .>= -λ))
  @objective(m, Min, τ)
  optimize!(m)
  st = string(termination_status(m))
  (; status = st, τ = st in ("OPTIMAL", "ALMOST_OPTIMAL") ? value(τ) : NaN, θ = st in ("OPTIMAL", "ALMOST_OPTIMAL") ? value.(θ) : nothing)
end
if abspath(PROGRAM_FILE) == @__FILE__
  out = open(joinpath(@__DIR__, "out", "oracleC.tsv"), "w")
  println(out, join(["set", "id", "T", "start", "config", "status", "tau", "ratio_big_theta", "excess"], '\t'))
  for pt in points()
    TT = pt.T == "Float64" ? Float64 : Float32
    prob = problem(pt.id); o = oracle(pt.id, TT); X, y, λ = data(prob, TT)
    Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
    c = oracleC(Xd, yd, λd, pt.β)
    rb = c.θ === nothing ? NaN : bigcert(Xd, yd, λd, pt.β, c.θ).ratio
    exc = Float64((Pbig(X, y, λ, pt.β) - big(o.D))/big(o.D))
    println(out, join(Any[pt.set, pt.id, pt.T, pt.start, pt.config, c.status, c.τ, rb, exc], '\t')); flush(out)
  end
  close(out)
end
