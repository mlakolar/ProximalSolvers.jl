# The #316/#317 family: ordinary design and response, loss scale α from 1e-100 to 1e-300 (value ≈ α·O(100) stays representable).
using ProximalSolvers, ProximalBase, LinearAlgebra, Printf, Random, Statistics
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
include(joinpath(@__DIR__, "ref.jl")); const R = Ref321
println("# Julia ", VERSION, " | ", Sys.CPU_NAME)
println("T\talpha\tsolver\tpolicy\toutcome\titers\tkkt_rel\tL_init")
for T in (Float64, Float32)
  rng = Xoshiro(5); n, p = 100, 20
  X0 = randn(rng, n, p); X0 .-= mean(X0, dims = 1); X0 ./= std(X0, dims = 1)
  β = zeros(p); β[1:5] .= randn(rng, 5); y0 = X0 * β .+ 0.1 .* randn(rng, n)
  X = T.(X0); y = T.(y0)
  αs = T === Float64 ? (1e-100, 1e-150, 1e-200, 1e-250, 1e-290, 1e-300) : (1e-10, 1e-20, 1e-30, 1e-35, 1e-37)
  for α in αs
    λ = T(0.1 * Float64(R.λmax(X, y, α)))
    for (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())), pol in (:base, :b1)
      x = zeros(T, p)
      try
        res, st, L0 = PS.solve_proto2!(x, α * LeastSquaresLoss(y, X), NormL1(λ), mk; L0 = pol)
        outcome = res.converged ? "converged" : res.iteration_converged ? "maxiter" : res.f_increased ? "f_increased" : "other"
        @printf("%s\t%.0e\t%s\t%s\t%s\t%d\t%.3e\t%.3e\n", T, α, sn, pol, outcome, res.iterations, R.kkt(X, y, α, λ, x), L0)
      catch e
        @printf("%s\t%.0e\t%s\t%s\terror:%s\t-\t-\t-\n", T, α, sn, pol, first(split(sprint(showerror, e), '\n')))
      end
    end
  end
end

# ---- the #317 reproducer family (archive/issue-296-evidence probes/repro.jl): dataset "base", cold start, "strict" options ----
println("\n## #317 family: n=30 p=12 (seed 296), cold start, ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)")
println("alpha\tfrac\tsolver\tpolicy\toutcome\titers\tL_final")
function data296()
  rng = Xoshiro(296); n, p = 30, 12
  X = randn(rng, n, p); β = zeros(p); β[1:4] .= [2.0, -1.5, 1.0, 0.5]
  y = X * β + 0.3 * randn(rng, n); X, y
end
let (X, y) = data296(), strict = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
  for α in (1e-6, 1e-100, 1e-200, 1e-300), frac in (0.0, 0.1)
    λ = frac * α * Float64(maximum(abs, big.(X)' * big.(y)))
    for (sn, mk) in (("pgd", ProximalGradientDescent()), ("apg", AccProxGradDescent())), pol in (:base, :b1)
      x = zeros(12)
      try
        res, st, L0 = PS.solve_proto2!(x, α * LeastSquaresLoss(y, X), NormL1(λ), mk, strict; L0 = pol)
        outcome = res.converged ? "converged" : res.iteration_converged ? "maxiter" : res.f_increased ? "f_increased" : "other"
        @printf("%.0e\t%.1f\t%s\t%s\t%s\t%d\t%.3e\n", α, frac, sn, pol, outcome, res.iterations, st.L)
      catch e
        @printf("%.0e\t%.1f\t%s\t%s\terror:%s\t-\t-\n", α, frac, sn, pol, first(split(sprint(showerror, e), '\n')))
      end
    end
  end
end
