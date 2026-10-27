struct CaseSpec
  meta::NamedTuple
  make::Function
end

struct CaseState{R,C,V}
  reset!::R
  call!::C
  certify::V
  problem_hash::String
end

struct IncompletePath <: Exception
  detail::String
end

Base.showerror(io::IO, err::IncompletePath) = print(io, err.detail)

const CASE_GROUPS = ("cd", "paths", "gradient", "newton", "admm", "primal_dual",
                     "nonconvex", "slope", "sgl")

function benchmark_options(; historical = false, residual = false)
  ProximalSolvers.ProximalOptions(maxiter = historical ? 5000 : 10_000,
    ftol = historical ? 1e-14 : 1e-15, xtol = 1e-14,
    gradtol = historical ? 1e-9 : 1e-11,
    gaptol = residual ? 0.0 : historical ? 1e-8 : 1e-10, gapevery = 10)
end

function benchmark_model(a)
  PB = ProximalBase
  if a.kind == :logistic
    loss = all(isone, a.w_obs) && all(iszero, a.offset) ? PB.LogisticLoss(a.y, a.X) :
      PB.LogisticLoss(a.y, a.X; weights = a.w_obs, offset = a.offset)
    return a.s * loss, PB.NormL1(a.λ)
  elseif a.kind == :sqrt_lasso
    return ProximalSolvers.SqrtLeastSquaresLoss(a.y, a.X), PB.NormL1(a.λ)
  elseif a.kind == :quadratic
    return PB.QuadraticFunction(a.A, -a.b, a.c), PB.NormL1(a.λ)
  elseif a.kind == :glasso
    return PB.LogDetLoss(a.S), PB.NormL1(1.0, a.Λ)
  end
  f = a.s * PB.LeastSquaresLoss(a.y, a.X)
  if a.kind == :group
    return f, PB.GroupNormL2(a.λ, a.groups, a.w_group)
  elseif a.kind == :sparse_group
    return f, PB.SparseGroupNormL2(a.λ * a.α, a.λ * (1 - a.α), a.groups, a.w_group)
  elseif a.kind == :slope
    return f, PB.SLOPE(a.λ)
  elseif a.kind == :mcp
    return f, PB.MCP(a.λ, a.a)
  elseif a.kind == :scad
    return f, PB.SCAD(a.λ, a.a)
  elseif a.kind == :iht
    return f, PB.IndBallL0(a.k)
  end
  penalty = all(isone, a.w) ? PB.NormL1(a.λ) : PB.NormL1(a.λ, a.w)
  f, penalty
end

function benchmark_method(solver, variant; gap = true)
  PS = ProximalSolvers
  solver == "pg" && return PS.ProximalGradientDescent()
  solver == "apg" && return PS.AccProxGradDescent()
  solver == "monotone" && return PS.MonotoneAccProxGradDescent()
  solver == "active" && return PS.ActiveAccProxGradDescent()
  solver == "diagonal" && return PS.ProximalGradientDescent(preconditioner = :diagonal)
  if solver == "cd"
    variant == "R" && return PS.CDSolver(rng = Xoshiro(9))
    variant == "B" && return PS.CDSolver(order = :cyclic, gaptol = 1e-8)
    return PS.CDSolver(order = :cyclic, tol = 1e-11, gaptol = gap ? 1e-10 : 0.0, rng = Xoshiro(9))
  elseif solver == "random-cd"
    return PS.CDSolver(tol = 1e-11, gaptol = 1e-10, rng = Xoshiro(9))
  elseif solver == "prox-newton"
    variant == "R" && return PS.ProxNewton()
    return PS.ProxNewton(tol = 1e-12, inner = PS.CDSolver(tol = 1e-10, order = :cyclic))
  elseif solver == "quic"
    return PS.ProxNewton(tol = 1e-11, inner = PS.CDSolver(tol = 1e-11, order = :cyclic))
  elseif solver == "admm"
    variant == "R" && return PS.ADMMSolver()
    return PS.ADMMSolver(abstol = 1e-10, reltol = 1e-9)
  elseif solver == "slope-apg"
    return PS.SLOPEAPG(tol = 1e-11, maxiter = 20_000)
  elseif solver == "slope-hybrid"
    return PS.SLOPEHybrid(tol = 1e-11, maxiter = 20_000)
  end
  error("unknown solver $solver")
