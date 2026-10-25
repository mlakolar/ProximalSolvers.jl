include("../../panocplus/common.jl")

# A coupled, everywhere-finite nonlinear loss using the same image-caching
# interface as production GLM losses. This avoids handicapping PG/APG with
# an extra matrix multiplication merely because this scalar loss is new.
struct CoupledQuarticScalar <: ProximalBase.ScalarLoss
    nu::Float64
end
(q::CoupledQuarticScalar)(eta,y)=(r=eta-y; r*r/2+q.nu*r^4/4)
ProximalBase.deriv(q::CoupledQuarticScalar,eta,y)=(r=eta-y; r+q.nu*r^3)
ProximalBase.deriv2(q::CoupledQuarticScalar,eta,y)=1+3q.nu*(eta-y)^2
ProximalBase.curvature(::CoupledQuarticScalar)=Inf
ProximalBase.value_and_deriv(q::CoupledQuarticScalar,eta,y)=(r=eta-y;(r*r/2+q.nu*r^4/4,r+q.nu*r^3))

function design_factors(n,p,seed)
    rng=Xoshiro(81000+seed+100p)
    U=Matrix(qr(randn(rng,n,p)).Q)[:,1:p]
    V=Matrix(qr(randn(rng,p,p)).Q)
    U,V
end
function conditioned_design(U,V,kappa)
    p=size(V,1)
    s=exp.(range(0,-log(kappa)/2,length=p))
    (U .* transpose(s))*V'
end
function poisson_draw(rng,rate)
    threshold=exp(-rate);product=1.0;k=0
    while product>threshold
        product*=rand(rng);k+=1
    end
    k-1
end
function problem(family,A,seed,kappa)
    n,p=size(A);rng=Xoshiro(92000+seed+100p)
    truth=zeros(p);support=randperm(rng,p)[1:max(3,p÷10)]
    truth[support].=2randn(rng,length(support))
    X=family=="logistic" ? 2A : A
    eta=X*truth
    if family=="ls"
        y=eta+0.1randn(rng,n);f=LeastSquaresLoss(y,X)
    elseif family=="logistic"
        y=Float64.(rand(rng,n).<1.0./(1.0.+exp.(-eta)))
        f=LogisticLoss(y,X)
    elseif family=="huber"
        y=eta+0.1randn(rng,n)
        for i in randperm(rng,n)[1:max(1,n÷20)]
            y[i]+=10randn(rng)
        end
        f=HuberLoss(y,X,1.0)
    elseif family=="poisson"
        y=Float64[poisson_draw(rng,exp(z)) for z in eta]
        f=PoissonLoss(y,X)
    elseif family=="quartic"
        y=eta+0.3randn(rng,n)
        for i in randperm(rng,n)[1:max(1,n÷20)]
            y[i]+=3randn(rng)
        end
        f=GLMLoss(CoupledQuarticScalar(1.0),y,X)
    else
        error("unknown loss")
    end
    grad=zeros(p);gradient!(grad,f,zeros(p))
    # Bound on the Hessian at x=0. For LS/Huber/logistic the global bound is
    # one by construction; for Poisson it is one at the zero predictor only.
    L0=family=="quartic" ? maximum(1 .+3 .*y.^2) : 1.0
    (;f,X,y,scale=norm(grad,Inf),L0,mu=family=="quartic" ? inv(kappa) : 0.0)
end

mutable struct BroadCertificate{F,G,E}
    f::F
    g::G
    ev::E
    grad::Vector{Float64}
    residual::Vector{Float64}
    scale::Float64
    mu::Float64
    tol::Float64
    kkt::Float64
    gap::Float64
    primal::Float64
    calls::Int
end
function BroadCertificate(P,lambda,tol)
    g=NormL1(lambda);x=zeros(size(P.X,2))
    ev=ProximalSolvers._gapevaluator(P.f,g,x)
    BroadCertificate(P.f,g,ev,similar(x),similar(x),max(P.scale,lambda,eps()),P.mu,tol,Inf,Inf,Inf,0)
