include("common.jl")
BLAS.set_num_threads(1)
const OUT=abspath(option("--out","broad.csv"))
const SIZES=parse.(Int,split(option("--sizes","100,500"),','))
const KAPPAS=parse.(Float64,split(option("--kappas","1,100,10000"),','))
const SEEDS=parse.(Int,split(option("--seeds","1,2,3,4,5,6,7,8,9,10"),','))
const ROUNDS=parse(Int,option("--rounds","3"))
const SHARD=parse(Int,option("--shard","1"))
const SHARDS=parse(Int,option("--shards","1"))
const LIMIT=parse(Float64,option("--limit","1"))
const TOL=parse(Float64,option("--tol","1e-6"))
const MAXITER=parse(Int,option("--maxiter","50000"))
const FAMILIES=split(option("--families","ls,logistic,huber,poisson,quartic"),',')
const FRACS=parse.(Float64,split(option("--fractions","0.05,0.005"),','))
mkpath(dirname(OUT))
# Compile each loss/method/certificate path outside every recorded timing.
for family in FAMILIES
    U,V=design_factors(24,12,0);A=conditioned_design(U,V,10.0)
    P=problem(family,A,0,10.0);lambda=0.05P.scale
    for config in configurations(P)
        timed_fit(P,lambda,config;limit=2.0,maxiter=2,tol=TOL)
    end
end
open(OUT,"w") do io
    println(io,join(BROAD_HEADER,','));flush(io)
    for p in SIZES, (seed_index,seed) in enumerate(SEEDS)
        mod(seed_index-1,SHARDS)+1==SHARD || continue
        U,V=design_factors(2p,p,seed)
        for kappa in KAPPAS
            A=conditioned_design(U,V,kappa)
            for family in FAMILIES
                P=problem(family,A,seed,kappa)
                for frac in FRACS, round in 1:ROUNDS
                    configs=configurations(P)
                    # Randomized complete blocks; all initializations and baselines
                    # use identical data and x=0, with no best-step selection.
                    shuffle!(Xoshiro(seed+100round+1000Int(kappa)+10p),configs)
                    for config in configs
                        lambda=frac*P.scale
                        fit=timed_fit(P,lambda,config;limit=LIMIT,maxiter=MAXITER,tol=TOL)
                        r,m=fit.result,fit.metrics
                        row=(family,p,kappa,seed,frac,lambda,round,fit.name,fit.init,fit.gamma0,P.L0,
                             fit.seconds,fit.bytes,r.iterations,r.status,fit.valid,m.kkt,m.gap,m.primal,
                             r.nf,r.ng,r.np,fit.certificate_calls,r.gamma)
                        println(io,join(row,','));flush(io)
                    end
                end
                println("COMPLETE family=$family p=$p kappa=$kappa seed=$seed");flush(stdout)
            end
        end
    end
end
println("BROAD_SHARD_COMPLETE shard=$SHARD")
