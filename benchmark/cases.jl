struct CaseSpec
  meta::NamedTuple
  make::Function
  # Capabilities of the loaded package that the case needs; see CAPABILITIES.
  requires::Vector{String}
end

CaseSpec(meta::NamedTuple, make::Function) = CaseSpec(meta, make, String[])

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

# What the harness may run against the loaded ProximalSolvers (#110). A case requires its
# solver ID and, per feature it uses, "solver:feature" (see `case_requirements`); a case
# with a requirement missing here is deferred: kept in the catalog definitions, listed with
# PS_LIST=deferred, and never constructed or run. The entries are declared, not inferred
# from the names a package defines: a solver type can exist without supporting a problem,
# an iterate or a phase. Restoring a solver feature means adding its entries here (and
# adapting its constructor in `benchmark_method` if its API changed).
const CAPABILITIES = Set([
  # CDSolver: dense Matrix least-squares lasso with unweighted NormL1, a dense Vector or a
  # vector SparseIterate, Float32 or Float64, cyclic ("cd") or random ("random-cd") order;
  # no gap stopping, workspaces or paths.
  "cd", "cd:lasso", "cd:sparse_iterate", "cd:float32", "random-cd", "random-cd:lasso",
  # ProximalGradientDescent: the same problem with a dense Vector, Float32 or Float64.
  "pg", "pg:lasso", "pg:float32",
  # AccProxGradDescent: the same problem with a dense Vector, Float32 or Float64; no gap
  # stopping, workspaces or other problems.
  "apg", "apg:lasso", "apg:float32",
])

const SOLVER_NAMES = Dict("cd" => "CDSolver", "random-cd" => "CDSolver(order = :random)",
  "pg" => "ProximalGradientDescent", "apg" => "AccProxGradDescent",
  "monotone" => "MonotoneAccProxGradDescent", "active" => "ActiveAccProxGradDescent",
  "diagonal" => "ProximalGradientDescent(preconditioner = :diagonal)",
  "prox-newton" => "ProxNewton", "quic" => "ProxNewton (QUIC)", "admm" => "ADMMSolver",
  "condat-vu" => "CondatVu", "slope-apg" => "SLOPEAPG", "slope-hybrid" => "SLOPEHybrid")
const FEATURE_NOTES = Dict(
  "lasso" => "least-squares lasso, dense Matrix design, unweighted NormL1",
  "float32" => "Float32 data and iterate", "sparse_iterate" => "vector SparseIterate iterate",
  "gap" => "duality-gap stopping (gaptol > 0)",
  "workspace" => "SolverWorkspace and reinit! (workspace phase)",
  "path" => "solve_path with screening", "setup" => "cached setup of the setup phase",
  "weighted_l1" => "weighted NormL1", "sparse_design" => "SparseMatrixCSC design",
  "sqrt_lasso" => "SqrtLeastSquaresLoss", "quadratic" => "QuadraticFunction loss",
  "group" => "GroupNormL2 on an AtomIterate", "sparse_group" => "SparseGroupNormL2 on an AtomIterate",
  "slope" => "SLOPE penalty", "logistic" => "LogisticLoss with L1",
  "glasso" => "LogDetLoss with entrywise L1", "generalized_lasso" => "generalized lasso (three-term)",
  "mcp" => "MCP penalty", "scad" => "SCAD penalty", "iht" => "L0-ball constraint")

case_requirements(solver, needs, phase) =
  [solver; ["$solver:$need" for need in needs]; phase == "workspace" ? ["$solver:workspace"] : String[]]
case_available(spec) = all(in(CAPABILITIES), spec.requires)

function describe_requirement(requirement)
  solver, feature = occursin(':', requirement) ? split(requirement, ':'; limit = 2) : (requirement, "")
  isempty(feature) && return "solver $(get(SOLVER_NAMES, solver, solver))"
  "$(get(SOLVER_NAMES, solver, solver)): $(get(FEATURE_NOTES, feature, feature))"
end
missing_requirements(spec) = [describe_requirement(r) for r in spec.requires if !(r in CAPABILITIES)]

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
  elseif isdefined(ProximalSolvers, :ProxNewton) && method isa ProximalSolvers.ProxNewton
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
  # Solvers that carry their own options; the others take benchmark options.
  own_options = solver in ("cd", "random-cd", "prox-newton", "quic", "slope-apg", "slope-hybrid")
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

