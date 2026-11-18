# Orchestrator's own reproduction of the two counterexamples of the Codex review of r1 (#353).
using Logging
const ROOT = "<WORK>"
for (nm, tree) in (("base", "ps-353"), ("x2", "ps-353-x2"), ("x1d", "ps-353-x1d"))
  @eval module $(Symbol("M_", nm)); include(joinpath(Main.ROOT, $tree, "src/ProximalSolvers.jl")); end
end
using ProximalBase: LeastSquaresLoss, SqrtLeastSquaresLoss, NormL1
run(f) = try r = with_logger(f, NullLogger()); string(r) catch e; "THROWS " * first(sprint(showerror, e), 110) end
# finding 1: Float32 data, Float64 loss scale, response scale at the floatmin(Float32) boundary
function boundary(P)
  y = fill(1f-18, 100); X = ones(Float32, 100, 1); s = 0f0
  for v in y; s += v*v; end
  α = Float64(floatmin(Float32))^2/Float64(s)
  x = zeros(Float32, 1)
  r = P.solve!(x, α*LeastSquaresLoss(y, X), NormL1(1f0), P.CDSolver(maxpasses = 2, momentum = false, order = :cyclic, tol = 1))
  (x = x, converged = r.converged)
end
println(VERSION, " finding 1  base: ", run(() -> boundary(M_base.ProximalSolvers)))
println(VERSION, " finding 1  x2  : ", run(() -> boundary(M_x2.ProximalSolvers)))
# finding 2: zero residual with a column whose squares are below the clean range
function exactfit(P, y, x0)
  x = copy(x0)
  r = P.solve!(x, SqrtLeastSquaresLoss(y, fill(1e-150, 2, 1)), NormL1(1e-151), P.CDSolver(order = :cyclic, momentum = false, maxpasses = 10))
  (x = x, converged = r.converged, gap = r.gap)
end
for (y, x0) in ((zeros(2), zeros(1)), (fill(1e-150, 2), ones(1)))
  println(VERSION, " finding 2  base: ", run(() -> exactfit(M_base.ProximalSolvers, y, x0)))
  println(VERSION, " finding 2  x1d : ", run(() -> exactfit(M_x1d.ProximalSolvers, y, x0)))
end
