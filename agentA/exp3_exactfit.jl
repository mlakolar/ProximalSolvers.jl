include("lib.jl")
# E3: near-exact-fit / noiseless p>n problems and nearly collinear columns. Cyclic CD from 0, up to 300 passes,
# tolerance 1e-7 relative change like the default; per visit branch counts and worst excess/bound.
function problem(T, n, p, σ, seed; collinear = false)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  if collinear
    for j in 2:p; X[:, j] .= X[:, 1] .+ 1e-4 .* randn(rng, n); end
  end
  β0 = zeros(p); β0[1:min(5, p)] .= [3.0, -2.0, 1.5, 1.0, -0.5][1:min(5, p)]
  y = X*β0 .+ σ .* randn(rng, n)
  T.(X), T.(y)
end
println("# E3 near-exact fits. cols: T n p sigma lf collinear | visits | branches | worst step ratio | public solve")
for T in (Float32, Float64), (n, p) in ((30, 100), (50, 20)), σ in (0.0, 1e-12, 1e-9, 1e-6, 1e-3), lf in (0.05, 0.3), col in (false, true)
  X, y = problem(T, n, p, σ, 7; collinear = col)
  λ = T(lf*lam_max(X, y))
  REAL_OFF[] = 0; REAL_BAND[] = 0
  recs, m, x, err = Base.invokelatest(run_passes, X, y, λ, 300; stoptol = T(1e-7)*sqrt(sum(abs2, y))/sqrt(n)/50)
  cnt, worst, _ = summarize(recs)
  w = isempty(worst) ? NaN : maximum(values(worst))
  res = try
    xs = zeros(T, p)
    r = Base.invokelatest(() -> Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
      solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(order = :cyclic))
    end)
    "conv=$(r.converged) gap=$(isnan(r.gap) ? "NaN" : @sprintf("%.1e", r.gap)) passes=$(r.passes)"
  catch e
    "THROW:" * first(split(sprint(showerror, e), '\n'))[1:min(end, 80)]
  end
  @printf("%s n=%d p=%d σ=%.0e lf=%.2f col=%s | %d | %s | %.2e | %s | err=%s\n", T, n, p, σ, lf, col, length(recs), fmtcnt(cnt), w, res, err === nothing ? "-" : "thrown")
end
