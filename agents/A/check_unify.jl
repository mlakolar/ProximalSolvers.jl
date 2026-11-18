# Does vcert(θ̂ = r̂) reproduce the production residual-direction certificate `_certify!`?
include(joinpath(@__DIR__, "lib.jl"))
FP = deserialize(joinpath(@__DIR__, "final_points.jls"))
out = open(joinpath(@__DIR__, "out", "unify.tsv"), "w")
println(out, join(["id","T","start","config","class","prod_code","prod_ratio","v_ok","v_ratio","big_ratio"], '\t'))
for r in FP
  TT = r.T == "Float64" ? Float64 : Float32
  prob = problem(r.id); X, y, λ = data(prob, TT); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  β = r.β
  code, ratio = certify_at(X, y, λ, TT.(β))
  res = copy(yd)                      # same sequential loop as `_certify!`
  for k in 1:length(β); iszero(β[k]) && continue; for i in eachindex(res); res[i] -= Xd[i, k]*β[k]; end; end
  v = all(iszero, res) ? (; ok = false, ratio = NaN) : vcert(Xd, yd, λd, λd, β, res)
  b = all(iszero, res) ? (; ratio = NaN) : bigcert(Xd, yd, λd, β, res)
  println(out, join(Any[r.id, r.T, r.start, r.config, r.class, code, ratio, v.ok, v.ratio, b.ratio], '\t'))
end
close(out)
