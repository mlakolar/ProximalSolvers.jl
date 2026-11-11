using ProximalBase, PrecompileTools, Random, LinearAlgebra
BLAS.set_num_threads(1)
module Historical
include(joinpath(@__DIR__,"historical","src","ProximalSolvers.jl"))
end
module Candidate
include(joinpath(@__DIR__,"candidate","src","ProximalSolvers.jl"))
end
function probe(api)
 T=Float32; q=T(.01); X=T[1 .2;-.3 1;.5 -.4;1 1]; y=T[1,-.4,.8,.2]
 s=one(T)/T(4);lambda=T(.1);x=zeros(T,2)
 result=api.solve!(x,s*LeastSquaresLoss(q*y,q*X),NormL1(lambda*q*q),api.CDSolver(order=:cyclic,rng=Xoshiro(88)))
 (;x,converged=result.converged,passes=result.passes,maxchange=result.maxchange,tolerance=result.tolerance,minimum=result.minimum)
end
println("julia=",VERSION," host_cpu=",Sys.CPU_NAME," cpu_target=",unsafe_string(Base.JLOptions().cpu_target)," bounds=",Base.JLOptions().check_bounds," PB=",pathof(ProximalBase))
a,b=probe(Historical.ProximalSolvers),probe(Candidate.ProximalSolvers)
println("historical=",a);println("candidate=",b);println("IDENTICAL=",isequal(a,b))
isequal(a,b)||error("finite trajectory/status differs between preserved and extracted code")
