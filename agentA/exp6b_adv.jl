include("exp6_cert.jl")
# E6b: adversarial attempts at the edges of the certificate's proof: sr near n*2^-969 and near floatmax, columns near
# the overflow of a_k, rounding-mode and level-type games, huge cancellation (rhat rounding), many tiny terms.
viol = String[]; cases = 0; cert = 0
function chk(X, y, β, λ0; tag = "")
  global cases += 1
  r = one_case(X, y, β, λ0; tag)
  r.code === :certified && (global cert += 1)
  isempty(r.viols) || (push!(viol, tag * " :: " * join(r.viols, "; ")))
  r
end
rng = Xoshiro(5)
n, p = 8, 4
# (1) sr near the lower limit n*2^-969 (Float64): data (y) scaled so that ||r||^2 = n 2^-969 (1+δ)
n, p = 8, 4
for δ in (-1e-3, -1e-9, 1e-9, 1e-3, 1.0, 100.0), trial in 1:5
  X = randn(rng, n, p); y = randn(rng, n); y ./= norm(y)
  β = zeros(p)                    # r̂ = y exactly: sr = ||y||^2 · (scale)^2
  target = n * 2.0^-969 * (1 + δ)
  y .*= sqrt(target)              # sr = target
  λ = 1.2 * lam_max(X, y)
  r = chk(X, y, β, λ; tag = "lower-limit δ=$δ")
  trial == 1 && println("δ=$δ: code=", r.code, " ratio=", r.ratio)
end
# (2) large end: ||r||^2 near floatmax, y ~ 1e153, columns ~ 1e150
for sc in (1e150, 1e152, 1e153, 1e154), trial in 1:5
  X = randn(rng, n, p); y = randn(rng, n) .* sc
  β = zeros(p); λ = 1.2*lam_max(X, y)
  r = chk(X, y, β, λ; tag = "large y=$sc")
  trial == 1 && println("y~$sc: code=", r.code)
end
for sx in (1e150, 1e153), trial in 1:5      # a_k = n sx^2 ~ 1e300..1e307
  X = randn(rng, n, p) .* sx; y = randn(rng, n)
  λ = 1.2*lam_max(X, y)
  β = zeros(p)
  chk(X, y, β, λ; tag = "large X=$sx")
end
# (3) F32 near the sr limit: r̂ in Float64 for F32 data: no range issue except n 2^-969: F32 ||r||^2 >= 1e-90 >> n 2^-969
for sc in (1e-20, 1e-30, 1e-38), trial in 1:5
  X = randn(rng, Float32, n, p); y = Float32.(randn(rng, n) .* sc)
  chk(X, y, zeros(Float32, p), Float64(1.2*lam_max(X, y)); tag = "F32 tiny y=$sc")
end
# (4) rounding-mode games for levels
for mode in (RoundUp, RoundDown, RoundToZero, RoundNearest)
  setrounding(BigFloat, mode) do
    for trial in 1:10
      X = randn(rng, 10, 4); y = randn(rng, 10)
      λ0 = big"0.1"* (1 + trial*big"1e-3")
      m, g, x = make_model(X, y, λ0, zeros(4))
      lo, hi = m.lo64, m.hi64
      ok = lo <= λ0 <= hi
      ok || push!(viol, "bracket fails under BigFloat rounding $mode: $lo $hi")
      chk(X, y, 0.01 .* randn(rng, 4), λ0; tag = "bigfloat level under $mode")
    end
  end
end
# (5) huge cancellation: β = (2^53, 1, -2^53) style, many sizes
for s in 40:5:100, trial in 1:5
  X = ones(3, 3) .+ 0.0; X[2, 2] = 2.0; X[3, 3] = 3
  β = [2.0^s, rand(rng), -2.0^s * (1 + rand(rng)*2.0^-30)]
  y = X*β .+ randn(rng, 3)*1e-3
  chk(X, y, β, 0.5; tag = "cancellation s=$s")
end
# (6) many tiny terms: p = 3000 coefficients of size 1e-300 .. 1 mixed
for trial in 1:5
  n, p = 50, 3000
  X = randn(rng, n, p); β = (rand(rng, p) .< 0.5) .* (10.0 .^ rand(rng, -300:0, p)) .* rand(rng, [-1,1], p)
  y = X*β .+ randn(rng, n) .* 0.1
  chk(X, y, β, 0.1*lam_max(X, y); tag = "many mixed-scale coefficients")
end
# (7) y = 0 and β≠0 (P* = 0): must not certify
X = randn(rng, 5, 3)
r = chk(X, zeros(5), [1e-3, 0, 0], 0.5; tag = "y=0 beta!=0"); r.code === :certified && push!(viol, "FALSE CERTIFICATE y=0 beta!=0")
# (8) exact-fit points with tiny r̂: rounded zero, never a false certificate (compare against P* ≥ θ'y only)
for trial in 1:200
  n, p = 4, 6
  X = round.(randn(rng, n, p) .* 4) ./ 4; β = round.(randn(rng, p) .* 4) ./ 4
  y = X*β            # exact fit (dyadic): r = 0 exactly
  r = chk(X, y, β, rand(rng, (0.01, 0.2, 1.0)); tag = "exact fit dyadic")
end
println("cases=$cases certified=$cert violations=$(length(viol))"); foreach(println, first(viol, 20))
