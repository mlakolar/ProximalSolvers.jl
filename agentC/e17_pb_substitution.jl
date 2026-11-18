include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss
println("E17 final decision with PB.norm_diff substituted for _se_norm_diff_onepass(_sumsq_diff(...)), julia ", VERSION)
src = read("<WORK>/ps-353/src/solvers/image_models.jl", String)
i = first(findfirst("function _bound_certified!", src)); j = first(findnext("\nend\n", src, i)) + 4
fn = src[i:j-1]
old = "N = _se_norm_diff_onepass(T, _sumsq_diff(zw, zu), zw, zu)"
@assert occursin(old, fn)
fn2 = replace(replace(fn, old => "N = _pb_N(T, zw, zu)"), "_bound_certified!" => "_bound_certified_pb!")
Core.eval(PS, quote
  _pb_N(::Type{T}, a, b) where {T} = (v = $(PB.norm_diff)(a, b); isfinite(v) ? _SE{T}(v) : nothing)
  $(Meta.parse(fn2))
end)
rng = Xoshiro(17)
sub(T) = T == Float32 ? -149 : -1074
ratio_exact(α, X, x, y, L) = (d = big_(x) - big_(y); BF(α) * sum(abs2, big_(X) * d) / (BF(L) * sum(abs2, d)))
for T in (Float32, Float64)
  E = T == Float32 ? 40 : 300; tol = (1 + 4eps(T))^2
  tPS = Tally("$T PS N: accept ⇒ exact inequality"); tPB = Tally("$T PB norm_diff N: accept ⇒ exact inequality")
  disagree = 0; nacc_ps = 0; nacc_pb = 0; subn_cases = 0
  for trial in 1:2500
    n, p = rand(rng, (1, 2, 5, 20, 60)), rand(rng, (1, 2, 5, 20))
    # mix of ordinary, wide-scale and deep-subnormal data (norm of Δz below floatmin)
    mode = rand(rng, 1:3)
    sc = mode == 1 ? 0 : mode == 2 ? rand(rng, -E:E) : sub(T) + rand(rng, 0:20)
    X = T.(randn(rng, n, p) .* 2.0^(mode == 3 ? rand(rng, -5:0) : sc ÷ 2)); c0 = rand(rng, Bool) ? 2.0^rand(rng, 0:E÷2) : 0.0
    xs = 2.0^(mode == 3 ? sub(T) + 5 : sc ÷ 2)
    xa = T.((c0 .+ randn(rng, p)) .* xs); xb = T.((c0 .+ randn(rng, p)) .* xs); x = T.(Float64.(xa) .+ randn(rng, p) .* 2.0^rand(rng, -10:0) .* xs)
    all(isfinite, X) && all(isfinite, x) && all(isfinite, xa) && all(isfinite, xb) || continue
    ω = rand(rng, (zero(T), T(0.25), T(0.9), one(T))); α = rand(rng, (1.0, 2.0^rand(rng, -20:20)))
    T == Float32 && !(isfinite(Float32(α)) && !iszero(Float32(α))) && continue
    y = similar(xa); PS.Blocks._extrapolate_point!(y, xa, xb, ω); all(isfinite, y) || continue
    za, zb = X * xa, X * xb; zu = @. za + ω * (za - zb); zw = X * x; d = x .- y
    (all(isfinite, zu) && all(isfinite, zw) && any(!=(0), d)) || continue
    c = PS._bound_constants(T, X); m = PS._image_model(isone(α) ? LeastSquaresLoss(zeros(T, n), X) : α * LeastSquaresLoss(zeros(T, n), X))
    na = PS._se_norm_onepass(T, sum(abs2, xa), xa); nb = PS._se_norm_onepass(T, sum(abs2, xb), xb); Ey = PS._image_error_bound(c, na, nb, ω > 0)
    sd, sx = PS._sumsq2(d, x); D = PS._se_norm_onepass(T, sd, d); nx = PS._se_norm_onepass(T, sx, x)
    (D === nothing || nx === nothing || iszero(D.s)) && continue
    rα = PS._root_scale(T, α); ρ1 = ratio_exact(α, X, x, y, one(T))
    Δ = bnormdiff(zw, zu); Δ < BF(floatmin(T)) && (subn_cases += 1)
    for f in (0.5, 0.99, 1 - 64eps(T), 1 + 4eps(T), 1 + 64eps(T), 1.01, 1.1, 2.0, 16.0, 1e3)
      L = T(ρ1 * f); (isfinite(L) && L >= floatmin(T)) || continue
      a = PS._bound_certified!(zeros(T, n), m, zu, zw, d, D, L, Ey, nx, rα, c, false)[1]
      b = PS._bound_certified_pb!(zeros(T, n), m, zu, zw, d, D, L, Ey, nx, rα, c, false)[1]
      ρ = ratio_exact(α, X, x, y, L)
      rec!(tPS, !a || ρ <= tol); rec!(tPB, !b || ρ <= tol)
      a != b && (disagree += 1); nacc_ps += a; nacc_pb += b
    end
  end
  report(tPS); report(tPB)
  println("   $T: accept decisions PS=$nacc_ps PB=$nacc_pb, decisions that differ=$disagree, cases with ‖Δz‖ < floatmin(T): $subn_cases")
end
