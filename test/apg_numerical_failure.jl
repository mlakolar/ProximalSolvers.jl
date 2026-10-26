module APGNumericalFailureTests
using Test, LinearAlgebra, SparseArrays, Statistics, ProximalBase, ProximalSolvers

# A legitimate implicit centering map with cancellation in its products. Cached
# extrapolated images and freshly evaluated images can disagree near a solution.
struct CenteredSparseColumn <: AbstractMatrix{Float64}
  X::SparseMatrixCSC{Float64,Int}
  center::Vector{Float64}
end
Base.size(Z::CenteredSparseColumn) = size(Z.X)
Base.getindex(Z::CenteredSparseColumn,i::Int,j::Int) = Z.X[i,j]-Z.center[j]
function LinearAlgebra.mul!(out::AbstractVector,Z::CenteredSparseColumn,b::AbstractVector,α::Number,δ::Number)
  mul!(out,Z.X,b,α,δ)
  out .-= α*dot(Z.center,b)
  out
end
LinearAlgebra.mul!(out::AbstractVector,Z::CenteredSparseColumn,b::AbstractVector) = mul!(out,Z,b,true,false)
function LinearAlgebra.mul!(out::AbstractVector,A::Union{Transpose{<:Any,<:CenteredSparseColumn},Adjoint{<:Any,<:CenteredSparseColumn}},b::AbstractVector,α::Number,δ::Number)
  Z=parent(A)
  mul!(out,transpose(Z.X),b,α,δ)
  out .-= (α*sum(b)).*Z.center
  out
end
LinearAlgebra.mul!(out::AbstractVector,A::Union{Transpose{<:Any,<:CenteredSparseColumn},Adjoint{<:Any,<:CenteredSparseColumn}},b::AbstractVector) = mul!(out,A,b,true,false)

@testset "APG handles cancellation without false success" begin
  X=reshape(1e8 .+ Float64.(0:9),:,1)
  center=mean(X)
  scale=sqrt(sum(abs2,X.-center)/10)
  Z=CenteredSparseColumn(sparse(X./scale),[center/scale])
  y=Float64.(0:9).-4.5
  # A stable Taylor-remainder check can now solve a case that previously failed.
  # Validate success against the exact operator represented by the stored data,
  # rather than requiring one particular floating-point failure trajectory.
  B=BigFloat.(Matrix(Z.X)).-BigFloat(Z.center[1])
  by=BigFloat.(y)
  for tol in (1e-7,1e-8)
    x=zeros(1)
    result=try
      solve!(x,(1/10)*LeastSquaresLoss(y,Z),SLOPE([0.01]),SLOPEAPG(;maxiter=20,tol))
    catch err
      @test err isa ErrorException
      nothing
    end
    if result !== nothing
      @test result.converged
      gradient=only(B'*(B*BigFloat.(x)-by))/10
      target=tol*max(1,abs(only(B'*by)/10))
      @test abs(gradient+BigFloat(0.01)*sign(x[1])) <= target
    end
  end
  # The equivalent explicitly centered problem must still converge.
  D=(X.-center)./scale
  result=solve!(zeros(1),(1/10)*LeastSquaresLoss(y,D),SLOPE([0.01]),SLOPEAPG(;maxiter=20))
  @test result.converged
end
end
