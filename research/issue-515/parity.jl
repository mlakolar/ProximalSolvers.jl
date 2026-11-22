# Correctness replay for #515: every #514 IndBallL1 fixture and accuracy profile, plus the
# #515 profile workloads, under B0 (the #514 code, arm B) and each candidate (B1, B2).
# For every solve it records the candidate's result, the #514 projection audit (exact PB
# projection inputs/steps/outputs digest, prox!/value_and_prox! byte parity at each call,
# accepted-iterate MPFR violation), the independent MPFR reference checks on the stored
# output, and field-by-field parity with B0. It also repeats the #514 callback/injected
# failure rollback probe for each candidate.
#
# Usage: julia --project=../issue-514/env/<v> [--check-bounds=yes] parity.jl <outdir> [short]
include(joinpath(@__DIR__, "common.jl"))

out = ARGS[1]
short = length(ARGS) > 1 && ARGS[2] == "short"
mkpath(out)

const CANDIDATES = (:B1 => B1, :B2 => B2)

function table(io, row)
    position(io) == 0 && println(io, join(keys(row), '\t'))
    println(io, join(values(row), '\t'))
end

digest!(ctx) = bytes2hex(SHA.digest!(ctx))

function run_arm(mod, d, f, g, m, a, audit)
    if mod === nothing
        b = budgets(d, a)
        r = projected_policy(Val(:B), d, f, g, m, b, a, audit)
        return r, b
    end
    b = mod.budgets(d, a)
    r = mod.as_namedtuple(mod.projected_policy(d, f, g, m, b, a, audit))
    r, b
end

const COMPARE = (:status, :success, :converged, :completed, :iterations, :trials, :rejected, :restarts,
                 :backtracks, :values, :membership, :smooth, :composite, :residual, :increased,
                 :gap, :gap_noise, :mapping, :map_noise, :b_work_margin, :feasibility_rejects,
                 :unresolved_rejects, :gradients, :projections, :stop_checks)

function differing(r0, r)
    bad = Symbol[]
    same_bits(r0.x, r.x) || push!(bad, :x)
    for k in COMPARE
        isequal(getproperty(r0, k), getproperty(r, k)) || push!(bad, k)
    end
    isempty(bad) ? "none" : join(bad, ',')
end

function workloads(T)
    ds = [d for d in fixtures(T; short) if d.ball === :l1]
    append!(ds, profile_fixtures(T; dims=short ? (2, 16) : PROFILE_DIMS))
    ds
end

profiles_for(d) = startswith(d.name, "pf_") ? (:ordinary,) :
    (startswith(d.name, "tie_scale") || startswith(d.name, "l1_tied") || d.name == "l1_correlated_active") ?
        (:ordinary, :tight, :mixed) : (:ordinary, :tight)

# Independent MPFR checks only where the reference is cheap: all #514 fixtures, and the
# profile workloads with a structured design or at most 256 columns.
reference_ok(d) = !startswith(d.name, "pf_") || d.design !== :dense || length(d.start) <= 256

