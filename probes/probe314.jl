# Disposable #314 probe (not part of the harness; no new runner). It loads the formal harness's
# problems.jl, certificates.jl and cases.jl into a module and, per problem and draw, runs PGD/APG
# under several ProximalOptions profiles, recording the independent certificate (harness
# `certify` on the rounded inputs read back in Float64), the stop flags and the work counters.
#
#   julia --project=<setup.jl env> probe314.jl <root> <set> <out.tsv> <draws a:b> [shard k/K] [rounds]
#
# <set>: "harness"  the 20 current-core PGD/APG cases (data hash checked against the harness case)
#        "sel"      Phase B selection problems (key prefix issue314/sel/)
#        "conf"     Phase B confirmation problems (key prefix issue314/conf/), independent seeds
#
# Profiles (frozen before any Phase B measurement; see PREREGISTRATION.md):
#   D   ProximalOptions()                                       package defaults
#   H   benchmark_options(residual = true)                      the harness's current-core settings
#   S   ftol=0, xtol=1e-300, gradtol=1e-11, allow_f_increases   #312 strict stress settings
#   P1  ftol=0, xtol=1e-14, gradtol=target(T), allow_f_increases
#   P2  ftol=0, xtol=1e-14, gradtol=target(T)/100, allow_f_increases
# all with maxiter = 10_000 except D (its default 200).
#
# Iterates do not depend on the stopping options, so every profile follows one trajectory until it
# stops. The probe checks that: a traced run (ftol=0, xtol=1e-300, gradtol=0, allow_f_increases,
# stopped at the largest profile stop K) certifies every iterate; the gap at each profile's K must
# equal the gap of that profile's returned minimizer. k* = first iteration with gap <= target.
# Time to target = a timed solve stopped at k* (maxiter = k*, or a callback stop for k* = 1).
# Timing: per (case, draw), `rounds` rounds, each timing every arm once in rotating order:
# the profiles' solves, the time-to-target solve and an A/A copy of H ("Haa").
root, set, out, draws = ARGS[1], ARGS[2], ARGS[3], ARGS[4]
shard = length(ARGS) >= 5 ? parse.(Int, split(ARGS[5], '/')) : [1, 1]
ROUNDS = length(ARGS) >= 6 ? parse(Int, ARGS[6]) : 5
a_, b_ = parse.(Int, split(draws, ':'))

const H = Module(:Harness314)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(root, "benchmark", f))
end
import ProximalSolvers
using LinearAlgebra, Printf, Statistics
BLAS.set_num_threads(1)
Threads.nthreads() == 1 || error("one Julia thread required")
const PS = ProximalSolvers
target(T) = H.CORE_TARGETS[T]

profiles(T) = [
  ("D", PS.ProximalOptions()),
  ("H", H.benchmark_options(; residual = true)),
  ("S", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)),
  ("P1", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = target(T), allow_f_increases = true)),
  ("P2", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = target(T) / 100, allow_f_increases = true))]

method(solver, T) = H.core_method(solver, T)

# ---- problem sets ------------------------------------------------------------------------
harness_designs = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]

# Phase B: column scales spread over two decades for the ill-conditioned design; λ recomputed.
function illcond(a, fraction)
  p = size(a.X, 2)
  X = a.X .* (10.0 .^ (-2 .* (0:p-1) ./ (p - 1)))'
  merge(a, (; X, λ = fraction * H.lambda_max(X, a.y; s = a.s)))
end
phaseb_designs(prefix) = [
  ("ord", (r, fr) -> H.regression_problem(r, "$prefix/ord"; n = 200, p = 100, design = :A, fraction = fr)),
  ("cor", (r, fr) -> H.regression_problem(r, "$prefix/cor"; n = 240, p = 160, design = :B, fraction = fr)),
  ("equi", (r, fr) -> H.regression_problem(r, "$prefix/equi"; n = 240, p = 160, design = :E, fraction = fr)),
  ("wide", (r, fr) -> H.regression_problem(r, "$prefix/wide"; n = 180, p = 600, design = :A, fraction = fr)),
  ("ill", (r, fr) -> illcond(H.regression_problem(r, "$prefix/ill"; n = 240, p = 160, design = :A), fr))]
