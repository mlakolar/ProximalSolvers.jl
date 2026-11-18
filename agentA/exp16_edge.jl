include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
# E16: edge of the clean range: rho^2 = n*floatmin/eps * U (U log-uniform in [1, 64]) with r nearly parallel to the column
# (d/||r|| log-uniform in [1e-12, 0.3]); lambda fractions near and away from sqrt(a). Option A (current), B1 and C2 overlays.
function edge(T, N, rng)
  worst = 0.0; viol = 0; ntr = 0; off = 0; thrown = 0
  for t in 1:N
    n = rand(rng, 2:12)
    xk = T.(randn(rng, n))                       # a ~ 1 (clean)
    u = randn(rng, n); u .-= (sum(u .* Float64.(xk))/sum(abs2, Float64.(xk))) .* Float64.(xk)    # orthogonal part
    θ = Float64(floatmin(T)/eps(T))
    target = n*θ*exp(rand(rng)*log(64))
    ρdir = randn(rng) .* Float64.(xk); ρdir ./= norm(ρdir)
    frac = 10.0^(-12*rand(rng))*0.3
    ρ = ρdir .+ frac .* (u ./ norm(u))
    ρ .*= sqrt(target)/norm(ρ)
    ρT = T.(ρ)
    λ = T(rand(rng, (0.01, 0.5, 0.999)) * sqrt(sum(abs2, Float64.(xk))))
    X = reshape(copy(xk), n, 1)
    m, g, x = make_model(X, ρT, λ)
    r0 = copy(m.ls.r)
    v = Base.invokelatest(visit!, m, g, x, 1)
    ntr += 1
    startswith(string(v.branch), "off") && (off += 1)
    if v.err !== nothing; thrown += 1; continue; end
    isfinite(v.ratio) || continue
    worst = max(worst, v.ratio); viol += v.ratio > 1
  end
  (worst, viol, ntr, off, thrown)
end
tag = ARGS[1]
tag == "B1" && install_B1!(); tag == "C2" && install_C2!()
for T in (Float32, Float64)
  w, viol, ntr, off, thrown = edge(T, 20000, Xoshiro(8))
  @printf("%s overlay %-2s: %d trials near the clean edge (%d classified exceptional by the current rules), worst excess/bound %.3g, violations %d, refusals %d\n", T, tag, ntr, off, w, viol, thrown)
end
