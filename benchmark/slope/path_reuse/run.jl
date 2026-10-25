include("common.jl")
out=abspath(option("--out","results"));mkpath(out)
shard=parse(Int,option("--shard","1"));shards=parse(Int,option("--shards","1"))
seeds=parse.(Int,split(option("--seeds","1,2,3,4,5"),','));rounds=parse(Int,option("--rounds","3"))
canary="--canary" in ARGS
P=problem(40,60,0.9,5,0);w=weight_sequence("bh",60);a=alpha_max(P.X,P.y,w)
for method in REUSE_METHODS
    timed_reuse(P.X,P.y,w,a.*[1.,0.3,0.05],method;limit=5.)
end
callfields=("n","p","rho","sparsity","weights","seed","round","method","seconds","julia_bytes","valid","status","returned","max_gap","iterations","backtracks","restarts","f_calls","grad_calls","prox_calls","certificate_calls","objective_rel_vs_library")
levelfields=("n","p","rho","sparsity","weights","seed","round","method","level","alpha","valid","status","gap","primal","dual","feasibility","fixedpoint","iterations","initial_L","final_L","initial_k","final_k","backtracks","restarts")
open(joinpath(out,"calls-$shard.csv"),"w") do calls
open(joinpath(out,"levels-$shard.csv"),"w") do levels
    write_csv(calls,callfields);write_csv(levels,levelfields)
    index=0
    for rho in (canary ? [0.9] : [0.,0.9]),s in (canary ? [10] : [10,100]),seed in seeds
        index+=1;mod(index-1,shards)+1==shard || continue
        n,p=canary ? (80,120) : (1000,2000)
        P=problem(n,p,rho,s,seed)
        for kind in ("linear","bh")
            w=weight_sequence(kind,p);alphas=alpha_max(P.X,P.y,w).*path_fractions()
            for rep in 1:rounds
                methods=collect(REUSE_METHODS);shuffle!(Xoshiro(57300+seed+rep*100+s+Int(100rho)),methods)
                fits=Dict()
                for method in methods
                    fits[method]=try timed_reuse(P.X,P.y,w,alphas,method) catch err
                        println(stderr,"FIT_ERROR $rho $s $kind $seed $rep $method: ",sprint(showerror,err));nothing
                    end
                end
                base=fits["SLOPE.jl"]
                for method in methods
                    fit=fits[method];prefix=(n,p,rho,s,kind,seed,rep,method)
                    if fit===nothing
                        write_csv(calls,(prefix...,NaN,-1,false,:exception,0,Inf,-1,-1,-1,-1,-1,-1,-1,NaN))
                    else
                        native=method!="SLOPE.jl"
                        total(field)=native ? sum(getproperty(i,field) for i in fit.infos) : -1
                        delta=base!==nothing && length(fit.metrics)==length(base.metrics) ? maximum(abs(m.primal-b.primal)/max(1,abs(b.primal)) for (m,b) in zip(fit.metrics,base.metrics)) : NaN
                        write_csv(calls,(prefix...,fit.seconds,fit.julia_bytes,fit.valid,fit.status,length(fit.betas),maximum(m.gap for m in fit.metrics),total(:iterations),total(:backtracks),total(:restarts),total(:nf),total(:ng),total(:np),total(:certificate_calls),delta))
                    end
                    for k in eachindex(alphas)
                        if fit===nothing || k>length(fit.betas)
                            write_csv(levels,(prefix...,k,alphas[k],false,:not_returned,Inf,NaN,NaN,Inf,Inf,-1,NaN,NaN,-1,-1,-1,-1))
                        else
                            m=fit.metrics[k];i=fit.infos[k];native=method!="SLOPE.jl"
                            extra= native ? (i.initial_L,i.final_L,i.initial_k,i.final_k,i.backtracks,i.restarts) : (NaN,NaN,-1,-1,-1,-1)
                            write_csv(levels,(prefix...,k,alphas[k],m.valid,i.status,m.gap,m.primal,m.dual,m.feasibility,m.fixedpoint,i.iterations,extra...))
                        end
                    end
                end
            end
            println("COMPLETE rho=$rho s=$s weights=$kind seed=$seed");flush(stdout)
        end
    end
end
end
println("PATH_REUSE_COMPLETE shard=$shard")
