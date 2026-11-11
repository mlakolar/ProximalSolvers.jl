# Coordinate descent for an explicitly normalized dense lasso.
using LinearAlgebra, ProximalBase, ProximalSolvers
X = [1. 0.; 0. 2.; 0. 0.]
y = [2., -2., .5]
x = zeros(2)
f = (1/length(y)) * LeastSquaresLoss(y, X)
g = NormL1(.1)
result = solve!(x, f, g, CDSolver())
@assert result.converged && result.minimizer === x
# Independent orthogonal-column solution, with unequal column norms.
@assert isapprox(x, [1.7, -.925]; atol=1e-7)
println(result)
