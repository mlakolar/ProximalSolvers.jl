# Supplementary (preregistered 2026-11-18 before running): how often do exact fits arise at the
# theory-recommended level? Belloni–Chernozhukov–Wang pivotal choice for the normalized objective
# ‖y−Xβ‖/√n + (λₙ/n)‖β‖₁ with λₙ = c √n Φ⁻¹(1 − α/(2p)), c = 1.1, α = 0.05, columns scaled to ‖X_j‖ = √n.
# In PS's unnormalized form ‖y−Xβ‖ + λ‖β‖₁ this is λ = c Φ⁻¹(1 − α/(2p)) (independent of n).
# Designs: Gaussian, Toeplitz ρ^|i−j| with ρ = 0.5 and 0.9; s ∈ {5, 20}; σ = 1; β_j = 1 on the support
# (alternating signs); (n, p) ∈ {(100, 500), (100, 2000), (50, 1000), (200, 1000)}; seeds 1..3.
# Also λ/2 and λ/4 (a smaller level, as in cross-validation-like tuning) to locate the exact-fit regime.
# Production solver (cyclic, momentum off; and random with default momentum, rng Xoshiro(7)) from 0, both types.
include(joinpath(@__DIR__, "common.jl"))
using JuMP, Clarabel
include(joinpath(@__DIR__, "oracle.jl"))   # primal, dual, dual_lower (the main block does not run on include)

# Φ⁻¹ without extra packages: bisection on erfc
using SpecialFunctions: erfcinv
qnorm(u) = -sqrt(2) * erfcinv(2u)

function design(n, p, ρ, s, seed)
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  if ρ > 0                           # AR(1) columns: x_j = ρ x_{j-1} + √(1-ρ²) z_j
    for j in 2:p
      Z[:, j] .= ρ .* Z[:, j-1] .+ sqrt(1 - ρ^2) .* Z[:, j]
    end
  end
  X = Z ./ sqrt.(sum(abs2, Z; dims = 1)) .* sqrt(n)
  β = zeros(p); β[1:s] .= [(-1)^j for j in 1:s]
  X, X * β .+ randn(Xoshiro(seed + 999), n)
end

out = open(joinpath(@__DIR__, "..", "out", "realistic.tsv"), "w")
println(out, join(["n", "p", "rho", "s", "seed", "lamfac", "lam", "lam_over_lammax", "T", "config", "opt_exact", "opt_nnz",
                   "rrel_opt", "converged", "excess", "class", "nnz", "passes"], '\t'))
for (n, p) in ((100, 500), (100, 2000), (50, 1000), (200, 1000)), ρ in (0.0, 0.5, 0.9), s in (5, 20), seed in 1:3
  s >= n ÷ 2 && continue
  X, y = design(n, p, ρ, s, seed)
  λ0 = 1.1 * qnorm(1 - 0.05 / (2p))
  for fac in (1.0, 0.5, 0.25)
    λ = fac * λ0
    for T in (Float64, Float32)
      XT, yT, λT = T.(X), T.(y), T(λ)
      X64, y64, λ64 = Float64.(XT), Float64.(yT), Float64(λT)
      βo, _ = primal(X64, y64, λ64); θo, _ = dual(X64, y64, λ64)
      D, _ = dual_lower(X64, y64, λ64, θo)
      rro = Float64(norm(big.(y64) - big.(X64) * big.(βo)) / norm(big.(y64)))
      o = (; D = Float64(D))
      for (cname, ckw) in (("cyclic-dense", (; order = :cyclic, momentum = false)), ("random-dense", (; rng = Xoshiro(7))))
        x, r, _, _ = ps_solve(XT, yT, λT, zeros(T, p); ckw...)
        c = classify(XT, yT, λT, x, o)
        class = r.converged ? (c.optimal ? "certified" : "FALSE-CERT") : r.passes >= 20_000 ? "capped" :
                c.optimal ? "missed-cert(156)" : "nonoptimal(155)"
        println(out, join(Any[n, p, ρ, s, seed, fac, λ, λ / lammax(X64, y64), T, cname, rro < 1e-8,
                              count(abs.(βo) .> 1e-8 * norm(βo, Inf)), rro, r.converged, c.excess, class, c.nnz, r.passes], '\t'))
        flush(out)
      end
    end
  end
end
close(out)
