using Test
include("common.jl")
BLAS.set_num_threads(1)
@testset "Controlled design and coupled quartic derivative" begin
    U,V=design_factors(40,20,4)
    for kappa in (1.,100.,10000.)
        A=conditioned_design(U,V,kappa)
        sv=svdvals(A)
        @test (sv[1]/sv[end])^2≈kappa rtol=1e-10
        P=problem("quartic",A,4,kappa)
        x=0.1randn(Xoshiro(4),20);d=randn(Xoshiro(5),20);d/=norm(d)
        grad=similar(x);fx=value_and_gradient!(grad,P.f,x)
        epsfd=1e-5
        @test dot(grad,d)≈(P.f(x+epsfd*d)-P.f(x-epsfd*d))/(2epsfd) rtol=1e-6
        model=ProximalSolvers._image_model(P.f)
        @test model!==nothing
        z=ProximalSolvers._image_buffer(model);ProximalSolvers._image!(z,model,x)
        scratch=similar(z);grad2=similar(x)
        fx2=ProximalSolvers._image_value_and_gradient!(grad2,model,z,scratch)
        @test fx2≈fx rtol=1e-13
        @test grad2≈grad rtol=1e-13
    end
end
@testset "Both certificates and known orthogonal lasso solution" begin
    U,V=design_factors(40,20,2);A=conditioned_design(U,V,1.)
    P=problem("ls",A,2,1.);lambda=0.05P.scale
    v=A'*P.y;solution=sign.(v).*max.(abs.(v).-lambda,0)
    cert=BroadCertificate(P,lambda,1e-8)
    @test cert(solution)
    m=final_metrics(P,lambda,solution)
    @test m.kkt<1e-10
    @test m.gap<1e-10
    for method in ("adaPGM","PG","APG")
        fit=timed_fit(P,lambda,(method,"unit",1.0);limit=5,tol=1e-6)
        @test fit.valid
    end
end
@testset "Broad family smoke checks" begin
    U,V=design_factors(40,20,3);A=conditioned_design(U,V,10.)
    for family in ("ls","logistic","huber","poisson","quartic")
        P=problem(family,A,3,10.);lambda=0.05P.scale
        for method in ("adaPGM","PG","APG")
            fit=timed_fit(P,lambda,(method,"reference",1/P.L0);limit=5,tol=1e-6)
            @test fit.valid
            @test fit.result.status==:target
        end
    end
end
println("BROAD_CHECKS_PASSED")
