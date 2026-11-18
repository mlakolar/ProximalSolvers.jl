using InteractiveUtils, LinearAlgebra
const ROOT = "<WORK>"
for (nm, tree) in (("base", "ps-353"), ("x1c", "ps-353-x1c"), ("x1d", "ps-353-x1d"))
  @eval module $(Symbol("M_", nm)); include(joinpath(Main.ROOT, $tree, "src/ProximalSolvers.jl")); end
end
using ProximalBase
for nm in (:M_base, :M_x1c, :M_x1d), T in (Float64, Float32)
  PS = getfield(getfield(Main, nm), :ProximalSolvers)
  X = randn(T, 20, 10); y = randn(T, 20)
  f = ProximalBase.SqrtLeastSquaresLoss(y, X); x = ProximalBase.SparseIterate(zeros(T, 10))
  m = PS.cdmodel(f, x); g = ProximalBase.NormL1(T(0.1)); PS.initialize!(m, x); PS._prepare!(m, g, x)
  rt = Base.return_types(PS._sqrt_minimizer, (typeof(m), T, T, T, T, Int))
  ci = first(code_typed(PS._sqrt_minimizer, (typeof(m), T, T, T, T, Int)))[1]
  calls = [replace(string(st), r"\s+" => " ") for st in ci.code if st isa Expr && st.head === :invoke]
  io = IOBuffer(); code_llvm(io, PS._sqrt_minimizer, (typeof(m), T, T, T, T, Int); debuginfo = :none); ll = String(take!(io))
  println(nm, " ", T, ": rt=", rt, " stmts=", length(ci.code), " invokes=", length(calls), " llvm_lines=", count(==('\n'), ll),
          " fdiv=", count("fdiv", ll), " sqrt=", count("llvm.sqrt", ll), " fcmp=", count("fcmp", ll), " br=", count(" br ", ll), " call=", count(r"call .*@j_|call .*julia_", ll), " alloca=", count("alloca", ll), " gcframe=", occursin("gcframe", ll) || occursin("pgcstack", ll))
  foreach(c -> println("     ", first(c, 170)), calls)
end
