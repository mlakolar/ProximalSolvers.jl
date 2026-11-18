include("lib.jl")
# E1: ordinary Gaussian designs, Float32/Float64, several n,p,lambda fractions. All visits: branch + excess ratio.
function run_grid()
  println("# E1 ordinary Gaussian designs (cyclic CD from 0, up to 25 passes, every visit referenced to BigFloat 512)")
  println("type n p lamfrac | visits | branch counts | worst excess/bound (all) | worst coordinate rel err")
  for T in (Float32, Float64), (n, p) in ((20, 10), (100, 60), (400, 40), (30, 120)), lf in (0.5, 0.1, 0.02)
    rng = Xoshiro(hash((n, p, lf)))
    X = randn(rng, T, n, p); y = randn(rng, T, n)
    λ = T(lf*lam_max(X, y))
    REAL_OFF[] = 0; REAL_BAND[] = 0
    recs, m, x, err = Base.invokelatest(run_passes, X, y, λ, 25)
    cnt, worst, worstz = summarize(recs)
    w = isempty(worst) ? NaN : maximum(values(worst))
    wz = isempty(worstz) ? NaN : maximum(values(worstz))
    @printf("%s n=%d p=%d lf=%.2f | %d | %s | %.3e | %.3e | realOFF=%d realBAND=%d err=%s\n", T, n, p, lf, length(recs), fmtcnt(cnt), w, wz, REAL_OFF[], REAL_BAND[], err)
  end
end
run_grid()