function collect_case(io, d)
    f, g = loss(d), ball(d)
    ref = reference_ok(d) ? reference_data(d) : nothing
    # The profile workloads have no closed-form optimum; `independent` uses `best` only for
    # the reported x_error and witness_obj_error, which this table does not print.
    best = ref === nothing ? nothing :
           (startswith(d.name, "pf_") ? zeros(BigFloat, length(d.start)) : optimum(g, ref))
    for m in methods(d), profile in profiles_for(d)
        a = accuracy(d, profile)
        audit0 = Audit(d.start)
        r0, b0 = run_arm(nothing, d, f, g, m, a, audit0)
        t0 = digest!(audit0.trial_hash); mp0 = digest!(audit0.mapping_hash)
        for (label, mod) in ((:B0, nothing), CANDIDATES...)
            if mod === nothing
                r, b, audit, td, md = r0, b0, audit0, t0, mp0
            else
                audit = Audit(d.start)
                r, b = run_arm(mod, d, f, g, m, a, audit)
                td, md = digest!(audit.trial_hash), digest!(audit.mapping_hash)
            end
            q = ref === nothing ? nothing : independent(d, r.x, g, b, ref, best)
            # Each arm is scored against its own declared budgets (cap, gap, mapping); B2's
            # are recomputed with a different rounding and are reported alongside B0's.
            table(io, (; T=eltype(d.start), case=d.name, p=length(d.start), design=d.design,
                       method=name(m), profile, arm=label, status=r.status, success=r.success,
                       converged=r.converged, membership=r.membership, iterations=r.iterations,
                       trials=r.trials, rejected=r.rejected, restarts=r.restarts, gradients=r.gradients,
                       projections=r.projections, stop_checks=r.stop_checks,
                       prescreens=hasproperty(r, :prescreens) ? r.prescreens : 0,
                       prescreen_rejects=hasproperty(r, :prescreen_rejects) ? r.prescreen_rejects : 0,
                       acceptable=q === nothing ? missing : q.acceptable,
                       false_success=q === nothing ? missing : (r.success && !q.acceptable),
                       violation=q === nothing ? NaN : q.violation, witness_gap=q === nothing ? NaN : q.witness_gap,
                       independent_mapping=q === nothing ? NaN : q.mapping,
                       witness_loss_change=q === nothing ? NaN : q.witness_loss_change,
                       kkt=q === nothing ? NaN : q.kkt, complementarity=q === nothing ? NaN : q.complementarity,
                       cap=b.cap, gap_target=b.gap, mapping_target=b.mapping,
                       cap_bits_equal=b.cap === b0.cap && b.gap === b0.gap && b.mapping === b0.mapping &&
                                      b.curvature === b0.curvature,
                       estimated_gap=r.gap, gap_noise=r.gap_noise, estimated_mapping=r.mapping, map_noise=r.map_noise,
                       smooth=r.smooth, composite=r.composite,
                       accepted_exterior=audit.accepted_exterior,
                       max_accepted_violation=Float64(audit.max_accepted_violation),
                       over_cap_accepted=audit.max_accepted_violation > BigFloat(b.cap),
                       trial_parity_checks=audit.trials, mapping_parity_checks=audit.mappings,
                       trial_sha256=td, mapping_sha256=md, trial_digest_equal_B0=td == t0,
                       output_sha256=bytes2hex(sha256(reinterpret(UInt8, r.x))),
                       differs_from_B0=label === :B0 ? "none" : differing(r0, r),
                       error=replace(r.error, '\n' => ' ')))
        end
    end
end

# The #514 rollback probe (correctness.jl probe_rollback) for B0 and each candidate.
function rollback(io, T)
    d = only(filter(v -> v.name == "l1_correlated_interior", fixtures(T; short=true)))
    g, f = ball(d), loss(d)
    a = accuracy(d, :ordinary)
    for m in methods(d), (label, mod) in ((:B0, nothing), CANDIDATES...)
        rows = NamedTuple[]
        cb(row) = (push!(rows, row); true)
        audit = Audit(d.start)
        if mod === nothing
            b = budgets(d, a)
            previous = projected_policy(Val(:B), d, f, g, m, b, a; callback=cb)
            failed = projected_policy(Val(:B), d, f, g, m, b, a, audit; fault_after=2)
        else
            b = mod.budgets(d, a)
            previous = mod.projected_policy(d, f, g, m, b, a; callback=cb)
            failed = mod.projected_policy(d, f, g, m, b, a, audit; fault_after=2)
        end
        @assert previous.status === :callback_stop && failed.status === :injected_trial_failure
        @assert length(rows) == 1 && failed.iterations == 1
        @assert same_bits(previous.x, failed.x) && !same_bits(previous.x, d.start)
        table(io, (; T, case=d.name, method=name(m), arm=label, callback=previous.status,
                   callback_smooth=rows[1].smooth, callback_composite=rows[1].composite,
                   failure=failed.status, bitwise_rollback=true,
                   x_sha256=bytes2hex(sha256(reinterpret(UInt8, failed.x)))))
    end
end

