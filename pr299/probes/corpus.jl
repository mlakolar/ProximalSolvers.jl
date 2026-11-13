# corpus.jl: the deterministic corpus (scenarios, option variants, refusals, fuzz) of issue #279.
# Every case is a `Scn` whose `make` builds fresh objects from seeded data (Random.Xoshiro), so a
# case is independent of the tree under test except through its public and internal API.
# Requires: common.jl included, `using ProximalSolvers` done in Main.
using Random
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
using SparseArrays: sparse
const PS = ProximalSolvers

struct Scn
  name::String
  group::Char
  T::DataType
  solver::Symbol
  make::Function
  paths::Vector{Symbol}
  expect::Union{Nothing,Tuple{DataType,Regex}}
  maxupd::Int
end
Scn(name, group, T, solver, make; paths = Symbol[], expect = nothing, maxupd = 200) =
  Scn(String(name), group, T, solver, make, paths, expect, maxupd)

# ---- data ------------------------------------------------------------------------------------
function lsq_data(::Type{T}, n, p; seed = 1, ρ = 0.0, xscale = 1.0, noise = 0.1) where {T}
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  if ρ != 0
    for j in 2:p
      X[:, j] .= ρ .* X[:, j - 1] .+ sqrt(1 - ρ^2) .* X[:, j]
    end
  end
  X .*= xscale
  β = zeros(p)
  coef = (1.5, -1.0, 0.75, 2.0)
  for j in 1:min(p, 4)
    β[j] = coef[j]
  end
  y = X * β .+ noise .* randn(rng, n)
  (Matrix{T}(X), Vector{T}(y), β)
end

alpha_of(kind::Symbol, ::Type{T}, n) where {T} =
  kind === :raw ? 1.0 : kind === :inv_n ? Float64(one(T) / T(n)) : kind === :inv_n_f64 ? 1 / n : 0.5

function make_loss(kind::Symbol, y::Vector{T}, X::Matrix{T}) where {T}
  n = size(X, 1)
  L = LeastSquaresLoss(y, X)
  kind === :raw ? L :
  kind === :inv_n ? (one(T) / T(n)) * L :
  kind === :inv_n_f64 ? (1 / n) * L :
  kind === :half ? 0.5 * L : error("unknown loss kind $kind")
end

