# For each problem/T: continuation over a FINE δ grid (δ = P* 10^(-k/3), k = -3..24, descending δ, warm-started from
# the stuck point), logging the dual error err_D = (P* - D_res(β_δ))/P* and primal error err_P = (P(β_δ) - P*)/P*,
# and the best decoupled ratio (min P - max D)/max D along the way.
include(joinpath(@__DIR__, "lib.jl"))
S = deserialize(joinpath(@__DIR__, "..", "out", "stress_problems.jls"))
ids = ARGS
out = open(joinpath(@__DIR__, "..", "out", "delta_curves.tsv"), "w")
println(out, join(["id", "T", "k", "delta_over_Pstar", "passes", "nnz", "err_D", "err_P", "best_ratio_so_far", "prodcode", "prodratio"], '\t'))
for id in ids, T in (Float64, Float32)
  pr = only(filter(p -> p.id == id, S.probs)); rec = S.recs[(id, string(T))]
  X, y, λ = data(pr, T); Pst = rec.D
  β0, conv, _ = stuck_point(X, y, λ, T.(pr.starts[1][2]))
  β = copy(β0); bestP = Pbig(X, y, λ, β0); bestD = big(0.0)
  for k in -3:24
    δ = Pst * 10.0^(-k / 3)
    β, ps, _, _, _ = smooth_stage(X, y, λ, β, δ)
    P = Pbig(X, y, λ, β); D = dual_res_big(X, y, λ, β)
    bestP = min(bestP, P); bestD = max(bestD, D)
    code, pr_ = certify_at(X, y, λ, β)
    println(out, join([id, T, k, 10.0^(-k / 3), ps, count(!iszero, β), Float64((big(Pst) - D) / big(Pst)), Float64((P - big(Pst)) / big(Pst)),
                       Float64((bestP - bestD) / bestD), code, pr_], '\t')); flush(out)
  end
end