# Return a path iterate to the empty start. A SparseIterate must also lose its working
# set: ProximalBase 0.5 empties it in fill!, while 0.6 only writes the values (#110).
# The dense iterate of the SLOPE paths has no working set.
function clear_path_iterate!(x)
  if x isa ProximalBase.SparseIterate
    SparseArrays.dropzeros!(fill!(x, 0.0))
  elseif x isa AbstractVector
    fill!(x, 0.0)
  else
    throw(ArgumentError("no reset for a path iterate of type $(typeof(x))"))
  end
  x
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
  reset!() = (clear_path_iterate!(x); reset_solver_rng!(method); nothing)
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

# Current-core cases (#110): CDSolver with a dense Vector or a vector SparseIterate, and
# ProximalGradientDescent and AccProxGradDescent with a dense Vector, Float32 or Float64. Targets are fixed per
# precision for every solver: 1e-8 in Float64, the threshold of the #103-#109 B cases, and
# 1e-5 in Float32, about 50-100 times the relative gap of the exact solution rounded to
# Float32 (5e-8 to 2e-7 on these designs). A solver that stops short of them is a non-ok
# observation, never a timing.
const CORE_TARGETS = Dict(Float64 => 1e-8, Float32 => 1e-5)
const CORE_PRECISIONS = ((Float64, "f64"), (Float32, "f32"))
const CORE_ITERATES = Dict("cd" => (:dense, :sparse), "pg" => (:dense,), "apg" => (:dense,))

# The start of a warm case: the solution at 1.25λ, the previous level of a path with ratio
# 0.8, computed in Float64 by the certificate module's own coordinate descent, so it does
# not depend on the solver under test. It is part of the inputs and of their data hash.
function warm_start(a)
  a.s == 1 / size(a.X, 1) && all(isone, a.w) || error("warm starts need s = 1/n and unit weights")
  refit = cert_loading_refit(a.X, a.y, 1.25a.λ, a.w, zeros(size(a.X, 2)); tol = 1e-12,
                             maxpasses = 100_000)
  refit.converged || error("the warm start did not certify")
  refit.β
end

# The problem a current-core case gives its solver: the Float64 draw rounded once to T, with
# its start. Certificates read the same values back exactly in Float64.
function core_problem(a, ::Type{T}; warm = false) where T
  start = warm ? warm_start(a) : zeros(size(a.X, 2))
  merge(a, (; X = T.(a.X), y = T.(a.y), s = T(a.s), λ = T(a.λ), w = T.(a.w), start = T.(start)))
end
exact_problem(a) = merge(a, (; X = Float64.(a.X), y = Float64.(a.y), s = Float64(a.s),
                             λ = Float64(a.λ), w = Float64.(a.w), start = Float64.(a.start)))

function sparse_start(start::Vector{T}) where T
  x = ProximalBase.SparseIterate(T, length(start))
  for j in eachindex(start)
    iszero(start[j]) || (x[j] = start[j])
  end
  x
end

function core_method(solver, ::Type{T}) where T
  PS = ProximalSolvers
  # Coefficient-change tolerances near the attainable precision; certificates decide accuracy.
  solver == "cd" && return PS.CDSolver(order = :cyclic, tol = T == Float32 ? 1e-6 : 1e-11,
                                       rng = Xoshiro(9))
  solver == "pg" && return PS.ProximalGradientDescent()
  solver == "apg" && return PS.AccProxGradDescent()
  error("no current-core method for $solver")
end

function core_case_state(a, solver, iterate)
  PS = ProximalSolvers
  T = eltype(a.X)
  f, g = benchmark_model(a)
  method = core_method(solver, T)
  options = benchmark_options(; residual = true)   # PGD and APG only; gaptol = 0
  start = iterate == :sparse ? sparse_start(a.start) : copy(a.start)
  x = copy(start)
  # copyto! between SparseIterates of one size copies the state: values, active set, order.
  reset! = () -> (copyto!(x, start); reset_solver_rng!(method); nothing)
  call! = solver in ("pg", "apg") ? (() -> PS.solve!(x, f, g, method, options)) :
    (() -> PS.solve!(x, f, g, method))
  exact = exact_problem(a)
  check(output) = certify(exact, Float64.(Array(output.minimizer)))
  CaseState(reset!, call!, check, data_hash(a))
end

