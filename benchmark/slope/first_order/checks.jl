using Test
include("common.jl")
include("profile.jl")
@testset "Native controls and faithful APG phase timers" begin
    n=4;X=Matrix{Float64}(I,n,n).*sqrt(n);y=sqrt(n).*[4.,2.,1.,0.]
    weights=[3.,2.,1.,.5];alphas=[1.,.3,.05]
    expected=[[1.,0.,0.,0.],[3.1,1.4,.7,0.],[3.85,1.9,.95,0.]]
    X0,y0,w0=copy(X),copy(y),copy(weights)
    for method in CONTROL_METHODS
        fit=timed_control(X,y,weights,alphas,method;tol=1e-8)
        @test fit.valid
        @test length(fit.betas)==3
        for (actual,target) in zip(fit.betas,expected)
            @test actual≈target atol=2e-4
        end
        @test X==X0 && y==y0 && weights==w0
    end
    for rho in (0.,.9),kind in ("linear","bh")
        P=problem(80,120,rho,10,0);w=weight_sequence(kind,120)
        a=alpha_max(P.X,P.y,w).*path_fractions()
        plain=timed_reuse(P.X,P.y,w,a,"workspace_L")
        profiled=timed_profile(P.X,P.y,w,a)
        @test check_profile_match(plain,profiled)
        for method in CONTROL_METHODS[3:end]
            fit=timed_control(P.X,P.y,w,a,method)
            @test fit.valid
            @test maximum(abs(m.primal-b.primal)/max(1,abs(b.primal)) for (m,b) in zip(fit.metrics,plain.metrics))<2e-6
        end
    end
end
