# Paired timing of CD on ordinary lasso problems: one fresh process per (tree, block); the driver
# alternates trees (master A, candidate B, master A′ as A/A control). Prints one TSV row per case:
# median and min seconds over `samples`, bytes allocated per solve, passes, converged.
# Usage: julia --project=TREE time311.jl LABEL SAMPLES
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
BLAS.set_num_threads(1)
include(joinpath(@__DIR__, "problems311.jl"))

function main(label, samples)
  for (pname, mk) in filter(p -> occursin(Regex(get(ENV, "PROBLEM", "")), p[1]), PROBLEMS)
    prob = mk()
    p = size(prob.X, 2)
    w = let f = prob.s * LeastSquaresLoss(prob.y, prob.X)
      x = zeros(p)
      with_logger(NullLogger()) do
        solve!(x, f, NormL1(1.25prob.λ), CDSolver(order = :cyclic, momentum = false, tol = 1e-12, maxpasses = 100_000))
      end
      x
    end
    for T in (Float32, Float64), (sname, x0) in (("cold", zeros(p)), ("warm", w)),
        (oname, order, momentum) in (("cyclic", :cyclic, false), ("random", :random, nothing), ("random-nomom", :random, false))
      f = T(prob.s) * LeastSquaresLoss(T.(prob.y), T.(prob.X)); g = NormL1(T(prob.λ)); xs = T.(x0)
      mk_solver() = CDSolver(; order, momentum, tol = 1e-7, maxpasses = 100_000, rng = Xoshiro(1))
      run() = (x = copy(xs); with_logger(NullLogger()) do; solve!(x, f, g, mk_solver()); end)
      r = run(); run()
      times = Float64[]; bytes = 0
      for _ in 1:samples
        t = @timed run()
        push!(times, t.time); bytes = t.bytes
      end
      sort!(times)
      println(join([label, VERSION, pname, T, sname, oname, times[cld(samples, 2)], times[1], bytes, r.passes, r.converged], '\t'))
    end
  end
end
main(ARGS[1], parse(Int, ARGS[2]))