function add_core_cases!(catalog, group, problem, solver, make_problem; warm = false,
                         suite = "quick")
  for (T, precision) in CORE_PRECISIONS, iterate in CORE_ITERATES[solver]
    variant = (warm ? "warm-" : "") * "$(iterate)-$(precision)"
    needs = ["lasso"; T == Float32 ? ["float32"] : String[];
             iterate == :sparse ? ["sparse_iterate"] : String[]]
    make = rep -> core_case_state(core_problem(make_problem(rep), T; warm), solver, iterate)
    add_case!(catalog, group, problem, solver, variant, make; suite, target = CORE_TARGETS[T],
              requires = case_requirements(solver, needs, "call"))
  end
end

function add_case!(catalog, group, problem, solver, variant, make;
                   phase = "call", suite = "quick", inputs = "draw", issue = "",
                   measure = "relative_gap", target = 1e-6, requires = String[])
  parts = (group, problem, solver, variant, phase)
  any(part -> occursin(r"[/\t\n\r]", part), parts) && error("invalid case identifier")
  isempty(requires) && error("case $(join(parts, '/')) declares no requirements")
  id = join(parts, '/')
  meta = (; id, group, problem, solver, variant, phase, suite, inputs, issue, measure, target)
  push!(catalog, CaseSpec(meta, make, requires))
end

function add_solve_cases!(catalog, group, problem, solver, variant, make_problem;
                          workspace = false, suite = "quick", inputs = "draw", issue = "",
                          measure = "relative_gap", target = 1e-6, needs = ())
  for phase in (workspace ? ("call", "workspace") : ("call",))
    make = rep -> solve_case_state(make_problem(rep), solver, variant, phase)
    add_case!(catalog, group, problem, solver, variant, make;
              phase, suite, inputs, issue, measure, target,
              requires = case_requirements(solver, needs, phase))
  end
end

