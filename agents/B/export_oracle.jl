# Julia 1.13: write the oracle fields and data checksums needed on Julia 1.10 to a plain TSV.
include(joinpath(@__DIR__, "..", "..", "scripts", "common.jl"))
open(joinpath(@__DIR__, "out", "oracle_plain.tsv"), "w") do io
  println(io, join(["id", "T", "D", "U", "exactfit", "rrel", "nnz", "xnorm", "ynorm", "lam", "beta"], '\t'))
  for prob in ORACLE.probs, T in ("Float64", "Float32")
    o = ORACLE.recs[(prob.id, T)]
    println(io, join([prob.id, T, repr(o.D), repr(o.U), o.exactfit, repr(o.rrel), o.nnz, repr(norm(prob.X)), repr(norm(prob.y)), repr(prob.λ),
                      join(repr.(o.β), ';')], '\t'))
  end
end
open(joinpath(@__DIR__, "out", "data_plain.tsv"), "w") do io
  for prob in ORACLE.probs
    println(io, join([prob.id, size(prob.X, 1), size(prob.X, 2), repr(prob.λ), join(repr.(prob.y), ';'), join(repr.(vec(prob.X)), ';')], '\t'))
  end
end