end

function reset_solver_rng!(method)
  if method isa ProximalSolvers.CDSolver
    # _CDState shares method.rng. Re-seeding it resets every random pass, for
    # both public calls and workspaces; each pass rebuilds its permutation.
    Random.seed!(method.rng, 9)
  elseif method isa ProximalSolvers.ProxNewton
    reset_solver_rng!(method.inner)
  end
  nothing
end

function benchmark_start(a, variant, solver)
  if a.kind == :glasso
    return Matrix{Float64}(I, size(a.S, 1), size(a.S, 1))
  elseif a.kind in (:group, :sparse_group)
    return ProximalBase.AtomIterate(size(a.X, 2), a.groups)
  elseif a.kind == :logistic && variant == "B" && solver == "prox-newton"
    return ProximalBase.SparseIterate(size(a.X, 2))
  end
  zeros(size(a.X, 2))
end

function solve_case_state(a, solver, variant, phase)
  PS = ProximalSolvers
  f, g = benchmark_model(a)
  method = benchmark_method(solver, variant; gap = !(a.kind in (:quadratic, :sqrt_lasso)))
  x = benchmark_start(a, variant, solver)
  start = copy(x)
  historical = variant in ("R", "B")
  options = variant == "R" ? PS.ProximalOptions() :
    benchmark_options(; historical, residual = a.kind in (:quadratic, :mcp, :scad, :iht))
  own_options = method isa Union{PS.CDSolver,PS.ProxNewton,PS.SLOPEAPG,PS.SLOPEHybrid}
  if phase == "workspace"
    workspace = own_options ? PS.SolverWorkspace(x, f, g, method) :
      PS.SolverWorkspace(x, f, g, method, options)
    reset! = () -> (PS.reinit!(workspace, start); reset_solver_rng!(method); nothing)
    call! = () -> PS.solve!(workspace)
  else
    # B times solve! on a reset iterate; the historical script times a fresh zeros(p) allocation too.
    reset! = () -> (copyto!(x, start); reset_solver_rng!(method); nothing)
    call! = () -> own_options ? PS.solve!(x, f, g, method) : PS.solve!(x, f, g, method, options)
  end
  check = function (output)
    cert = certify(a, Array(output.minimizer))
    if a.kind == :quadratic && variant == "dual-gap"
      cert.status == :ok || return uncertifiable(cert.detail)
      scale = a.s * sum(abs2, a.y) / 2 + a.λ * dot(a.w, abs.(output.minimizer))
      return relative_certificate(cert.primal, cert.dual; scale, terms = max(size(a.X)..., 1))
    end
    cert
  end
  CaseState(reset!, call!, check, data_hash(a))
end

function checked_path(a, output, grid; slope = false)
  returned = slope ? output.lambda : output.λ
  certs = Certificate[]
  for (level, β) in zip(returned, output.solutions)
    current = merge(a, (; λ = slope ? level .* a.λ : level))
    push!(certs, certify(current, Array(β)))
  end
  # Certify even the levels of an incomplete output before rejecting its grid.
  complete = length(returned) == length(grid) == length(output.solutions) && returned == grid
  complete || throw(IncompletePath("returned $(length(output.solutions)) of $(length(grid)) requested levels"))
  path_certificate(certs)
end

