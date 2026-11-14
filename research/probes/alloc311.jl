# Allocation check: per-pass allocations (full and active) are 0, and a whole solve allocates the
# same bytes for 10 passes as for 1000 passes (no per-pass allocation in the scheduling loop).
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "problems311.jl"))
prob = PROBLEMS[6][2]()   # stress 200x1000 r.95: long active phases, forced full passes fire on the candidate
for T in (Float32, Float64), (order, momentum) in ((:cyclic, false), (:random, nothing), (:random, false))
  f = T(prob.s) * LeastSquaresLoss(T.(prob.y), T.(prob.X)); g = NormL1(T(prob.λ))
  p = size(prob.X, 2)
  solve_with(maxpasses) = (x = zeros(T, p); with_logger(NullLogger()) do
    solve!(x, f, g, CDSolver(; order, momentum, tol = 1e-7, maxpasses, rng = Xoshiro(1))) end)
  solve_with(10); solve_with(1000)
  a10 = @allocated solve_with(10); a1000 = @allocated solve_with(1000)
  r = solve_with(1000)
  # direct per-pass check on a private iterate and model
  xs = SparseIterate(zeros(T, p)); m = PS.cdmodel(f, xs); PS.initialize!(m, xs)
  st = PS._CDState(T, xs, CDSolver(; order, momentum, rng = Xoshiro(1)))
  PS._pass!(xs, m, g, st, true, true); PS._pass!(xs, m, g, st, false, true)
  af = @allocated PS._pass!(xs, m, g, st, true, true)
  aa = @allocated PS._pass!(xs, m, g, st, false, true)
  @printf "%s %-7s %-7s bytes(maxpasses=10)=%d bytes(maxpasses=1000)=%d passes=%d full-pass alloc=%d active-pass alloc=%d\n" T order string(momentum) a10 a1000 r.passes af aa
end
