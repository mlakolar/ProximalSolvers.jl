# #317 diagnosis: log the failing rejection (probe-only override of backtrack!, which is
# the master source with prints added before the error)
using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const LS = ProximalSolvers.LineSearches
src = read(joinpath(pkgdir(ProximalSolvers), "src", "line_searches.jl"), String)
i1 = findfirst("function backtrack!(", src).start; i2 = findfirst("\nhas_updated_gradient", src).start
body = src[i1:i2]
body = replace(body, "    isfinite(state.L) || error(" =>
 """    if !isfinite(state.L)
        d = state.delta_x
        println("  FAIL iter-state: L_prev(trial)=", L_trial, " mode=", gradient_mode ? "grad" : "fval",
                "\\n   xy_sq=_norm(d)^2=", xy_sq, " (subnormal=", issubnormal(xy_sq), ")  sum(abs2,d)=", sum(abs2, d),
                "\\n   maxabs(d)=", maximum(abs, d), " norm(x)=", norm(state.x), " f_x=", state.f_x, " f_prev=", state.f_x_previous,
                "\\n   sum(abs2,dz)=", sum(abs2, state.dz), " norm(dz)=", norm(state.dz),
                "\\n   local_l(after check)=", local_l, " verified=", verified,
                "\\n   robust c = m α (‖Xd‖/‖d‖)^2 = ", (gradient_mode ? 2 : 1) * state.model.α * (norm(state.dz)/norm(d))^2)
    end
    isfinite(state.L) || error(""")
body = replace(body, "    local_l = Inf\n" => "    local_l = Inf\n    L_trial = state.L\n")
write(joinpath(@__DIR__, "body.jl"), body); Core.eval(LS, :(using LinearAlgebra: norm)); Core.eval(LS, Meta.parseall(body))
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X * β + 0.3 * randn(rng, 30)
println("‖X‖₂² = ", opnorm(X)^2, "  ‖Xᵀy‖∞ = ", norm(X'y, Inf))
for α in (1e-180, 1e-200, 1e-300)
  x = zeros(12)
  println("α=$α  true curvature α‖X‖² = ", α*opnorm(X)^2)
  try solve!(x, α * LeastSquaresLoss(y, X), NormL1(0.0), ProximalGradientDescent(), ProximalOptions(maxiter = 20_000))
  catch e; println("  -> ", sprint(showerror, e)); end
end
