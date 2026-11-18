# #317: plain reproducer on the checked-out source (no variant overrides)
using ProximalSolvers, ProximalBase, LinearAlgebra, Random
println("julia ", VERSION, "  PS ", pkgversion(ProximalSolvers), "  BLAS ", BLAS.get_config())
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X * β + 0.3 * randn(rng, 30)
λmax1 = norm(X'y, Inf)
for (label, opts) in (("lserr opts", ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)),
                      ("default opts", ProximalOptions()),
                      ("maxiter 20000", ProximalOptions(maxiter = 20_000)))
  for α in (1e-150, 1e-180, 1e-190, 1e-200, 1e-250, 1e-300), frac in (0.0, 0.1)
    x = zeros(12); tr = Any[]
    cb = os -> (push!(tr, (os.iteration, os.L)); false)
    o = ProximalOptions(; (k => getfield(opts, k) for k in fieldnames(typeof(opts)) if k != :callback)..., callback = cb)
    try
      r = solve!(x, α * LeastSquaresLoss(y, X), NormL1(frac * α * λmax1), ProximalGradientDescent(), o)
      println(rpad(label,14), " α=$α λfrac=$frac ok: iters=", r.iterations, " conv=", r.converged, " L=", tr[end][2])
    catch e
      println(rpad(label,14), " α=$α λfrac=$frac ERROR: ", sprint(showerror, e), " after ", length(tr), " iters; last L=", isempty(tr) ? NaN : tr[end][2])
    end
  end
end
