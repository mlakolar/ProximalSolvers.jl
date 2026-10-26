module SLOPEHybridTests
using Test, Random, LinearAlgebra, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

struct ProductDesign{T,M<:AbstractMatrix{T}} <: AbstractMatrix{T}
  data::M
  failures::Base.RefValue{Int}
end
Base.size(X::ProductDesign) = size(X.data)
Base.getindex(::ProductDesign,::Int,::Int) = error("implicit scalar indexing")
Base.getindex(X::ProductDesign,::Colon,E::AbstractVector) = ProductDesign(X.data[:,E],X.failures)
LinearAlgebra.mul!(out::AbstractVector,X::ProductDesign,b::AbstractVector) = mul!(out,X.data,b)
LinearAlgebra.mul!(out::AbstractVector,X::Transpose{<:Any,<:ProductDesign},b::AbstractVector) = mul!(out,transpose(parent(X).data),b)
Base.:*(X::ProductDesign,b::AbstractVector) = X.data*b
Base.:*(X::Transpose{<:Any,<:ProductDesign},b::AbstractVector) = transpose(parent(X).data)*b
function PS._slope_cluster_column!(column,X::ProductDesign,w,g)
  if X.failures[] > 0
    X.failures[] -= 1
    fill!(column,NaN)
  else
    invoke(PS._slope_cluster_column!,Tuple{Any,Any,Any,Any},column,X,w,g)
  end
end

@testset "Reusable SLOPE cluster state" begin
  rng = Xoshiro(9595)
  for p in (2,5,12), trial in 1:30
    x = Float64.(rand(rng,-4:4,p))
    lambda = sort!(rand(rng,p);rev=true)
    w = PS._SLOPEClusters(Float64,3,p)
    PS._slope_clusters!(w,x,lambda)
    @test sum(w.sizes[g] for g in w.order[1:w.groups];init=0) == count(!iszero,x)
    for pos in 1:w.groups
      g = w.order[pos]; m = w.sizes[g]
      others = sort!([abs(x[j]) for j in eachindex(x) if abs(x[j]) != w.values[g]];rev=true)
      curvature = .1+rand(rng); gamma = 10randn(rng)
      value = PS._slope_cluster_value(w,pos,gamma,curvature)
      candidates = [0.;others;-others]
      for rank in 0:p-m
        z = max(0.,(abs(gamma)-sum(lambda[rank+1:rank+m]))/curvature)
        append!(candidates,[z,-z])
      end
      objective(z) = curvature*z*z/2-gamma*z+dot(lambda,sort!([fill(abs(z),m);others];rev=true))
      expected = candidates[argmin(objective.(candidates))]
      @test value ≈ expected atol=1e-10 rtol=1e-10
    end
  end
  # Opposite signed identical columns form an exact zero-curvature cluster.
  for A in ([1. 1.;2. 2.],sparse([1. 1.;2. 2.]))
    x=[1.,-1.]; y=[1.,2.];w=PS._SLOPEClusters(Float64,2,2)
    PS._slope_clusters!(w,x,[.2,.1]);w.residual .= y-A*x
    @test PS._slope_cluster_sweep!(x,A,1.,w)
    @test x == zeros(2) && w.groups == 0
    @test w.residual == y
  end
  A = randn(rng,80,120); y = randn(rng,80); x = randn(rng,120)
  weights = collect(range(.5,.1;length=120)); w = PS._SLOPEClusters(Float64,80,120)
  PS._slope_clusters!(w,x,weights); w.residual .= y-A*x
  @test PS._slope_cluster_sweep!(x,A,1/80,w)
  bytes = @allocated PS._slope_cluster_sweep!(x,A,1/80,w)
  @test bytes <= 8192
  for storage in ("dense","sparse"), seed in 1:5
    rng=Xoshiro(95950+seed)
    A=randn(rng,40,30);storage=="sparse" && (A=sparse(A.*(rand(rng,40,30).<.2)))
    y=randn(rng,40);x=Float64.(rand(rng,-3:3,30));weights=collect(range(.8,.01;length=30))
    w=PS._SLOPEClusters(Float64,40,30);PS._slope_clusters!(w,x,weights)
    w.residual .= y-A*x
    objective()=sum(abs2,y-A*x)/80+SLOPE(weights)(x)
    for _ in 1:10
      before=objective()
      @test PS._slope_cluster_sweep!(x,A,1/40,w)
      @test objective() <= before+1e-10
      @test norm(w.residual-(y-A*x),Inf) < 1e-10
      @test sum(w.sizes[g] for g in w.order[1:w.groups];init=0)==count(!iszero,x)
      @test issorted([w.values[g] for g in w.order[1:w.groups]];rev=true)
    end
  end