end
function residual!(r,grad,x,lambda)
    @inbounds for i in eachindex(x)
        r[i]=x[i]==0 ? sign(grad[i])*max(abs(grad[i])-lambda,0) : grad[i]+lambda*sign(x[i])
    end
    r
end
function (c::BroadCertificate)(x)
    c.calls+=1
    fx=value_and_gradient!(c.grad,c.f,x)
    if !isfinite(fx)||!all(isfinite,c.grad)||!all(isfinite,x)
        c.kkt=c.gap=Inf;return false
    end
    residual!(c.residual,c.grad,x,c.g.λ0)
    c.kkt=norm(c.residual,Inf)/c.scale
    c.primal=fx+c.g(x)
    c.gap=Inf
    if c.kkt<=c.tol
        if c.ev===nothing
            # Strong convexity gives F(x)-F* <= dist(0,subdiff F(x))²/(2mu).
            c.gap=dot(c.residual,c.residual)/(2c.mu*max(1,abs(c.primal)))
        else
            pd=ProximalSolvers._evalgap!(c.ev,c.f,c.g,x)
            if pd!==nothing
                primal,dual=pd;gap=primal-dual
                gap>=-100eps()*max(1,abs(primal)) && (c.gap=max(gap,0)/max(1,abs(primal)))
            end
        end
    end
    c.kkt<=c.tol&&isfinite(c.gap)&&c.gap<=c.tol
end

# Direct forward/transpose products and scalar derivatives at the returned
# point, outside the timer. No solver state or cached stopping residual reused.
function final_metrics(P,lambda,x)
    eta=P.X*x
    if P.f isa LeastSquaresLoss
        d=eta-P.y;fx=dot(d,d)/2
    else
        d=similar(eta);fx=0.0
        for i in eachindex(eta)
            v,dv=ProximalBase.value_and_deriv(P.f.loss,eta[i],P.y[i])
            fx+=v;d[i]=dv
        end
    end
    grad=P.X'*d;r=similar(x);residual!(r,grad,x,lambda)
    primal=fx+lambda*sum(abs,x)
    kkt=norm(r,Inf)/max(P.scale,lambda,eps())
    if P.mu>0
        gap=dot(r,r)/(2P.mu*max(1,abs(primal)))
    else
        dg=duality_gap(P.f,NormL1(lambda),x)
        gap=dg.gap < -100eps()*max(1,abs(dg.primal)) ? Inf : max(dg.gap,0)/max(1,abs(dg.primal))
    end
    (;kkt,gap,primal,finite=all(isfinite,x)&&all(isfinite,grad)&&isfinite(primal))
end

const BROAD_HEADER=("family","p","kappa","seed","lambda_fraction","lambda","round","method","initialization","gamma0","L0","seconds","total_bytes","iterations","status","valid","kkt","gap","primal","f_calls","grad_calls","prox_calls","certificate_calls","final_gamma")
function configurations(P)
    configs=[("adaPGM",name,factor/P.L0) for (name,factor) in (("tiny",0.01),("reference",1.0),("large",100.0),("extreme",1e4))]
    P.L0==1.0 || push!(configs,("adaPGM","unit",1.0))
    push!(configs,("PG","default",1.0),("APG","default",1.0))
    configs
end

function timed_fit(P,lambda,config;limit=1.0,maxiter=50000,tol=1e-6)
    name,init,gamma0=config
    x=zeros(size(P.X,2));g=NormL1(lambda);cert=BroadCertificate(P,lambda,tol)
    GC.gc()
    result=nothing
    t=@timed result=run_method!(x,P.f,g,name;check=cert,gamma0,limit,maxiter)
    metrics=try final_metrics(P,lambda,x) catch; (;kkt=Inf,gap=Inf,primal=NaN,finite=false) end
    valid=metrics.finite&&metrics.kkt<=tol&&metrics.gap<=tol
    (;name,init,gamma0,seconds=t.time,bytes=t.bytes,result,metrics,valid,certificate_calls=cert.calls)
end
