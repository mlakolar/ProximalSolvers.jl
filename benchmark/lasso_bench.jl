# Lasso benchmark: ProximalSolvers's proximal gradient solvers against
# current HighDimensionalModels.jl and historical CoordinateDescent.jl, with glmnet (GLMNet.jl) and
# Lasso.jl for reference.
#
#     julia --project=benchmark benchmark/lasso_bench.jl            # 1.5 to 3.5 hours
#     julia --project=benchmark benchmark/lasso_bench.jl --quick
#     julia --project=benchmark benchmark/lasso_bench.jl --smoke    # bounded plumbing check
#
# 1. One λ, starting from β = 0: each solver is run over a sweep of its
#    tolerance, and each run records its time and accuracy. This gives the time
#    a solver needs to reach a given relative suboptimality (F - F*) / F*.
# 2. Each solver at its package defaults.
# 3. A path of λ values from λmax to λmax/100, each warm started from the
#    previous solution.
#
# Results are written to benchmark/results/single.csv and path.csv; print
# tables from them with lasso_summary.jl. See README.md.

include(joinpath(@__DIR__, "lasso_setup.jl"))
BLAS.set_num_threads(1)

const SMOKE = "--smoke" in ARGS
const QUICK = SMOKE || "--quick" in ARGS
const OUT = get(ENV, "PROXIMAL_LASSO_OUT", joinpath(@__DIR__, "results"))

const SCENARIOS = SMOKE ?
  [(name = "smoke", desc = "n=80 p=120 AR(1) 0.3", n = 80, p = 120, s = 5, ρ = 0.3, common = 0.0, gram = true)] : QUICK ?
  [(name = "A", desc = "n=300 p=1000 independent", n = 300, p = 1000, s = 20, ρ = 0.0, common = 0.0, gram = true)] :
  [(name = "A", desc = "n=500 p=2500 independent",      n = 500,  p = 2500,  s = 50, ρ = 0.0, common = 0.0, gram = true),
   (name = "B", desc = "n=500 p=2500 AR(1) 0.8",        n = 500,  p = 2500,  s = 50, ρ = 0.8, common = 0.0, gram = true),
   (name = "C", desc = "n=5000 p=500 AR(1) 0.5",        n = 5000, p = 500,   s = 50, ρ = 0.5, common = 0.0, gram = true),
   (name = "D", desc = "n=1000 p=20000 independent",    n = 1000, p = 20000, s = 20, ρ = 0.0, common = 0.0, gram = false),
   (name = "E", desc = "n=500 p=2500 equicorrelated 0.5", n = 500, p = 2500, s = 50, ρ = 0.0, common = 0.5, gram = true)]
const LAMBDA_FRACS = QUICK ? (0.1,) : (0.1, 0.02)
const N_LAMBDA = SMOKE ? 4 : QUICK ? 10 : 50
const TOLS = SMOKE ? (1e-8,) : QUICK ? 10.0 .^ (-2:-2:-14) : 10.0 .^ (-1:-1:-16)
const PATH_TOLS = SMOKE ? (1e-8,) : QUICK ? 10.0 .^ (-4:-2:-14) : 10.0 .^ (-3:-1:-14)
const RUN_CAP = 20.0       # stop a sweep after a run this slow (seconds)
const SOLVER_CAP = 90.0    # or after this much time on one solver in one case
const DONE = 1e-11         # or once the relative suboptimality is below this

function bench_timed(run, P, args...; maxreps = 7)
  timed_solver(run, P, args...; budget = SMOKE ? 0.0 : 0.3,
               minreps = SMOKE ? 1 : 3, maxreps = SMOKE ? 1 : maxreps)
end

function check_fit(P, β, λ; accuracy = true)
  length(β) == P.p || error("A solver returned the wrong coefficient dimension.")
  all(isfinite, β) && isfinite(objective(P, β, λ)) || error("A solver returned a nonfinite fit.")
  accuracy && lasso_kkt(P, β, λ) > 1e-3 * max(P.λmax, 1.0) &&
    error("Smoke fit does not satisfy the lasso KKT conditions.")
