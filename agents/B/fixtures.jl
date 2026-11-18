include(joinpath(@__DIR__, "escape.jl"))
for T in (Float64, Float32), id in ("A155", "A156", "AI3")
  prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
  β0 = start_point(prob, :given, o.β)
  cfg = cfgmaker("cyclic-dense")
  x, r, _, _ = ps_solve(X, y, λ, β0; cfg...)
  println("== $id $T stage1 x=$x conv=$(r.converged) F=$(fhat(X,y,λ,x)[1])")
  for (name, f) in (("C", escape_C), ("B", escape_B), ("A1", escape_A1))
    βn, info = f(X, y, λ, x)
    println("  $name: ", info, " β_new=", βn)
  end
  for (name, fb) in (("C", (args...) -> fallback_escape(args..., escape_C)), ("B", (args...)->fallback_escape(args..., escape_B)), ("D", fallback_D), ("E", fallback_E), ("A2", fallback_A2))
    xf, rf, info = fb(X, y, λ, x, r, cfg)
    c = classify(X, y, λ, xf, o)
    println("  pipeline $name: conv=$(rf.converged) excess=$(c.excess) nnz=$(c.nnz) ", info)
  end
end
