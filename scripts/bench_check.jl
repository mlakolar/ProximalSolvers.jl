# #351: cost of the level conversion and of the stop check (the body of PS._stationary! after the gradient),
# for the current conversion (base, and an identical copy as the A/A control), A (@noinline helper),
# B (helper only for Float32), C (coefficients converted once, passed in). Caller-shaped: the check is
# inlined into a loop over a pool of fresh (grad, x) pairs, results summed. One process, rounds interleaved.
using ProximalSolvers, ProximalBase, Random, Printf, Statistics
const PS = ProximalSolvers

@noinline lvlA(::Type{T}, λ) where T = T(λ)
lvlB(::Type{Float32}, λ) = lvlA(Float32, λ)
@inline lvlB(::Type{T}, λ) where T = T(λ)

@inline conv_base(g::NormL1, ::Type{T}) where T = NormL1(T(g.λ0))
@inline conv_base(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))
@inline conv_aa(g::NormL1, ::Type{T}) where T = NormL1(T(g.λ0))
@inline conv_aa(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))
@inline conv_A(g::ElasticNet, ::Type{T}) where T = ElasticNet(lvlA(T, g.λ1), lvlA(T, g.λ2))
@inline conv_B(g::ElasticNet, ::Type{T}) where T = ElasticNet(lvlB(T, g.λ1), lvlB(T, g.λ2))

struct Base_ end; struct AA end; struct A_ end; struct B_ end; struct C_ end
@inline penalty(::Base_, g, gT, T) = conv_base(g, T)
@inline penalty(::AA, g, gT, T) = conv_aa(g, T)
@inline penalty(::A_, g, gT, T) = conv_A(g, T)
@inline penalty(::B_, g, gT, T) = conv_B(g, T)
@inline penalty(::C_, g, gT, T) = gT

# the stop check of _stationary! (PGD: the gradient is stored; λmax cached)
@inline function check(v, g, gT, grad::Vector{T}, x::Vector{T}, λmax::T, τ::T) where T
  h = penalty(v, g, gT, T)
  λ = PS._l1_level(h)
  r = kkt_violation(h, grad, x)
  S = max(λ, λmax)
  thr = τ * S
  isfinite(S) & (thr >= floatmin(T)) & isfinite(r) & (r < thr)
end
function checks!(v, g, gT, pool, λmax::T, τ::T) where T
  c = 0
  for (grad, x) in pool
    c += check(v, g, gT, grad, x, λmax, τ)
  end
  c
end
# the conversion alone, inlined in a loop over a pool of penalties with different levels
function convs(v, gs, ::Type{T}) where T
  s = zero(T)
  for g in gs
    h = penalty(v, g, nothing, T)
    s += h.λ1 + h.λ2
  end
  s
end

function timeit(f, reps)
  f()
  best = typemax(Float64)
  for _ in 1:reps
    t = time_ns(); f(); best = min(best, (time_ns() - t))
  end
  best
end

println("Julia ", VERSION, " | ", Sys.CPU_NAME, " | threads ", Threads.nthreads())
variants = (("base", Base_()), ("A/A", AA()), ("A", A_()), ("B", B_()), ("C", C_()))
rng = Xoshiro(351)
for T in (Float32, Float64), (lname, mk) in (("native T", λ -> T(λ)), ("Float64", λ -> Float64(λ)), ("Rational", λ -> rationalize(Int64, Float64(λ); tol = 1e-12)))
  T == Float64 && lname == "Float64" && continue
  # conversion only: 4096 penalties
  gs = [ElasticNet(mk(0.1 + rand(rng)), mk(0.05 * rand(rng))) for _ in 1:4096]
  res = Dict{String, Vector{Float64}}()
  for round in 1:7, (vn, v) in (round % 2 == 0 ? reverse(variants) : variants)
    vn == "C" && continue
    push!(get!(res, vn, Float64[]), timeit(() -> convs(v, gs, T), 50) / length(gs))
  end
  @printf("%-7s level %-8s  conversion only (ns/penalty):  %s\n", T, lname,
          join([@sprintf("%s %.2f", vn, median(res[vn])) for (vn, _) in variants if vn != "C"], " | "))
  for p in (32, 500, 5000)
    K = max(8, 2^20 ÷ (8p))           # pool of K pairs, ~8 MB of data
    pool = [(randn(rng, T, p), (x = randn(rng, T, p); x[rand(rng, p) .< 0.6] .= 0; x)) for _ in 1:K]
    g = ElasticNet(mk(0.3), mk(0.05)); gT = conv_base(g, T)
    λmax, τ = T(1), T(64 * eps(T))
    res = Dict{String, Vector{Float64}}()
    for round in 1:7, (vn, v) in (round % 2 == 0 ? reverse(variants) : variants)
      push!(get!(res, vn, Float64[]), timeit(() -> checks!(v, g, gT, pool, λmax, τ), 15) / K)
    end
    b = median(res["base"])
    @printf("%-7s level %-8s p=%-5d check (ns): base %.1f | %s\n", T, lname, p, b,
            join([@sprintf("%s %+.2f ns (%+.1f%%)", vn, median(res[vn]) - b, 100 * (median(res[vn]) / b - 1)) for (vn, _) in variants if vn != "base"], " | "))
  end
end
