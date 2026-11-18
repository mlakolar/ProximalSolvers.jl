# #317 paired in-process timing of the ordinary path: base source (A), the head source (B), and second
# compiled copies base2 and head2 (A/A controls), alternating in one process. PGD only, cold start.
# One Julia thread, one BLAS thread.
#   julia --project=<env> paired317.jl <base src> <head src> <rounds> <groups...>
#   groups: time (needs rounds >= 1), allocs
using LinearAlgebra, Random, Printf, Statistics
import ProximalBase
BLAS.set_num_threads(1)
basesrc, headsrc = abspath.(ARGS[1:2])
rounds = parse(Int, ARGS[3]); groups = ARGS[4:end]
for (w, src) in ((:BaseW, basesrc), (:HeadW, headsrc), (:Base2W, basesrc), (:Head2W, headsrc))
  Core.eval(Main, :(module $w; include($(joinpath(src, "ProximalSolvers.jl"))); end))
end
const SIDES = (base = BaseW.ProximalSolvers, head = HeadW.ProximalSolvers,
               base2 = Base2W.ProximalSolvers, head2 = Head2W.ProximalSolvers)
println("julia ", VERSION, " ", Sys.CPU_NAME, " threads ", Threads.nthreads(), " blas ", BLAS.get_num_threads())
include(joinpath(@__DIR__, "datasets.jl"))

function bigdata()   # n = 200, p = 500, seeded lasso signal
  rng = Xoshiro(317)
  X = randn(rng, 200, 500)
  β = zeros(500); β[1:10] .= [2.0, -1.5, 1.0, 0.5, -0.5, 1.2, -0.8, 0.7, -1.1, 0.9]
  X, X * β + 0.3 * randn(rng, 200)
end
designdata(d) = d == "big" ? bigdata() : data(d)

struct Case{T, F, G}
  name::String
  opts::String
  x0::Vector{T}
  f::F
  g::G
end
cases = Case[]
λmaxof(X, y) = maximum(abs, X' * y)
for d in ("base", "ill", "big"), T in (Float64, Float32), fr in (0.1, 0.5), o in ("default", "strict")
  X, y = designdata(d)
  f = ProximalBase.LeastSquaresLoss(T.(y), T.(X)); g = ProximalBase.NormL1(T(fr * λmaxof(X, y)))
  push!(cases, Case("$d/$T/fr$fr", o, zeros(T, size(X, 2)), f, g))
end
opts(M, o) = o == "strict" ?
  M.ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11) : M.ProximalOptions()

const SINK = Ref(0.0)   # typed result sink: keeps each solve's result live
# one batch: the minimum over reps solves of the time of solve!, in microseconds (function barrier;
# the solve function is a type parameter, so the call is static)
function run_batch!(sf::F, x, x0, f, g, method, options, reps) where F
  t = Inf
  acc = 0.0
  for _ in 1:reps
    copyto!(x, x0)
    t0 = time_ns()
    r = sf(x, f, g, method, options)
    t = min(t, (time_ns() - t0) / 1e3)
    acc += r.iterations + Float64(x[1])
  end
  SINK[] += acc
  t
end

println("load_start ", strip(read("/proc/loadavg", String)))
alloc_rows = Tuple[]
if "allocs" in groups || "time" in groups
  println("INFO\tcase\topts\tside\titerations\tconverged\tbytes_warmed\tsame_x_as_base")
  xbase = Dict{String, Vector}()
  for c in cases
    for s in keys(SIDES)
      M = SIDES[s]; m = M.ProximalGradientDescent(); o = opts(M, c.opts)
      x = copy(c.x0)
      M.solve!(x, c.f, c.g, m, o)                 # warm up (compile)
      copyto!(x, c.x0); M.solve!(x, c.f, c.g, m, o)
      copyto!(x, c.x0); bytes = @allocated M.solve!(x, c.f, c.g, m, o)
      copyto!(x, c.x0); r = M.solve!(x, c.f, c.g, m, o)
      key = c.name * "/" * c.opts
      s == :base && (xbase[key] = copy(x))
      @printf "INFO\t%s\t%s\t%s\t%d\t%s\t%d\t%s\n" c.name c.opts s r.iterations r.converged bytes (x == xbase[key])
    end
  end
end

if "time" in groups
  times = Dict{Tuple{String, String, Symbol}, Vector{Float64}}()
  # batch sizes: about 40 ms of solving per batch, at most 10 solves
  reps = Dict{Tuple{String, String}, Int}()
  for c in cases
    M = SIDES.base; m = M.ProximalGradientDescent(); o = opts(M, c.opts); x = copy(c.x0)
    t = run_batch!(M.solve!, x, c.x0, c.f, c.g, m, o, 1)
    reps[(c.name, c.opts)] = clamp(round(Int, 40_000 / t), 1, 10)
  end
  println("TIME\tround\tcase\topts\tside\tmicroseconds")
  for rnd in 1:rounds
    order = isodd(rnd) ? collect(keys(SIDES)) : reverse(collect(keys(SIDES)))
    for c in cases
      for s in order
        M = SIDES[s]; m = M.ProximalGradientDescent(); o = opts(M, c.opts); x = copy(c.x0)
        t = run_batch!(M.solve!, x, c.x0, c.f, c.g, m, o, reps[(c.name, c.opts)])
        push!(get!(times, (c.name, c.opts, s), Float64[]), t)
        @printf "TIME\t%d\t%s\t%s\t%s\t%.2f\n" rnd c.name c.opts s t
      end
    end
  end
  println("SUMMARY\tcase\topts\treps\tmedian head/base\tmin head/base\tmax head/base\tmedian head2/head\tmedian base2/base\tmin/max base2/base\tmin/max head2/head")
  allr = Float64[]
  for c in cases
    t(s) = times[(c.name, c.opts, s)]
    r1 = t(:head) ./ t(:base); r2 = t(:head2) ./ t(:head); r3 = t(:base2) ./ t(:base)
    append!(allr, r1)
    @printf "SUMMARY\t%s\t%s\t%d\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.3f/%.3f\t%.3f/%.3f\n" c.name c.opts reps[(c.name, c.opts)] median(r1) minimum(r1) maximum(r1) median(r2) median(r3) minimum(r3) maximum(r3) minimum(r2) maximum(r2)
  end
  @printf "OVERALL median of per-round head/base ratios over all cases and rounds: %.4f\n" median(allr)
  println("sink ", SINK[])
end
println("load_end ", strip(read("/proc/loadavg", String)))
println("DONE")
