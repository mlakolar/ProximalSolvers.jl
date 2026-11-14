# Disposable #308 diagnostic (not part of the package or harness).
#   julia --project=<env> trace308.jl <outdir> <reps a:b> [T=Float32] [maxiter=10000]
# Runs the five Float32 PGD benchmark designs under #286's strict settings with the
# package's own update_state!/convergence_assessment (the body of _solve_gradient!,
# without tracing/limits, which are inactive here), and logs every iteration:
# stall, trials, L, mode, computed objective, residual, step size in ulps, the exact
# Float64 objective P64 and the independent relative duality gap.
outdir, reps = ARGS[1], ARGS[2]
Tn = length(ARGS) >= 3 ? ARGS[3] : "Float32"
maxiter = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 10_000
a_, b_ = parse.(Int, split(reps, ':'))
const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const H = Module(:Harness308)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(ROOT, "benchmark", f))
end
import ProximalSolvers
using LinearAlgebra, Printf
BLAS.set_num_threads(1)
const PS = ProximalSolvers
mkpath(outdir)
println("PS at ", pathof(PS), "; julia ", VERSION, "; ", Sys.CPU_NAME)

const DESIGNS = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B-warm", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]

T = Tn == "Float64" ? Float64 : Float32
ulps(a, b) = a == b ? 0.0 : Float64(abs(a - b)) / Float64(eps(max(abs(a), abs(b))))
p64(ex, x) = (r = ex.y - ex.X * x; ex.s * sum(abs2, r) / 2 + ex.λ * sum(abs, x))

summ = open(joinpath(outdir, "v$(VERSION.major).$(VERSION.minor)-$Tn-summary.tsv"), "w")
println(summ, join(("case", "rep", "iterations", "converged", "x_conv", "g_conv", "backtracks",
  "f_calls", "grad_calls", "prox_calls", "verif", "gap_end", "gap_min", "k_hit", "stalls", "check_equal", "mu", "period", "detA", "detS"), '\t'))
for (name, make, warm) in DESIGNS, rep in a_:b_
  a = H.core_problem(make(rep), T; warm)
  f, g = H.benchmark_model(a)
  method = H.core_method("pg", T)
  opts = PS.ProximalOptions(maxiter = maxiter, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)
  ex = H.exact_problem(a)
  x = copy(a.start)
  PS._check_problem(x, f, g)
  st = PS.initial_state(method, opts, f, g, x)
  io = open(joinpath(outdir, "v$(VERSION.major).$(VERSION.minor)-$Tn-$name-$rep.tsv"), "w")
  println(io, join(("k", "stall", "trials", "nbt", "nver", "L", "mode", "F", "dF", "gres",
                    "dx_ulps", "nchg", "P64", "gap", "prods", "conv"), '\t'))
  gapmin, khit, nst, k, conv = Inf, 0, 0, 0, false
  seen = Dict{Vector{UInt8}, Int}(); mu, lamc = 0, 0
  # Brent over every iteration (A) and over stall iterations only, from the first stall (S)
  snapA = similar(st.x); LA = zero(st.L); mA = true; rA = zero(st.L); powA, lamA, detA = 1, -1, 0
  snapS = similar(st.x); LS = zero(st.L); mS = true; rS = zero(st.L); powS, lamS, detS = 1, -1, 0
  nstall_seen = 0
  while !conv && k < maxiter
    k += 1
    p0, b0, v0 = st.prox_calls, st.backtrack_steps, st.verifications
    Fp = Float64(st.f_x + st.g_x)
    PS.update_state!(f, g, st, method)
    isfinite(st.f_x + st.g_x) || error("nonfinite")
    xc, fc, gc, conv, finc = PS.convergence_assessment(st, f, g, opts)
    stall = st.x == st.x_previous
    nst += stall
    du, nchg = 0.0, 0
    @inbounds for i in eachindex(st.x)
      u = ulps(st.x[i], st.x_previous[i]); du = max(du, u); nchg += u > 0
    end
    key = vcat(reinterpret(UInt8, copy(st.x)), reinterpret(UInt8, [st.L, st.max_residual]), UInt8(st.backtrack_simple))
    if mu == 0
      if haskey(seen, key); mu = seen[key]; lamc = k - mu; else; seen[key] = k; end
    end
    if detA == 0
      if lamA < 0
        copyto!(snapA, st.x); LA, mA, rA = st.L, st.backtrack_simple, st.max_residual; lamA = 0
      else
        lamA += 1
        if st.L == LA && st.backtrack_simple == mA && st.max_residual == rA && st.x == snapA
          detA = k
        elseif lamA == powA
          copyto!(snapA, st.x); LA, mA, rA = st.L, st.backtrack_simple, st.max_residual; powA *= 2; lamA = 0
        end
      end
    end
    if detS == 0 && stall
      if lamS < 0
        copyto!(snapS, st.x); LS, mS, rS = st.L, st.backtrack_simple, st.max_residual; lamS = 0
      else
        lamS += 1
        if st.L == LS && st.backtrack_simple == mS && st.max_residual == rS && st.x == snapS
          detS = k
        elseif lamS == powS
          copyto!(snapS, st.x); LS, mS, rS = st.L, st.backtrack_simple, st.max_residual; powS *= 2; lamS = 0
        end
      end
    end
    xx = Float64.(st.x)
    gap = H.certify(ex, xx).value
    gap < gapmin && (gapmin = gap)
    khit == 0 && gap <= H.CORE_TARGETS[T] && (khit = k)
    F = Float64(st.f_x + st.g_x)
    println(io, k, '\t', Int(stall), '\t', st.prox_calls - p0, '\t', st.backtrack_steps - b0, '\t',
            st.verifications - v0, '\t', repr(Float64(st.L)), '\t', Int(st.backtrack_simple), '\t',
            repr(F), '\t', repr(F - Fp), '\t', repr(Float64(PS.g_residual(st))), '\t', du, '\t', nchg, '\t',
            repr(p64(ex, xx)), '\t', repr(gap), '\t', st.prox_calls + st.grad_calls + st.verifications, '\t', Int(conv))
  end
  close(io)
  # the same solve through the public entry point must end at the same point
  x2 = copy(a.start)
  r2 = PS.solve!(x2, f, g, method, opts)
  same = x2 == st.x && r2.iterations == k
  println(summ, join((name, rep, k, conv, false, false, st.backtrack_steps, st.f_calls, st.grad_calls,
    st.prox_calls, st.verifications, H.certify(ex, Float64.(st.x)).value, gapmin, khit, nst, same, mu, lamc, detA, detS), '\t'))
  flush(summ)
  println(name, "/", rep, ": k=", k, " khit=", khit, " stalls=", nst, " gap_end=", H.certify(ex, Float64.(st.x)).value, " same=", same, " mu=", mu, " period=", lamc, " detA=", detA, " detS=", detS)
end
close(summ)
