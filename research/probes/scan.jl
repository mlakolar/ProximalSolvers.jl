# #317 scan: α (and data scale) x datasets x λ fraction x start, one variant per process.
# Reference: the lasso is invariant under (α, λ) -> (sα, sλ), so the α = 1 solution (CD, tight) is exact.
include(joinpath(@__DIR__, "variants.jl"))
using ProximalBase, Random, Printf
T = parse(Bool, get(ENV, "F32", "false")) ? Float32 : Float64
function design(name)
  rng = Xoshiro(296)
  if name == "base"
    X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
  elseif name == "wide"
    X = randn(rng, 40, 100); β = zeros(100); β[1:5] .= [3.0, -2, 1.5, -1, 0.5]; y = X*β + 0.5*randn(rng, 40)
  else # corr
    Z = randn(rng, 60, 20); X = Z * cholesky(Symmetric([0.8^abs(i-j) for i in 1:20, j in 1:20])).U
    β = zeros(20); β[[1,5,9]] .= [1.0, -1, 2]; y = X*β + randn(rng, 60)
  end
  T.(X), T.(y)
end
kkt(x, X, y, λ) = (g = X'*(X*x - y); maximum(i -> x[i] != 0 ? abs(g[i] + λ*sign(x[i])) : max(abs(g[i]) - λ, 0), eachindex(x)) / max(λ, norm(X'y, Inf)))
ref(X, y, λ) = (x = zeros(Float64, size(X, 2)); solve!(x, LeastSquaresLoss(Float64.(y), Float64.(X)), NormL1(λ), CDSolver(tol = 1e-14, rng = Xoshiro(1))); x)
αs = T == Float64 ? [1.0, 1e-100, 1e-140, 1e-150, 1e-155, 1e-158, 1e-160, 1e-162, 1e-165, 1e-170, 1e-180, 1e-200, 1e-250, 1e-300] :
                    T[1, 1f-10, 1f-15, 1f-17, 1f-18, 1f-19, 1f-20, 1f-22, 1f-25, 1f-30]
println("# variant=$VARIANT T=$T julia=$VERSION")
println("data\tlfrac\tstart\talpha\toutcome\titers\tconverged\trelerr\tkkt\tsubnormal_hits")
for d in ("base", "wide", "corr"), lf in (0.0, 0.1, 0.5), start in ("cold", "warm")
  X, y = design(d); (d == "wide" && lf == 0) && continue
  λ1 = lf * norm(Float64.(X)'Float64.(y), Inf); xr = ref(X, y, λ1)
  for α in αs
    x = start == "cold" ? zeros(T, size(X, 2)) : T.(xr .* (1 .+ 1e-3 .* sin.(1:length(xr))))
    SUBNORMAL_HITS[] = 0
    out, it, cv = "ok", -1, false
    try
      r = solve!(x, α * LeastSquaresLoss(y, X), NormL1(T(α*λ1)), ProximalGradientDescent(), ProximalOptions(maxiter = 20_000))
      it, cv = r.iterations, r.converged
    catch e
      out = "ERR:" * first(sprint(showerror, e), 60)
    end
    re = norm(Float64.(x) - xr) / max(norm(xr), 1e-300)
    @printf("%s\t%.1f\t%s\t%.0e\t%s\t%d\t%s\t%.2e\t%.2e\t%d\n", d, lf, start, α, out, it, cv, re, kkt(Float64.(x), Float64.(X), Float64.(y), λ1), SUBNORMAL_HITS[])
  end
end