"""
    build_catalog(suite, groups; deferred = false)

The cases of `suite` and `groups` that the loaded package supports (`case_available`), in
ID order, or with `deferred = true` the cases that need a capability missing from
CAPABILITIES. Building the catalog constructs no solver and no data.
"""
function build_catalog(suite, groups; deferred = false)
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
  problem_needs = Dict(:newton => "logistic", :sqrt => "sqrt_lasso")
  for (group, problem, solver, family, issue, workspace) in history
    for variant in (family == :sqrt ? ("R",) : ("R", "B"))
      make_problem = variant == "R" ? (rep -> release_problem(family)) :
        (rep -> batched_problem(family))
      # B stops on the duality gap (gaptol = 1e-8), except ProxNewton, whose B variant
      # starts from a SparseIterate instead.
      needs = [get(problem_needs, family, "lasso");
               variant == "B" ? [solver == "prox-newton" ? "sparse_iterate" : "gap"] : String[]]
      add_solve_cases!(catalog, group, problem, solver, variant, make_problem;
        workspace, inputs = "fixed", issue, target = variant == "R" ? NaN : 1e-8, needs)
    end
  end
  add_solve_cases!(catalog, "cd", "lasso-csc", "cd", "B", rep -> batched_problem(:csc);
                   workspace = true, inputs = "fixed", issue = "#108", target = 1e-8,
                   needs = ("sparse_design", "gap"))
  for solver in ("apg", "diagonal")
    key = "gradient/lasso/$(solver)"
    add_solve_cases!(catalog, "gradient", "lasso", solver, "tight",
      rep -> regression_problem(rep, key); workspace = true, needs = ("lasso", "gap"))
  end
  add_solve_cases!(catalog, "cd", "lasso", "random-cd", "tight",
    rep -> regression_problem(rep, "cd/lasso/random"); workspace = true, needs = ("lasso", "gap"))
  add_solve_cases!(catalog, "cd", "weighted-lasso", "cd", "tight",
    rep -> begin
      a = regression_problem(rep, "cd/weighted-lasso")
      merge(a, (; w = collect(range(0.5, 1.5; length = size(a.X, 2)))))
    end; workspace = true, needs = ("weighted_l1", "gap"))
  add_solve_cases!(catalog, "cd", "quadratic", "cd", "tight",
    rep -> quadratic_problem(rep, "cd/quadratic"); workspace = true, measure = "kkt_residual",
    needs = ("quadratic",))
  # The second variant records the least-squares gap of the same quadratic.
  add_solve_cases!(catalog, "cd", "quadratic", "cd", "dual-gap",
    rep -> quadratic_problem(rep, "cd/quadratic"); workspace = true, needs = ("quadratic",))
  add_solve_cases!(catalog, "cd", "group-lasso", "cd", "tight",
    rep -> grouped_problem(rep, "cd/group-lasso"); workspace = true, needs = ("group", "gap"))
  add_solve_cases!(catalog, "cd", "sqrt-lasso", "cd", "tight",
    rep -> begin
      a = regression_problem(rep, "cd/sqrt-lasso")
      merge(a, (; kind = :sqrt_lasso, λ = 0.5, fit_floor = 1e-12))
    end; workspace = true, needs = ("sqrt_lasso",))
  add_solve_cases!(catalog, "newton", "logistic-weighted-offset", "prox-newton", "tight",
    rep -> logistic_problem(rep, "newton/logistic-weighted-offset"; weighted = true),
    needs = ("logistic",))
  add_solve_cases!(catalog, "newton", "glasso", "quic", "tight",
    rep -> glasso_problem(rep, "newton/glasso"), needs = ("glasso",))
  add_case!(catalog, "primal_dual", "generalized-lasso", "condat-vu", "tight",
    rep -> primal_dual_case_state(generalized_problem(rep, "primal_dual/generalized"));
    requires = case_requirements("condat-vu", ("generalized_lasso", "gap"), "call"))
  for kind in (:mcp, :scad, :iht)
    add_solve_cases!(catalog, "nonconvex", string(kind), "pg", "tight",
      rep -> nonconvex_problem(rep, "nonconvex/$(kind)", kind);
      workspace = true, measure = "fixed_point_residual", needs = (string(kind),))
  end
  for solver in ("slope-apg", "slope-hybrid")
    add_solve_cases!(catalog, "slope", "slope", solver, "tight",
      rep -> slope_problem(rep, "slope/$(solver)"), needs = ("slope",))
    add_case!(catalog, "paths", "slope", solver, "grid8",
      rep -> path_case_state(slope_problem(rep, "paths/$(solver)"), solver);
      requires = case_requirements(solver, ("slope", "path"), "call"))
  end
  for solver in ("cd", "apg")
    add_solve_cases!(catalog, "sgl", "sparse-group", solver, "tight",
      rep -> grouped_problem(rep, "sgl/$(solver)"; sparse_group = true); workspace = true,
      needs = ("sparse_group", "gap"))
  end
  path_needs = ("lasso", "path", "sparse_iterate", "gap")
  add_case!(catalog, "paths", "lasso", "cd", "grid8",
    rep -> path_case_state(regression_problem(rep, "paths/lasso"), "cd");
    requires = case_requirements("cd", path_needs, "call"))
  for (group, solver, issue) in (("admm", "admm", "#109"), ("gradient", "diagonal", ""))
    add_case!(catalog, group, "lasso", solver, "construction",
      rep -> setup_case_state(regression_problem(rep, "setup/$(solver)"), solver);
      phase = "setup", issue, measure = "self_consistency", target = 1e-12,
      requires = case_requirements(solver, ("setup",), "setup"))
  end
  for design in (:A, :B, :C, :D, :E)
    n, p = design == :C ? (800, 120) : design == :D ? (180, 600) : (240, 160)
    make_problem = rep -> regression_problem(rep, "extended/design-$(design)"; n, p, design)
    for solver in ("cd", "apg")
      add_solve_cases!(catalog, solver == "cd" ? "cd" : "gradient", "lasso-$(design)",
        solver, "tight", make_problem; workspace = true, suite = "extended",
        needs = ("lasso", "gap"))
    end
    add_case!(catalog, "paths", "lasso-$(design)", "cd", "grid16",
      rep -> path_case_state(make_problem(rep), "cd"; levels = 16); suite = "extended",
      requires = case_requirements("cd", path_needs, "call"))
  end
  add_solve_cases!(catalog, "newton", "logistic-larger", "prox-newton", "tight",
    rep -> logistic_problem(rep, "extended/logistic"; n = 800, p = 120); suite = "extended",
    needs = ("logistic",))
  add_solve_cases!(catalog, "newton", "glasso-larger", "quic", "tight",
    rep -> glasso_problem(rep, "extended/glasso"; n = 400, p = 40); suite = "extended",
    needs = ("glasso",))
  add_solve_cases!(catalog, "admm", "lasso-larger", "admm", "tight",
    rep -> regression_problem(rep, "extended/admm"; n = 800, p = 160);
    workspace = true, suite = "extended", needs = ("lasso", "gap"))
  add_case!(catalog, "primal_dual", "generalized-larger", "condat-vu", "tight",
    rep -> primal_dual_case_state(generalized_problem(rep, "extended/generalized"; n = 240, p = 100));
    suite = "extended", requires = case_requirements("condat-vu", ("generalized_lasso", "gap"), "call"))
  for solver in ("slope-apg", "slope-hybrid")
    add_solve_cases!(catalog, "slope", "slope-larger", solver, "tight",
      rep -> slope_problem(rep, "extended/slope/$(solver)"; n = 600, p = 160); suite = "extended",
      needs = ("slope",))
  end
  for solver in ("cd", "apg")
    add_solve_cases!(catalog, "sgl", "sparse-group-larger", solver, "tight",
      rep -> grouped_problem(rep, "extended/sgl/$(solver)"; n = 600, p = 160, sparse_group = true);
      workspace = true, suite = "extended", needs = ("sparse_group", "gap"))
  end
  for kind in (:mcp, :scad, :iht)
    add_solve_cases!(catalog, "nonconvex", "$(kind)-larger", "pg", "tight",
      rep -> nonconvex_problem(rep, "extended/nonconvex/$(kind)", kind; n = 600, p = 160);
      workspace = true, suite = "extended", measure = "fixed_point_residual",
      needs = (string(kind),))
  end
  # Current core (#110): one small and one medium correlated design shared by CD, PGD and APG
  # (cold and warm starts), and two larger designs in the extended suite. The medium and
  # larger designs reuse the inputs of the deferred extended cases of the same design.
  core_designs = (("lasso", rep -> regression_problem(rep, "core/lasso"), (false,), "quick"),
    ("lasso-B", rep -> regression_problem(rep, "extended/design-B"; n = 240, p = 160, design = :B),
     (false, true), "quick"),
    ("lasso-C", rep -> regression_problem(rep, "extended/design-C"; n = 800, p = 120, design = :C),
     (false,), "extended"),
    ("lasso-D", rep -> regression_problem(rep, "extended/design-D"; n = 180, p = 600, design = :D),
     (false,), "extended"))
  for (problem, make_problem, starts, suite) in core_designs, warm in starts
    add_core_cases!(catalog, "cd", problem, "cd", make_problem; warm, suite)
    add_core_cases!(catalog, "gradient", problem, "pg", make_problem; warm, suite)
    add_core_cases!(catalog, "gradient", problem, "apg", make_problem; warm, suite)
  end
  # IDs are unique across supported and deferred cases, so restoring one never renames another.
  length(unique(c.meta.id for c in catalog)) == length(catalog) || error("duplicate case id")
  selected = filter(c -> c.meta.group in groups && (suite == "extended" || c.meta.suite == "quick") &&
                    case_available(c) != deferred, catalog)
  sort!(selected; by = c -> c.meta.id)
