# Exploratory timings of the supported minimal core: dense coordinate descent and dense
# proximal gradient descent on Float32/Float64 least-squares lasso. Run under the root project:
#
#   JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/minimal/explore.jl
#
# Prints one row per case and writes nothing. The timings are EXPLORATORY: one process, no
# paired baseline, no noise control. They show whether a change is worth a closer look, not
# whether it is faster; use a paired, controlled comparison (benchmark/sparse_cd/ for CD) for that.
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random
BLAS.set_num_threads(1)

function fixture(::Type{T}, n, p) where {T}
  rng = Xoshiro(0x6d696e + n + p)
  X = T.(randn(rng, n, p))
  beta = zeros(T, p); beta[1:8] .= T.(range(1, 0.2; length = 8))
  y = X * beta + T(0.05) .* T.(randn(rng, n))
  scale = one(T) / T(n)
  lambda = T(0.1) * norm(scale * (X' * y), Inf)
  (; X, y, scale, lambda, f = scale * LeastSquaresLoss(y, X), g = NormL1(lambda))
end

# Optimality is checked from the problem data, independently of each solver's stopping rule.
function kkt(problem, x)
  X, y, s, l = Float64.(problem.X), Float64.(problem.y), Float64(problem.scale), Float64(problem.lambda)
  x = Float64.(x); grad = s * (X' * (X * x - y))
  maximum(iszero(x[i]) ? max(abs(grad[i]) - l, 0.0) : abs(grad[i] + l * sign(x[i])) for i in eachindex(x))
end

const METHODS = (
  ("cd", () -> CDSolver(; rng = Xoshiro(1)), nothing),
  ("pgd", () -> ProximalGradientDescent(), ProximalOptions(; maxiter = 5000)),
)

run_case(problem, make, options) = options === nothing ?
  solve!(zeros(eltype(problem.X), size(problem.X, 2)), problem.f, problem.g, make()) :
  solve!(zeros(eltype(problem.X), size(problem.X, 2)), problem.f, problem.g, make(), options)

function main(; samples = 15)
  @printf("EXPLORATORY julia=%s threads=%d blas=%d cpu=%s\n", VERSION, Threads.nthreads(),
          BLAS.get_num_threads(), Sys.CPU_NAME)
  @printf("%-4s %-8s %5s %5s %9s %6s %12s %12s %10s %9s\n", "alg", "type", "n", "p", "converged",
          "work", "median_us", "min_us", "bytes", "kkt")
  for T in (Float32, Float64), (n, p) in ((100, 50), (500, 200)), (name, make, options) in METHODS
    problem = fixture(T, n, p)
    result = run_case(problem, make, options)                 # compilation and validation call
    times = Float64[]; bytes = 0
    for _ in 1:samples
      timed = @timed run_case(problem, make, options)
      push!(times, timed.time); bytes = timed.bytes
    end
    work = result isa ProximalSolvers.CDResults ? result.passes : result.iterations
    @printf("%-4s %-8s %5d %5d %9s %6d %12.1f %12.1f %10d %9.2e\n", name, T, n, p, result.converged,
            work, 1e6 * sort(times)[cld(samples, 2)], 1e6 * minimum(times), bytes,
            kkt(problem, result.minimizer))
  end
end

main()
