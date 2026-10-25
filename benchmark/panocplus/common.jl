using LinearAlgebra, Random, Printf, ProximalBase, ProximalSolvers
include("prototype.jl")
include("../adaptive/rules.jl")
using .PANOCPrototype, .AdaptivePrototype

# Globally finite, convex, locally Lipschitz gradient; no global gradient bound.
struct QuarticLoss <: ProximalBase.AbstractFunction
    a::Vector{Float64}
    w::Vector{Float64}
end
ProximalBase.issmooth(::Type{QuarticLoss})=true
ProximalBase.isconvex(::Type{QuarticLoss})=true
(f::QuarticLoss)(x)=sum(f.w[i]*(x[i]-f.a[i])^4/4+(x[i]-f.a[i])^2/2 for i in eachindex(x))
function ProximalBase.gradient!(grad,f::QuarticLoss,x)
    @. grad=f.w*(x-f.a)^3+(x-f.a)
    grad
end
ProximalBase.value_and_gradient!(grad,f::QuarticLoss,x)=(gradient!(grad,f,x);f(x))

# Gap validation independent of the package's graphical-lasso gap evaluator.
# Dual point U=clip(X^-1-S); no clipping of a materially negative duality gap.
function glasso_certificate(S,weights,X)
    asym=norm(X-X')/max(norm(X),1)
    asym<=1e-10 || return Inf
    C=cholesky(Symmetric(X);check=false)
    isposdef(C) || return Inf
    P=dot(S,X)-2sum(log,diag(C.U))+sum(weights.*abs.(X))
    W=Matrix(inv(C))
    U=clamp.(W-S,-weights,weights)
    Dchol=cholesky(Symmetric(S+U);check=false)
    isposdef(Dchol) || return Inf
    D=2sum(log,diag(Dchol.U))+size(X,1)
    P-D >= -1e-10*max(abs(P),1) || return Inf
    max(P-D,0)/max(abs(P),eps())
end
function certificate(f,g,x)
    d=duality_gap(f,g,x)
    d.gap>=-1e-9*max(abs(d.primal),1) || return Inf
    max(d.gap,0)/max(abs(d.primal),eps())
end
function quartic_certificate(f,lambda,x)
    grad=similar(x); gradient!(grad,f,x)
    maximum(x[i]==0 ? max(abs(grad[i])-lambda,0) : abs(grad[i]+lambda*sign(x[i])) for i in eachindex(x))
end
function covariance(p,seed=25)
    omega=Matrix(1.4I,p,p)
    for j in 1:p-1
        omega[j,j+1]=omega[j+1,j]=0.3
    end
    Z=randn(Xoshiro(seed+p),2p,p)/cholesky(Symmetric(omega)).U'
    Matrix(Symmetric(Z'*Z/(2p)))
end
function baseline!(x,f,g,method;check,every=10,maxiter=10000,limit=60.0)
    opt=ProximalOptions(;maxiter,time_limit=limit)
    st=ProximalSolvers.initial_state(method,opt,f,g,x)
    start=time(); status=:maxiter; iterations=0
    for k in 1:maxiter
        iterations=k
        if k==1 && check(st.x)
            status=:target; break
        end
        ProximalSolvers.update_state!(f,g,st,method)
        # Same certificate cadence as prototypes; always validate the final point.
        if k%every==0 && check(st.x)
            status=:target; break
        end
        if time()-start>limit
            status=:time_limit; break
        end
    end
    copyto!(x,st.x)
    (;status,iterations,nf=st.f_calls,ng=st.grad_calls,np=st.prox_calls,
      rejects=-1,shrinks=st.backtrack_steps,resets=-1,fallbacks=-1,gamma=inv(st.L))
end
function run_method!(x,f,g,name;check,gamma0=1.0,target=1e-6,limit=30.0,maxiter=10000)
    name=="PANOCplus" && return panocplus!(x,f,g;check,gamma0,limit,maxiter)
    name=="adaPGM" && return adaptive!(x,f,g;check,gamma0,rule=:adapgm,limit,maxiter)
    name=="MM" && return adaptive!(x,f,g;check,gamma0,rule=:mm,limit,maxiter)
    name=="APG" && return baseline!(x,f,g,AccProxGradDescent();check,limit,maxiter)
    name=="PG" && return baseline!(x,f,g,ProximalGradientDescent();check,limit,maxiter)
    if name=="QUIC"
        opt=ProximalOptions(;time_limit=limit,maxiter)
        res=solve!(x,f,g,ProxNewton(;tol=target,maxiter=200,inner=CDSolver(;rng=Xoshiro(25))))
        return (;status=check(x) ? :target : :not_converged,iterations=res.passes,
                nf=-1,ng=-1,np=-1,rejects=-1,shrinks=-1,resets=-1,fallbacks=-1,gamma=NaN)
    end
    error("unknown method $name")
end
option(name,default)=(i=findfirst(==(name),ARGS);i===nothing ? default : ARGS[i+1])
