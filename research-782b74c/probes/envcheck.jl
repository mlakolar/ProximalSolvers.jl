# envcheck.jl: environment header, PB guard and a smoke solve.
include(joinpath(@__DIR__, "common.jl"))
ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
env_header()
TREE_DIR_REF[] = pkgdir(ProximalSolvers)
for T in (Float32, Float64), m in (ProximalGradientDescent(), AccProxGradDescent())
  X = T[1 0; 0 2; 1 1]; y = T[1, -1, .5]
  r = solve!(zeros(T, 2), (one(T)/T(3))*LeastSquaresLoss(y, X), NormL1(T(.1)), m)
  println("SMOKE ", T, " ", typeof(m).name.name, " iters=", r.iterations, " x=", r.minimizer)
end
println("ENVCHECK DONE")
