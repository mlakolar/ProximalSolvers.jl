using Test, Random
include("prototype.jl")

@testset "SLOPE scalar cluster minimization" begin
  prefix = [0.;cumsum([.9,.6,.3])]
  @test cluster_value(3.5,1.,[2.,1.],1,prefix) ≈ 2.6
  @test cluster_value(-3.5,1.,[2.,1.],1,prefix) ≈ -2.6
  @test cluster_value(2.7,1.,[2.,1.],1,prefix) == 2.
  @test cluster_value(.2,1.,[2.,1.],1,prefix) == 0.
  rng = Xoshiro(95)
  for p in (2,5,12), m in 1:p, trial in 1:20
    others = sort!(Float64.(rand(rng,0:4,p-m));rev=true)
    weights = sort!(rand(rng,p);rev=true)
    curvature = .1+3rand(rng)
    gamma = 20randn(rng)
    prefix = [0.;cumsum(weights)]
    z = cluster_value(gamma,curvature,others,m,prefix)
    # Enumerate every kink and every stationary value for every possible rank.
    # Evaluate the actual sorted penalty, with no threshold implementation.
    candidates = [0.;others;-others]
    for rank in 0:p-m
      root = max(0.,(abs(gamma)-sum(weights[rank+1:rank+m]))/curvature)
      append!(candidates,[root,-root])
    end
    objective(t) = curvature*t^2/2-gamma*t+dot(weights,sort!([fill(abs(t),m);others];rev=true))
    oracle = candidates[argmin(objective.(candidates))]
    @test z ≈ oracle atol=1e-10 rtol=1e-10
  end
end

# A product-only design that rejects scalar indexing and preserves restrictions.
# It also permits injecting one bad cluster direction, without corrupting APG.
struct ImplicitDesign{T,M<:AbstractMatrix{T}} <: AbstractMatrix{T}
  data::M
  failures::Base.RefValue{Int}
end
Base.size(X::ImplicitDesign) = size(X.data)
Base.getindex(::ImplicitDesign,::Int,::Int) = error("scalar indexing an implicit design")
Base.getindex(X::ImplicitDesign,::Colon,E::AbstractVector) = ImplicitDesign(X.data[:,E],X.failures)
LinearAlgebra.mul!(out::AbstractVector,X::ImplicitDesign,b::AbstractVector) = mul!(out,X.data,b)
LinearAlgebra.mul!(out::AbstractVector,X::Transpose{<:Any,<:ImplicitDesign},b::AbstractVector) = mul!(out,transpose(parent(X).data),b)
Base.:*(X::ImplicitDesign,b::AbstractVector) = X.data*b
Base.:*(X::Transpose{<:Any,<:ImplicitDesign},b::AbstractVector) = transpose(parent(X).data)*b
function cluster_column!(column,X::ImplicitDesign,indices,signs)
  if X.failures[] > 0
    X.failures[] -= 1
    fill!(column,NaN)
  else
    cluster_column!(column,X.data,indices,signs)
  end
end

@testset "Hybrid paths, representations, repairs and fallback" begin
  @test_throws ArgumentError HybridPrototype(;maxiter=1)
  @test_throws ArgumentError HybridPrototype(;tol=NaN)
  rng = Xoshiro(951)
  A = randn(rng,40,60); A[:,2] .= A[:,1]
  y = 2A[:,1]-A[:,3]+.1randn(rng,40)
  weights = collect(range(.6,.1;length=60))
  f = (1/40)*LeastSquaresLoss(y,A)
  g = SLOPE(weights)
  top = lambda_max(f,g,zeros(60)); grid = top.*[1.,.6,.2,.05]
  oracle = solve_path(f,g,grid,SLOPEAPG(;tol=1e-8))
  @test all(oracle.converged)
  for design in (A,sparse(A),ImplicitDesign(A,Ref(0)))
    loss = (1/40)*LeastSquaresLoss(y,design)
    path = solve_path(loss,g,grid,HybridPrototype(;tol=1e-8))
    @test all(path.converged)
    @test all(norm(A*(a-b),Inf)<1e-4 for (a,b) in zip(path.solutions,oracle.solutions))
    full = solve_path(loss,g,grid,HybridPrototype(;tol=1e-8);screening=false)
    @test all(full.converged)
    @test all(norm(A*(a-b),Inf)<1e-4 for (a,b) in zip(path.solutions,full.solutions))
    repaired = solve!(zeros(60),loss,SLOPE(.2top.*weights),HybridPrototype(;tol=1e-8);candidates=Int[])
    @test repaired.converged && repaired.kkt_repairs > 0
    limited = solve_path(loss,g,grid,HybridPrototype(;maxiter=2,tol=1e-12))
    @test all(<=(2),limited.iterations)
    @test !all(limited.converged)
    @test length(limited.solutions) == length(grid)
  end
  faulty = ImplicitDesign(A,Ref(1))
  restored = solve!([fill(.1,30);zeros(30)],(1/40)*LeastSquaresLoss(y,faulty),SLOPE(.2top.*weights),HybridPrototype(;tol=1e-8))
  @test faulty.failures[] == 0
  @test restored.converged
  @test norm(A*(restored.minimizer-oracle.solutions[3]),Inf)<1e-4
end

@testset "SLOPE sweep and splitting" begin
  X = Matrix{Float64}(I,3,3); y = [3.,1.,-2.]
  weights = [.9,.6,.3]
  x = [1.,1.,0.]; residual = y-X*x
  before = sum(abs2,residual)/2+SLOPE(weights)(x)
  @test cluster_sweep!(x,X,residual,1.,weights)
  @test abs(x[1]) == abs(x[2])
  @test x[3] == 0
  @test sum(abs2,y-X*x)/2+SLOPE(weights)(x) <= before
  result = solve!(copy(x),LeastSquaresLoss(y,X),SLOPE(weights),HybridPrototype(;tol=1e-9))
  oracle = similar(x); prox!(oracle,SLOPE(weights),y,1.)
  @test result.converged
  @test result.minimizer ≈ oracle atol=1e-8
  @test abs(result.minimizer[1]) != abs(result.minimizer[2])
  @test result.minimizer[3] != 0

  # Opposite signed identical columns give an exactly zero-curvature direction.
  A = [1. 1.;2. 2.]; b = [1.,2.]; z = [1.,-1.]
  @test cluster_sweep!(z,A,b-A*z,1.,[.2,.1])
  @test z == zeros(2)
  f32 = .25f0*LeastSquaresLoss(Float32[3,2,1,0],2Matrix{Float32}(I,4,4))
  result32 = solve!(zeros(Float32,4),f32,SLOPE(Float32[.4,.3,.2,.1]),HybridPrototype(;tol=1e-5))
  @test result32.converged
  @test result32.minimizer ≈ Float32[1.1,.7,.3,0] atol=1e-5
end
