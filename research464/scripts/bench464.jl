# Issue #464 timing workload: one process times every workload with the ProximalSolvers of its --project.
#   julia --project=<tree> bench464.jl <label> <slot> <out.tsv>
# Each workload: a warm-up solve, then REPS solves from a fresh copy of the start, timed with time_ns, with the
# allocations of one further solve. Iterations, counters, the objective and a hash of the returned coefficients are
# recorded, with an independent column-local KKT residual in BigFloat: maxⱼ Gⱼ / (‖Xⱼ‖ ‖r₀‖ + cⱼ), r₀ = y (LS) or
# y - ½ (logistic), which uses neither the solver's oracles nor any stopping rule's scale.
using LinearAlgebra, Printf, Random, Statistics, ProximalBase, ProximalSolvers
BLAS.set_num_threads(1)
setprecision(BigFloat, 128)

const LABEL, SLOT, OUT = ARGS[1], ARGS[2], ARGS[3]
const REPS = parse(Int, get(ENV, "BENCH_REPS", "40"))

sigmoid(t) = t >= 0 ? inv(1 + exp(-t)) : (e = exp(t); e / (1 + e))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

function design(n, p; ρ = 0.5, seed = 1)
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p)
  C = [ρ^abs(i - j) for i in 1:p, j in 1:p]
  X = Z * cholesky(C).U
  β = zeros(p); β[1:10] .= randn(rng, 10) .* 2
  X, X * β + randn(rng, n)
end

# objective in Float64-free BigFloat
function objective(loss, X, y, λ0, w, b)
  A, bb = big.(X), big.(b)
  η = A * bb
  c = w === nothing ? fill(big(λ0), length(b)) : big(λ0) .* big.(w)
  sm = loss === :ls ? sum(abs2, big.(y) - η) / 2 : sum(softplus.(η) .- big.(y) .* η)
  sm + sum(c .* abs.(bb))
end
function kkt_local(loss, X, y, λ0, w, b)
  A, bb = big.(X), big.(b)
  η = A * bb
  g = loss === :ls ? A' * (η - big.(y)) : A' * (sigmoid.(η) .- big.(y))
  c = w === nothing ? fill(big(λ0), length(b)) : big(λ0) .* big.(w)
  s = [iszero(bb[j]) ? max(abs(g[j]) - c[j], big(0)) : abs(g[j] + c[j] * sign(bb[j])) for j in eachindex(bb)]
  r0 = loss === :ls ? norm(big.(y)) : norm(big.(y) .- big(1) / 2)
  Float64(maximum(s ./ [norm(A[:, j]) * r0 + c[j] for j in eachindex(bb)]))
end

struct Workload
  name::String
  loss::Symbol
  method
  X
  y
  λ0
  w
end

function workloads()
  W = Workload[]
  X, y = design(1000, 500)
  λ = 0.1 * norm(X' * y, Inf)
  wo = 0.5 .+ 1.5 .* rand(MersenneTwister(3), 500)
  wx = copy(wo); wx[1] = 0.0; wx[end] = 1e6          # a free coordinate and an excluded one: v1 differs here
  for T in (Float64, Float32), (mn, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
    XT, yT = T.(X), T.(y)
    push!(W, Workload("LS unweighted $mn $T", :ls, m, XT, yT, T(λ), nothing))
    push!(W, Workload("LS weighted ordinary $mn $T", :ls, m, XT, yT, T(λ), T.(wo)))
    push!(W, Workload("LS weighted free+excluded $mn $T", :ls, m, XT, yT, T(λ), T.(wx)))
  end
  rng = MersenneTwister(7)
  Xl = randn(rng, 1000, 200)
  yl = Float64.(rand(rng, 1000) .< sigmoid.(Xl[:, 1:10] * randn(rng, 10) .+ 0.3))
  Xi = hcat(ones(1000), Xl)
  λl = 0.05 * norm(Xi' * (0.5 .- yl), Inf)
  wl = vcat(0.0, 0.5 .+ 1.5 .* rand(MersenneTwister(9), 200))
  wlx = copy(wl); wlx[end] = 1e6
  push!(W, Workload("logistic unweighted PGD", :logistic, ProximalGradientDescent(), Xl, yl, λl, nothing))
  push!(W, Workload("logistic weighted+intercept PGD", :logistic, ProximalGradientDescent(), Xi, yl, λl, wl))
  push!(W, Workload("logistic intercept+excluded PGD", :logistic, ProximalGradientDescent(), Xi, yl, λl, wlx))
  W
end

penalty(w::Workload) = w.w === nothing ? NormL1(w.λ0) : NormL1(w.λ0, w.w)
lossof(w::Workload) = w.loss === :ls ? LeastSquaresLoss(w.y, w.X) : LogisticLoss(w.y, w.X)
solve1(w::Workload, b) = solve!(b, lossof(w), penalty(w), w.method)

function main()
  rows = String[]
  for wk in workloads()
    T = eltype(wk.X)
    b = zeros(T, size(wk.X, 2))
    r = solve1(wk, b)                                  # warm-up and the recorded result
    times = Float64[]
    for _ in 1:REPS
      bb = zeros(T, size(wk.X, 2))
      t0 = time_ns(); solve1(wk, bb); push!(times, (time_ns() - t0) / 1e9)
    end
    bb = zeros(T, size(wk.X, 2))
    alloc = @allocated solve1(wk, bb)
    F = Float64(objective(wk.loss, wk.X, wk.y, wk.λ0, wk.w, b))
    K = kkt_local(wk.loss, wk.X, wk.y, wk.λ0, wk.w, b)
    push!(rows, join([LABEL, SLOT, wk.name, @sprintf("%.6e", median(times)), @sprintf("%.6e", minimum(times)),
      alloc, r.converged, r.iterations, r.f_calls, r.grad_calls, r.prox_calls, @sprintf("%.15e", F),
      @sprintf("%.3e", K), string(hash(b), base = 16)], '\t'))
    println(rows[end])
  end
  open(OUT, "a") do io
    foreach(r -> println(io, r), rows)
  end
end
main()
