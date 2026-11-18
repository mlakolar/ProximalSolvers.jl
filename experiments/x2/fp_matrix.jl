# Fingerprint matrix: BASE vs X2 (and X3 when its tree exists) in one process.
#   julia +lts|+release --project=<WORK>/ps-353 fp_matrix.jl [x2|x3|both]
const HERE = @__DIR__
include(joinpath(HERE, get(ENV, "LOADER", "loadtrees.jl")))
include(joinpath(HERE, "fp_lib.jl"))
which = isempty(ARGS) ? "both" : ARGS[1]
mods = Any[("base", BaseMod.ProximalSolvers)]
which in ("x2", "both") && push!(mods, ("x2", X2Mod.ProximalSolvers))
which == "sc" && push!(mods, ("sc", SCMod.ProximalSolvers))
which in ("x3", "both") && isdefined(Main, :X3Mod) && push!(mods, ("x3", X3Mod.ProximalSolvers))
println("Julia ", VERSION, "  CPU ", Sys.CPU_NAME, "  trees: ", join(first.(mods), ", "))

tally = Dict{String, Tally}()
T_(name) = get!(tally, name, Tally())
rng = Xoshiro(20261118)

cdsolver(PS, T; order, momentum, seed, tol = T === Float64 ? 1e-10 : 1e-5, maxpasses = 5000, relative = true) =
  PS.CDSolver(; order, momentum, tol, maxpasses, rng = Xoshiro(seed), relative)
const CONFIGS = ((:cyclic, nothing), (:cyclic, false), (:random, nothing), (:random, false), (:random, true))
scalesfor(::Type{T}, n) where T = T === Float32 ? (nothing, 1f0 / n, 2, 0.37, 1.0 / n) : (nothing, 1.0 / n, 3, 0.37f0)
lossof(α, y, X) = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
amax(α, X, y) = (α === nothing ? 1.0 : Float64(α)) * maximum(abs, Float64.(X)' * Float64.(y))

# -------------------- CD lasso / elastic net -----------------------------------------------
for T in (Float32, Float64), (n, p) in ((20, 8), (50, 30), (60, 150), (200, 40)),
    sc in (1.0, T === Float32 ? 2.0^-70 : 2.0^-540, T === Float32 ? 2.0^60 : 2.0^520)
  X, y, β = lsdata(rng, T, n, p; scale = sc, corr = n == 50)
  start = zeros(T, p); for k in 1:3:p; start[k] = T(0.1 * k); end
  for α in scalesfor(T, n), (pen, mk) in (("lasso", λ -> NormL1(λ)), ("enet", λ -> ElasticNet(λ, λ / 3)))
    lm = amax(α, X, y)
    for frac in (0.05, 0.4), kind in (:dense, :empty, :warm, :densewarm), (order, momentum) in CONFIGS
      (sc != 1.0 && (frac != 0.4 || kind != :dense || momentum === false || (n, p) != (50, 30))) && continue
      λ = T(frac * lm); isfinite(λ) && λ > 0 || continue
      label = "cd-$pen $T n=$n p=$p scale=$sc α=$(repr(α)) frac=$frac $kind $order mom=$momentum"
      compare!(T_("cd-lasso/enet"), label, mods, PS -> begin
        x = kind === :dense ? zeros(T, p) : kind === :empty ? SparseIterate(T, p) : kind === :warm ? SparseIterate(copy(start)) : copy(start)
        r = PS.solve!(x, lossof(α, y, X), mk(λ), cdsolver(PS, T; order, momentum, seed = 7))
        (r, x)
      end)
    end
  end
end

# -------------------- CD group lasso -----------------------------------------------------------
for T in (Float32, Float64), (n, p, gs) in ((40, 12, 3), (60, 30, 1), (60, 30, 5), (30, 40, 4)),
    singles in (false, true)
  X, y, β = lsdata(rng, T, n, p; corr = true)
  groups = singles ? [[j] for j in 1:p] : [collect((k - 1) * gs + 1:min(k * gs, p)) for k in 1:cld(p, gs)]
  if n == 40; X[:, 4:6] .= 0; end   # a flat group (C5)
  for α in (nothing, T === Float32 ? 1f0 / n : 1.0 / n, 2, 0.37), order in (:cyclic, :random), kind in (:cold, :warm)
    lm = amax(α, X, y)
    for frac in (0.1, 0.5)
      λ = T(frac * lm / 3)
      label = "group $T n=$n p=$p gs=$(singles ? 1 : gs) α=$(repr(α)) $order $kind frac=$frac"
      compare!(T_("cd-group"), label, mods, PS -> begin
        g = GroupNormL2(λ, groups)
        x = BlockIterate(T, p, g)
        if kind === :warm
          x = BlockIterate(T.(0.05 .* (1:p) .* (mod.(1:p, 3) .== 0)), groups)
        end
        r = PS.solve!(x, lossof(α, y, X), g, PS.CDSolver(; order, tol = T === Float64 ? 1e-10 : 1e-5, maxpasses = 5000, rng = Xoshiro(3)))
        (r, x)
      end)
    end
  end
end

# -------------------- CD sqrt lasso ----------------------------------------------------------
for T in (Float32, Float64), (n, p) in ((20, 8), (50, 30), (60, 150), (200, 40)),
    sc in (1.0, T === Float32 ? 2.0^-60 : 2.0^-500, T === Float32 ? 2.0^50 : 2.0^480)
  X, y, β = lsdata(rng, T, n, p; scale = sc, corr = n == 50)
  lmax = maximum(abs, Float64.(X)' * Float64.(y)) / norm(Float64.(y))
  for frac in (0.05, 0.3, 0.8), kind in (:dense, :owner, :warm), order in (:cyclic, :random)
    (sc != 1.0 && (frac != 0.3 || kind != :dense || (n, p) != (50, 30))) && continue
    λ = T(frac * lmax); isfinite(λ) && λ > 0 || continue
    label = "sqrt $T n=$n p=$p scale=$sc frac=$frac $kind $order"
    compare!(T_("cd-sqrt"), label, mods, PS -> begin
      x0 = kind === :warm ? T.(0.01 .* (mod.(1:p, 4) .== 0)) : zeros(T, p)
      x = kind === :dense ? copy(x0) : SparseIterate(copy(x0))
      r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(; order, rng = Xoshiro(5), tol = T === Float64 ? 1e-9 : 1e-4, maxpasses = 5000))
      (r, x)
    end)
  end
end
# sqrt lasso with a zero response and with an exact fit (certificate edge)
for T in (Float32, Float64)
  X = randn(rng, T, 30, 10); b = zeros(T, 10); b[2] = 1; b[5] = -2
  for (nm, y) in (("y=0", zeros(T, 30)), ("exact", X * b), ("tinyy", X * b .* T(2)^-40))
    compare!(T_("cd-sqrt"), "sqrt $T $nm", mods, PS -> begin
      x = SparseIterate(T, 10)
      r = PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(T(0.1)), PS.CDSolver(rng = Xoshiro(1), order = :cyclic))
      (r, x)
    end)
  end
