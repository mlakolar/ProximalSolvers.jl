# Disposable #320 probe (research only; not part of the package or the harness). It loads the
# formal harness's problems.jl, certificates.jl and cases.jl, builds the harness's Float32/Float64
# problems (rounded once, same data hashes), and for each problem
#
#  * follows ONE PGD trajectory with a copy of the solver loop built on the loaded revision's own
#    state, line search, gradient test and stationarity check (it calls update_state!, _gradient_test,
#    _stationary! and _stagnated of the loaded ProximalSolvers; nothing in src/ is changed), and
#    evaluates for every iteration and every ProximalOptions "profile" which predicate proposed a
#    stop (x, objective relative, objective one-ulp, gradient mapping), whether the stationarity
#    check accepted it, and where that profile stops. The trajectory does not depend on the stop
#    options (the options do not enter update_state!), so one run serves all profiles; the probe
#    checks this by running the library's own loop (_solve_gradient!) per named profile and
#    comparing iterations, flags and the returned iterate bit by bit (field `xcheck`).
#  * evaluates, at EVERY accepted iterate, the independent relative duality gap and the KKT
#    residual of the rounded data in Float64 (harness certificate), and optionally in BigFloat.
#  * runs Float32 APG and Float64 PGD controls through the library only.
#
#   julia --project=<env> probe320.jl <mode> <outprefix> <draws a:b> [designs,comma separated]
# modes: repro (the three #320 cases, per-iteration TSV), matrix (harness designs), adverse (the
# preregistered adverse set), both = matrix + adverse
# env A320_HARNESS = directory with problems.jl, certificates.jl, cases.jl
# env A320_BIG=1   = BigFloat(256) gap/KKT at the returned and first-proposal iterates
using Pkg, TOML, SHA, Printf, Statistics, LinearAlgebra, InteractiveUtils
import ProximalSolvers, ProximalBase
mode, outprefix, draws = ARGS[1], ARGS[2], ARGS[3]
only_designs = length(ARGS) >= 4 ? split(ARGS[4], ',') : String[]
a_, b_ = parse.(Int, split(draws, ':'))
harness = get(ENV, "A320_HARNESS", joinpath(@__DIR__, "..", "..", "benchmark"))
BIG = get(ENV, "A320_BIG", "0") == "1"
const KEXTRA = parse(Int, get(ENV, "A320_KEXTRA", "20"))
DETAIL = get(ENV, "A320_DETAIL", "1") == "1"
BLAS.set_num_threads(1)
Threads.nthreads() == 1 || error("one Julia thread required")

const H = Module(:Harness320)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(harness, f))
end
const PS = ProximalSolvers
const PB = ProximalBase
mkpath(dirname(outprefix))

# ---- provenance -------------------------------------------------------------------------
function provenance(io)
  println(io, "julia ", VERSION, "  cpu_name ", Sys.CPU_NAME, "  model ", Sys.cpu_info()[1].model)
  println(io, "threads ", Threads.nthreads(), "  blas_threads ", BLAS.get_num_threads(), "  ", BLAS.get_config())
  println(io, "PS path ", pkgdir(PS), "  version ", pkgversion(PS))
  io2 = IOBuffer()
  for fn in sort(vcat(joinpath(pkgdir(PS), "Project.toml"), [joinpath(d, n) for (d, _, ns) in walkdir(joinpath(pkgdir(PS), "src")) for n in ns if endswith(n, ".jl")]))
    write(io2, relpath(fn, pkgdir(PS)), '\0', read(fn), '\0')
  end
  println(io, "PS fingerprint(sha1 of Project.toml+src, run.jl scheme) ", bytes2hex(sha1(take!(io2))))
  println(io, "PB path ", pkgdir(PB), "  version ", pkgversion(PB))
  project = Base.active_project(); manifest = Base.project_file_manifest_path(project)
  m = TOML.parsefile(manifest); e = only(get(m, "deps", m)["ProximalBase"])
  println(io, "PB manifest ", manifest, "  repo-rev ", get(e, "repo-rev", ""), "  git-tree-sha1 ", get(e, "git-tree-sha1", ""))
  println(io, "project ", project)
  println(io, "harness ", harness)
  for f in ("problems.jl", "certificates.jl", "cases.jl")
    println(io, "  harness ", f, " sha1 ", bytes2hex(sha1(read(joinpath(harness, f)))))
  end
  println(io, "stationarity method 4-arg: ", hasmethod(PS._stationary!, Tuple{PS.ProximalGradientDescentState{Float32}, Any, Any, PS.ProximalOptions}))
  InteractiveUtils.versioninfo(io)
