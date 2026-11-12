# Warm persistent worker; stdin carries case IDs, stdout carries TSV measurements.
using ProximalBase, ProximalSolvers, LinearAlgebra, Random, SHA
BLAS.set_num_threads(1)

function fixture(::Type{T}, n, p) where T
  rng = Xoshiro(0x17a2c0 + n + p)
  Z, shared = randn(rng, n, p), randn(rng, n)
  X64 = sqrt(.8) .* Z .+ sqrt(.2) .* shared
  beta = zeros(p)
  beta[1:8] .= [1., -.8, .6, -.4, .3, -.2, .15, -.1]
  y64 = X64 * beta + .05 .* randn(rng, n)
  X, y = T.(X64), T.(y64)
  (; X, y, f = (one(T) / T(n)) * LeastSquaresLoss(y, X), g = NormL1(T(.03)))
end
method(::Val{:CD}) = CDSolver(rng = Xoshiro(0x2cd314))
method(::Val{:PGD}) = ProximalGradientDescent()
prepare(problem, solver, inner) = [(zeros(eltype(problem.X), size(problem.X, 2)),
  problem.f, problem.g, method(solver)) for _ in 1:inner]
function batch!(works)
  result = solve!(works[1]...)
  for i in 2:length(works)
    result = solve!(works[i]...)
  end
  result
end
function diagnostics(problem, result)
  x, X, y = Float64.(result.minimizer), Float64.(problem.X), Float64.(problem.y)
  scale = Float64(one(eltype(problem.X)) / eltype(problem.X)(length(y)))
  lambda = Float64(problem.g.λ0)
  r = X*x-y
  objective = scale * sum(abs2, r)/2 + lambda * sum(abs, x)
  gradient = scale * (X'*r)
  kkt = maximum(iszero(x[i]) ? max(abs(gradient[i])-lambda, 0.) :
    abs(gradient[i]+lambda*sign(x[i])) for i in eachindex(x))
  @assert isfinite(objective) && isfinite(kkt)
  @assert isapprox(result.minimum, objective; rtol = 100eps(eltype(problem.X)))
  iterations = hasproperty(result, :passes) ? result.passes : result.iterations
  fields = (:converged, :iteration_converged, :x_converged, :f_converged,
    :grad_converged, :f_increased, :call_limit_reached, :maxchange, :tolerance,
    :x_residual, :f_residual, :g_residual, :f_calls, :grad_calls, :prox_calls,
    :backtrack_steps)
  flags = join((string(s, '=', getproperty(result, s)) for s in fields
    if hasproperty(result, s)), ',')
  point = bytes2hex(sha256(reinterpret(UInt8, result.minimizer)))
  join((point, bitstring(result.minimum), iterations, flags, objective, kkt), '\t')
end
function measure(problem, solver, inner)
  works = prepare(problem, solver, inner)
  GC.gc()
  timed = @timed batch!(works)
  @assert all(w -> isequal(w[1], timed.value.minimizer), works)
  string(timed.time/inner, '\t', timed.bytes/inner, '\t', timed.gctime/inner,
    '\t', diagnostics(problem, timed.value))
end
function blasbatch!(z, grad, X, x, residual)
  for _ in 1:200
    mul!(z, X, x)
    mul!(grad, transpose(X), residual)
  end
end
function components(problem)
  X = problem.X
  x, residual = ones(eltype(X), size(X, 2)), ones(eltype(X), size(X, 1))
  z, grad = similar(residual), similar(x)
  blasbatch!(z, grad, X, x, residual)
  samples = Float64[]
  for _ in 1:7
    GC.gc()
    push!(samples, (@elapsed blasbatch!(z, grad, X, x, residual))/200)
  end
  join(("BLAS", UInt(pointer(X)) % 4096, UInt(pointer(X)) % 64,
    join(samples, ',')), '\t')
end
const CASES = [(T, n, p, inner, solver) for T in (Float64, Float32)
  for (n,p,inner) in ((128,32,100), (1024,256,20)) for solver in (Val(:CD),Val(:PGD))]
const PROBLEMS = [fixture(T,n,p) for (T,n,p,_,_) in CASES]
for (i, (_,_,_,inner,solver)) in enumerate(CASES)
  for _ in 1:5
    measure(PROBLEMS[i], solver, inner)
  end
end
println("READY\t", VERSION, '\t', Sys.CPU_NAME, '\t', Threads.nthreads(), '\t',
  BLAS.get_num_threads(), '\t', pathof(ProximalBase), '\t', pathof(ProximalSolvers))
flush(stdout)
for line in eachline(stdin)
  line == "quit" && break
  if line == "components"
    println(components(PROBLEMS[4]))
    flush(stdout)
    continue
  end
  i = parse(Int, line)
  _,_,_,inner,solver = CASES[i]
  println(measure(PROBLEMS[i], solver, inner))
  flush(stdout)
end
