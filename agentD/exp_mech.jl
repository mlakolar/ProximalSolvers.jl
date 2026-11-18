using ProximalBase, ProximalSolvers, LinearAlgebra
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
# 1. public/export mechanics
println("PB exports: ", length(filter(n -> Base.isexported(PB, n), names(PB))))
@static if VERSION >= v"1.11"
  println("PB public non-exported: ", sort([n for n in names(PB) if Base.ispublic(PB, n) && !Base.isexported(PB, n)]))
  println("PS public: ", sort([n for n in names(PS) if Base.ispublic(PS, n)]))
else
  println("Base.ispublic defined: ", isdefined(Base, :ispublic), "; names(PB) lists only exports: ", length(names(PB)))
end
# a name not exported/public is still importable and callable on every version
println("PB.value_from_residual callable qualified: ", PB.value_from_residual(PB.LeastSquaresLoss([1.0],[2.0;;]), [3.0]))
# 2. inlining of a PB internal into a PS-side caller: no call to the PB method remains
callclean(s, n) = PS._clean_sum(s, n)
callpb(s, n) = PB._squares_normal(s, n, Float64)
for (nm, f) in (("PS._clean_sum", callclean), ("PB._squares_normal", callpb))
  ci = Base.code_typed(f, (Float64, Int); optimize = true)[1][1]
  nc = count(st -> st isa Expr && st.head in (:invoke, :call) && !(st.args[1] isa Core.IntrinsicFunction) && !(st.args[1] isa GlobalRef && st.args[1].mod in (Core, Base) && false), ci.code)
  invokes = count(st -> st isa Expr && st.head === :invoke, ci.code)
  println("code_typed(", nm, ") statements=", length(ci.code), " :invoke=", invokes)
end
# 3. norm of Float32 beyond Float32 range
y = Float32[3e38, 3e38]
println("LinearAlgebra.norm(Float32[3e38,3e38]) = ", norm(y), "   PS._scaled_norm -> ", PS._scaled_norm(y, 2), " (value ", ldexp(PS._scaled_norm(y,2)[1], PS._scaled_norm(y,2)[2]), ")  Float64(norm(Float64.(y))) = ", norm(Float64.(y)))
println("PB.norm_diff(y, zeros(Float32,2)) = ", PB.norm_diff(y, zeros(Float32, 2)))
