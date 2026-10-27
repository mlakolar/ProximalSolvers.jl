# Bounded exploratory measurements for the release follow-up issues.
# Run each source edition in a fresh process with the same dependency manifest.
using ProximalBase, ProximalSolvers, LinearAlgebra, Random, Statistics
BLAS.set_num_threads(1)
family = isempty(ARGS) ? "newton" : only(ARGS)
rng = Xoshiro(90210)
n, p = family == "newton" ? (400, 40) : (120, 40)
X = randn(rng, n, p)
y = X[:, 1:4] * [1.0, -1.0, 0.5, -0.5] + randn(rng, n)
if family == "newton"
  f = (1 / n) * LogisticLoss(Float64.(y .> 0), X)
  g, method = NormL1(0.05), ProxNewton()
elseif family == "sqrt"
  f, g, method = SqrtLeastSquaresLoss(y, X), NormL1(0.5), CDSolver(rng = Xoshiro(9))
else
  f, g = (1 / n) * LeastSquaresLoss(y, X), NormL1(0.05)
  methods = Dict("pg" => ProximalGradientDescent(), "apg" => AccProxGradDescent(),
                 "monotone" => MonotoneAccProxGradDescent(),
                 "active" => ActiveAccProxGradDescent(),
                 "cd" => CDSolver(rng = Xoshiro(9)), "admm" => ADMMSolver())
  haskey(methods, family) || error("choose newton, sqrt, pg, apg, monotone, active, cd or admm")
  method = methods[family]
end
x = zeros(p)
function runfit!(x, f, g, method)
  fill!(x, 0)
  solve!(x, f, g, method)
end
runfit!(x, f, g, method)  # compilation, buffers and loss factorization warmup
samples = [@timed runfit!(x, f, g, method) for _ in 1:9]
res = samples[end].value
println("Julia=", VERSION, " Julia_threads=", Threads.nthreads(), " BLAS=", BLAS.get_config())
println("CPU=", Sys.CPU_NAME, " family=", family, " n=", n, " p=", p)
println("seconds_min_median_max=", extrema(s.time for s in samples)[1], ",",
        median(s.time for s in samples), ",", extrema(s.time for s in samples)[2])
println("bytes_median=", median(s.bytes for s in samples), " converged=", res.converged,
        " objective=", f(x) + g(x))
if family == "sqrt"
  r = y - X*x
  grad = -(X'r) / norm(r)
else
  grad = zeros(p)
  ProximalBase.gradient!(grad, f, x)
end
trial = zeros(p)
ProximalBase.prox!(trial, g, x-grad, 1.0)
println("unit_prox_residual=", norm(x-trial, Inf))
# A small timing difference is not conclusive. Check the acceptance target and
# use a pinned runner, paired source editions and matched accuracy for decisions.