end

"""
    check_deferred_request(filter, suite, groups)

Refuse a PS_CASES `filter` entry that names a deferred case, or a pattern that matches
deferred cases but no supported one, with the capabilities those cases lack. A pattern
that also matches supported cases selects only those (select_cases); the IDs of the
deferred cases it also matches are returned, to be reported as not run.
"""
# The cases of `catalog` that one PS_CASES entry selects, with the matching of select_cases
# (run.jl), which refuses an entry that matches nothing.
function selected_by(catalog, pattern)
  try
    select_cases(catalog, pattern)
  catch err
    err isa ArgumentError || rethrow()
    CaseSpec[]
  end
end

function check_deferred_request(filter::AbstractString, suite, groups)
  patterns = [String(strip(p)) for p in split(filter, ',') if !isempty(strip(p))]
  isempty(patterns) && return String[]
  active, deferred = build_catalog(suite, groups), build_catalog(suite, groups; deferred = true)
  skipped = String[]
  for pattern in patterns
    hits = selected_by(deferred, pattern)
    if isempty(selected_by(active, pattern)) && !isempty(hits)
      reasons = unique(reduce(vcat, missing_requirements.(hits)))
      throw(ArgumentError("case selection \"$pattern\" selects $(length(hits)) deferred case(s) " *
        "that the loaded ProximalSolvers cannot run (missing: $(join(reasons, "; "))); " *
        "PS_LIST=deferred lists deferred cases and their requirements"))
    end
    append!(skipped, spec.meta.id for spec in hits)
  end
  unique(skipped)
end
