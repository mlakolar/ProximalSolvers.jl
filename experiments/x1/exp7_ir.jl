# X1 experiment 7: emit optimized LLVM IR / typed IR of coordinate_step! (SqrtLSModel{T}) for the three trees. julia --project=ps-353 exp7_ir.jl
include("x1lib.jl")
using InteractiveUtils
ver = "$(VERSION.major).$(VERSION.minor)"
for T in (Float32, Float64), t in TNAMES
  P = getproperty(TREES, t)
  M = P.SqrtLSModel{T, P.LSModel{T, T, Matrix{T}, Vector{T}}}
  sig = (M, NormL1{T, Nothing}, SparseIterate{T}, Int)
  open("ir/cs_$(T)_$(t)_$(ver).ll", "w") do io; code_llvm(io, P.coordinate_step!, sig; optimize = true, debuginfo = :none, dump_module = false); end
  # typed IR text
  open("ir/cs_$(T)_$(t)_$(ver).typed", "w") do io; ci = code_typed(P.coordinate_step!, sig; optimize = true); show(io, MIME("text/plain"), ci[1][1]); end
  open("ir/cs_$(T)_$(t)_$(ver).native", "w") do io; code_native(io, P.coordinate_step!, sig; debuginfo = :none); end
end
println("done")
