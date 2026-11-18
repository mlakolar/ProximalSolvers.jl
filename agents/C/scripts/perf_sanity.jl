include(joinpath(@__DIR__, "perf_load.jl")); include("<RUN>/scripts/matrix.jl")
using Logging
X, y = noisy(60, 20, 4, 1.0, 401); λ = 0.1 * lammax(X, y)
res = Dict()
for v in VARS
  PS = mod(v); x = zeros(20)
  r = with_logger(NullLogger()) do; PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = :cyclic, momentum = false)) end
  res[v] = (copy(x), r.passes, r.converged, r.gap)
end
for v in VARS; println(v, " passes=", res[v][2], " conv=", res[v][3], " gap=", res[v][4], " identical to old: ", res[v][1] == res["old"][1]); end
