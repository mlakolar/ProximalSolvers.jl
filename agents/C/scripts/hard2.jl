# Third catalogue: #156-type constructions with an INFEASIBLE least-norm support dual, #155 invertible-X families.
include(joinpath(@__DIR__, "hard.jl"))

# like ex156, but each off-support column gets a large component g·w along w = θ_LN/‖θ_LN‖ (so that
# x_jᵀθ_LN = g‖θ_LN‖ > λ for some j), while its θ0-inner product is repaired along θ0 - (θ0ᵀw)w ⟂ w, so θ0 stays feasible.
function ex156b(n, p, k, seed; λ = 0.3, g = 3.0)
  rng = Xoshiro(seed)
  X = randn(rng, n, p) ./ sqrt(n)
  θ0 = randn(rng, n); θ0 .*= 0.5 / norm(θ0)
  s = rand(rng, (-1.0, 1.0), k)
  for j in 1:k
    X[:, j] .+= ((λ * s[j] - dot(X[:, j], θ0)) / dot(θ0, θ0)) .* θ0
  end
  XS = X[:, 1:k]
  θLN = XS * ((XS' * XS) \ (λ .* s)); w = θLN / norm(θLN)
  v = θ0 - dot(θ0, w) * w
  for j in k+1:p
    X[:, j] .+= (g * randn(rng)) .* w
    t = (rand(rng) * 1.6 - 0.8) * λ                     # target θ0-inner product in (-0.8λ, 0.8λ)
    X[:, j] .+= ((t - dot(X[:, j], θ0)) / dot(v, θ0)) .* v
  end
  βS = s .* (0.5 .+ rand(rng, k)); y = XS * βS
  β = zeros(p); β[1:k] .= βS
  feasLN = maximum(abs, X' * θLN) <= λ * (1 + 1e-12) && norm(θLN) <= 1
  feas0 = maximum(abs, X' * θ0) <= λ * (1 + 1e-12) && norm(θ0) <= 1
  (; X, y, λ, β, θ0, θLN, feasLN, feas0, viol = maximum(abs, X' * θLN) / λ)
end

function hard2_problems()
  P = NamedTuple[]
  add!(id, desc, X, y, λ, starts) = push!(P, (; id, desc, X, y, λ, starts))
  for (n, p, k, sd) in ((10, 30, 3, 16001), (10, 30, 3, 16002), (10, 30, 5, 16003), (50, 200, 10, 16004), (50, 200, 10, 16005), (50, 200, 25, 16006),
                        (200, 800, 40, 16007), (200, 800, 100, 16008))
    e = ex156b(n, p, k, sd)
    add!("F156-n$(n)p$(p)k$(k)-$sd", "ex156b seed $sd: feasLN=$(e.feasLN) feas0=$(e.feas0) maxviolLN=$(round(e.viol; digits = 3))", e.X, e.y, e.λ, ["optimum" => e.β, "lnfit" => pinv(e.X) * e.y])
  end
  # #155-type invertible X: m/2 block-diagonal copies of A155 (X invertible, exact-fit start (1,-1,...), optimum 0)
  for m in (10, 50)
    X = zeros(m, m)
    for b in 1:m÷2; X[2b-1:2b, 2b-1:2b] .= [1.0 1.0; 0.0 0.01]; end
    β0 = repeat([1.0, -1.0], m ÷ 2); y = X * β0
    add!("BLK155-m$m", "m/2 blocks of the A155 matrix, y = X(1,-1,...), λ=0.1 (X invertible)", X, y, 0.1, ["given" => β0])
  end
  # ill-conditioned invertible X (κ = 1e4), exact-fit start with dense ±1, λ = 1.001 λmax (so 0 is optimal)
  for (n, sd) in ((30, 17001), (100, 17002))
    rng = Xoshiro(sd); U = Matrix(qr(randn(rng, n, n)).Q); V = Matrix(qr(randn(rng, n, n)).Q)
    X = U * Diagonal(10.0 .^ (-4 .* (0:n-1) ./ (n - 1))) * V'
    β0 = rand(rng, (-1.0, 1.0), n); y = X * β0
    add!("ILLINV-n$n", "X = U diag(10^(-4(i-1)/(n-1))) V' (seed $sd) invertible, y = Xβ0 (β0 = ±1), λ = 1.001 λmax", X, y, 1.001 * lammax(X, y), ["given" => β0])
  end
  P
end
