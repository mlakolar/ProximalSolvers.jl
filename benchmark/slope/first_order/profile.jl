# Benchmark-only phase timers. Mirrors the unchanged production APG kernels;
# every measured path must match an uninstrumented workspace_L replay.
const PS=ProximalSolvers
Base.@kwdef mutable struct PhaseTimes
    gradient_ns::Int=0
    prox_ns::Int=0
    trial_loss_ns::Int=0
    update_ns::Int=0
    certificate_ns::Int=0
    setup_ns::Int=0
    total_ns::Int=0
end

function profile_prox_step!(f,g,st::PS.AccProxGradDescentState{T},method,times) where T
    begin_ns=time_ns()
    st.f_y=PS._value_and_gradient!(st.grad_f_y,f,st.y,st.model,st.z_y,st.dz)
    times.gradient_ns+=Int(time_ns()-begin_ns)
    st.f_calls+=1;st.grad_calls+=1
    if !isfinite(st.f_y)
        st.f_x=T(Inf);return st
    end
    while true
        PS._step!(st.xhat,st.y,st.grad_f_y,st.L)
        begin_ns=time_ns()
        st.g_x=PB.value_and_prox!(st.x,g,st.xhat,one(T)/st.L)
        times.prox_ns+=Int(time_ns()-begin_ns)
        PS._drop!(st.x)
        begin_ns=time_ns()
        st.f_x=PS._value!(f,st.x,st.model,st.z_x)
        times.trial_loss_ns+=Int(time_ns()-begin_ns)
        st.prox_calls+=1;st.f_calls+=1
        PS._sub!(st.xhat,st.x,st.y)
        upper=st.f_y+PS._dot(st.grad_f_y,st.xhat)+st.L/2*PS._sumabs2(st.xhat)
        st.backtrack_steps+=1
        st.f_x<=upper+10eps(T)*max(abs(st.f_y),one(T)) && break
        st.L/=method.β
    end
    st
end

function profile_update!(f,g,st::PS.AccProxGradDescentState{T},method,times) where T
    begin_ns=time_ns()
    omega=T(st.k/(st.k+3));st.L*=T(method.α)
    PS._extrapolate_point!(st.y,st.x,st.x_previous,omega)
    PS._drop!(st.y);PS._extrapolate_image!(st,st.model,omega)
    PS._copyto!(st.x_previous,st.x)
    st.f_x_previous=st.f_x;st.g_x_previous=st.g_x
    PS._shift_image!(st,st.model)
    while true
        profile_prox_step!(f,g,st,method,times)
        if omega>0 && st.f_x+st.g_x>st.f_x_previous+st.g_x_previous
            omega=zero(T);st.k=0;st.restarts+=1
            PS._copyto!(st.y,st.x_previous);PS._restart_image!(st,st.model)
        else
            break
        end
    end
    st.k+=1;PS._sub!(st.deltaX,st.x,st.x_previous)
    times.update_ns+=Int(time_ns()-begin_ns)
    st
end

function profile_certificate!(cert,x,times,tol)
    begin_ns=time_ns();valid=cert(x;tol)
    times.certificate_ns+=Int(time_ns()-begin_ns)
    valid
end

function profile_level!(st,f,g,solver,cert,times,tol,start,limit,maxiter)
    profile_certificate!(cert,st.x,times,tol) && return :target,0
    for k in 1:maxiter
        profile_update!(f,g,st,solver,times)
        k%10==0 && profile_certificate!(cert,st.x,times,tol) && return :target,k
        time()-start>=limit && return :time_limit,k
        all(isfinite,st.x) || return :nonfinite,k
    end
    :maxiter,maxiter
end

function profile_path(X,y,weights,alphas;tol=1e-6,limit=10.,maxiter=20000)
    times=PhaseTimes();total_start=time_ns();setup_start=time_ns()
    x=zeros(size(X,2));f=PB.Scaled(PB.LeastSquaresLoss(y,X),inv(length(y)))
    solver=AccProxGradDescent();options=ProximalOptions(;maxiter,time_limit=limit)
    g=PB.SLOPE(copy(weights));cert=Certificate(X,y,weights,first(alphas))
    betas=Vector{Vector{Float64}}();infos=NamedTuple[];st=nothing;start=time()
    times.setup_ns+=Int(time_ns()-setup_start)
    for alpha in alphas
        setup_start=time_ns()
        @. g.λ=alpha*weights
        cert.alpha=alpha;cert.calls=0
        st=st===nothing ? PS.initial_state(solver,options,f,g,x) : handoff!(st,g,"workspace_L")
        initial_L,initial_k=st.L,st.k
        times.setup_ns+=Int(time_ns()-setup_start)
        status,iterations=profile_level!(st,f,g,solver,cert,times,tol,start,limit,maxiter)
        copyto!(x,st.x);push!(betas,copy(x))
        push!(infos,(;status,iterations,nf=st.f_calls,ng=st.grad_calls,np=st.prox_calls,
            certificate_calls=cert.calls,initial_L,final_L=st.L,initial_k,final_k=st.k,
            backtracks=st.backtrack_steps,restarts=st.restarts))
        status==:target || break
    end
    times.total_ns=Int(time_ns()-total_start)
    (;betas,infos,times)
end

function timed_profile(X,y,weights,alphas;tol=1e-6,limit=10.)
    GC.gc();t=@timed result=profile_path(X,y,weights,alphas;tol,limit)
    metrics=[final_metrics(X,y,weights,alphas[k],x;tol) for (k,x) in enumerate(result.betas)]
    (;seconds=t.time,julia_bytes=t.bytes,result...,metrics,
      valid=length(result.betas)==length(alphas)&&all(m.valid for m in metrics))
end

function check_profile_match(plain,profiled)
    @assert plain.valid && profiled.valid
    @assert plain.infos==profiled.infos
    @assert length(plain.betas)==length(profiled.betas)
    @assert all(a==b for (a,b) in zip(plain.betas,profiled.betas))
    t=profiled.times
    @assert 0<=t.gradient_ns+t.prox_ns+t.trial_loss_ns<=t.update_ns
    @assert t.update_ns+t.certificate_ns+t.setup_ns<=t.total_ns
    true
end
