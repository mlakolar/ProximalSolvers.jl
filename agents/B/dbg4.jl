include(joinpath(@__DIR__, "escape.jl"))
id = ARGS[1]; T = ARGS[3] == "32" ? Float32 : Float64
prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
cfg = cfgmaker("cyclic-dense")
x, r, _, _ = ps_solve(X, y, λ, start_point(prob, Symbol(ARGS[2]), o.β); cfg...)
F0 = fhat(X,y,λ,x)[1]
println("$id $T stage1 F=$F0 P*=$(o.U) ‖y‖=$(norm(y))")
global β = copy(x)
for j in 0:14
  δ = 0.1 * F0 * 0.5^j
  global β; β, rs, s, _ = smooth_stage(X, y, λ, β, δ; cfg)
  code, ratio = certify_at(X, y, λ, β)
  c = classify(X, y, λ, β, o)
  rn = fhat(X,y,λ,β)[3]
  println("j=$j δ=$(round(δ,sigdigits=3)) passes=$(rs.passes) conv=$(rs.converged) code=$code ratio=$ratio excess=$(round(c.excess,sigdigits=3)) ‖r‖=$(round(norm(rn),sigdigits=3)) nnz=$(c.nnz)")
end
