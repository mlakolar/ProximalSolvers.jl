# allocation of warmed solves that contain flat (zero) columns / flat groups: BASE vs X2 vs X3 (C5)
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
include(joinpath(HERE, "fp_lib.jl"))
println("Julia ", VERSION)
mods = Any[("base", BaseMod.ProximalSolvers), ("x2", X2Mod.ProximalSolvers), ("x3", X3Mod.ProximalSolvers)]
function al(f, a...); f(a...); f(a...); best = typemax(Int); for _ in 1:5; best = min(best, @allocated f(a...)); end; best; end
function run_lasso(PS, T, solver)
  X, y, _ = lsdata(Xoshiro(1), T, 60, 20); X[:, [3, 4, 9]] .= 0; X[:, 5] .= -zero(T)
  f = LeastSquaresLoss(y, X); λ = T(0.1 * maximum(abs, X' * y))
  mk() = (SparseIterate(T, 20), f, NormL1(λ), solver())
  best = typemax(Int)
  a = mk(); PS.solve!(a...); a = mk(); PS.solve!(a...)
  for _ in 1:5; a = mk(); best = min(best, @allocated PS.solve!(a...)); end
  best
end
function run_group(PS, T)
  X, y, _ = lsdata(Xoshiro(1), T, 60, 20); X[:, 3:6] .= 0
  f = LeastSquaresLoss(y, X); λ = T(0.1 * maximum(abs, X' * y)); g = GroupNormL2(λ, [collect(4k-3:4k) for k in 1:5])
  best = typemax(Int)
  for _ in 1:7; x = BlockIterate(T, 20, g); a = (x, f, g, PS.CDSolver(rng = Xoshiro(1))); PS.solve!(a...); end
  for _ in 1:5; x = BlockIterate(T, 20, g); a = (x, f, g, PS.CDSolver(rng = Xoshiro(1))); best = min(best, @allocated PS.solve!(a...)); end
  best
end
for T in (Float32, Float64)
  println(T, " lasso with zero / -0.0 columns: ", join(["$n=$(run_lasso(PS, T, () -> PS.CDSolver(rng = Xoshiro(1))))" for (n, PS) in mods], "  "),
          "   group with a flat group: ", join(["$n=$(run_group(PS, T))" for (n, PS) in mods], "  "))
end
