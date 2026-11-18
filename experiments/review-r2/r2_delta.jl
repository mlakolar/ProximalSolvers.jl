using ProximalSolvers, ProximalBase, LinearAlgebra
module X2B
include("<RUN>/experiments/x2/x2b_tree/src/ProximalSolvers.jl")
end
module X2Old
include("<WORK>/ps-353-x2/src/ProximalSolvers.jl")
end
struct ReadVector{T} <: AbstractVector{T}
 v::Vector{T}
 reads::Base.RefValue{Int}
end
Base.size(v::ReadVector)=size(v.v)
Base.IndexStyle(::Type{<:ReadVector})=IndexLinear()
function Base.getindex(v::ReadVector,i::Int)
 v.reads[]+=1
 v.v[i]
end
function main()
 println("Julia ",VERSION)
 y=fill(1f-18,100);X=ones(Float32,100,1);s=0f0
 for v in y;s+=v*v;end
 alpha=Float64(floatmin(Float32))^2/Float64(s)
 for (name,P) in [("master",ProximalSolvers),("x2b",X2B.ProximalSolvers)]
  result=P.solve!(zeros(Float32,1),alpha*LeastSquaresLoss(y,X),NormL1(1f0),P.CDSolver(maxpasses=2,momentum=false,order=:cyclic,tol=1))
  println(name," boundary converged=",result.converged," x=",result.minimizer," tolerance=",result.tolerance)
 end
 for (name,P) in [("master",ProximalSolvers),("x2-old",X2Old.ProximalSolvers),("x2b",X2B.ProximalSolvers)]
  y=ReadVector(ones(Float32,100),Ref(0));m=P.LSModel(y,ones(Float32,100,1),1e-43)
  val=P.response_scale(m,nothing)
  println(name," response_scale reads=",y.reads[]," n=",length(y)," value=",val)
 end
 P=ProximalSolvers
 X=reshape([floatmax(Float64)],1,1);f=LeastSquaresLoss(zeros(1),X);model=P._image_model(f)
 d=[2.0];D=P._se_norm(Float64,d);normx=P._se_norm(Float64,[2.0]);c=P._bound_constants(Float64,X);buf=zeros(1)
 answer=P._bound_certified!(buf,model,zeros(1),zeros(1),d,D,1.0,P._se_zero(Float64),normx,P._root_scale(Float64,1.0),c,true)
 println("fresh Xd overflow: D is nothing=",D===nothing," normx is nothing=",normx===nothing," Xd=",buf," W is nothing=",P._se_norm_onepass(Float64,sum(abs2,buf),buf)===nothing," _bound_certified! returned=",answer)
end
main()
