# cd-sqrt family of Stage 0's fingerprint matrix (fp_matrix.jl), master vs candidate in one process.
const HERE = @__DIR__
include(joinpath(HERE, "trees.jl"))
include(joinpath(HERE, "fp_lib.jl"))
mods = Any[("base", TREES.base), ("cand", TREES.cand)]
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
open(joinpath(HERE, "fp_sqrt_mismatches_$(VERSION.major).$(VERSION.minor).txt"), "w") do io
  for (k, t) in sort(collect(tally); by = first), m in t.mismatches
    println(io, k, "\t", first(m, 500))
  end
end
