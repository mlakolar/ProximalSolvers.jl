# Allocation check with every measurement inside a function (a top-level @allocated can count
# the boxing of its own result): bytes of one full pass and one active pass after warm-up, and
# bytes of whole solves with maxpasses = 10 and 1000. Same problem and configurations as alloc311.jl.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "problems311.jl"))
pass_bytes(xs, m, g, st, full) = @allocated PS._pass!(xs, m, g, st, full, true)
solve_bytes(f, g, p, ::Type{T}, solver) where {T} = (x = zeros(T, p); @allocated solve!(x, f, g, solver))
function main()
  prob = PROBLEMS[6][2]()   # stress 200x1000 r.95: long active phases, forced full passes fire on the fix
  for T in (Float32, Float64), (order, momentum) in ((:cyclic, false), (:random, nothing), (:random, false))
    f = T(prob.s) * LeastSquaresLoss(T.(prob.y), T.(prob.X)); g = NormL1(T(prob.λ))
    p = size(prob.X, 2)
    solver(maxpasses) = CDSolver(; order, momentum, tol = 1e-7, maxpasses, rng = Xoshiro(1))
    b10, b1000, passes = with_logger(NullLogger()) do
      solve_bytes(f, g, p, T, solver(10)); solve_bytes(f, g, p, T, solver(1000))
      x = zeros(T, p); r = solve!(x, f, g, solver(1000))
      solve_bytes(f, g, p, T, solver(10)), solve_bytes(f, g, p, T, solver(1000)), r.passes
    end
    xs = SparseIterate(zeros(T, p)); m = PS.cdmodel(f, xs); PS.initialize!(m, xs)
    st = PS._CDState(T, xs, CDSolver(; order, momentum, rng = Xoshiro(1)))
    pass_bytes(xs, m, g, st, true); pass_bytes(xs, m, g, st, false)
    af = pass_bytes(xs, m, g, st, true); aa = pass_bytes(xs, m, g, st, false)
    @printf "%s %-7s %-7s bytes(maxpasses=10)=%d bytes(maxpasses=1000)=%d passes=%d full-pass alloc=%d active-pass alloc=%d\n" T order string(momentum) b10 b1000 passes af aa
  end
end
main()
