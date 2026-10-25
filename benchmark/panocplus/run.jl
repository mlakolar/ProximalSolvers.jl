# All numerical work, including package setup, runs within a Slurm allocation.
include("common.jl")
BLAS.set_num_threads(1)
const TRACK=option("--track","panocplus")
const OUT=abspath(option("--out",joinpath(@__DIR__,"results",TRACK*".csv")))
const SIZES=parse.(Int,split(option("--sizes","50,200,600"),','))
const AUXSIZES=parse.(Int,split(option("--aux-sizes","100,1000"),','))
const ROUNDS=parse(Int,option("--rounds","3"))
const LIMIT=parse(Float64,option("--limit","30"))
const TARGET=parse(Float64,option("--target","1e-6"))
const METHODS=TRACK=="panocplus" ? ["PANOCplus","APG","QUIC"] : ["adaPGM","MM","PG","APG"]
mkpath(dirname(OUT))
# Compilation warmup is outside timings.
for name in METHODS
    S=covariance(8);w=fill(0.12,8,8);w[diagind(w)].=0
    f,g=LogDetLoss(S),NormL1(1.0,w);x=Matrix(1.0I,8,8)
    run_method!(x,f,g,name;check=x->glasso_certificate(S,w,x)<=TARGET,limit=2.0)
end
const WARMED=Set{Tuple{DataType,String}}()
function record(io,f,g,x,name,cert;family,p,seed,round,mode,level,lambda,gamma0)
    # Cheap package certificate for stopping, independent glasso certificate
    # after the timer. Both first-order methods use the same cadence.
    ev = family=="quartic" ? nothing : ProximalSolvers._gapevaluator(f,g,x)
    check = ev===nothing ? (x->cert(x)<=TARGET) :
        (x->ProximalSolvers._relgap!(ev,f,g,x)<=TARGET)
    cert(x) # Compile the independent final validator outside solve timings.
    key=(typeof(f),name)
    if !(key in WARMED)
        run_method!(copy(x),f,g,name;check,gamma0,target=TARGET,limit=2.0,maxiter=2)
        push!(WARMED,key)
    end
    # Counts and allocations include setup and certificate checks. Raw total
    # bytes are retained; no claim that total/iterations is steady-state cost.
    GC.gc()
    result=nothing
    timed=@timed result=run_method!(x,f,g,name;check,gamma0,target=TARGET,limit=LIMIT)
    err=cert(x)
    valid=isfinite(err)&&err<=TARGET
    row=(TRACK,family,p,seed,round,mode,level,lambda,name,gamma0,timed.time,timed.bytes,
         result.iterations,err,valid,result.status,result.nf,result.ng,result.np,
         result.rejects,result.shrinks,result.resets,result.fallbacks,result.gamma)
    println(io,join(row,','));flush(io)
    println(join(row,','));flush(stdout)
    valid
end
open(OUT,"w") do io
    println(io,"track,family,p,seed,round,mode,level,lambda,method,gamma0,seconds,total_bytes,iterations,error,valid,status,f_calls,grad_calls,prox_calls,domain_rejections,step_shrinks,history_resets,pg_fallbacks,final_gamma")
    for p in SIZES, seed in (25,71), round in 1:ROUNDS, mode in ("cold","warm")
        S=covariance(p,seed)
        order=isodd(round) ? METHODS : reverse(METHODS)
        for name in order
            x=Matrix(1.0I,p,p)
            for (level,lambda) in enumerate((0.2,0.12,0.08))
                mode=="cold" && (x.=Matrix(1.0I,p,p))
                w=fill(lambda,p,p);w[diagind(w)].=0
                f,g=LogDetLoss(S),NormL1(1.0,w)
                cert=x->glasso_certificate(S,w,x)
                valid=record(io,f,g,x,name,cert;family="glasso",p,seed,round,mode,level,lambda,gamma0=1.0)
                !valid && mode=="warm" && break # never warm-start from a failed fit
            end
        end
    end
    if TRACK=="adaptive"
        # Both line-search-free rules on a globally defined composite lasso
        # and a convex quartic with locally but not globally Lipschitz gradient.
        for family in ("lasso","quartic"), p in AUXSIZES, seed in (25,71), round in 1:ROUNDS
            rng=Xoshiro(seed+p)
            if family=="lasso"
                A=randn(rng,2p,p)/sqrt(2p)
                b=A*randn(rng,p)+0.1randn(rng,2p)
                f=LeastSquaresLoss(b,A);lambda=0.1maximum(abs,A'*b)
                g=NormL1(lambda);cert=x->certificate(f,g,x)
            else
                f=QuarticLoss(randn(rng,p),exp.(range(0,log(100),length=p)))
                lambda=0.1;g=NormL1(lambda);cert=x->quartic_certificate(f,lambda,x)
            end
            for gamma0 in (0.01,1.0,10.0), name in (isodd(round) ? METHODS : reverse(METHODS))
                name in ("PG","APG") && gamma0!=1.0 && continue
                x=zeros(p)
                record(io,f,g,x,name,cert;family,p,seed,round,mode="cold",level=1,lambda,gamma0)
            end
        end
    end
end
