# #320 Stage 2: the evaluator as a user callback with the current public API (research only).
#   julia --project=<env> s2callback.jl <outprefix>
# Float32 PGD, harness designs and two adverse designs, draws 1:10: stop when the widened gap is at
# most 1e-5, evaluated every iteration (print_every = 1), with ftol = 0 and allow_f_increases = true.
# Compared with the trajectory rule R1 of s2traj (same iterates, same rule): the stop iteration and
# the BigFloat gap at the returned point.
include(joinpath(@__DIR__, "s2common.jl"))
outprefix = ARGS[1]; mkpath(dirname(outprefix))
open(io -> provenance(io), outprefix * "-provenance.txt", "w")
BLAS.set_num_threads(1)
io = open(outprefix * "-callback.tsv", "w")
tsv(io, "julia", "design", "draw", "iterations", "converged", "f_increased", "stagnated", "iteration_converged", "w_rel", "big_rel", "alloc_bytes")
for (design, make, warm) in vcat(HARNESS_DESIGNS, filter(d -> d[1] in ("adv-cor-low-cold", "adv-wide-low-cold"), ADVERSE_DESIGNS)), draw in 1:10
  a = H.core_problem(make(draw), Float32; warm)
  f, g = H.benchmark_model(a)
  n, p = size(a.X); work = GapWork(n, p)
  last = Ref(NaN)
  cb = os -> (last[] = gap_widened!(work, a.X, a.y, a.s, a.λ, os.metadata["x"]).rel; last[] <= 1e-5)
  o = PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true,
                         extended_trace = true, callback = cb)
  x = copy(a.start); r = PS.solve!(x, f, g, PS.ProximalGradientDescent(), o)
  x2 = copy(a.start); al = @allocated PS.solve!(x2, f, g, PS.ProximalGradientDescent(), o)
  b = gap_big(a.X, a.y, a.s, a.λ, x).rel
  tsv(io, VERSION, design, draw, r.iterations, r.converged, r.f_increased, r.stagnated, r.iteration_converged, last[], b, al)
end
close(io); println(stderr, "s2callback finished")
