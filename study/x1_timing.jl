# Paired in-process timing of prototype X1 on the ordinary path (default options, ftol > 0), where X1's
# outcomes are identical to master's. Three copies of the package are compiled from source in one
# process: master (A), a second copy of master (A2, the A/A control) and X1 (B).
using ProximalBase, LinearAlgebra, Printf, Logging
const WT, X1 = ARGS[1], ARGS[2]
module MA; include(joinpath(Main.WT, "src", "ProximalSolvers.jl")); end
module MA2; include(joinpath(Main.WT, "src", "ProximalSolvers.jl")); end
module MB; include(joinpath(Main.X1, "src", "ProximalSolvers.jl")); end
include(joinpath(@__DIR__, "lib_fixtures.jl"))
BLAS.set_num_threads(1)
function batch(PSm, method, opts, x, x0, f, g, reps)
  s = 0
  t = time_ns()
  for _ in 1:reps
    copyto!(x, x0)
    r = PSm.solve!(x, f, g, method, opts)
    s += r.iterations
  end
  (time_ns() - t) / reps, s
end
function side(PSm, sol, optkw, x0, f, g, reps, nb)
  method = sol == "pgd" ? PSm.ProximalGradientDescent() : PSm.AccProxGradDescent()
  opts = PSm.ProximalOptions(; optkw...)
  x = copy(x0)
  best = Inf
  for _ in 1:nb
    t, _ = batch(PSm, method, opts, x, x0, f, g, reps)
    best = min(best, t)
  end
  best
end
med(v) = sort(v)[(length(v) + 1) ÷ 2]
println("Julia ", VERSION, ", load average ", Sys.loadavg())
@printf("%-8s %-7s %-4s %-9s %10s %8s %8s %8s %8s\n", "fixture", "T", "sol", "options", "A ns", "B/A med", "B/A max", "A2/A med", "A2/A max")
for T in (Float64, Float32), name in ("gauss", "wide", "corr95"), sol in ("pgd", "apg"), (oname, kw) in (("default", (;)), ("gradtol1e-8", (; maxiter = 20_000, gradtol = 1e-8)))
  _, X0, y0 = fixture(name)
  X, y = T.(X0), T.(y0)
  λ = T(0.1 * maximum(abs, Float64.(X)' * Float64.(y)))
  f, g = LeastSquaresLoss(y, X), NormL1(λ)
  x0 = zeros(T, size(X, 2))
  ta = with_logger(NullLogger()) do
    side(MA.ProximalSolvers, sol, kw, x0, f, g, 3, 2); side(MA2.ProximalSolvers, sol, kw, x0, f, g, 3, 2); side(MB.ProximalSolvers, sol, kw, x0, f, g, 3, 2)
  end
  reps = max(1, round(Int, 3e6 / ta))
  rb, ra2 = Float64[], Float64[]
  a0 = 0.0
  with_logger(NullLogger()) do
    for round in 1:9
      order = isodd(round) ? (:A, :B, :A2) : (:A2, :B, :A)
      t = Dict{Symbol, Float64}()
      for s in order
        t[s] = side(s === :A ? MA.ProximalSolvers : s === :A2 ? MA2.ProximalSolvers : MB.ProximalSolvers, sol, kw, x0, f, g, reps, 15)
      end
      push!(rb, t[:B] / t[:A]); push!(ra2, t[:A2] / t[:A]); a0 = t[:A]
    end
  end
  @printf("%-8s %-7s %-4s %-9s %10.0f %8.3f %8.3f %8.3f %8.3f\n", name, T, sol, oname, a0, med(rb), maximum(rb), med(ra2), maximum(ra2))
end
println("load average ", Sys.loadavg())
