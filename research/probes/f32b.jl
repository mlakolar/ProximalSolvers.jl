using ProximalSolvers, ProximalBase, LinearAlgebra, Random
rng = Xoshiro(296); X = Float32.(randn(rng, 30, 12)); y = Float32.(X*[2.0,-1.5,1,0.5,0,0,0,0,0,0,0,0] + 0.3*randn(rng, 30))
x = zeros(Float32, 12); tr = Tuple{Int,Float32,Float32}[]; xprev = copy(x)
solve!(x, 1f-30*LeastSquaresLoss(y, X), NormL1(0f0), ProximalGradientDescent(),
  ProximalOptions(maxiter = 20_000, callback = s -> (push!(tr, (s.iteration, s.L, Float32(norm(x - xprev)))); xprev .= x; false)))
for t in tr[1:40:end]; println(t, "  norm^2=", t[3]^2); end
