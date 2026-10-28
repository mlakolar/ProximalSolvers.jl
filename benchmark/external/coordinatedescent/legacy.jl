import CoordinateDescent, ProximalBase

const LEGACY = CoordinateDescent

function legacy_cd_options(settings)
  # v0.6.1 src/utils.jl:77-91: preserve automatic momentum and all public defaults.
  LEGACY.CDOptions(maxIter = settings["maxIter"], optTol = settings["optTol"],
    order = Symbol(settings["order"]), warmStart = settings["warmStart"],
    numSteps = settings["numSteps"], relativeTol = settings["relativeTol"],
    anderson = settings["anderson"],
    momentum = settings["momentum"] == "default" ? nothing : settings["momentum"])
end

function legacy_iter_options(settings)
  # v0.6.1 src/utils.jl:167-174: explicit shared initialization and outer tolerances.
  LEGACY.IterLassoOptions(maxIter = settings["maxIter"], optTol = settings["optTol"],
    initProcedure = Symbol(settings["initProcedure"]), sinit = settings["sinit"],
    σinit = settings["sigma_init"], optionsCD = legacy_cd_options(settings["optionsCD"]))
end

function legacy_solution(result, settings)
  # v0.6.1 src/lasso.jl:27-34: .x is on the original coefficient scale.
  info = Dict{String,Any}("iterations" => result.iterations, "converged" => result.converged,
    "intercept" => result.intercept, "gram_policy" => settings["gram_policy"])
  result.σ === nothing || (info["sigma"] = result.σ)
  (; β = Vector{Float64}(result.x), info)
end

function run_case(case::Dict, data::NamedTuple, settings::Dict)
  a, kind = data, case["estimator"]
  settings["intercept"] === false || error("this suite requires intercept=false")
  if kind == "lasso"
    # v0.6.1 src/lasso.jl:68-99: LS is normalized by n; weighted form has no scaling keyword.
    settings["standardizeX"] === false || error("standardization is disabled")
    result = LEGACY.lasso(a.X, a.y, a.λ, legacy_cd_options(settings);
      intercept = false, standardizeX = false)
  elseif kind == "weighted_lasso"
    result = LEGACY.lasso(a.X, a.y, a.λ, copy(a.Γ), legacy_cd_options(settings); intercept = false)
  elseif kind == "path"
    # v0.6.1 src/lasso.jl:462-518: explicit levels, warm starts, strong screening, no truncation.
    settings["standardizeX"] === false && settings["screening"] === true &&
      settings["max_hat_s"] == "Inf" || error("invalid path objective settings")
    path = LEGACY.LassoPath(a.X, a.y, copy(a.λs), legacy_cd_options(settings);
      intercept = false, standardizeX = false, screening = true, max_hat_s = Inf)
    # v0.6.1 src/lasso.jl:424-431: archive every level, including screening diagnostics.
    return (; βs = [Vector{Float64}(β) for β in path.βpath], λs = copy(path.λpath),
      info = Dict{String,Any}("iterations" => sum(path.iterations),
        "iterations_by_level" => path.iterations, "converged" => all(path.converged),
        "converged_by_level" => path.converged, "kkt_checks" => path.kktChecks,
        "gram_policy" => "residual"))
  elseif kind in ("quadratic", "group_lasso")
    options = legacy_cd_options(settings)
    if kind == "quadratic"
      # v0.6.1 src/cd_differentiable_function.jl:728-755: β'Aβ/2+b'β.
      x = ProximalBase.SparseIterate(copy(a.β0))
      loss = LEGACY.CDQuadraticLoss(a.A, a.b)
      penalty = ProximalBase.ProxL1(a.λ)
    else
      # v0.6.1 src/coordinate_descent.jl:35-49,195-242: groups are atoms, with unit weights.
      settings["standardize"] == "none" || error("standardization is disabled")
      penalty = ProximalBase.ProxGroupL2(a.λ, a.groups, copy(a.w_group))
      x = ProximalBase.AtomIterate(a.p, penalty)
      loss = LEGACY.CDLeastSquaresLoss(a.y, a.X; intercept = false)
    end
    info = LEGACY.CDInfo()
    # v0.6.1 src/coordinate_descent.jl:98-160,195-242: return is x; CDInfo holds stopping data.
    LEGACY.coordinateDescent!(x, loss, penalty, options, info)
    return (; β = Vector{Float64}(x), info = Dict{String,Any}("iterations" => info.iterations,
      "converged" => info.converged, "gram_policy" => settings["gram_policy"]))
  elseif kind == "sqrt_lasso"
    # v0.6.1 src/lasso.jl:124-149: the API uses ||r||, so λ_api = sqrt(n)*λ.
    settings["standardizeX"] === false || error("standardization is disabled")
    result = LEGACY.sqrtLasso(a.X, a.y, sqrt(a.n) * a.λ, legacy_cd_options(settings);
      intercept = false, standardizeX = false)
  elseif kind == "scaled_lasso"
    # v0.6.1 src/lasso.jl:224-240,278-285: it performs the sqrt(n) conversion internally.
    # Explicit ω supplies the fixed penalty weights without any standardization.
    result = LEGACY.scaledLasso(a.X, a.y, a.λ, copy(a.w), legacy_iter_options(settings); intercept = false)
  elseif kind == "feasible_lasso"
    # v0.6.1 src/lasso.jl:322-370: Γ is updated in place after the final fit.
    # Neither this returned penalty nor its last update enters the certificate.
    x = ProximalBase.SparseIterate(copy(a.β0))
    result = LEGACY.feasibleLasso!(x, a.X, a.y, a.λ, legacy_iter_options(settings); intercept = false)
  else
    error("unsupported estimator $kind")
  end
  legacy_solution(result, settings)
end
