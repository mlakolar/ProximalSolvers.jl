using ProximalSolvers, ProximalBase, LinearAlgebra, Logging, Printf
BLAS.set_num_threads(1)
const ROOT = "<REVIEW>"
module X1
include("<X1>/src/ProximalSolvers.jl")
end
const B = X1.ProximalSolvers
println("Julia ", VERSION, " PB ", pathof(ProximalBase))
function showres(label, x, r)
  println(label, " x=", x, " converged=", r.converged, " iter=", hasproperty(r,:passes) ? r.passes : r.iterations,
          " minimum=", r.minimum, hasproperty(r,:grad_calls) ? " gradients=$(r.grad_calls) stagnated=$(r.stagnated)" : "")
end
# An ordinary-range warm start with a large component in the nullspace.
for T in (Float32,Float64)
  M = T === Float32 ? T(2)^20 : T(2)^49
  X, y, g = ones(T,1,2), T[1/64], NormL1(T(1/1024))
  for (name,modu) in (("master",ProximalSolvers),("X1",B))
    x = T[M,-M]
    r = modu.solve!(x,LeastSquaresLoss(y,X),g,modu.CDSolver(order=:cyclic,momentum=false))
    showres("warm-cancel $T $name",x,r)
    setprecision(BigFloat,600) do
      xb, Xb, yb, lb = big.(x), big.(X),big.(y),big(g.λ0)
      gr = Xb'*(Xb*xb-yb)
      G=maximum(abs.(gr+lb*sign.(xb)))
      F=sum(abs2,Xb*xb-yb)/2+lb*sum(abs,xb)
      # x1=y-lambda,x2=0 is an exact minimizer here.
      Fs=lb*yb[1]-lb^2/2
      println("  exact normalized KKT=",Float64(G/yb[1])," relative suboptimality=",Float64((F-Fs)/Fs)," true F=",Float64(F))
    end
  end
end
# X1 changes the strict underflow result into false mathematical convergence.
for T in (Float32,Float64)
  ex,ey,es = T===Float32 ? (-70,-90,90) : (-500,-700,300)
  X,y,s = fill(ldexp(T(1),ex),2,1),fill(ldexp(T(1),ey),2),ldexp(T(1),es)
  l=ldexp(T(1),es+ex+ey-2)
  for (name,modu) in (("master",ProximalSolvers),("X1",B)), sol in (:pgd,:apg)
    x=zeros(T,1)
    met=sol===:pgd ? modu.ProximalGradientDescent() : modu.AccProxGradDescent()
    opt=modu.ProximalOptions(ftol=0,xtol=1e-300,gradtol=1e-11,maxiter=20,allow_f_increases=true)
    r=modu.solve!(x,s*LeastSquaresLoss(y,X),NormL1(l),met,opt)
    showres("underflow-strict $T $name $sol",x,r)
  end
end
# A one-dimensional cancellation gives a transient stall at L=.9 and motion at L=.81.
for T in (Float32,Float64)
  u=eps(T)
  # gradient at x0=1 is 7u/16; the small lambda is representable.
  a=T(1/2); yy=prevfloat(a); lambda=T(u*3/16)
  X,y,g=reshape(T[a],1,1),T[yy],NormL1(lambda)
  for (name,modu) in (("master",ProximalSolvers),("X1",B))
    x=T[1]
    opt=modu.ProximalOptions(ftol=0,xtol=1e-300,gradtol=1e-12,maxiter=100,allow_f_increases=true,grad_calls_limit=2,store_trace=true,extended_trace=true)
    r=modu.solve!(x,LeastSquaresLoss(y,X),g,modu.AccProxGradDescent(),opt)
    showres("call-limit $T $name",x,r)
  end
end
