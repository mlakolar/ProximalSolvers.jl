include("load.jl")
include("historical.jl")

out = ARGS[1]
short = length(ARGS) > 1 && ARGS[2] == "short"
mkpath(out)

function table(io, row)
    if position(io) == 0
        println(io, join(keys(row), '\t'))
    end
    println(io, join(values(row), '\t'))
end

function clipping_controls(io, T)
    fixtures, f, y = controls(T)
    for (label, g, reference) in fixtures
        p = similar(y)
        q = similar(y)
        PB.prox!(p, g, y, one(T))
        v = PB.value_and_prox!(q, g, y, one(T))
        @assert same_bits(p, q) && p == reference && iszero(v)
        for m in (PS.ProximalGradientDescent(), PS.AccProxGradDescent())
            x = zeros(T, length(y))
            allowed = label !== :nonnegative || m isa PS.ProximalGradientDescent
            opts = PS.ProximalOptions(; allow_f_increases=true)
            status = if allowed
                r = PS.solve!(x, f, g, m, opts)
                @assert r.converged && iszero(g(x)) && maximum(abs,x-reference) < 1e-4
                :converged
            else
                rejected = false
                try
                    PS.solve!(x, f, g, m, opts)
                catch e
                    e isa ArgumentError || rethrow()
                    rejected = true
                end
                @assert rejected && iszero(x)
                :public_refused
            end
            table(io, (; T, control=label, method=name(m), status, projection_parity=true))
        end
    end
end

function probe_rollback(io, d, method, arm)
    g, f = ball(d), loss(d)
    a = accuracy(d, :ordinary)
    b = budgets(d, a)
    rows = NamedTuple[]
    function cb(row)
        push!(rows, row)
        true
    end
    previous = projected_policy(arm, d, f, g, method, b, a; callback=cb)
    audit = Audit(d.start)
    failed = projected_policy(arm, d, f, g, method, b, a, audit; fault_after=2)
    @assert previous.status === :callback_stop && failed.status === :injected_trial_failure
    @assert length(rows) == 1 && failed.iterations == 1
    @assert same_bits(previous.x, failed.x) && !same_bits(previous.x, d.start)
    table(io,(; T=eltype(d.start), case=d.name, method=name(method), arm=arm isa Val{:B} ? :B : :C,
               callback=previous.status, callback_smooth=rows[1].smooth,
               callback_composite=rows[1].composite, failure=failed.status, bitwise_rollback=true))
end

function probe_oracles(io, T, data)
    for d in data
        d.design === :diagonal && all(isfinite, d.start) || continue
        d.name in ("rounded_zero_predictor", "l1_interior") && continue
        g = ball(d)
        z = iszero(d.start) ? d.y ./ diag(d.X) : d.start
        for gamma in (one(T), T(0.125))
            out, fused = similar(z), similar(z)
            PB.prox!(out, g, z, gamma)
            fv = PB.value_and_prox!(fused, g, z, gamma)
            @assert same_bits(out, fused) && isequal(fv, g(out))
            inplace, inplace_fused = copy(z), copy(z)
            PB.prox!(inplace, g, inplace, gamma)
            av = PB.value_and_prox!(inplace_fused, g, inplace_fused, gamma)
            @assert same_bits(inplace,inplace_fused) && isequal(av,g(inplace))
            signed = big_norm(g,BigFloat.(out))-BigFloat(g.r)
            for cap in (0.0, ldexp(Float64(d.r), -54), ldexp(Float64(d.r), -40), 1e-10*Float64(d.r))
                B = decision(Val(:B), out, g, cap; stop=true)
                C = g isa L1 ? decision(Val(:C), out, g, cap; stop=true) : nothing
                if g isa L1
                    for bounds in (Enclosure1138.wide_screen(out, g.r), Enclosure1138.compensated(out, g.r))
                        @assert bounds !== nothing && BigFloat(bounds[1]) <= signed <= BigFloat(bounds[2])
                    end
                end
                table(io,(; T, case=d.name, ball=d.ball, p=length(out), gamma, cap, pb_value=fv,
                           exact_margin=Float64(signed), exact_pass=signed <= BigFloat(cap), B=B.code,
                           B_sign=B.membership, C=C === nothing ? :na : C.code,
                           C_sign=C === nothing ? :na : C.membership,
                           C_refined=C !== nothing && C.refined, output_sha256=bytes2hex(sha256(reinterpret(UInt8,out))),
                           alias_bits_equal=same_bits(out,inplace)))
            end
        end
    end
end

