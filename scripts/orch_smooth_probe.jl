# Orchestrator's quick feasibility probe of smoothing continuation, using only the production solver:
# F_δ(β) = √(‖y − Xβ‖² + δ²) + λ‖β‖₁ is the square-root lasso on the augmented data [y; δ], [X; 0ᵀ].
# From the baseline's final point, solve F_δ for δ = δ0·10^-j (j = 0, 1, ...), warm-started, and after each
# stage call the production certificate for the ORIGINAL objective at the stage's point.
include(joinpath(@__DIR__, "common.jl"))
function smooth_stage(X::Matrix{T}, y::Vector{T}, λ, β, δ) where T
  Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(δ))
  x, r, sec, _ = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses = 20_000)
  x, r.passes, sec
end
function continuation(X::Matrix{T}, y::Vector{T}, λ, β0; stages = 8, c0 = 1e-2) where T
  P0 = Float64(Pbig(X, y, λ, β0))
  β = copy(β0); passes = 0
  for j in 0:stages-1
    δ = c0 * P0 * 10.0^(-j)
    β, ps, _ = smooth_stage(X, y, λ, β, δ)
    passes += ps
    code, ratio = certify_at(X, y, λ, β)
    code === :certified && return β, j + 1, passes, ratio, δ
  end
  β, -1, passes, NaN, NaN
end
ids = ["A155", "A156", "AI3", "N8p20-0.05-s1", "N8p20-0.2-s1", "N8p20-0.2-s4", "N40p120-0.05-s1", "N40p120-0.2-s1",
       "N100p400-s1", "NE1.0e-7-s1", "SW0.3-s2", "SW0.4-s1", "C95-s2", "D10-s1", "O60p20-s1"]
for id in ids, T in (Float64, Float32)
  prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
  sk = :given in prob.starts ? :given : :lnfit
  x, r, _, _ = ps_solve(X, y, λ, start_point(prob, sk, o.β); order = :cyclic, momentum = false)
  c0 = classify(X, y, λ, x, o)
  β, stage, passes, ratio, δ = continuation(X, y, λ, x)
  c = classify(X, y, λ, β, o)
  @printf "%-18s %-7s start=%-5s base: conv=%d excess=%.2e | smooth: stage=%2d passes=%5d ratio=%.2e δ=%.1e excess=%.2e decreased=%s nnz=%d (n=%d)\n" id T sk r.converged c0.excess stage passes ratio δ c.excess (c.excess < c0.excess) c.nnz size(X, 1)
end
