using ProximalSolvers, ProximalBase, LinearAlgebra, Logging
BLAS.set_num_threads(1)
for T in (Float32,Float64)
  m=T===Float32 ? T(2)^24 : T(2)^53
  for vals in ([m,1,-m], [m,1,-m,0], [m,1,-m,0,0], [m,1,-m,0,0,0,0,0])
    X=reshape(T.(vals),:,1);y=ones(T,length(vals));g=NormL1(T(1/8))
    println(T," n=",length(vals)," BLAS XTy=",(X'*y)[1]," exact=1")
    for (label,method) in (("cd",CDSolver(order=:cyclic,momentum=false)),("pgd",ProximalGradientDescent()),("apg",AccProxGradDescent()))
      x=zeros(T,1)
      r=with_logger(NullLogger()) do
        solve!(x,LeastSquaresLoss(y,X),g,method)
      end
      setprecision(BigFloat,600) do
        grad=only(big.(X)'*(big.(X)*big.(x)-big.(y)))
        G=iszero(x[1]) ? max(abs(grad)-big(g.λ0),0) : abs(grad+big(g.λ0)*sign(x[1]))
        println("  ",label," x=",x," conv=",r.converged," its=",hasproperty(r,:passes) ? r.passes : r.iterations," exact KKT normalized=",Float64(G))
      end
    end
  end
end