const FRACTIONS = (("high", 0.5), ("mid", 0.15), ("low", 0.02))

# items: (case label, design, λ level, warm, T, solver, draw, problem builder, harness id or "")
items = []
if set == "harness"
  catalog = Dict(s.meta.id => s for s in H.build_catalog("extended", ["gradient"]))
  for (name, make, warm) in harness_designs, solver in ("pg", "apg"), T in (Float64, Float32), r in a_:b_
    id = "gradient/$name/$solver/$(warm ? "warm-" : "")dense-$(T == Float32 ? "f32" : "f64")/call"
    haskey(catalog, id) || error("harness has no case $id")
    push!(items, (id, name, "harness", warm, T, solver, r, () -> make(r), id))
  end
else
  set in ("sel", "conf") || error("unknown set $set")
  for (name, make) in phaseb_designs("issue314/$set"), (lev, fr) in FRACTIONS, warm in (false, true),
      solver in ("pg", "apg"), T in (Float64, Float32), r in a_:b_
    id = "$set/$name/$lev/$(warm ? "warm" : "cold")/$solver/$(T == Float32 ? "f32" : "f64")"
    push!(items, (id, name, lev, warm, T, solver, r, () -> make(r, fr), ""))
  end
end
k, K = shard
items = items[k:K:end]

# ---- measurement -------------------------------------------------------------------------
products(st::PS.ProximalGradientDescentState, r) = 1 + r.grad_calls + r.prox_calls + st.verifications
products(st::PS.AccProxGradDescentState, r) = 1 + r.grad_calls + r.prox_calls + st.fallbacks
checks(st::PS.ProximalGradientDescentState) = st.verifications
checks(st::PS.AccProxGradDescentState) = st.fallbacks

function termination(r, o)
  r.converged && return join([t for (t, b) in (("x", r.x_converged), ("f", r.f_converged), ("g", r.grad_converged)) if b], "+")
  r.stagnated && return "stagnated"
  r.call_limit_reached && return "call_limit"
  r.iteration_converged && return "maxiter"
  r.f_increased && !o.allow_f_increases && return "f_increased"
  return "other"
end

function solve_with_state(a, solver, o)
  T = eltype(a.X)
  f, g = H.benchmark_model(a)
  m = method(solver, T)
  x = copy(a.start)
  st = PS.initial_state(m, o, f, g, x)
  r = PS._solve_gradient!(st, f, g, m, o, time())
  x2 = copy(a.start); r2 = PS.solve!(x2, f, g, m, o)
  (x2 == x && r2.iterations == r.iterations) || error("solve! differs from the state-level solve")
  st, r, x
end

timed(f, g, m, start, o) = (x = copy(start); t0 = time_ns(); PS.solve!(x, f, g, m, o); time_ns() - t0)

header = ("set", "id", "design", "level", "warm", "T", "solver", "draw", "profile", "gap", "target", "pass",
  "termination", "converged", "stagnated", "iteration_limit", "x_conv", "f_conv", "g_conv", "f_increased",
  "iterations", "f_calls", "grad_calls", "prox_calls", "backtracks", "checks", "products", "alloc_bytes",
  "kstar", "time_med_ns", "time_min_ns", "ttt_med_ns", "ttt_min_ns", "traj_ok", "data_hash", "julia", "cpu")
io = open(out, "w")
println(io, join(header, '\t'))
println(stderr, "PS ", pkgdir(PS), " julia ", VERSION, " ", Sys.CPU_NAME, " items ", length(items))

