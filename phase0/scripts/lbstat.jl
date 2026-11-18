# L_lower (free), U = α‖X‖_F² and L_f = α‖X‖₂² on the control problems (x0 as in controls.jl)
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
include(joinpath(@__DIR__, "ref.jl"))
const R = Ref321
include(joinpath(@__DIR__, "problems.jl"))
println("case\tT\tL_lower\tU=α‖X‖_F²\tL_f(Float64 opnorm)\tU/L_f\tL_lower/L_f")
for pr in probs
  T = pr.T
  f = (pr.α == 1.0 && startswith(pr.name, "ord-raw")) ? LeastSquaresLoss(pr.y, pr.X) : pr.α * LeastSquaresLoss(pr.y, pr.X)
  ll = PS._probe_Llower(T, f, pr.x0)
  Llow = ll === nothing ? NaN : Float64(PS._se_to_T(Float64, ll))
  U = Float64(PS._se_to_T(Float64, PS._probe_frob_alpha(Float64, pr.T === Float64 ? f : (Float64(pr.α) * LeastSquaresLoss(Float64.(pr.y), Float64.(pr.X))))))
  Lf = try pr.α * Float64(opnorm(Float64.(pr.X))^2) catch; NaN end
  @printf("%s\t%s\t%.3e\t%.3e\t%.3e\t%.3g\t%.3g\n", pr.name, T, Llow, U, Lf, U / Lf, Llow / Lf)
end
