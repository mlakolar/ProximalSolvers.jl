include(joinpath(@__DIR__, "common.jl"))
println("E1 _frobenius_upper on julia ", VERSION)
rng = Xoshiro(1)
function cases(T)
  out = Any[]
  fmin, fmax = floatmin(T), floatmax(T)
  emax, emin = exponent(fmax), exponent(fmin)
  sub = T == Float32 ? -149 : -1074
  # ordinary, various scales and sizes
  for n in (1, 2, 7, 50), p in (1, 3, 40), k in (-30, 0, 30), _ in 1:4
    push!(out, ("ordinary", T.(randn(rng, n, p) .* 2.0^k)))
  end
  # scales across the whole range (squares overflow/underflow in T; Float64 accumulation for Float32)
  for k in range(sub + 5, emax - 8, length = 40), (n, p) in ((5, 4), (30, 20))
    X = randn(rng, n, p) .* 2.0^k
    all(isfinite, T.(X)) && push!(out, ("wide k=$(round(Int,k))", T.(X)))
  end
  # large-but-representable: Σx² overflows Float64 (needs Float64 data)
  for c in (0.5, 0.99, 1.0, 1.5, 3.0), (n, p) in ((4, 4), (20, 30), (200, 10))
    v = sqrt(Float64(fmax) / (n * p)) * c
    all(isfinite, T(v)) && push!(out, ("near-overflow c=$c", fill(T(v), n, p) .* T.(rand(rng, n, p) .+ 0.5) ./ 1.5))
  end
  # a single huge entry among tiny ones; huge entries only
  X = fill(T(2.0)^-60, 10, 10); X[3, 4] = fmax; push!(out, ("one floatmax", X))
  X = fill(fmax, 6, 6); push!(out, ("all floatmax", X))
  X = fill(nextfloat(zero(T)), 5, 5); push!(out, ("all denorm_min", X))
  X = fill(nextfloat(zero(T)), 5, 5); X[2, 2] = one(T); push!(out, ("denorm + 1", X))
  X = T.(randn(rng, 8, 8) .* 2.0^sub); push!(out, ("subnormal randn", X))
  push!(out, ("zero", zeros(T, 3, 3)))
  push!(out, ("single entry", fill(T(3), 1, 1)))
  # around the one-pass threshold s ≈ 4N floatmin (Float64 data; for Float32 data the sum is in Float64)
  for c in (0.7, 0.9, 0.999, 1.0, 1.001, 1.1, 2.0), (n, p) in ((10, 10), (50, 20), (300, 30))
    N = n * p
    for base in (4N * fmin, 4N * Float64(fmin))
      v = T(sqrt(base / N * c))
      v > 0 && push!(out, ("threshold c=$c", fill(v, n, p) .* T.(0.5 .+ rand(rng, n, p))./ T(1)))
    end
  end
  # squares underflowing individually but the sum ≥ 4N floatmin
  for (n, p) in ((100, 100), (1000, 100))
    N = n * p
    v = T(sqrt(8N * Float64(fmin) / N) * 0.4)
    push!(out, ("under-squares", fill(v, n, p)))
  end
  out
end
for T in (Float32, Float64)
  t = Tally("$T upper ≥ ‖X‖_F"); tt = Tally("$T upper/‖X‖_F - 1 (tightness)")
  nvac = 0
  for (name, X) in cases(T)
    all(isfinite, X) || continue
    U = PS._frobenius_upper(T, X)
    ub = se2big(U); fro = bnorm(X)
    iszero(fro) && (rec!(t, iszero(ub)); continue)
    rec!(t, ub >= fro)
    r = Float64(ub / fro - 1)
    rec!(tt, true, r)
    t.viol > 0 && rec!(Tally(""), true) 
    if ub < fro; println("   VIOLATION ", name, " size=", size(X), " rel=", Float64(ub/fro - 1)); end
    r > 1e-3 && (nvac += 1)
  end
  report(t); report(tt)
  N = 40000
  @printf("  %s: bound slack target gamma_{N+3}(F64)+8u_T+eps: for N=%d  %.3g;  cases with slack>1e-3: %d\n", T, N, gam(Float64, N + 3) + 8unit(T) + eps(Float64), nvac)
end