function metric_row(d, method, profile, label, a, b, r, q, public_r, audit)
    (; T=eltype(d.start), case=d.name, ball=d.ball, design=d.design, p=length(d.start),
       radius=d.r, alpha=d.alpha, method=name(method), profile, arm=label,
       public_status=public_r.status, status=r.status, r.completed, r.success, r.converged,
       acceptable=q.acceptable, false_success=r.success && !q.acceptable,
       q.violation, q.signed_margin, work_margin=norm_64(r.x,ball(d))-Float64(d.r),
       native_indicator=ball(d)(r.x), r.membership, cap=b.cap,
       gap_target=b.gap, q.witness_gap, estimated_gap=r.gap, r.gap_noise,
       mapping_target=b.mapping, mapping_L=b.curvature, independent_mapping=q.mapping,
       estimated_mapping=r.mapping, r.map_noise, q.kkt, q.complementarity, q.witness_loss_change,
       q.witness_obj_error, q.x_error, q.native_grad, q.exact_grad, smooth_reference=q.smooth,
       smooth_monitor=r.smooth, returned_composite=r.composite, q.exact_composite, r.residual, r.increased,
       r.native_residual, r.iterations, r.gradients, r.values, r.projections, r.trials, r.rejected,
       r.backtracks, r.restarts, r.feasibility_rejects, r.unresolved_rejects, r.cap_refines,
       r.stop_refines, r.stop_checks, accepted_exterior=audit.accepted_exterior,
       max_accepted_violation=Float64(audit.max_accepted_violation),
       trial_parity=audit.trials, mapping_parity=audit.mappings, fused_nonfinite=audit.nonfinite_fused,
       trial_sha256=bytes2hex(SHA.digest!(audit.trial_hash)), mapping_sha256=bytes2hex(SHA.digest!(audit.mapping_hash)),
       output_sha256=bytes2hex(sha256(reinterpret(UInt8,r.x))), error=replace(r.error,'\n'=>' '))
end

function collect_results(io, traceio, vectorio, historyio, d)
    f, g = loss(d), ball(d)
    ref = reference_data(d)
    best = optimum(g, ref)
    q_best = big_norm(g,best)
    @assert q_best <= ref.r + big"1e-53" * max(ref.r,1)
    profiles = short ? (:ordinary,) :
        (startswith(d.name,"tie_scale") || startswith(d.name,"l1_tied") ||
         d.name in ("l1_correlated_active", "l2_blocks_active_5", "l2_diagonal_active_2048")) ?
         (:ordinary,:tight,:mixed) : (:ordinary,:tight)
    for method in methods(d), profile in profiles
        a = accuracy(d, profile)
        b = budgets(d, a)
        public_r = public_control(d,f,g,method; profile)
        audit = Audit(d.start)
        strict = strict_control(d,f,g,method,audit; profile)
        if g isa L1 || length(d.start) != 4
            @assert public_r.status === :refused && same_bits(public_r.x,d.start)
        else
            @assert same_bits(public_r.x,strict.x)
            @assert (public_r.result !== nothing) == strict.completed
            if strict.completed
                @assert public_r.result.iterations == strict.iterations
                @assert public_r.result.converged == strict.success
                @assert public_r.result.minimum == strict.composite
            end
        end
        for arm in (g isa L1 ? (:A,:B,:C) : (:A,:B))
            arm === :A || (audit = Audit(d.start))
            result = arm === :A ? strict : projected_policy(Val(arm),d,f,g,method,b,a,audit)
            q = independent(d,result.x,g,b,ref,best)
            row = metric_row(d,method,profile,arm,a,b,result,q,public_r,audit)
            table(io,row)
            table(vectorio,(; T=eltype(d.start), case=d.name, method=name(method), profile, arm,
                             x=bytes2hex(reinterpret(UInt8,result.x))))
            if length(d.start) <= 5 && (d.name in ("tie_scale_0", "rounded_zero_predictor",
                                                  "l1_correlated_interior", "l2_1036_4", "l2_1036_5",
                                                  "l1_exact_boundary_stop", "stationary_tail_0.25_eps"))
                for step in audit.trace
                    if arm === :A
                        table(traceio,(; T=eltype(d.start), case=d.name, method=name(method), profile, arm,
                                       step.iteration, step.monitor, step.smooth, composite=step.monitor,
                                       residual=missing, increased=missing, step.L, step.violation))
                    else
                        table(traceio,(; T=eltype(d.start), case=d.name, method=name(method), profile, arm, step...))
                    end
                end
            end
        end
        if (profile === :ordinary && startswith(d.name,"tie_scale")) ||
           (profile === :tight && d.name in ("rounded_zero_predictor","l1_correlated_interior"))
            arm = profile === :ordinary ? :H4eps : :Hworking
            r = historical(Val(arm),d,f,g,method,b)
            q = independent(d,r.x,g,b,ref,best)
            table(historyio,(; T=eltype(d.start), case=d.name, method=name(method), arm,
                             r.converged,r.iterations,r.score,q.violation,q.witness_gap,target=b.gap,
                             q.native_grad,q.exact_grad, false_exact_feasibility=r.converged&&q.violation>0,
                             false_gap=r.converged&&q.witness_gap>b.gap,q.acceptable))
        end
    end
end

setprecision(BigFloat, 2304) do
    open(joinpath(out,"solves.tsv"),"w") do solves
        open(joinpath(out,"traces.tsv"),"w") do traces
            open(joinpath(out,"vectors.tsv"),"w") do vectors
                open(joinpath(out,"historical.tsv"),"w") do hist
                    for T in (Float32,Float64)
                        data = fixtures(T;short)
                        for d in data
                            collect_results(solves,traces,vectors,hist,d)
                        end
                        open(joinpath(out,"projections-$T.tsv"),"w") do io
                            probe_oracles(io,T,data)
                        end
                        open(joinpath(out,"controls-$T.tsv"),"w") do io
                            clipping_controls(io,T)
                            d = only(filter(v -> v.name=="l1_correlated_interior",data))
                            for method in methods(d), arm in (Val(:B),Val(:C))
                                # Separate table for assertions that exercise the rollback boundary.
                                open(joinpath(out,"rollback-$T.tsv"),"a") do roll
                                    probe_rollback(roll,d,method,arm)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
