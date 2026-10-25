module PANOCPrototype
using LinearAlgebra, ProximalBase
export panocplus!, LBFGSMemory, direction!, update!

# Independent implementation of De Marchi--Themelis (2022), Algorithm 2.
# Dense real arrays only. The SPD-domain safeguard is an experimental extension.
mutable struct LBFGSMemory{T}
    S::Matrix{T}
    Y::Matrix{T}
    rho::Vector{T}
    a::Vector{T}
    head::Int
    used::Int
end
LBFGSMemory(x, m=5) = LBFGSMemory(zeros(eltype(x), length(x), m),
    zeros(eltype(x), length(x), m), zeros(eltype(x), m), zeros(eltype(x), m), 0, 0)
reset!(h) = (h.head = 0; h.used = 0; nothing)
function update!(h, s, y)
    sy, yy = dot(s, y), dot(y, y)
    sy > sqrt(eps(eltype(s))) * norm(s) * norm(y) && yy > 0 || return false
    j = mod1(h.head + 1, size(h.S, 2))
    copyto!(view(h.S, :, j), vec(s)); copyto!(view(h.Y, :, j), vec(y))
    h.rho[j] = inv(sy)
    h.head = j; h.used = min(h.used + 1, size(h.S, 2))
    true
end
function direction!(d, h, r; bound=1e4)
    copyto!(d, r)
    m = size(h.S, 2)
    for k in 0:h.used-1
        j = mod1(h.head-k, m)
        s, y = view(h.S, :, j), view(h.Y, :, j)
        h.a[j] = h.rho[j] * dot(s, vec(d))
        for i in eachindex(d)
            d[i] -= h.a[j]*y[i]
        end
    end
    if h.used > 0
        y = view(h.Y, :, h.head)
        d .*= inv(h.rho[h.head] * dot(y,y))
    end
    for k in h.used-1:-1:0
        j = mod1(h.head-k, m)
        s, y = view(h.S, :, j), view(h.Y, :, j)
        b = h.rho[j] * dot(y, vec(d))
        for i in eachindex(d)
            d[i] += (h.a[j]-b)*s[i]
        end
    end
    d .*= -1
    nr, nd = norm(r), norm(d)
    nd > bound * nr && (d .*= bound * nr / nd)
    d
end

# Counters exclude the external stopping certificate. Each call allocates its
# workspace once; the iteration arrays and circular L-BFGS history are reused.
function panocplus!(out, f, g; gamma0=1.0, memory=5, alpha=0.95, beta=0.5,
                    maxiter=10000, limit=60.0, check=(x->false), every=10,
                    residual_tol=0.0, history=nothing, direction_override=nothing)
    T = eltype(out)
    x, z, r, grad = copy(out), similar(out), similar(out), similar(out)
    xc, zc, rc, gc, forward = (similar(out) for _ in 1:5)
    s, y, d, gz = (similar(out) for _ in 1:4)
    h = LBFGSMemory(out, memory)
    gamma = T(gamma0)
    nf=0; ng=0; np=0; rejects=0; shrinks=0; resets=0; fallbacks=0
    start=time(); iterations=0; status=:maxiter
    fx = value_and_gradient!(grad, f, x); nf+=1; ng+=1
    isfinite(fx) && all(isfinite, grad) || throw(ArgumentError("finite initial loss and gradient required"))
    phi=T(Inf)
    # Initialization is Algorithm 2, step 2.4, with no envelope decrease test.
    for b in 0:80
        @. forward = x - gamma * grad
        gval = value_and_prox!(z, g, forward, gamma); np+=1
        @. r = x - z
        fz=f(z); nf+=1
        model=fx-dot(grad,r)+alpha*dot(r,r)/(2gamma)
        if isfinite(fz) && isfinite(gval) && fz <= model + 10eps(T)*(1+abs(fx))
            phi=fx+gval-dot(grad,r)+dot(r,r)/(2gamma)
            break
        end
        !isfinite(fz) && (rejects+=1)
        gamma/=2; shrinks+=1
    end
    isfinite(phi) || return (;status=:initial_linesearch_failed, iterations, nf,ng,np,rejects,shrinks,resets,fallbacks,gamma)
    copyto!(out,z)
    history === nothing || push!(history, (;phi,gamma,model_ok=true))
    for k in 1:maxiter
        if time()-start > limit
            status=:time_limit; break
        end
        if (k==1 || (k-1)%every==0) && check(z)
            status=:target; break
        end
        if residual_tol>0
            value_and_gradient!(gz,f,z); nf+=1; ng+=1
            @. s = r/gamma - grad + gz
            if norm(s,Inf)<=residual_tol
                status=:residual; break
            end
        end
        iterations=k
        oldgamma=gamma
        threshold=phi-beta*(1-alpha)*dot(r,r)/(2oldgamma)
        threshold += 10eps(T)*(1+abs(phi))
        direction!(d,h,r)
        direction_override === nothing || direction_override(d,x,r)
        tau=one(T); bt=0; accepted=false; changed=false
        # A finite cap reports failure; it never accepts a failed merit test.
        for trial in 1:400
            @. xc = (1-tau)*z + tau*(x+d)
            fxc=value_and_gradient!(gc,f,xc); nf+=1; ng+=1
            if !isfinite(fxc) || !all(isfinite,gc)
                rejects+=1
                tau = bt>=30 ? zero(T) : tau/2; bt+=1
                continue
            end
            @. forward = xc - gamma*gc
            gval=value_and_prox!(zc,g,forward,gamma); np+=1
            @. rc = xc-zc
            fzc=f(zc); nf+=1
            model=fxc-dot(gc,rc)+alpha*dot(rc,rc)/(2gamma)
            if !isfinite(fzc) || !isfinite(gval) || fzc>model+10eps(T)*(1+abs(fxc))
                !isfinite(fzc) && (rejects+=1)
                gamma/=2; shrinks+=1
                gamma > eps(T)^2 || break
                reset!(h); resets+=1; changed=true
                direction!(d,h,r)
                direction_override === nothing || direction_override(d,x,r)
                tau=one(T); bt=0
                continue
            end
            phic=fxc+gval-dot(gc,rc)+dot(rc,rc)/(2gamma)
            if isfinite(phic) && phic<=threshold
                @. s=xc-x
                @. y=rc-r
                changed || update!(h,s,y)
                copyto!(x,xc); copyto!(z,zc); copyto!(r,rc); copyto!(grad,gc)
                phi=phic; fx=fxc; accepted=true
                tau==0 && (fallbacks+=1)
                history === nothing || push!(history,(;phi,gamma,model_ok=true))
                break
            end
            tau = bt>=30 ? zero(T) : tau/2; bt+=1
        end
        if !accepted
            status=:linesearch_failed; break
        end
        copyto!(out,z)
    end
    status==:maxiter && check(out) && (status=:target)
    (;status,iterations,nf,ng,np,rejects,shrinks,resets,fallbacks,gamma)
end
end
