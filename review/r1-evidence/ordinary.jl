using ProximalSolvers, ProximalBase, LinearAlgebra, Logging
BLAS.set_num_threads(1)
module X1
include("<X1>/src/ProximalSolvers.jl")
end
const B=X1.ProximalSolvers
for T in (Float32,Float64)
  d=eps(T)/2; X=reshape(T[1,d,-1],3,1);y=ones(T,3);lambda=d/8
  println(T," X=",vec(X)," lambda=",lambda," computed XTy=",only(X'*y)," exact lambda_max=",d)
  for (name,P) in (("master",ProximalSolvers),("X1",B)), sol in (:cd,:pgd,:apg), strict in (false,true)
    strict && sol===:cd && continue
    x=zeros(T,1);f=LeastSquaresLoss(y,X);g=NormL1(lambda)
    method=sol===:cd ? P.CDSolver(order=:cyclic,momentum=false) : sol===:pgd ? P.ProximalGradientDescent() : P.AccProxGradDescent()
    opt=P.ProximalOptions(;maxiter=20,ftol=strict ? 0 : 1e-8,xtol=strict ? 1e-300 : 1e-5,gradtol=strict ? 1e-11 : 1e-5,allow_f_increases=true)
    r=sol===:cd ? P.solve!(x,f,g,method) : P.solve!(x,f,g,method,opt)
    println(" ",name," ",sol," strict=",strict," x=",x," converged=",r.converged," iterations=",hasproperty(r,:passes) ? r.passes : r.iterations)
  end
end
# A stall can fail stationarity and later escape as L decreases. Added APG checks count against call limits.
# Choose x0=1, X tiny, y large enough to leave a gradient just below the rounding threshold of x0.
for limit in (0,2,3,344,350)
  T=Float64; X=reshape(T[2.0^-27],1,1);y=T[2.0^-28];g=NormL1(0.0)
  for (name,P) in (("master",ProximalSolvers),("X1",B))
    x=T[1];opt=P.ProximalOptions(ftol=0,xtol=1e-300,gradtol=1e-5,maxiter=1000,allow_f_increases=true,grad_calls_limit=limit)
    r=P.solve!(x,LeastSquaresLoss(y,X),g,P.AccProxGradDescent(),opt)
    println("counter-example limit=",limit," ",name," x=",x," conv=",r.converged," iter=",r.iterations," grad=",r.grad_calls," limited=",r.call_limit_reached)
  end
end
# APG's x == y but x != x_previous should continue to use its gradient proposal.
for (name,P) in (("master",ProximalSolvers),("X1",B))
  x=[0.0];f=LeastSquaresLoss([1.0],reshape([1.0],1,1));g=NormL1(2.0);o=P.ProximalOptions(ftol=0)
  s=P.initial_state(P.AccProxGradDescent(),o,f,g,x)
  s.x_previous .= 1.0;s.delta_x .= -1.0;s.y .= 0.0;s.grad_f_y .= -1.0
  s.f_x=0.5;s.f_x_previous=0.0;s.g_x=0.0;s.g_x_previous=2.0;s.L=1.0
  println("apg-x-equals-y ",name," assessment=",P.convergence_assessment(s,f,g,o))
end
