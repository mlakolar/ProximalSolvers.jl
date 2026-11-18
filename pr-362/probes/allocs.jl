# Warmed allocation of solve! and of the changed helpers, BASE vs X2 (vs X3), one process, measured inside functions.
#   julia +lts|+release --project=<WORK>/ps-353 allocs.jl [x2|x3|both]
const HERE = @__DIR__
include(joinpath(HERE, get(ENV, "LOADER", "loader.jl")))
include(joinpath(HERE, "fp_lib.jl"))
which = isempty(ARGS) ? "both" : ARGS[1]
mods = Any[("base", BaseMod.ProximalSolvers)]
which in ("x2", "both") && push!(mods, ("x2", X2Mod.ProximalSolvers))
which == "sc" && push!(mods, ("sc", SCMod.ProximalSolvers))
which in ("x3", "both") && isdefined(Main, :X3Mod) && push!(mods, ("x3", X3Mod.ProximalSolvers))
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)

# the allocation of one solve!, after warm-up; minimum over 5 repetitions on fresh iterates
function solve_alloc(solvefn, mk)
  a = mk(); solvefn(a...)                # warm (compiles)
  a = mk(); solvefn(a...)
  best = typemax(Int)
  for _ in 1:5
    a = mk()
    best = min(best, @allocated solvefn(a...))
  end
  best
end

rng = Xoshiro(272)
function problems(PS)
  out = Pair{String, Function}[]
  for T in (Float32, Float64)
    n, p = 80, 40
    X, y, β = lsdata(Xoshiro(1), T, n, p; corr = true)
    λ = T(0.1 * maximum(abs, X' * y))
    α = T === Float32 ? 1.0 / n : 1.0 / n         # Float64 scale (Float32 data keeps S = Float64)
    f = LeastSquaresLoss(y, X); fα = α * LeastSquaresLoss(y, X)
    push!(out, "cd lasso dense $T" => () -> (zeros(T, p), f, NormL1(λ), PS.CDSolver(rng = Xoshiro(1))))
    push!(out, "cd lasso scaled(Float64 α) sparse $T" => () -> (SparseIterate(T, p), fα, NormL1(T(λ * α)), PS.CDSolver(rng = Xoshiro(1), order = :cyclic, momentum = false)))
    push!(out, "cd enet dense $T" => () -> (zeros(T, p), f, ElasticNet(λ, λ / 2), PS.CDSolver(rng = Xoshiro(1))))
    g = GroupNormL2(T(0.3 * λ), [collect(4k-3:4k) for k in 1:10])
    push!(out, "cd group $T" => () -> (BlockIterate(T, p, g), f, g, PS.CDSolver(rng = Xoshiro(1))))
    gs = GroupNormL2(T(0.3 * λ), [[j] for j in 1:p])
    push!(out, "cd group singletons $T" => () -> (BlockIterate(T, p, gs), f, gs, PS.CDSolver(rng = Xoshiro(1))))
    lmax = maximum(abs, X' * y) / norm(y)
    push!(out, "cd sqrt $T" => () -> (SparseIterate(T, p), SqrtLeastSquaresLoss(y, X), NormL1(T(0.2 * lmax)), PS.CDSolver(rng = Xoshiro(1))))
    push!(out, "pgd lasso $T" => () -> (zeros(T, p), f, NormL1(λ), PS.ProximalGradientDescent()))
    push!(out, "pgd lasso scaled $T" => () -> (zeros(T, p), fα, NormL1(T(λ * α)), PS.ProximalGradientDescent()))
    push!(out, "apg lasso $T" => () -> (zeros(T, p), f, NormL1(λ), PS.AccProxGradDescent()))
    push!(out, "apg lasso scaled $T" => () -> (zeros(T, p), fα, NormL1(T(λ * α)), PS.AccProxGradDescent()))
    push!(out, "apg enet $T" => () -> (zeros(T, p), f, ElasticNet(λ, λ / 2), PS.AccProxGradDescent()))
    # data at tiny scale: the exceptional response scale and the scaled fallbacks of APG
    Xt, yt = X .* T(T === Float32 ? 2.0^-60 : 2.0^-500), y .* T(T === Float32 ? 2.0^-60 : 2.0^-500)
    ft = LeastSquaresLoss(yt, Xt); λt = T(0.1 * maximum(abs, Xt' * yt))
    push!(out, "cd lasso tiny-scale $T" => () -> (zeros(T, p), ft, NormL1(λt), PS.CDSolver(rng = Xoshiro(1))))
    push!(out, "apg lasso tiny-scale $T" => () -> (zeros(T, p), ft, NormL1(λt), PS.AccProxGradDescent()))
  end
  out
end
tab = Dict{String, Vector{Int}}()
names = String[]
for (mname, PS) in mods
  for (nm, mk) in problems(PS)
    mname == "base" && push!(names, nm)
    solvefn = PS.solve!
    v = solve_alloc(solvefn, mk)
    push!(get!(tab, nm, Int[]), v)
  end
end
println(rpad("case", 40), join(rpad.(first.(mods), 12)))
nbad = 0
for nm in names
  v = tab[nm]; ok = all(==(v[1]), v)
  global nbad += ok ? 0 : 1
  println(rpad(nm, 40), join(rpad.(string.(v), 12)), ok ? "" : "  <-- DIFFERS")
end
println("cases with differing allocation: ", nbad, " of ", length(names))

# helpers changed by the items: allocation of one warmed call
println("\nallocation of single warmed calls (bytes):")
function hcall(f, args...)
  f(args...); f(args...)
  @allocated f(args...)
end
for (mname, PS) in mods
  res = String[]
  for T in (Float32, Float64)
    X, y, β = lsdata(Xoshiro(2), T, 50, 20)
    x = randn(Xoshiro(3), T, 20); xp = randn(Xoshiro(4), T, 20)
    m = PS.LSModel(y, X, 1.0); Xz = copy(X); Xz[:, 3] .= 0; mz = PS.LSModel(y, Xz, 1.0)
    ms = PS.LSModel(y, X, 0.37)
    push!(res, "$T _norm_diff(Inf)=" * string(hcall(PS.Blocks._norm_diff, x, xp, Inf)) *
               " _frobenius_upper=" * string(hcall(PS._frobenius_upper, T, X)) *
               " _root_scale=" * string(hcall(PS._root_scale, T, 0.37)) *
               " response_scale=" * string(hcall(PS.response_scale, m, nothing)) *
               " response_scale(S=Float64)=" * string(hcall(PS.response_scale, ms, nothing)) *
               " _flat_column(nonflat/flat)=" * string(hcall(PS._flat_column, m, 3)) * "/" * string(hcall(PS._flat_column, mz, 3)) *
               " _flat_group=" * string(hcall(PS._flat_group, mz, [1, 3])))
  end
  println("  ", mname, ": ", join(res, " | "))
end
