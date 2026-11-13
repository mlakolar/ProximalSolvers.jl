# instrument.jl: counters on the branches of the solver core, by re-evaluating a text-transformed copy of
# individual function definitions inside the loaded package module. No tracked file is edited; the change
# lives in one Julia process only. Every anchor must occur exactly once or the probe fails loudly.
# Hits are counted in Main.HITS through Main.__hit.
const HITS = Dict{Symbol,Int}()
__hit(s::Symbol) = (HITS[s] = get(HITS, s, 0) + 1; nothing)
hits_snapshot() = copy(HITS)
hits_reset!() = empty!(HITS)

function instrument_function!(mod::Module, file::AbstractString, start::Regex, repls::Vector{Pair{String,String}})
  lines = readlines(file; keep = true)
  i0 = findfirst(l -> occursin(start, l), lines)
  i0 === nothing && error("instrument: no line matches $start in $file")
  i1 = findnext(l -> l == "end\n" || l == "end", lines, i0)
  i1 === nothing && error("instrument: no closing end for $start in $file")
  text = join(lines[i0:i1])
  for (a, b) in repls
    n = count(a, text)
    n == 1 || error("instrument: anchor occurs $n times (expected 1) in $(basename(file)) for $start:\n$a")
    text = replace(text, a => b; count = 1)
  end
  Base.include_string(mod, text, "instrumented:" * basename(file))
  nothing
end

