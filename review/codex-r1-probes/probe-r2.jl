using Pkg; Pkg.instantiate()
using ProximalBase, LinearAlgebra, Random, Logging
const PROTO = abspath(".codex-orchestrator/proto3")
module M0; include(joinpath(Main.PROTO, "master", "src", "ProximalSolvers.jl")); end
module MS; include(joinpath(Main.PROTO, "S1024", "src", "ProximalSolvers.jl")); end
setprecision(BigFloat,600)
for T in (Float32,Float64)
    j=T===Float32 ? 20 : 40; M=T(2)^j; delta=inv(M); lambda=T(2)^(-j-10)
    X=T[1 0;0 delta]; x0=T[0,M]; y=T[0,1+T(2)^(-10)]
    g=GroupNormL2(lambda,[[1,2]],[one(T)])
    for (name,P) in (("master",M0.ProximalSolvers),("S1024",MS.ProximalSolvers))
        x=BlockIterate(copy(x0),g)
        r=with_logger(NullLogger()) do
            P.solve!(x,LeastSquaresLoss(y,X),g,P.CDSolver(order=:cyclic,momentum=false,maxpasses=100))
        end
        xb=BigFloat.(collect(x)); rb=BigFloat.(y)-BigFloat.(X)*xb
        grad=-(BigFloat.(X)'*rb)+big(lambda)*xb/norm(xb)
        println((label="exact group optimum with explicit unit weight",T=T,name=name,converged=r.converged,passes=r.passes,x=collect(x),kkt=Float64(norm(grad))))
    end
end
for T in (Float32,Float64)
    ex=T===Float32 ? -100 : -600
    eX=T===Float32 ? 60 : 300
    ey=T===Float32 ? -70 : -360
    X=fill(T(2)^eX,1,2); y=T[T(2)^ey]; x0=T[T(2)^ex,-T(2)^ex]
    g=GroupNormL2(zero(T),[[1,2]],[one(T)])
    for (name,P) in (("master",M0.ProximalSolvers),("S1024",MS.ProximalSolvers))
        x=BlockIterate(copy(x0),g)
        r=with_logger(NullLogger()) do
            P.solve!(x,LeastSquaresLoss(y,X),g,P.CDSolver(order=:cyclic,momentum=false,maxpasses=20))
        end
        xb=BigFloat.(collect(x)); Xb=BigFloat.(X); yb=BigFloat.(y); rb=yb-Xb*xb
        rho=big(eps(T))*sum(norm(Xb[:,k])*abs(xb[k]) for k in eachindex(xb)); L=max(big(1e-7),big(1024)*big(eps(T)))*norm(yb)
        println((label="group bound squares underflow",T=T,name=name,converged=r.converged,passes=r.passes,x=collect(x),rho_over_L=Float64(rho/L),kkt_rel=Float64(norm(Xb'*rb)/norm(Xb'*yb)),reported=r.minimum,true_loss=Float64(sum(abs2,rb)/2)))
    end
end
