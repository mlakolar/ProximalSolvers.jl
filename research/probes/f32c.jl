using ProximalSolvers, ProximalBase, LinearAlgebra, Random
const LS = ProximalSolvers.LineSearches
src = read(joinpath(pkgdir(ProximalSolvers), "src", "line_searches.jl"), String)
i1 = findfirst("function backtrack!(", src).start; i2 = findfirst("\nhas_updated_gradient", src).start
body = replace(src[i1:i2], "    state.backtrack_steps += 1;\n" =>
  "    state.backtrack_steps += 1;\n    (xy_sq < 1f-36) && Main.LOG[] < 12 && (Main.LOG[] += 1; println(\"xy_sq=\", xy_sq, \" mode_grad=\", gradient_mode, \" local_l=\", local_l, \" L=\", state.L))\n")
const LOG = Ref(0)
Core.eval(LS, Meta.parseall(body))
rng = Xoshiro(296); X = Float32.(randn(rng, 30, 12)); y = Float32.(X*[2.0,-1.5,1,0.5,0,0,0,0,0,0,0,0] + 0.3*randn(rng, 30))
x = zeros(Float32, 12)
solve!(x, 1f-30*LeastSquaresLoss(y, X), NormL1(0f0), ProximalGradientDescent(), ProximalOptions(maxiter = 20_000))
