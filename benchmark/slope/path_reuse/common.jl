include("../common.jl")

const REUSE_METHODS=("reset","carry_L","workspace_reset","workspace_L","full_state","SLOPE.jl")

# Function barrier keeps the numerical loop specialized for the concrete state,
# loss, penalty and certificate, independently of the outer handoff selection.
function drive_level!(st,f,g,solver,cert,tol,start,limit,maxiter)
    cert(st.x;tol) && return :target,0
    for k in 1:maxiter
        ProximalSolvers.update_state!(f,g,st,solver)
        k%10==0 && cert(st.x;tol) && return :target,k
        time()-start>=limit && return :time_limit,k
        all(isfinite,st.x) || return :nonfinite,k
    end
    :maxiter,maxiter
end

# Same production APG updates; only the handoff between penalty levels changes.
# Loss data and x are unchanged at a handoff, so cached f(x) and X*x remain valid.
# Penalty values must be refreshed before an update can test objective descent.
function handoff!(st,g,mode)
    st.g_x=g(st.x)
    if mode=="full_state"
        st.g_x_previous=g(st.x_previous)
    else
        copyto!(st.x_previous,st.x)
        st.model===nothing || copyto!(st.z_previous,st.z_x)
        st.f_x_previous=st.g_x_previous=st.f_y=NaN
        st.k=0
    end
    mode=="workspace_reset" && (st.L=1.0)
    st.maxResidual=-Inf
    st.restarts=st.backtrack_steps=st.f_calls=st.grad_calls=st.prox_calls=0
    st
end

function reuse_path(X,y,weights,alphas,mode;tol=1e-6,limit=10.,maxiter=20000,observer=nothing)
    mode in REUSE_METHODS[1:5] || error("unknown APG handoff")
    x=zeros(size(X,2));f=PB.Scaled(PB.LeastSquaresLoss(y,X),inv(length(y)))
    solver=AccProxGradDescent();options=ProximalOptions(;maxiter,time_limit=limit)
    reuse=mode in ("workspace_reset","workspace_L","full_state")
    penalty=reuse ? PB.SLOPE(copy(weights)) : nothing
    certificate=reuse ? Certificate(X,y,weights,first(alphas)) : nothing
    st=nothing;previous_L=1.0
    betas=Vector{Vector{Float64}}();infos=NamedTuple[];start=time()
    for (level,alpha) in enumerate(alphas)
        if reuse
            @. penalty.λ=alpha*weights
            g=penalty;cert=certificate;cert.alpha=alpha;cert.calls=0
        else
            g=PB.SLOPE(alpha.*weights);cert=Certificate(X,y,weights,alpha)
        end
        if !reuse || st===nothing
            st=ProximalSolvers.initial_state(solver,options,f,g,x)
            mode=="carry_L" && (st.L=previous_L)
        else
            handoff!(st,g,mode)
        end
        initial_L,initial_k=st.L,st.k
        observer===nothing || observer(level,st,g,f)
        status,iterations=drive_level!(st,f,g,solver,cert,tol,start,limit,maxiter)
        copyto!(x,st.x);push!(betas,copy(x));previous_L=st.L
        push!(infos,(;status,iterations,nf=st.f_calls,ng=st.grad_calls,np=st.prox_calls,
                      certificate_calls=cert.calls,initial_L,final_L=st.L,initial_k,final_k=st.k,
                      backtracks=st.backtrack_steps,restarts=st.restarts))
        status==:target || break
    end
    (;betas,infos)
end

function timed_reuse(X,y,weights,alphas,mode;limit=10.,tol=1e-6)
    if mode=="SLOPE.jl"
        fit=timed_fit(X,y,weights,alphas,"SLOPE.jl";tol,limit,library_tol=1e-6)
        return (;fit...,mode)
    end
    GC.gc();result=nothing
    t=@timed result=reuse_path(X,y,weights,alphas,mode;tol,limit)
    metrics=[final_metrics(X,y,weights,alphas[k],x;tol) for (k,x) in enumerate(result.betas)]
    valid=length(result.betas)==length(alphas)&&all(m.valid for m in metrics)
    (;mode,seconds=t.time,julia_bytes=t.bytes,result.betas,result.infos,metrics,valid,
      status=valid ? :target : last(result.infos).status)
end
