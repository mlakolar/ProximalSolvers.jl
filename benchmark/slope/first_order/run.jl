include("common.jl")
include("profile.jl")
out=abspath(option("--out","results"));mkpath(out)
shard=parse(Int,option("--shard","1"));shards=parse(Int,option("--shards","1"))
seeds=parse.(Int,split(option("--seeds","1,2,3"),','));rounds=parse(Int,option("--rounds","3"))
canary="--canary" in ARGS;profiles="--profiles" in ARGS
P=problem(40,60,.9,5,0);w=weight_sequence("bh",60);a=alpha_max(P.X,P.y,w).*[1.,.3,.05]
for method in CONTROL_METHODS
    timed_control(P.X,P.y,w,a,method)
end
check_profile_match(timed_reuse(P.X,P.y,w,a,"workspace_L"),timed_profile(P.X,P.y,w,a))
callfields=("n","p","rho","sparsity","weights","seed","round","method","seconds","julia_bytes",
            "valid","status","returned","max_gap","passes","iterations","grad_calls","prox_calls","certificate_calls","restarts","backtracks","objective_rel_vs_library")
levelfields=("n","p","rho","sparsity","weights","seed","round","method","level","alpha","valid","gap","primal","dual","feasibility","fixedpoint","passes")
profilefields=("n","p","rho","sparsity","weights","seed","round","profile_first","plain_seconds","profile_seconds","valid","exact_match",
               "iterations","grad_calls","prox_calls","certificate_calls","restarts","backtracks",
               "gradient_ns","prox_ns","trial_loss_ns","update_ns","certificate_ns","setup_ns","total_ns")
open(joinpath(out,"calls-$shard.csv"),"w") do calls
open(joinpath(out,"levels-$shard.csv"),"w") do levels
open(joinpath(out,"profiles-$shard.csv"),"w") do profileout
    write_csv(calls,callfields);write_csv(levels,levelfields);write_csv(profileout,profilefields)
    index=0
    for rho in (0.,.9),s in (canary ? [10] : [10,100]),seed in seeds
        index+=1;mod(index-1,shards)+1==shard || continue
        n,p=canary ? (80,120) : (1000,2000)
        P=problem(n,p,rho,s,seed)
        for kind in ("linear","bh")
            w=weight_sequence(kind,p);alphas=alpha_max(P.X,P.y,w).*path_fractions()
            for rep in 1:rounds
                methods=collect(CONTROL_METHODS)
                shuffle!(Xoshiro(57400+seed+rep*100+s+Int(100rho)),methods)
                fits=Dict()
                for method in methods
                    fits[method]=try timed_control(P.X,P.y,w,alphas,method) catch err
                        println(stderr,"FIT_ERROR $rho $s $kind $seed $rep $method: ",sprint(showerror,err));nothing
                    end
                end
                base=fits["SLOPE.jl"]
                for method in methods
                    fit=fits[method];prefix=(n,p,rho,s,kind,seed,rep,method)
                    if fit===nothing
                        write_csv(calls,(prefix...,NaN,-1,false,:exception,0,Inf,-1,-1,-1,-1,-1,-1,-1,NaN))
                    else
                        apg=method=="APG_workspace_L"
                        total(field)=apg ? sum(getproperty(i,field) for i in fit.infos) : -1
                        delta=base!==nothing && length(fit.metrics)==length(base.metrics) ? maximum(abs(m.primal-b.primal)/max(1,abs(b.primal)) for (m,b) in zip(fit.metrics,base.metrics)) : NaN
                        write_csv(calls,(prefix...,fit.seconds,fit.julia_bytes,fit.valid,fit.status,length(fit.betas),maximum(m.gap for m in fit.metrics),
                            startswith(method,"native_") ? sum(fit.passes) : -1,total(:iterations),total(:ng),total(:np),total(:certificate_calls),total(:restarts),total(:backtracks),delta))
                    end
                    for k in eachindex(alphas)
                        if fit===nothing || k>length(fit.betas)
                            write_csv(levels,(prefix...,k,alphas[k],false,Inf,NaN,NaN,Inf,Inf,-1))
                        else
                            m=fit.metrics[k]
                            write_csv(levels,(prefix...,k,alphas[k],m.valid,m.gap,m.primal,m.dual,m.feasibility,m.fixedpoint,fit.passes[k]))
                        end
                    end
                end
            end
            if profiles
                for rep in 1:rounds
                    # Pair in random order, separately from solver-comparison blocks.
                    order=rand(Xoshiro(57500+seed+100rep+s+Int(100rho)),Bool)
                    if order
                        plain=timed_reuse(P.X,P.y,w,alphas,"workspace_L");profiled=timed_profile(P.X,P.y,w,alphas)
                    else
                        profiled=timed_profile(P.X,P.y,w,alphas);plain=timed_reuse(P.X,P.y,w,alphas,"workspace_L")
                    end
                    matched=check_profile_match(plain,profiled)
                    total(field)=sum(getproperty(i,field) for i in profiled.infos)
                    t=profiled.times
                    write_csv(profileout,(n,p,rho,s,kind,seed,rep,!order,plain.seconds,profiled.seconds,profiled.valid,matched,
                        total(:iterations),total(:ng),total(:np),total(:certificate_calls),total(:restarts),total(:backtracks),
                        t.gradient_ns,t.prox_ns,t.trial_loss_ns,t.update_ns,t.certificate_ns,t.setup_ns,t.total_ns))
                end
            end
            println("COMPLETE rho=$rho s=$s weights=$kind seed=$seed");flush(stdout)
        end
    end
end
end
end
println("FIRST_ORDER_COMPLETE shard=$shard")
