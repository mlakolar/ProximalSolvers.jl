# Stress problem catalogue for agent C. Every problem is deterministic from the seeds below.
# `stress_problems()` -> Vector of (; id, desc, X, y, λ, starts::Vector{Pair{String,Vector{Float64}}}).
include(joinpath(@__DIR__, "lib.jl"))
include("<RUN>/scripts/oracle.jl")

# oracle record for arbitrary (X,y,λ) (data of type T rounded and then solved as exact data)
function oracle_for(X, y, λ, ::Type{T}) where T
  X64, y64, λ64 = Float64.(T.(X)), Float64.(T.(y)), Float64(T(λ))
  β, sp = primal(X64, y64, λ64)
  θ, sd = dual(X64, y64, λ64)
  U = Pbig(X64, y64, λ64, β)
  D, θf = dual_lower(X64, y64, λ64, θ)
  rrel = Float64(norm(big.(y64) - big.(X64) * big.(β)) / norm(big.(y64)))
  (; β, θ = Float64.(θf), U = Float64(U), D = Float64(D), relwidth = Float64((U - D) / D), rrel,
     exactfit = rrel < 1e-8, status = (sp, sd))
end

nullbasis(X) = (F = svd(X; full = true); F.V[:, size(X, 1)+1:end])

function lam_critical(X, y; lo = 0.0, hi = lammax(X, y), iters = 40)
  # largest λ whose optimum is an exact fit (r*/‖y‖ < 1e-9), by bisection with Clarabel
  isexact(λ) = begin
    b, _ = primal(X, y, λ)
    norm(y - X * b) / norm(y) < 1e-9
  end
  lo = 1e-3 * hi
  isexact(lo) || return NaN
  for _ in 1:iters
    mid = (lo + hi) / 2
    isexact(mid) ? (lo = mid) : (hi = mid)
  end
  lo
end

