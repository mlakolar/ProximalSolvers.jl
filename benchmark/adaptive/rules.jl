module AdaptivePrototype
using LinearAlgebra, ProximalBase
export adaptive!, next_gamma

# Latafat et al., arXiv:2301.04431v4, Algorithm 2.1 and Remark 2.4.
# Algebraically avoid c=||y||²/<s,y>, which can overflow near zero curvature.
function next_gamma(rule, gamma, previous, ss, sy, yy; first=false)
    growth = gamma * sqrt(1 + (first && rule==:mm ? Inf : gamma/previous))
    if rule==:adapgm
        D = ss==0 ? 0.0 : max((gamma^2*yy-gamma*sy)/ss,0.0)
        return min(growth, D==0 ? Inf : gamma/(2sqrt(D)))
    elseif rule==:mm
        L = ss==0 ? 0.0 : sqrt(yy/ss)
        return min(growth, L==0 ? Inf : inv(2L))
    end
    throw(ArgumentError("unknown adaptive rule"))
end

# No objective comparisons, trial retries, or line searches. Certificates are
# external diagnostics. gradient! may internally share a value/gradient oracle.
function adaptive!(out,f,g; rule=:adapgm,gamma0=1.0,maxiter=10000,
                   limit=60.0,check=(x->false),every=10,history=nothing)
    x, prev, grad, oldgrad, forward, s, y = (similar(out) for _ in 1:7)
    copyto!(prev,out)
    gradient!(oldgrad,f,prev)
    all(isfinite,oldgrad) || throw(ArgumentError("finite starting gradient required"))
    gamma=Float64(gamma0); previous=gamma
    ng=1; np=0; iterations=0; status=:maxiter; start=time()
    @. forward=prev-gamma*oldgrad
    prox!(x,g,forward,gamma); np+=1
    for k in 1:maxiter
        iterations=k
        gradient!(grad,f,x); ng+=1
        if !all(isfinite,x) || !all(isfinite,grad)
            status=f isa LogDetLoss ? :invalid_domain : :nonfinite_gradient; break
        end
        copyto!(out,x)
        history===nothing || push!(history,gamma)
        if (k==1 || k%every==0) && check(x)
            status=:target; break
        end
        if time()-start>limit
            status=:time_limit; break
        end
        @. s=x-prev
        @. y=grad-oldgrad
        gamma_next=next_gamma(rule,gamma,previous,dot(s,s),dot(s,y),dot(y,y);first=k==1)
        if !isfinite(gamma_next) || gamma_next<=0
            status=:invalid_step; break
        end
        previous,gamma=gamma,gamma_next
        copyto!(prev,x); copyto!(oldgrad,grad)
        @. forward=x-gamma*grad
        prox!(x,g,forward,gamma); np+=1
    end
    (;status,iterations,nf=0,ng,np,rejects=0,shrinks=0,resets=0,fallbacks=0,gamma)
end
end
