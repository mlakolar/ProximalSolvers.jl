# Exploratory timings of the supported minimal core: dense coordinate descent and dense
# proximal gradient descent on Float32/Float64 least-squares lasso. Run under the root project:
#
#   JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/minimal/explore.jl
#
# Prints one row per case and writes no files. This is NOT the formal benchmark framework
# (benchmark/HARNESS.md): one process, no paired baseline, no A/A noise control and no record
# validation. Its timings can show that a change is worth a closer look; they are not evidence of
# a speedup or of noninferiority. test/benchmark_explore.jl checks that it runs and that every
# case reaches a small KKT residual.
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random
BLAS.set_num_threads(1)

function fixture(::Type{T}, n, p) where {T}
  rng = Xoshiro(0x6d696e + n + p)
  X = T.(randn(rng, n, p))
  beta = zeros(T, p); beta[1:min(8, p)] .= T.(range(1, 0.2; length = min(8, p)))
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

function main(; samples = 15, sizes = ((100, 50), (500, 200)), io = stdout)
  @printf(io, "EXPLORATORY julia=%s threads=%d blas=%d cpu=%s\n", VERSION, Threads.nthreads(),
          BLAS.get_num_threads(), Sys.CPU_NAME)
  @printf(io, "%-4s %-8s %5s %5s %9s %6s %12s %12s %10s %9s\n", "alg", "type", "n", "p", "converged",
          "work", "median_us", "min_us", "bytes", "kkt")
  rows = NamedTuple[]
  for T in (Float32, Float64), (n, p) in sizes, (name, make, options) in METHODS
    problem = fixture(T, n, p)
    result = run_case(problem, make, options)                 # compilation and validation call
    times = Float64[]; bytes = 0
    for _ in 1:samples
      timed = @timed run_case(problem, make, options)
      push!(times, timed.time); bytes = timed.bytes
    end
    work = result isa ProximalSolvers.CDResults ? result.passes : result.iterations
    row = (; alg = name, type = T, n, p, converged = result.converged, work,
           median_s = sort(times)[cld(samples, 2)], min_s = minimum(times), bytes,
           kkt = kkt(problem, result.minimizer))
    push!(rows, row)
    @printf(io, "%-4s %-8s %5d %5d %9s %6d %12.1f %12.1f %10d %9.2e\n", name, T, n, p, row.converged,
            work, 1e6 * row.median_s, 1e6 * row.min_s, bytes, row.kkt)
  end
  rows
end

if abspath(PROGRAM_FILE) == @__FILE__
  main()
end
