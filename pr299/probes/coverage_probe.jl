# coverage_probe.jl: path-coverage probe at the base tree (issue #279, W2).
#   parent mode (no args): header, then two child processes of this same script:
#     reach <dir>  - instrumented copy of the branch-bearing functions (instrument.jl); reached flags per scenario/path
#                    from solve-level and update-level runs, with the update index k* of the first hit
#     alloc <dir>  - clean (un-instrumented) code: warmed @allocated of solve! (or _solve_gradient!) and of one
#                    update_state! at k*, plus the fingerprint signature of every scenario (instrumented/clean check)
#   and prints the path table.
include(joinpath(@__DIR__, "common.jl"))
const MODE = isempty(ARGS) ? "parent" : ARGS[1]
MODE == "parent" && ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
TREE_DIR_REF[] = pkgdir(ProximalSolvers)
include(joinpath(@__DIR__, "corpus.jl"))
include(joinpath(@__DIR__, "runner.jl"))
MODE == "reach" && include(joinpath(@__DIR__, "instrument.jl"))

# id, label, location in the base tree (782b74c)
const PATHS = [
  (:pgd_ls_Float64_data_Float32, "PGD default BackTracking() (Float64 settings) with Float32 data", "proximal_gradient_descent.jl:125; line_searches.jl:81,110"),
  (:pgd_ls_Float32_data_Float32, "PGD BackTracking(0.9f0, 0.5f0, Inf32) with Float32 data", "proximal_gradient_descent.jl:125; line_searches.jl:81,110"),
  (:pgd_exit_lexact, "PGD finite Lexact: exit through state.L >= ls.Lexact (local_l > L)", "line_searches.jl:109"),
  (:pgd_mode_switch, "PGD simple-to-gradient mode switch", "line_searches.jl:93-98"),
  (:pgd_gradient_mode_trial, "PGD trial in gradient mode", "line_searches.jl:99-105"),
  (:pgd_zero_step_simple, "PGD zero step, simple mode", "line_searches.jl:64-73"),
  (:pgd_zero_step_gradient, "PGD zero step, gradient mode (refresh of grad_f_x)", "line_searches.jl:67-72"),
  (:pgd_nonfinite_trial, "PGD nonfinite trial value", "line_searches.jl:79-83"),
  (:next_curvature_error, "next_curvature error (L/beta not a finite increase)", "line_searches.jl:48-52"),
  (:eng_rollback, "rollback of x to x_previous in solve engine", "solve.jl:88-96"),
  (:apg_accept_cached, "APG accept from the cached image difference", "image_models.jl:259"),
  (:apg_early_reject, "APG early reject from the cached image difference", "image_models.jl:261"),
  (:apg_fresh_product, "APG fresh product X d formed", "image_models.jl:264"),
  (:apg_fresh_accept, "APG decision after the fresh product: accept", "image_models.jl:264-269"),
  (:apg_fresh_reject, "APG decision after the fresh product: reject", "image_models.jl:264-269"),
  (:apg_W_nothing, "APG W === nothing (nonfinite fresh product)", "image_models.jl:266"),
  (:apg_cached_norm_nothing, "APG N === nothing (cached difference norm unusable, falls to fresh product)", "image_models.jl:255-256"),
  (:apg_norm_nothing, "APG normx or D === nothing", "accelerated_proximal_gradient_descent.jl:232"),
  (:apg_zero_step, "APG iszero(D.s): x == y entrywise, zero step", "accelerated_proximal_gradient_descent.jl:233-238"),
  (:apg_onepass_to_twopass, "APG _se_norm_onepass falls back to the two-pass norm", "image_models.jl:125-128"),
  (:apg_diffonepass_to_twopass, "APG _se_norm_diff_onepass falls back to the two-pass norm", "image_models.jl:129-132"),
  (:apg_frobenius_scaled, "APG _frobenius_upper scaled branch", "image_models.jl:156"),
  (Symbol("apg_alpha_", typeof(2)), "APG loss scale Int through _significand_exponent(::Real)", "image_models.jl:175"),
  (Symbol("apg_alpha_", typeof(1 // 2)), "APG loss scale Rational through _significand_exponent(::Real)", "image_models.jl:175"),
  (Symbol("apg_alpha_", typeof(BigFloat(0.5))), "APG loss scale BigFloat through _significand_exponent(::Real)", "image_models.jl:175"),
  (Symbol("apg_alpha_", typeof(true)), "APG raw LeastSquaresLoss (scale true::Bool) through _significand_exponent(::Real)", "image_models.jl:10,175"),
  (Symbol("apg_alpha_", typeof(π)), "APG loss scale Irrational through _significand_exponent(::Real)", "image_models.jl:175"),
  (:apg_fresh_only, "APG fresh_only = true (state built with PS.initial_state)", "image_models.jl:254"),
  (:apg_restart, "APG restart (state.restarts > 0)", "accelerated_proximal_gradient_descent.jl:189-195"),
  (:apg_nonfinite_y, "APG nonfinite y (value or gradient at extrapolated point)", "accelerated_proximal_gradient_descent.jl:215-218"),
  (:apg_overflow_rollback, "APG curvature overflow: next_curvature error and rollback", "accelerated_proximal_gradient_descent.jl:253"),
  (:eng_store_trace, "engine store_trace", "utils.jl:15"),
  (:eng_show_trace, "engine show_trace", "utils.jl:16"),
  (:eng_extended_metadata, "engine extended_trace metadata (extended alone and with others)", "utils.jl:9-12"),
  (:eng_callback_called, "engine callback called", "utils.jl:17-18"),
  (:eng_callback_stop, "engine stop by callback", "solve.jl:103"),
  (:eng_time_limit_stop, "engine time_limit stop", "solve.jl:106"),
  (:eng_f_limit, "engine f_calls_limit stop", "solve.jl:107"),
  (:eng_grad_limit, "engine grad_calls_limit stop", "solve.jl:108"),
  (:eng_prox_limit, "engine prox_calls_limit stop", "solve.jl:109"),
  (:eng_f_increase_allowed, "engine allow_f_increases = true with an objective increase", "solve.jl:111-115"),
  (:eng_f_increase_stop, "engine stop at an objective increase (allow_f_increases = false)", "solve.jl:111-115"),
  (:refuse_dimension, "refusal: dimension mismatch", "solve.jl (_check_data)"),
  (:refuse_empty, "refusal: empty X", "solve.jl (_check_data)"),
  (:refuse_nonfinite, "refusal: nonfinite data or penalty", "solve.jl (_check_problem, _check_data)"),
  (:refuse_keywords, "refusal: unsupported solve! keywords", "solve.jl (_check_keywords)"),
  (:refuse_type, "refusal: unsupported types/losses", "solve.jl (_check_problem, _check_data)"),
  (:refuse_alias, "refusal: x aliases X or y", "solve.jl (_check_data)"),
  (:refuse_scale, "refusal: unusable loss scale", "solve.jl (_scalar_parameter)"),
  (:refuse_options, "refusal: ProximalOptions validation", "types.jl (ProximalOptions)"),
  (:refuse_method, "refusal: solver/line-search settings", "solver constructors, _check_method"),
  (:refuse_bound_size, "refusal: APG _check_bound_size (Float32, p = 2.1e6)", "accelerated_proximal_gradient_descent.jl:268-273"),
  # ---- #270 (ftol = 0), master 3408e1f; group F scenarios (corpus_f.jl) ----
  (:eng_f0_objective_off, "ftol = 0: objective test off (convergence_assessment evaluated with ftol = 0)", "utils.jl:48,54-60"),
  (:eng_f0_normdx_zero, "ftol = 0 and norm(delta_x) == 0 (the elementwise comparison runs)", "utils.jl:48"),
  (:eng_f0_stall, "ftol = 0 stall: norm(delta_x) == 0 and _unchanged(x, x_previous)", "utils.jl:48"),
  (:eng_f0_stall_blocks_x, "stall blocks the x test (it would have held)", "utils.jl:50"),
  (:eng_f0_stall_blocks_grad, "stall blocks the gradient test (gradient_converged! true, evaluated, result masked)", "utils.jl:68"),
  (:eng_f0_normdx_zero_not_unchanged, "ftol = 0, norm(delta_x) == 0 but x != x_previous: not a stall", "utils.jl:48"),
  (:eng_f0_stall_until_maxiter, "stall solve ends at maxiter: iteration_converged && !converged", "solve.jl (loop), utils.jl:48"),
  (:eng_ftol_pos_unchanged_passes_x, "control: ftol > 0, unchanged iterate passes the x test", "utils.jl:50-52"),
  (:eng_fres_ftol_positive, "f_residual, ftol > 0 formula", "utils.jl:28"),
  (:eng_fres_both_zero, "f_residual, ftol = 0, F = F' = 0 (explicit 0.0)", "utils.jl:29-30"),
  (:eng_fres_zero_change_nonzero_F, "f_residual, ftol = 0, F = F' != 0 (0.0)", "utils.jl:30"),
  (:eng_fres_F0_Fprev_nonzero_inf, "f_residual, ftol = 0, F = 0 != F' (Inf)", "utils.jl:30"),
  (:eng_fres_ratio, "f_residual, ftol = 0, |F - F'| / |F| with F != 0 and F != F'", "utils.jl:30"),
  (:eng_ftol_negzero_stored_plus0, "ProximalOptions: a -0.0 spelling of ftol is stored as +0.0", "types.jl:122"),
  (:refuse_ftol_rounds_to_zero, "refusal: positive ftol that rounds to 0 in Float64 (keyword and positional)", "types.jl:115"),
  (:refuse_ftol_nonneg, "refusal: negative, NaN or infinite ftol", "types.jl:112"),
]

const SCENARIOS = Scn[s for s in vcat(w2_scenarios(), refusal_scenarios(), filter(s -> !isempty(s.paths), f0_scenarios()))]

# ---------------------------------------------------------------- reach child
function exc_of(rec::String)
  m = match(r"^EXC (\S+) (.*)$"m, rec)
  m === nothing && (m = match(r"^BUILD_THROW (\S+) (.*)$"m, rec))
  m === nothing ? nothing : (String(m.captures[1]), String(m.captures[2]))
end

function reach_one!(tsv::IO, sc::Scn)
  tname = string(sc.T)
  hits_reset!()
  a = try sc.make() catch; nothing end
  if sc.solver === :pgd && a !== nothing && a.method isa ProximalGradientDescent
    __hit(Symbol("pgd_ls_", typeof(a.method.ls.α), "_data_", sc.T))
  end
  rec = case_record(sc)
  sig = sha1hex(rec)
  exc = exc_of(rec)
  outcome = exc === nothing ? "ok" : "throw:" * exc[1] * ":" * first(exc[2], 70)
  if exc !== nothing && occursin("cannot increase finitely", exc[2]) && sc.solver === :apg
    __hit(:apg_overflow_rollback)
  end
  # solve-level facts of group F that no counter sees: a stall that lasts to maxiter, a -0.0 spelling stored as +0.0
  if get(HITS, :eng_f0_stall, 0) > 0 && occursin("\nR iteration_converged Bool true", rec) && occursin("\nR converged Bool false", rec)
    __hit(:eng_f0_stall_until_maxiter)
  end
  if a !== nothing && occursin("neg", sc.name) && a.opts isa ProximalOptions && a.opts.ftol === 0.0
    __hit(:eng_ftol_negzero_stored_plus0)
  end
  matched = false
  if sc.expect !== nothing && exc !== nothing
    et, rx = sc.expect
    matched = occursin(rx, exc[2]) && (et === Exception || exc[1] == string(et))
  end
  h1 = hits_snapshot()
  # update-level replay
  kstar = Dict{Symbol,Int}()
  h2 = Dict{Symbol,Int}()
  upd_outcome = "skipped"
  if sc.maxupd > 0 && a !== nothing
    hits_reset!()
    try
      a2 = sc.make()
      x = a2.alias ? a2.x0 : copy(a2.x0)
      st = PS.initial_state(a2.method, a2.opts, a2.f, a2.g, x)
      a2.prep === nothing || a2.prep(st)
      hits_reset!()
      upd_outcome = "ran"
      for k in 1:sc.maxupd
        before = hits_snapshot()
        r0 = hasproperty(st, :restarts) ? st.restarts : 0
        threw = false
        try
          PS.update_state!(a2.f, a2.g, st, a2.method)
        catch
          threw = true
        end
        (hasproperty(st, :restarts) && st.restarts > r0) && __hit(:apg_restart)
        after = hits_snapshot()
        for (key, c) in after
          if c > get(before, key, 0) && !haskey(kstar, key)
            kstar[key] = k
          end
        end
        if threw
          upd_outcome = "threw@$k"
          break
        end
        all(p -> haskey(kstar, p), sc.paths) && !isempty(sc.paths) && break
      end
      h2 = hits_snapshot()
    catch e
      upd_outcome = "error:" * sprint(showerror, e)[1:min(end, 120)]
    end
  end
  fmt(d) = join(("$(k)=$(v)" for (k, v) in sort!(collect(d); by = first)), ";")
  println(tsv, "S\t", sc.name, "\t", tname, "\t", sig, "\t", outcome, "\t", upd_outcome)
  println(tsv, "H\t", sc.name, "\t", tname, "\tsolve:", fmt(h1), "\tupd:", fmt(h2))
  seen = String[]
  for p in sc.paths
    reached = get(h1, p, 0) > 0 || get(h2, p, 0) > 0 || (matched && p in sc.paths)
    println(tsv, "P\t", sc.name, "\t", tname, "\t", p, "\t", reached ? 1 : 0, "\t", get(kstar, p, 0))
    push!(seen, string(p, "=", reached ? "yes" : "no"))
  end
  println("REACH ", sc.name, " ", tname, " outcome=", outcome, " ", join(seen, " "), " upd=", upd_outcome)
  flush(stdout)
end

# Constructed states (as in the characterization tests): the one branch no solve reaches, x != x_previous while
# norm(delta_x) == 0 (the norm of a nonzero difference does not underflow), and a stall by construction.
function direct_checks!(tsv::IO)
  for T in (Float32, Float64), solver in (:pgd, :apg)
    f, g = LeastSquaresLoss(T[1, -1], T[1 0; 0 2]), NormL1(T(.1))
    options = ProximalOptions(; ftol = 0, xtol = 1e-8, gradtol = 1e-11)
    function assessed(x, previous, delta)
      st = PS.initial_state(default_method(solver), options, f, g, T[.3, -.2])
      st.x .= x; st.x_previous .= previous; st.delta_x .= delta
      st.f_x, st.g_x = T(1.5), zero(T); st.f_x_previous, st.g_x_previous = T(2.5), zero(T)
      hits_reset!()
      flags = PS.convergence_assessment(st, f, g, options)
      (flags, hits_snapshot())
    end
    fl1, h1 = assessed(T[1, 2], T[1.01, 2.01], zeros(T, 2))    # x != x_previous, delta_x = 0: not a stall
    fl2, h2 = assessed(T[1, 2], T[1, 2], zeros(T, 2))          # x == x_previous: a stall
    nm = "direct:constructed_state:$solver"
    println(tsv, "P\t", nm, "\t", T, "\teng_f0_normdx_zero_not_unchanged\t", get(h1, :eng_f0_normdx_zero_not_unchanged, 0) > 0 ? 1 : 0, "\t0")
    println(tsv, "P\t", nm, "\t", T, "\teng_f0_stall\t", get(h2, :eng_f0_stall, 0) > 0 ? 1 : 0, "\t0")
    println("DIRECT ", solver, " ", T, " not-a-stall flags (x_conv, f_conv, grad_conv, converged, f_inc) = ", fl1,
            "; stall flags = ", fl2)
  end
  hits_reset!()
end

function reach_main(dir)
  open(joinpath(dir, "reach.tsv"), "w") do tsv
    for sc in SCENARIOS
      reach_one!(tsv, sc)
    end
    direct_checks!(tsv)
  end
  println("REACH_CHILD_DONE ", length(SCENARIOS), " scenarios")
end

# ---------------------------------------------------------------- alloc child
function alloc_solve(a, x)
  if isempty(a.kwargs)
    @allocated (try; PS.solve!(x, a.f, a.g, a.method, a.opts); nothing; catch; nothing; end)
  else
    @allocated (try; PS.solve!(x, a.f, a.g, a.method, a.opts; a.kwargs...); nothing; catch; nothing; end)
  end
end

function alloc_solve_state(a, x)
  st = PS.initial_state(a.method, a.opts, a.f, a.g, x)
  a.prep === nothing || a.prep(st)
  @allocated (try; PS._solve_gradient!(st, a.f, a.g, a.method, a.opts); nothing; catch; nothing; end)
end

alloc_one_update(f, g, st, m) = @allocated (try; PS.update_state!(f, g, st, m); nothing; catch; nothing; end)

function measure_solve(sc::Scn)
  best = typemax(Int)
  note = ""
  for rep in 1:4          # the first repetition warms (compiles); the minimum of the rest is reported
    a = sc.make()
    a.how === :update && return (-1, "n/a (update-only scenario)")
    x = a.alias ? a.x0 : copy(a.x0)
    f = a.how === :solve ? alloc_solve : alloc_solve_state
    b = if a.opts isa ProximalOptions && a.opts.show_trace
      note = "stdout redirected to a file"
      capture_stdout(() -> f(a, x))[1]
    else
      f(a, x)
    end
    rep > 1 && (best = min(best, b))
  end
  (best, note)
end

function measure_update(sc::Scn, k::Int)
  note = ""
  function build(upto)
    a = sc.make()
    x = a.alias ? a.x0 : copy(a.x0)
    st = PS.initial_state(a.method, a.opts, a.f, a.g, x)
    a.prep === nothing || a.prep(st)
    threw = false
    for _ in 1:upto
      try
        PS.update_state!(a.f, a.g, st, a.method)
      catch
        threw = true
        break
      end
    end
    (a, st, threw)
  end
  build(k)                                  # warm
  best = typemax(Int)
  for rep in 1:3
    a, st, threw = build(k - 1)
    threw && return (-1, "threw before update $k")
    b = alloc_one_update(a.f, a.g, st, a.method)
    best = min(best, b)
  end
  (best, note)
end

function alloc_main(dir)
  kst = Dict{Tuple{String,String},Int}()
  for line in eachline(joinpath(dir, "reach.tsv"))
    f = split(line, '\t')
    if f[1] == "P"
      k = parse(Int, f[6])
      p = f[4]
      startswith(p, "eng_") && continue
      k > 0 && (kst[(f[2], f[3])] = min(get(kst, (f[2], f[3]), typemax(Int)), k))
    end
  end
  open(joinpath(dir, "alloc.tsv"), "w") do tsv
    for sc in SCENARIOS
      tname = string(sc.T)
      sig = sha1hex(case_record(sc))
      sb, sn = try
        measure_solve(sc)
      catch e
        (-1, "error: " * sprint(showerror, e)[1:min(end, 100)])
      end
      k = get(kst, (sc.name, tname), 1)
      ub, un = if sc.maxupd == 0
        (-1, "n/a (refusal)")
      else
        try
          measure_update(sc, k)
        catch e
          (-1, "error: " * sprint(showerror, e)[1:min(end, 100)])
        end
      end
      println(tsv, "A\t", sc.name, "\t", tname, "\t", sb, "\t", sn, "\t", ub, "\t", k, "\t", un, "\t", sig)
      println("ALLOC ", sc.name, " ", tname, " solve=", sb, " ", sn, " update=", ub, "@k", k, " ", un)
      flush(stdout)
    end
  end
  println("ALLOC_CHILD_DONE ", length(SCENARIOS), " scenarios")
end

# ---------------------------------------------------------------- parent
function run_child(mode, dir)
  cmd = `$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) --startup-file=no $(@__FILE__) $mode $dir`
  println("PARENT spawning child: ", mode)
  flush(stdout)
  run(cmd)
  nothing
end

function print_table(dir)
  T2 = ("Float32", "Float64")
  reach = Dict{Tuple{String,String},Vector{Tuple{String,Bool,Int}}}()
  sigs = Dict{Tuple{String,String},String}()
  for line in eachline(joinpath(dir, "reach.tsv"))
    f = split(line, '\t')
    if f[1] == "P"
      push!(get!(reach, (f[4], f[3]), Tuple{String,Bool,Int}[]), (f[2], f[5] == "1", parse(Int, f[6])))
    elseif f[1] == "S"
      sigs[(f[2], f[3])] = f[4]
    end
  end
  alloc = Dict{Tuple{String,String},Tuple{String,String,Int,String}}()
  asigs = Dict{Tuple{String,String},String}()
  for line in eachline(joinpath(dir, "alloc.tsv"))
    f = split(line, '\t')
    alloc[(f[2], f[3])] = (f[4], f[6], parse(Int, f[7]), string(f[5], f[8]))
    asigs[(f[2], f[3])] = f[9]
  end
  println("PATH_TABLE columns: path | location | reached Float32 | reached Float64 | alloc Float32 | alloc Float64")
  println("PATH_TABLE alloc = bytes of solve! (or _solve_gradient! for state scenarios) / bytes of one update_state! at update k of the first scenario that reached the path")
  for (id, label, loc) in PATHS
    cells = String[]
    acells = String[]
    for T in T2
      ents = get(reach, (string(id), T), Tuple{String,Bool,Int}[])
      st = isempty(ents) ? "-" : any(e -> e[2], ents) ? "yes" : "no"
      push!(cells, st)
      pick = findfirst(e -> e[2], ents)
      pick === nothing && (pick = isempty(ents) ? nothing : 1)
      if pick === nothing
        push!(acells, "-")
      else
        nm = ents[pick][1]
        al = get(alloc, (nm, T), nothing)
        push!(acells, al === nothing ? nm : "$(nm): solve=$(al[1]) update=$(al[2])@k$(al[3])")
      end
    end
    println("PATH ", id, " | ", loc, " | ", cells[1], " | ", cells[2], " | ", acells[1], " | ", acells[2], " | ", label)
  end
  # claims of the group F scenario families: how many scenarios of a family reached the path they claim
  fam = Dict{Tuple{String,String,String,Bool},Int}()
  for ((path, T), ents) in reach, (name, ok, _) in ents
    (startswith(name, "F:") || startswith(name, "direct:")) || continue
    fm = startswith(name, "F:") ? split(name, ':')[2] : name
    fam[(fm, T, path, ok)] = get(fam, (fm, T, path, ok), 0) + 1
  end
  for (fm, T, path, ok) in sort!(collect(keys(fam)))
    println("CLAIMS ", fm, " | ", T, " | ", path, " | reached=", ok, " scenarios=", fam[(fm, T, path, ok)])
  end
  same = count(k -> haskey(asigs, k) && asigs[k] == sigs[k], keys(sigs))
  println("INSTRUMENTATION_CHECK scenarios with identical fingerprint signature, instrumented vs clean: ", same, " of ", length(sigs))
  for k in keys(sigs)
    haskey(asigs, k) && asigs[k] == sigs[k] || println("INSTRUMENTATION_CHECK DIFFERS ", k)
  end
end

if MODE == "parent"
  env_header()
  dir = mktempdir()
  println("PARENT scenarios: ", length(SCENARIOS), " (", count(s -> s.T === Float32, SCENARIOS), " Float32, ",
          count(s -> s.T === Float64, SCENARIOS), " Float64)")
  run_child("reach", dir)
  run_child("alloc", dir)
  print_table(dir)
  println("COVERAGE_PROBE DONE")
elseif MODE == "reach"
  instrument_core!(pkgdir(ProximalSolvers))
end
MODE == "reach" && reach_main(ARGS[2])
MODE == "alloc" && alloc_main(ARGS[2])
