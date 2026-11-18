using ProximalSolvers,ProximalBase,LinearAlgebra
BLAS.set_num_threads(1)
module X1
include("<X1>/src/ProximalSolvers.jl")
end
const B=X1.ProximalSolvers
let tol=1e-7, delta=1e-12
  X=[1.0 1.0;0.0 1.0];y=[delta,0.0];x=[0.0,tol/2]
  r=solve!(x,LeastSquaresLoss(y,X),NormL1(0.0),CDSolver(order=:cyclic,momentum=false,relative=false,tol=tol))
  println("absolute-bound conv=",r.converged," passes=",r.passes," KKT=",maximum(abs,X'*(X*x-y))," claimed relative RHS=",tol*norm(y))
end
for T in (Float32,Float64)
  X=Matrix(Diagonal(T[1,0,2]));y=T[1,3,2]
  g=GroupNormL2(T(1/4),[[1],[2],[3]],T[0,1,2])
  x=BlockIterate(T[1,1,1],g)
  r=solve!(x,LeastSquaresLoss(y,X),g,CDSolver(order=:cyclic))
  println("zero-weight/flat-group ",T," x=",collect(x)," conv=",r.converged," passes=",r.passes," F=",r.minimum," expected=[1,0,0.875], F=4.96875")
end
for (name,P) in (("master",ProximalSolvers),("X1",B))
  hits=Int[];x=[1.0]
  f=LeastSquaresLoss([2.0^-28],reshape([2.0^-27],1,1));g=NormL1(0.0)
  o=P.ProximalOptions(ftol=0,xtol=1e-300,gradtol=1e-5,maxiter=1000,allow_f_increases=true,print_every=7,callback=s->(push!(hits,s.iteration);false))
  r=P.solve!(x,f,g,P.AccProxGradDescent(),o)
  println("callback ",name," conv=",r.converged," iterations=",r.iterations," calls=",length(hits)," cadence=",all(hits.==collect(7:7:r.iterations))," grad=",r.grad_calls)
end
