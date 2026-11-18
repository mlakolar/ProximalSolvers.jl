# Which calls remain out of line in coordinate_step!(::SqrtLSModel{T}) for each tree?
using InteractiveUtils
const ROOT = "<WORK>"
for (nm, tree) in (("base", "ps-353"), ("x1a", "ps-353-x1a"), ("x1b", "ps-353-x1b"))
  @eval module $(Symbol("M_", nm)); include(joinpath(Main.ROOT, $tree, "src/ProximalSolvers.jl")); end
end
using ProximalBase
for nm in (:M_base, :M_x1a, :M_x1b), T in (Float64,)
  PS = getfield(getfield(Main, nm), :ProximalSolvers)
  X = randn(T, 20, 10); y = randn(T, 20)
  f = ProximalBase.SqrtLeastSquaresLoss(y, X); x = ProximalBase.SparseIterate(zeros(T, 10))
  m = PS.cdmodel(f, x); g = ProximalBase.NormL1(T(0.1))
  ci = first(code_typed(PS.coordinate_step!, (typeof(m), typeof(g), typeof(x), Int); optimize = true))[1]
  inv = [string(st) for st in ci.code if st isa Expr && st.head in (:invoke, :call) && occursin(r"sqrt_|prox|shrink|_cold|_offrange|_band|throw|view|SubArray", string(st))]
  println(nm, " ", T, ": statements=", length(ci.code))
  foreach(s -> println("    ", first(s, 150)), unique(inv))
end
