using Pkg, UUIDs, InteractiveUtils
mode, env = ARGS[1:2]
Pkg.activate(env)
if mode == "registry"
    Pkg.add(["ProximalSolvers","ProximalBase"])
elseif mode == "git"
    Pkg.add([PackageSpec(url="https://github.com/mlakolar/ProximalSolvers.jl.git",rev=ARGS[3]),
             PackageSpec(url="https://github.com/mlakolar/ProximalBase.jl.git",rev="4dc00b0772b67757bdad3d3933f85fee9e22822f")])
else
    try
        Pkg.add(PackageSpec(url="https://github.com/mlakolar/ProximalSolvers.jl.git",rev=ARGS[3]))
        error("candidate unexpectedly resolved without a development ProximalBase source")
    catch err
        msg = sprint(showerror,err)
        @assert occursin("ProximalBase",msg) && occursin("Unsatisfiable requirements",msg)
        println("EXPECTED_UNSUPPORTED_RELEASE_RESOLUTION\n",msg)
        exit(0)
    end
end
versioninfo()
using ProximalSolvers, ProximalBase, LinearAlgebra
for id in [UUID("fc4971f5-6616-4709-9bfc-89a819252f6b"),UUID("0a755509-c5b1-5d6f-9b24-59bcda3c37a3")]
    info=Pkg.dependencies()[id]
    @show info.name info.version info.tree_hash info.source info.git_revision info.git_source
end
x=zeros(2)
r=solve!(x,SqrNormL2(1.,[1.,-2.]),NormL1(.1),AccProxGradDescent(),
         ProximalOptions(maxiter=1000,ftol=1e-12,xtol=1e-12,gradtol=1e-10))
@assert ProximalSolvers.converged(r) && norm(x-[.9,-1.9],Inf)<1e-7
println("INSTALL_AND_INDEPENDENT_ORTHOGONAL_CHECK_PASS ",x)
if mode == "git"
    expected=[:OptimizationResults,:ActiveSetResults,:ADMMResults,:PrimalDualResults,:LineSearches,
              :initialize!,:coordinate_step!,:coordinate_derivatives,:update_cache!,:intercept,:deviance,:nulldeviance]
    @assert all(name->isdefined(ProximalSolvers,name),expected)
    if VERSION >= v"1.11.0-DEV.469"
        @assert all(name->Base.ispublic(ProximalSolvers,name),expected)
    end
    println("QUALIFIED_API_DISCOVERY_PASS")
end
