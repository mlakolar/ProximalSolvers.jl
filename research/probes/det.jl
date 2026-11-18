using ProximalSolvers, ProximalBase, LinearAlgebra, Random
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
x = zeros(12); solve!(x, LeastSquaresLoss(y, X), NormL1(0.0), CDSolver(tol = 1e-14)); println("CD  ", hash(x), " ", x[1])
x2 = zeros(12); r = solve!(x2, LeastSquaresLoss(y, X), NormL1(0.0), ProximalGradientDescent()); println("PGD ", hash(x2), " ", r.iterations)
