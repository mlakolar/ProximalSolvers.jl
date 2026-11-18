# Where PGD's backtracking test stops being usable: ordinary random design, response and coefficients at scale s,
# loss scale α = 1e16/s² (value ≈ 1e18 ... representable), policies base and b1.
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
length(ARGS) >= 1 && (ENV["REFPREC"] = ARGS[1])
include(joinpath(@__DIR__, "ref.jl"))
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
const R = Ref321
println("# Julia ", VERSION, " | ", Sys.CPU_NAME, " | ref precision ", precision(BigFloat))
for l in readlines(`lscpu`); occursin(r"^Model name", l) && println("# ", l); end
println("T\ts\talpha\tsolver\tpolicy\toutcome\titers\tkkt_rel\tmax|x|\tL_final")
for T in (Float64, Float32)
  rng = Xoshiro(77)
  n, p = 100, 20
  X0 = randn(rng, n, p); X0 .-= mean(X0, dims = 1); X0 ./= std(X0, dims = 1)
  β = zeros(p); β[1:5] .= randn(rng, 5); y0 = X0 * β .+ 0.1 .* randn(rng, n)
  ss = T === Float64 ? (1e100, 1e140, 1e150, 1e152, 1e153, 1e154, 1e155, 1e156, 1e158) : (1e8, 1e15, 1e18, 1e19, 1e20, 1e21)
  for s in ss
    α = (T === Float64 ? 1e16 : 1e5) / s^2
    X = T.(X0); y = T.(y0 .* s)
    λ = T(0.1 * Float64(R.λmax(X, y, α)))
    for (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())), pol in (:base, :b1)
      x = zeros(T, p)
      try
        res, st, L0 = PS.solve_proto2!(x, α * LeastSquaresLoss(y, X), NormL1(λ), mk, ProximalOptions(); L0 = pol)
        outcome = res.converged ? "converged" : res.iteration_converged ? "maxiter" : res.f_increased ? "f_increased" : res.stagnated ? "stagnated" : "other"
        @printf("%s\t%.0e\t%.2e\t%s\t%s\t%s\t%d\t%.3e\t%.3e\t%.3e\n", T, s, α, sn, pol, outcome, res.iterations, R.kkt(X, y, α, λ, x), maximum(abs, x), st.L)
      catch e
        @printf("%s\t%.0e\t%.2e\t%s\t%s\terror:%s\t-\t-\t-\t-\n", T, s, α, sn, pol, first(split(sprint(showerror, e), '\n')))
      end
    end
  end
end
