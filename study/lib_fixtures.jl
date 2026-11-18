# The fixture generators of lib.jl, alone (no package is loaded here).
# ---- deterministic numbers (splitmix64; only +, *, shifts, so inputs are the same on every Julia) ----
mutable struct SM64
  s::UInt64
end
function next!(g::SM64)
  g.s += 0x9e3779b97f4a7c15
  z = g.s
  z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
  z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
  z ⊻ (z >> 31)
end
unif(g::SM64) = (next!(g) >> 11) * 2.0^-53
# approximately standard normal: a sum of 12 uniforms minus 6 (no libm call)
function gaussish(g::SM64)
  s = -6.0
  for _ in 1:12
    s += unif(g)
  end
  s
end
gmat(g, n, p) = [gaussish(g) for _ in 1:n, _ in 1:p]
gvec(g, n) = [gaussish(g) for _ in 1:n]

# ---- fixtures: (name, X, y) in Float64; the caller rounds them to T ----
function hadamard(n)
  H = ones(1, 1)
  while size(H, 1) < n
    H = [H H; H -H]
  end
  H
end
function sparse_truth(g, p, k)
  b = zeros(p)
  for j in 1:k
    b[1 + (7j) % p] = (isodd(j) ? 1.0 : -1.0) * (1 + unif(g))
  end
  b
end
function fixtures()
  out = Tuple{String, Matrix{Float64}, Vector{Float64}}[]
  g = SM64(0x352)
  # orthogonal columns (exactly, in both precisions)
  X = hadamard(32)[:, 2:9]
  push!(out, ("orth", X, X * sparse_truth(g, 8, 3) + 0.5 * gvec(g, 32)))
  # i.i.d. columns
  X = gmat(g, 40, 12)
  push!(out, ("gauss", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # equicorrelated, rho = 0.95
  Z, z0 = gmat(g, 40, 12), gvec(g, 40)
  X = sqrt(0.05) .* Z .+ sqrt(0.95) .* z0
  push!(out, ("corr95", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # rank deficient: 6 independent columns, 4 exact copies or sums, 2 near copies
  B = gmat(g, 40, 6)
  X = hcat(B, B[:, 1], B[:, 2] + B[:, 3], B[:, 4] - B[:, 5], 2 .* B[:, 6],
           B[:, 1] + 1e-6 .* gvec(g, 40), B[:, 2] + 1e-9 .* gvec(g, 40))
  push!(out, ("rankdef", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # underdetermined, noisy
  X = gmat(g, 20, 60)
  push!(out, ("wide", X, X * sparse_truth(g, 60, 5) + 0.5 * gvec(g, 20)))
  # underdetermined, exact fit
  X = gmat(g, 20, 60)
  push!(out, ("wide_exact", X, X * sparse_truth(g, 60, 5)))
  # a zero column and a column orthogonal to y by construction
  X = gmat(g, 40, 12)
  X[:, 3] .= 0
  push!(out, ("zerocol", X, X * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # column norms spread over 10^-3 .. 10^3
  X = gmat(g, 40, 12) .* reshape([10.0^(-3 + 6 * (j - 1) / 11) for j in 1:12], 1, 12)
  push!(out, ("colscale", X, gmat(g, 40, 12) * sparse_truth(g, 12, 4) + 0.5 * gvec(g, 40)))
  # tall and noiseless (near exact fit with a small penalty)
  X = gmat(g, 60, 10)
  push!(out, ("tall_exact", X, X * sparse_truth(g, 10, 3)))
  # response dwarfs the residual: a large offset in the span of X
  X = hcat(ones(50), gmat(g, 50, 9))
  push!(out, ("offset", X, 1e6 .+ X[:, 2:end] * sparse_truth(g, 9, 3) + 0.5 * gvec(g, 50)))
  # y = 0
  push!(out, ("yzero", gmat(g, 30, 8), zeros(30)))
  out
end
fixture(name) = only(f for f in fixtures() if f[1] == name)

