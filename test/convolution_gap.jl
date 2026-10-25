module ConvolutionGapTests
using Test, LinearAlgebra, Random, SparseArrays
using ProximalBase, ProximalSolvers
const PS = ProximalSolvers

@testset "convolution check conjugates" begin
  for T in (Float32, Float64), kernel in (:uniform, :epanechnikov), τ in (.1,.5,.9), h in (.05,.4)
    loss = ProximalBase.ConvolutionCheck(T(τ), T(h); kernel)
    y = T(.7)
    @test PS._hasconjugate(loss)
    for s in (-3.,-1.,-.8,-.2,0.,.3,.9,1.,3.)
      η = y - T(s)*T(h)
      u = ProximalBase.deriv(loss, η, y)
      c = PS._conjugate(loss, u, y)
      @test isapprox(loss(η,y)+c, u*η; atol=50eps(T), rtol=50eps(T))
      # Fenchel's inequality at independent dual points, not just gradients.
      for v in range(-T(τ), one(T)-T(τ); length=9)
        @test loss(η,y)+PS._conjugate(loss,v,y) >= v*η-50eps(T)
      end
    end
    @test isinf(PS._conjugate(loss, -T(τ)-T(.01), y))
    @test isinf(PS._conjugate(loss, one(T)-T(τ)+T(.01), y))
  end
end

@testset "Newton convolution paths certify raw scores" begin
  rng=Xoshiro(819); X=randn(rng,83,6); y=.4 .+ X*[1.,-.7,.3,0,0,0] .+ randn(rng,83)
  n,p=size(X); w=[1.,.7,1.3,1.,1.,.8]; ls=[.3,.1,.03]; target=1e-6
  for kernel in (:uniform,:epanechnikov), τ in (.2,.5,.8), int in (false,true), sp in (false,true)
    @testset "$kernel tau=$τ intercept=$int sparse=$sp" begin
    A=sp ? sparse(X) : X
    loss=ProximalBase.ConvolutionCheck(τ,.3;kernel)
    f=(1/n)*ProximalBase.GLMLoss(loss,y,A)
    x=SparseIterate(p); m=PS.cdmodel(f,x;intercept=int); aa=Float64[]
    save(k,λ,x,m)=(push!(aa,PS.intercept(m,x));false)
    method=ProxNewton(;tol=1e-10,maxiter=200,inner=CDSolver(;tol=1e-9,maxpasses=20000,rng=Xoshiro(19)))
    r=solve_path(m,NormL1(1.,w),ls,method;gaptol=target,devmax=1,callback=save)
    @test length(r.λ)==3
    @test all(r.converged)
    @test all(g -> isfinite(g) && g<=target,r.gap)
    for k in eachindex(ls)
      b=Vector(r.solutions[k]); η=A*b .+ aa[k]
      d=[ProximalBase.deriv(loss,η[i],y[i]) for i in 1:n]
      grad=A'd/n; g=NormL1(ls[k],w)
      P=sum(loss(η[i],y[i]) for i in 1:n)/n+g(b)
      rawgap=P+sum(PS._conjugate(loss,d[i],y[i]) for i in 1:n)/n
      @test abs(rawgap)<=target*(1+abs(P))
      @test maximum(abs.(grad).-ls[k].*w)<=target
      @test maximum(abs(b[j]-sign(b[j]-grad[j])*max(abs(b[j]-grad[j])-ls[k]*w[j],0)) for j in 1:p)<=target
      @test !int || abs(sum(d)/n)<=target
    end
    end
  end
end

@testset "unpenalized convolution scores and explicit legacy stopping" begin
  rng=Xoshiro(84); X=randn(rng,71,5); y=.3 .+ X*[.8,-.4,0,0,0] .+ randn(rng,71)
  n,p=size(X); target=1e-6
  for kernel in (:uniform,:epanechnikov), w in (ones(p),[0.,1,1,1,1])
    loss=ProximalBase.ConvolutionCheck(.5,.3;kernel)
    f=(1/n)*ProximalBase.GLMLoss(loss,y,X); x=SparseIterate(p);m=PS.cdmodel(f,x;intercept=true)
    aa=Float64[];save(k,λ,x,m)=(push!(aa,PS.intercept(m,x));false)
    method=ProxNewton(;tol=1e-10,maxiter=200,inner=CDSolver(;tol=1e-9,maxpasses=20000,rng=Xoshiro(19)))
    r=solve_path(m,NormL1(1.,w),[.1,0.],method;gaptol=target,devmax=1,callback=save)
    @test length(r.λ)==2
    for k in eachindex(r.λ)
      b=Vector(r.solutions[k]);η=X*b .+ aa[k];d=[ProximalBase.deriv(loss,η[i],y[i]) for i in 1:n]
      grad=X'd/n;P=sum(loss(η[i],y[i]) for i in 1:n)/n+r.λ[k]*dot(w,abs.(b))
      @test abs(sum(d)/n)<=target
      @test maximum(abs(b[j]-sign(b[j]-grad[j])*max(abs(b[j]-grad[j])-r.λ[k]*w[j],0)) for j in 1:p)<=target
      @test abs(P+sum(PS._conjugate(loss,d[i],y[i]) for i in 1:n)/n)<=target*(1+abs(P))
    end
    legacy=solve_path(f,NormL1(1.,w),[.1,.03],method;gaptol=0,devmax=1)
    @test all(isnan,legacy.gap)
    @test all(isfinite,legacy.values)
    stopped=solve_path(f,NormL1(1.,w),[.03],ProxNewton(;maxiter=1,inner=CDSolver(;maxpasses=1));gaptol=1e-10)
    @test !only(stopped.converged)
  end
end
end
