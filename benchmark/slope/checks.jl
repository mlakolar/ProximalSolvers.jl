using Test
include("common.jl")
@testset "SLOPE dual ball, alpha_max and known optima" begin
    rng=Xoshiro(57);n=12
    X=Matrix(1.0I,n,n);y=randn(rng,n)
    for weights in (fill(0.7,n),[1.;zeros(n-1)],weight_sequence("linear",n),weight_sequence("bh",n))
        amax=alpha_max(X,y,weights)
        zero_cert=Certificate(X,y,weights,amax)
        @test zero_cert(zeros(n);tol=1e-12)
        @test norm(PB.prox(PB.SLOPE(n*amax.*weights),y))<1e-12
        @test !Certificate(X,y,weights,0.9amax)(zeros(n);tol=1e-12)
        alpha=0.2amax
        solution=PB.prox(PB.SLOPE(n*alpha.*weights),y)
        m=final_metrics(X,y,weights,alpha,solution)
        @test m.valid
        @test m.gap<1e-12
        @test m.fixedpoint<1e-12
        @test m.feasibility<=1+1e-12
        for method in ("PG","APG","SLOPE.jl")
            fit=timed_fit(X,y,weights,[alpha],method;limit=5)
            @test fit.valid
            @test norm(only(fit.betas)-solution,Inf)<1e-4
        end
    end
    z=randn(rng,n)
    @test dualnorm!(zeros(n),z,ones(n))≈norm(z,Inf)
    @test dualnorm!(zeros(n),z,[1.;zeros(n-1)])≈norm(z,1)
end
@testset "Matched library scaling, full paths, and independent final checks" begin
    P=problem(60,100,0.9,10,57)
    savedX=copy(P.X);savedy=copy(P.y)
    for kind in ("linear","bh")
        weights=weight_sequence(kind,100);amax=alpha_max(P.X,P.y,weights)
        alphas=amax.*[1.,0.3,0.05]
        fits=[timed_fit(P.X,P.y,weights,alphas,method;limit=10) for method in ("PG","APG","SLOPE.jl")]
        @test P.X==savedX
        @test P.y==savedy
        for fit in fits
            @test fit.valid
            @test length(fit.betas)==3
            @test all(m.feasibility<=1+1e-12 for m in fit.metrics)
            @test maximum(abs(m.primal-b.primal)/max(1,abs(b.primal)) for (m,b) in zip(fit.metrics,last(fits).metrics))<2e-6
        end
    end
    w=weight_sequence("bh",100)
    @test issorted(w;rev=true)&&all(>(0),w)
    # A too-small cap is retained as a failure, and never used as a warm start.
    r=package_fit(P.X,P.y,w,alpha_max(P.X,P.y,w).*[0.05,0.01],"PG";maxiter=2,limit=10)
    @test length(r.betas)==1
    @test only(r.infos).status==:maxiter
end
println("SLOPE_CHECKS_PASSED")
