include("lib.jl")
for T in (Float64, Float32)
  rng = Xoshiro(1)
  n, p = 50, 10
  X = randn(rng, T, n, p); y = randn(rng, T, n)
  y .*= T(2)^(T===Float32 ? -60 : -600)   # tiny y -> offrange
  λ = T(0.3*lam_max(X, y)) 
  λ = T(0.3*lam_max(X, y ./ y[1]*one(T)))
  REAL_OFF[] = 0; REAL_BAND[] = 0
  recs, m, x, err = Base.invokelatest(run_passes, X, y, λ, 5)
  cnt, worst, worstz = summarize(recs)
  println(T, " ", fmtcnt(cnt), " worst ratio ", worst, " err=", err, " realOFF=", REAL_OFF[], " realBAND=", REAL_BAND[])
end
