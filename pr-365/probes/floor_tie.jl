# The tightening decision `tol/100 >= floor64` at an exact tie (user tolerance 1600 eps, relative threshold): outcome of
# public solves on one tree (ARGS[1] = path of the tree), printed per problem, to be compared across trees and across
# compilation settings of the same tree.
using Random, Logging, Printf
module M; include(joinpath(ARGS[1], "src/ProximalSolvers.jl")); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
const PS = M.ProximalSolvers
function run(nprob)
  rng = Xoshiro(365353)
  for k in 1:nprob
    X = randn(rng, 100, 8)
    k % 3 == 0 && (X[:, 2] = X[:, 1] + 0.01randn(rng, 100))
    noise = randn(rng, 100)
    y = ldexp.(X[:, 1], 27) + noise
    for tolf in (1600, 160000)
      r = with_logger(NullLogger()) do
        PS.solve!(zeros(8), SqrtLeastSquaresLoss(y, X), NormL1(ldexp(1000.0, -27)),
                  PS.CDSolver(order = :cyclic, momentum = false, tol = tolf*eps(Float64), maxpasses = 2000))
      end
      @printf("%3d tol=%6d eps passes=%4d converged=%-5s tolerance=%.17g gap=%.6g\n", k, tolf, r.passes, r.converged, r.tolerance, r.gap)
    end
  end
end
run(parse(Int, ARGS[2]))