end

# -------------------- PGD and APG ---------------------------------------------------------------
mkopts(PS, i) = i == 1 ? PS.ProximalOptions(maxiter = 4000) : PS.ProximalOptions(maxiter = 20000, ftol = 0.0, xtol = 1e-14, gradtol = 1e-7)
for T in (Float32, Float64), (n, p) in ((20, 8), (60, 30), (40, 120), (200, 50)),
    sc in (1.0, T === Float32 ? 2.0^-60 : 2.0^-450)
  X, y, β = lsdata(rng, T, n, p; scale = sc, corr = n == 60)
  start = zeros(T, p); for k in 1:3:p; start[k] = T(0.05 * k * sc); end
  for α in scalesfor(T, n), (pen, mk) in (("lasso", λ -> NormL1(λ)), ("enet", λ -> ElasticNet(λ, λ / 3))),
      (mn, meth) in (("pgd", PS -> PS.ProximalGradientDescent()), ("apg", PS -> PS.AccProxGradDescent()))
    (sc != 1.0 && (α !== nothing && !(α isa Integer) || (n, p) != (60, 30))) && continue
    lm = amax(α, X, y)
    for frac in (0.05, 0.4), kind in (:cold, :warm), oi in 1:2
      (sc != 1.0 && (frac != 0.4 || oi != 1)) && continue
      λ = T(frac * lm); isfinite(λ) && λ > 0 || continue
      label = "$mn-$pen $T n=$n p=$p scale=$sc α=$(repr(α)) frac=$frac $kind opts=$oi"
      compare!(T_("pgd/apg"), label, mods, PS -> begin
        x = kind === :cold ? zeros(T, p) : copy(start)
        r = PS.solve!(x, lossof(α, y, X), mk(λ), meth(PS), mkopts(PS, oi))
        (r, x)
      end)
    end
  end
end

# -------------------- report ------------------------------------------------------------------
total, bad = 0, 0
for (k, t) in sort(collect(tally); by = first)
  println(rpad(k, 16), " comparisons=", t.n, " mismatches=", length(t.mismatches), " (base converged: ", t.converged, ", base threw: ", t.errors, ")")
  global total += t.n; global bad += length(t.mismatches)
  for (e, c) in t.errmsgs; println("    base threw x", c, ": ", e); end
end
println("TOTAL comparisons=", total, " (cases x trees), mismatches=", bad)
for (k, t) in sort(collect(tally); by = first), m in t.mismatches[1:min(end, 12)]
  println("MISMATCH ", k, " ", first(m, 400))
end
open(joinpath(HERE, "fp_mismatches_$(which)_$(VERSION.major).$(VERSION.minor).txt"), "w") do io
  for (k, t) in sort(collect(tally); by = first), m in t.mismatches
    println(io, k, "\t", first(m, 500))
  end
end
