# #296 paired in-process timing: master (base), F+G+R (fgr), the PR head (head) and second
# compiled copies of base and head (A/A controls), alternating in one process.
# One Julia thread, one BLAS thread.
#   julia --project=<env> paired296.jl <base src> <fgr src> <head src> <rounds> <benchmark dir> <groups...>
#   group = ordinary | harness | tiny | allocs
using LinearAlgebra, Random, Printf, Statistics
import ProximalBase
BLAS.set_num_threads(1)
basesrc, fgrsrc, headsrc = abspath.(ARGS[1:3])
rounds = parse(Int, ARGS[4]); benchdir = abspath(ARGS[5]); groups = ARGS[6:end]
for (w, src) in ((:BaseW, basesrc), (:FgrW, fgrsrc), (:HeadW, headsrc), (:Base2W, basesrc), (:Head2W, headsrc))
  Core.eval(Main, :(module $w; include($(joinpath(src, "ProximalSolvers.jl"))); end))
end
const SIDES = (base = BaseW.ProximalSolvers, fgr = FgrW.ProximalSolvers, head = HeadW.ProximalSolvers,
               base2 = Base2W.ProximalSolvers, head2 = Head2W.ProximalSolvers)
println("julia ", VERSION, " ", Sys.CPU_NAME, " threads ", Threads.nthreads(), " blas ", BLAS.get_num_threads())

const H = Module(:Harness296p)
Core.eval(H, :(import ProximalBase; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl")
  Base.include(H, joinpath(benchdir, f))
end
include(joinpath(@__DIR__, "datasets.jl"))

struct Case{T, F, G}
  name::String
  group::String
  x0::Vector{T}
  f::F
  g::G
  opts::String
  method::String
  ex::NamedTuple
end
cases = Case[]
function addcase!(group, name, X, y, s, λ, T, x0, opts, method)
  f = T(s) * ProximalBase.LeastSquaresLoss(T.(y), T.(X)); g = ProximalBase.NormL1(T(λ))
  ex = (; X = Float64.(T.(X)), y = Float64.(T.(y)), s = Float64(T(s)), λ = Float64(T(λ)), w = ones(size(X, 2)))
  push!(cases, Case(name, group, T.(x0), f, g, opts, method, ex))
end
λmaxof(X, y, s) = s * maximum(abs, X' * y)
for grp in groups
  if grp == "ordinary"
    for d in ("base", "ill", "big"), T in (Float64, Float32), m in ("PGD", "APG"), fr in (0.1, 0.5), o in ("default", "ftol0", "strict")
      X, y = data(d); addcase!(grp, "$d/$T/fr$fr", X, y, 1.0, fr * λmaxof(X, y, 1.0), T, zeros(size(X, 2)), o, m)
    end
  elseif grp == "harness"
    designs = [("lasso", r -> H.regression_problem(r, "core/lasso")),
               ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B)),
               ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C)),
               ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D))]
    for (nm, mk) in designs, dr in 1:3, T in (Float64, Float32), m in ("PGD", "APG"), o in ("default", "strict")
      a = mk(dr); addcase!(grp, "$nm/d$dr/$T", a.X, a.y, a.s, a.λ, T, zeros(size(a.X, 2)), o, m)
    end
  elseif grp == "tiny"
    X, y = data("base")
    for (T, s) in ((Float64, 1e-300), (Float32, 1e-30)), m in ("PGD", "APG"), o in ("default", "ftol0")
      addcase!(grp, "base/$T/s$s", X, y, s, 0.1 * λmaxof(X, y, s), T, zeros(size(X, 2)), o, m)
    end
  end
end
opts(M, o; maxiter = nothing) = o == "strict" ?
  M.ProximalOptions(maxiter = something(maxiter, 20_000), ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11) :
  o == "ftol0" ? M.ProximalOptions(maxiter = something(maxiter, 200), ftol = 0) : M.ProximalOptions(maxiter = something(maxiter, 200))
