# X3 item 8 at solve level: group lasso BASE vs X3 (singleton groups take _singleton_curvature, whose sum changes order).
# Reports bit-identity, pass counts, converged, objective relative difference (BigFloat) and an independent BigFloat KKT residual.
#   julia +lts|+release --project=<WORK>/ps-353 x3_group.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
include(joinpath(HERE, "fp_lib.jl"))
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
mods = Any[("base", BaseMod.ProximalSolvers), (isempty(ARGS) ? "x3" : ARGS[1], isempty(ARGS) || ARGS[1] == "x3" ? X3Mod.ProximalSolvers : X2Mod.ProximalSolvers)]
rng = Xoshiro(275)
bigobj(X, y, s, λ0, w, groups, β) = setprecision(() -> begin
    r = BigFloat.(y) .- BigFloat.(X) * BigFloat.(β)
    BigFloat(s) / 2 * sum(abs2, r) + BigFloat(λ0) * sum(w[k] * sqrt(sum(abs2, BigFloat.(β[g]))) for (k, g) in enumerate(groups))
  end, BigFloat, 256)
# KKT residual (relative to max(1, λ0 w_k s...)): for a group with β_G ≠ 0, ‖∇_G + λ0 w_k β_G/‖β_G‖‖; at 0, max(0, ‖∇_G‖ − λ0 w_k); ∇ = s Xᵀ(Xβ − y)
function kkt(X, y, s, λ0, w, groups, β)
  setprecision(BigFloat, 256) do
    r = BigFloat.(X) * BigFloat.(β) .- BigFloat.(y); ∇ = BigFloat(s) .* (BigFloat.(X)' * r)
    worst = BigFloat(0)
    for (k, g) in enumerate(groups)
      nb = sqrt(sum(abs2, BigFloat.(β[g])))
      res = iszero(nb) ? max(sqrt(sum(abs2, ∇[g])) - BigFloat(λ0) * w[k], BigFloat(0)) : sqrt(sum(abs2, ∇[g] .+ BigFloat(λ0) * w[k] .* BigFloat.(β[g]) ./ nb))
      worst = max(worst, res)
    end
    Float64(worst / max(1, BigFloat(λ0)))
  end
end
rows = Any[]
for T in (Float32, Float64), (n, p, gs) in ((40, 12, 1), (60, 30, 1), (30, 40, 1), (200, 80, 1), (40, 12, 3), (60, 30, 5)),
    α in (nothing, T === Float32 ? 1f0 / 50 : 1.0 / 50, 2, 0.37), order in (:cyclic, :random), frac in (0.05, 0.3), tolscale in (1.0, 1e-2)
  X, y, β0 = lsdata(rng, T, n, p; corr = true)
  groups = [collect((k - 1) * gs + 1:min(k * gs, p)) for k in 1:cld(p, gs)]
  s = α === nothing ? 1.0 : Float64(α)
  w = ones(length(groups))
  λ0 = T(frac * s * maximum(abs, Float64.(X)' * Float64.(y)) / sqrt(gs))
  tol = (T === Float64 ? 1e-10 : 1e-5) * tolscale
  res = Dict{String, Any}()
  for (name, PS) in mods
    g = GroupNormL2(λ0, groups); x = BlockIterate(T, p, g)
    f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    local r
    r = with_logger(Test.TestLogger(min_level = Logging.Debug)) do
      PS.solve!(x, f, g, PS.CDSolver(; order, tol, maxpasses = 20000, rng = Xoshiro(3)))
    end
    res[name] = (r, Vector(x))
  end
  rb, xb = res["base"]; r3, x3 = res[mods[2][1]]
  identical = ddiff((rb, xb), (r3, x3)) === nothing
  ob, o3 = bigobj(X, y, s, λ0, w, groups, xb), bigobj(X, y, s, λ0, w, groups, x3)
  push!(rows, (; T, n, p, gs, frac, α, order, identical, passes = (rb.passes, r3.passes), conv = (rb.converged, r3.converged),
                reldiff = Float64(abs(ob - o3) / ob), kb = kkt(X, y, s, λ0, w, groups, xb), k3 = kkt(X, y, s, λ0, w, groups, x3), tol))
end
for sing in (true, false), T in (Float32, Float64)
  R = filter(r -> (r.gs == 1) == sing && r.T === T, rows)
  isempty(R) && continue
  println("$(sing ? "singleton groups" : "multi-column groups (control)") $T: cases=$(length(R)) bit-identical=$(count(r -> r.identical, R)) ",
          "passes equal=$(count(r -> r.passes[1] == r.passes[2], R)) (max |Δpasses| = $(maximum(abs(r.passes[1] - r.passes[2]) for r in R))) ",
          "converged: base $(count(r -> r.conv[1], R))/x3 $(count(r -> r.conv[2], R)) ",
          "max objective rel diff=$(round(maximum(r.reldiff for r in R), sigdigits = 3)) (eps(T)=$(eps(T))) ",
          "max KKT residual: base $(round(maximum(r.kb for r in R), sigdigits = 3)) x3 $(round(maximum(r.k3 for r in R), sigdigits = 3)) (tolerances 1e-4 F32 / 1e-8 F64 in the test suite)")
end
# the worst pass-count difference, and whether any case changed converged
worst = sort(filter(r -> r.gs == 1, rows); by = r -> -abs(r.passes[1] - r.passes[2]))[1:5]
for r in worst; println("  largest pass difference: $(r.T) n=$(r.n) p=$(r.p) frac=$(r.frac) tol=$(r.tol) α=$(repr(r.α)) $(r.order) base $(r.passes[1]) vs x3 $(r.passes[2]) converged $(r.conv), kkt base $(r.kb) x3 $(r.k3)"); end
for T in (Float32, Float64), (lbl, sel) in (("tol at the working-precision floor (tolscale 1e-2)", r -> r.tol < (T === Float64 ? 1e-10 : 1e-5)), ("ordinary tol", r -> r.tol >= (T === Float64 ? 1e-10 : 1e-5)))
  R = filter(r -> r.gs == 1 && r.T === T && sel(r), rows)
  isempty(R) && continue
  println("  $T, $lbl: cases=$(length(R)), passes differ in $(count(r -> r.passes[1] != r.passes[2], R)), max |Δpasses|=$(maximum(abs(r.passes[1]-r.passes[2]) for r in R)), converged differs in $(count(r -> r.conv[1] != r.conv[2], R))")
end
