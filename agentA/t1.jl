include("lib.jl")
for T in (Float64, Float32)
  rng = Xoshiro(1)
  n, p = 50, 10
  X = randn(rng, T, n, p); y = randn(rng, T, n)
  λ = T(0.3*lam_max(X, y))
  recs, m, x, err = run_passes(X, y, λ, 20)
  cnt, worst, worstz = summarize(recs)
  println(T, " ", fmtcnt(cnt), " worst ratio ", worst, " err=", err)
end