end
open(io -> provenance(io), outprefix * "-provenance.txt", "w")

# ---- independent certificates -----------------------------------------------------------
function indep(ex, x)
  β = Float64.(x)
  c = H.certify(ex, β)
  r = ex.y - ex.X * β
  grad = -ex.s .* (ex.X' * r)
  S = max(ex.λ, ex.s * maximum(abs, ex.X' * ex.y))
  G = 0.0
  @inbounds for j in eachindex(β)
    v = β[j] == 0 ? max(abs(grad[j]) - ex.λ, 0.0) : abs(grad[j] + ex.λ * sign(β[j]))
    G = max(G, v)
  end
  (; gap = c.status == :ok ? c.value : NaN, status = c.status, P = c.primal, D = c.dual, kkt = G / S, S, grad)
end

# gap in BigFloat(256) of the same lasso certificate (dual point θ = s r scaled into the dual ball)
function gap_big(ex, x)
  setprecision(BigFloat, 256) do
    X, y = BigFloat.(ex.X), BigFloat.(ex.y)
    s, λ = BigFloat(ex.s), BigFloat(ex.λ)
    β = BigFloat.(Float64.(x))
    r = y - X * β
    P = s * sum(abs2, r) / 2 + λ * sum(abs, β)
    θ = s .* r
    z = X' * θ
    t = BigFloat(1)
    for j in eachindex(z)
      abs(z[j]) > 0 && (t = min(t, λ / abs(z[j])))
    end
    θ .*= t
    D = sum(y .* θ) - sum(abs2, θ) / (2s)
    grad = -s .* (X' * r)
    S = max(λ, s * maximum(abs, X' * y))
    G = BigFloat(0)
    for j in eachindex(β)
      v = iszero(β[j]) ? max(abs(grad[j]) - λ, BigFloat(0)) : abs(grad[j] + λ * sign(β[j]))
      G = max(G, v)
    end
    (Float64((P - D) / P), Float64(G / S), Float64(P))
  end
end

# ---- profiles ---------------------------------------------------------------------------
target(T) = H.CORE_TARGETS[T]
function profiles(T)
  # named profiles (each is also run through the library for the cross-check) and sweep profiles
  # (trajectory-derived only): ftol = 0, xtol = 1e-14, allow_f_increases, gradtol = g.
  named = [
    ("D", PS.ProximalOptions()),
    ("H", H.benchmark_options(; residual = true)),
    ("S", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)),
    ("A", H.accuracy_options()),
    ("Q", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = target(T) / 100, allow_f_increases = true))]
  sweep = [("G$(e)", PS.ProximalOptions(maxiter = 10_000, ftol = 0, xtol = 1e-14, gradtol = 10.0^(-e), allow_f_increases = true)) for e in (5, 6, 8)]
  named, sweep
end

# ---- trajectory --------------------------------------------------------------------------
mutable struct Prof
  name::String
  o::PS.ProximalOptions
  named::Bool
  done::Bool
  stop::Int
  conv::Bool; xc::Bool; fc::Bool; gc::Bool; incr::Bool; stag::Bool; itlim::Bool
  first_prop::Int; first_set::String; first_gate::Bool; nprop::Int; ngaterej::Int
  x::Vector
end
Prof(name, o, named, T, p) = Prof(name, o, named, false, 0, false, false, false, false, false, false, false, 0, "", false, 0, 0, zeros(T, p))

stationary(state, f, g, o) = hasmethod(PS._stationary!, Tuple{typeof(state), typeof(f), typeof(g), typeof(o)}) ?
  PS._stationary!(state, f, g, o) : PS._stationary!(state, g, o)

function trajectory(a, ex, f, g, T, profs; detail = false, kmax = 10_000)
  method = PS.ProximalGradientDescent()
  o0 = PS.ProximalOptions(maxiter = kmax, ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
  x = copy(a.start)
  st = PS.initial_state(method, o0, f, g, x)
  p = length(x)
  Lexact = ex.s * opnorm(ex.X)^2
  rows = NamedTuple[]           # per-iteration detail (all iterations)
  gaps = Float64[]; kkts = Float64[]
  ind0 = indep(ex, x)
  push!(gaps, ind0.gap); push!(kkts, ind0.kkt)
  gap_at = Dict{Int, Float64}(); kkt_at = Dict{Int, Float64}()
  L1 = T(NaN); Lmax = zero(T); mode_switch = 0; trials_total = 0
  prev_prox = 0; prev_ver = 0
  k = 0
  tgt = target(T)
  kstar = ind0.gap <= tgt ? 0 : -1
  gmin = ind0.gap; gmin_k = 0
  events = NamedTuple[]
  Tp = T
  kextra = 0
  while k < kmax && (!all(pf -> pf.done, profs) || kextra < KEXTRA)
    all(pf -> pf.done, profs) && (kextra += 1)
    k += 1
    PS.update_state!(f, g, st, method)
    isfinite(st.f_x + st.g_x) || error("nonfinite objective")
    trials = st.prox_calls - prev_prox; prev_prox = st.prox_calls
    vers = st.verifications - prev_ver; prev_ver = st.verifications
    norm_x = PS._state_norm(st, st.x); norm_dx = PS._state_norm(st, st.delta_x)
    fval = st.f_x + st.g_x; fval_prev = st.f_x_previous + st.g_x_previous
    fres = PS.f_residual(fval, fval_prev, 0.0)
    ulp = abs(fval - fval_prev) < eps(abs(fval) + abs(fval_prev))
    r = PS.g_residual(st)
    st.max_residual = max(st.max_residual, r)
    subgrad = PS._maxabs_axpy(st.L, st.delta_x, st.grad_f_x_previous)
    N = max(PS._norm_inf(st.grad_f_x), subgrad)
    rho = st.L * eps(T) * PS._norm_inf(st.x)
    unchanged = iszero(norm_dx) && PS._unchanged(st.x, st.x_previous)
    incr = fval > fval_prev
    ind = indep(ex, st.x)
    push!(gaps, ind.gap); push!(kkts, ind.kkt)
    if kstar < 0 && ind.gap <= tgt; kstar = k; end
    if ind.gap < gmin; gmin = ind.gap; gmin_k = k; end
    isnan(L1) && (L1 = st.L)
    Lmax = max(Lmax, st.L)
    (mode_switch == 0 && !st.backtrack_simple) && (mode_switch = k)
    # solver gradient versus independent gradient at x (normalized by S)
    gerr = maximum(abs.(Float64.(st.grad_f_x) .- ind.grad)) / ind.S
    # widened residual of the stationarity check: G of the solver's own gradient, in Float64
    Gs = 0.0; λT = Float64(T(g.λ0))
    @inbounds for j in 1:p
      gj = Float64(st.grad_f_x[j]); xj = Float64(st.x[j])
      v = xj == 0 ? max(abs(gj) - λT, 0.0) : abs(gj + λT * sign(xj))
      Gs = max(Gs, v)
    end
    Sg = max(λT, Float64(st.λmax < 0 ? PS._lambda_max!(st) : st.λmax))
    Gs_rel = Gs / Sg
    for pf in profs
      pf.done && continue
      o = pf.o
      stalled = iszero(o.ftol) && unchanged
      xraw = !stalled && norm_dx < o.xtol * max(norm_x, 1.0)
      frel = !iszero(o.ftol) && fres < o.ftol
      fulp = !iszero(o.ftol) && ulp
      graw = PS._gradient_test(st, o, r, N) && !stalled
      prop = xraw || frel || fulp || graw
      gate = false
      if prop
        gate = stationary(st, f, g, o)
        pf.nprop += 1
        gate || (pf.ngaterej += 1)
        if pf.first_prop == 0
          pf.first_prop = k
          pf.first_set = string(xraw ? "x" : "", frel ? "f" : "", fulp ? "u" : "", graw ? "g" : "")
          pf.first_gate = gate
        end
        if pf.name in ("H", "Q", "D") && length(events) < 400
          push!(events, (; prof = pf.name, k, set = string(xraw ? "x" : "", frel ? "f" : "", fulp ? "u" : "", graw ? "g" : ""),
                           gate, Gs_rel, gap = ind.gap, kkt = ind.kkt, fval = Float64(fval), fprev = Float64(fval_prev)))
        end
      end
      conv = prop && gate
      stag = PS._stagnated(st, o)
      inc_stop = incr && !o.allow_f_increases
      stop = conv || inc_stop || stag || k >= o.maxiter
      if stop
        pf.done = true; pf.stop = k; pf.conv = conv
        pf.xc = conv && xraw; pf.fc = conv && (frel || fulp); pf.gc = conv && graw
        pf.incr = incr; pf.stag = stag; pf.itlim = k == o.maxiter
        copyto!(pf.x, st.x)
        gap_at[k] = ind.gap; kkt_at[k] = ind.kkt
      end
    end
    if detail
      # duality gap computable from the solver's own data (image z = X x, y, gradient): dual point
      # theta = s (y - z) scaled by min(1, lambda / ||grad||_inf); once accumulated in Float64 from the
      # T entries, once entirely in T
      gc64 = begin
        sT = Float64(a.s); lam = Float64(g.λ0)
        yy = a.y; zz = st.z_x
        sr2 = 0.0; yth = 0.0; ab = 0.0
        @inbounds for i in eachindex(yy)
          ri = Float64(yy[i]) - Float64(zz[i]); th = sT * ri
          sr2 += th * th; yth += Float64(yy[i]) * th
        end
        @inbounds for j in 1:p; ab += abs(Float64(st.x[j])); end
        gi = Float64(PS._norm_inf(st.grad_f_x)); t = gi > lam ? lam / gi : 1.0
        Pp = 0.5 * sT * (sr2 / (sT * sT)) + lam * ab
        Dd = t * yth - t * t * sr2 / (2 * sT)
        (Pp - Dd) / Pp
      end
      gc32 = begin
        sT = a.s; lam = T(g.λ0); yy = a.y; zz = st.z_x
        sr2 = zero(T); yth = zero(T); ab = zero(T)
        @inbounds for i in eachindex(yy)
          th = sT * (yy[i] - zz[i]); sr2 += th * th; yth += yy[i] * th
        end
        @inbounds for j in 1:p; ab += abs(st.x[j]); end
        gi = PS._norm_inf(st.grad_f_x); t = gi > lam ? lam / gi : one(T)
        Pp = sT * (sr2 / (sT * sT)) / 2 + lam * ab
        Dd = t * yth - t * t * sr2 / (2 * sT)
        Float64((Pp - Dd) / Pp)
      end
      stagc = PS._stagnated(st, o0)
      push!(rows, (; k, F = Float64(fval), fres, ulp, dxx = Float64(norm_dx / norm_x), L = Float64(st.L), simple = st.backtrack_simple,
                    stagc, gapc64 = gc64, gapc32 = gc32,
                    trials, vers, r = Float64(r), m = Float64(st.max_residual), N = Float64(N), rho = Float64(rho), unchanged, incr,
                    Gs_rel, gerr, gap = ind.gap, kkt = ind.kkt, P = ind.P))
    end
  end
  (; st, k, gaps, kkts, kstar, gmin, gmin_k, L1, Lmax, Lexact, mode_switch, rows, events, gap_at, kkt_at)
end

# library solve of one named profile (state-level loop, as in #314's probe) for the cross-check
function lib_solve(a, f, g, o, solver, T)
  method = solver == "apg" ? PS.AccProxGradDescent() : PS.ProximalGradientDescent()
  x = copy(a.start)
  st = PS.initial_state(method, o, f, g, x)
  res = PS._solve_gradient!(st, f, g, method, o, time())
  # public API gives the same result; check it once
  x2 = copy(a.start); r2 = PS.solve!(x2, f, g, method, o)
  (x2 == x && r2.iterations == res.iterations && r2.converged == res.converged) || error("solve! differs from the state-level solve")
  (; st, res, x)
end

termination(r, o) = r.converged ? join([t for (t, b) in (("x", r.x_converged), ("f", r.f_converged), ("g", r.grad_converged)) if b], "+") :
  r.stagnated ? "stagnated" : r.call_limit_reached ? "call_limit" : r.iteration_converged ? "maxiter" :
  (r.f_increased && !o.allow_f_increases) ? "f_increased" : "other"

tsv(io, vals...) = println(io, join((v isa AbstractFloat ? repr(v) : replace(string(v), '\t' => ' ', '\n' => ' ') for v in vals), '\t'))

# ---- problem sets -----------------------------------------------------------------------
illcond(a, fraction) = begin
  p = size(a.X, 2)
  X = a.X .* (10.0 .^ (-2 .* (0:p-1) ./ (p - 1)))'
  merge(a, (; X, λ = fraction * H.lambda_max(X, a.y; s = a.s)))
end
harness_designs = [
  ("lasso", r -> H.regression_problem(r, "core/lasso"), false),
  ("lasso-B", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), false),
  ("lasso-B-warm", r -> H.regression_problem(r, "extended/design-B"; n = 240, p = 160, design = :B), true),
  ("lasso-C", r -> H.regression_problem(r, "extended/design-C"; n = 800, p = 120, design = :C), false),
  ("lasso-D", r -> H.regression_problem(r, "extended/design-D"; n = 180, p = 600, design = :D), false)]
# The preregistered adverse set (fixed before any matrix run; see report): keys issue320/adv/*
adverse_designs = [
  ("adv-cor-low-cold", r -> H.regression_problem(r, "issue320/adv/cor"; n = 240, p = 160, design = :B, fraction = 0.02), false),
  ("adv-cor-low-warm", r -> H.regression_problem(r, "issue320/adv/cor"; n = 240, p = 160, design = :B, fraction = 0.02), true),
  ("adv-equi-low-cold", r -> H.regression_problem(r, "issue320/adv/equi"; n = 240, p = 160, design = :E, fraction = 0.02), false),
  ("adv-ill-mid-cold", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.15), false),
  ("adv-ill-low-cold", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.02), false),
  ("adv-ill-low-warm", r -> illcond(H.regression_problem(r, "issue320/adv/ill"; n = 240, p = 160, design = :A), 0.02), true),
  ("adv-wide-low-cold", r -> H.regression_problem(r, "issue320/adv/wide"; n = 180, p = 600, design = :A, fraction = 0.02), false)]
repro_cases = [("lasso-C", 7), ("lasso-D", 7), ("lasso-D", 9)]

items = Tuple{String, Function, Bool, Int}[]
if mode == "repro"
  for (d, r) in repro_cases
    des = only(filter(x -> x[1] == d, harness_designs))
    push!(items, (d, des[2], des[3], r))
  end
else
  sets = mode == "matrix" ? harness_designs : mode == "adverse" ? adverse_designs : vcat(harness_designs, adverse_designs)
  for (d, mk, w) in sets, r in a_:b_
    isempty(only_designs) || d in only_designs || continue
    push!(items, (d, mk, w, r))
  end
end

header = ("julia", "cpu", "mode", "design", "draw", "T", "solver", "profile", "kind", "data_hash", "target",
  "converged", "x_conv", "f_conv", "g_conv", "f_increased", "stagnated", "iter_limit", "call_limit", "termination",
  "iterations", "f_calls", "grad_calls", "prox_calls", "backtracks", "verifications", "fallbacks",
  "gap", "kkt_rel", "gap_big", "kkt_big", "status", "false_success", "missed", "xcheck",
  "first_prop_iter", "first_prop_set", "first_prop_gate", "n_prop", "n_gate_reject",
  "kstar", "gap_min", "gap_min_iter", "iters_after_kstar",
  "L1", "Lmax", "Lfinal", "Lexact", "Lfinal_over_exact", "mode_switch_iter", "rejected_trials")
sio = open(outprefix * "-summary.tsv", "w"); tsv(sio, header...)
eio = open(outprefix * "-events.tsv", "w"); tsv(eio, "julia", "design", "draw", "T", "profile", "iter", "set", "gate_accepted", "Gs_rel", "gap", "kkt", "F", "Fprev")
cpu = Sys.cpu_info()[1].model
println(stderr, "probe320 ", mode, " items ", length(items), " julia ", VERSION, " ", Sys.CPU_NAME)
mkpath(outprefix * "-iters")

for (idx, (design, make, warm, draw)) in enumerate(items)
  built = make(draw)
  for T in (Float32, Float64)
    a = H.core_problem(built, T; warm)
    dh = H.data_hash(a)
    ex = H.exact_problem(a)
    f, g = H.benchmark_model(a)
    named, sweep = profiles(T)
    tgt = target(T)
    # --- trajectory (PGD) with profiles
    profs = [Prof(n, o, true, T, length(a.start)) for (n, o) in named]
    append!(profs, [Prof(n, o, false, T, length(a.start)) for (n, o) in sweep])
    tr = trajectory(a, ex, f, g, T, profs; detail = DETAIL)
    for pf in profs
      pf.name in ("H", "Q", "D", "A", "S") && T == Float32 && mode != "repro" && nothing
    end
    for ev in tr.events
      tsv(eio, VERSION, design, draw, T, ev.prof, ev.k, ev.set, ev.gate, ev.Gs_rel, ev.gap, ev.kkt, ev.fval, ev.fprev)
    end
    for pf in profs
      kind = pf.named ? "pgd-lib+traj" : "pgd-traj"
      xcheck = "n/a"
      if pf.named
        lib = lib_solve(a, f, g, pf.o, "pgd", T)
        r, st = lib.res, lib.st
        ok = r.iterations == pf.stop && r.converged == pf.conv && r.x_converged == pf.xc && r.f_converged == pf.fc &&
             r.grad_converged == pf.gc && r.stagnated == pf.stag && r.f_increased == pf.incr && r.iteration_converged == pf.itlim &&
             lib.x == pf.x
        xcheck = ok ? "ok" : "MISMATCH"
        ind = indep(ex, lib.x)
        gb = BIG ? gap_big(ex, lib.x) : (NaN, NaN, NaN)
        conv = r.converged
        gap_ = ind.gap
        status = ind.status == :ok ? (ind.gap <= tgt ? "ok" : "target_missed") : string(ind.status)
        tsv(sio, VERSION, cpu, mode, design, draw, T, "pgd", pf.name, kind, dh, tgt,
            conv, r.x_converged, r.f_converged, r.grad_converged, r.f_increased, r.stagnated, r.iteration_converged, r.call_limit_reached,
            termination(r, pf.o), r.iterations, r.f_calls, r.grad_calls, r.prox_calls, r.backtrack_steps, st.verifications, "",
            gap_, ind.kkt, gb[1], gb[2], status, conv && ind.gap > tgt, ind.gap > tgt, xcheck,
            pf.first_prop, pf.first_set, pf.first_gate, pf.nprop, pf.ngaterej,
            tr.kstar, tr.gmin, tr.gmin_k, tr.kstar >= 0 ? r.iterations - tr.kstar : "",
            tr.L1, tr.Lmax, st.L, tr.Lexact, Float64(st.L) / tr.Lexact, tr.mode_switch, r.prox_calls - r.iterations)
      else
        # sweep profile: derive from the trajectory only
        gap_ = tr.gap_at[pf.stop]; kk = tr.kkt_at[pf.stop]
        status = isnan(gap_) ? "uncertifiable" : (gap_ <= tgt ? "ok" : "target_missed")
        term = pf.conv ? join([t for (t, b) in (("x", pf.xc), ("f", pf.fc), ("g", pf.gc)) if b], "+") : pf.stag ? "stagnated" : pf.itlim ? "maxiter" : "other"
        tsv(sio, VERSION, cpu, mode, design, draw, T, "pgd", pf.name, kind, dh, tgt,
            pf.conv, pf.xc, pf.fc, pf.gc, pf.incr, pf.stag, pf.itlim, false, term, pf.stop, "", "", "", "", "", "",
            gap_, kk, NaN, NaN, status, pf.conv && gap_ > tgt, gap_ > tgt, xcheck,
            pf.first_prop, pf.first_set, pf.first_gate, pf.nprop, pf.ngaterej,
            tr.kstar, tr.gmin, tr.gmin_k, tr.kstar >= 0 ? pf.stop - tr.kstar : "", tr.L1, tr.Lmax, "", tr.Lexact, "", tr.mode_switch, "")
      end
    end
    # --- first-proposal point certified in BigFloat (H profile) for the widened comparison
    if BIG
      pfH = only(filter(p -> p.name == "H", profs))
      if pfH.first_prop > 0
        # re-run to the first proposal to get that iterate: the trajectory kept x only at stops,
        # so use the library with maxiter = first proposal (iterates do not depend on options)
        oH = PS.ProximalOptions(maxiter = max(pfH.first_prop, 2), ftol = 0, xtol = 1e-300, gradtol = 0, allow_f_increases = true)
        lib = lib_solve(a, f, g, oH, "pgd", T)
        if lib.res.iterations == pfH.first_prop
          gb = gap_big(ex, lib.x); ind = indep(ex, lib.x)
          tsv(eio, VERSION, design, draw, T, "H-first-prop-big", pfH.first_prop, "", "", "", ind.gap, ind.kkt, gb[1], gb[2])
        end
      end
    end
    # --- per-iteration detail for the repro cases
    if DETAIL
      open(outprefix * "-iters/$(design)-draw$(draw)-$(T).tsv", "w") do io
        names = keys(tr.rows[1])
        tsv(io, names...)
        for rw in tr.rows
          tsv(io, values(rw)...)
        end
      end
    end
    # --- controls through the library: Float32 APG (and Float64 PGD is covered above as T = Float64)
    if T == Float32
      for (n, o) in named
        lib = lib_solve(a, f, g, o, "apg", T)
        r, st = lib.res, lib.st
        ind = indep(ex, lib.x)
        gb = BIG ? gap_big(ex, lib.x) : (NaN, NaN, NaN)
        status = ind.status == :ok ? (ind.gap <= tgt ? "ok" : "target_missed") : string(ind.status)
        tsv(sio, VERSION, cpu, mode, design, draw, T, "apg", n, "apg-lib", dh, tgt,
            r.converged, r.x_converged, r.f_converged, r.grad_converged, r.f_increased, r.stagnated, r.iteration_converged, r.call_limit_reached,
            termination(r, o), r.iterations, r.f_calls, r.grad_calls, r.prox_calls, r.backtrack_steps, "", st.fallbacks,
            ind.gap, ind.kkt, gb[1], gb[2], status, r.converged && ind.gap > tgt, ind.gap > tgt, "n/a",
            "", "", "", "", "", "", "", "", "", "", "", "", tr.Lexact, "", "", "")
      end
    end
    flush(sio); flush(eio)
  end
  println(stderr, "done ", design, " draw ", draw, " (", idx, "/", length(items), ")")
end
close(sio); close(eio)
println(stderr, "probe320 finished")
