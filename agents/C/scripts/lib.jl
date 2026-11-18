# Agent C library: smoothing fallback H (research prototype built on the production solver with augmented
# data), BigFloat dual/primal bounds, stress problem generators.
include("<RUN>/scripts/common.jl")
using Statistics

# BigFloat residual-direction dual lower bound D_lo(β): θ = t r/‖r‖, t = min(1, λ/‖Xᵀr/‖r‖‖∞) (exactly
# feasible up to the 256-bit rounding, shaved by 1e-60). Returns 0 where r = 0 (undefined).
function dual_res_big(X, y, λ, β)
  Xb = big.(X); yb = big.(y); r = yb - Xb * big.(β)
  nr = norm(r)
  iszero(nr) && return big(0.0)
  G = maximum(abs, Xb' * r) / nr
  t = min(big(1), big(λ) / G)
  t * dot(r, yb) / nr * (1 - big(10)^-60)
end

# one smoothing stage: production solver on the augmented data [y; δ], [X; 0ᵀ]
function smooth_stage(X::Matrix{T}, y::Vector{T}, λ, β, δ; maxpasses = 20_000, kw...) where T
  Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(δ))
  x, r, sec, bytes = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses, kw...)
  x, r.passes, sec, bytes, r.converged
end

# Fallback H. `adaptive = false`: δ_j = c P(β_stuck) 10^-j (the orchestrator's hypothesis);
# `adaptive = true`: δ_j = c · (best original objective so far) · 10^-j' with the scale refreshed each stage.
# Returns a NamedTuple with the per-stage log and the final decision (all bounds in BigFloat).
function fallback(X::Matrix{T}, y::Vector{T}, λ, β0; c = 1e-2, stages = 6, adaptive = false, ratio_target = 1e-4,
                  maxpasses = 20_000, stop_at_cert = true, β_lo_scale = nothing) where T
  Pstuck = Pbig(X, y, λ, β0)
  bestβ = copy(β0); bestP = Pstuck
  bestD = dual_res_big(X, y, λ, β0)
  β = copy(β0); log = NamedTuple[]
  passes = 0; secs = 0.0; bytes = 0
  certified = false
  for j in 0:stages-1
    scale = adaptive ? bestP : Pstuck
    δ = c * Float64(scale) * (adaptive ? 1.0 : 10.0^(-j))
    if adaptive && j > 0
      δ = c * Float64(bestP) * 10.0^(-j)
    end
    β, ps, sec, by, conv = smooth_stage(X, y, λ, β, δ; maxpasses)
    passes += ps; secs += sec; bytes += by
    P = Pbig(X, y, λ, β); D = dual_res_big(X, y, λ, β)
    if P < bestP; bestP = P; bestβ = copy(β); end
    bestD = max(bestD, D)
    ratio = bestD > 0 ? Float64((bestP - bestD) / bestD) : Inf
    code, pr = certify_at(X, y, λ, β)
    push!(log, (; stage = j + 1, δ, passes = ps, sec, conv, P = Float64(P), D = Float64(D), nnz = count(!iszero, β),
                prodcode = code, prodratio = pr, ratio, improved = P < Pstuck))
    if ratio <= ratio_target
      certified = true
      stop_at_cert && break
    end
  end
  (; β = bestβ, Pstuck = Float64(Pstuck), P = Float64(bestP), D = Float64(bestD), ratio = bestD > 0 ? Float64((bestP - bestD)/bestD) : Inf,
     certified, passes, secs, bytes, log, nstages = length(log))
end

# stuck point of the production solver (cyclic, from β0); returns (β, converged, passes)
function stuck_point(X, y, λ, β0)
  x, r, _, _ = ps_solve(X, y, λ, β0; order = :cyclic, momentum = false)
  x, r.converged, r.passes
end

# Fallback with a schedule: sched = :fixed  → δ_j = c P(β_stuck) 10^(-step j)
#                           sched = :track  → δ_0 = c P(β_stuck), δ_{j+1} = min(δ_j 10^(-step), c P(best so far))
# `reltol`: if not nothing, the stage solve uses `tolerance = reltol * δ / ‖ỹ‖` hmm — not used here (production defaults).
function fallback2(X::Matrix{T}, y::Vector{T}, λ, β0; c = 1.0, step = 1.0, stages = 14, sched = :track,
                   ratio_target = 1e-4, maxpasses = 20_000, stop_at_cert = true) where T
  Pstuck = Pbig(X, y, λ, β0)
  bestβ = copy(β0); bestP = Pstuck; bestD = dual_res_big(X, y, λ, β0)
  β = copy(β0); log = NamedTuple[]; passes = 0; secs = 0.0; bytes = 0; certified = false
  δ = c * Float64(Pstuck)
  for j in 0:stages-1
    if j > 0
      δ = sched === :fixed ? c * Float64(Pstuck) * 10.0^(-step * j) : min(δ * 10.0^(-step), c * Float64(bestP))
    end
    β, ps, sec, by, conv = smooth_stage(X, y, λ, β, δ; maxpasses)
    passes += ps; secs += sec; bytes += by
    P = Pbig(X, y, λ, β); D = dual_res_big(X, y, λ, β)
    if P < bestP; bestP = P; bestβ = copy(β); end
    bestD = max(bestD, D)
    ratio = bestD > 0 ? Float64((bestP - bestD) / bestD) : Inf
    push!(log, (; stage = j + 1, δ, passes = ps, sec, conv, P = Float64(P), D = Float64(D), nnz = count(!iszero, β), ratio))
    if ratio <= ratio_target
      certified = true
      stop_at_cert && break
    end
  end
  (; β = bestβ, Pstuck = Float64(Pstuck), P = Float64(bestP), D = Float64(bestD), ratio = bestD > 0 ? Float64((bestP - bestD)/bestD) : Inf,
     certified, passes, secs, bytes, log, nstages = length(log))
end