end

@testset "Opt-in SLOPE hybrid and slow-progress fallback" begin
  @test_throws ArgumentError SLOPEHybrid(;maxiter=1)
  @test_throws ArgumentError SLOPEHybrid(;cd_sweeps=0)
  @test_throws ArgumentError SLOPEHybrid(;stall_cycles=0)
  @test_throws ArgumentError SLOPEHybrid(;tol=Inf)
  A=2Matrix{Float64}(I,4,4); y=[3.,2.,1.,0.]; weights=[.4,.3,.2,.1]
  f=.25*LeastSquaresLoss(y,A); g=SLOPE(weights)
  method=SLOPEHybrid(;tol=1e-9)
  r=solve!(zeros(4),f,g,method;candidates=Int[])
  @test r.converged && r.kkt_repairs >= 1
  @test r.minimizer ≈ [1.1,.7,.3,0.] atol=1e-8
  split=solve!(ones(4),f,g,method)
  @test split.converged
  @test split.minimizer ≈ r.minimizer atol=1e-8
  f32=.25f0*LeastSquaresLoss(Float32.(y),Float32.(A))
  @test solve!(zeros(Float32,4),f32,SLOPE(Float32.(weights)),SLOPEHybrid(;tol=1e-5)).converged
  rng=Xoshiro(9596); A=randn(rng,60,90)
  for j in 2:90
    A[:,j] .= .99A[:,j-1]+sqrt(1-.99^2).*A[:,j]
  end
  A[:,2] .= A[:,1]
  y=2A[:,1]-A[:,3]+.1randn(rng,60)
  weights=collect(range(.6,.1;length=90));g=SLOPE(weights)
  f=(1/60)*LeastSquaresLoss(y,A)
  top=lambda_max(f,g,zeros(90));grid=top.*[1.,.5,.1,.05]
  oracle=solve_path(f,g,grid,SLOPEAPG(;tol=1e-8))
  @test all(oracle.converged)
  for design in (A,sparse(A),ProductDesign(A,Ref(0)))
    loss=(1/60)*LeastSquaresLoss(y,design)
    result=solve_path(loss,g,grid,SLOPEHybrid(;tol=1e-8))
    @test all(result.converged)
    @test all(norm(A*(a-b),Inf)<2e-4 for (a,b) in zip(result.solutions,oracle.solutions))
    limited=solve_path(loss,g,grid,SLOPEHybrid(;maxiter=2,tol=1e-14))
    @test all(<=(2),limited.iterations)
    @test !all(limited.converged)
    workspace=PS._slope_workspace(design,y,SLOPEHybrid())
    x=zeros(90)
    # An impossible test-only target prevents an exactly solved one-dimensional
    # cluster from terminating before fallback. APG may stop early and return
    # control to the full working-set check; its reserved budget is a ceiling.
    used=PS._slope_inner!(x,loss,SLOPE(.1top.*weights),SLOPEHybrid(;maxiter=30),30,-1.,workspace)
    @test 1 <= used <= 30
    @test workspace.clusters.fallbacks == 1
    @test workspace.clusters.pg_steps >= 2
    @test PS._slope_hybrid_trial_budget(SLOPEHybrid(),30) == 15
    @test PS._slope_hybrid_trial_budget(SLOPEHybrid(),10000) == 110
    @test workspace.clusters.sweeps > 0
  end
  faulty=ProductDesign(A,Ref(1))
  workspace=PS._slope_workspace(faulty,y,SLOPEHybrid())
  x=fill(.1,90);loss=(1/60)*LeastSquaresLoss(y,faulty)
  PS._slope_inner!(x,loss,SLOPE(.1top.*weights),SLOPEHybrid(;tol=1e-8),10000,1e-8,workspace)
  @test faulty.failures[] == 0
  @test workspace.clusters.fallbacks > 0
  residual,_,_=PS._slope_kkt(faulty,y,x,.1top.*weights,1/60,workspace)
  @test residual < 1e-8
end
end
