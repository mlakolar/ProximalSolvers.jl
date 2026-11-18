include(joinpath(@__DIR__, "escape.jl"))
id = ARGS[1]; T = Float64
prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
cfg = cfgmaker("cyclic-dense")
x, r, _, _ = ps_solve(X, y, λ, start_point(prob, Symbol(ARGS[2]), o.β); cfg...)
println("stage1 passes=", r.passes, " F=", fhat(X,y,λ,x)[1], " Fstar=", o.U, " nnz=", count(!iszero,x), " oracle nnz=", o.nnz)
for e in 1:8
  βn, info = escape_Cm(X, y, λ, x; inner = parse(Int, ARGS[3]))
  println("esc $e: ", info)
  βn === nothing && break
  println("   after escape: nnz=", count(!iszero,βn), " F=", fhat(X,y,λ,βn)[1], " excess=", classify(X,y,λ,βn,o).excess, " rrel=", classify(X,y,λ,βn,o).rrel)
  x2, r2, _, _ = ps_solve(X, y, λ, βn; cfg...)
  c = classify(X,y,λ,x2,o)
  println("   resumed: passes=$(r2.passes) conv=$(r2.converged) nnz=$(c.nnz) rrel=$(c.rrel) excess=$(c.excess)")
  global x = x2
  r2.converged && break
end
