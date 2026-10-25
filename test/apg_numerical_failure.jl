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

@testset "APG reports cancellation-induced line search failure" begin
  X=reshape(1e8 .+ Float64.(0:9),:,1)
  center=mean(X)
  scale=sqrt(sum(abs2,X.-center)/10)
  Z=CenteredSparseColumn(sparse(X./scale),[center/scale])
  y=Float64.(0:9).-4.5
  for tol in (1e-7,1e-8)
    @test_throws ErrorException solve!(zeros(1),(1/10)*LeastSquaresLoss(y,Z),
      SLOPE([0.01]),SLOPEAPG(;maxiter=20,tol))
  end
  # The equivalent explicitly centered problem must still converge.
  D=(X.-center)./scale
  result=solve!(zeros(1),(1/10)*LeastSquaresLoss(y,D),SLOPE([0.01]),SLOPEAPG(;maxiter=20))
  @test result.converged
end
end
