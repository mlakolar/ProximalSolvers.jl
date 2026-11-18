# CD as a control on the extreme-scale problems (independent 256-bit KKT residual and objective).
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "ref.jl")); const R = Ref321
include(joinpath(@__DIR__, "problems.jl"))
println("# Julia ", VERSION, " | ", Sys.CPU_NAME)
println("case\tT\tconverged\tkkt_rel\tsubopt_frac")
for pr in probs
  occursin(r"^(R5|#327|F32-wide|extreme|tiny|alpha=1.0e-12|xscale=0.001|ord-norm-Float64)", pr.name) || continue
  X, y, α, λ = pr.X, pr.y, pr.α, pr.λ
  x = copy(pr.x0); f = α * LeastSquaresLoss(y, X)
  xs = try R.xstar(X, y, α, λ; maxpass = 20000, tol = big"1e-45") catch; nothing end
  try
    r = with_logger(NullLogger()) do
      solve!(x, f, NormL1(λ), CDSolver())
    end
    Fs = xs === nothing ? nothing : R.F(X, y, α, λ, xs); F0 = R.F(X, y, α, λ, pr.x0); Fk = R.F(X, y, α, λ, x)
    sub = Fs === nothing ? NaN : Float64((Fk - Fs) / max(F0 - Fs, big(nextfloat(0.0))))
    @printf("%s\t%s\t%s\t%.3e\t%.3e\n", pr.name, pr.T, r.converged, R.kkt(X, y, α, λ, x), sub)
  catch e
    @printf("%s\t%s\terror:%s\t-\t-\n", pr.name, pr.T, first(split(sprint(showerror, e), '\n')))
  end
end
