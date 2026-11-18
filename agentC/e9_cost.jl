# Indicative cost probe (not a controlled benchmark): the certified test per trial versus one matrix-vector product.
include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss
println("E9 cost/alloc of the certification, julia ", VERSION)
rng = Xoshiro(9)
for T in (Float32, Float64), (n, p) in ((200, 50), (2000, 500), (20000, 100))
  X = randn(rng, T, n, p); xa = randn(rng, T, p); xb = randn(rng, T, p); x = xa .+ T(1e-3) .* randn(rng, T, p)
  ω = T(0.5)
  y = similar(xa); PS.Blocks._extrapolate_point!(y, xa, xb, ω)
  za, zb = X * xa, X * xb; zu = @. za + ω * (za - zb); zw = X * x; d = x .- y
  bc = PS._bound_constants(T, X)
  m = PS._image_model(LeastSquaresLoss(zeros(T, n), X))
  rα = PS._root_scale(T, 1.0); buf = zeros(T, n)
  na, nb = PS._se_norm(T, xa), PS._se_norm(T, xb)
  Ey = PS._image_error_bound(bc, na, nb, true)
  sd, sx = PS._sumsq2(d, x); D = PS._se_norm_onepass(T, sd, d); nx = PS._se_norm_onepass(T, sx, x)
  Lbig = T(1e6)    # certified cheaply
  r = PS._bound_certified!(buf, m, zu, zw, d, D, Lbig, Ey, nx, rα, bc, false)
  function once()
    sd, sx = PS._sumsq2(d, x); D = PS._se_norm_onepass(T, sd, d); nx = PS._se_norm_onepass(T, sx, x)
    PS._bound_certified!(buf, m, zu, zw, d, D, Lbig, Ey, nx, rα, bc, false)
  end
  once(); a1 = @allocated once()
  reps = 2000
  tm(f) = minimum((@elapsed(for _ in 1:reps; f(); end)) / reps for _ in 1:5)
  t_cert = tm(once)
  zz = zeros(T, n)
  mul!(zz, X, x)
  t_mv = tm(() -> mul!(zz, X, x))
  t_fresh = tm(() -> PS._bound_certified!(buf, m, zu, zw, d, D, Lbig, Ey, nx, rα, bc, true))
  @printf("  %-8s n=%6d p=%4d  accept=%s  cert(cheap, incl. sumsq2)=%7.2f us   fresh_only=%8.2f us   one X*x=%8.2f us   alloc(cheap)=%d B\n", T, n, p, r, t_cert * 1e6, t_fresh * 1e6, t_mv * 1e6, a1)
end
