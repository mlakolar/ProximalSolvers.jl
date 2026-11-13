# corpus_f.jl: group F of the #279 corpus: ftol = 0 (issue #270, PR #286), written against master 3408e1f.
# Included by corpus.jl (needs Scn, std pieces, PS, raw_make, lsq_data, ... in scope). Groups A-E are not touched:
# F is appended after E, with its own option variants (OPTION_NAMES is deliberately not extended, the fuzz group E
# draws from it).
#
# Claims (`paths`) are what a scenario is meant to reach; coverage_probe.jl counts what it really reaches.

const F_TINY = (xtol = 1e-300, gradtol = 0.0)

function f_option_kwargs(name::Symbol, log::Vector{String})
  name === :f0_default && return (ftol = 0,)
  name === :f0_tight && return (maxiter = 500, ftol = 0, xtol = 1e-12, gradtol = 1e-10)
  name === :f0_gt0 && return (maxiter = 300, ftol = 0, F_TINY...)
  name === :f0_gt0_defx && return (ftol = 0, gradtol = 0)              # default xtol, gradtol = 0
  name === :f0_mi2 && return (maxiter = 2, ftol = 0)
  name === :f0_mi7 && return (maxiter = 7, ftol = 0, F_TINY...)
  name === :f0_mi60 && return (maxiter = 60, ftol = 0, xtol = 1e-300, gradtol = 1e-11)
  name === :f0_allow && return (maxiter = 200, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
  name === :f0_noallow && return (maxiter = 200, ftol = 0, allow_f_increases = false, F_TINY...)
  name === :f0_store && return (maxiter = 30, ftol = 0, store_trace = true, F_TINY...)
  name === :f0_store_ext && return (maxiter = 20, ftol = 0, store_trace = true, extended_trace = true, F_TINY...)
  name === :f0_show && return (maxiter = 12, ftol = 0, show_trace = true, F_TINY...)
  name === :f0_cb && return (maxiter = 60, ftol = 0, print_every = 2, extended_trace = true, callback = cb_logger(log, 3), F_TINY...)
  name === :f0_cb_store && return (maxiter = 25, ftol = 0, store_trace = true, callback = cb_logger(log, 0), F_TINY...)
  name === :f0_all && return (maxiter = 15, ftol = 0, store_trace = true, show_trace = true, extended_trace = true,
                              print_every = 2, allow_f_increases = true, callback = cb_logger(log, 0), F_TINY...)
  name === :f0_limits && return (maxiter = 100, ftol = 0, f_calls_limit = 9, grad_calls_limit = 6, prox_calls_limit = 7,
                                 allow_f_increases = true, store_trace = true, F_TINY...)
  name === :f0_timeneg && return (maxiter = 100, ftol = 0, time_limit = -1.0, F_TINY...)
  # controls with ftol > 0 (the unchanged iterate passes the x test; f_residual keeps its formula)
  name === :pos_default && return (;)
  name === :pos_tiny && return (maxiter = 100, ftol = 1e-300, xtol = 1e-300, gradtol = 0.0)
  error("unknown F option variant $name")
end

const F_OPTION_NAMES = [:f0_default, :f0_tight, :f0_gt0, :f0_gt0_defx, :f0_mi2, :f0_mi7, :f0_mi60, :f0_allow,
  :f0_noallow, :f0_store, :f0_store_ext, :f0_show, :f0_cb, :f0_cb_store, :f0_all, :f0_limits, :f0_timeneg]

# gradtol > 0 and no early stop: which claims an option variant supports on a stalling solve
f_gradtol_positive(o::Symbol) = o in (:f0_default, :f0_tight, :f0_mi2, :f0_mi60, :f0_allow, :pos_default)
f_runs_to_maxiter(o::Symbol) = o in (:f0_default, :f0_tight, :f0_gt0, :f0_gt0_defx, :f0_mi2, :f0_mi7, :f0_mi60, :f0_allow, :f0_noallow,
                                     :f0_store, :f0_store_ext, :f0_show, :f0_cb_store, :f0_all)

# solution of the problem to high accuracy, from the solver under test (same tree): a converged warm start
# (counters of the coverage probe are paused during it: the warm-up solve is not the scenario)
const F_QUIET = Ref(false)
function f_warm_solution(T, solver, f, g, p)
  x = zeros(T, p)
  F_QUIET[] = true
  try
    PS.solve!(x, f, g, default_method(solver), ProximalOptions(maxiter = 4000, ftol = 0, allow_f_increases = true,
                                                                 xtol = 1e-300, gradtol = 1e-12))
  finally
    F_QUIET[] = false
  end
  x
end

function f_make(T, solver, n, p, loss, λfrac, start, optname; seed = 1000n + p, how = :solve, prep = nothing)
  function ()
    X, y, β = lsq_data(T, n, p; seed)
    f = make_loss(loss, y, X)
    α = alpha_of(loss, T, n)
    g = NormL1(T(λfrac * lambda_max(X, y, α)))
    log = String[]
    opts = ProximalOptions(; f_option_kwargs(optname, log)...)
    x0 = start === :warmsol ? f_warm_solution(T, solver, f, g, p) : make_start(T, start, p, β)
    (; x0, f, g, method = default_method(solver), opts, log, prep, how, kwargs = (;), alias = false)
  end
end

const F_SIZES = [(12, 7), (31, 33), (33, 31), (100, 32)]
const F_STALL_SIZES = [(31, 31), (32, 32), (33, 33)]

function f0_scenarios()
  S = Scn[]
  add!(name, T, solver, make; paths = Symbol[], expect = nothing, maxupd = 3) =
    push!(S, Scn(name, 'F', T, solver, make; paths, expect, maxupd))
  # ---- F1: seeded grid, every ftol = 0 variant on every (solver, T, size) ----------------------------------------
  rng = Xoshiro(279_270)
  λfs = (0.0, 0.05, 0.5, 1.5)
  losses = (:raw, :inv_n, :inv_n_f64, :half)
  starts = (:cold, :warm, :warm2)
  for solver in (:pgd, :apg), T in (Float32, Float64), (n, p) in F_SIZES, opt in F_OPTION_NAMES
    λf, loss, start = λfs[rand(rng, 1:4)], losses[rand(rng, 1:4)], starts[rand(rng, 1:3)]
    nm = "F:grid:$(solver):$(T):$(n)x$(p):$(loss):l$(λf):$(start):$(opt)"
    add!(nm, T, solver, f_make(T, solver, n, p, loss, λf, start, opt))
  end
  # ---- F2: stalls from a zero start with λ above λ_max (x == x_previous from the first iteration) -----------------
  stall_opts = (:f0_default, :f0_gt0, :f0_mi7, :f0_allow, :f0_noallow, :f0_store_ext, :f0_cb)
  for solver in (:pgd, :apg), T in (Float32, Float64), (n, p) in F_STALL_SIZES, λf in (1.5, 4.0), opt in stall_opts
    paths = [:eng_f0_stall, :eng_f0_normdx_zero, :eng_f0_stall_blocks_x, :eng_f0_objective_off]
    f_gradtol_positive(opt) && push!(paths, :eng_f0_stall_blocks_grad)
    f_runs_to_maxiter(opt) && push!(paths, :eng_f0_stall_until_maxiter)
    nm = "F:stall0:$(solver):$(T):$(n)x$(p):l$(λf):$(opt)"
    add!(nm, T, solver, f_make(T, solver, n, p, :inv_n, λf, :cold, opt); paths)
  end
  # ---- F3: nonzero start, λ above λ_max: the first step reaches 0, the next ones stall at 0 -----------------------
  for solver in (:pgd, :apg), T in (Float32, Float64), (n, p) in ((31, 31), (33, 33)), opt in (:f0_default, :f0_allow, :f0_gt0, :f0_store)
    nm = "F:stallwarm:$(solver):$(T):$(n)x$(p):l3.0:$(opt)"
    paths = [:eng_f0_stall, :eng_f0_stall_blocks_x]
    f_runs_to_maxiter(opt) && push!(paths, :eng_f0_stall_until_maxiter)
    add!(nm, T, solver, f_make(T, solver, n, p, :inv_n, 3.0, :warm, opt); paths)
  end
  # ---- F4: converged warm start (the solution of the same solver at 4000 iterations): a stall only if the step is exactly 0
  for solver in (:pgd, :apg), T in (Float32, Float64), (n, p) in ((31, 31), (33, 33)), λf in (0.05, 0.3),
      opt in (:f0_default, :f0_tight, :f0_gt0, :f0_allow)
    nm = "F:warmsol:$(solver):$(T):$(n)x$(p):l$(λf):$(opt)"
    add!(nm, T, solver, f_make(T, solver, n, p, :inv_n, λf, :warmsol, opt); paths = [:eng_f0_stall])
  end
  # ---- F5: the manual path and update-level states on a stalling problem ------------------------------------------
  for solver in (:pgd, :apg), T in (Float32, Float64)
    for opt in (:f0_default, :f0_cb, :f0_store_ext)
      add!("F:state:$(solver):$(T):l1.5:$(opt)", T, solver, f_make(T, solver, 31, 31, :inv_n, 1.5, :cold, opt; how = :state);
           paths = [:eng_f0_stall, :eng_f0_stall_blocks_x])
    end
    add!("F:update:$(solver):$(T):l1.5", T, solver, f_make(T, solver, 31, 31, :inv_n, 1.5, :cold, :f0_default; how = :update);
         maxupd = 3)
  end
  # ---- F6: f_residual reporting: F = F' = 0, F = 0 != F', and the controls with ftol > 0 -------------------------------
  for solver in (:pgd, :apg), T in (Float32, Float64)
    rep(nm, x0v, o; paths = Symbol[]) = add!("F:rep_$(nm):$(solver):$(T)", T, solver, raw_make(() -> (;
      x0 = T[x0v], f = LeastSquaresLoss(T[0], reshape(T[1], 1, 1)), g = NormL1(T(100)), method = default_method(solver),
      opts = o())); paths)
    # F = F' = 0 at every iteration (x = 0 is the minimizer and the start)
    rep("zero_zero", 0, () -> ProximalOptions(maxiter = 3, ftol = 0);
        paths = [:eng_f0_stall, :eng_f0_stall_until_maxiter, :eng_fres_both_zero])
    rep("zero_zero_trace", 0, () -> ProximalOptions(maxiter = 4, ftol = 0, store_trace = true, show_trace = true,
                                                     extended_trace = true); paths = [:eng_fres_both_zero])
    rep("zero_zero_pos", 0, () -> ProximalOptions(maxiter = 3, ftol = 1e-6); paths = [:eng_fres_ftol_positive])
    rep("zero_zero_tinypos", 0, () -> ProximalOptions(maxiter = 3, ftol = 1e-300); paths = [:eng_fres_ftol_positive])
    # F = 0 != F' at iteration 1; the callback stops there, so the result reports Inf
    rep("zero_prev", 1, () -> ProximalOptions(ftol = 0, callback = _ -> true); paths = [:eng_fres_F0_Fprev_nonzero_inf])
    rep("zero_prev_store", 1, () -> ProximalOptions(ftol = 0, callback = _ -> true, store_trace = true, extended_trace = true);
        paths = [:eng_fres_F0_Fprev_nonzero_inf])
    rep("zero_prev_pos", 1, () -> ProximalOptions(ftol = 1e-6, callback = _ -> true); paths = [:eng_fres_ftol_positive])
    # without the callback: iteration 2 has F = F' = 0 again, and the unchanged iterate is a stall
    rep("zero_prev_run", 1, () -> ProximalOptions(maxiter = 5, ftol = 0); paths = [:eng_f0_stall, :eng_fres_both_zero])
    rep("zero_prev_run_noinc", 1, () -> ProximalOptions(maxiter = 5, ftol = 0, allow_f_increases = true, show_trace = true);
        paths = [:eng_fres_both_zero])
    # change zero at nonzero F: an unchanged iterate at F != 0 (loss with y = 1 and a large penalty), and the ratio branch
    function nonzero(nm, x0v, o, claims)
      add!("F:rep_$(nm):$(solver):$(T)", T, solver, raw_make(() -> (;
        x0 = T[x0v], f = LeastSquaresLoss(T[1], reshape(T[1], 1, 1)), g = NormL1(T(100)), method = default_method(solver),
        opts = o())); paths = claims)
    end
    nonzero("nz_stall", 0, () -> ProximalOptions(maxiter = 4, ftol = 0), [:eng_f0_stall, :eng_fres_zero_change_nonzero_F])
    nonzero("nz_ratio", 1, () -> ProximalOptions(maxiter = 4, ftol = 0, callback = _ -> true), [:eng_fres_ratio])
    nonzero("nz_pos", 0, () -> ProximalOptions(maxiter = 4, ftol = 1e-6), [:eng_fres_ftol_positive, :eng_ftol_pos_unchanged_passes_x])
  end
  # ---- F7: ftol validation: zero spellings are accepted and stored as +0.0; positive values that round to 0 are refused -
  zero_spellings = Pair{String,Any}["Int0" => 0, "pos0" => 0.0, "neg0" => -0.0, "f32pos0" => 0f0, "f32neg0" => -0f0,
    "big0" => big(0), "bigneg0" => big"-0.0", "rat0" => 0 // 1]
  for solver in (:pgd, :apg), T in (Float32, Float64), (lbl, z) in zero_spellings
    nm = "F:ftolzero_$(lbl):$(solver):$(T)"
    claim = occursin("neg", lbl) ? [:eng_ftol_negzero_stored_plus0] : Symbol[]
    add!(nm, T, solver, f_make_spelled(T, solver, z); paths = claim)
  end
  tiny_values = Pair{String,Any}["big1e-400" => big"1e-400", "rat1e-400" => 1 // big(10)^400, "big1e-1000" => big"1e-1000",
    "nextbig0" => nextfloat(big"0.0")]
  bad_values = Pair{String,Any}["neg1" => -1.0, "neg1e-300" => -1e-300, "negtiny" => -nextfloat(0.0), "nan" => NaN, "inf" => Inf,
    "ninf" => -Inf, "nan32" => NaN32, "inf32" => Inf32, "bignegtiny" => big"-1e-400", "big1e400" => big"1e400"]
  for solver in (:pgd, :apg), T in (Float32, Float64)
    for (lbl, v) in tiny_values
      add!("F:ref_ftol_rounds0_kw_$(lbl):$(solver):$(T)", T, solver, f_make_spelled(T, solver, v);
           paths = [:refuse_ftol_rounds_to_zero], expect = (ArgumentError, r"rounds to 0 in Float64"), maxupd = 0)
      add!("F:ref_ftol_rounds0_pos_$(lbl):$(solver):$(T)", T, solver, f_make_spelled(T, solver, v; positional = true);
           paths = [:refuse_ftol_rounds_to_zero], expect = (ArgumentError, r"rounds to 0 in Float64"), maxupd = 0)
    end
    for (lbl, v) in bad_values
      add!("F:ref_ftol_bad_$(lbl):$(solver):$(T)", T, solver, f_make_spelled(T, solver, v);
           paths = [:refuse_ftol_nonneg], expect = (ArgumentError, r"ftol must be finite and nonnegative"), maxupd = 0)
    end
    # accepted tiny positive values: the smallest ones that survive the conversion
    for (lbl, v) in ("floatmin" => floatmin(Float64), "nextfloat0" => nextfloat(0.0), "e300" => 1e-300)
      add!("F:ftolpos_$(lbl):$(solver):$(T)", T, solver, f_make_spelled(T, solver, v))
    end
  end
  S
end

# a small stalling problem whose options carry the given spelling of ftol (keyword or positional constructor)
function f_make_spelled(T, solver, ftolv; positional::Bool = false)
  function ()
    X, y, β = lsq_data(T, 20, 6; seed = 4)
    f = (one(T) / T(20)) * LeastSquaresLoss(y, X)
    g = NormL1(T(2 * lambda_max(X, y, Float64(one(T) / T(20)))))
    opts = positional ?
      ProximalOptions(25, ftolv, 1e-8, 1e-5, 0, 0, 0, false, false, false, false, 1, nothing, Inf) :
      ProximalOptions(; maxiter = 25, ftol = ftolv)
    (; x0 = zeros(T, 6), f, g, method = default_method(solver), opts, log = String[], prep = nothing, how = :solve,
       kwargs = (;), alias = false)
  end
end
