# Why does H fail at λ ≤ 1e-3 λmax? Baseline from zero and from lnfit with growing pass budgets; smoothing stage budgets.
include(joinpath(@__DIR__, "lib.jl"))
S = deserialize(joinpath(@__DIR__, "..", "out", "hard_problems.jls"))
for id in ["SMALLLAM-n40p120-0.01", "SMALLLAM-n40p120-0.001", "SMALLLAM-n40p120-0.0001"]
  pr = only(filter(p -> p.id == id, S.probs)); rec = S.recs[(id, "Float64")]
  X, y, λ = data(pr, Float64); D = big(rec.D)
  println("== ", id, " λ=", λ, " ‖y‖=", norm(y), " P*=", rec.D, " P*/‖y‖=", rec.D / norm(y))
  for (sn, b0) in (("zero", zeros(size(X, 2))), pr.starts[1])
    for mp in (20_000, 200_000, 2_000_000)
      x, r, sec, _ = ps_solve(X, y, λ, b0; order = :cyclic, momentum = false, maxpasses = mp)
      c = classify(X, y, λ, x, rec)
      println("  base start=$sn maxpasses=$mp: converged=$(r.converged) passes=$(r.passes) sec=$(round(sec;digits=3)) excess=$(c.excess) nnz=$(c.nnz) tol=$(r.tolerance) maxchange=$(r.maxchange)")
    end
  end
end
