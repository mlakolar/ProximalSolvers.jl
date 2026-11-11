# Recovered same-process harness. No measurements were run during recovery.
# Root must prepare a compatible PB environment and explicitly authorize use.
using ProximalBase, LinearAlgebra, Random, Statistics, SHA, Dates
BLAS.set_num_threads(1)
const EXPECTED_PB_A_DIGEST = "39b3ba0a53df8de3659e71ec138f67690003664fc82428dd28ee32be5d98af16"
# Bare scratch PS modules need PrecompileTools visible directly. Either put it
# in the selected environment's direct deps or populate dependencies/ with
# symlinks to the SAME installed PrecompileTools/Preferences as PB uses.
push!(LOAD_PATH,joinpath(@__DIR__,"dependencies"))

function source_digest(root)
    files=sort!([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
    ctx=SHA.SHA2_256_CTX()
    for p in files
        SHA.update!(ctx,codeunits(relpath(p,root)))
        SHA.update!(ctx,read(p))
    end
    bytes2hex(SHA.digest!(ctx))
end
function load_ps(wrapper_name, source_root)
    wrapper=Module(wrapper_name)
    Base.include(wrapper,joinpath(source_root,"ProximalSolvers.jl"))
    Base.invokelatest(getfield,wrapper,:ProximalSolvers)
end
function fixture(::Type{T},n,p) where T
    rng=Xoshiro(0x17a2c0+n+p)
    Z=randn(rng,n,p);shared=randn(rng,n)
    X64=sqrt(.8).*Z .+ sqrt(.2).*shared
    beta=zeros(p);beta[1:8].=[1.,-.8,.6,-.4,.3,-.2,.15,-.1]
    y64=X64*beta + 0.05 .* randn(rng,n)
    X,y=T.(X64),T.(y64)
    scale=one(T)/T(n)
    (;X,y,x0=zeros(T,p),f=scale*LeastSquaresLoss(y,X),g=NormL1(T(.03)),scale)
end
make_method(C::F,::Val{:CD}) where F=C(rng=Xoshiro(0x2cd314))
make_method(C::F,::Val{:PGD}) where F=C()
function prepare(problem,constructor::C,method,inner) where C
    [(copy(problem.x0),problem.f,problem.g,make_method(constructor,method)) for _ in 1:inner]
end
function batch!(solvefn::F,works::Vector{W}) where {F,W}
    x,f,g,m=works[1]
    result=solvefn(x,f,g,m)
    @inbounds for i in 2:length(works)
        x,f,g,m=works[i]
        result=solvefn(x,f,g,m)
    end
    result
end
function diagnostics(problem,result)
    raw=result.minimizer
    x=Float64.(raw);X=Float64.(problem.X);y=Float64.(problem.y)
    scale,lambda=Float64(problem.scale),Float64(problem.g.λ0)
    residual=X*x-y
    objective=scale*sum(abs2,residual)/2+lambda*sum(abs,x)
    d=scale*(X'*residual)
    kkt=maximum(iszero(x[i]) ? max(abs(d[i])-lambda,0.) : abs(d[i]+lambda*sign(x[i])) for i in eachindex(x))
    flags=join((string(s,'=',getproperty(result,s)) for s in (:converged,:iteration_converged,:x_converged,:f_converged,:grad_converged,:f_increased,:call_limit_reached) if hasproperty(result,s)),',')
    residuals=join((string(s,'=',repr(getproperty(result,s))) for s in (:x_residual,:f_residual,:g_residual,:maxchange,:tolerance,:kkt_checks,:gap) if hasproperty(result,s)),',')
    passes=hasproperty(result,:passes) ? result.passes : result.iterations
    counts=hasproperty(result,:f_calls) ? (result.f_calls,result.grad_calls,result.prox_calls,result.backtrack_steps) : (-1,-1,-1,-1)
    (passes,flags,result.minimum,bitstring(result.minimum),residuals,counts...,objective,kkt,sum(x),sum(abs2,x),sum(i*x[i] for i in eachindex(x)),count(!iszero,x),bytes2hex(SHA.sha256(reinterpret(UInt8,raw))),repr(raw))
end
function measure!(io,problem,solvername,method,inner,round,position,label,solvefn::F,constructor::C) where {F,C}
    works=prepare(problem,constructor,method,inner)
    timed=@timed batch!(solvefn,works)
    all_points_identical=all(w->isequal(w[1],timed.value.minimizer),works)
    all_points_identical || error("batch produced different final points for identical starts/seeds")
    row=(string(eltype(problem.x0)),size(problem.X)...,solvername,round,position,label,inner,timed.time/inner,timed.bytes/inner,timed.gctime/inner,diagnostics(problem,timed.value)...,all_points_identical)
    println(io,join(row,'\t'));flush(io)
end
function benchmark_case!(io,mods,::Type{T},n,p,inner,method;triplets=12) where T
    problem=fixture(T,n,p)
    symbol=method isa Val{:CD} ? :CDSolver : :ProximalGradientDescent
    constructors=map(m->getfield(m,symbol),mods)
    functions=map(m->getfield(m,:solve!),mods)
    for j in 1:2
        for _ in 1:4
            batch!(functions[j],prepare(problem,constructors[j],method,inner))
        end
        warm=@timed batch!(functions[j],prepare(problem,constructors[j],method,inner))
        diagnostics(problem,warm.value)
    end
    orders=vcat(fill((1,2,1),triplets÷2),fill((2,1,2),triplets÷2))
    shuffle!(Xoshiro(0xaba2026+n+p),orders)
    for (round,order) in enumerate(orders)
        GC.gc()
        for (position,j) in enumerate(order)
            measure!(io,problem,string(typeof(method).parameters[1]),method,inner,round,position,string(j),functions[j],constructors[j])
        end
    end
end
function run_session(label,roots,before,mods,output,trajectory)
    open(output,"w") do io
        println(io,"# label=",label," time_utc=",Dates.now(Dates.UTC))
        println(io,"# harness_digest=",bytes2hex(SHA.sha256(read(@__FILE__))))
        project_file=Base.active_project()
        println(io,"# environment_project=",project_file," project_digest=",bytes2hex(SHA.sha256(read(project_file))))
        manifest_file=joinpath(dirname(project_file),"Manifest.toml")
        isfile(manifest_file) && println(io,"# environment_manifest=",manifest_file," manifest_digest=",bytes2hex(SHA.sha256(read(manifest_file))))
        println(io,"# julia=",VERSION," cpu=",Sys.CPU_NAME," threads=",Threads.nthreads()," blas_threads=",BLAS.get_num_threads()," blas=",BLAS.get_config())
        println(io,"# source1=",roots[1]," digest=",before[1]," module=",mods[1])
        println(io,"# source2=",roots[2]," digest=",before[2]," module=",mods[2])
        println(io,"# PB_path=",pathof(ProximalBase)," PB_digest=",source_digest(dirname(pathof(ProximalBase)))," PB_SHA=e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291")
        println(io,"# setup_excluded=true; fresh_x/RNG; fixed_correlated_benchmark_fixture; homogeneous_types; defaults; balanced_random_ABA/BAB_triplets=12; four_warm_batches; GC_before_triplet; no_CPU_affinity")
        println(io,"type\tn\tp\tsolver\ttriplet\tposition\tmodule\tinner\tseconds\tbytes\tgc_seconds\titerations\tflags\tminimum\tminimum_bits\tresiduals\tf_calls\tgrad_calls\tprox_calls\tbacktrack_steps\tobjective64\tkkt64\tsum_x64\tnorm2_x64\tweighted_sum_x64\tnnz\tpoint_sha256\tpoint\tall_batch_points_identical")
        for T in (Float64,Float32),(n,p,inner) in ((128,32,20),(1024,256,5)),method in (Val(:CD),Val(:PGD))
            benchmark_case!(io,mods,T,n,p,inner,method)
        end
        final=source_digest.(roots)
        println(io,"# sources_unchanged=",final==before)
        final==before || error("source changed during measurement; reject results")
    end
    open(trajectory,"w") do io
        println(io,"type\tn\tp\tsolver\tmodule\tstep\tdiagnostics")
        for T in (Float64,Float32),(n,p) in ((128,32),(1024,256)),j in 1:2
            problem=fixture(T,n,p);ps=mods[j]
            method=getfield(ps,:ProximalGradientDescent)()
            state=getfield(ps,:initial_state)(method,getfield(ps,:ProximalOptions)(),problem.f,problem.g,copy(problem.x0))
            for step in 1:4
                getfield(ps,:update_state!)(problem.f,problem.g,state,method)
                payload=(repr(state.x),state.f_x,state.g_x,state.L,state.backtrack_simple,state.backtrack_steps,state.f_calls,state.grad_calls,state.prox_calls)
                println(io,join((T,n,p,"PGD",j,step,repr(payload)),'\t'))
            end
            for step in 1:4
                x=copy(problem.x0)
                cd=getfield(ps,:CDSolver)(maxpasses=step,rng=Xoshiro(0x2cd314))
                result=redirect_stderr(devnull) do
                    getfield(ps,:solve!)(x,problem.f,problem.g,cd)
                end
                println(io,join((T,n,p,"CD",j,step,repr(diagnostics(problem,result))),'\t'))
            end
        end
    end
end
function main()
    length(ARGS)==5 || error("usage: controlled.jl LABEL SRC1 SRC2 OUTPUT.tsv TRAJECTORY.tsv")
    label,src1,src2,output,trajectory=ARGS
    source_digest(dirname(pathof(ProximalBase))) == EXPECTED_PB_A_DIGEST || error("loaded PB source is not the independently verified A snapshot")
    roots=abspath.((src1,src2));before=source_digest.(roots)
    mods=(load_ps(:PSOldWrapper,roots[1]),load_ps(:PSComparedWrapper,roots[2]))
    before==source_digest.(roots) || error("source changed while loading")
    Base.invokelatest(run_session,label,roots,before,mods,output,trajectory)
end
main()
