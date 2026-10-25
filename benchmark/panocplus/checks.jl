using Test
include("common.jl")
BLAS.set_num_threads(1)
@testset "L-BFGS circular history agrees with explicit inverse updates" begin
    rng=Xoshiro(8);h=LBFGSMemory(zeros(4),3)
    for rep in 1:8
        s=randn(rng,4);y=Diagonal([1.,2,3,4])*s
        @test update!(h,s,y)
        j=h.head;Y=h.Y[:,j];H=Matrix(1.0I,4,4)/(h.rho[j]*dot(Y,Y))
        for k in h.used-1:-1:0
            j=mod1(h.head-k,3);s=h.S[:,j];y=h.Y[:,j];r=h.rho[j]
            H=(I-r*s*y')*H*(I-r*y*s')+r*s*s'
        end
        r=randn(rng,4);d=zeros(4);direction!(d,h,r)
        @test d≈-H*r rtol=1e-12
    end
end
@testset "PANOCplus certificates, envelope descent, bad steps and directions" begin
    for T in (Float64,Float32)
        f=QuadraticFunction(Matrix(Diagonal(T[1,4,9])),T[-1,2,-3])
        g=NormL1(T(0.2));solution=T[0.8,-0.45,2.8/9]
        x=zeros(T,3);hist=NamedTuple[]
        res=panocplus!(x,f,g;gamma0=10.0,residual_tol=T==Float32 ? 1e-4 : 1e-8,history=hist)
        @test x≈solution atol=(T==Float32 ? 1e-4 : 1e-7)
        @test res.shrinks>0
        @test all(hist[i].phi<=hist[i-1].phi+1e-5 for i in 2:length(hist))
    end
    S=covariance(12);w=fill(0.1,12,12);w[diagind(w)].=0
    f,g=LogDetLoss(S),NormL1(1.0,w);x=Matrix(1.0I,12,12)
    cert=x->glasso_certificate(S,w,x)<=1e-6
    res=panocplus!(x,f,g;gamma0=100.0,check=cert)
    @test cert(x)
    @test res.rejects>0
    @test abs(glasso_certificate(S,w,x)-certificate(f,g,x))<1e-10
    # Force off-domain quasi-Newton points. The PG fallback must still work.
    x=Matrix(1.0I,12,12)
    bad=(d,x,r)->(d .= -100 .* x)
    res=panocplus!(x,f,g;check=cert,direction_override=bad,maxiter=10000)
    @test cert(x)
    @test res.rejects>0
end
@testset "adaptive rules match equations and independent trajectory" begin
    @test AdaptivePrototype.next_gamma(:adapgm,0.5,0.25,2.,3.,5.)≈0.5sqrt(3)
    @test AdaptivePrototype.next_gamma(:adapgm,1.,1.,2.,3.,5.)≈0.5
    @test AdaptivePrototype.next_gamma(:mm,0.5,0.25,2.,3.,5.)≈1/(2sqrt(2.5))
    @test AdaptivePrototype.next_gamma(:adapgm,1.,1.,0.,0.,0.)≈sqrt(2)
    f=QuadraticFunction(Matrix(Diagonal([1.,4.,9.])),[-1.,2.,-3.]);g=NormL1(0.2)
    for rule in (:adapgm,:mm)
        x=zeros(3);adaptive!(x,f,g;rule,gamma0=0.01,maxiter=12,every=100)
        old=zeros(3);gradold=[-1.,2.,-3.];gamma=0.01;previous=gamma
        z=sign.(old-gamma*gradold).*max.(abs.(old-gamma*gradold).-gamma*0.2,0)
        for k in 1:11
            grad=[1.,4.,9.].*z+[-1.,2.,-3.]
            s=z-old;y=grad-gradold
            L=norm(y)/norm(s)
            ell=dot(s,y)/dot(s,s);c=dot(y,y)/dot(s,y)
            growth=gamma*sqrt(1+(k==1&&rule==:mm ? Inf : gamma/previous))
            new=rule==:mm ? min(growth,1/(2L)) : min(growth,gamma/(2sqrt(max(gamma*ell*(gamma*c-1),0))))
            old=z;gradold=grad;previous,gamma=gamma,new
            v=z-gamma*grad;z=sign.(v).*max.(abs.(v).-gamma*0.2,0)
        end
        @test x≈z atol=1e-14
        x=zeros(3);res=adaptive!(x,f,g;rule,gamma0=0.01,check=x->norm(x-[0.8,-0.45,2.8/9],Inf)<1e-6)
        @test res.status==:target
    end
    S=Matrix(10.0I,3,3);w=fill(0.1,3,3);w[diagind(w)].=0
    x=Matrix(1.0I,3,3)
    res=adaptive!(x,LogDetLoss(S),NormL1(1.0,w);gamma0=10.0)
    @test res.status==:invalid_domain
    @test res.shrinks==0
end
println("PROTOTYPE_CHECKS_PASSED")
