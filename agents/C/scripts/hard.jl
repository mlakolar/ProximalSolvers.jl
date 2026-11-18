# Second stress catalogue (hard cases). Deterministic from the seeds in the ids/descriptions.
include(joinpath(@__DIR__, "stress.jl"))

# #156-type random construction: exact-fit optimum with support S (|S| = k < n), signs s, a feasible dual θ0
# (‖θ0‖ = 0.5) with X_Sᵀθ0 = λ s and |X_{S^c}ᵀθ0| ≤ 0.8 λ; y = X_S β_S with sign(β_S) = s. The least-norm
# support dual θ_LN = X_S (X_SᵀX_S)^{-1} λ s may be infeasible.
function ex156(n, p, k, seed; λ = 0.3)
  rng = Xoshiro(seed)
  X = randn(rng, n, p) ./ sqrt(n)
  θ0 = randn(rng, n); θ0 .*= 0.5 / norm(θ0)
  s = rand(rng, (-1.0, 1.0), k)
  for j in 1:p
    c = dot(X[:, j], θ0)
    if j <= k
      X[:, j] .+= ((λ * s[j] - c) / dot(θ0, θ0)) .* θ0
    elseif abs(c) > 0.8λ
      X[:, j] .+= ((sign(c) * 0.8λ * rand(rng) - c) / dot(θ0, θ0)) .* θ0
    end
  end
  βS = s .* (0.5 .+ rand(rng, k)); y = X[:, 1:k] * βS
  β = zeros(p); β[1:k] .= βS
  θLN = X[:, 1:k] * ((X[:, 1:k]' * X[:, 1:k]) \ (λ .* s))
  feasLN = maximum(abs, X' * θLN) <= λ * (1 + 1e-12) && norm(θLN) <= 1
  (; X, y, λ, β, θ0, θLN, feasLN, feas0 = maximum(abs, X' * θ0) <= λ * (1 + 1e-12))
end

function hard_problems(; wide = true)
  P = NamedTuple[]
  add!(id, desc, X, y, λ, starts) = push!(P, (; id, desc, X, y, λ, starts))
  lnfit(X, y) = "lnfit" => pinv(X) * y
  for (n, p, k) in ((40, 120, 5), (100, 400, 10)), f in (1e-2, 1e-3, 1e-4)
    X, y = noiseless(n, p, k, 11000 + n); add!("SMALLLAM-n$(n)p$(p)-$f", "noiseless n$n p$p (seed $(11000+n)), λ = $f λmax", X, y, f * lammax(X, y), [lnfit(X, y)])
  end
  for (n, p, ρ, sd) in ((100, 1000, 0.99, 12001), (40, 120, 0.999, 12002), (40, 120, 0.9999, 12003))
    X, y = noiseless(n, p, 5, sd; ρ); add!("CORR$(ρ)-n$(n)p$(p)", "equicorrelated ρ=$ρ n$n p$p (seed $sd), 0.1λmax", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
  end
  if wide
    X, y = noiseless(100, 10000, 10, 13001); add!("WIDE-n100p10000", "noiseless n100 p10000 (seed 13001) 0.1λmax", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
  end
  # near-duplicates with cancelling huge coefficients
  for (e, sd) in ((1e-6, 14001), (1e-9, 14002))
    rng = Xoshiro(sd); X, y = noiseless(15, 40, 3, sd); X[:, 2] .= X[:, 1] .+ e .* randn(rng, 15)
    b0 = pinv(X) * y; b1 = copy(b0); b1[1] += 1e5; b1[2] -= 1e5
    add!("CANCEL$(e)-n15p40", "col2 = col1 + $e g (seed $sd), start has ±1e5 cancelling pair", X, y, 0.1 * lammax(X, y), ["lnfit" => b0, "cancel" => b1])
  end
  # Vandermonde-like ill conditioned
  let n = 30, p = 60
    t = range(-1, 1; length = p); X = [t[j]^(i - 1) for i in 1:n, j in 1:p]
    b = zeros(p); b[[5, 20, 41]] .= [1.0, -2.0, 1.5]; y = X * b
    add!("VAND-n30p60", "Vandermonde nodes linspace(-1,1,60), powers 0..29, 3-sparse b at 5,20,41", X, y, 0.05 * lammax(X, y), [lnfit(X, y)])
  end
  # non-exact-fit optimum with p > n (ordinary-like) from the exact-fit start
  for s in 1:2, f in (0.5, 0.7)
    X, y = noisy(20, 60, 3, 0.5, 9500 + s); add!("NONEX$(f)-n20p60-s$s", "noisy σ=.5 n20 p60 (seed $(9500+s)), $(f)λmax", X, y, f * lammax(X, y), [lnfit(X, y)])
  end
  # #156-type random constructions
  for (n, p, k, sd) in ((10, 30, 5, 15001), (10, 30, 5, 15002), (50, 200, 25, 15003), (50, 200, 25, 15004), (50, 200, 10, 15005), (200, 800, 100, 15006), (200, 800, 100, 15007))
    e = ex156(n, p, k, sd)
    add!("E156-n$(n)p$(p)k$(k)-$sd", "ex156 construction seed $sd: feasibleLN=$(e.feasLN) feasible θ0=$(e.feas0)", e.X, e.y, e.λ, ["optimum" => e.β, lnfit(e.X, e.y)])
  end
  P
end
