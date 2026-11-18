# INDICATIVE ONLY (shared machine, single process, interleaved reps): time of 200 passes of coordinate_step! over p coordinates, ordinary data,
# state kept at the optimum-ish (warmed 30 passes). The orchestrator runs the controlled timing.
include("x1lib.jl")
function mk(P, X::Matrix{T}, y::Vector{T}, λ) where T
  f = SqrtLeastSquaresLoss(y, X); x = SparseIterate(zeros(T, size(X, 2)))
  m = P.cdmodel(f, x); P.initialize!(m, x); g = NormL1(λ); P._prepare!(m, g, x); m, g, x
end
function passes!(cs::F, m, g, x, p, reps) where F
  for _ in 1:reps, k in 1:p; cs(m, g, x, k); end
  nothing
end
println("# Julia ", VERSION, " INDICATIVE timings: median ns per visit over 15 interleaved reps of 200 passes")
for T in (Float32, Float64), (n, p) in ((20, 10), (100, 60), (500, 40))
  rng = Xoshiro(3); X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(0.1 * norm(Float64.(X)' * Float64.(y), Inf) / norm(Float64.(y)))
  st = Dict(t => mk(getproperty(TREES, t), X, y, λ) for t in TNAMES)
  css = Dict(t => getproperty(TREES, t).coordinate_step! for t in TNAMES)
  for t in TNAMES; passes!(css[t], st[t]..., p, 30); end
  times = Dict(t => Float64[] for t in TNAMES)
  for rep in 1:15, t in TNAMES
    el = @elapsed passes!(css[t], st[t]..., p, 200)
    push!(times[t], el / (200p) * 1e9)
  end
  med(v) = sort(v)[8]
  println(T, " n=", n, " p=", p, ": ", join([@sprintf("%s %.1f ns (min %.1f)", t, med(times[t]), minimum(times[t])) for t in TNAMES], " | "))
end
