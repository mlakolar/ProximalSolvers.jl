# Run in this directory's independent environment. No oracle/benchmark packages
# become dependencies of ProximalSolvers. CSV output includes failures/limits.
using LinearAlgebra, SparseArrays, Random, Printf, Test
using ProximalBase, ProximalSolvers, ProximalAlgorithms, ProximalCore
import JuMP, HiGHS
include(joinpath(@__DIR__,"..","proxalg","adapter.jl"))
const PS = ProximalSolvers
const PA = ProximalAlgorithms
BLAS.set_num_threads(1)
const OUT = get(ENV,"PD_OUT",joinpath(@__DIR__,"results"))
mkpath(OUT)
const ORACLE_ONLY = get(ENV,"PD_ORACLE_ONLY","false") == "true"
const MAXTIME = parse(Float64,get(ENV,"PD_MAXTIME","15"))

# Identical gap checks and caps for both packages. The adapter keeps its
# upstream unbuffered conjugate so allocation comparisons use the existing API.
function pa_gap(alg,f,g,h,D,steps,tol;maxit=1_000_000,kwargs...)
  k=Ref(0); t0=time()
  stop(iter,state)=begin
    k[]+=1
    if k[]%25 == 0
      x,y=PA.default_solution(iter,state)
      cert=duality_gap(f,g,h,D,x,y)
      cert.gap/max(abs(cert.primal),floatmin(Float64)) <= tol && return true
    end
    time()-t0 > MAXTIME
  end
  alg(maxit=maxit,stop=stop)(x0=zeros(size(D,2)),y0=zeros(size(D,1)),
                               g=PAProx(g),h=PAProx(h),L=D,gamma=steps;kwargs...)
end

include(joinpath(@__DIR__,"..","..","test","oracles","primal_dual.jl"))
ORACLE_ONLY && exit()