end

function check_smoke_outputs()
  single = readlines(joinpath(OUT, "single.csv"))
  paths = readlines(joinpath(OUT, "path.csv"))
  expected_single = [(S.name, S.package) for S in SOLVERS]
  append!(expected_single, [(name, "defaults") for (name, _) in DEFAULT_RUNS])
  actual_single = [(split(line, ',')[5], split(line, ',')[6]) for line in single[2:end]]
  sort(actual_single) == sort(expected_single) || error("Smoke run missed or duplicated a single/default solver.")
  expected_paths = [(S.name, S.package) for S in PATH_SOLVERS]
  actual_paths = [(split(line, ',')[3], split(line, ',')[4]) for line in paths[2:end]]
  sort(actual_paths) == sort(expected_paths) || error("Smoke run missed or duplicated a path solver.")
  # A defaults error is written as a NaN row, so fail on it as well.
  any(line -> occursin("NaN,NaN", line), single[2:end]) && error("Smoke run contains an error row.")
  println("LASSO_SMOKE_PASSED singles=", length(single) - 1, " paths=", length(paths) - 1)
end

function warmup()
  P = make_problem("warmup", "warmup"; n = 50, p = 100, s = 5)
  λ = 0.1 * P.λmax
  λs = P.λmax .* 10 .^ range(0, -2; length = 5)
  foreach(S -> S.run(P, λ, 1e-6), SOLVERS)
  foreach(d -> d[2](P, λ), DEFAULT_RUNS)
  foreach(S -> S.run(P, λs, 1e-6), PATH_SOLVERS)
  nothing
end