function stress_problems(; large = true)
  P = NamedTuple[]
  add!(id, desc, X, y, λ, starts) = push!(P, (; id, desc, X, y, λ, starts))
  lnfit(X, y) = "lnfit" => pinv(X) * y
  # HUGE: exact-fit start with a huge nullspace component (P_stuck/P* ≫ 1)
  for s in 1:3
    X, y = noiseless(20, 60, 3, 1000 + s); λ = 0.1 * lammax(X, y)
    N = nullbasis(X); rng = Xoshiro(1100 + s); z = randn(rng, size(N, 2))
    b0 = pinv(X) * y
    add!("HUGE-n20p60-s$s", "noiseless n20 p60 (seed $(1000+s)), exact-fit starts with nullspace component 1e2,1e4,1e6 (z seed $(1100+s))",
         X, y, λ, ["lnfit" => b0, ("huge$e" => b0 .+ 10.0^e .* (N * z) for e in (2, 4, 6))...])
  end
  # SCALE: badly scaled columns 10^U(-3,3)
  for s in 1:3
    rng = Xoshiro(2000 + s); X0, _ = noiseless(15, 40, 3, 2000 + s)
    sc = 10.0 .^ (3 .* rand(rng, 40) .- 1.5); X = X0 .* sc'
    b = zeros(40); b[1:3] .= [-1.0, 1.5, 2.0] ./ sc[1:3]; y = X * b       # coefficients of order 1/scale
    add!("SCALE-n15p40-s$s", "noiseless n15 p40 columns scaled 10^U(-1.5,1.5) (seed $(2000+s))", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
  end
  # TINYY / BIGY: homogeneity in y (λmax is invariant)
  for (nm, f) in (("TINY12", 2.0^-40), ("BIG12", 2.0^40), ("TINY20", 2.0^-66), ("BIG20", 2.0^66))
    X, y = noiseless(20, 60, 3, 3001); add!("$(nm)-n20p60", "noiseless n20 p60 (seed 3001), y scaled by $f", X, f .* y, 0.1 * lammax(X, y), [lnfit(X, f .* y)])
  end
  # λ near the interpolation threshold λc (largest λ with an exact-fit optimum)
  for s in 1:3
    X, y = noiseless(10, 30, 3, 4000 + s); λc = lam_critical(X, y)
    for (nm, f) in (("0.5", 0.5), ("0.99", 0.99), ("1.0", 1.0), ("1.01", 1.01), ("1.2", 1.2))
      add!("LAMC$(nm)-n10p30-s$s", "noiseless n10 p30 (seed $(4000+s)), λ = $(nm) λc, λc=$(λc) (exact-fit threshold by bisection)", X, y, f * λc, [lnfit(X, y)])
    end
  end
  # duplicated / near-duplicated columns
  for s in 1:3
    X, y = noiseless(15, 40, 3, 5000 + s; dup = 10); add!("DUP-n15p40-s$s", "10 exactly duplicated columns (seed $(5000+s))", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
    X, y = noiseless(15, 40, 3, 5000 + s; dup = 10); rng = Xoshiro(5100 + s)
    X[:, end-9:end] .+= 1e-8 .* randn(rng, 15, 10)
    add!("NDUP-n15p40-s$s", "10 duplicated columns + 1e-8 noise (seeds $(5000+s), $(5100+s))", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
  end
  # nearly rank-deficient X: singular values 10^(-10 (i-1)/(n-1))
  for s in 1:3
    rng = Xoshiro(6000 + s); n, p = 30, 60
    U = Matrix(qr(randn(rng, n, n)).Q); V = Matrix(qr(randn(rng, p, n)).Q)
    X = U * Diagonal(10.0 .^ (-10 .* (0:n-1) ./ (n - 1))) * V'
    b = zeros(p); b[randperm(rng, p)[1:3]] .= [1.0, -2.0, 1.5]; y = X * b
    add!("LOWRANK-n30p60-s$s", "X = U diag(10^(-10 (i-1)/29)) V' (seed $(6000+s)), 3-sparse b", X, y, 0.1 * lammax(X, y), [lnfit(X, y)])
  end
  # identity-type: k-coordinate block moves fail; zero is optimal; start at the exact fit
  for n in (50, 200, 1000)
    add!("ID$n", "X = I_$n, y = 1, λ = (1 + 0.25/n)/√n ∈ (1/√n, 1/√(n-1))", Matrix(1.0I, n, n), ones(n), (1 + 0.25 / n) / sqrt(n), ["given" => ones(n)])
  end
  for n in (50, 200)
    rng = Xoshiro(7000 + n); Q = Matrix(qr(randn(rng, n, n)).Q); y = Q * ones(n)
    add!("ORTH$n", "X = random orthogonal $n (seed $(7000+n)), y = X*1, λ = 1.001 λmax", Q, y, 1.001 * lammax(Q, y), ["given" => ones(n)])
    for ε in (0.1, 0.5)
      rng = Xoshiro(7100 + n); X = Matrix(1.0I, n, n) .+ ε .* randn(rng, n, n) ./ sqrt(n); y = X * ones(n)
      add!("PERT$(ε)-$n", "X = I + $ε G/√n (seed $(7100+n)), y = X*1, λ = 1.001 λmax", X, y, 1.001 * lammax(X, y), ["given" => ones(n)])
    end
  end
  # Float32 at its rounding floor: near-exact fits with noise 3e-8, 1e-6, 1e-5 relative
  for σ in (3e-8, 1e-6, 1e-5), s in 1:2
    X, y = noisy(30, 80, 4, σ, 8000 + s); add!("FLOOR$(σ)-n30p80-s$s", "noisy n30 p80 σ=$σ (seed $(8000+s))", X, y, 0.05 * lammax(X, y), [lnfit(X, y)])
  end
  if large
    for (n, p, k, f) in ((100, 1000, 8, 0.1), (200, 2000, 10, 0.05), (200, 2000, 10, 0.2))
      X, y = noiseless(n, p, k, 9000 + n); add!("LARGE-n$(n)p$(p)-$f", "noiseless n$n p$p k=$k (seed $(9000+n)), $(f)λmax", X, y, f * lammax(X, y), [lnfit(X, y)])
    end
  end
  # p > n whose optimum is NOT an exact fit (ordinary), with the exact-fit start
  for s in 1:2
    X, y = noisy(20, 60, 3, 0.5, 9500 + s); add!("NONEXACT-n20p60-s$s", "noisy σ=0.5 n20 p60 (seed $(9500+s)), 0.3λmax", X, y, 0.3 * lammax(X, y), [lnfit(X, y)])
  end
  P
end
