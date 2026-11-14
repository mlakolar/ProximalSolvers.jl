# Seed scan of the #311 fixture (§18 Float32 reciprocal case) and its zero-column variant: how
# often does the stall occur, and does a forced full pass remove it? Runs the tree's own schedule.
# Usage: julia --project=<tree> seeds313.jl NSEEDS LABEL
using LinearAlgebra, Random, ProximalBase, ProximalSolvers, Printf, Logging
const PS = ProximalSolvers
include(joinpath(@__DIR__, "fixture311.jl"))
setK!(K) = nothing   # the schedule is the tree's own; K labels the tree (master or the fix)
function main(nseeds, Ks)
  @printf "Julia %s coverage=%d\n" VERSION Base.JLOptions().code_coverage
  for zc in (false, true), frac in (0.1, 0.5)
    X, y, c, α, _, _ = fixture311(; zero_column = zc)
    f = α * LeastSquaresLoss(y, X)
    λ = penalty_fraction(Float32, X, y, α, frac)
    p = size(X, 2)
    for (sname, x0) in (("cold", zeros(Float32, p)), ("warm", Float32.(c .* (0.3 .* sin.(1:p))))),
        momentum in (nothing, false), K in Ks
      setK!(K)
      nstall = 0; nfalse = 0; maxpass = 0; worstkkt = 0.0; stallseeds = Int[]
      for seed in 1:nseeds
        x = copy(x0)
        r = with_logger(NullLogger()) do
          solve!(x, f, NormL1(λ), CDSolver(; order = :random, momentum, tol = 1e-7, maxpasses = 2000, rng = Xoshiro(seed)))
        end
        k = kkt_relative(X, y, α, λ, x)
        r.converged || (nstall += 1; length(stallseeds) < 5 && push!(stallseeds, seed))
        r.converged && k > max(1e-7, 100eps(Float32)) && (nfalse += 1)
        r.converged && (maxpass = max(maxpass, r.passes); worstkkt = max(worstkkt, k))
      end
      @printf "zc=%-5s frac=%.1f %-4s mom=%-7s K=%-6s stalls=%3d/%d falseconv=%d max passes(conv)=%4d worst KKT(conv)=%.2e seeds=%s\n" zc frac sname string(momentum) K nstall nseeds nfalse maxpass worstkkt string(stallseeds)
    end
  end
end
main(parse(Int, ARGS[1]), ARGS[2:end])
