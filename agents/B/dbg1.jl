include(joinpath(@__DIR__, "escape.jl"))
id = "N8p20-0.2-s1"; T = Float64
prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
cfg = cfgmaker("cyclic-dense")
x, r, _, _ = ps_solve(X, y, λ, start_point(prob, :zero, o.β); cfg...)
println("stage1 passes=", r.passes, " F=", fhat(X,y,λ,x)[1], " Fstar=", o.U, " nnz=", count(!iszero,x), " rrel=", classify(X,y,λ,x,o).rrel)
println("oracle nnz=", o.nnz, "  oracle exact=", o.exactfit)
for e in 1:6
  F0 = fhat(X, y, λ, x)
  d, u, ρ, ps, st = dirlasso(X, x, T(λ); maxpasses = 200, target = 2.0)
  println("esc $e: ρ=$ρ passes=$ps st=$st ‖u‖=$(norm(u)) ‖d‖=$(norm(d)) nnz(d)=$(count(!iszero,d)) F0=$(F0[1]) E0=$(F0[2])")
  u64 = Float64.(X)*Float64.(d)
  t = line_min(F0[3], u64, x, d, λ)
  βn = apply_step(x, d, t)
  F1 = fhat(X, y, λ, βn)
  println("   t=$t F1=$(F1[1]) E1=$(F1[2]) strict=$(strict_decrease(F1,F0))  nnz(new)=$(count(!iszero,βn))")
  x2, r2, _, _ = ps_solve(X, y, λ, βn; cfg...)
  println("   resumed: passes=$(r2.passes) F=$(fhat(X,y,λ,x2)[1]) conv=$(r2.converged) nnz=$(count(!iszero,x2)) rrel=$(classify(X,y,λ,x2,o).rrel) excess=$(classify(X,y,λ,x2,o).excess)")
  global x = x2
end
