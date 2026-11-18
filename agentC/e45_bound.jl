include(joinpath(@__DIR__, "common.jl"))
println("E4/E5 image error bound, cheap-path chain and final decision on julia ", VERSION)
rng = Xoshiro(45)
sub(T) = T == Float32 ? -149 : -1074
function setup(T, n, p, E, subn)
  X = T.(randn(rng, n, p) .* 2.0^(subn ? rand(rng, -E:0) + sub(T) + E : rand(rng, -E:E)))
  c = rand(rng, Bool) ? 2.0^rand(rng, 0:E) : 0.0
  xs = subn ? 2.0^(sub(T) + 3) : 1.0
  xa = T.((c .+ randn(rng, p)) .* xs); xb = T.((c .+ randn(rng, p)) .* xs)
  x = T.(Float64.(xa) .+ randn(rng, p) .* 2.0^rand(rng, -E÷2:0) .* xs)
  X, xa, xb, x
end
# the solver's own formulas: y, zu (extrapolated), zw = X x, and the PS quantities
function solver_quantities(T, X, xa, xb, x, ω)
  extrapolated = ω > 0
  za, zb = X * xa, X * xb
  y = similar(xa); PS.Blocks._extrapolate_point!(y, xa, xb, ω)
  zu = similar(za); @. zu = za + ω * (za - zb)
  zw = X * x
  bc = PS._bound_constants(T, X)
  na = PS._se_norm_onepass(T, sum(abs2, xa), xa); nb = PS._se_norm_onepass(T, sum(abs2, xb), xb)
  Ey = PS._image_error_bound(bc, na, nb, extrapolated)
  (; y, zu, zw, bc, Ey)
end
ratio_exact(α, X, x, y, L) = (d = big_(x) - big_(y); BF(α) * sum(abs2, big_(X) * d) / (BF(L) * sum(abs2, d)))
tally = Dict{String, Tally}()
get_t(name) = get!(tally, name) do; Tally(name); end
for T in (Float32, Float64)
  E = T == Float32 ? 40 : 300
  tol = (1 + 4eps(T))^2
  for trial in 1:1200
    n, p = rand(rng, (1, 2, 5, 20, 60, 120)), rand(rng, (1, 2, 5, 20, 60))
    subn = rand(rng) < 0.12
    X, xa, xb, x = setup(T, n, p, E, subn)
    ω = rand(rng, (zero(T), T(0.25), T(0.9), prevfloat(one(T)), one(T)))
    α = rand(rng, (1, T(2.0)^rand(rng, -E÷2:E÷2), 2.0^rand(rng, -E÷2:E÷2)))
    T == Float32 && α isa Float64 && (!isfinite(Float32(α)) || iszero(Float32(α))) && continue
    all(isfinite, X) && all(isfinite, x) && all(isfinite, xa) && all(isfinite, xb) || continue
    q = solver_quantities(T, X, xa, xb, x, ω)
    all(isfinite, q.y) && all(isfinite, q.zu) && all(isfinite, q.zw) || continue
    y = q.y; d = x .- y
    any(!=(0), d) || continue
    Xb = big_(X)
    # E4: image error of zu against X y (stored y), fresh and extrapolated
    Eyb = se2big(q.Ey)
    err_u = bnormdiff(q.zu, Xb * big_(y))
    rec!(get_t("$T E4 ‖zu - X y‖ <= Ey (ω>0: $(ω>0))"), err_u <= Eyb, iszero(Eyb) ? NaN : Float64(err_u / Eyb))
    # E4b: the cheap-path chain: ‖(zw - zu) - X d‖ <= E = product·‖x‖ + under_product + Ey
    sd, sx = PS._sumsq2(d, x)
    D, normx = PS._se_norm_onepass(T, sd, d), PS._se_norm_onepass(T, sx, x)
    (D === nothing || normx === nothing || iszero(D.s)) && continue
    Ech = PS._se_add(PS._se_add(PS._se_mul(q.bc.product, q.bc.upper_x, normx), q.bc.under_product), q.Ey)
    lhs = bnormdiff(BF.(q.zw) .- BF.(q.zu), Xb * (big_(x) - big_(y)))
    rec!(get_t("$T E4b ‖(zw-zu) - X d‖ <= E"), lhs <= se2big(Ech), iszero(se2big(Ech)) ? NaN : Float64(lhs / se2big(Ech)))
    # E4c: ‖d‖ and iterate-norm bounds used by the constants
    rec!(get_t("$T E4c lower_step·D <= ‖d‖ <= upper_step·D"), se2big(PS._se_mul(q.bc.lower_step, D)) <= bnorm(BF.(x) - BF.(y)) <= se2big(PS._se_mul(q.bc.upper_step, D)))
    rec!(get_t("$T E4d ‖x‖ <= upper_x·normx"), bnorm(x) <= se2big(PS._se_mul(q.bc.upper_x, normx)))
    # E5: decisions on a grid of L around the exact threshold
    ρ1 = ratio_exact(α, X, x, y, one(T))      # curvature
    m = PS._image_model(isone(α) ? LeastSquaresLoss(zeros(T, n), X) : α * LeastSquaresLoss(zeros(T, n), X))
    rα = PS._root_scale(T, α)
    for factor in (0.25, 0.9, 0.99, 0.9999, 1 - 64eps(T), 1 - 8eps(T), 1 - 4eps(T), 1.0, 1 + 4eps(T), 1 + 8eps(T), 1 + 64eps(T), 1.001, 1.01, 1.1, 2.0, 16.0)
      L = T(ρ1 * factor)
      (isfinite(L) && L >= floatmin(T)) || continue
      for fo in (false, true)
        ok, fresh = PS._bound_certified!(zeros(T, n), m, q.zu, q.zw, d, D, L, q.Ey, normx, rα, q.bc, fo)
        ρ = ratio_exact(α, X, x, y, L)        # exact ratio α‖Xd‖²/(L‖d‖²)
        # safety: accepted => ρ <= tol
        rec!(get_t("$T E5 accept ⇒ α‖Xd‖² <= (1+4eps)² L‖d‖²  (fresh_only=$fo)"), !ok || ρ <= tol, ok ? Float64(ρ / tol) : NaN)
        ok && rec!(get_t("$T E5 MAX of (ρ/tol-1)/eps among accepted (= -min margin in eps), fo=$fo"), true, Float64((ρ / tol - 1) / eps(T)))
      end
    end
  end
end
for k in sort(collect(keys(tally))); report(tally[k]); end
