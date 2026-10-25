include("common.jl")
BLAS.set_num_threads(1)
open(option("--out","domain-probes.csv"),"w") do io
    println(io,"method,p,gamma0,status,valid,error,iterations,domain_rejections,step_shrinks")
    for gamma0 in (1.0,10.0,100.0),name in ("PANOCplus","adaPGM","MM")
        p=20;S=Matrix(10.0I,p,p);weights=fill(0.1,p,p);weights[diagind(weights)].=0
        f,g=LogDetLoss(S),NormL1(1.0,weights);x=Matrix(1.0I,p,p)
        check=x->glasso_certificate(S,weights,x)<=1e-6
        r=run_method!(x,f,g,name;check,gamma0,limit=10.0)
        err=glasso_certificate(S,weights,x)
        row=(name,p,gamma0,r.status,isfinite(err)&&err<=1e-6,err,r.iterations,r.rejects,r.shrinks)
        println(io,join(row,','));flush(io)
        println(join(row,','))
    end
end
