include("common.jl")
const OUT=abspath(option("--out","results"))
const SHARD=parse(Int,option("--shard","1"));const SHARDS=parse(Int,option("--shards","1"))
const SEEDS=parse.(Int,split(option("--seeds","1,2,3,4,5"),','))
const ROUNDS=parse(Int,option("--rounds","3"))
const LIMIT=parse(Float64,option("--limit","10"))
const TOL=parse(Float64,option("--tol","1e-6"))
const CANARY="--canary" in ARGS
mkpath(OUT)

# Warm all solver paths outside recorded timings.
P=problem(40,60,0.5,5,0)
for kind in ("linear","bh"),method in ("PG","APG","SLOPE.jl")
    w=weight_sequence(kind,60);a=alpha_max(P.X,P.y,w)
    timed_fit(P.X,P.y,w,a.*[1.,0.3,0.05],method;tol=TOL,limit=2.0)
end
callfields=("n","p","rho","sparsity","weights","seed","round","mode","method","seconds","julia_bytes","valid","status","returned","expected","max_gap","iterations","nnz","clusters","coef_inf_vs_library","prediction_rel_vs_library","objective_rel_vs_library")
levelfields=("n","p","rho","sparsity","weights","seed","round","mode","method","level","fraction","alpha","valid","status","gap","primal","dual","feasibility","fixedpoint","nnz","clusters","iterations","f_calls","grad_calls","prox_calls","certificate_calls")
open(joinpath(OUT,"calls-$SHARD.csv"),"w") do calls
open(joinpath(OUT,"levels-$SHARD.csv"),"w") do levels
    write_csv(calls,callfields);write_csv(levels,levelfields)
    sizes=CANARY ? [(80,120)] : [(200,500),(1000,2000)]
    rhos=CANARY ? [0.9] : [0.,0.9]
    sparsities=CANARY ? [10] : [10,100]
    for (n,p) in sizes,rho in rhos,sparsity in sparsities,seed in SEEDS
        mod(seed-1,SHARDS)+1==SHARD || continue
        P=problem(n,p,rho,sparsity,seed)
        for kind in ("linear","bh")
            weights=weight_sequence(kind,p);amax=alpha_max(P.X,P.y,weights)
            modes=[("single_0.3",[0.3]),("single_0.05",[0.05]),("path",path_fractions())]
            for round in 1:ROUNDS
                order=collect(Iterators.product(1:3,("PG","APG","SLOPE.jl")))
                shuffle!(Xoshiro(5700+seed+100round+Int(100rho)+sparsity),order)
                results=Dict()
                for (mi,method) in order
                    mode,fractions=modes[mi]
                    fit=try timed_fit(P.X,P.y,weights,amax.*fractions,method;tol=TOL,limit=LIMIT) catch err
                        println(stderr,"FIT_ERROR n=$n p=$p rho=$rho s=$sparsity seed=$seed method=$method mode=$mode: ",sprint(showerror,err))
                        nothing
                    end
                    results[(mode,method)]=fit
                end
                for (mi,method) in order
                    mode,fractions=modes[mi];fit=results[(mode,method)];base=results[(mode,"SLOPE.jl")]
                    prefix=(n,p,rho,sparsity,kind,seed,round,mode,method)
                    if fit===nothing
                        write_csv(calls,(prefix...,NaN,-1,false,:exception,0,length(fractions),Inf,-1,-1,-1,NaN,NaN,NaN))
                    else
                        coef=pred=obj=NaN
                        if base!==nothing && length(base.betas)==length(fit.betas)
                            coef=maximum(norm(x-b,Inf) for (x,b) in zip(fit.betas,base.betas))
                            pred=maximum(norm(P.X*(x-b))/max(1,norm(P.y)) for (x,b) in zip(fit.betas,base.betas))
                            obj=maximum(abs(x.primal-b.primal)/max(1,abs(b.primal)) for (x,b) in zip(fit.metrics,base.metrics))
                        end
                        iterations=method=="SLOPE.jl" ? -1 : sum(i.iterations for i in fit.infos)
                        m=last(fit.metrics)
                        write_csv(calls,(prefix...,fit.seconds,fit.julia_bytes,fit.valid,fit.status,length(fit.betas),length(fractions),maximum(m.gap for m in fit.metrics),iterations,m.nnz,m.clusters,coef,pred,obj))
                    end
                    for (k,fraction) in enumerate(fractions)
                        if fit===nothing || k>length(fit.betas)
                            write_csv(levels,(prefix...,k,fraction,amax*fraction,false,:not_returned,Inf,NaN,NaN,Inf,Inf,-1,-1,-1,-1,-1,-1,-1))
                        else
                            m=fit.metrics[k];i=fit.infos[k]
                            write_csv(levels,(prefix...,k,fraction,amax*fraction,m.valid,i.status,m.gap,m.primal,m.dual,m.feasibility,m.fixedpoint,m.nnz,m.clusters,i.iterations,i.nf,i.ng,i.np,i.certificate_calls))
                        end
                    end
                end
            end
            println("COMPLETE n=$n p=$p rho=$rho s=$sparsity weights=$kind seed=$seed");flush(stdout)
        end
    end
end
end
println("SLOPE_SHARD_COMPLETE shard=$SHARD")
