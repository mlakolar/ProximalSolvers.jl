# Disposable #308 paired in-process timing: base (master), candidate (R-B), and a second
# compiled copy of each (A/A controls), alternating in one process on the five PGD benchmark
# designs. One Julia thread, one BLAS thread.
#   julia --project=<env> paired308.jl <base src> <cand src> <rounds> <draws a:b> <groups...>
#   group = strict-f32 | strict-f64 | harness-f32 | harness-f64
using LinearAlgebra, Random, Printf, Statistics
import ProximalBase
BLAS.set_num_threads(1)
basesrc, candsrc, rounds, drawspec = abspath(ARGS[1]), abspath(ARGS[2]), parse(Int, ARGS[3]), ARGS[4]
groups = ARGS[5:end]
d1, d2 = parse.(Int, split(drawspec, ':'))
for (w, src) in ((:BaseW, basesrc), (:CandW, candsrc), (:Base2W, basesrc), (:Cand2W, candsrc))
  Core.eval(Main, :(module $w; include($(joinpath(src, "ProximalSolvers.jl"))); end))
end
const SIDES = (base = BaseW.ProximalSolvers, cand = CandW.ProximalSolvers, base2 = Base2W.ProximalSolvers, cand2 = Cand2W.ProximalSolvers)
println("julia ", VERSION, " ", Sys.CPU_NAME, " threads ", Threads.nthreads(), " blas ", BLAS.get_num_threads())
println("cand has rule: ", isdefined(SIDES.cand, :_stagnated), "; base has rule: ", isdefined(SIDES.base, :_stagnated))

const H = Module(:Harness308p)
Core.eval(H, :(import ProximalBase; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
root = normpath(joinpath(@__DIR__, "..", ".."))
for f in ("problems.jl", "certificates.jl")
  Base.include(H, joinpath(root, "benchmark", f))
end
designs = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B-warm", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]
warmstart(a) = H.cert_loading_refit(a.X, a.y, 1.25a.λ, a.w, zeros(size(a.X, 2)); tol = 1e-12, maxpasses = 100_000).β

struct Case{T, F, G}
  name::String
  group::String
  x0::Vector{T}
  f::F
  g::G
  ex::NamedTuple
end
cases = Case[]
for grp in groups, (name, make, warm) in designs, d in d1:d2
  T = endswith(grp, "f32") ? Float32 : Float64
  a = make(d)
  start = warm ? warmstart(a) : zeros(size(a.X, 2))
  f = T(a.s) * ProximalBase.LeastSquaresLoss(T.(a.y), T.(a.X))
  g = ProximalBase.NormL1(T(a.λ))
  ex = (; X = Float64.(T.(a.X)), y = Float64.(T.(a.y)), s = Float64(T(a.s)), λ = Float64(T(a.λ)), w = ones(size(a.X, 2)))
  push!(cases, Case("$name/d$d", grp, T.(start), f, g, ex))
end
opts(M, grp) = startswith(grp, "strict") ?
  M.ProximalOptions(maxiter = 10_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11) :
  M.ProximalOptions(maxiter = 10_000, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)
solve_side(x, f, g, method, options) = parentmodule(typeof(method)).solve!(x, f, g, method, options)
function run_batch!(x, x0, f, g, method, options, reps)
  t = Inf
  for _ in 1:reps
    copyto!(x, x0)
    t0 = time_ns()
    solve_side(x, f, g, method, options)
    t = min(t, (time_ns() - t0) / 1e3)
  end
  t
end
gapof(c, x) = H.lasso_certificate(c.ex.X, c.ex.y, c.ex.s, c.ex.λ, c.ex.w, Float64.(x)).value

println("load ", read(`cat /proc/loadavg`, String))
println("INFO\tgroup\tcase\tside\titerations\tconverged\tfinal\tbacktracks\tf_calls\tgrad_calls\tprox_calls\talloc_bytes\tgap\tsame_x_as_base")
xb = Dict{String, Any}()
for c in cases, s in keys(SIDES)
  M = SIDES[s]; m = M.ProximalGradientDescent(); o = opts(M, c.group)
  x = copy(c.x0)
  run_batch!(x, c.x0, c.f, c.g, m, o, 2)
  copyto!(x, c.x0); bytes = @allocated solve_side(x, c.f, c.g, m, o)
  copyto!(x, c.x0); r = solve_side(x, c.f, c.g, m, o)
  s === :base && (xb[c.group * c.name] = copy(x))
  fin = r.converged ? "converged" : r.iterations == o.maxiter ? "maxiter" : r.f_increased ? "f_increased" : "stagnated"
  @printf "INFO\t%s\t%s\t%s\t%d\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.3e\t%s\n" c.group c.name s r.iterations r.converged fin r.backtrack_steps r.f_calls r.grad_calls r.prox_calls bytes gapof(c, x) (x == xb[c.group * c.name])
end
println("T\tround\tgroup\tcase\tbase_us\tcand_us\tbase2_us\tcand2_us")
for k in 1:rounds, c in cases
  x = copy(c.x0)
  ms = map(M -> M.ProximalGradientDescent(), SIDES); os = map(M -> opts(M, c.group), SIDES)
  t1 = run_batch!(x, c.x0, c.f, c.g, ms.base, os.base, 1)
  reps = clamp(round(Int, 2000 / max(t1, 1.0)), 3, 200)
  order = isodd(k) ? (:base, :cand, :base2, :cand2) : (:cand2, :base2, :cand, :base)
  ts = Dict{Symbol, Float64}()
  for s in order
    ts[s] = run_batch!(x, c.x0, c.f, c.g, ms[s], os[s], reps)
  end
  @printf "T\t%d\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\n" k c.group c.name ts[:base] ts[:cand] ts[:base2] ts[:cand2]
end
println("load ", read(`cat /proc/loadavg`, String))
println("done")
