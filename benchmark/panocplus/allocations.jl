include("common.jl")
BLAS.set_num_threads(1)
neverstop(x)=false
out=option("--out","allocations.csv")
open(out,"w") do io
    println(io,"method,p,k1,k2,actual1,actual2,bytes1,bytes2,incremental_bytes_per_iteration,status1,status2")
    for p in (50,200), name in ("PANOCplus","APG","PG","adaPGM","MM")
        # Globally defined convex least squares avoids domain failures. Keep
        # measured iteration counts: early termination invalidates the slope.
        rng=Xoshiro(25+p);A=randn(rng,2p,p)/sqrt(2p);b=randn(rng,2p)
        f,g=LeastSquaresLoss(b,A),NormL1(0.01)
        r1=r2=nothing;x=zeros(p)
        for k in (20,120)
            fill!(x,0);run_method!(x,f,g,name;check=neverstop,maxiter=k,limit=30.0,gamma0=0.01)
        end
        fill!(x,0);b1=@allocated r1=run_method!(x,f,g,name;check=neverstop,maxiter=20,limit=30.0,gamma0=0.01)
        fill!(x,0);b2=@allocated r2=run_method!(x,f,g,name;check=neverstop,maxiter=120,limit=30.0,gamma0=0.01)
        slope=r1.iterations==20&&r2.iterations==120 ? (b2-b1)/100 : NaN
        println(io,join((name,p,20,120,r1.iterations,r2.iterations,b1,b2,slope,r1.status,r2.status),','));flush(io)
    end
end
