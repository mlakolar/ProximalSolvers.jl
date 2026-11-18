# PROTOTYPE timing, NOT production evidence: the least-squares CD path (LSModel, shared with SqrtLSModel's ls field) across the 6 copies.
include(joinpath(@__DIR__, "perf_load.jl")); include("<RUN>/scripts/matrix.jl")
using Logging, Statistics
rng = Xoshiro(5); X, y = noisy(200, 50, 4, 1.0, 402); λ = 0.1 * lammax(X, y)
function run(PS, K); for _ in 1:K; x = zeros(50); PS.solve!(x, 0.5 / 200 * LeastSquaresLoss(y, X), NormL1(λ / 200), PS.CDSolver(order = :cyclic)); end; end
with_logger(NullLogger()) do
  for v in VARS; run(mod(v), 3); end
  K = 400; T = Dict(v => Float64[] for v in VARS)
  for rep in 1:40, v in shuffle(rng, VARS); push!(T[v], @elapsed(run(mod(v), K)) / K); end
  b = [mean((T["old"][i], T["ctl"][i])) for i in 1:40]
  for v in VARS; r = T[v] ./ b; println(v, " median ratio to mean(old,ctl) = ", round(median(r); digits = 3), "  IQR [", round(quantile(r, .25); digits = 3), ", ", round(quantile(r, .75); digits = 3), "]"); end
end
