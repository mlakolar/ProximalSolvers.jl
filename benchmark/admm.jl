# Run from a single pinned harness checkout, with --project pointing at the solver
# revision under measurement. See HARNESS.md for paired and A/A series.
include("run.jl")

function admm_center(rep, n, ::Type{T}) where {T}
  rng = scenario_rng(rep, "admm/centered-quadratic/$n")
  # This grid has active and inactive coordinates away from the threshold.
  [T(rand(rng, -16:16)) / T(8) for _ in 1:n]
end

function admm_benchmark_model(c, λ, τ, ρ, abstol, reltol, adaptive)
  T = eltype(c)
  (ProximalBase.SqrNormL2(λ, c), ProximalBase.NormL1(τ),
   ProximalSolvers.ADMMSolver(; ρ, α = T(1.4), abstol, reltol, adaptive),
   ProximalSolvers.ProximalOptions(; maxiter = 5000))
end

function admm_case_state(rep, n, ::Type{T}, adaptive, start) where {T}
  c = admm_center(rep, n, T)
  λ, τ = T(2), T(0.8125)
  ρ = adaptive ? T(64) : T(2)
  tolerance = max(T(4) * eps(T), T(1e-13))
  c64, λ64, τ64 = Float64.(c), Float64(λ), Float64(τ)
  reference = cert_soft.(c64, τ64 / λ64)
  # Use the same primal and scaled-dual optimum for the warm start on both revisions.
  z0 = start == "warm" ? T.(reference) : zeros(T, n)
  u0 = start == "warm" ? T.(λ64 .* (c64 .- reference) ./ Float64(ρ)) : zeros(T, n)
  model() = admm_benchmark_model(c, λ, τ, ρ, tolerance, tolerance, adaptive)

  if start == "fresh"
    # Time construction of the model, method/options and initial primal vector.
    reset! = () -> nothing
    call! = () -> ProximalSolvers.solve!(copy(z0), model()...)
  else
    f, g, method, options = model()
    z, u = copy(z0), copy(u0)
    reset! = () -> (copyto!(z, z0); copyto!(u, u0); nothing)
    call! = () -> ProximalSolvers.solve!(z, f, g, method, options; u)
  end

  check = function (result)
    z64 = Float64.(result.minimizer)
    grad = λ64 .* (z64 .- c64)
    objective = λ64 * sum(abs2, z64 .- c64) / 2 + τ64 * sum(abs, z64)
    result.converged && result.prox_calls == 2 * result.iterations ||
      return uncertifiable("ADMM did not converge or recorded inconsistent proximal calls";
                            measure = :kkt_residual)
    abs(Float64(result.minimum) - objective) <= max(128eps(T), 1e-12) * max(1, objective) ||
      return uncertifiable("returned objective differs from the independent value";
                            measure = :kkt_residual)
    kkt = maximum(eachindex(z64)) do i
      iszero(z64[i]) ? max(abs(grad[i]) - τ64, 0) : abs(grad[i] + τ64 * sign(z64[i]))
    end
    # Strong convexity bounds the point error by the per-coordinate KKT residual divided by λ.
    maximum(abs, z64 - reference) <= kkt / λ64 + 4eps(Float64) ||
      return uncertifiable("point error differs from the independent soft threshold";
                            measure = :kkt_residual)
    residual_certificate(kkt, objective)
  end
  CaseState(reset!, call!, check, data_hash((; c, λ, τ, z0, u0, ρ, tolerance, adaptive)))
end

function admm_catalog()
  catalog = CaseSpec[]
  for n in (32, 8192), T in (Float32, Float64), adaptive in (false, true),
      start in ("fresh", "prebuilt", "warm")
    problem = "centered-l1-$n"
    policy = adaptive ? "adaptive" : "fixed"
    precision = T == Float32 ? "f32" : "f64"
    variant = "$start-$policy-$precision"
    target = T == Float32 ? 2e-5 : 1e-10
    meta = (id = "admm/$problem/admm/$variant/call", group = "admm", problem,
            solver = "admm", variant, phase = "call", suite = "quick", inputs = "draw",
            issue = "#433", measure = "kkt_residual", target)
    push!(catalog, CaseSpec(meta, rep -> admm_case_state(rep, n, T, adaptive, start)))
  end
  catalog
end

function run_admm_benchmarks()
  settings = withenv(() -> runner_settings(), "PS_GROUPS" => "admm", "PS_SUITE" => "quick")
  catalog = admm_catalog()
  isempty(settings.cases) || (catalog = select_cases(catalog, settings.cases))
  Threads.nthreads() == 1 || error("run with JULIA_NUM_THREADS=1")
  BLAS.set_num_threads(1)
  run_records(settings, catalog)
end

if abspath(PROGRAM_FILE) == @__FILE__
  exit(run_admm_benchmarks())
end
