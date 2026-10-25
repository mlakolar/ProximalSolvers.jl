include("../path_reuse/common.jl")
const CONTROL_METHODS=("APG_workspace_L","SLOPE.jl","native_pgd_none","native_pgd_strong",
                       "native_fista_none","native_fista_strong","native_hybrid_none","native_hybrid_strong")
const CONTROL_LIBRARY=get(ENV,"SLOPE_CONTROL_LIBRARY",joinpath(@__DIR__,"libslope_control.so"))

function native_path(X::Matrix{Float64},y::Vector{Float64},weights::Vector{Float64},
                     alphas::Vector{Float64},method;tol=1e-6,limit=10.,maxiter=20000)
    solver=occursin("pgd",method) ? 0 : occursin("fista",method) ? 1 : 2
    screening=endswith(method,"strong") ? 1 : 0
    betas=fill(NaN,size(X,2),length(alphas));passes=fill(Cint(-1),length(alphas))
    returned=Ref{Cint}(0);message=zeros(UInt8,4096)
    code=ccall((:slope_control,CONTROL_LIBRARY),Cint,
        (Ptr{Cdouble},Ptr{Cdouble},Ptr{Cdouble},Ptr{Cdouble},Cint,Cint,Cint,Cint,Cint,
         Cdouble,Cint,Cdouble,Ptr{Cdouble},Ptr{Cint},Ref{Cint},Ptr{UInt8},Cint),
        X,y,weights,alphas,size(X,1),size(X,2),length(alphas),solver,screening,tol,maxiter,
        limit,betas,passes,returned,message,length(message))
    code==0 || throw(ErrorException(String(message[1:findfirst(iszero,message)-1])))
    0<=returned[]<=length(alphas) || error("invalid native path length")
    (;betas=[copy(betas[:,k]) for k in 1:returned[]],passes=Int.(passes[1:returned[]]))
end

function timed_control(X,y,weights,alphas,method;tol=1e-6,limit=10.)
    if method in ("APG_workspace_L","SLOPE.jl")
        fit=timed_reuse(X,y,weights,alphas,method=="SLOPE.jl" ? method : "workspace_L";tol,limit)
        return (;fit...,passes=fill(-1,length(fit.betas)))
    end
    GC.gc()
    t=@timed result=native_path(X,y,weights,alphas,method;tol,limit)
    metrics=[final_metrics(X,y,weights,alphas[k],x;tol) for (k,x) in enumerate(result.betas)]
    valid=length(result.betas)==length(alphas)&&all(m.valid for m in metrics)
    (;seconds=t.time,julia_bytes=t.bytes,result.betas,result.passes,metrics,valid,
      status=valid ? :target : :uncertified_native,infos=NamedTuple[])
end
