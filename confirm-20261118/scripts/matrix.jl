# Preregistered test matrix for the #155/#156 joint study (written before any candidate was run).
# Every problem is generated from a fixed Xoshiro seed; `problems()` returns a vector of NamedTuples
# (; id, family, X, y, λ, start_kinds) in Float64. Float32 runs use T.(X), T.(y), T(λ): the Float32 problem
# is the rounded data, so oracle comparisons for Float32 use the Float32 data's own oracle (see oracle.jl).
using LinearAlgebra, Random

lammax(X, y) = maximum(abs, X' * y) / norm(y)

function noiseless(n, p, k, seed; ρ = 0.0, dup = 0)
  rng = Xoshiro(seed)
  Z = randn(rng, n, p)
  if ρ > 0                                   # equicorrelated columns
    z0 = randn(rng, n)
    Z = sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* z0
  end
  if dup > 0                                  # last `dup` columns duplicate the first `dup` (rank deficient)
    Z[:, end-dup+1:end] .= Z[:, 1:dup]
  end
  b = zeros(p); b[1:k] .= [(-1)^j * (1 + j / k) for j in 1:k]
  Z, Z * b
end
function noisy(n, p, k, σ, seed)
  X, y = noiseless(n, p, k, seed)
  rng = Xoshiro(seed + 10_000)
  X, y .+ σ .* randn(rng, n)
end

function problems()
  P = NamedTuple[]
  add!(id, fam, X, y, λ; starts = (:zero, :lnfit, :warm)) = push!(P, (; id, family = fam, X, y, λ, starts))
  # analytic fixtures
  X = [1.0 1.0; 0.0 0.01]; add!("A155", "analytic-155", X, X * [1.0, -1.0], 0.1; starts = (:zero, :given))
  add!("A156", "analytic-156", [1.0 2.0; 0.0 1.0], [1.0, 0.0], 0.1; starts = (:zero, :given))
  add!("AI3", "analytic-identity", Matrix(1.0I, 3, 3), ones(3), 0.65; starts = (:zero, :given))
  # noiseless underdetermined (the #155 probe shape)
  for f in (0.05, 0.2), s in 1:8
    X, y = noiseless(8, 20, 3, s); add!("N8p20-$(f)-s$s", "noiseless n8 p20 $(f)λmax", X, y, f * lammax(X, y))
  end
  for f in (0.05, 0.2), s in 1:6
    X, y = noiseless(40, 120, 5, 100 + s); add!("N40p120-$(f)-s$s", "noiseless n40 p120 $(f)λmax", X, y, f * lammax(X, y))
  end
  for s in 1:3
    X, y = noiseless(100, 400, 10, 200 + s); add!("N100p400-s$s", "noiseless n100 p400 0.1λmax", X, y, 0.1 * lammax(X, y))
  end
  # near-exact fits
  for σ in (1e-7, 1e-4), s in 1:6
    X, y = noisy(30, 80, 4, σ, 300 + s); add!("NE$(σ)-s$s", "near-exact σ=$σ n30 p80 0.05λmax", X, y, 0.05 * lammax(X, y))
  end
  # ordinary (r* ≠ 0 expected)
  for s in 1:6
    X, y = noisy(60, 20, 4, 1.0, 400 + s); add!("O60p20-s$s", "ordinary n60 p20 σ=1 0.1λmax", X, y, 0.1 * lammax(X, y))
  end
  # λ sweep across the interpolation threshold (noisy p > n)
  for f in (0.1, 0.2, 0.3, 0.4), s in 1:4
    X, y = noisy(40, 120, 5, 0.5, 500 + s); add!("SW$(f)-s$s", "sweep noisy n40 p120 $(f)λmax", X, y, f * lammax(X, y))
  end
  # highly correlated and rank deficient (noiseless)
  for s in 1:6
    X, y = noiseless(40, 120, 5, 600 + s; ρ = 0.95); add!("C95-s$s", "correlated ρ=.95 n40 p120 0.1λmax", X, y, 0.1 * lammax(X, y))
  end
  for s in 1:6
    X, y = noiseless(20, 40, 3, 700 + s; dup = 10); add!("D10-s$s", "duplicate cols n20 p40 0.1λmax", X, y, 0.1 * lammax(X, y))
  end
  P
end

# starting points: :zero, :given (analytic fixture's start), :lnfit (least-norm interpolant X⁺y, an
# exact fit when rank X = n: an adversarial warm start), :warm (oracle β* + fixed perturbation; filled in
# by the runner from the oracle record)
function start_point(prob, kind, βref)
  p = size(prob.X, 2)
  kind === :zero && return zeros(p)
  kind === :given && return prob.id == "A155" ? [1.0, -1.0] : prob.id == "A156" ? [1.0, 0.0] : ones(3)
  kind === :lnfit && return pinv(prob.X) * prob.y
  kind === :warm && return βref .+ [isodd(k) ? 0.125 : -0.25 for k in 1:p] .* (norm(βref, Inf) + 1) ./ 8
  error("unknown start $kind")
end
