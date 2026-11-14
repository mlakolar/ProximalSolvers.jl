# Disposable #308 real-code matrix: the five Float32 PGD benchmark designs (and Float64 controls)
# with the package loaded by the active environment (base or candidate tree), real stopping.
#   julia --project=<env> matrix308.jl <label> <reps a:b> <settings: strict|harness> [T...]
label, reps, setting = ARGS[1], ARGS[2], ARGS[3]
Ts = length(ARGS) >= 4 ? [t == "Float64" ? Float64 : Float32 for t in ARGS[4:end]] : [Float32]
a_, b_ = parse.(Int, split(reps, ':'))
const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const H = Module(:Harness308m)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(ROOT, "benchmark", f))
end
import ProximalSolvers
using LinearAlgebra, Printf
BLAS.set_num_threads(1)
const PS = ProximalSolvers
println(stderr, "PS at ", pathof(PS), "; julia ", VERSION, "; ", Sys.CPU_NAME, "; stagnation rule: ", isdefined(PS, :_stagnated))
const DESIGNS = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B-warm", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]
opts() = setting == "strict" ?
  PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true) :
  H.benchmark_options(; residual = true)
function termination(r, maxiter)
  r.converged && return "converged"
  r.call_limit_reached && return "call_limit"
  r.iterations == maxiter && return "maxiter"
  r.f_increased && return "f_increased"
  return "stopped_other"   # stagnation (or callback/time limit, not used here)
end
println(join(("label", "julia", "T", "case", "rep", "setting", "iterations", "termination", "converged", "x_conv", "f_conv", "g_conv",
  "f_increased", "x_residual", "g_residual", "backtracks", "f_calls", "grad_calls", "prox_calls", "verif", "products",
  "gap", "pass", "alloc_bytes", "time_us"), '\t'))
for T in Ts, (name, make, warm) in DESIGNS, rep in a_:b_
  a = H.core_problem(make(rep), T; warm)
  f, g = H.benchmark_model(a)
  method = H.core_method("pg", T)
  o = opts()
  ex = H.exact_problem(a)
  x = copy(a.start)
  PS._check_problem(x, f, g)
  st = PS.initial_state(method, o, f, g, x)
  r = PS._solve_gradient!(st, f, g, method, o, time())
  # the public entry point must give the same result; then its allocations and time
  x2 = copy(a.start); r2 = PS.solve!(x2, f, g, method, o)
  (x2 == x && r2.iterations == r.iterations) || error("solve! differs from _solve_gradient! on $name/$rep")
  x2 .= a.start; bytes = @allocated PS.solve!(x2, f, g, method, o)
  t = Inf
  for _ in 1:3
    x2 .= a.start; t0 = time_ns(); PS.solve!(x2, f, g, method, o); t = min(t, (time_ns() - t0) / 1e3)
  end
  cert = H.certify(ex, Float64.(x))
  println(join((label, "v$(VERSION.major).$(VERSION.minor)", T, name, rep, setting, r.iterations, termination(r, o.maxiter),
    r.converged, r.x_converged, r.f_converged, r.grad_converged, r.f_increased, r.x_residual, r.g_residual,
    r.backtrack_steps, r.f_calls, r.grad_calls, r.prox_calls, st.verifications,
    st.prox_calls + st.grad_calls + st.verifications, cert.value, cert.value <= H.CORE_TARGETS[T], bytes, round(t; digits = 1)), '\t'))
  flush(stdout)
end
