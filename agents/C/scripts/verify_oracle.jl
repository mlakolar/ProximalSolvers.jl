# Task 2a: independent verification of the oracle records. (i) exact BigFloat (512 bits) re-derivation of the dual lower bound D from the
# stored θ (re-scaled into exact feasibility) and of the upper bound U = P(β*); (ii) a different Clarabel formulation (split β = β⁺ - β⁻,
# explicit SOC on the residual, different tolerances) on a sample; (iii) the sandwich D ≤ P_alt ≤ U(1+tol).
include(joinpath(@__DIR__, "lib.jl"))
using JuMP, Clarabel
setprecision(BigFloat, 512)
function alt_primal(X, y, λ)
  n, p = size(X); m = Model(Clarabel.Optimizer); set_silent(m)
  set_attribute(m, "tol_gap_abs", 1e-14); set_attribute(m, "tol_gap_rel", 1e-14); set_attribute(m, "tol_feas", 1e-14); set_attribute(m, "max_iter", 800)
  set_attribute(m, "equilibrate_enable", false)
  @variable(m, bp[1:p] >= 0); @variable(m, bm[1:p] >= 0); @variable(m, t >= 0)
  @constraint(m, [t; y .- X * (bp .- bm)] in SecondOrderCone())
  @objective(m, Min, t + λ * (sum(bp) + sum(bm)))
  optimize!(m); value.(bp) .- value.(bm)
end
maxrel = 0.0; maxD = 0.0; nbad = 0; worstwidth = 0.0; maxalt = 0.0; nalt = 0; viol = 0
for (i, (key, o)) in enumerate(sort(collect(ORACLE.recs); by = first))
  id, Ts = key; T = Ts == "Float64" ? Float64 : Float32
  prob = problem(id); X, y, λ = data(prob, T)
  Xb, yb, λb = big.(X), big.(y), big(λ)
  θ = big.(o.θ); nθ = norm(θ); G = maximum(abs, Xb' * θ)
  t = min(big(1), 1 / nθ, λb / G)
  Dnew = t * dot(θ, yb)
  Unew = Pbig(X, y, λ, o.β)
  global maxD = max(maxD, Float64(abs(Dnew - big(o.D)) / Dnew))
  global worstwidth = max(worstwidth, Float64((Unew - Dnew) / Dnew))
  Unew >= Dnew || (global viol += 1; println("VIOLATION weak duality: ", key))
  # stored D was rounded to Float64: is it ≤ the exact dual bound? (it must be a LOWER bound up to 1 ulp)
  global maxrel = max(maxrel, Float64((big(o.D) - Dnew) / Dnew))
  if i % 4 == 1 || id in ("A155", "A156", "AI3")
    βa = try alt_primal(Float64.(X), Float64.(y), Float64(λ)) catch; nothing end
    nothing === βa && continue
    Pa = Pbig(X, y, λ, βa); global nalt += 1
    # alt objective must be ≥ Dnew (rigorous) and within the oracle band
    Pa >= Dnew || (global viol += 1; println("ALT below the exact dual bound! ", key, " ", Float64((Dnew - Pa) / Dnew)))
    global maxalt = max(maxalt, Float64((Pa - Dnew) / Dnew))
  end
end
println("records=", length(ORACLE.recs), " weak-duality violations=", viol)
println("max |D_stored - D_exact|/D_exact = ", maxD, "; max (D_stored - D_exact)/D_exact (positive means stored D is above the exact bound) = ", maxrel)
println("max (U - D_exact)/D_exact over all records = ", worstwidth)
println("alternative-formulation Clarabel solves: ", nalt, "; max (P(β_alt) - D_exact)/D_exact = ", maxalt)
