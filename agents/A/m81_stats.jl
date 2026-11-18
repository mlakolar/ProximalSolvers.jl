include(joinpath(@__DIR__, "lib.jl")); include(joinpath(@__DIR__, "pts.jl"))
out = open(joinpath(@__DIR__, "out", "m81_stats.tsv"), "w")
println(out, join(["set","id","T","start","config","n","ns","rank","cond","rP","nnz"], '\t'))
for pt in points()
  pt.set in ("M81", "OPTx") || continue
  TT = pt.T == "Float64" ? Float64 : Float32
  prob = problem(pt.id); X, y, λ = data(prob, TT); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  P = Float64(Pbig(X, y, λ, TT.(pt.β))); r = norm(big.(yd) - big.(Xd)*big.(pt.β))
  S = effsupport(pt.β, 3e-5); sv = svdvals(Xd[:, S])
  println(out, join(Any[pt.set, pt.id, pt.T, pt.start, pt.config, size(X, 1), length(S), count(>(1e-10*sv[1]), sv), sv[1]/sv[end], Float64(r)/P, count(!iszero, pt.β)], '\t'))
end
close(out)
