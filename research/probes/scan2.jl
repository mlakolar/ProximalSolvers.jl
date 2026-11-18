# #317 scan 2 (Float64): exits by option set; trigger is the step scale, not α itself (data-scale arm).
include(joinpath(@__DIR__, "variants.jl"))
using ProximalBase, Random, Printf
function design(name)
  rng = Xoshiro(296)
  if name == "base"
    X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
  elseif name == "wide"
    X = randn(rng, 40, 100); β = zeros(100); β[1:5] .= [3.0, -2, 1.5, -1, 0.5]; y = X*β + 0.5*randn(rng, 40)
  else
    Z = randn(rng, 60, 20); X = Z * cholesky(Symmetric([0.8^abs(i-j) for i in 1:20, j in 1:20])).U
    β = zeros(20); β[[1,5,9]] .= [1.0, -1, 2]; y = X*β + randn(rng, 60)
  end
  X, y
end
ref(X, y, λ) = (x = zeros(size(X, 2)); solve!(x, LeastSquaresLoss(y, X), NormL1(λ), CDSolver(tol = 1e-14, rng = Xoshiro(1))); x)
opts = Dict("default" => () -> ProximalOptions(maxiter = 20_000),
            "afi_ftol0" => () -> ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true))
println("# variant=$VARIANT julia=$VERSION")
println("arm\topts\tdata\tlfrac\tstart\tscale\toutcome\titers\tconverged\tf_increased\tstagnated\trelerr\thits")
for arm in ("alpha", "data"), on in ("default", "afi_ftol0"), d in ("base", "wide", "corr"), lf in (0.0, 0.1, 0.5), start in ("cold", "warm")
  (d == "wide" && lf == 0) && continue
  X0, y0 = design(d); λ1 = lf * norm(X0'y0, Inf); xr = ref(X0, y0, λ1)
  for s in (1e200, 1e100, 1.0, 1e-100, 1e-150, 1e-158, 1e-200, 1e-300)
    arm == "data" && s > 1 && continue
    # alpha arm: loss scale s.  data arm: X, y scaled by sqrt(s), α = 1 (same minimizer, λ scaled by s)
    X, y, α = arm == "alpha" ? (X0, y0, s) : (X0 .* sqrt(s), y0 .* sqrt(s), 1.0)
    x = start == "cold" ? zeros(size(X, 2)) : xr .* (1 .+ 1e-3 .* sin.(1:length(xr)))
    SUBNORMAL_HITS[] = 0; out, it, cv, fi, st = "ok", -1, false, false, false
    try
      r = solve!(x, α * LeastSquaresLoss(y, X), NormL1(s * λ1), ProximalGradientDescent(), opts[on]())
      it, cv, fi, st = r.iterations, r.converged, r.f_increased, r.stagnated
    catch e; out = "ERR:" * first(sprint(showerror, e), 50); end
    @printf("%s\t%s\t%s\t%.1f\t%s\t%.0e\t%s\t%d\t%s\t%s\t%s\t%.2e\t%d\n", arm, on, d, lf, start, s, out, it, cv, fi, st, norm(x - xr)/max(norm(xr), 1e-300), SUBNORMAL_HITS[])
  end
end
