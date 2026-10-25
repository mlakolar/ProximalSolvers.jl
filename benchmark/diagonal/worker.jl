using ProximalBase, ProximalSolvers, Random, LinearAlgebra
BLAS.set_num_threads(1)
function workload(case)
  rng = Xoshiro(92026)
  n, p = 600, 80
  X = randn(rng, n, p) / sqrt(n)
  # Mild correlation ensures the diagonal itself is not a majorizer.
  X[:, 2:end] .+= 0.4 .* X[:, 1:1]
  beta = [fill(2.0, 12); zeros(p-12)]
  y = X * beta + 0.1randn(rng, n)
  case == "ls-well" || (X .*= (10 .^ range(0, 3; length=p))')
  f = if case == "logistic-scaled"
    yy = Float64.(rand(rng, n) .< (1 ./ (1 .+ exp.(-y))))
    LogisticLoss(yy, X)
  else
    LeastSquaresLoss(y, X)
  end
  d = coordinate_lipschitz!(zeros(p), f)
  f, NormL1(0.03, sqrt.(d)), p
end
const CASES = ("ls-well", "ls-scaled", "logistic-scaled")
const DATA = Dict(c => workload(c) for c in CASES)
function trial(case, solver, mode)
  f, g, p = DATA[case]
  ctor = solver == "pgd" ? ProximalGradientDescent : AccProxGradDescent
  method = mode == "baseline" ? ctor() : ctor(; preconditioner=Symbol(mode))
  options = ProximalOptions(; maxiter=6000, gaptol=1e-5, gapevery=10)
  x = zeros(p)
  GC.gc()
  sample = @timed solve!(x, f, g, method, options)
  r = sample.value
  (seconds=sample.time, bytes=sample.bytes, iterations=r.iterations,
   gap=r.gap, converged=r.converged, objective=r.minimum,
   backtracks=r.backtrack_steps, coefficients=copy(x))
end