function main()
  println(env_summary(), SMOKE ? " (smoke run)" : QUICK ? " (quick run)" : "")
  println("Current packages: ProximalSolvers ", pkgversion(ProximalSolvers),
          ", ProximalBase ", pkgversion(ProximalBase),
          ", HighDimensionalModels ", pkgversion(HighDimensionalModels), ", GLMNet ", pkgversion(GLMNet),
          ", Lasso ", pkgversion(Lasso))
  warmup()
  mkpath(OUT)

  single = open(joinpath(OUT, "single.csv"), "w")
  println(single, "scenario,desc,lambda_frac,nnz_star,solver,package,tol,time,gram_time,rel_subopt,max_abs_diff,support_errors,nnz,kkt")
  paths = open(joinpath(OUT, "path.csv"), "w")
  println(paths, "scenario,desc,solver,package,tol,time,gram_time,max_rel_subopt,max_abs_diff,max_support_errors,n_lambda")

  for sc in SCENARIOS
    P = make_problem(sc.name, sc.desc; n = sc.n, p = sc.p, s = sc.s, ρ = sc.ρ, common = sc.common, gram = sc.gram)
    @printf "\n### %s: %s (X'X/n %.2f s)\n" sc.name sc.desc P.gram_time
    flush(stdout)

    for frac in LAMBDA_FRACS
      λ = frac * P.λmax
      tref = @elapsed (βstar, Fstar, kkt) = reference(P, λ)
      SMOKE && kkt > 1e-9 * max(P.λmax, 1.0) && error("Reference KKT check failed.")
      nnzstar = count(!iszero, βstar)
      @printf "  λ = %.2f λmax: nnz(β*) = %d, KKT residual of the reference %.1e (%.1f s)\n" frac nnzstar kkt tref

      row(solver, package, tol, gram_time, β, t) = @printf(single, "%s,%s,%g,%d,%s,%s,%g,%.6g,%.6g,%.6g,%.6g,%d,%d,%.6g\n",
        P.name, P.desc, frac, nnzstar, solver, package, tol, t, gram_time,
        relsubopt(objective(P, β, λ), Fstar), maximum(abs, β - βstar), support_errors(β, βstar),
        count(!iszero, β), lasso_kkt(P, β, λ))

      for S in SOLVERS
        (S.needs_gram && P.G === nothing) && continue
        spent, best = 0.0, Inf
        for tol in TOLS
          local β, t
          try
            β, t = bench_timed(S.run, P, λ, tol)
            SMOKE && check_fit(P, β, λ)
          catch err
            SMOKE && rethrow()
            @printf "    %-24s tol = %.0e failed: %s\n" S.name tol first(sprint(showerror, err), 120)
            break
          end
          row(S.name, S.package, tol, S.needs_gram ? P.gram_time : 0.0, β, t)
          spent += t
          best = min(best, relsubopt(objective(P, β, λ), Fstar))
          (t > RUN_CAP || spent > SOLVER_CAP || best < DONE) && break
        end
        @printf "    %-24s best rel. suboptimality %.1e, sweep %.1f s\n" S.name best spent
        flush(single); flush(stdout)
      end

      for (name, run) in DEFAULT_RUNS
        try
          β, t = bench_timed(run, P, λ)
          SMOKE && check_fit(P, β, λ; accuracy = false)
          row(name, "defaults", NaN, 0.0, β, t)
        catch err
          SMOKE && rethrow()
          # recorded with NaN accuracy, reported as an error
          @printf "    defaults %-15s failed: %s\n" name first(sprint(showerror, err), 120)
          @printf(single, "%s,%s,%g,%d,%s,%s,%g,%.6g,%.6g,%.6g,%.6g,%d,%d,%.6g\n", P.name, P.desc, frac,
                  nnzstar, name, "defaults", NaN, NaN, 0.0, NaN, NaN, -1, -1, NaN)
        end
      end
      flush(single)
    end

    λs = P.λmax .* 10 .^ range(0, -2; length = N_LAMBDA)
    tref = @elapsed ref = path_reference(P, λs)
    Fref = [objective(P, ref[k], λs[k]) for k in eachindex(λs)]
    @printf "  path: %d λ from λmax to λmax/100, nnz at the end %d (reference %.1f s)\n" N_LAMBDA count(!iszero, ref[end]) tref
    for S in PATH_SOLVERS
      (S.needs_gram && P.G === nothing) && continue
      spent, best = 0.0, Inf
      for tol in PATH_TOLS
        local B, t
        try
          B, t = bench_timed(S.run, P, λs, tol; maxreps = 3)
          if SMOKE
            length(B) == length(λs) || error("Smoke path was truncated.")
            foreach(k -> check_fit(P, B[k], λs[k]), eachindex(λs))
          end
        catch err
          SMOKE && rethrow()
          @printf "    path %-19s tol = %.0e failed: %s\n" S.name tol first(sprint(showerror, err), 120)
          break
        end
        K = length(B)
        sub = maximum(relsubopt(objective(P, B[k], λs[k]), Fref[k]) for k in 1:K)
        dif = maximum(maximum(abs, B[k] - ref[k]) for k in 1:K)
        sup = maximum(support_errors(B[k], ref[k]) for k in 1:K)
        @printf(paths, "%s,%s,%s,%s,%g,%.6g,%.6g,%.6g,%.6g,%d,%d\n", P.name, P.desc, S.name, S.package, tol, t,
                S.needs_gram ? P.gram_time : 0.0, K < length(λs) ? Inf : sub, dif, sup, K)
        spent += t
        best = min(best, sub)
        (t > RUN_CAP || spent > SOLVER_CAP || best < DONE) && break
      end
      @printf "    path %-19s best max rel. suboptimality %.1e, sweep %.1f s\n" S.name best spent
      flush(paths); flush(stdout)
    end
  end
  close(single)
  close(paths)
  SMOKE && check_smoke_outputs()
end

try
  main()
finally
  close_legacy_worker!()
end
