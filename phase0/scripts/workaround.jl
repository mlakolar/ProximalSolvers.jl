# Candidate A: what a user can do without a code change. R5 and #327 with the design scaled by a power of two
# (objective unchanged: X x = (X c)(x / c)), or the response and the loss scale rescaled.
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
println("# Julia ", VERSION, " | ", Sys.CPU_NAME)
println("variant\tsolver\tconverged\titers\tx_rescaled\trel.err vs 1e160")
for (name, X0, y0, α0) in (("R5", ones(5, 1), fill(1e160, 5), 1e-100), ("#327", [1.0;;], [1e160], 5e-100))
  # design scaled by c = 2^k: x' = x / c
  for k in (0, 100, 166, 200, 300), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()), ("cd", CDSolver()))
    c = 2.0^k
    X = X0 .* c; f = α0 * LeastSquaresLoss(y0, X); x = [0.0]
    r = try solve!(x, f, NormL1(0.0), mk) catch e; e end
    r isa Exception ? println(name, " X*2^", k, "\t", sn, "\tthrew ", first(split(sprint(showerror, r), '\n'))) :
      @printf("%s X*2^%d\t%s\t%s\t%s\t%.4e\t%.2e\n", name, k, sn, r.converged, hasproperty(r, :iterations) ? r.iterations : -1, x[1] * c, abs(x[1] * c - 1e160) / 1e160)
  end
  # response scaled by 2^-k, loss scale by 2^(2k): objective unchanged, x' = x 2^-k
  for k in (100, 300, 500), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent()), ("cd", CDSolver()))
    s = 2.0^-k
    f = (α0 * 2.0^(2k)) * LeastSquaresLoss(y0 .* s, X0); x = [0.0]
    r = try solve!(x, f, NormL1(0.0), mk) catch e; e end
    r isa Exception ? println(name, " y*2^-", k, ",α*2^", 2k, "\t", sn, "\tthrew ", first(split(sprint(showerror, r), '\n'))) :
      @printf("%s y*2^-%d, α*2^%d\t%s\t%s\t%s\t%.4e\t%.2e\n", name, k, 2k, sn, r.converged, hasproperty(r, :iterations) ? r.iterations : -1, x[1] / s, abs(x[1] / s - 1e160) / 1e160)
  end
end
# an APG run on the response-rescaled R5: how many trials the first iteration needs when L = 1 is far below L_f
let X = ones(5, 1), y = fill(1e160, 5) .* 2.0^-300, α = 1e-100 * 2.0^600
  x = [0.0]; f = α * LeastSquaresLoss(y, X)
  res, st, L0 = PS.solve_proto2!(x, f, NormL1(0.0), AccProxGradDescent(); L0 = :base)
  println("APG on R5 rescaled by 2^-300 / 2^600: converged=", res.converged, " iterations=", res.iterations, " f_calls=", st.f_calls, " backtrack_steps=", st.backtrack_steps, " L_f=", 5α)
end

println("\n# PGD under b1 on rank-one designs (X = ones(5,1), y = s·ones), α = 1e16/s²: where the line search loses range")
println("s\tsolver\tpolicy\toutcome\titers\tkkt_rel")
include(joinpath(@__DIR__, "ref.jl"))
for s in (1e100, 1e140, 1e150, 1e152, 1e153, 1e154, 1.2e154, 1.5e154, 2e154, 1e155, 1e157, 1e160), (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())), pol in (:base, :b1)
  X = ones(5, 1); y = fill(s, 5); α = (1e16 / s) / s
  x = [0.0]
  res, st, L0 = PS.solve_proto2!(x, α * LeastSquaresLoss(y, X), NormL1(0.0), mk; L0 = pol)
  outcome = res.converged ? "converged" : res.iteration_converged ? "maxiter" : res.f_increased ? "f_increased" : "other"
  @printf("%.3e\t%s\t%s\t%s\t%d\t%.3e\n", s, sn, pol, outcome, res.iterations, Ref321.kkt(X, y, α, 0.0, x))
end
