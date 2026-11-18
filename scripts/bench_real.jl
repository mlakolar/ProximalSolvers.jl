# #351: the real PS._stationary! (per call, on a real solver state) and whole solve! times, for the
# conversion variants, switched by redefining PS._converted_penalty(::ElasticNet, T) in this one process.
# Rounds interleave base, A/A (identical redefinition), A, B and C0. C0 = no conversion and no rebuild
# (returns g; valid only for levels already of type T), a lower bound for what conversion-once could save
# per check. Run: julia --project=<PS 8d2a30e> bench_real.jl
using ProximalSolvers, ProximalBase, Random, Printf, Statistics, LinearAlgebra
const PS = ProximalSolvers
include(joinpath(pkgdir(ProximalSolvers), "benchmark", "problems.jl"))
BLAS.set_num_threads(1)

@eval PS @noinline _lvlA(::Type{T}, λ) where T = T(λ)
@eval PS _lvlB(::Type{Float32}, λ) = _lvlA(Float32, λ)
@eval PS _lvlA2(::Type{T}, λ::T) where T = λ
@eval PS @noinline _lvlA2(::Type{T}, λ) where T = T(λ)
@eval PS @inline _lvlB(::Type{T}, λ) where T = T(λ)
const DEFS = Dict(
  "base" => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))),
  "A/A"  => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))),
  "A"    => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_lvlA(T, g.λ1), _lvlA(T, g.λ2))),
  "B"    => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_lvlB(T, g.λ1), _lvlB(T, g.λ2))),
  "A'"   => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_lvlA2(T, g.λ1), _lvlA2(T, g.λ2))),
  "C0"   => :(_converted_penalty(g::ElasticNet, ::Type{T}) where T = g))
const ORDER = ["base", "A/A", "A", "A'", "B", "C0"]
use!(v) = Core.eval(PS, DEFS[v])

function stat_ns(state, f, g, o, n)
  PS._stationary!(state, f, g, o)
  best = typemax(UInt64)
  for _ in 1:n
    t = time_ns(); PS._stationary!(state, f, g, o); best = min(best, time_ns() - t)
  end
  Float64(best)
end
function solve_ns(x0, f, g, m, o, n)
  x = copy(x0); solve!(x, f, g, m, o)
  ts = Float64[]
  for _ in 1:n
    copyto!(x, x0); t = time_ns(); solve!(x, f, g, m, o); push!(ts, time_ns() - t)
  end
  median(ts)
end

println("Julia ", VERSION, " | ", Sys.CPU_NAME, " | BLAS threads ", BLAS.get_num_threads())
o = ProximalOptions()
for T in (Float32, Float64), (des, n, p, s) in ((:A, 100, 32, 5), (:B, 200, 500, 10), (:C, 1000, 200, 20))
  d = lasso_design(des, 1; n, p, s)
  X = T.(d.X); y = T.(d.y); f = (one(T) / T(n)) * LeastSquaresLoss(y, X)
  λ1 = T(0.1lambda_max(d.X, d.y))
  for (lname, g) in (("native", ElasticNet(λ1, T(0.05))), ("Rational", ElasticNet(rationalize(Int64, Float64(λ1); tol = 1e-12), 1 // 20)))
    for (mname, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
      x0 = zeros(T, p)
      st = Dict(v => Float64[] for v in ORDER); sv = Dict(v => Float64[] for v in ORDER)
      for round in 1:7, v in (isodd(round) ? ORDER : reverse(ORDER))
        (v == "C0" && lname != "native") && continue
        use!(v)
        state = Base.invokelatest(PS.initial_state, m, o, f, g, copy(x0))
        push!(st[v], Base.invokelatest(stat_ns, state, f, g, o, 2000))
        push!(sv[v], Base.invokelatest(solve_ns, x0, f, g, m, o, n * p <= 5000 ? 2000 : 60))
      end
      use!("base")
      b, bs = median(st["base"]), median(sv["base"])
      fmt(v) = isempty(st[v]) ? "" : @sprintf(" %s %+.1f ns / solve %+.2f%%", v, median(st[v]) - b, 100 * (median(sv[v]) / bs - 1))
      @printf("%-7s %s %4d×%-4d %-8s %s  _stationary! %.0f ns, solve %.1f µs |%s\n", T, des, n, p, lname, mname, b, bs / 1e3,
              join(fmt.(ORDER[2:end]), " |"))
    end
  end
end
