# Search for a summation-order-independent #311 stall: Float32 problems with n = 2 rows (a two-term
# sum is the same in any order), cyclic order, momentum=false, so the run is deterministic IEEE
# arithmetic on any CPU. Exploration build (Ref). Usage: julia --project=<E tree> tiny311.jl NTRIALS
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "fixture311.jl"))
function setK!(K)
  K == "master" && return (PS._FULL_PASS_INTERVAL[] = typemax(Int))
  PS._FULL_PASS_MODE[] = startswith(K, "w") ? :work : :passes
  PS._FULL_PASS_INTERVAL[] = parse(Int, lstrip(K, 'w'))
end
function trial(seed; n = 2, p = 3)
  rng = Xoshiro(seed)
  X = Float32.(randn(rng, n, p)); y = Float32.(randn(rng, n))
  frac = rand(rng, (0.1, 0.3, 0.5, 0.7))
  λ = penalty_fraction(Float32, X, y, 1f0, frac)
  x0 = Float32.(3 .* randn(rng, p))
  (; X, y, λ, x0, frac)
end
function solve_t(t, K; tol = 1e-7)
  setK!(K)
  x = copy(t.x0)
  r = with_logger(NullLogger()) do
    solve!(x, LeastSquaresLoss(t.y, t.X), NormL1(t.λ), CDSolver(; order = :cyclic, momentum = false, tol, maxpasses = 2000))
  end
  r, x
end
function main(N)
  found = 0
  for seed in 1:N
    t = trial(seed)
    r, x = solve_t(t, "master")
    r.converged && continue
    found += 1
    kkt = kkt_relative(t.X, t.y, 1f0, t.λ, x)
    out = String[]
    for K in ("50", "w10", "w20")
      rK, xK = solve_t(t, K)
      push!(out, @sprintf("%s: conv=%s passes=%d KKT=%.2e", K, rK.converged, rK.passes, kkt_relative(t.X, t.y, 1f0, t.λ, xK)))
    end
    @printf "seed %d frac %.1f master: passes=%d KKT=%.2e x=%s | %s\n" seed t.frac r.passes kkt string(x) join(out, " | ")
    found >= 15 && break
  end
  println("master stalls found: $found in up to $N trials")
end
main(parse(Int, ARGS[1]))
