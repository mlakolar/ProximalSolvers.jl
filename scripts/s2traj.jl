# #320 Stage 2: hypothetical gap stopping along recorded solver trajectories, and the accuracy of
# the widened gap evaluator against BigFloat(256) on the same rounded inputs (research only).
#
#   julia --project=<env> s2traj.jl <outprefix> <draws a:b> [designs,comma separated]
#
# For each problem and solver arm (Float32 PGD, Float32 APG, Float64 PGD):
#  * the library solve with the harness options H (benchmark_options(residual = true)) gives the
#    current stop, its flags and its class;
#  * one trajectory is stepped with the solver's own update_state! (options do not enter the step;
#    checked: the trajectory iterate at the H stop equals the library's returned iterate), with no
#    stop, up to KMAX iterations or an unchanged iterate for 200 iterations;
#  * at every iteration: the widened gap W1 (identity and P-D forms), the computed KKT check of the
#    H options (_stationary!), and the computed objective increase;
#  * hypothetical rules (none changes the iterates):
#      R1    stop at the first iteration with W1 relative gap <= tol (evaluated every iteration)
#      R10   the same, evaluated every 10th iteration (gapevery = 10)
#      RK    evaluated only where the computed KKT check passes
#      R1i   R1, but an objective increase still ends the solve (unverified, as now)
#      RKi   RK, but an objective increase still ends the solve
#    tol = 1e-5 (Float32) or 1e-8 (Float64), the harness targets; R1 and RK also at 10 tol, tol/10;
#  * BigFloat(256) relative gap at every rule stop, the H stop, iterates whose W1 gap lies within a
#    factor 3 of tol (up to NBAND per trajectory) and every 50th iterate (up to 40).
using Random
include(joinpath(@__DIR__, "s2common.jl"))
outprefix, draws = ARGS[1], ARGS[2]
only_designs = length(ARGS) >= 3 ? split(ARGS[3], ',') : String[]
a_, b_ = parse.(Int, split(draws, ':'))
const KMAX = parse(Int, get(ENV, "S2_KMAX", "10000"))
const NBAND = parse(Int, get(ENV, "S2_NBAND", "60"))
BLAS.set_num_threads(1)
Threads.nthreads() == 1 || error("one Julia thread required")
mkpath(dirname(outprefix))
open(io -> provenance(io), outprefix * "-provenance.txt", "w")

termination(r, o) = r.converged ? "converged" : r.stagnated ? "stagnated" : r.call_limit_reached ? "call_limit" :
  (r.f_increased && !o.allow_f_increases) ? "f_increased" : r.iteration_converged ? "maxiter" : "callback_or_time"

struct Rule
  name::String
  tolmul::Float64
  every::Int
  kkt_gated::Bool
  increase_exit::Bool
end
const RULES = [Rule("R1", 1, 1, false, false), Rule("R10", 1, 10, false, false), Rule("RK", 1, 1, true, false),
               Rule("R1i", 1, 1, false, true), Rule("RKi", 1, 1, true, true),
               Rule("R1x10", 10, 1, false, false), Rule("R1d10", 0.1, 1, false, false),
               Rule("RKx10", 10, 1, true, false), Rule("RKd10", 0.1, 1, true, false)]

mutable struct RuleState
  done::Bool; k::Int; reason::String; ngap::Int; wrel::Float64
end