lambda_max(X, y, α) = α * maximum(abs, Float64.(X)' * Float64.(y))

function make_start(::Type{T}, kind::Symbol, p, β) where {T}
  kind === :cold ? zeros(T, p) :
  kind === :warm ? T.(0.9 .* β .+ 0.01 .* cos.(1:p)) :
  kind === :warm2 ? T.(0.1 .* cos.(1:p)) : error("unknown start $kind")
end

default_method(solver::Symbol) = solver === :pgd ? ProximalGradientDescent() : AccProxGradDescent()

# ---- options ---------------------------------------------------------------------------------
function cb_logger(log::Vector{String}, stop_at::Int)
  cnt = Ref(0)
  function (arg)
    cnt[] += 1
    if arg isa AbstractVector
      if isempty(arg)
        push!(log, "CB $(cnt[]) vec len=0")
      else
        s = last(arg)
        push!(log, "CB $(cnt[]) vec len=$(length(arg)) last=$(s.iteration) $(bitstring(s.fg_x)) $(bitstring(s.dxx)) $(bitstring(s.L)) md=$(length(s.metadata))")
      end
    else
      push!(log, "CB $(cnt[]) st $(arg.iteration) $(bitstring(arg.fg_x)) $(bitstring(arg.dxx)) $(bitstring(arg.L)) md=$(length(arg.metadata)) $(typeof(arg))")
    end
    stop_at > 0 && cnt[] >= stop_at
  end
end

const OPTION_NAMES = [:default, :tight, :loose, :gradonly, :maxiter2, :maxiter7, :fcalls, :gradcalls, :proxcalls,
  :time0, :timetiny, :timeneg, :allow_inc, :inc_stop, :store, :store_ext, :ext_alone, :show, :show_pe3, :cb_false,
  :cb_store_false, :cb_stop3, :cb_ext_stop, :all, :limits_combo]

function option_kwargs(name::Symbol, log::Vector{String})
  tiny = (ftol = 1e-30, xtol = 1e-30, gradtol = 0.0)
  name === :default && return (;)
  name === :tight && return (maxiter = 500, ftol = 1e-12, xtol = 1e-12, gradtol = 1e-10)
  name === :loose && return (ftol = 1e-2, xtol = 1e-2, gradtol = 1e-2)
  name === :gradonly && return (maxiter = 400, ftol = 1e-300, xtol = 1e-300, gradtol = 1e-6)
  name === :maxiter2 && return (maxiter = 2,)
  name === :maxiter7 && return (; maxiter = 7, tiny...)
  name === :fcalls && return (; maxiter = 100, f_calls_limit = 6, tiny...)
  name === :gradcalls && return (; maxiter = 100, grad_calls_limit = 4, tiny...)
  name === :proxcalls && return (; maxiter = 100, prox_calls_limit = 5, tiny...)
  # time_limit = 0 and tiny positive limits are decided by clock ties on tiny problems (an A/A run differed on one such
  # record), so the limits here are negative: the first complete iteration always stops the solve
  name === :time0 && return (; maxiter = 100, time_limit = -5e-324, tiny...)
  name === :timetiny && return (; maxiter = 100, time_limit = -1e-300, tiny...)
  name === :timeneg && return (; maxiter = 100, time_limit = -1.0, tiny...)
  name === :inc_stop && return (; maxiter = 300, tiny...)
  name === :allow_inc && return (; maxiter = 300, allow_f_increases = true, tiny...)
  name === :store && return (; maxiter = 30, store_trace = true, tiny...)
  name === :store_ext && return (; maxiter = 20, store_trace = true, extended_trace = true, tiny...)
  name === :ext_alone && return (; maxiter = 20, extended_trace = true, tiny...)
  name === :show && return (; maxiter = 12, show_trace = true, tiny...)
  name === :show_pe3 && return (; maxiter = 15, show_trace = true, print_every = 3, store_trace = true, tiny...)
  name === :cb_false && return (; maxiter = 25, callback = cb_logger(log, 0), tiny...)
  name === :cb_store_false && return (; maxiter = 25, store_trace = true, callback = cb_logger(log, 0), tiny...)
  name === :cb_stop3 && return (; maxiter = 60, print_every = 2, extended_trace = true, callback = cb_logger(log, 3), tiny...)
  name === :cb_ext_stop && return (; maxiter = 60, store_trace = true, extended_trace = true, callback = cb_logger(log, 2), tiny...)
  name === :all && return (; maxiter = 15, store_trace = true, show_trace = true, extended_trace = true, print_every = 2,
                           callback = cb_logger(log, 0), tiny...)
  name === :limits_combo && return (; maxiter = 100, f_calls_limit = 9, grad_calls_limit = 6, prox_calls_limit = 7,
                                    allow_f_increases = true, store_trace = true, tiny...)
  error("unknown option variant $name")
end

# ---- standard maker --------------------------------------------------------------------------
function std_make(T, solver, n, p, loss, λfrac, start, optname; seed = 1000n + p, ρ = 0.0, xscale = 1.0, method = nothing)
  function ()
    X, y, β = lsq_data(T, n, p; seed, ρ, xscale)
    f = make_loss(loss, y, X)
    α = alpha_of(loss, T, n)
    g = NormL1(T(λfrac * lambda_max(X, y, α)))
    log = String[]
    opts = ProximalOptions(; option_kwargs(optname, log)...)
    m = method === nothing ? default_method(solver) : method()
    (; x0 = make_start(T, start, p, β), f, g, method = m, opts, log, prep = nothing, how = :solve, kwargs = (;), alias = false)
  end
end

# a maker from explicit pieces
function raw_make(build::Function; how = :solve)
  function ()
    r = build()
    (; x0 = r.x0, f = r.f, g = r.g, method = r.method, opts = get(r, :opts, ProximalOptions()),
       log = get(r, :log, String[]), prep = get(r, :prep, nothing), how = get(r, :how, how), kwargs = get(r, :kwargs, (;)),
       alias = get(r, :alias, false))
  end
end

const TIGHT_OPTS = (maxiter = 300, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11)
const LONG_OPTS = (maxiter = 500, ftol = 1e-300, xtol = 1e-300, gradtol = 0.0)

# ---- the W2 path scenarios (also corpus group C) ----------------------------------------------
function w2_scenarios()
  S = Scn[]
  add!(args...; kw...) = push!(S, Scn(args...; kw...))
  for T in (Float32, Float64)
    tn = string(T)
    # ---------------- PGD ----------------
    add!("pgd_default_bt", 'C', T, :pgd, std_make(T, :pgd, 50, 20, :inv_n, 0.05, :cold, :default);
         paths = T === Float32 ? [:pgd_ls_Float64_data_Float32] : Symbol[], maxupd = 60)
    add!("pgd_bt_f32params", 'C', T, :pgd,
         std_make(T, :pgd, 50, 20, :inv_n, 0.05, :cold, :default;
                  method = () -> ProximalGradientDescent(ls = PS.LineSearches.BackTracking(0.9f0, 0.5f0, Inf32)));
         paths = T === Float32 ? [:pgd_ls_Float32_data_Float32] : Symbol[], maxupd = 60)
    add!("pgd_lexact", 'C', T, :pgd, raw_make(() -> begin
           X, y, β = lsq_data(T, 50, 20; seed = 11, ρ = 0.5)
           curv = opnorm(Float64.(X))^2
           lx = Float64(Float32(0.2 * curv))        # representable in Float32 as well
           (; x0 = zeros(T, 20), f = LeastSquaresLoss(y, X), g = NormL1(T(0.02 * lambda_max(X, y, 1.0))),
              method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(Lexact = lx)),
              opts = ProximalOptions(; maxiter = 60, allow_f_increases = true, ftol = 1e-30, xtol = 1e-30, gradtol = 0.0))
         end); paths = [:pgd_exit_lexact], maxupd = 60)
    add!("pgd_mode_switch", 'C', T, :pgd, std_make(T, :pgd, 50, 20, :inv_n, 0.05, :cold, :allow_inc);
         paths = [:pgd_mode_switch, :pgd_gradient_mode_trial], maxupd = 300)
    add!("pgd_zero_step_simple", 'C', T, :pgd, std_make(T, :pgd, 30, 10, :raw, 1.5, :cold, :default);
         paths = [:pgd_zero_step_simple], maxupd = 5)
    add!("pgd_zero_step_gradient", 'C', T, :pgd, raw_make(() -> begin
           X, y, β = lsq_data(T, 30, 10; seed = 5)
           (; x0 = zeros(T, 10), f = LeastSquaresLoss(y, X), g = NormL1(T(1.5 * lambda_max(X, y, 1.0))),
              method = ProximalGradientDescent(), how = :state,
              prep = st -> (st.backtrack_simple = false; nothing))
         end); paths = [:pgd_zero_step_gradient], maxupd = 5)
    add!("pgd_nonfinite_trial_recovers", 'C', T, :pgd, raw_make(() -> begin
           s = T === Float32 ? T(1e18) : T(1e150)
           (; x0 = zeros(T, 2), f = LeastSquaresLoss(fill(s, 2), Matrix{T}(s * I, 2, 2)), g = NormL1(zero(T)),
              method = ProximalGradientDescent(), opts = ProximalOptions(; TIGHT_OPTS...))
         end); paths = [:pgd_nonfinite_trial], maxupd = 40)
    add!("pgd_nonfinite_then_error", 'C', T, :pgd, raw_make(() -> begin
           s = T === Float32 ? T(1e19) : T(1e154)
           (; x0 = zeros(T, 1), f = LeastSquaresLoss(T[1], fill(s, 1, 1)), g = NormL1(zero(T)),
              method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(β = nextfloat(0.0))))
         end); paths = [:pgd_nonfinite_trial, :next_curvature_error, :eng_rollback], maxupd = 5)
    add!("pgd_state_fault_rollback", 'C', T, :pgd, raw_make(() -> begin
           X, y, β = lsq_data(T, 20, 5; seed = 3)
           f = (one(T) / T(20)) * LeastSquaresLoss(y, X); g = NormL1(T(0.05)); m = ProximalGradientDescent()
           (; x0 = zeros(T, 5), f, g, method = m, how = :state,
              prep = st -> (PS.update_state!(f, g, st, m); st.L = zero(T); nothing))
         end); paths = [:next_curvature_error, :eng_rollback], maxupd = 3)
    # ---------------- APG ----------------
    add!("apg_illcond", 'C', T, :apg, raw_make(() -> begin
           X, y, β = lsq_data(T, 50, 20; seed = 5, ρ = 0.95, xscale = 3.0)
           α = 1 / 50
           (; x0 = zeros(T, 20), f = (one(T) / T(50)) * LeastSquaresLoss(y, X),
              g = NormL1(T(0.01 * lambda_max(X, y, Float64(one(T) / T(50))))), method = AccProxGradDescent(),
              opts = ProximalOptions(; TIGHT_OPTS...))
         end); paths = [:apg_accept_cached, :apg_early_reject, :apg_fresh_product, :apg_fresh_accept, :apg_fresh_reject,
                       :apg_restart, :apg_cached_norm_nothing, :apg_onepass_to_twopass, :apg_diffonepass_to_twopass],
         maxupd = 300)
    add!("apg_fresh_only", 'C', T, :apg, raw_make(() -> begin
           X, y, β = lsq_data(T, 50, 20; seed = 5, ρ = 0.95, xscale = 3.0)
           (; x0 = zeros(T, 20), f = (one(T) / T(50)) * LeastSquaresLoss(y, X),
              g = NormL1(T(0.01 * lambda_max(X, y, Float64(one(T) / T(50))))), method = AccProxGradDescent(),
              opts = ProximalOptions(; TIGHT_OPTS...), how = :state, prep = st -> (st.fresh_only = true; nothing))
         end); paths = [:apg_fresh_only, :apg_fresh_product], maxupd = 300)
    add!("apg_zero_step", 'C', T, :apg, std_make(T, :apg, 30, 10, :raw, 1.5, :cold, :default);
         paths = [:apg_zero_step], maxupd = 5)
    # non-IEEE (and IEEE) loss scales through _significand_exponent / _root_scale
    for (lbl, α) in (("Int", 2), ("Rational", 1 // 2), ("BigFloat", BigFloat(0.5)), ("Bool_rawLS", true),
                     ("Irrational", π), ("Float16", Float16(0.5)), ("Float32", 0.5f0), ("Float64", 0.5))
      add!("apg_alpha_$lbl", 'C', T, :apg, raw_make(() -> begin
             X, y, β = lsq_data(T, 20, 6; seed = 9)
             f = α === true ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
             (; x0 = zeros(T, 6), f, g = NormL1(T(0.05)), method = AccProxGradDescent(), opts = ProximalOptions(; TIGHT_OPTS...))
           end); paths = (α isa Union{Float16,Float32,Float64} ? Symbol[] : [Symbol("apg_alpha_", typeof(α))]), maxupd = 100)
    end
    add!("apg_frob_huge", 'C', T, :apg, raw_make(() -> begin
           (Xv, yv, s) = T === Float32 ? (T(1e20), T(1), 1e-20) : (T(1e160), T(1), 1e-20)
           (; x0 = zeros(T, 1), f = s * LeastSquaresLoss(T[yv], reshape(T[Xv], 1, 1)), g = NormL1(zero(T)),
              method = AccProxGradDescent(), opts = ProximalOptions(; LONG_OPTS...))
         end); paths = [:apg_frobenius_scaled], maxupd = 100)
    add!("apg_frob_tiny", 'C', T, :apg, raw_make(() -> begin
           X, y, β = lsq_data(T, 4, 3; seed = 2)
           tinyv = T === Float32 ? T(1e-30) : T(1e-200)
           (; x0 = zeros(T, 3), f = LeastSquaresLoss(y .* tinyv, X .* tinyv), g = NormL1(zero(T)),
              method = AccProxGradDescent(), opts = ProximalOptions(; maxiter = 50))
         end); paths = [:apg_frobenius_scaled], maxupd = 50)
    add!("apg_nonfinite_y", 'C', T, :apg, raw_make(() -> begin
           val = T === Float32 ? T(1.5f19) : T(1e154)
           X = Matrix{T}(I, 2, 2); y = zeros(T, 2)
           f = LeastSquaresLoss(y, X); g = NormL1(zero(T)); m = AccProxGradDescent()
           (; x0 = zeros(T, 2), f, g, method = m, how = :update, opts = ProximalOptions(; TIGHT_OPTS...),
              prep = st -> begin
                st.x .= T[val, 0]; st.x_previous .= T[-val, 0]
                st.z_x .= X * st.x; st.z_previous .= X * st.x_previous
                st.normx = PS._se_norm(T, st.x); st.normx_previous = PS._se_norm(T, st.x_previous)
                st.f_x = sum(abs2, st.x) / 2; st.g_x = zero(T); st.k = 1000
                nothing
              end)
         end); paths = [:apg_nonfinite_y, :apg_restart], maxupd = 1)
    add!("apg_overflow_rollback", 'C', T, :apg, raw_make(() -> begin
           (Xv, yv) = T === Float32 ? (T(1e20), T(1e-20)) : (T(1e200), T(1e-200))
           (; x0 = zeros(T, 1), f = LeastSquaresLoss(T[yv], reshape(T[Xv], 1, 1)), g = NormL1(zero(T)), method = AccProxGradDescent())
         end); paths = [:apg_overflow_rollback, :next_curvature_error, :eng_rollback, :apg_onepass_to_twopass], maxupd = 5)
    add!("apg_tiny_range", 'C', T, :apg, raw_make(() -> begin
           (Xv, yv) = T === Float32 ? (T(1e10), T(1e-25)) : (T(1e100), T(1e-80))
           (; x0 = zeros(T, 1), f = LeastSquaresLoss(T[yv], reshape(T[Xv], 1, 1)), g = NormL1(zero(T)), method = AccProxGradDescent())
         end); paths = [:apg_onepass_to_twopass], maxupd = 100)
    add!("apg_subnormal_images", 'C', T, :apg, raw_make(() -> begin
           t = nextfloat(zero(T))
           (; x0 = zeros(T, 1), f = LeastSquaresLoss(T[4t], fill(T(0.25), 1, 1)), g = NormL1(0.99 * Float64(t)),
              method = AccProxGradDescent(α = 0.01))
         end); paths = [:apg_diffonepass_to_twopass, :apg_onepass_to_twopass], maxupd = 100)
    for (lbl, c2) in (("exact", 1.0), ("near", T === Float32 ? 1 - 1e-5 : 1 - 1e-13))
      add!("apg_curvature_$lbl", 'C', T, :apg, raw_make(() -> begin
             X = Matrix{T}(sqrt(c2) * I, 8, 8)
             y = T.(cos.(1:8) .* 3)
             (; x0 = zeros(T, 8), f = LeastSquaresLoss(y, X), g = NormL1(T(0.01)), method = AccProxGradDescent(α = 1.0),
                opts = ProximalOptions(; TIGHT_OPTS...))
           end); paths = lbl == "exact" ? [:apg_fresh_product, :apg_fresh_reject] : [:apg_fresh_product, :apg_fresh_accept], maxupd = 100)
    end
    add!("apg_tiny_X", 'C', T, :apg, raw_make(() -> begin
           (Xv, sc) = T === Float32 ? (T(1e-15), 1e30) : (T(1e-150), 1e300)
           (; x0 = zeros(T, 1), f = sc * LeastSquaresLoss(T[Xv], fill(Xv, 1, 1)), g = NormL1(zero(T)),
              method = AccProxGradDescent(), opts = ProximalOptions(; TIGHT_OPTS...))
         end); paths = [:apg_diffonepass_to_twopass, :apg_frobenius_scaled], maxupd = 100)
    add!("apg_wide_range_nonfinite_pair", 'C', T, :apg, raw_make(() -> begin
           # an attempt at W === nothing / D === nothing: large unscaled magnitudes around floatmax
           big = T === Float32 ? T(1e19) : T(1e154)
           X = Matrix{T}(I, 4, 4); y = T[big, -big, big, 1]
           (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(zero(T)), method = AccProxGradDescent(),
              opts = ProximalOptions(; LONG_OPTS...))
         end); paths = [:apg_W_nothing, :apg_norm_nothing], maxupd = 100)
  end
  # engine scenarios (both solvers, both T)
  for T in (Float32, Float64), solver in (:pgd, :apg)
    for (opt, ps) in ((:store, [:eng_store_trace]), (:show, [:eng_show_trace]), (:ext_alone, [:eng_extended_metadata]),
                      (:cb_stop3, [:eng_callback_stop, :eng_callback_called, :eng_extended_metadata]),
                      (:time0, [:eng_time_limit_stop]), (:fcalls, [:eng_f_limit]), (:gradcalls, [:eng_grad_limit]),
                      (:proxcalls, [:eng_prox_limit]), (:allow_inc, [:eng_f_increase_allowed]),
                      (:tight, [:eng_f_increase_stop]), (:inc_stop, [:eng_f_increase_stop]))
      add!("eng_$(solver)_$opt", 'C', T, solver, std_make(T, solver, 60, 25, :inv_n, 0.05, :cold, opt);
           paths = ps, maxupd = 100)
    end
  end
  S
end

# ---- refusals (group D) ----------------------------------------------------------------------
function refusal_scenarios()
  S = Scn[]
  add!(args...; kw...) = push!(S, Scn(args...; kw...))
  for T in (Float32, Float64), solver in (:pgd, :apg)
    sn = string(solver)
    base(; n = 10, p = 4, seed = 7) = lsq_data(T, n, p; seed)
    refuse(name, paths, rx, build) = add!("ref_$(sn)_$name", 'D', T, solver, raw_make(build); paths, expect = rx, maxupd = 0)
    refuse("dim_x", [:refuse_dimension], (DimensionMismatch, r"do not match"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 5), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("dim_y", [:refuse_dimension], (DimensionMismatch, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y[1:end-1], X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("empty_rows", [:refuse_empty], (Exception, r"."), () -> (; x0 = zeros(T, 3), f = LeastSquaresLoss(T[], zeros(T, 0, 3)),
           g = NormL1(T(0.1)), method = default_method(solver)))
    refuse("empty_cols", [:refuse_empty], (Exception, r"."), () -> (; x0 = T[], f = LeastSquaresLoss(zeros(T, 3), zeros(T, 3, 0)),
           g = NormL1(T(0.1)), method = default_method(solver)))
    refuse("nan_X", [:refuse_nonfinite], (ArgumentError, r"finite"), () -> begin
      X, y, β = base(); X[2, 2] = NaN; (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("inf_y", [:refuse_nonfinite], (ArgumentError, r"finite"), () -> begin
      X, y, β = base(); y[3] = Inf; (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("nan_x0", [:refuse_nonfinite], (ArgumentError, r"finite"), () -> begin
      X, y, β = base(); (; x0 = T[0, NaN, 0, 0], f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("lambda_inf", [:refuse_nonfinite], (ArgumentError, r"penalty lambda"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(Inf)), method = default_method(solver)); end)
    refuse("lambda_neg", [:refuse_nonfinite], (Exception, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(-0.1)), method = default_method(solver)); end)
    refuse("keywords", [:refuse_keywords], (ArgumentError, r"unsupported solve! keywords"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         kwargs = (; foo = 1, bar = 2)); end)
    refuse("mixed_types", [:refuse_type], (ArgumentError, r"must be Matrix"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(Float64.(y), Float64.(X)) , g = NormL1(T(0.1)), method = default_method(solver))
      T === Float64 ? (; x0 = zeros(T, 4), f = LeastSquaresLoss(Float32.(y), Float32.(X)), g = NormL1(T(0.1)), method = default_method(solver)) :
                      (; x0 = zeros(T, 4), f = LeastSquaresLoss(Float64.(y), Float64.(X)), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("x_float16", [:refuse_type], (ArgumentError, r"dense Vector"), () -> begin
      X, y, β = base(); (; x0 = zeros(Float16, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("x_int", [:refuse_type], (ArgumentError, r"dense Vector"), () -> begin
      X, y, β = base(); (; x0 = zeros(Int, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("sparse_X", [:refuse_type], (Exception, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, sparse(X)), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("loss_not_ls", [:refuse_type], (ArgumentError, r"only LeastSquaresLoss"), () ->
      (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(0.1)), method = default_method(solver)))
    refuse("alias_y", [:refuse_alias], (ArgumentError, r"alias"), () -> begin
      X, y, β = lsq_data(T, 4, 4; seed = 3); (; x0 = y, f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver), alias = true); end)
    refuse("scale_neg", [:refuse_scale], (ArgumentError, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = (-1.0) * LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("scale_nan", [:refuse_scale], (ArgumentError, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = NaN * LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    refuse("scale_underflow", [:refuse_scale], (ArgumentError, r"."), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = 1e-400 * LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    if T === Float32
    refuse("scale_underflow_f32", [:refuse_scale], (ArgumentError, r"loss scale"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = 1e-60 * LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver)); end)
    end
    refuse("opts_maxiter1", [:refuse_options], (ArgumentError, r"maxiter"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         opts = ProximalOptions(maxiter = 1)); end)
    refuse("opts_ftol0", [:refuse_options], (ArgumentError, r"ftol"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         opts = ProximalOptions(ftol = 0)); end)
    refuse("opts_gaptol", [:refuse_options], (ArgumentError, r"gap"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         opts = ProximalOptions(gaptol = 1.0)); end)
    refuse("opts_timenan", [:refuse_options], (ArgumentError, r"time_limit"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         opts = ProximalOptions(time_limit = NaN)); end)
    refuse("opts_tolunderflow", [:refuse_options], (ArgumentError, r"xtol"), () -> begin
      X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)), method = default_method(solver),
                         opts = ProximalOptions(xtol = 1e-400)); end)
    if solver === :pgd
      refuse("m_normalized", [:refuse_method], (ArgumentError, r"normalized"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = ProximalGradientDescent(normalized = true)))
      refuse("m_debias", [:refuse_method], (ArgumentError, r"debias"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = ProximalGradientDescent(debias = 2)))
      refuse("m_precond", [:refuse_method], (ArgumentError, r"precondition"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = ProximalGradientDescent(preconditioner = :diagonal)))
      refuse("m_ls_custom", [:refuse_method], (ArgumentError, r"only BackTracking"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = ProximalGradientDescent(ls = 1)))
      refuse("m_ls_bad", [:refuse_method], (ArgumentError, r"backtracking needs"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = ProximalGradientDescent(ls = PS.LineSearches.BackTracking(β = 1.5))))
    else
      refuse("m_beta", [:refuse_method], (ArgumentError, r"β"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = AccProxGradDescent(β = 1.5)))
      refuse("m_alpha", [:refuse_method], (ArgumentError, r"α"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = AccProxGradDescent(α = 0.0)))
      refuse("m_precond", [:refuse_method], (ArgumentError, r"precondition"), () ->
        (; x0 = zeros(T, 4), f = NormL1(T(1)), g = NormL1(T(1)), method = AccProxGradDescent(preconditioner = :diagonal)))
      if T === Float32      # for Float64 data this beta is valid and the line search would need ~1e13 trials
      refuse("m_after_conversion", [:refuse_method], (ArgumentError, r"after conversion"), () -> begin
        X, y, β = base(); (; x0 = zeros(T, 4), f = LeastSquaresLoss(y, X), g = NormL1(T(0.1)),
                           method = AccProxGradDescent(β = 1 - 1e-12)); end)
      end
      if T === Float32
        refuse("bound_size", [:refuse_bound_size], (ArgumentError, r"needs max\(n, p\)"), () -> begin
          p = 2_100_000
          (; x0 = zeros(Float32, p), f = LeastSquaresLoss(Float32[1], zeros(Float32, 1, p)), g = NormL1(0.1f0),
             method = AccProxGradDescent()); end)
      end
    end
  end
  S
end

# ---- the full corpus -------------------------------------------------------------------------
const SIZES_A = [(4, 3), (12, 7), (20, 16), (31, 31), (32, 32), (33, 31), (64, 20), (100, 31), (100, 32), (100, 33),
                 (200, 64), (40, 150), (300, 12), (1100, 8), (24, 1030), (60, 1100)]
const SIZES_B = [(12, 7), (31, 33), (100, 32), (60, 40)]

function corpus_cases(; nfuzz = 7900, with_f = true)
  S = Scn[]
  # A: sizes x loss x lambda x start x T x solver, default options
  for (n, p) in SIZES_A, T in (Float32, Float64), solver in (:pgd, :apg), loss in (:raw, :inv_n, :inv_n_f64),
      λf in (0.0, 0.01, 0.3, 1.5), start in (:cold, :warm)
    nm = "A:$(solver):$(T):$(n)x$(p):$(loss):l$(λf):$(start)"
    push!(S, Scn(nm, 'A', T, solver, std_make(T, solver, n, p, loss, λf, start, :default)))
  end
  # B: option variants on a few sizes
  for opt in OPTION_NAMES, (n, p) in SIZES_B, T in (Float32, Float64), solver in (:pgd, :apg), λf in (0.05, 0.5),
      loss in (:raw, :inv_n), start in (:cold, :warm2)
    nm = "B:$(solver):$(T):$(n)x$(p):$(loss):l$(λf):$(start):$(opt)"
    push!(S, Scn(nm, 'B', T, solver, std_make(T, solver, n, p, loss, λf, start, opt)))
  end
  # C, D: the W2 scenarios and the refusals
  for s in vcat(w2_scenarios(), refusal_scenarios())
    push!(S, Scn(string(s.group, ":", s.name, ":", s.T), s.group, s.T, s.solver, s.make, s.paths, s.expect, s.maxupd))
  end
  # E: seeded fuzz
  rng = Xoshiro(20261113)
  λfs = (0.0, 1e-3, 0.05, 0.5, 2.0)
  losses = (:raw, :inv_n, :inv_n_f64, :half)
  for i in 1:nfuzz
    n = clamp(round(Int, exp(rand(rng) * log(160.0))), 1, 160)
    p = clamp(round(Int, exp(rand(rng) * log(160.0))), 1, 160)
    T = rand(rng, Bool) ? Float32 : Float64
    solver = rand(rng, Bool) ? :pgd : :apg
    loss = losses[rand(rng, 1:4)]
    λf = λfs[rand(rng, 1:5)]
    start = (:cold, :warm, :warm2)[rand(rng, 1:3)]
    opt = OPTION_NAMES[rand(rng, 1:length(OPTION_NAMES))]
    ρ = rand(rng) < 0.2 ? 0.9 : 0.0
    xs = (1.0, 1.0, 1.0, 0.01, 100.0)[rand(rng, 1:5)]
    seed = rand(rng, 1:10^9)
    nm = "E:$(i):$(solver):$(T):$(n)x$(p):$(loss):l$(λf):$(start):$(opt):r$(ρ):s$(xs)"
    push!(S, Scn(nm, 'E', T, solver, std_make(T, solver, n, p, loss, λf, start, opt; seed, ρ, xscale = xs)))
  end
  # F: ftol = 0 (#270, master 3408e1f); appended after E, so the order and keys of A-E do not change
  with_f && append!(S, f0_scenarios())
  S
end

# group F (ftol = 0, #270)
include(joinpath(@__DIR__, "corpus_f.jl"))
