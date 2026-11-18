include(joinpath(@__DIR__, "lib.jl"))
S = deserialize(joinpath(@__DIR__, "..", "out", "hard_problems.jls"))
pr = only(filter(p -> p.id == "SMALLLAM-n40p120-0.001", S.probs)); rec = S.recs[("SMALLLAM-n40p120-0.001", "Float64")]
X, y, λ = data(pr, Float64)
for tol in (1e-7, 1e-10, 1e-13, 0.0)
  x, r, sec, _ = ps_solve(X, y, λ, zeros(120); order = :cyclic, momentum = false, tol, maxpasses = 200_000)
  c = classify(X, y, λ, x, rec)
  println("base zero tol=$tol converged=$(r.converged) passes=$(r.passes) excess=$(c.excess) rrel=$(c.rrel) nnz=$(c.nnz) gap=$(r.gap)")
end
# smoothing stage solves with stage tolerance tied to δ (κ δ absolute change threshold)
function stage_kappa(X, y, λ, β, δ, κ; maxpasses = 200_000)
  Xa = vcat(X, zeros(1, size(X, 2))); ya = vcat(y, δ)
  x, r, sec, _ = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses, tol = κ * δ / norm(ya))
  x, r.passes, r.converged
end
β0, conv, _ = stuck_point(X, y, λ, pr.starts[1][2])
for κ in (1e-2, 1e-4, 1e-6)
  β = copy(β0); Pst = Float64(Pbig(X, y, λ, β0)); tp = 0
  println("κ=$κ")
  for j in 0:8
    δ = Pst * 10.0^(-j)
    β, ps, cv = stage_kappa(X, y, λ, β, δ, κ); tp += ps
    P = Pbig(X, y, λ, β); D = dual_res_big(X, y, λ, β)
    println("   j=$j δ/P*=$(δ/rec.D) passes=$ps conv=$cv errP=$(Float64((P-big(rec.D))/big(rec.D))) errD=$(Float64((big(rec.D)-D)/big(rec.D))) nnz=$(count(!iszero,β))")
  end
end
