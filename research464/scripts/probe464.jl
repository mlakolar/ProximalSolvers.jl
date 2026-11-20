# Issue #464: cost of the weighted-NormL1 stationarity decision, shipped (v0) against the per-entry rule (v1), with
# an A/A copy of v0, in one process. Each call forms the converted penalty, λ = λ0 maximum(w), the full-point
# kkt_violation and the threshold, as _stationary! does after its gradient is available; v1 then runs the
# per-entry loop when λ > λmax. Inputs come from a pool of K independent (grad, x, w) sets so that a call does
# not reuse the arrays of the previous one; the variants are timed in a random order in each of R rounds.
#   julia --project=<tree> probe464.jl <out.tsv>
using LinearAlgebra, Printf, Random, Statistics, ProximalBase
BLAS.set_num_threads(1)

@noinline function check_v0(g, grad, x, λmax, τ::T) where T
  gT = NormL1(T(g.λ0), g.w)
  λ = gT.λ0 * maximum(gT.w)
  r = kkt_violation(gT, grad, x)
  S = max(λ, λmax); t = τ * S
  isfinite(S) && t >= floatmin(T) && isfinite(r) && r < t
end
@noinline function check_v0copy(g, grad, x, λmax, τ::T) where T
  gT = NormL1(T(g.λ0), g.w)
  λ = gT.λ0 * maximum(gT.w)
  r = kkt_violation(gT, grad, x)
  S = max(λ, λmax); t = τ * S
  isfinite(S) && t >= floatmin(T) && isfinite(r) && r < t
end
@noinline function check_v1(g, grad, x, λmax, τ::T) where T
  gT = NormL1(T(g.λ0), g.w)
  λ = gT.λ0 * maximum(gT.w)
  r = kkt_violation(gT, grad, x)
  S = max(λ, λmax); t = τ * S
  (isfinite(S) && t >= floatmin(T) && isfinite(r) && r < t) || return false
  λ <= λmax && return true
  @inbounds for i in eachindex(x, grad, gT.w)
    ti = τ * max(gT.λ0 * gT.w[i], λmax)
    (ti >= floatmin(T) && kkt_violation(gT, grad, x, i) < ti) || return false
  end
  true
end

# a near-stationary point: half the entries zero with |∇fᵢ| < cᵢ, the others with ∇fᵢ = -cᵢ sign xᵢ up to τ/10
function inputs(T, p, regime, rng)
  w = T.(0.5 .+ 1.5 .* rand(rng, p))
  regime === :excluded && (w[end] = T(1e6))
  λ0 = one(T)
  c = λ0 .* w
  x = T.(randn(rng, p)); x[1:2:end] .= 0
  grad = similar(x)
  for i in 1:p
    grad[i] = iszero(x[i]) ? T(0.5) * c[i] * T(rand(rng) - 0.5) : -c[i] * sign(x[i]) * (1 + T(1e-7) * T(randn(rng)))
  end
  λmax = T(3)                                       # above every ordinary coefficient; below the excluded one
  NormL1(λ0, w), grad, x, λmax
end

function main(out)
  rows = String[]
  for T in (Float64, Float32), p in (100, 10_000, 1_000_000), regime in (:ordinary, :excluded)
    K = p >= 1_000_000 ? 4 : 64
    R = p >= 1_000_000 ? 15 : 41
    N = max(1, 2_000_000 ÷ p)                        # calls per timing
    rng = MersenneTwister(p)
    pool = [inputs(T, p, regime, rng) for _ in 1:K]
    τ = T(1e-5)
    fs = (v0 = check_v0, v0copy = check_v0copy, v1 = check_v1)
    res = Dict(k => Float64[] for k in keys(fs))
    decisions = Dict(k => [f(pool[1]..., τ) for _ in 1:1] for (k, f) in pairs(fs))
    for (k, f) in pairs(fs)                              # warm-up
      for q in pool; f(q..., τ); end
    end
    for round in 1:R
      for k in shuffle(MersenneTwister(round), collect(keys(fs)))
        f = fs[k]
        acc = 0
        t0 = time_ns()
        for j in 1:N
          q = pool[mod1(j, K)]
          acc += f(q..., τ)
        end
        dt = (time_ns() - t0) / N
        acc < 0 && println("never")
        push!(res[k], dt)
      end
    end
    m0 = median(res[:v0])
    for k in (:v0, :v0copy, :v1)
      push!(rows, join([string(T), p, regime, k, @sprintf("%.1f", median(res[k])), @sprintf("%.4f", median(res[k]) / m0),
        @sprintf("%.3f", median(res[k]) / p), decisions[k][1]], '\t'))
      println(rows[end])
    end
  end
  open(out, "w") do io
    println(io, join(["T", "p", "regime", "variant", "ns_per_call", "ratio_to_v0", "ns_per_entry", "decision"], '\t'))
    foreach(r -> println(io, r), rows)
  end
end
main(isempty(ARGS) ? "probe464.tsv" : ARGS[1])
