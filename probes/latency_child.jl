# #307 first-call latency child: one fresh process measures one (solver, T, order).
# julia --startup-file=no --project=ENV latency_child.jl ARM SOLVER T ORDER REP
# SOLVER ∈ cd|pg|apg, T ∈ Float32|Float64, ORDER ∈ raw-scaled|scaled-raw.
# Prints one line starting with "CSV,first," (see HEADER in latency_driver.jl).
Base.cumulative_compile_timing(true)
ctime() = Int(Base.cumulative_compile_time_ns()[1])
const arm, sname, tname, order, rep = ARGS[1], ARGS[2], ARGS[3], ARGS[4], ARGS[5]
c0 = ctime(); t0 = time_ns()
using ProximalSolvers, ProximalBase
t_load = time_ns() - t0; c_load = ctime() - c0
using LinearAlgebra, Random
LinearAlgebra.BLAS.set_num_threads(1)
const T = tname == "Float64" ? Float64 : tname == "Float32" ? Float32 : error("T")
method() = sname == "cd" ? ProximalSolvers.CDSolver() :
           sname == "pg" ? ProximalSolvers.ProximalGradientDescent() :
           sname == "apg" ? ProximalSolvers.AccProxGradDescent() : error("solver")
c0 = ctime(); t0 = time_ns()
rng = Xoshiro(5)
X = randn(rng, T, 57, 13)
y = randn(rng, T, 57)
raw = ProximalBase.LeastSquaresLoss(y, X)
scaled = (one(T) / T(57)) * ProximalBase.LeastSquaresLoss(y, X)
λmax_raw = maximum(abs, X' * y)                 # ‖Xᵀy‖∞, for λ = λmax/10 on each loss
losses = Dict("raw" => (raw, ProximalBase.NormL1(T(λmax_raw / 10))),
              "scaled" => (scaled, ProximalBase.NormL1(T(λmax_raw / 570))))
t_fix = time_ns() - t0; c_fix = ctime() - c0
seq = order == "raw-scaled" ? ("raw", "scaled") : order == "scaled-raw" ? ("scaled", "raw") : error("order")
fields = Any[arm, string(VERSION), sname, tname, order, rep, t_load, c_load, t_fix, c_fix]
for kind in seq
  f, g = losses[kind]
  x = zeros(T, 13)
  c0 = ctime(); t0 = time_ns()
  r1 = solve!(x, f, g, method())
  t1 = time_ns() - t0; k1 = ctime() - c0
  x2 = zeros(T, 13)
  c0 = ctime(); t0 = time_ns()
  r2 = solve!(x2, f, g, method())
  t2 = time_ns() - t0; k2 = ctime() - c0
  append!(fields, (kind, t1, k1, t2, k2, r1.minimum, x == x2))
end
pso = Base.pkgorigins[Base.PkgId(ProximalSolvers)]
pbo = Base.pkgorigins[Base.PkgId(ProximalBase)]
append!(fields, (something(pso.cachepath, "none"), something(pbo.cachepath, "none")))
println("CSV,first,", join(fields, ","))
