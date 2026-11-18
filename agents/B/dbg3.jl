include(joinpath(@__DIR__, "escape.jl"))
id = ARGS[1]; T = Float64
prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
cfg = cfgmaker("cyclic-dense")
x, r, _, _ = ps_solve(X, y, λ, start_point(prob, Symbol(ARGS[2]), o.β); cfg...)
println("stage1 F=", fhat(X,y,λ,x)[1], " Fstar=", o.U, " nnz=", count(!iszero,x), " oracle nnz=", o.nnz)
println("sorted |β| = ", sort(abs.(x[x .!= 0])))
x0 = Vector{T}(x)
let x = x0
for it in 1:12
  F0 = fhat(X, y, λ, x)
  d, u, ρ, ps, st = dirlasso(X, x, T(λ); maxpasses = 200, target = 2.0)
  ρ <= 1 + 1e-6 && (println("nodescent ρ=$ρ $st passes=$ps"); break)
  u64 = Float64.(X)*Float64.(d)
  t = line_min(F0[3], u64, x, d, λ)
  βn = apply_step(x, d, t)
  F1 = fhat(X, y, λ, βn)
  hit = [k for k in eachindex(x) if x[k] != 0 && βn[k] == 0]
  println("it $it ρ=$(round(ρ,digits=3)) ps=$ps st=$st t=$t hit=$hit |β_hit|=$(abs.(x[hit])) ΔF=$(F0[1]-F1[1]) E=$(F0[2]) strict=$(strict_decrease(F1,F0)) nnz $(count(!iszero,x))→$(count(!iszero,βn)) excess=$(classify(X,y,λ,βn,o).excess)")
  strict_decrease(F1,F0) || break
  x = βn
end
end
