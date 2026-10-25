using LinearAlgebra, SparseArrays, Statistics, Printf
using ProximalBase, ProximalSolvers
include(joinpath(@__DIR__, "..", "..", "examples", "support", "primal_dual_lessons.jl"))
using .PrimalDualLessons
include("qp.jl")

BLAS.set_num_threads(1)
const TOL = 1e-6
const REPEATS = parse(Int, get(ENV, "LESSON_REPEATS", "3"))
REPEATS > 0 || error("LESSON_REPEATS must be positive")
const OUT = get(ENV, "LESSON_OUT", joinpath(@__DIR__, "results"))
mkpath(OUT)

methods(a) = a.name == "graph" ?
    [("CondatVu", x -> native_solve(x; tol = TOL)),
     ("ADMM-rho1", x -> split_admm(x; ρ = 1.0, tol = TOL)),
     ("ADMM-rho10", x -> split_admm(x; ρ = 10.0, tol = TOL)),
     ("HiGHS-QP", x -> qp_solve(x; tol = TOL))] :
    [("CondatVu", x -> native_solve(x; tol = TOL)),
     ("ADMM-rho1", x -> split_admm(x; ρ = 1.0, tol = TOL)),
     ("ADMM-rho10", x -> split_admm(x; ρ = 10.0, tol = TOL)),
     ("ADMM-rho100", x -> split_admm(x; ρ = 100.0, tol = TOL)),
     ("TV-split-ADMM", x -> trend_admm(x; tol = TOL)),
     ("HiGHS-QP", x -> qp_solve(x; tol = TOL))]

# Compile every complete call path, including setup and scheduled certificates.
for a in (graph_problem(5), trend_problem(40)), (_, solve) in methods(a)
    solve(a).converged || error("warm-up did not converge")
end

rows = []
for a in (graph_problem(16), graph_problem(32), trend_problem(400), trend_problem(1600))
    reference = qp_solve(a; tol = TOL)
    reference.converged || error("QP certificate exceeds target")
    fits = Dict{String,Vector{Float64}}()
    for (method, solve) in methods(a)
        runs = []
        for _ in 1:REPEATS
            GC.gc()
            push!(runs, solve(a))
        end
        # Report the measured run with the median total, preserving consistent
        # setup/solve/iteration/certificate columns for that same run.
        r = runs[sortperm([r.setup + r.seconds for r in runs])[cld(REPEATS, 2)]]
        all(s -> abs(s.cert.primal - reference.cert.primal) <= s.cert.gap + reference.cert.gap + 1e-7, runs) ||
            error("objective difference exceeds certificates")
        all(s -> norm(s.x - reference.x) <= s.cert.distance_bound + reference.cert.distance_bound + 1e-7, runs) ||
            error("solution difference exceeds certificates")
        fits[method] = r.x
        push!(rows, (problem = a.name, p = a.p, edges = size(a.D, 1), method,
                     setup_seconds = r.setup, solve_seconds = r.seconds,
                     total_seconds = r.setup + r.seconds,
                     min_total = minimum(s.setup + s.seconds for s in runs),
                     max_total = maximum(s.setup + s.seconds for s in runs),
                     iterations = r.iterations, converged = all(s -> s.converged, runs), certificate = r.cert.relative,
                     objective = r.cert.primal, reference_objective = reference.cert.primal,
                     coefficient_l2_error = norm(r.x - reference.x),
                     distance_bound = r.cert.distance_bound, factor_nnz = r.factor_nnz))
        @printf("%s p=%d %-14s setup %.4fs solve %.4fs gap %.2e converged=%s\n",
                a.name, a.p, method, r.setup, r.seconds, r.cert.relative, r.converged)
        flush(stdout)
    end
    # Enough data to recreate the teaching figures without rerunning solvers.
    if a.name == "trend" || a.p == 256
        open(joinpath(OUT, "$(a.name)-$(a.p)-fits.csv"), "w") do io
            println(io, "index,truth,observation,fit,reference")
            for i in 1:a.p
                observation = a.X === nothing ? a.b[i] : NaN
                println(io, join((i, a.truth[i], observation, fits["CondatVu"][i], reference.x[i]), ','))
            end
        end
    end
end
open(joinpath(OUT, "comparison.csv"), "w") do io
    println(io, join(keys(first(rows)), ','))
    for row in rows
        println(io, join(values(row), ','))
    end
end
open(joinpath(OUT, "environment.txt"), "w") do io
    println(io, "Julia ", VERSION, "; CPU ", Sys.CPU_NAME, "; threads ", Threads.nthreads())
    println(io, "BLAS ", BLAS.get_config(), "; threads ", BLAS.get_num_threads())
    println(io, "repeats=", REPEATS, "; common certificate target=", TOL)
    println(io, "JuMP ", pkgversion(JuMP), "; HiGHS ", pkgversion(HiGHS))
    for pkg in (ProximalBase, ProximalSolvers)
        root = pkgdir(pkg)
        sha = readchomp(`git -C $root rev-parse HEAD`)
        dirty = !isempty(readchomp(`git -C $root status --porcelain --untracked-files=no`))
        println(io, nameof(pkg), " ", pkgversion(pkg), " source=", sha, " tracked_changes=", dirty)
    end
    root = pkgdir(ProximalSolvers)
    for relative in ("examples/support/primal_dual_lessons.jl",
                     "benchmark/composite_lessons/run.jl", "benchmark/composite_lessons/qp.jl")
        path = joinpath(root, relative)
        println(io, relative, " git-blob=", readchomp(`git hash-object $path`))
    end
end