function path_case_state(a, solver; levels = 8)
  PS = ProximalSolvers
  f, g = benchmark_model(a)
  slope = a.kind == :slope
  if slope
    base = cumsum(a.λ)
    z = cumsum(sort!(abs.(a.s .* (a.X' * a.y)); rev = true))
    top = maximum(z ./ base)
    grid = lambda_grid(top, 0.1, levels)
    x = zeros(size(a.X, 2))
  else
    grid = lambda_grid(lambda_max(a.X, a.y; s = a.s, w = a.w), 0.1, levels)
    x = ProximalBase.SparseIterate(size(a.X, 2))
  end
  method = benchmark_method(solver, "tight")
  reset!() = (fill!(x, 0.0); reset_solver_rng!(method); nothing)
  call!() = PS.solve_path(f, g, grid, method; x, screening = true)
  check(output) = checked_path(a, output, grid; slope)
  CaseState(reset!, call!, check, data_hash(merge(a, (; grid))))
end

function primal_dual_case_state(a)
  PS, PB = ProximalSolvers, ProximalBase
  f = PB.Sum(a.s * PB.LeastSquaresLoss(a.y, a.X), PB.SqrNormL2(a.μ))
  g, h = PB.NormL1(a.λ1), PB.NormL1(a.λ2)
  L = a.s * opnorm(a.X)^2 + a.μ
  norm_d = sqrt(opnorm(a.D, 1) * opnorm(a.D, Inf))
  method = PS.CondatVu(; L, norm_d, abstol = 1e-10, reltol = 1e-9)
  options = benchmark_options()
  x, y = zeros(size(a.X, 2)), zeros(size(a.D, 1))
  gap(x, y) = certify(a, (; x, y)).value
  reset!() = (fill!(x, 0.0); fill!(y, 0.0); nothing)
  call!() = PS.solve!(x, f, g, h, a.D, method, options; y, gap)
  check(output) = certify(a, (; x = output.minimizer, y = output.y))
  CaseState(reset!, call!, check, data_hash(a))
end

function setup_case_state(a, solver)
  PB = ProximalBase
  if solver == "admm"
    call! = function ()
      loss = PB.LeastSquaresLoss(a.y, a.X)
      # ADMM's least-squares prox caches an SVD, rather than a Cholesky factor.
      PB._svd_cache!(loss)
    end
    check = function (loss)
      gram = loss.V * Diagonal(loss.s2) * loss.V'
      rhs = loss.V * loss.sUtY
      value = max(norm(gram - a.X' * a.X, Inf) / max(1.0, norm(a.X' * a.X, Inf)),
                  norm(rhs - a.X' * a.y, Inf) / max(1.0, norm(a.X' * a.y, Inf)))
      residual_certificate(value, 0.0; measure = :self_consistency)
    end
  else
    call! = function ()
      loss = a.s * PB.LeastSquaresLoss(a.y, a.X)
      curvature = zeros(size(a.X, 2))
      PB.coordinate_lipschitz!(curvature, loss)
      curvature
    end
    check = function (curvature)
      expected = a.s .* vec(sum(abs2, a.X; dims = 1))
      residual_certificate(cert_maxabs(curvature - expected) / max(1.0, cert_maxabs(expected)),
                           0.0; measure = :self_consistency)
    end
  end
  CaseState(() -> nothing, call!, check, data_hash(a))
end

function add_case!(catalog, group, problem, solver, variant, make;
                   phase = "call", suite = "quick", inputs = "draw", issue = "",
                   measure = "relative_gap", target = 1e-6)
  parts = (group, problem, solver, variant, phase)
  any(part -> occursin(r"[/\t\n\r]", part), parts) && error("invalid case identifier")
  id = join(parts, '/')
  meta = (; id, group, problem, solver, variant, phase, suite, inputs, issue, measure, target)
  push!(catalog, CaseSpec(meta, make))
end

function add_solve_cases!(catalog, group, problem, solver, variant, make_problem;
                          workspace = false, suite = "quick", inputs = "draw", issue = "",
                          measure = "relative_gap", target = 1e-6)
  for phase in (workspace ? ("call", "workspace") : ("call",))
    make = rep -> solve_case_state(make_problem(rep), solver, variant, phase)
    add_case!(catalog, group, problem, solver, variant, make;
              phase, suite, inputs, issue, measure, target)
  end
end

function build_catalog(suite, groups)
  suite in ("quick", "extended") || throw(ArgumentError("PS_SUITE must be quick or extended"))
  all(in(CASE_GROUPS), groups) || throw(ArgumentError("unknown PS_GROUPS entry"))
  catalog = CaseSpec[]
  # R and B preserve the generation sequence and solver settings of #103–#109.
  history = (("newton", "logistic-l1", "prox-newton", :newton, "#103", false),
             ("cd", "sqrt-lasso", "cd", :sqrt, "#104", true),
             ("gradient", "lasso", "monotone", :monotone, "#105", true),
             ("gradient", "lasso", "pg", :pg, "#106", true),
             ("gradient", "lasso", "active", :active, "#107", false),
             ("cd", "lasso-dense", "cd", :cd, "#108", true),
             ("admm", "lasso", "admm", :admm, "#109", true))
  for (group, problem, solver, family, issue, workspace) in history
    for variant in (family == :sqrt ? ("R",) : ("R", "B"))
      make_problem = variant == "R" ? (rep -> release_problem(family)) :
        (rep -> batched_problem(family))
      add_solve_cases!(catalog, group, problem, solver, variant, make_problem;
        workspace, inputs = "fixed", issue, target = variant == "R" ? NaN : 1e-8)
    end
  end
  add_solve_cases!(catalog, "cd", "lasso-csc", "cd", "B", rep -> batched_problem(:csc);
                   workspace = true, inputs = "fixed", issue = "#108", target = 1e-8)
  for solver in ("apg", "diagonal")
    key = "gradient/lasso/$(solver)"
    add_solve_cases!(catalog, "gradient", "lasso", solver, "tight",
      rep -> regression_problem(rep, key); workspace = true)
  end
  add_solve_cases!(catalog, "cd", "lasso", "random-cd", "tight",
    rep -> regression_problem(rep, "cd/lasso/random"); workspace = true)
  add_solve_cases!(catalog, "cd", "weighted-lasso", "cd", "tight",
    rep -> begin
      a = regression_problem(rep, "cd/weighted-lasso")
      merge(a, (; w = collect(range(0.5, 1.5; length = size(a.X, 2)))))
    end; workspace = true)
  add_solve_cases!(catalog, "cd", "quadratic", "cd", "tight",
    rep -> quadratic_problem(rep, "cd/quadratic"); workspace = true, measure = "kkt_residual")
  # The second variant records the least-squares gap of the same quadratic.
  add_solve_cases!(catalog, "cd", "quadratic", "cd", "dual-gap",
    rep -> quadratic_problem(rep, "cd/quadratic"); workspace = true)
  add_solve_cases!(catalog, "cd", "group-lasso", "cd", "tight",
    rep -> grouped_problem(rep, "cd/group-lasso"); workspace = true)
  add_solve_cases!(catalog, "cd", "sqrt-lasso", "cd", "tight",
    rep -> begin
      a = regression_problem(rep, "cd/sqrt-lasso")
      merge(a, (; kind = :sqrt_lasso, λ = 0.5, fit_floor = 1e-12))
    end; workspace = true)
  add_solve_cases!(catalog, "newton", "logistic-weighted-offset", "prox-newton", "tight",
    rep -> logistic_problem(rep, "newton/logistic-weighted-offset"; weighted = true))
  add_solve_cases!(catalog, "newton", "glasso", "quic", "tight",
    rep -> glasso_problem(rep, "newton/glasso"))
  add_case!(catalog, "primal_dual", "generalized-lasso", "condat-vu", "tight",
    rep -> primal_dual_case_state(generalized_problem(rep, "primal_dual/generalized")))
  for kind in (:mcp, :scad, :iht)
    add_solve_cases!(catalog, "nonconvex", string(kind), "pg", "tight",
      rep -> nonconvex_problem(rep, "nonconvex/$(kind)", kind);
      workspace = true, measure = "fixed_point_residual")
  end
  for solver in ("slope-apg", "slope-hybrid")
    add_solve_cases!(catalog, "slope", "slope", solver, "tight",
      rep -> slope_problem(rep, "slope/$(solver)"))
    add_case!(catalog, "paths", "slope", solver, "grid8",
      rep -> path_case_state(slope_problem(rep, "paths/$(solver)"), solver))
  end
  for solver in ("cd", "apg")
    add_solve_cases!(catalog, "sgl", "sparse-group", solver, "tight",
      rep -> grouped_problem(rep, "sgl/$(solver)"; sparse_group = true); workspace = true)
  end
  add_case!(catalog, "paths", "lasso", "cd", "grid8",
    rep -> path_case_state(regression_problem(rep, "paths/lasso"), "cd"))
  for (group, solver, issue) in (("admm", "admm", "#109"), ("gradient", "diagonal", ""))
    add_case!(catalog, group, "lasso", solver, "construction",
      rep -> setup_case_state(regression_problem(rep, "setup/$(solver)"), solver);
      phase = "setup", issue, measure = "self_consistency", target = 1e-12)
  end
  for design in (:A, :B, :C, :D, :E)
    n, p = design == :C ? (800, 120) : design == :D ? (180, 600) : (240, 160)
    make_problem = rep -> regression_problem(rep, "extended/design-$(design)"; n, p, design)
    for solver in ("cd", "apg")
      add_solve_cases!(catalog, solver == "cd" ? "cd" : "gradient", "lasso-$(design)",
        solver, "tight", make_problem; workspace = true, suite = "extended")
    end
    add_case!(catalog, "paths", "lasso-$(design)", "cd", "grid16",
      rep -> path_case_state(make_problem(rep), "cd"; levels = 16); suite = "extended")
  end
  add_solve_cases!(catalog, "newton", "logistic-larger", "prox-newton", "tight",
    rep -> logistic_problem(rep, "extended/logistic"; n = 800, p = 120); suite = "extended")
  add_solve_cases!(catalog, "newton", "glasso-larger", "quic", "tight",
    rep -> glasso_problem(rep, "extended/glasso"; n = 400, p = 40); suite = "extended")
  add_solve_cases!(catalog, "admm", "lasso-larger", "admm", "tight",
    rep -> regression_problem(rep, "extended/admm"; n = 800, p = 160);
    workspace = true, suite = "extended")
  add_case!(catalog, "primal_dual", "generalized-larger", "condat-vu", "tight",
    rep -> primal_dual_case_state(generalized_problem(rep, "extended/generalized"; n = 240, p = 100));
    suite = "extended")
  for solver in ("slope-apg", "slope-hybrid")
    add_solve_cases!(catalog, "slope", "slope-larger", solver, "tight",
      rep -> slope_problem(rep, "extended/slope/$(solver)"; n = 600, p = 160); suite = "extended")
  end
  for solver in ("cd", "apg")
    add_solve_cases!(catalog, "sgl", "sparse-group-larger", solver, "tight",
      rep -> grouped_problem(rep, "extended/sgl/$(solver)"; n = 600, p = 160, sparse_group = true);
      workspace = true, suite = "extended")
  end
  for kind in (:mcp, :scad, :iht)
    add_solve_cases!(catalog, "nonconvex", "$(kind)-larger", "pg", "tight",
      rep -> nonconvex_problem(rep, "extended/nonconvex/$(kind)", kind; n = 600, p = 160);
      workspace = true, suite = "extended", measure = "fixed_point_residual")
  end
  selected = filter(c -> c.meta.group in groups && (suite == "extended" || c.meta.suite == "quick"), catalog)
  sort!(selected; by = c -> c.meta.id)
  length(unique(c.meta.id for c in selected)) == length(selected) || error("duplicate case id")
  selected
end
