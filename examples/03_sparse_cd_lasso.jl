# Coordinate descent on a SparseIterate that the caller owns.
using LinearAlgebra, ProximalBase, ProximalSolvers
X = [1. 0.; 0. 2.; 0. 0.]
y = [2., -2., .5]
s = 1/length(y)
f = s * LeastSquaresLoss(y, X)
g = NormL1(.1)
# The owner starts empty. The solver works on a private copy of it that keeps its
# active zeros and their order, and gives the final state back to this owner.
x = SparseIterate(2)
result = solve!(x, f, g, CDSolver())
@assert result.converged && result.minimizer === x
# Independent analytic solution of the orthogonal columns: soft-threshold the
# correlation with y at lambda/s and divide by the squared column norm.
b = X' * y
a = vec(sum(abs2, X; dims = 1))
analytic = @. sign(b) * max(abs(b) - .1 / s, 0) / a
@assert isapprox(Vector(x), analytic; atol = 1e-7)
@assert isapprox(Vector(x), [1.7, -.925]; atol = 1e-7)
# Both coordinates are nonzero, so both are active in the owner that was passed in.
@assert nactive(x) == 2 && Set(activecoordinates(x)) == Set([1, 2])
println(result)
