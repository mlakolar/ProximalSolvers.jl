# Print tiny seed 598 as exact Float32 literals and verify the literal problem reproduces the stall
# (master schedule) and its fix (w20), with the BigFloat KKT. Exploration build.
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "fixture311.jl"))
rng = Xoshiro(598); n, p = 2, 3
X = Float32.(randn(rng, n, p)); y = Float32.(randn(rng, n)); frac = rand(rng, (0.1, 0.3, 0.5, 0.7))
λ = penalty_fraction(Float32, X, y, 1f0, frac); x0 = Float32.(3 .* randn(rng, p))
lit(v) = "Float32[" * join((repr(Float32(e)) for e in v), ", ") * "]"
println("X = ", "reshape(", lit(vec(X)), ", 2, 3)"); println("y = ", lit(y)); println("λ = ", repr(λ), "  # ", frac, " λmax"); println("x0 = ", lit(x0))
for K in ("master", "w20", "w10", "50")
  if K == "master"; PS._FULL_PASS_INTERVAL[] = typemax(Int)
  else PS._FULL_PASS_MODE[] = startswith(K, "w") ? :work : :passes; PS._FULL_PASS_INTERVAL[] = parse(Int, lstrip(K, 'w')) end
  for owner in (false, true)
    x = owner ? SparseIterate(copy(x0)) : copy(x0)
    r = with_logger(NullLogger()) do; solve!(x, LeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic, momentum = false, tol = 1e-7, maxpasses = 2000)); end
    @printf "%-6s owner=%-5s converged=%-5s passes=%4d KKT=%.3e x=%s\n" K owner r.converged r.passes kkt_relative(X, y, 1f0, λ, Vector(x)) string(Vector(x))
  end
end
b = reference_lasso(X, y, 1f0, λ); println("BigFloat reference: ", Float64.(b))
