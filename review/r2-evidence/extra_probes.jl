include("<REVIEW>/.codex-orchestrator/audit/study/lib.jl")
BLAS.set_num_threads(1)
setprecision(BigFloat,600)
for T in (Float64,Float32)
  _,X0,y0=fixture("tall_exact")
  X,y=T.(X0),T.(y0)
  open("<TMP>/tall_$(T).tsv","w") do io
    for i in 1:size(X,1)
      println(io,join(vcat(Float64.(X[i,:]),Float64(y[i])),'\t'))
    end
  end
end
let T=Float32
  _,X0,y0=fixture("gauss");Xu,yu=T.(X0),T.(y0)
  lambda=T(.1*maximum(abs,Float64.(Xu)'*Float64.(yu)))
  for (ex,ey) in ((-20,0),(0,60),(20,-60))
    X,y,l=ldexp.(Xu,ex),ldexp.(yu,ey),ldexp(lambda,ex+ey)
    for (label,method) in (("pgd",ProximalGradientDescent()),("apg",AccProxGradDescent()))
      x=zeros(T,size(X,2)); r=solve!(x,LeastSquaresLoss(y,X),NormL1(l),method)
      println("scale ",ex," ",ey," ",label," converged=",r.converged," its=",r.iterations," increase=",r.f_increased," maxiter=",r.iteration_converged," norm_step=",r.x_residual," Float32_stepnorm_squared=",T(r.x_residual)^2)
    end
  end
end
