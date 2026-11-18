# problem set of the controls (needs Ref321 as R, Random, Statistics, LinearAlgebra)
function design(::Type{T}, n, p; seed = 1, cond = 1.0, zero_cols = 0, xscale = 1.0, standardize = true) where T
  rng = Xoshiro(seed + 1000n + p)
  X = randn(rng, n, p)
  if cond > 1
    U = Matrix(qr(randn(rng, n, p)).Q)[:, 1:p]; V = Matrix(qr(randn(rng, p, p)).Q)
    X = U * Diagonal(exp10.(range(0, -log10(cond), length = p))) * V' .* sqrt(n)
  elseif standardize
    X .-= mean(X, dims = 1); X ./= std(X, dims = 1)
  end
  for j in 1:zero_cols; X[:, j] .= 0; end
  β = zeros(p); β[1:min(p, 5)] .= randn(rng, min(p, 5))
  y = X * β .+ 0.1 .* randn(rng, n)
  (T.(X .* xscale), T.(y), β)
end

struct Prob; name::String; T::DataType; X; y; α; λ; x0; end
probs = Prob[]
add!(name, T, X, y, α, λ, x0 = zeros(T, size(X, 2))) = push!(probs, Prob(name, T, X, y, α, λ, x0))
λrel(X, y, α, c) = c * Float64(R.λmax(X, y, α))

for T in (Float64, Float32)
  tn = string(T)
  X, y, _ = design(T, 100, 20)
  add!("ord-norm-$tn", T, X, y, 1 / 100, T(λrel(X, y, 1 / 100, 0.1)))          # α = 1/n, standardized, λ = 0.1 λmax
  add!("ord-raw-$tn", T, X, y, 1.0, T(λrel(X, y, 1.0, 0.1)))                    # unscaled (α = 1; stored as LeastSquaresLoss)
  add!("ord-lambda0-$tn", T, X, y, 1 / 100, T(0))
  add!("ord-lowlam-$tn", T, X, y, 1 / 100, T(λrel(X, y, 1 / 100, 1e-3)))
  Xb, yb, _ = design(T, 400, 60; seed = 2)
  add!("ord-wide-$tn", T, Xb, yb, 1 / 400, T(λrel(Xb, yb, 1 / 400, 0.05)))
  Xp, yp, _ = design(T, 50, 120; seed = 3)
  add!("ord-p>n-$tn", T, Xp, yp, 1 / 50, T(λrel(Xp, yp, 1 / 50, 0.1)))
  for a in (T === Float64 ? (1e-12, 1e-6, 1e-3, 1e3, 1e6) : (1e-6, 1e-3, 1e3))
    add!("alpha=$(a)-$tn", T, X, y, a, T(λrel(X, y, a, 0.1)))
  end
  for s in (1e-3, 1e3)
    Xs, ys, _ = design(T, 100, 20; xscale = s)
    add!("xscale=$(s)-$tn", T, Xs, ys, 1 / 100, T(λrel(Xs, ys, 1 / 100, 0.1)))
  end
  Xz, yz, _ = design(T, 100, 20; zero_cols = 4)
  add!("zerocols-$tn", T, Xz, yz, 1 / 100, T(λrel(Xz, yz, 1 / 100, 0.1)))
  Xi4, yi4, _ = design(T, 100, 10; cond = 1e4, seed = 4)
  add!("cond1e4-lam0-$tn", T, Xi4, yi4, 1 / 100, T(0))
  add!("cond1e4-lam-$tn", T, Xi4, yi4, 1 / 100, T(λrel(Xi4, yi4, 1 / 100, 1e-3)))
  Xi6, yi6, _ = design(T, 100, 10; cond = 1e6, seed = 5)
  add!("cond1e6-lam0-$tn", T, Xi6, yi6, 1 / 100, T(0))
  # warm starts: the solution at a larger λ, and a start scaled far from the solution
  xw = T.(R.xstar(X, y, 1 / 100, 2 * Float64(T(λrel(X, y, 1 / 100, 0.1)))))
  add!("warm-lam2x-$tn", T, X, y, 1 / 100, T(λrel(X, y, 1 / 100, 0.1)), xw)
  add!("warm-far-$tn", T, X, y, 1 / 100, T(λrel(X, y, 1 / 100, 0.1)), T(50) .* xw)
  # coefficient magnitude: moderate and large
  Xm, ym, _ = design(T, 100, 20; seed = 6)
  βm = T(1e3) .* T.(randn(Xoshiro(7), 20))
  ym = Xm * βm .+ T(0.1) .* T.(randn(Xoshiro(8), 100))
  add!("coef1e3-$tn", T, Xm, ym, 1 / 100, T(λrel(Xm, ym, 1 / 100, 0.01)))
end
# extreme but representable, Float64 only: the response (hence x) at 1e50 and 1e100 with the scale compensating
for (s, a) in ((1e50, 1e-100), (1e100, 1e-200), (1e120, 1e-250))
  X, y, _ = design(Float64, 100, 20; seed = 9)
  ys = y .* s
  add!("extreme-s=$(s)-α=$(a)-ordinary-design", Float64, X, ys, a, λrel(X, ys, a, 0.1))
  add!("extreme-s=$(s)-α=$(a)-lam0", Float64, X, ys, a, 0.0)
end
# a large scale (L_f above 1) with a tiny response, Float64 and Float32
let (X, y, _) = design(Float64, 100, 20; seed = 10)
  add!("bigalpha=1e100-F64", Float64, X, y .* 1e-50, 1e100, λrel(X, y .* 1e-50, 1e100, 0.1))
  add!("bigalpha=1e30-F64", Float64, X, y .* 1e-15, 1e30, λrel(X, y .* 1e-15, 1e30, 0.1))
end
let (X, y, _) = design(Float32, 100, 20; seed = 11)
  add!("bigalpha=1e20-F32", Float32, X, y .* 1f-10, 1e20, Float32(λrel(X, y .* 1f-10, 1e20, 0.1)))
end
# the #321 problems
add!("R5-F64-lam0", Float64, ones(5, 1), fill(1e160, 5), 1e-100, 0.0)
add!("R5-F64-lam", Float64, ones(5, 1), fill(1e160, 5), 1e-100, 0.1 * 5e60)
add!("#327-F64", Float64, [1.0;;], [1e160], 5e-100, 0.0)
add!("F32-wide(α=1e-30)", Float32, ones(Float32, 5, 1), fill(1f20, 5), 1e-30, 0f0)
add!("F32-wide(α=1e-10)", Float32, ones(Float32, 5, 1), fill(1f20, 5), 1e-10, 0f0)
# the tiny-α family of #316/#317 on an ordinary design: response 1e30..1e100, α compensating
for (s, a) in ((1e10, 1e-20), (1e30, 1e-60), (1e60, 1e-120))
  X, y, _ = design(Float64, 100, 20; seed = 12)
  add!("tinyα-s=$(s)-α=$(a)", Float64, X, y .* s, a, λrel(X, y .* s, a, 0.1))
end

