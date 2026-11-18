# Float32 certification analysis: (1) residual resolution u32‖μ‖/‖r‖ vs dual error along the δ chain; (2) a Float64 witness: the same δ chain run on
# Float64 COPIES of the Float32 data (identical numbers), D from the Float64 points, primal candidate = Float32 rounding of the Float64 points.
include(joinpath(@__DIR__, "stress.jl"))
S = deserialize(joinpath(@__DIR__, "..", "out", "stress_problems.jls"))
u32 = Float64(eps(Float32)) / 2
out = open(joinpath(@__DIR__, "..", "out", "f32_analysis.tsv"), "w")
println(out, join(["id", "k", "delta_over_Pstar", "norm_r_over_Pstar", "noise_q", "errD_f32chain", "errD_f64chain", "errP_f32chain", "errP_round32_of_f64chain", "witness_ratio_f64D_vs_round32P", "f32only_best_ratio"], '\t'))
for id in ["LARGE-n100p1000-0.1", "TINY12-n20p60", "FLOOR1.0e-6-n30p80-s1", "DUP-n15p40-s1", "HUGE-n20p60-s1", "LAMC0.5-n10p30-s1"]
  pr = only(filter(p -> p.id == id, S.probs)); rec = S.recs[(id, "Float32")]; Ps = rec.D
  X, y, λ = data(pr, Float32); X64, y64, λ64 = Float64.(X), Float64.(y), Float64(λ)
  β0, _, _ = stuck_point(X, y, λ, Float32.(pr.starts[1][2]))
  β32 = copy(β0); β64 = Float64.(β0); bestD32 = big(0.0); bestD64 = big(0.0); bestP32 = Pbig(X, y, λ, β0); bestPr = bestP32
  for k in -3:3:18
    δ = Ps * 10.0^(-k / 3)
    β32, _ = smooth_stage(X, y, λ, β32, δ)
    β64, _ = smooth_stage(X64, y64, λ64, β64, δ)
    r = big.(y) - big.(X) * big.(β32); nr = Float64(norm(r)); μ = norm(abs.(big.(y)) + abs.(big.(X)) * abs.(big.(β32))); q = u32 * Float64(μ) / nr
    D32 = dual_res_big(X, y, λ, β32); D64 = dual_res_big(X, y, λ, β64)
    bestD32 = max(bestD32, D32); bestD64 = max(bestD64, D64)
    P32 = Pbig(X, y, λ, β32); bestP32 = min(bestP32, P32)
    b32r = Float32.(β64); Pr = Pbig(X, y, λ, b32r); bestPr = min(bestPr, Pr)
    Pb = big(Ps)
    println(out, join([id, k, 10.0^(-k / 3), nr / Ps, q, Float64((Pb - D32) / Pb), Float64((Pb - D64) / Pb), Float64((P32 - Pb) / Pb), Float64((Pr - Pb) / Pb),
                       Float64((bestPr - bestD64) / bestD64), Float64((bestP32 - bestD32) / bestD32)], '\t')); flush(out)
  end
end
close(out)
