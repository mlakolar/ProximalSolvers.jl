import HighDimensionalModels, ProximalBase, ProximalSolvers

const CURRENT = HighDimensionalModels

function current_cd_options(settings)
  # 5e89ef4 src/utils.jl:135-144,170-179: nothing keeps the path gap default;
  # zero selects coordinate stopping, and positive gaptol replaces it for LS/group fits.
  CURRENT.CDOptions(max_iter = settings["max_iter"], opt_tol = settings["opt_tol"],
    order = Symbol(settings["order"]), warm_start = settings["warm_start"],
    num_steps = settings["num_steps"], relative_tol = settings["relative_tol"],
    anderson = settings["anderson"],
    momentum = settings["momentum"] == "default" ? nothing : settings["momentum"],
    gaptol = settings["gaptol"] == "default" ? nothing : settings["gaptol"])
end

function current_iter_options(settings)
  # 5e89ef4 src/utils.jl:282-285: outer defaults match v0.6.1, including Screening and sinit=5.
  CURRENT.IterLassoOptions(max_iter = settings["max_iter"], opt_tol = settings["opt_tol"],
    init_procedure = Symbol(settings["init_procedure"]), sinit = settings["sinit"],
    σinit = settings["sigma_init"], options_cd = current_cd_options(settings["options_cd"]))
end

function current_gram_info(case, data, settings)
  kind = case["estimator"]
  policy = settings["gram_policy"]
  # 5e89ef4 src/lasso.jl:124-136: :auto chooses Gram only for a dense path,
  # n >= p and p <= 2000; artifact designs are dense. The primary call omits gram.
  # ProximalSolvers src/cd/gap.jl:167-169: QuadModel has no gap stopping,
  # so the automatic Gram path keeps the coordinate-change rule.
  used = kind == "quadratic" || (kind == "path" && data.n >= data.p && data.p <= 2000)
  haskey(settings, "gram") && (used = settings["gram"])
  Dict{String,Any}("gram_policy" => policy, "gram_used" => used)
end

function run_case(case::Dict, data::NamedTuple, settings::Dict)
  a, kind = data, case["estimator"]
  settings["intercept"] === false || error("this suite requires intercept=false")
  gram_kw = haskey(settings, "gram") ? (; gram = settings["gram"]) : (;)
  if kind == "lasso"
    # 5e89ef4 src/lasso.jl:256-265,382-444: λ is normalized LS level; .x is the original scale.
    settings["standardize_x"] === false || error("standardization is disabled")
    result = CURRENT.lasso(a.X, a.y, a.λ, current_cd_options(settings);
      intercept = false, standardize_x = false, gram_kw...)
  elseif kind == "weighted_lasso"
    # 5e89ef4 src/lasso.jl:423-444: explicit loadings bypass standardize_x.
    result = CURRENT.lasso(a.X, a.y, a.λ, copy(a.Γ), current_cd_options(settings);
      intercept = false, gram_kw...)
  elseif kind == "path"
    # 5e89ef4 src/lasso.jl:924-979: explicit grid, screening and no support truncation.
    settings["standardize_x"] === false && settings["screening"] === true &&
      settings["max_hat_s"] == "Inf" || error("invalid path objective settings")
    path = CURRENT.LassoPath(a.X, a.y, copy(a.λs), current_cd_options(settings);
      intercept = false, standardize_x = false, screening = true, max_hat_s = Inf, gram_kw...)
    # 5e89ef4 src/lasso.jl:859-870,979: fields retain every level and kkt_checks.
    info = merge(current_gram_info(case, a, settings), Dict{String,Any}(
      "iterations" => sum(path.iterations), "iterations_by_level" => path.iterations,
      "converged" => all(path.converged), "converged_by_level" => path.converged,
      "kkt_checks" => path.kkt_checks))
    return (; βs = [Vector{Float64}(β) for β in path.βpath], λs = copy(path.λpath), info)
  elseif kind == "quadratic"
    # 5e89ef4 src/coordinate_descent.jl:126-144: CDResults reports passes/converged.
    # 5e89ef4 src/losses.jl:96-114: CDQuadraticLoss(A,b) uses β'Aβ/2+b'β.
    x = ProximalBase.SparseIterate(copy(a.β0))
    loss = CURRENT.CDQuadraticLoss(a.A, a.b)
    result = CURRENT.coordinate_descent!(x, loss, ProximalBase.NormL1(a.λ), current_cd_options(settings))
    return (; β = Vector{Float64}(x), info = merge(current_gram_info(case, a, settings),
      Dict{String,Any}("iterations" => result.passes, "converged" => result.converged)))
  elseif kind == "group_lasso"
    # 5e89ef4 src/group.jl:130-167: override intercept=true, orthonormalization
    # and sqrt(group size) weights; .x is already mapped back to original columns.
    settings["standardize"] == "none" || error("standardization is disabled")
    result = CURRENT.group_lasso(a.X, a.y, a.λ, a.groups, current_cd_options(settings);
      intercept = false, standardize = :none, groupweights = copy(a.w_group))
  elseif kind == "sqrt_lasso"
    # 5e89ef4 src/lasso.jl:466-518: ||r|| is unnormalized, λ_api = sqrt(n)*λ.
    settings["standardize_x"] === false || error("standardization is disabled")
    result = CURRENT.sqrt_lasso(a.X, a.y, sqrt(a.n) * a.λ, current_cd_options(settings);
      intercept = false, standardize_x = false, gram_kw...)
  elseif kind == "scaled_lasso"
    # 5e89ef4 src/lasso.jl:603-627,676-683: sqrt(n) is internal; σ=||r||/sqrt(n).
    # Its gaptol is a final check; the ladder sweeps options_cd.opt_tol instead.
    result = CURRENT.scaled_lasso(a.X, a.y, a.λ, copy(a.w), current_iter_options(settings); intercept = false)
  elseif kind == "feasible_lasso"
    # 5e89ef4 src/lasso.jl:727-770: the returned penalty belongs to the last fit.
    # Residual-based certification ignores it, matching the legacy adapter.
    x = ProximalBase.SparseIterate(copy(a.β0))
    result = CURRENT.feasible_lasso!(x, a.X, a.y, a.λ, current_iter_options(settings); intercept = false)
  else
    error("unsupported estimator $kind")
  end
  # 5e89ef4 src/lasso.jl:39-49 and src/group.jl:116-127: coefficients and diagnostics.
  info = merge(current_gram_info(case, a, settings), Dict{String,Any}(
    "iterations" => result.iterations, "converged" => result.converged, "intercept" => result.intercept))
  hasproperty(result, :σ) && result.σ !== nothing && (info["sigma"] = result.σ)
  (; β = Vector{Float64}(result.x), info)
end
