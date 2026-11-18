# (a) how many iterations the unmodified solvers need on R5/#327; (b) blindness of PGD's backtracking test at large steps
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf
const PS = ProximalSolvers
length(ARGS) >= 1 && (ENV["REFPREC"] = ARGS[1])
include(joinpath(@__DIR__, "ref.jl"))
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
const R = Ref321
println("# Julia ", VERSION, " | ", Sys.CPU_NAME, " | ref precision ", precision(BigFloat))

println("\n## (a) unmodified solve!, larger iteration budgets (R5, λ = 0; x* = 1e160)")
for maxiter in (200, 1000, 2000, 2500, 3000, 5000), (sn, m) in (("PGD", ProximalGradientDescent()), ("APG", AccProxGradDescent()))
  X, y, α = ones(5, 1), fill(1e160, 5), 1e-100
  x = [0.0]; f = α * LeastSquaresLoss(y, X)
  r = try solve!(x, f, NormL1(0.0), m, ProximalOptions(maxiter = maxiter)) catch e; e end
  if r isa Exception
    println("maxiter=", maxiter, " ", sn, " threw ", sprint(showerror, r))
  else
    @printf("maxiter=%4d %s: converged=%s iterations=%d x=%.4e KKTrel=%.3e f_calls=%d increased=%s\n", maxiter, sn, r.converged, r.iterations, x[1], R.kkt(X, y, α, 0.0, x), r.f_calls, r.f_increased)
  end
end
# where the L estimate crosses L_f along the baseline trajectory
let X = ones(5, 1), y = fill(1e160, 5), α = 1e-100
  Lf = α * 5
  for kind in (:pgd, :apg)
    x = [0.0]; f = α * LeastSquaresLoss(y, X)
    res, recs = PS.traced_solve!(kind, x, f, NormL1(0.0), ProximalOptions(maxiter = 3000))
    println("baseline traced ", kind, ": converged=", res.converged, " iterations=", res.iterations, " stop=", res.stop, " x=", @sprintf("%.4e", x[1]))
    for r in recs
      isempty(r.error) || (println("  it ", r.iter, " ERROR ", r.error); break)
      k = r.iter
      (k in (2100, 2150, 2160, 2170, 2175, 2180, 2185, 2190, 2200) || k == length(recs)) || continue
      @printf("  it %4d L_start=%.3e L_end=%.3e #trials=%d x=%.4e dx=%.3e F/F0=%.3e flags=(%d%d%d)\n", k, r.L_start, r.L_end, length(r.trials), r.x[1], abs(r.x[1] - r.xprev[1]), r.f / 2.5e220, r.flags.x, r.flags.f, r.flags.g)
    end
  end
end

println("\n## (b) PGD backtracking at a step whose square overflows: same one-dimensional problem scaled so that L_f = 5 α... start L0 = 0.4 L_f")
println("# problem: X = ones(5,1), y = s·ones(5), α = 5e-100·(1e160/s)^2·... chosen so that α s² is fixed; L0 = 0.4 L_f = 0.4·5α")
for s in (1e100, 1e140, 1e150, 1e153, 1e154, 1e155, 1e160), kind in (:pgd, :apg)
  X = ones(5, 1); y = fill(s, 5)
  α = 1e-100 * (1e160 / s)^2          # α s² = 1e-100 · 1e320 (value fixed), L_f = 5α
  Lf = 5α
  f = α * LeastSquaresLoss(y, X); x = [0.0]
  res, recs = PS.traced_solve!(kind, x, f, NormL1(0.0), ProximalOptions(maxiter = 6); L0 = 0.4 * Lf / 0.9)  # L after the α-decrease = 0.4 L_f
  r1 = recs[1]
  t = r1.trials
  @printf("s=%.0e α=%.2e L_f=%.3e kind=%s: it1 #trials=%d trial L's=%s  accepted_L=%.3e  |dx|=%.3e  (dx)^2 %s\n", s, α, Lf, kind, length(t),
          join([@sprintf("%.2e", tt.L) for tt in t], ","), t[end].L, kind === :pgd ? t[end].dxnorm : t[end].dnorm, (kind === :pgd ? t[end].dxnorm : t[end].dnorm)^2 > floatmax(Float64) ? "overflows" : "finite")
end
