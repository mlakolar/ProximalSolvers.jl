include("<RUN>/agents/A/lib.jl")
include("<RUN>/scripts/orch_d2_lib.jl")
using Random
setprecision(BigFloat,512)
function checks()
  println("Julia ",VERSION)
  # An upper-bound comparison can accept a true objective increase.
  X=ones(1,2);y=[1.0];A=2.0^40;x0=[A,1-A];b=zeros(2);lambda=(1-1e-5)/(2A-1)
  p0=Pup(X,y,lambda,x0);pb=Pup(X,y,lambda,b)
  println("upper-bound comparison: P0=",Float64(Pbig(X,y,lambda,x0))," Pb=",Float64(Pbig(X,y,lambda,b))," P0up=",p0," Pbup=",pb," accepts=",pb<p0)
  # Equality in the coordinatewise-minimum condition is a tie, resolved to zero.
  b,r,_,_=ps_solve(ones(1,1),[1.0],1.0,[1.0];order=:cyclic,momentum=false)
  println("equality fixed-point check: beta=",b," certified=",r.converged)
  # Empty support-certificate set: G is unbounded along an exact null direction.
  X2=[1.0 1.0];b2=[2.0,-1.0];d=[-1.0,1.0];lambda2=.1
  println("empty-support-witness: Xd=",X2*d," s'd=",dot(sign.(b2),d)," G(kd)=",[.5norm(X2*(k*d))^2+lambda2*dot(sign.(b2),k*d) for k in [1.,10.,100.]])
  # Independent checks, including subnormal norm squares and t > 1.
  rng=Xoshiro(1776);bad=Dict(:feas=>0,:gap=>0,:dual=>0,:primal=>0,:ratio=>0);countvalid=0;tlarge=0
  for iter in 1:1500
    n=rand(rng,1:12);p=rand(rng,1:15);sc=ldexp(1.0,rand(rng,-530:400))
    X=randn(rng,n,p);y=randn(rng,n);beta=randn(rng,p);theta=sc*randn(rng,n);lambda=.5
    v=vcert(X,y,lambda,lambda,beta,theta)
    isfinite(v.gap)&&isfinite(v.t) || continue
    countvalid+=1;tlarge+=v.t>1
    xb,yb,bb,tb=big.(X),big.(y),big.(beta),big.(theta);t=big(v.t)
    D=t*dot(tb,yb);P=norm(yb-xb*bb)+big(lambda)*sum(abs,bb)
    bad[:feas]+=(t*norm(tb)>1 || t*maximum(abs,xb'*tb)>big(lambda))
    bad[:gap]+=(big(v.gap)<P-D)
    bad[:dual]+=(isfinite(v.Dlo)&&big(v.Dlo)>D)
    bad[:primal]+=(big(Pup(X,y,lambda,beta))<P)
    bad[:ratio]+=(v.Dlo>0&&big(v.ratio)<(P-D)/D)
  end
  println("independent wide-range validator checks: n=",countvalid," t>1=",tlarge," violations=",bad)
end
checks()
