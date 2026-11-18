using ProximalSolvers, ProximalBase
module X2
include("<WORK>/ps-353-x2/src/ProximalSolvers.jl")
end
println("Julia ",VERSION)
y=fill(1f-18,100); X=ones(Float32,100,1)
s=0f0;for v in y;global s+=v*v;end
alpha=Float64(floatmin(Float32))^2/Float64(s)
println("s=",s," alpha=",alpha," native alpha=",Float32(alpha))
ProximalSolvers._check_loss_scale(alpha,Float32)
for (name,p) in [("master",ProximalSolvers),("x2",X2.ProximalSolvers)]
 try
  m=p.LSModel(y,X,alpha)
  println(name," response=",p.response_scale(m,nothing))
  result=p.solve!(zeros(Float32,1),alpha*LeastSquaresLoss(y,X),NormL1(1f0),p.CDSolver(maxpasses=2,momentum=false,order=:cyclic,tol=1))
  println(name," solve returned converged=",result.converged," x=",result.minimizer," tolerance=",result.tolerance)
 catch e
  println(name," error=",sprint(showerror,e))
 end
end
