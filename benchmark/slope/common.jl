using LinearAlgebra, Random, ProximalSolvers
import ProximalBase, SLOPE
const PB = ProximalBase
BLAS.set_num_threads(1)

# J_lambda^D(z) = max_k sum_{j<=k} |z|_(j) / sum_{j<=k} lambda_j.
# The benchmark uses strictly positive weights. This is also alpha_max when
# z=X'y/n: zero is optimal iff all cumulative dual constraints hold.
function dualnorm!(scratch, z, weights)
    @. scratch = abs(z)
    sort!(scratch; rev=true, alg=QuickSort)
    numerator=0.0; denominator=0.0; result=0.0
    for k in eachindex(scratch)
        numerator+=scratch[k]; denominator+=weights[k]
        denominator>0 || throw(ArgumentError("positive weight prefixes required"))
        result=max(result,numerator/denominator)
    end
    result
end
alpha_max(X,y,weights)=dualnorm!(zeros(size(X,2)),X'*y/length(y),weights)

mutable struct Certificate{M,V}
    X::M
    y::V
    weights::V
    alpha::Float64
    predictor::V
    theta::V
    gradient::V
    sorted::V
    primal::Float64
    dual::Float64
    gap::Float64
    feasibility::Float64
    calls::Int
end
function Certificate(X,y,weights,alpha)
    Certificate(X,y,weights,Float64(alpha),zeros(length(y)),zeros(length(y)),
                zeros(size(X,2)),zeros(size(X,2)),Inf,-Inf,Inf,Inf,0)
end
function (c::Certificate)(x; tol=1e-6)
    c.calls+=1
    n=length(c.y)
    mul!(c.predictor,c.X,x)
    @. c.theta=(c.y-c.predictor)/n
    mul!(c.gradient,transpose(c.X),c.theta)
    dn=dualnorm!(c.sorted,c.gradient,c.weights)
    # Contract slightly into the dual ball to avoid rounding outside it.
    scale=dn==0 ? 1.0 : min(1.0,c.alpha/(dn*(1+16eps())))
    c.feasibility=c.alpha>0 ? scale*dn/c.alpha : Inf
    @. c.sorted=abs(x)
    sort!(c.sorted;rev=true,alg=QuickSort)
    rr=dot(c.theta,c.theta)
    c.primal=n*rr/2+c.alpha*dot(c.weights,c.sorted)
    c.dual=scale*dot(c.y,c.theta)-n*scale^2*rr/2
    gap=c.primal-c.dual
    c.gap=gap < -100eps()*max(1,abs(c.primal)) ? Inf : max(gap,0)/max(1,abs(c.primal))
    isfinite(c.primal)&&isfinite(c.dual)&&isfinite(c.gap)&&c.feasibility<=1+1e-12&&c.gap<=tol
end

function problem(n,p,rho,sparsity,seed)
    rng=Xoshiro(57000+seed+10p+sparsity)
    X=randn(rng,n,p)
    # AR(1) covariance, unit marginal variance; no sample standardization.
    for j in 2:p
        @views X[:,j].=rho.*X[:,j-1].+sqrt(1-rho^2).*X[:,j]
    end
    beta=zeros(p); support=randperm(rng,p)[1:sparsity]
    beta[support].=2randn(rng,sparsity)
    y=X*beta+randn(rng,n)
    (;X,y)
end
function weight_sequence(kind,p)
    kind=="linear" && return collect(range(2.0,0.5;length=p))
    kind=="bh" && return SLOPE.regweights(p;q=0.1,type=:bh)
    error("unknown weights")
end
path_fractions()=collect(exp.(range(0,log(0.05);length=12)))

function package_fit(X,y,weights,alphas,method;tol=1e-6,limit=10.0,maxiter=20000)
    x=zeros(size(X,2));f=PB.Scaled(PB.LeastSquaresLoss(y,X),inv(length(y)))
    solver=method=="APG" ? AccProxGradDescent() : ProximalGradientDescent()
    options=ProximalOptions(;maxiter,time_limit=limit)
    betas=Vector{Vector{Float64}}(); infos=NamedTuple[]
    start=time()
    for alpha in alphas
        g=PB.SLOPE(alpha.*weights);cert=Certificate(X,y,weights,alpha)
        st=ProximalSolvers.initial_state(solver,options,f,g,x)
        status=:maxiter;iterations=0
        if cert(st.x;tol)
            status=:target
        else
            for k in 1:maxiter
                ProximalSolvers.update_state!(f,g,st,solver);iterations=k
                if k%10==0 && cert(st.x;tol)
                    status=:target;break
                end
                if time()-start>=limit
                    status=:time_limit;break
                end
                if !all(isfinite,st.x)
                    status=:nonfinite;break
                end
            end
        end
        copyto!(x,st.x);push!(betas,copy(x))
        push!(infos,(;status,iterations,nf=st.f_calls,ng=st.grad_calls,np=st.prox_calls,certificate_calls=cert.calls))
        status==:target || break # a failed point never seeds the next level
    end
    (;betas,infos)
end

function library_fit(X,y,weights,alphas;tol=1e-9,maxiter=20000)
    fit=SLOPE.slope(X,y;α=alphas,λ=weights,fit_intercept=false,loss=:quadratic,
                    centering=:none,scaling=:none,tol,max_it=maxiter,
                    max_clusters=size(X,2)+1,dev_change_tol=0.0,dev_ratio_tol=1.0,
                    cd_type=:permuted,random_seed=57)
    # The public SlopeFit wrapper exposes no iterations, oracle counts or
    # convergence status. Do not manufacture them from path length.
    fit
end

function final_metrics(X,y,weights,alpha,x)
    c=Certificate(X,y,weights,alpha);valid=c(x)
    g=PB.SLOPE(alpha.*weights)
    z=similar(x);PB.prox!(z,g,x+c.gradient,1.0)
    fixedpoint=norm(x-z,Inf)/max(1,norm(x,Inf))
    (;valid,gap=c.gap,primal=c.primal,dual=c.dual,feasibility=c.feasibility,
      fixedpoint,nnz=count(!iszero,x),clusters=length(unique(abs.(filter(!iszero,x)))))
end

function timed_fit(X,y,weights,alphas,method;tol=1e-6,limit=10.0,library_tol=1e-9)
    GC.gc(); result=nothing
    t=@timed result=method=="SLOPE.jl" ? library_fit(X,y,weights,alphas;tol=library_tol) : package_fit(X,y,weights,alphas,method;tol,limit)
    betas=method=="SLOPE.jl" ? [Vector(b[:,1]) for b in result.coefficients] : result.betas
    infos=method=="SLOPE.jl" ? [(;status=:library_returned,iterations=-1,nf=-1,ng=-1,np=-1,certificate_calls=-1) for _ in betas] : result.infos
    if method=="SLOPE.jl"
        length(result.α)==length(alphas) && all(isapprox.(result.α,alphas;rtol=1e-12)) || error("library returned a truncated/different alpha grid")
    end
    metrics=[final_metrics(X,y,weights,alphas[k],x) for (k,x) in enumerate(betas)]
    valid=length(betas)==length(alphas)&&all(m.valid for m in metrics)
    (;seconds=t.time,julia_bytes=t.bytes,betas,infos,metrics,valid,
      status=valid ? :target : (isempty(infos) ? :empty : last(infos).status))
end

function write_csv(io,row)
    println(io,join(row,','));flush(io)
end
option(name,default)=(i=findfirst(==(name),ARGS);i===nothing ? default : ARGS[i+1])