for (n_item, (id, name, lev, warm, T, solver, r, build, hid)) in enumerate(items)
  a = H.core_problem(build(), T; warm)
  dh = H.data_hash(a)
  if !isempty(hid)
    st0 = catalog[hid].make(r)
    st0.problem_hash == dh || error("inputs differ from the harness for $hid draw $r")
  end
  ex = H.exact_problem(a)
  tgt = target(T)
  f, g = H.benchmark_model(a)
  m = method(solver, T)
  profs = profiles(T)
  res = [(pn, o, solve_with_state(a, solver, o)...) for (pn, o) in profs]
  certs = [H.certify(ex, Float64.(x)) for (_, _, _, _, x) in res]
  Kmax = max(2, maximum(rr.iterations for (_, _, _, rr, _) in res))
  # trace the shared trajectory
  gaps = Float64[]
  cb = os -> begin
    c = H.certify(ex, Float64.(os.metadata["x"]))
    push!(gaps, c.status == :ok ? c.value : NaN)
    false
  end
  tro = PS.ProximalOptions(maxiter = Kmax, ftol = 0, xtol = 1e-300, gradtol = 0.0, allow_f_increases = true,
                           extended_trace = true, callback = cb)
  PS.solve!(copy(a.start), f, g, m, tro)
  # callback is called at iteration 0 too (trace! of the initial state) if the package does so;
  # align: the trace has one entry per iteration 1..K, or 0..K
  off = length(gaps) == Kmax + 1 ? 1 : 0
  gap_at(kk) = kk + off <= length(gaps) && kk + off >= 1 ? gaps[kk + off] : NaN
  start_gap = H.certify(ex, Float64.(a.start)).value
  kstar = start_gap <= tgt ? 0 : something(findfirst(<=(tgt), gaps[1+off:end]), -1)
  # time to target arm
  ttt_opts = kstar >= 2 ? PS.ProximalOptions(maxiter = kstar, ftol = 0, xtol = 1e-300, gradtol = 0.0, allow_f_increases = true) :
             kstar == 1 ? PS.ProximalOptions(maxiter = 2, ftol = 0, xtol = 1e-300, gradtol = 0.0, allow_f_increases = true,
                                             callback = os -> os.iteration >= 1) : nothing
  arms = Tuple{String, Any}[(pn, o) for (pn, o) in profs]
  push!(arms, ("Haa", profs[2][2]))
  ttt_opts === nothing || push!(arms, ("TTT", ttt_opts))
  for (_, o) in arms; timed(f, g, m, a.start, o); end   # warm-up
  times = Dict(an => Int[] for (an, _) in arms)
  for round in 1:ROUNDS
    sh = mod(round + n_item, length(arms))
    for (an, o) in circshift(arms, sh)
      push!(times[an], timed(f, g, m, a.start, o))
    end
  end
  tt = haskey(times, "TTT") ? (round(Int, median(times["TTT"])), minimum(times["TTT"])) :
       kstar == 0 ? (0, 0) : ("", "")
  for (i, (pn, o, st, rr, x)) in enumerate(res)
    c = certs[i]
    gv = c.status == :ok ? c.value : NaN
    traj = isequal(gap_at(rr.iterations), gv) || (isnan(gap_at(rr.iterations)) && isnan(gv))
    x3 = copy(a.start); bytes = @allocated PS.solve!(x3, f, g, m, o)
    println(io, join((set, id, name, lev, warm, T, solver, r, pn, gv, tgt, c.status == :ok && gv <= tgt,
      termination(rr, o), rr.converged, rr.stagnated, rr.iteration_converged, rr.x_converged, rr.f_converged,
      rr.grad_converged, rr.f_increased, rr.iterations, rr.f_calls, rr.grad_calls, rr.prox_calls,
      rr.backtrack_steps, checks(st), products(st, rr), bytes, kstar,
      round(Int, median(times[pn])), minimum(times[pn]), tt[1], tt[2], traj, dh,
      "$(VERSION.major).$(VERSION.minor).$(VERSION.patch)", Sys.CPU_NAME), '\t'))
  end
  # the A/A copy of H, as its own row (same solve as H)
  println(io, join((set, id, name, lev, warm, T, solver, r, "Haa", "", tgt, "", "", "", "", "", "", "", "", "",
    "", "", "", "", "", "", "", "", kstar, round(Int, median(times["Haa"])), minimum(times["Haa"]), "", "", "",
    dh, "$(VERSION.major).$(VERSION.minor).$(VERSION.patch)", Sys.CPU_NAME), '\t'))
  flush(io)
end
close(io)
println(stderr, "done ", out)
