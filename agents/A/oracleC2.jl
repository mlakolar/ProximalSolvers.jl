# Support-family ceiling with the same drop-budget ladder as Bm: C feasible for some εdrop ∈ ladder.
include(joinpath(@__DIR__, "oracleC.jl"))
out = open(joinpath(@__DIR__, "out", "oracleC_ladder.tsv"), "w")
println(out, join(["set","id","T","start","config","eps","status","tau","ratio_big_theta"], '\t'))
for pt in points()
  pt.set in ("M81", "OPTx") || continue
  TT = pt.T == "Float64" ? Float64 : Float32
  prob = problem(pt.id); X, y, λ = data(prob, TT); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  for e in (1e-6, 1e-5, 3e-5)
    c = oracleC(Xd, yd, λd, pt.β; εdrop = e)
    rb = c.θ === nothing ? NaN : bigcert(Xd, yd, λd, pt.β, c.θ).ratio
    println(out, join(Any[pt.set, pt.id, pt.T, pt.start, pt.config, e, c.status, c.τ, rb], '\t'))
  end
  flush(out)
end
close(out)
