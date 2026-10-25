using Test
include("common.jl")

@testset "Path handoff caches and reset equivalence" begin
    P=problem(60,100,0.9,10,14);weights=weight_sequence("bh",100)
    alphas=alpha_max(P.X,P.y,weights).*[1.,0.3,0.1,0.05]
    original=package_fit(P.X,P.y,weights,alphas,"APG";limit=20.)
    baseline=reuse_path(P.X,P.y,weights,alphas,"reset";limit=20.)
    @test baseline.betas==original.betas
    @test [i.iterations for i in baseline.infos]==[i.iterations for i in original.infos]
    savedX=copy(P.X);savedy=copy(P.y)
    for mode in REUSE_METHODS[1:5]
        seen=Int[]
        observer=function(level,st,g,f)
            @test st.f_x≈f(st.x) rtol=1e-12
            @test st.g_x≈g(st.x) rtol=1e-12
            @test st.z_x≈P.X*st.x rtol=1e-12 atol=1e-12
            if mode=="full_state" && level>1 && st.k>0
                @test st.g_x_previous≈g(st.x_previous) rtol=1e-12
                @test st.f_x_previous≈f(st.x_previous) rtol=1e-12
                @test st.z_previous≈P.X*st.x_previous rtol=1e-12 atol=1e-12
            else
                @test st.k==0
                @test st.x_previous==st.x
            end
            push!(seen,level)
        end
        fit=reuse_path(P.X,P.y,weights,alphas,mode;limit=20.,observer)
        @test seen==collect(1:4)
        @test all(final_metrics(P.X,P.y,weights,alphas[k],b).valid for (k,b) in enumerate(fit.betas))
        if mode in ("carry_L","workspace_L","full_state")
            @test all(fit.infos[k].initial_L==fit.infos[k-1].final_L for k in 2:4)
        else
            @test all(i.initial_L==1.0 for i in fit.infos)
        end
    end
    @test P.X==savedX
    @test P.y==savedy
end

@testset "Known orthogonal optima and failed path handoff" begin
    n=12;X=Matrix(1.0I,n,n);y=randn(Xoshiro(57),n);w=weight_sequence("linear",n)
    alphas=alpha_max(X,y,w).*[1.,0.3,0.05]
    for mode in REUSE_METHODS
        fit=timed_reuse(X,y,w,alphas,mode;limit=10.)
        @test fit.valid
        @test all(norm(b-PB.prox(PB.SLOPE(n*alphas[k].*w),y),Inf)<1e-4 for (k,b) in enumerate(fit.betas))
    end
    P=problem(60,100,0.9,10,14);w=weight_sequence("linear",100)
    for mode in REUSE_METHODS[1:5]
        fit=reuse_path(P.X,P.y,w,alpha_max(P.X,P.y,w).*[0.1,0.05],mode;maxiter=2,limit=10.)
        @test length(fit.betas)==1
        @test only(fit.infos).status==:maxiter
    end
end
println("PATH_REUSE_CHECKS_PASSED")