function instrument_core!(tree::AbstractString)
  src(f) = joinpath(tree, "src", f)
  LS = PS.LineSearches
  # ---- line searches (PGD) ----
  instrument_function!(LS, src("line_searches.jl"), r"^function next_curvature\(", [
    "isfinite(next) && next > L || error(" => "isfinite(next) && next > L || (Main.__hit(:next_curvature_error); error(",
    "cannot increase finitely\")\n" => "cannot increase finitely\"))\n"])
  instrument_function!(LS, src("line_searches.jl"), r"^function backtrack!\(", [
    "    if xy_sq == zero(T) && isfinite(state.f_x)\n" =>
      "    if xy_sq == zero(T) && isfinite(state.f_x)\n      Main.__hit(state.backtrack_simple ? :pgd_zero_step_simple : :pgd_zero_step_gradient)\n",
    "    if !isfinite(state.f_x)\n        state.backtrack_steps += 1\n" =>
      "    if !isfinite(state.f_x)\n        Main.__hit(:pgd_nonfinite_trial)\n        state.backtrack_steps += 1\n",
    "        if !state.backtrack_simple\n            value_and_gradient_at_x!(state, f)\n            state.f_calls += 1\n            state.grad_calls += 1\n        end\n    else\n" =>
      "        if !state.backtrack_simple\n            Main.__hit(:pgd_mode_switch)\n            value_and_gradient_at_x!(state, f)\n            state.f_calls += 1\n            state.grad_calls += 1\n        end\n    else\n        Main.__hit(:pgd_gradient_mode_trial)\n",
    "    (local_l <= state.L || state.L >= ls.Lexact) && return true\n" =>
      "    if local_l <= state.L\n      Main.__hit(:pgd_exit_local)\n      return true\n    end\n    if state.L >= ls.Lexact\n      Main.__hit(:pgd_exit_lexact)\n      return true\n    end\n"])
  # ---- engine ----
  instrument_function!(PS, src("utils.jl"), r"^function trace!\(", [
    "    if options.extended_trace && iteration > 0\n" =>
      "    if options.extended_trace && iteration > 0\n        Main.__hit(:eng_extended_metadata)\n",
    "    options.store_trace && push!(tr, os)\n" => "    options.store_trace && (Main.__hit(:eng_store_trace); push!(tr, os))\n",
    "    options.show_trace && mod(iteration, options.print_every) == 0 && show(os)\n" =>
      "    options.show_trace && mod(iteration, options.print_every) == 0 && (Main.__hit(:eng_show_trace); show(os))\n",
    "    options.store_trace ? options.callback(tr) : options.callback(os)\n" =>
      "    Main.__hit(:eng_callback_called)\n    options.store_trace ? options.callback(tr) : options.callback(os)\n"])
  instrument_function!(PS, src("solve.jl"), r"^function _solve_gradient!\(", [
    "    catch\n      # Trials overwrite x for allocation-free iteration. An unsuccessful\n" =>
      "    catch\n      Main.__hit(:eng_rollback)\n      # Trials overwrite x for allocation-free iteration. An unsuccessful\n",
    "      stopped_by_callback = trace!(tr, f, g, state, iteration, method, options)\n" =>
      "      stopped_by_callback = trace!(tr, f, g, state, iteration, method, options)\n      stopped_by_callback && Main.__hit(:eng_callback_stop)\n",
    "    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false\n" =>
      "    stopped_by_time_limit = time()-t0 > options.time_limit ? true : false\n    stopped_by_time_limit && Main.__hit(:eng_time_limit_stop)\n",
    "    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit\n" =>
      "    prox_limit_reached = options.prox_calls_limit > 0 && state.prox_calls >= options.prox_calls_limit\n    f_limit_reached && Main.__hit(:eng_f_limit)\n    grad_limit_reached && Main.__hit(:eng_grad_limit)\n    prox_limit_reached && Main.__hit(:eng_prox_limit)\n",
    "    increased = f_increased && !options.allow_f_increases\n" =>
      "    increased = f_increased && !options.allow_f_increases\n    increased && Main.__hit(:eng_f_increase_stop)\n    (f_increased && options.allow_f_increases) && Main.__hit(:eng_f_increase_allowed)\n"])
  # ---- APG ----
  instrument_function!(PS, src("solvers/image_models.jl"), r"^function _se_norm_onepass\(", [
    "  _se_norm(T, v)\n" => "  Main.__hit(:apg_onepass_to_twopass)\n  _se_norm(T, v)\n"])
  instrument_function!(PS, src("solvers/image_models.jl"), r"^function _se_norm_diff_onepass\(", [
    "  _se_norm_diff(T, a, b)\n" => "  Main.__hit(:apg_diffonepass_to_twopass)\n  _se_norm_diff(T, a, b)\n"])
  instrument_function!(PS, src("solvers/image_models.jl"), r"^function _frobenius_upper\(", [
    "  if !(isfinite(s) && (T === Float32 || s >= 4N * floatmin(Float64)))\n" =>
      "  if !(isfinite(s) && (T === Float32 || s >= 4N * floatmin(Float64)))\n    Main.__hit(:apg_frobenius_scaled)\n"])
  instrument_function!(PS, src("solvers/image_models.jl"), r"^_significand_exponent\(α::Real\)", [
    "_significand_exponent(α::Real) = setprecision(BigFloat, 256) do\n" =>
      "_significand_exponent(α::Real) = setprecision(BigFloat, 256) do\n  Main.__hit(Symbol(\"apg_alpha_\", typeof(α)))\n"])
  instrument_function!(PS, src("solvers/image_models.jl"), r"^function _bound_certified!\(", [
    "  if !fresh_only\n" => "  fresh_only && Main.__hit(:apg_fresh_only)\n  if !fresh_only\n",
    "    if N !== nothing\n" => "    N === nothing && Main.__hit(:apg_cached_norm_nothing)\n    if N !== nothing\n",
    "      _se_le(_se_mul(rootα, upper), accept_rhs) && return true, false\n" =>
      "      _se_le(_se_mul(rootα, upper), accept_rhs) && (Main.__hit(:apg_accept_cached); return true, false)\n",
    "      _se_le(_se_mul(rootα, lower), _se_mul(c.reject, rootL, c.upper_step, D)) || return false, false\n" =>
      "      _se_le(_se_mul(rootα, lower), _se_mul(c.reject, rootL, c.upper_step, D)) || (Main.__hit(:apg_early_reject); return false, false)\n",
    "  mul!(buf, model.X, d)\n" => "  Main.__hit(:apg_fresh_product)\n  mul!(buf, model.X, d)\n",
    "  W === nothing && return false, true\n" => "  W === nothing && (Main.__hit(:apg_W_nothing); return false, true)\n",
    "  _se_le(_se_mul(rootα, upper), accept_rhs), true\n" =>
      "  r_fresh = _se_le(_se_mul(rootα, upper), accept_rhs)\n  Main.__hit(r_fresh ? :apg_fresh_accept : :apg_fresh_reject)\n  r_fresh, true\n"])
  instrument_function!(PS, src("solvers/accelerated_proximal_gradient_descent.jl"), r"^function _prox_grad_step!\(", [
    "    if !(isfinite(state.f_y) && _allfinite(state.grad_f_y))\n" =>
      "    if !(isfinite(state.f_y) && _allfinite(state.grad_f_y))\n        Main.__hit(:apg_nonfinite_y)\n",
    "        if normx !== nothing && D !== nothing\n" =>
      "        if normx === nothing || D === nothing\n          Main.__hit(:apg_norm_nothing)\n        end\n        if normx !== nothing && D !== nothing\n",
    "          if iszero(D.s)\n" => "          if iszero(D.s)\n            Main.__hit(:apg_zero_step)\n",
    "      state.L = LineSearches.next_curvature(state.L, β)\n" =>
      "      Main.__hit(:apg_L_raised)\n      state.L = LineSearches.next_curvature(state.L, β)\n"])
  nothing
end