open(joinpath(OUT,"comparison.csv"),"w") do io
  println(io,"problem,n,p,method,seconds,iterations,objective,relative_error,relative_gap,converged,primal_error,dual_error,bytes_per_iteration")
  for (n,p) in ((500,100),(2000,200))
    q=.5; X,b,λ=quantile_data(n,p,q)
    xlp,ylp,Fref=quantile_lp(X,b,q,λ)
    f,g,h=ZeroFunction(),NormL1(λ),Scaled(Translate(CheckLoss(1-q),b),1/n)
    nd=opnorm(X)
    τq,σq,_,_=PS._pd_startsteps(CondatVu(norm_d=nd),f,X,Float64)
    # Warm compilation before all timed runs.
    solve!(zeros(p),f,g,h,X,CondatVu(norm_d=nd),ProximalOptions(maxiter=2,gaptol=1e-6))
    run_pa_iters(PA.ChambollePock,2;x0=zeros(p),y0=zeros(n),g=PAProx(g),h=PAProx(h),L=X,gamma=(τq,σq))
    pa_gap(PA.ChambollePock,f,g,h,X,(τq,σq),1e-6;maxit=25)
    for (name,adapt,restart) in (("native fixed",false,false),("native adaptive",true,true))
      method=CondatVu(norm_d=nd,abstol=1e-8,reltol=1e-7,adaptive=adapt,restart=restart)
      options=ProximalOptions(maxiter=1_000_000,gaptol=1e-6,gapevery=25,time_limit=MAXTIME)
      solve!(zeros(p),f,g,h,X,method,ProximalOptions(maxiter=25,gaptol=1e-6,gapevery=25,time_limit=MAXTIME))
      tm=@elapsed res=solve!(zeros(p),f,g,h,X,method,options)
      st=PS._pd_state(zeros(p),zeros(n),f,X); hc=Conjugate(h)
      step()=PS._pd_step!(st,f,g,hc,X,.99/nd,.99/nd,1e-8,1e-7)
      step();step(); bytes=@allocated step()
      println(io,join(("quantile",n,p,name,tm,res.iterations,res.minimum,abs(res.minimum-Fref)/abs(Fref),res.gap,res.converged,norm(res.minimizer-xlp,Inf),norm(res.y-ylp,Inf),bytes),',')); flush(io)
    end
    tm=@elapsed sol=pa_gap(PA.ChambollePock,f,g,h,X,(τq,σq),1e-6;maxit=1_000_000)
    xx,yy=sol[1]; F=g(xx)+h(X*xx)
    rgap=duality_gap(f,g,h,X,xx,yy).gap/max(abs(F),floatmin(Float64))
    b1=@allocated run_pa_iters(PA.ChambollePock,100;x0=zeros(p),y0=zeros(n),g=PAProx(g),h=PAProx(h),L=X,gamma=(τq,σq))
    b2=@allocated run_pa_iters(PA.ChambollePock,200;x0=zeros(p),y0=zeros(n),g=PAProx(g),h=PAProx(h),L=X,gamma=(τq,σq))
    println(io,join(("quantile",n,p,"PA ChambollePock",tm,sol[2],F,abs(F-Fref)/abs(Fref),rgap,rgap<=1e-6,norm(xx-xlp,Inf),norm(yy-ylp,Inf),(b2-b1)/100),','));flush(io)
    tm=@elapsed quantile_lp(X,b,q,λ)
    println(io,join(("quantile",n,p,"HiGHS LP",tm,0,Fref,0,0,true,0,0,0),','));flush(io)
  end
  for n in (1000,10000)
    rng=MersenneTwister(23+n); b=repeat(randn(rng,10);inner=n÷10)+.5randn(rng,n)
    D=spdiagm(n-1,n,0=>-ones(n-1),1=>ones(n-1))
    f,g,h=SqrNormL2(1.,b),ZeroFunction(),NormL1(1.)
    truth=prox(TotalVariation1D(1.),b); Fref=f(truth)+h(D*truth)
    τv,σv,_,_=PS._pd_startsteps(CondatVu(),f,D,Float64)
    solve!(zeros(n),f,g,h,D,CondatVu(),ProximalOptions(maxiter=2,gaptol=1e-8))
    run_pa_iters(PA.VuCondat,2;x0=zeros(n),y0=zeros(n-1),f=PASmooth(f),beta_f=1.,h=PAProx(h),L=D,gamma=(τv,σv))
    pa_gap(PA.VuCondat,f,g,h,D,(τv,σv),1e-8;maxit=25,f=PASmooth(f),beta_f=1.)
    for (name,adapt,restart) in (("native fixed",false,false),("native adaptive",true,true))
      method=CondatVu(abstol=1e-8,reltol=1e-7,adaptive=adapt,restart=restart)
      options=ProximalOptions(maxiter=1_000_000,gaptol=1e-8,gapevery=25,time_limit=MAXTIME)
      solve!(zeros(n),f,g,h,D,method,ProximalOptions(maxiter=25,gaptol=1e-8,gapevery=25,time_limit=MAXTIME))
      tm=@elapsed res=solve!(zeros(n),f,g,h,D,method,options)
      st=PS._pd_state(zeros(n),zeros(n-1),f,D);hc=Conjugate(h)
      step()=PS._pd_step!(st,f,g,hc,D,.4,.4,1e-8,1e-7);step();step();bytes=@allocated step()
      println(io,join(("TV",n,n,name,tm,res.iterations,res.minimum,abs(res.minimum-Fref)/abs(Fref),res.gap,res.converged,norm(res.minimizer-truth,Inf),NaN,bytes),','));flush(io)
    end
    tm=@elapsed sol=pa_gap(PA.VuCondat,f,g,h,D,(τv,σv),1e-8;maxit=1_000_000,f=PASmooth(f),beta_f=1.)
    xx,yy=sol[1];F=f(xx)+h(D*xx)
    rgap=duality_gap(f,g,h,D,xx,yy).gap/max(abs(F),floatmin(Float64))
    b1=@allocated run_pa_iters(PA.VuCondat,100;x0=zeros(n),y0=zeros(n-1),f=PASmooth(f),beta_f=1.,h=PAProx(h),L=D,gamma=(τv,σv))
    b2=@allocated run_pa_iters(PA.VuCondat,200;x0=zeros(n),y0=zeros(n-1),f=PASmooth(f),beta_f=1.,h=PAProx(h),L=D,gamma=(τv,σv))
    println(io,join(("TV",n,n,"PA VuCondat",tm,sol[2],F,abs(F-Fref)/abs(Fref),rgap,rgap<=1e-8,norm(xx-truth,Inf),NaN,(b2-b1)/100),','));flush(io)
    tm=@elapsed direct=prox(TotalVariation1D(1.),b)
    println(io,join(("TV",n,n,"direct TV prox",tm,0,Fref,0,0,true,norm(direct-truth,Inf),NaN,0),','));flush(io)
  end
end
println("PRIMAL_DUAL_BENCHMARK_COMPLETE")