meth(M, m) = m == "PGD" ? M.ProximalGradientDescent() : M.AccProxGradDescent()
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
function relkkt(c, x)
  X, y, s, λ = c.ex.X, c.ex.y, c.ex.s, c.ex.λ; xb = Float64.(x)
  gr = s .* (X' * (X * xb .- y)); m = 0.0
  for i in eachindex(xb)
    m = max(m, iszero(xb[i]) ? max(abs(gr[i]) - λ, 0.0) : abs(gr[i] + λ * sign(xb[i])))
  end
  m / (s * maximum(abs, X' * y))
end

println("load ", read(`cat /proc/loadavg`, String))
println("INFO\tgroup\tcase\tmethod\topts\tside\titerations\tconverged\tx\tf\tg\tf_increased\tmaxiter\tf_calls\tgrad_calls\tprox_calls\talloc_bytes\tgap\trelkkt")
for c in cases, s in keys(SIDES)
  M = SIDES[s]; m = meth(M, c.method); o = opts(M, c.opts)
  x = copy(c.x0)
  run_batch!(x, c.x0, c.f, c.g, m, o, 2)
  copyto!(x, c.x0); bytes = @allocated solve_side(x, c.f, c.g, m, o)
  copyto!(x, c.x0); r = solve_side(x, c.f, c.g, m, o)
  @printf "INFO\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.3e\t%.3e\n" c.group c.name c.method c.opts s r.iterations r.converged r.x_converged r.f_converged r.grad_converged r.f_increased r.iteration_converged r.f_calls r.grad_calls r.prox_calls bytes gapof(c, x) relkkt(c, x)
end

# allocations per warmed iteration: a solve that keeps running (tolerances off) at two iteration
# caps; equal bytes mean no allocation per iteration. Also a case whose stops are proposed and
# then refused each iteration (adversarial diag, default options).
if "allocs" in groups
  println("ALLOC\tcase\tside\tbytes_maxiter50\tbytes_maxiter100")
  X, y = data("base"); Xd, yd = data("diag")
  for (nm, XX, yy, o) in (("base-strict", X, y, "strict"), ("diag-default", Xd, yd, "default")), T in (Float64, Float32), mname in ("PGD", "APG"), s in keys(SIDES)
    M = SIDES[s]; m = meth(M, mname)
    f = ProximalBase.LeastSquaresLoss(T.(yy), T.(XX)); g = ProximalBase.NormL1(T(0.1 * λmaxof(XX, yy, 1.0)))
    x0 = nm == "diag-default" ? T[1, 0] : zeros(T, size(XX, 2))
    b = map((50, 100)) do k
      ok = M.ProximalOptions(maxiter = k, ftol = o == "strict" ? 0 : 1e-6, xtol = o == "strict" ? 1e-300 : 1e-8,
                             gradtol = o == "strict" ? 0 : 1e-5, allow_f_increases = true)
      x = copy(x0); solve_side(x, f, g, m, ok); x = copy(x0); @allocated solve_side(x, f, g, m, ok)
    end
    @printf "ALLOC\t%s/%s/%s\t%s\t%d\t%d\n" nm T mname s b[1] b[2]
  end
end

println("TIME\tround\tgroup\tcase\tmethod\topts\tside\tmicroseconds")
for rnd in 1:rounds
  order = isodd(rnd) ? collect(keys(SIDES)) : reverse(collect(keys(SIDES)))
  for c in cases
    reps = c.group == "harness" && c.opts == "strict" ? 3 : 10
    for s in order
      M = SIDES[s]; m = meth(M, c.method); o = opts(M, c.opts)
      x = copy(c.x0)
      t = run_batch!(x, c.x0, c.f, c.g, m, o, reps)
      @printf "TIME\t%d\t%s\t%s\t%s\t%s\t%s\t%.2f\n" rnd c.group c.name c.method c.opts s t
    end
  end
end
println("load ", read(`cat /proc/loadavg`, String))
println("DONE")
