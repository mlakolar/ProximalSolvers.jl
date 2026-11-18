using ProximalSolvers, ProximalBase, LinearAlgebra
module X1
include("<WORK>/ps-353-x1d/src/ProximalSolvers.jl")
end
println("Julia ",VERSION)
for (label,X,y,beta,lambda) in [
 ("zero response tiny column",fill(1e-150,2,1),zeros(2),zeros(1),1e-151),
 ("exact fit tiny column",fill(1e-150,2,1),fill(1e-150,2),ones(1),1e-151),
 ("zero column",zeros(2,1),ones(2),zeros(1),1.0)]
 println(label)
 for (name,p) in [("master",ProximalSolvers),("x1d",X1.ProximalSolvers)]
  x=copy(beta)
  try
   result=p.solve!(x,SqrtLeastSquaresLoss(y,X),NormL1(lambda),p.CDSolver(order=:cyclic,momentum=false,maxpasses=10))
   println(name," returned x=",x," converged=",result.converged," gap=",result.gap)
  catch e
   println(name," error=",sprint(showerror,e))
  end
 end
end
for n in [20,100,1000],v in [1f-18,1.1f-18,1.5f-18]
 y=fill(v,n);s=0f0
 for a in y;s+=a*a;end
 exact=sum(abs2,Float64.(y))
 println("fixed y n=",n," v=",v," sum/exact=",Float64(s)/exact)
end
