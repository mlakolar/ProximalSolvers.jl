const FP = deserialize(joinpath(@__DIR__, "final_points.jls"))
function points()
  P = NamedTuple[]
  for r in FP
    set = r.class == "missed-cert(156)" ? "M81" : r.class == "nonoptimal(155)" ? "NEG" : continue
    push!(P, (; set, id = r.id, T = r.T, start = r.start, config = r.config, β = r.β))
  end
  for prob in ORACLE.probs, T in ("Float64", "Float32")
    o = oracle(prob.id, T == "Float64" ? Float64 : Float32)
    TT = T == "Float64" ? Float64 : Float32
    push!(P, (; set = o.exactfit ? "OPTx" : "OPTn", id = prob.id, T, start = "oracle", config = "-", β = Float64.(TT.(o.β))))
  end
  P
end

