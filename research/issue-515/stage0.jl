# Stage 0 profile of the #514 B0 prototype (PGD/APG, Float32/Float64, dense IndBallL1 LS).
# Usage: julia --project=../issue-514/env/<v> stage0.jl <outdir> [quick]
include(joinpath(@__DIR__, "..", "issue-514", "load.jl"))
include(joinpath(@__DIR__, "profile_fixtures.jl"))
include(joinpath(@__DIR__, "stage0_probe.jl"))
using Statistics, InteractiveUtils

out = ARGS[1]
quick = length(ARGS) > 1 && ARGS[2] == "quick"
mkpath(out)

const CASES514 = ("tie_scale_0", "l1_interior", "l1_correlated_active", "l1_correlated_interior",
                  "l1_tied_2048_1", "l1_correlated_2048")

function workloads(T)
    ds = [d for d in fixtures(T) if d.name in CASES514]
    append!(ds, profile_fixtures(T; dims=quick ? (2, 16, 256) : PROFILE_DIMS))
    ds
end

b0_run(d, f, g, m, a) = projected_policy(Val(:B), d, f, g, m, budgets(d, a), a)

function same_result(r, q)
    same_bits(r.x, q.x) || return false
    for k in (:status, :success, :converged, :iterations, :gradients, :values, :projections, :trials,
              :restarts, :backtracks, :stop_checks, :feasibility_rejects, :unresolved_rejects, :membership)
        isequal(getproperty(r, k), getproperty(q, k)) || return false
    end
    for k in (:gap, :gap_noise, :mapping, :map_noise, :smooth, :residual)
        isequal(getproperty(r, k), getproperty(q, k)) || return false
    end
    true
end

# Seconds-scale batches; returns the median and minimum per-call ns over `reps` batches.
function time_calls(fun, target_ns=2e7, reps=9)
    fun()
    t0 = time_ns(); fun(); one = max(Float64(time_ns() - t0), 50.0)
    n = clamp(round(Int, target_ns / one), 1, 100_000)
    samples = Float64[]
    for _ in 1:reps
        t = time_ns()
        for _ in 1:n
            fun()
        end
        push!(samples, (time_ns() - t) / n)
    end
    median(samples), minimum(samples), n
end

function timer_overhead()
    reset_stages!()
    n = 1_000_000
    t = time_ns()
    for _ in 1:n
        @stage row nothing
    end
    ns = (time_ns() - t) / n
    reset_stages!()
    ns
end

function a_run(d, f, g, m)
    r = native_A(d, f, g, m)
    r
end

