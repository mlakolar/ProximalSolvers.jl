include(joinpath(@__DIR__, "escape.jl"))
id = ARGS[1]; T = ARGS[3] == "32" ? Float32 : Float64
prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
cfg = cfgmaker("cyclic-dense")
x, r, _, _ = ps_solve(X, y, λ, start_point(prob, Symbol(ARGS[2]), o.β); cfg...)
F0 = fhat(X,y,λ,x)[1]; Pstar = big(o.U)
println("$id $T F0=$F0 P*≈$(o.U) D*=$(o.D)")
let β = copy(x)
for j in 0:13
  δ = 0.1 * F0 * 0.3^j
  β, rs, s, _ = smooth_stage(X, y, λ, β, δ; cfg)
  Dj = dual_bound(X, y, λ, β)
  Pj = Pbig(X, y, λ, β)
  rn = norm(fhat(X,y,λ,β)[3])
  println("j=$j δ=$(round(δ,sigdigits=3)) ‖r‖=$(round(rn,sigdigits=3)) dual defect (P*-D_j)/P*=$(round(Float64((Pstar-Dj)/Pstar),sigdigits=3)) primal excess=$(round(Float64((Pj-Pstar)/Pstar),sigdigits=3)) own ratio=$(round(Float64((Pj-Dj)/Dj),sigdigits=3))")
end
end
