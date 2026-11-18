using Pkg; Pkg.instantiate()
using ProximalBase, LinearAlgebra, Random, Logging
const PROTO = abspath(".codex-orchestrator/proto3")
module M0; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
module MS; include(joinpath(Main.PROTO, "S1024", "src", "ProximalSolvers.jl")); end
setprecision(BigFloat,600)
function scalarcase(label,T,X,y,x0,lambda;cap=100,tol=1e-7,momentum=false,order=:cyclic)
    for (name,P) in (("master",M0.ProximalSolvers),("S1024",MS.ProximalSolvers))
        x=copy(x0)
        r=with_logger(NullLogger()) do
            P.solve!(x,LeastSquaresLoss(y,X),NormL1(lambda),P.CDSolver(;order,momentum,maxpasses=cap,tol,rng=Xoshiro(123)))
        end
        xb,Xb,yb=BigFloat.(x),BigFloat.(X),BigFloat.(y)
        rb=yb-Xb*xb; grad=-(Xb'*rb)
        kkt=maximum(iszero(xb[k]) ? max(abs(grad[k])-big(lambda),0) : abs(grad[k]+big(lambda)*sign(xb[k])) for k in eachindex(xb))
        println((label=label,T=T,name=name,converged=r.converged,passes=r.passes,maxchange=r.maxchange,x=x,kkt=Float64(kkt),tol=r.tolerance))
    end
end
for T in (Float32,Float64)
    j=T===Float32 ? 20 : 40
    M=T(2)^j; delta=inv(M); lambda=T(2)^(-j-10)
    X=T[1 1;0 delta]; x=T[-M,M]; y=T[-lambda,1+T(2)^(-9)]
    scalarcase("exact positive lasso optimum, cancelling columns",T,X,y,x,lambda)
    X2=T[1 0;0 delta]; x2=T[0,M]; y2=T[0,1+T(2)^(-10)]
    scalarcase("exact positive lasso optimum, unequal column norms",T,X2,y2,x2,lambda)
    scalarcase("same, cap=1",T,X2,y2,x2,lambda;cap=1)
    scalarcase("same, momentum",T,X2,y2,x2,lambda;momentum=true,order=:random)
    g=GroupNormL2(lambda,[[1,2]])
    for (name,P) in (("master",M0.ProximalSolvers),("S1024",MS.ProximalSolvers))
        xg=BlockIterate(T,2,g); xg[1]=x2[1]; xg[2]=x2[2]
        r=with_logger(NullLogger()) do
            P.solve!(xg,LeastSquaresLoss(y2,X2),g,P.CDSolver(order=:cyclic,momentum=false,maxpasses=100))
        end
        xb=BigFloat.(collect(xg)); rb=BigFloat.(y2)-BigFloat.(X2)*xb
        grad=-(BigFloat.(X2)'*rb)+big(lambda)*xb/norm(xb)
        println((label="exact positive group optimum, unequal column norms",T=T,name=name,converged=r.converged,passes=r.passes,maxchange=r.maxchange,x=collect(xg),kkt=Float64(norm(grad))))
    end
end
