module SLOPEEngineTests
using Test, Random, LinearAlgebra, SparseArrays, ProximalBase, ProximalSolvers

@testset "Screened SLOPE APG numerical engine" begin
  X=2Matrix{Float64}(I,4,4);y=[3.,2.,1.,0.];lambda=[.4,.3,.2,.1]
  f=(1/4)*LeastSquaresLoss(y,X);g=SLOPE(lambda);method=SLOPEAPG(;maxiter=500,tol=1e-9)
  x=zeros(4);X0=copy(X);y0=copy(y);w0=copy(lambda)
  r=solve!(x,f,g,method;candidates=Int[])
  @test r.minimizer === x
  @test r.converged && r.kkt_repairs>=1
  @test x≈[1.1,.7,.3,0.] atol=1e-7
  @test r.gradient≈X'*(X*x-y)/4
  @test X==X0 && y==y0 && lambda==w0 && g.λ==w0
  @test r.kkt_residual<=method.tol*max(1,norm(X'y/4,Inf))
  limited=solve!(zeros(4),f,g,SLOPEAPG(;maxiter=2,tol=1e-9);candidates=[4])
  @test limited.iterations<=2
  @test !limited.converged
  warm=solve!(fill(.1,4),f,g,method;candidates=Int[])
  @test warm.converged
  @test warm.minimizer≈x atol=1e-7
  unscaled=solve!(zeros(4),LeastSquaresLoss(y,X),SLOPE(4lambda),method)
  @test unscaled.converged
  @test unscaled.minimizer≈x atol=1e-7
  amax=lambda_max(f,g,zeros(4))
  @test amax≈maximum(cumsum(sort(abs.(X'y/4);rev=true))./cumsum(lambda))
  @test lambda_max(f,SLOPE(zeros(4)),zeros(4))==Inf
  @test lambda_max((1/4)*LeastSquaresLoss(zeros(4),X),SLOPE(zeros(4)),zeros(4))==0
  factors=[amax,.5amax,.2amax]
  path=solve_path(f,g,factors,method)
  @test all(path.converged)
  @test norm(path.solutions[1],Inf)<1e-7
  @test path.lambda==factors
  @test path.solutions[1] !== path.solutions[2]
  saved=copy(path.solutions[2]);path.solutions[1][1]=99
  @test path.solutions[2]==saved
  for seed in 1:4
    rng=Xoshiro(seed);A=randn(rng,60,90);A[:,2:10] .+= 0.8 .* A[:,1]
    b=2A[:,1]-A[:,20]+randn(rng,60)
    weights=collect(range(.2,.03;length=90));loss=(1/60)*LeastSquaresLoss(b,A)
    penalty=SLOPE(weights);top=lambda_max(loss,penalty,zeros(90))
    grid=top.*exp.(range(0,log(.15);length=12))
    screened=solve_path(loss,penalty,grid,SLOPEAPG(;tol=2e-7))
    full=solve_path(loss,penalty,grid,SLOPEAPG(;tol=2e-7);screening=false)
    sparsepath=solve_path((1/60)*LeastSquaresLoss(b,sparse(A)),penalty,grid,SLOPEAPG(;tol=2e-7))
    @test all(screened.converged) && all(full.converged) && all(sparsepath.converged)
    @test all(norm(A*(a-z),Inf)<2e-4 for (a,z) in zip(screened.solutions,full.solutions))
    @test all(norm(a-z,Inf)<2e-4 for (a,z) in zip(screened.solutions,sparsepath.solutions))
    @test all(<=(90),screened.working_sizes)
  end
  f32=(1f0/4)*LeastSquaresLoss(Float32.(y),Float32.(X))
  @test solve!(zeros(Float32,4),f32,SLOPE(Float32.(lambda)),SLOPEAPG(;tol=1e-4)).converged
  failed=solve_path(f,g,[1.,.5],SLOPEAPG(;maxiter=2,tol=1e-14))
  @test length(failed.solutions)==2 && !all(failed.converged)
  @test_throws ArgumentError SLOPEAPG(;maxiter=1)
  @test_throws ArgumentError SLOPEAPG(;tol=NaN)
  @test_throws ArgumentError solve_path(f,g,[.1,1.],method)
  @test_throws ArgumentError solve_path(f,g,[NaN],method)
  @test_throws ArgumentError solve_path(f,g,Float64[],method)
  @test_throws ArgumentError solve!(zeros(4),f,g,method;candidates=[0])
  @test_throws ArgumentError solve!(zeros(4),f,g,method;candidates=[1.5])
  @test_throws DimensionMismatch solve!(zeros(3),f,g,method)
  badX=copy(X);badX[1]=NaN
  @test_throws ArgumentError solve!(zeros(4),(1/4)*LeastSquaresLoss(y,badX),g,method)
  @test_throws ArgumentError solve!(zeros(4),(-1/4)*LeastSquaresLoss(y,X),g,method)
  @test_throws ArgumentError solve!(zeros(4),QuadraticFunction(X,y),g,method)
  @test_throws ArgumentError solve!(zeros(4),LeastSquaresLoss(hcat(y,y),X),g,method)
end
end
