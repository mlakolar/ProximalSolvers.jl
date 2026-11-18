# Outcomes of the cases of test/initial_curvature.jl at the worktree this runs in (base or head).
using ProximalSolvers, ProximalBase, Random, Test
const PS = ProximalSolvers
println("# Julia ", VERSION, " PS ", pkgdir(PS))
include(joinpath(@__DIR__, "common.jl"))

function show_case(name, method, f, g, x0, opts = ProximalOptions())
  x = copy(x0)
  L0 = try PS.initial_state(method, opts, f, g, copy(x0)).L catch e; "err " * first(sprint(showerror, e), 80) end
  r = try solve!(x, f, g, method, opts) catch e; println(name, "\t", nameof(typeof(method)), "\tTHROW ", first(sprint(showerror, e), 120)); return end
  println(name, "\t", nameof(typeof(method)), "\tL0=", L0, "\tconv=", r.converged, "\titer=", r.iterations,
          "\tbt=", r.backtrack_steps, "\tf_inc=", r.f_increased, "\tstag=", r.stagnated, "\titlim=", r.iteration_converged,
          "\tx1=", x[1], "\tmin=", r.minimum)
end

for (name, X, y, α, frac) in (("R5-lam0", ones(5, 1), fill(1e160, 5), 1e-100, 0.0), ("R5-lam0.1", ones(5, 1), fill(1e160, 5), 1e-100, 0.1),
                              ("327", [1.0;;], [1e160], 5e-100, 0.0))
  λ = penalty(Float64, X, y, α, frac)
  for m in METHODS; show_case(name, m, lossof(α, y, X), NormL1(λ), zeros(1)); end
end
# EN
let X = ones(5, 1), y = fill(1e160, 5), α = 1e-100
  for m in METHODS; show_case("EN", m, lossof(α, y, X), ElasticNet(0.1 * 5e60, 1e-101), zeros(1)); end
end
# alpha 1e-12
let (X, y) = standardized(Float64, 100, 20), α = 1e-12
  λ = penalty(Float64, X, y, α, 0.1)
  for m in METHODS; show_case("alpha1e-12", m, lossof(α, y, X), NormL1(λ), zeros(20)); end
end
# zero curvature
for T in (Float32, Float64), m in METHODS
  show_case("zeroX-$T", m, lossof(T(1), ones(T, 5), zeros(T, 5, 3)), NormL1(T(0.5)), zeros(T, 3))
end
# underflow
let T = Float32, α = 1e-40
  X, y = fill(T(1e-10), 4, 1), fill(T(1e-10), 4)
  for m in METHODS; show_case("underflow-F32", m, lossof(α, y, X), NormL1(zero(T)), zeros(T, 1)); end
end
let T = Float64, α = 1e-300
  X, y = fill(1e-10, 4, 1), fill(1e-10, 4)
  for m in METHODS; show_case("underflow-F64", m, lossof(α, y, X), NormL1(zero(T)), zeros(T, 1)); end
end