function run_problem(design, make, warm, draw, T, solver, sio, aio)
  built = make(draw)
  a = H.core_problem(built, T; warm)
  dh = H.data_hash(a)
  ex = H.exact_problem(a)
  f, g = H.benchmark_model(a)
  tol = H.CORE_TARGETS[T]
  oH = H.benchmark_options(; residual = true)
  method = solver == "apg" ? PS.AccProxGradDescent() : PS.ProximalGradientDescent()
  # library solve with H
  xH = copy(a.start)
  rH = PS.solve!(xH, f, g, method, oH)
  classH = termination(rH, oH)
  # trajectory
  oS = PS.ProximalOptions(maxiter = KMAX, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
  x = copy(a.start)
  st = PS.initial_state(method, oS, f, g, x)
  n, p = size(a.X)
  work = GapWork(n, p)
  X64 = Float64.(a.X); x64 = zeros(p); work2 = GapWork(n, p)
  Xb, yb, sb, λb = setprecision(BigFloat, 256) do
    big.(Float64.(a.X)), big.(Float64.(a.y)), big(Float64(a.s)), big(Float64(a.λ))
  end
  bigrel(xv) = setprecision(BigFloat, 256) do
    gap_big_prepared(Xb, yb, sb, λb, big.(Float64.(xv))).rel
  end
  rs = Dict(r.name => RuleState(false, 0, "", 0, NaN) for r in RULES)
  kstar_cert = -1                    # first iterate with harness Float64 certificate <= tol
  hcheck = "n/a"; bigH = NaN
  unchanged_run = 0
  nband = 0; nsamp = 0
  k = 0
  stopped_trajectory = "kmax"
  rows_big = Tuple[]
  while k < KMAX
    k += 1
    PS.update_state!(f, g, st, method)
    isfinite(st.f_x + st.g_x) || error("nonfinite objective")
    fval = st.f_x + st.g_x; fprev = st.f_x_previous + st.g_x_previous
    incr = fval > fprev
    unchanged_run = st.x == st.x_previous ? unchanged_run + 1 : 0
    wr = gap_widened!(work, a.X, a.y, a.s, a.λ, st.x)
    kkt = PS._stationary!(st, f, g, oH)
    c = H.certify(ex, Float64.(st.x))
    cert = c.status == :ok ? c.value : NaN
    (kstar_cert < 0 && cert <= tol) && (kstar_cert = k)
    if k == rH.iterations
      hcheck = st.x == xH ? "ok" : "MISMATCH"
    end
    anystop = false
    for r in RULES
      s = rs[r.name]
      s.done && continue
      eval_now = (k % r.every == 0) && (!r.kkt_gated || kkt)
      if eval_now
        s.ngap += 1
        if wr.rel <= r.tolmul * tol
          s.done = true; s.k = k; s.reason = "gap"; s.wrel = wr.rel; anystop = true
          continue
        end
      end
      if r.increase_exit && incr
        s.done = true; s.k = k; s.reason = "f_increased"; s.wrel = wr.rel; anystop = true
      end
    end
    # BigFloat samples
    inband = tol / 3 <= wr.rel <= 3tol
    want = anystop || k == rH.iterations || (inband && nband < NBAND) || (k % 50 == 0 && nsamp < 40)
    if want
      inband && (nband += 1); (k % 50 == 0) && (nsamp += 1)
      w2 = gap_widened_blas!(work2, X64, a.y, a.s, a.λ, st.x, x64)
      r32 = gap_rounded(a.X, a.y, a.s, a.λ, st.x)
      br = bigrel(st.x)
      k == rH.iterations && (bigH = br)
      tsv(aio, VERSION, design, draw, T, solver, k, wr.rel, wr.rel_pd, w2.rel, r32.rel, cert, br, kkt, incr, wr.status)
      for r in RULES
        s = rs[r.name]
        (s.done && s.k == k) && push!(rows_big, (r.name, br))
      end
    end
    if all(s -> s.done, values(rs)) && k >= rH.iterations && (wr.rel <= tol / 10 || k >= maximum(s.k for s in values(rs)) + 50)
      stopped_trajectory = "rules_done"; break
    end
    if unchanged_run >= 200
      stopped_trajectory = "unchanged200"; break
    end
  end
  bigat = Dict(rows_big)
  for r in RULES
    s = rs[r.name]
    if !s.done
      s.k = k; s.reason = stopped_trajectory == "kmax" ? "maxiter" : "stalled"
    end
    br = get(bigat, r.name, NaN)
    success = s.reason == "gap"
    tsv(sio, VERSION, Sys.cpu_info()[1].model, design, draw, T, solver, dh, tol, r.name, r.tolmul * tol, r.every, r.kkt_gated,
        r.increase_exit, s.k, s.reason, s.ngap, s.wrel, br, success && br > r.tolmul * tol, success,
        rH.iterations, classH, rH.converged, bigH, kstar_cert, hcheck, stopped_trajectory, k)
  end
  flush(sio); flush(aio)
end

sio = open(outprefix * "-rules.tsv", "w")
tsv(sio, "julia", "cpu", "design", "draw", "T", "solver", "data_hash", "target", "rule", "gaptol", "every", "kkt_gated",
    "increase_exit", "stop_k", "reason", "n_gap_evals", "w_rel_at_stop", "big_rel_at_stop", "false_success", "success",
    "H_iterations", "H_class", "H_converged", "H_big_rel", "kstar_cert", "H_traj_check", "trajectory_end", "trajectory_len")
aio = open(outprefix * "-accuracy.tsv", "w")
tsv(aio, "julia", "design", "draw", "T", "solver", "k", "w1_rel", "w1_rel_pd", "w2_rel", "r32_rel", "cert64_rel", "big_rel",
    "kkt_pass", "f_increased", "status")
for (design, make, warm) in ALL_DESIGNS, draw in a_:b_
  isempty(only_designs) || design in only_designs || continue
  for (T, solver) in ((Float32, "pgd"), (Float32, "apg"), (Float64, "pgd"))
    t0 = time()
    run_problem(design, make, warm, draw, T, solver, sio, aio)
    println(stderr, "done ", design, " draw ", draw, " ", T, " ", solver, " ", round(time() - t0; digits = 1), " s")
  end
end
close(sio); close(aio)
println(stderr, "s2traj finished")
