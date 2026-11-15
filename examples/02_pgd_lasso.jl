# The same lasso with the historical cached proximal-gradient algorithm.
using ProximalBase, ProximalSolvers
X = [1. 0.; 0. 2.; 0. 0.]
y = [2., -2., .5]
x = zeros(2)
f = (1/length(y)) * LeastSquaresLoss(y, X)
g = NormL1(.1);
# gradtol = 1e-10 is near the rounding level of the objective, so the solve may end on a
# computed objective increase (converged = false) unless increases are allowed
options = ProximalOptions(maxiter=2000, ftol=1e-14, xtol=1e-12, gradtol=1e-10,
                          allow_f_increases=true)
result = solve!(x, f, g, ProximalGradientDescent(), options)
@assert result.converged && result.minimizer === x
# Accuracy is checked separately from the solver's stopping flag.
@assert isapprox(x, [1.7, -.925]; atol=1e-7)
println(result)
