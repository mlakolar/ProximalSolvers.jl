# Coordinate descent on a SparseIterate that stores only active coefficients.
# The data/design matrix remains dense. Set lambda=1 to make one coefficient zero.
using ProximalBase, ProximalSolvers

X = [1.0 0.0; 0.0 2.0; 0.0 0.0]
y = [2.0, -2.0, 0.5]
n = length(y)
lambda = 1.0
f = (1 / n) * LeastSquaresLoss(y, X)
g = NormL1(lambda);

# An empty SparseIterate has no active coordinates; the solver discovers them.
x = SparseIterate(2)
result = solve!(x, f, g, CDSolver(order=:cyclic, momentum=false))
@assert result.converged && result.minimizer === x

# Soft-thresholding the independent orthogonal-column solution:
@assert isapprox(Vector(x), [0.0, -0.25]; atol=1e-7)
# Only the second coordinate is stored as active after compaction.
@assert nactive(x) == 1 && collect(activecoordinates(x)) == [2]
println("coefficients = ", Vector(x), "; active coordinates = ", collect(activecoordinates(x)))
