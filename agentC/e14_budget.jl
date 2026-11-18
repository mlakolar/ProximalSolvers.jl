include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss
println("E14 rounding budget of the cheap accept test: do the roundings of the constants and _SE operations stay inside κ = 32u? julia ", VERSION)
rng = Xoshiro(14)
# ideal (all-BigFloat) value of the left side bound and the right side of the cheap accept test, from the same
# computed norms N, D, normx, na, nb, and the exact ‖X‖_F, √α, √L; compared with the computed _SE chain of _bound_certified!.
function budget(T, X, xa, xb, x, ω, α, L)
  n, p = size(X); u = BF(unit(T)); ε = BF(eps(T))
  y = similar(xa); PS.Blocks._extrapolate_point!(y, xa, xb, ω)
  za, zb = X * xa, X * xb; zu = @. za + ω * (za - zb); zw = X * x; d = x .- y
  (any(!=(0), d) && all(isfinite, y) && all(isfinite, zu) && all(isfinite, zw)) || return nothing
  c = PS._bound_constants(T, X)
  na = PS._se_norm_onepass(T, sum(abs2, xa), xa); nb = PS._se_norm_onepass(T, sum(abs2, xb), xb)
  Ey = PS._image_error_bound(c, na, nb, ω > 0)
  sd, sx = PS._sumsq2(d, x); D = PS._se_norm_onepass(T, sd, d); nx = PS._se_norm_onepass(T, sx, x)
  N = PS._se_norm_diff_onepass(T, PS._sumsq_diff(zw, zu), zw, zu)
  (D === nothing || nx === nothing || N === nothing || iszero(D.s)) && return nothing
  rα = PS._root_scale(T, α); rootL = PS._SE{T}(sqrt(L))
  # computed chain (as in _bound_certified!)
  acc_rhs = PS._se_mul(c.accept, rootL, c.lower_step, D)
  E = PS._se_add(PS._se_add(PS._se_mul(c.product, c.upper_x, nx), c.under_product), Ey)
  upper = PS._se_add(PS._se_mul(N, c.upper_image), E)
  lhs = PS._se_mul(rα, upper)
  # ideal chain
  δn, δp, γp = BF(gam(T, n + 4)), BF(gam(T, p + 4)), BF(gam(T, p))
  # exact γ's from rationals
  ku(k) = k * u; γ(k) = ku(k) / (1 - ku(k)); δn, δp, γp = γ(n + 4), γ(p + 4), γ(p)
  fro = bnorm(X); η = BF(nextfloat(zero(T)))
  Nb, Db, nxb, nab, nbb = se2big.((N, D, nx, na, nb))
  upx = nxb / (1 - δp)
  Eideal = γp * fro * upx + 2 * p * sqrt(BF(n)) * η
  Ey_ideal = ω > 0 ? (2γp + 16u) * fro * (nab + nbb) / (1 - δp) + (8p * sqrt(BF(n)) * η + 2 * sqrt(BF(p)) * fro * η) :
                     γp * fro * nab / (1 - δp) + 2p * sqrt(BF(n)) * η
  up_id = sqrt(BF(α)) * (Nb / ((1 - δn) * (1 - u)) + Eideal + Ey_ideal)
  rhs_id = (1 + 4ε) * sqrt(BF(L)) * Db / ((1 + δp) * (1 + u))
  lhs_c, rhs_c = se2big(lhs), se2big(acc_rhs)
  (; r_L = lhs_c / up_id - 1, r_R = rhs_id / rhs_c - 1, prod = (lhs_c / up_id) * (rhs_id / rhs_c), u = Float64(u))
end
for T in (Float32, Float64)
  E = T == Float32 ? 30 : 200
  minprod = Inf; minL = Inf; minR = Inf; nn = 0; bad = 0
  for trial in 1:3000
    n, p = rand(rng, (1, 2, 5, 20, 100, 500)), rand(rng, (1, 2, 5, 20, 100))
    X = T.(randn(rng, n, p) .* 2.0^rand(rng, -E:E)); c0 = rand(rng, Bool) ? 2.0^rand(rng, 0:E) : 0.0
    xa = T.(c0 .+ randn(rng, p)); xb = T.(c0 .+ randn(rng, p)); x = T.(Float64.(xa) .+ randn(rng, p) .* 2.0^rand(rng, -10:0))
    ω = rand(rng, (zero(T), T(0.25), T(0.9), one(T))); α = rand(rng, (1.0, 2.0^rand(rng, -20:20)))
    T == Float32 && !(isfinite(Float32(α)) && !iszero(Float32(α))) && continue
    all(isfinite, X) && all(isfinite, x) || continue
    L = T(rand(rng) * 2.0^rand(rng, -E÷2:E÷2))
    (isfinite(L) && L > floatmin(T)) || continue
    r = budget(T, X, xa, xb, x, ω, α, L)
    r === nothing && continue
    nn += 1
    minprod = min(minprod, Float64(r.prod - 1) / r.u)
    minL = min(minL, Float64(r.r_L) / r.u); minR = min(minR, Float64(r.r_R) / r.u)
    # the accept rule needs (computed LHS ≤ computed RHS) ⇒ ideal LHS ≤ ideal RHS; this holds if prod >= 1 (up to the κ margin already inside `accept`)
    Float64(r.prod - 1) < 0 && (bad += 1)
  end
  @printf("  %-8s samples=%d  min(lhs_computed/lhs_ideal - 1)/u=%.2f  min(rhs_ideal/rhs_computed - 1)/u=%.2f  min(product - 1)/u=%.2f (>=0 required; κ=32u is inside rhs)  violations=%d\n", T, nn, minL, minR, minprod, bad)
end
