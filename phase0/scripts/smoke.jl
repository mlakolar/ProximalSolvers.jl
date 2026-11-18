using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const PS = ProximalSolvers
Base.include(PS, joinpath(@__DIR__, "trace_defs.jl"))
rng = Xoshiro(1); X = randn(rng, 100, 10); y = randn(rng, 100); f = (1/100) * LeastSquaresLoss(y, X)
for pol in (:base, :b1, :b1x), mk in (ProximalGradientDescent(), AccProxGradDescent())
  x = zeros(10); r = PS.solve_proto!(x, f, NormL1(0.05), mk; L0 = pol); println(pol, " ", typeof(mk).name.name, " ", r.iterations, " ", r.converged, " L0=", PS._probe_L0(pol, Float64, f))
end
x = zeros(10); r = PS.solve_apg_reuse!(x, f, NormL1(0.05), AccProxGradDescent()); println("reuse ", r.iterations, " ", r.converged)
Xs = X .* 1e-3; f2 = (1/100) * LeastSquaresLoss(y .* 1e-3, Xs)
for pol in (:base, :b1, :b1x); println("small ", pol, " L0=", PS._probe_L0(pol, Float64, f2)); end
x = zeros(10); r = PS.solve_apg_reuse!(x, f2, NormL1(0.05e-6), AccProxGradDescent()); println("reuse small ", r.iterations, " ", r.converged)
println("Llower ", PS._probe_Llower(Float64, f, zeros(10)))
