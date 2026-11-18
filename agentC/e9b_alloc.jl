include(joinpath(@__DIR__, "common.jl"))
using ProximalBase: LeastSquaresLoss
println("E9b allocations of the certified step, no captured variables, julia ", VERSION)
rng = Xoshiro(9)
function cert(buf, m, zu, zw, d, x, L, Ey, rα, bc, fo, ::Type{T}) where {T}
  sd, sx = PS._sumsq2(d, x); D = PS._se_norm_onepass(T, sd, d); nx = PS._se_norm_onepass(T, sx, x)
  PS._bound_certified!(buf, m, zu, zw, d, D, L, Ey, nx, rα, bc, fo)
end
for T in (Float32, Float64)
  n, p = 500, 100
  X = randn(rng, T, n, p); xa = randn(rng, T, p); xb = randn(rng, T, p); x = xa .+ T(1e-3) .* randn(rng, T, p); ω = T(0.5)
  y = similar(xa); PS.Blocks._extrapolate_point!(y, xa, xb, ω)
  za, zb = X * xa, X * xb; zu = @. za + ω * (za - zb); zw = X * x; d = x .- y
  bc = PS._bound_constants(T, X); m = PS._image_model(LeastSquaresLoss(zeros(T, n), X)); rα = PS._root_scale(T, 1.0); buf = zeros(T, n)
  Ey = PS._image_error_bound(bc, PS._se_norm(T, xa), PS._se_norm(T, xb), true)
  for (name, L, fo) in (("cheap accept", T(1e6), false), ("cheap reject", T(1e-6), false), ("fresh product", T(1e6), true))
    cert(buf, m, zu, zw, d, x, L, Ey, rα, bc, fo, T)
    a = @allocated cert(buf, m, zu, zw, d, x, L, Ey, rα, bc, fo, T)
    @printf("  %-8s %-14s result=%s  allocated=%d B\n", T, name, cert(buf, m, zu, zw, d, x, L, Ey, rα, bc, fo, T), a)
  end
  # the image error bound and constants
  PS._image_error_bound(bc, PS._se_norm(T, xa), PS._se_norm(T, xb), true)
  a = @allocated PS._image_error_bound(bc, PS._se_norm(T, xa), PS._se_norm(T, xb), true)
  a2 = @allocated PS._bound_constants(T, X)
  @printf("  %-8s _image_error_bound+2 se_norm: %d B ; _bound_constants (setup): %d B\n", T, a, a2)
end