function main()
    tov = timer_overhead()
    println(stderr, "timer overhead per stage ≈ $(round(tov, digits=1)) ns")
    open(joinpath(out, "stage0.tsv"), "w") do io
        open(joinpath(out, "stops.tsv"), "w") do sio
            header = false
            sheader = false
            for T in (Float32, Float64), d in workloads(T)
                f, g = loss(d), ball(d)
                a = accuracy(d, :ordinary)
                for m in methods(d)
                    r0 = b0_run(d, f, g, m, a)
                    empty!(STOPLOG)
                    rp = probe_policy(d, f, g, m, a; log_working=true)
                    @assert same_result(r0, rp) "probe/B0 mismatch on $(d.name) $T $(name(m))"
                    stops = copy(STOPLOG)
                    # uninstrumented totals
                    b0_med, b0_min, nb = time_calls(() -> b0_run(d, f, g, m, a))
                    a_med, a_min, _ = time_calls(() -> a_run(d, f, g, m))
                    ra = a_run(d, f, g, m)
                    b0_alloc = (b0_run(d, f, g, m, a); @allocated b0_run(d, f, g, m, a))
                    b0_count = @allocations b0_run(d, f, g, m, a)
                    a_alloc = (a_run(d, f, g, m); @allocated a_run(d, f, g, m))
                    a_count = @allocations a_run(d, f, g, m)
                    budget_alloc = (budgets(d, a); @allocated budgets(d, a))
                    bb = budgets(d, a)
                    nob_med, _, _ = time_calls(() -> projected_policy(Val(:B), d, f, g, m, bb, a))
                    stop_at = r0.iterations
                    ro = oracle_policy(d, f, g, m, bb, a, stop_at)
                    @assert same_bits(ro.x, r0.x) && ro.iterations == r0.iterations && ro.success == r0.success
                    orc_med, _, _ = time_calls(() -> oracle_policy(d, f, g, m, bb, a, stop_at))
                    bud_med, _, _ = time_calls(() -> budgets(d, a))
                    ws_med, _, _ = time_calls(() -> StopWorkspace(d))
                    # instrumented stage profile
                    reps = clamp(round(Int, 2e8 / max(b0_med, 1.0)), 3, 20_000)
                    probe_policy(d, f, g, m, a)
                    reset_stages!()
                    t = time_ns()
                    for _ in 1:reps
                        probe_policy(d, f, g, m, a)
                    end
                    probe_total = (time_ns() - t) / reps
                    stage_ns = (ST_NS ./ reps) .- tov .* (ST_N ./ reps)
                    stage_n = ST_N ./ reps
                    a_res = ra.result
                    row = (; T, case=d.name, p=length(d.start), design=d.design, method=name(m),
                           status=r0.status, iterations=r0.iterations, trials=r0.trials, rejected=r0.rejected,
                           restarts=r0.restarts, gradients=r0.gradients, projections=r0.projections, values=r0.values,
                           stop_checks=r0.stop_checks, stop_pass=count(s -> s.pass == 1, stops),
                           feasibility_rejects=r0.feasibility_rejects, unresolved_rejects=r0.unresolved_rejects,
                           a_status=ra.status, a_iterations=a_res === nothing ? missing : a_res.iterations,
                           a_gradients=a_res === nothing ? missing : a_res.grad_calls,
                           a_projections=a_res === nothing ? missing : a_res.prox_calls,
                           b0_med_ns=b0_med, b0_min_ns=b0_min, a_med_ns=a_med, a_min_ns=a_min,
                           b0_bytes=b0_alloc, b0_allocs=b0_count, a_bytes=a_alloc, a_allocs=a_count,
                           budget_bytes=budget_alloc, nobudget_med_ns=nob_med, oracle_med_ns=orc_med,
                           budgets_med_ns=bud_med, workspace_med_ns=ws_med, oracle_checks=ro.stop_checks,
                           probe_total_ns=probe_total, timer_ns=tov, reps)
                    stage_cols = NamedTuple{Tuple(Symbol.("ns_", STAGES))}(Tuple(stage_ns))
                    count_cols = NamedTuple{Tuple(Symbol.("n_", STAGES))}(Tuple(stage_n))
                    full = merge(row, stage_cols, count_cols)
                    if !header
                        println(io, join(keys(full), '\t')); header = true
                    end
                    println(io, join(values(full), '\t'))
                    flush(io)
                    for (k, s) in enumerate(stops)
                        srow = (; T, case=d.name, p=length(d.start), method=name(m), check=k, s.pass, s.gap_ratio,
                                s.map_ratio, s.gap_noise_ratio, s.map_noise_ratio, s.working_gap_ratio)
                        if !sheader
                            println(sio, join(keys(srow), '\t')); sheader = true
                        end
                        println(sio, join(values(srow), '\t'))
                    end
                    println(stderr, "$(T) $(d.name) $(name(m)) it=$(r0.iterations) checks=$(r0.stop_checks) ",
                            "B0=$(round(b0_med/1e3, digits=2))µs A=$(round(a_med/1e3, digits=2))µs ($(ra.status)) ",
                            "probe=$(round(probe_total/1e3, digits=2))µs status=$(r0.status)")
                end
            end
        end
    end
end

setprecision(BigFloat, 2304) do
    main()
end
