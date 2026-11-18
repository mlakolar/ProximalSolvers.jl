include("<REVIEW>/.codex-orchestrator/audit/study/lib.jl")
setprecision(BigFloat,600)
BLAS.set_num_threads(1)
println("Julia ",VERSION)
for T in (Float64,Float32)
  _,X0,y0=fixture("tall_exact");X,y=T.(X0),T.(y0)
  lmax=maximum(abs,Float64.(X)'*Float64.(y))/norm(Float64.(y))
  for frac in (.001,.3,.7)
    l=T(frac*lmax);g=NormL1(l);f=SqrtLeastSquaresLoss(y,X);x=zeros(T,size(X,2))
    r=quiet(()->solve!(x,f,g,CDSolver(order=:cyclic,momentum=false)))
    w=SparseIterate(x);m=PS.cdmodel(f,w);PS.initialize!(m,w);PS._prepare!(m,g,w)
    code,ratio=PS._certify!(m,w)
    nb=count(!iszero,x);n=size(X,1);eps64=eps(Float64);eta=nextfloat(0.0);psi=(n+1)*eps64
    smu=sum(abs2,m.rowmag64)
    Mup=PS._up(sqrt(PS._up(PS._up(smu*(1+psi))+n*eta)))
    Eup=PS._up(PS._up(((nb+1)*eps64)*Mup)+PS._up(PS._up(Float64(nb)*Float64(n))*eta))
    rho=norm(m.res64);ind=sqrt_measures(X,y,l,x);P=ind.P
    println(T," fraction=",frac," converged=",r.converged," passes=",r.passes," certificate=",code," ratio=",ratio," residual64_norm=",rho," Eup=",Eup," Eup/residual=",Eup/rho," Eup/P=",Float64(Eup/P)," ideal_dual_positive=",ind.D>0," independent_gap=",ind.D>0 ? Float64((P-ind.D)/ind.D) : NaN)
  end
end
println("scaled-reference precision:")
for T in (Float64,Float32)
  _,X0,y0=fixture("gauss");X,y=T.(X0),T.(y0);l=T(.1*maximum(abs,Float64.(X)'*Float64.(y)))
  R=LassoRef(X,y,one(T),l,zero(T));ref=reference(R,Float64.(X),Float64.(y),1.0,l,zero(T))
  println(T," (Fref-Dref)/Dref=",Float64((ref.Fref-ref.Dref)/ref.Dref))
end