# Regression rows from the independent #515 review (comment 7071291648): a one-ulp gap
# threshold case and a gradual-underflow case. Every candidate must reproduce B0's status
# and output bits; `onepass` records the withdrawn one-pass budgets on the first case.
function review_cases(io)
    eta = nextfloat(0f0)
    cases = (
        ("review_threshold_ulp", Fixture("review_threshold_ulp", :l1, :dense, reshape([0.25, 0.1], 2, 1), [1.0, 0.0],
                                         16.0, [0.0], 1.0), Accuracy(1e-5, 0.0, 0.3372675092849525, 1.0), 1),
        ("review_underflow", Fixture("review_underflow", :l1, :dense, Float32[0.75 0.75], [-3eta], 4eta,
                                     [-2eta, -2eta], 1f0), nothing, 3))
    # Review round 2 (comment 7072380127): Float64 case whose unscaled ||x||^2 underflows;
    # B0 rejects the proposal, and the screen's bound must hold as well (`bound_holds` below).
    X3 = zeros(2, 32); X3[1, :] .= 0x1p500
    x3 = [0x1p-540; fill(0x1p-594, 30); -0x1p-540]
    a3 = Accuracy(1e-10, 0.0, 8.326672684688671e-16, 1e-8)
    d3 = Fixture("review_norm_underflow", :l1, :dense, X3, [30 * 0x1p-94, 0.0], 0x1p-538, x3, 1.0)
    b3 = B2.budgets(d3, a3)
    G3 = zeros(32); z3 = zeros(2); dz3 = zeros(2)
    PS._image!(z3, PS._image_model(loss(d3)), x3)
    f3 = PS._value_and_gradient!(G3, x3, loss(d3), z3, dz3)
    dec3 = B2.norm_decision(x3, ball(d3), b3.cap)
    ref3 = reference_data(d3)
    exact_gap = independent(d3, x3, ball(d3), b3, ref3, zeros(BigFloat, 32)).witness_gap
    screened = B2.prescreen_rejects(G3, x3, dec3, d3, ball(d3), b3, f3)
    table(io, (; case="review_norm_underflow", T=Float64, method="screen", arm=:B2, status=screened ? :screened : :full_check,
               iterations=0, gap_target=b3.gap, estimated_gap=exact_gap,
               same_status_as_B0=true, same_bits_as_B0=true,
               output=string("bound_holds=", !screened || exact_gap > b3.gap)))
    for (label, d, acc, maxiter) in cases
        f, g = loss(d), ball(d)
        a = acc === nothing ? accuracy(d, :ordinary) : acc
        for m in methods(d)
            b0 = budgets(d, a)
            r0 = projected_policy(Val(:B), d, f, g, m, b0, a; maxiter)
            arms = Any[(:B0, r0, b0)]
            for (lab, mod) in CANDIDATES
                b = mod.budgets(d, a)
                push!(arms, (lab, mod.as_namedtuple(mod.projected_policy(d, f, g, m, b, a; maxiter)), b))
            end
            bo = B2.budgets_onepass(d, a)
            push!(arms, (:B2_onepass_budgets, B2.as_namedtuple(B2.projected_policy(d, f, g, m, bo, a; maxiter)), bo))
            for (lab, r, b) in arms
                table(io, (; case=label, T=eltype(d.start), method=name(m), arm=lab, status=r.status,
                           iterations=r.iterations, gap_target=b.gap, estimated_gap=r.gap,
                           same_status_as_B0=r.status === r0.status, same_bits_as_B0=same_bits(r.x, r0.x),
                           output=bytes2hex(reinterpret(UInt8, r.x))))
            end
        end
    end
end

setprecision(BigFloat, 2304) do
    open(joinpath(out, "review_cases.tsv"), "w") do io
        review_cases(io)
    end
    open(joinpath(out, "parity.tsv"), "w") do io
        open(joinpath(out, "rollback.tsv"), "w") do rio
            for T in (Float32, Float64)
                for d in workloads(T)
                    collect_case(io, d)
                    flush(io)
                end
                rollback(rio, T)
            end
        end
    end
end
