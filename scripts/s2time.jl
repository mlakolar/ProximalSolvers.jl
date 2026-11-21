# #320 Stage 2: cost of the widened gap evaluator (research only).
#
#   julia --project=<env> s2time.jl <outprefix> <draws a:b>
#
# Per Float32 problem, arms in a rotating order over ROUNDS rounds; the statistic is the minimum
# per-call time over rounds (fixed before the run). Arms:
#   H, Haa     library solve! with the harness options H (fresh copy of the start), twice (A/A)
#   W1, W1aa   one widened evaluation (on-the-fly widening, no copy of X) at the H point, twice (A/A)
#   W2         the evaluation with a caller-held Float64 copy of X and BLAS
#   W2setup    building that Float64 copy (one-time cost per solve if W2 were chosen)
#   R32        the comparator that reuses rounded Float32 BLAS products (allocates)
#   G32        one Float32 product pair X*x and Xᵀ*r with mul! (about one gradient of the solver)
# Allocation of each arm after warm-up is recorded with @allocated.
using Random
include(joinpath(@__DIR__, "s2common.jl"))
outprefix, draws = ARGS[1], ARGS[2]
a_, b_ = parse.(Int, split(draws, ':'))
const ROUNDS = parse(Int, get(ENV, "S2_ROUNDS", "11"))
BLAS.set_num_threads(1)
Threads.nthreads() == 1 || error("one Julia thread required")
mkpath(dirname(outprefix))
open(io -> provenance(io), outprefix * "-provenance.txt", "w")

const DESIGNS = vcat(HARNESS_DESIGNS, filter(d -> d[1] in ("adv-ill-low-cold", "adv-wide-low-cold"), ADVERSE_DESIGNS))

# time `reps` calls of f(), return seconds per call
function percall(f, reps)
  t0 = time_ns()
  for _ in 1:reps
    f()
  end
  (time_ns() - t0) * 1e-9 / reps
end

io = open(outprefix * "-time.tsv", "w")
tsv(io, "julia", "cpu", "design", "draw", "n", "p", "H_iterations", "arm", "reps", "min_s", "median_s", "alloc_bytes")
rng = MersenneTwister(320)
for (design, make, warm) in DESIGNS, draw in a_:b_
  built = make(draw)
  a = H.core_problem(built, Float32; warm)
  f, g = H.benchmark_model(a)
  oH = H.benchmark_options(; residual = true)
  method = PS.ProximalGradientDescent()
  n, p = size(a.X)
  xH = copy(a.start); rH = PS.solve!(xH, f, g, method, oH)
  work = GapWork(n, p); X64 = Float64.(a.X); x64 = zeros(p)
  xs = copy(a.start)
  r32 = zeros(Float32, n); z32 = zeros(Float32, p)
  sink = Ref(0.0)
  arms = Dict(
    "H" => () -> (copyto!(xs, a.start); sink[] += PS.solve!(xs, f, g, method, oH).iterations),
    "Haa" => () -> (copyto!(xs, a.start); sink[] += PS.solve!(xs, f, g, method, oH).iterations),
    "W1" => () -> (sink[] += gap_widened!(work, a.X, a.y, a.s, a.λ, xH).rel),
    "W1aa" => () -> (sink[] += gap_widened!(work, a.X, a.y, a.s, a.λ, xH).rel),
    "W2" => () -> (sink[] += gap_widened_blas!(work, X64, a.y, a.s, a.λ, xH, x64).rel),
    "W2setup" => () -> (sink[] += Float64.(a.X)[1]),
    "R32" => () -> (sink[] += gap_rounded(a.X, a.y, a.s, a.λ, xH).rel),
    "G32" => () -> (mul!(r32, a.X, xH); r32 .= a.y .- r32; mul!(z32, transpose(a.X), r32); sink[] += z32[1]))
  names = sort(collect(keys(arms)))
  # warm-up and repetitions so that one measurement lasts about 20 ms
  reps = Dict{String, Int}()
  allocs = Dict{String, Int}()
  for nm in names
    fn = arms[nm]
    fn(); fn()
    allocs[nm] = @allocated fn()
    t = percall(fn, 3)
    reps[nm] = max(1, round(Int, 0.02 / max(t, 1e-9)))
  end
  times = Dict(nm => Float64[] for nm in names)
  for _ in 1:ROUNDS
    for nm in shuffle(rng, names)
      push!(times[nm], percall(arms[nm], reps[nm]))
    end
  end
  for nm in names
    tsv(io, VERSION, Sys.cpu_info()[1].model, design, draw, n, p, rH.iterations, nm, reps[nm],
        minimum(times[nm]), median(times[nm]), allocs[nm])
  end
  flush(io)
  println(stderr, "done ", design, " draw ", draw, " sink ", sink[] > 0)
end
close(io)
println(stderr, "s2time finished")
