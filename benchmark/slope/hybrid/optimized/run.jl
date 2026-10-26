using Libdl
include("../pilot.jl")
const PS = ProximalSolvers
const LIBRARY = get(ENV,"MATCH_LIBRARY",joinpath(pwd(),"libslope_plain.so"))
const ALLOC_LIBRARY = get(ENV,"MATCH_ALLOC_LIBRARY",joinpath(pwd(),"libslope_alloc.so"))

struct ObservedHybrid <: ProximalSolver
  inner::SLOPEHybrid
  workspace::Base.RefValue{Any}
end
Base.getproperty(m::ObservedHybrid,k::Symbol) = k in (:tol,:maxiter) ? getproperty(getfield(m,:inner),k) : getfield(m,k)
function PS._slope_workspace(X,y,m::ObservedHybrid)
  w=PS._slope_workspace(X,y,m.inner);m.workspace[]=w;w
end
PS._slope_inner!(x,f,g,m::ObservedHybrid,budget,target,w) = PS._slope_inner!(x,f,g,m.inner,budget,target,w)
PS.solve_path(f::ProximalBase.AbstractFunction,g::ProximalBase.SLOPE,a::AbstractVector{<:Real},m::ObservedHybrid;
              x=PS._slope_default_x(f),screening::Bool=true) = PS._slope_path(f,g,a,m;x,screening)

function cases()
  out=NamedTuple[]
  for seed in (1,2,3,11,12),rho in (0.,.99),storage in ("dense","sparse"),sparsity in (8,32),kind in ("linear","stepped"),depth in (6,12)
    push!(out,(;id=length(out)+1,cohort="original",seed,rho,storage,sparsity,kind,depth))
  end
  for seed in (1,2,3,11,12),rho in (0.,.9,.99),storage in ("dense","sparse"),kind in ("linear","stepped")
    push!(out,(;id=length(out)+1,cohort="larger",seed,rho,storage,sparsity=32,kind,depth=12))
  end
  out
end
function data(c)
  if c.cohort=="original"
    X,y=fixture(c.seed,c.rho,c.storage,c.sparsity)
  else
    rng=Xoshiro(959500+c.seed);n,p=600,1000
    A=zeros(n,p)
    if c.storage=="dense"
      randn!(rng,A)
      for j in 2:p
        @views A[:,j].=c.rho.*A[:,j-1].+sqrt(1-c.rho^2).*A[:,j]
      end
    else
      # Within-block predictors share row support, retaining strong correlation
      # rather than weakening it with independent per-column masks.
      for first in 1:10:p
        support=findall(rand(rng,n).<.05)
        anchor=randn(rng,length(support))
        for j in first:min(first+9,p)
          A[support,j].=sqrt(c.rho).*anchor.+sqrt(1-c.rho).*randn(rng,length(support))
        end
      end
    end
    beta=zeros(p);indices=randperm(rng,p)[1:c.sparsity]
    beta[indices].=repeat([2.,-2.,1.,-1.],cld(c.sparsity,4))[1:c.sparsity]
    y=A*beta+.3randn(rng,n)
    X=c.storage=="sparse" ? sparse(A) : A
  end
  p=size(X,2)
  weights=c.kind=="linear" ? collect(range(2.,.5;length=p)) : vcat(fill(2.,p÷3),fill(.8,p-p÷3))
  top=lambda_max(inv(length(y))*LeastSquaresLoss(y,X),ProximalBase.SLOPE(weights),zeros(p))
  grid=top.*exp.(range(0,log(.05);length=c.depth))
  (;X,y,weights,grid)
end

struct NativeInput{V}
  values::V
  outer::Vector{Cint}
  inner::Vector{Cint}
  sparse::Bool
  n::Int
  p::Int
end
NativeInput(X::Matrix) = NativeInput(vec(X),Cint[],Cint[],false,size(X)...)
NativeInput(X::SparseMatrixCSC) = NativeInput(nonzeros(X),Cint.(X.colptr.-1),Cint.(rowvals(X).-1),true,size(X)...)
const HANDLES = Dict{String,Ptr{Cvoid}}()
function native(d,input;counted=false)
  library=counted ? ALLOC_LIBRARY : LIBRARY
  handle=get!(HANDLES,library) do
    Libdl.dlopen(library)
  end
  fun=Libdl.dlsym(handle,:slope_matched)
  betas=fill(NaN,input.p,length(d.grid));passes=fill(Cint(-1),length(d.grid))
  returned=Ref{Cint}(0);bytes=Ref{UInt64}(0);calls=Ref{UInt64}(0);message=zeros(UInt8,4096)
  code=ccall(fun,Cint,(Ptr{Cdouble},Ptr{Cint},Ptr{Cint},Cint,Ptr{Cdouble},Ptr{Cdouble},Ptr{Cdouble},
    Cint,Cint,Cint,Cint,Cdouble,Cint,Cdouble,Ptr{Cdouble},Ptr{Cint},Ref{Cint},Ref{UInt64},Ref{UInt64},Ptr{UInt8},Cint),
    input.values,input.outer,input.inner,input.sparse ? length(input.values) : 0,d.y,d.weights,d.grid,
    input.n,input.p,length(d.grid),input.sparse,parse(Float64,get(ENV,"MATCH_NATIVE_TOL","1e-8")),20000,10.,betas,passes,returned,bytes,calls,message,length(message))
  code==0 || error(String(message[1:findfirst(iszero,message)-1]))
  (;solutions=[copy(betas[:,k]) for k in 1:returned[]],passes=Int.(passes[1:returned[]]),cpp_bytes=bytes[],cpp_calls=calls[])
end

function julia_fit(d,name)
  observed=ObservedHybrid(SLOPEHybrid(;tol=1e-8),Ref{Any}(nothing))
  method=name=="apg" ? SLOPEAPG(;tol=1e-8) : observed
  r=solve_path(inv(length(d.y))*LeastSquaresLoss(d.y,d.X),ProximalBase.SLOPE(d.weights),d.grid,method)
  stats=observed.workspace[]
  (;solutions=r.solutions,iterations=r.iterations,converged=r.converged,
    pg=stats===nothing ? -1 : stats.clusters.pg_steps,
    sweeps=stats===nothing ? 0 : stats.clusters.sweeps,
    fallbacks=stats===nothing ? 0 : stats.clusters.fallbacks)
end
function metrics(d,r)
  normalizer=max(1.,norm(d.X'*d.y/length(d.y),Inf))
  [begin
    gradient=d.X'*(d.X*x-d.y)/length(d.y)
    z=similar(x);prox!(z,ProximalBase.SLOPE(a.*d.weights),x-gradient,1.)
    residual=norm(x-z,Inf)/normalizer
    dual_gap=gap(d.X,d.y,x,a.*d.weights)
    (;dual_gap,residual,valid=isfinite(dual_gap)&&dual_gap<=1e-6&&isfinite(residual)&&residual<=1e-7)
  end for (a,x) in zip(d.grid,r.solutions)]
end
function warmup()
  for storage in ("dense","sparse")
    c=(;cohort="original",seed=0,rho=.9,storage,sparsity=8,kind="linear",depth=6)
    d=data(c);input=NativeInput(d.X)
    julia_fit(d,"apg");julia_fit(d,"hybrid");native(d,input);native(d,input;counted=true)
  end
  handle=HANDLES[ALLOC_LIBRARY]
  @test ccall(Libdl.dlsym(handle,:slope_allocation_probe),UInt64,())==422
end

function run_case(c,io,levels;rounds=3)
  d=data(c);input=NativeInput(d.X)
  original_X=copy(d.X);original_y=copy(d.y);original_weights=copy(d.weights);original_grid=copy(d.grid)
  rng=Xoshiro(9595000+c.id)
  for round in 1:rounds
    for name in shuffle(rng,["apg","hybrid","libslope"])
      GC.gc()
      status="ok";result=nothing;measured=nothing;cpp_bytes=UInt64(0);cpp_calls=UInt64(0)
      try
        measured=@timed name=="libslope" ? native(d,input) : julia_fit(d,name)
        result=measured.value
        if name=="libslope"
          counted=native(d,input;counted=true)
          cpp_bytes,cpp_calls=counted.cpp_bytes,counted.cpp_calls
          length(counted.solutions)==length(result.solutions) || error("native allocation replay changed path length")
          scale=max(1.,norm(d.y,Inf))
          all(norm(d.X*(a-b),Inf)<=1e-7*scale for (a,b) in zip(counted.solutions,result.solutions)) ||
            error("native allocation replay changed predictions beyond tolerance")
          all(m.valid for m in metrics(d,counted)) || error("native allocation replay missed common accuracy")
        end
        d.X==original_X && d.y==original_y && d.weights==original_weights && d.grid==original_grid ||
          error("a solver modified shared benchmark inputs")
      catch e
        status=replace(sprint(showerror,e),'\t'=>' ','\n'=>' ')
      end
      checked=result===nothing ? NamedTuple[] : metrics(d,result)
      valid=status=="ok"&&length(checked)==length(d.grid)&&all(m.valid for m in checked)
      converged=result===nothing ? 0 : name=="libslope" ? -1 : count(result.converged)
      row=(c.id,c.cohort,c.seed,c.rho,c.storage,c.sparsity,c.kind,c.depth,round,name,
        measured===nothing ? NaN : measured.time,measured===nothing ? -1 : measured.bytes,
        cpp_bytes,cpp_calls,length(checked),converged,valid,status,
        isempty(checked) ? Inf : maximum(m.dual_gap for m in checked),
        isempty(checked) ? Inf : maximum(m.residual for m in checked),
        result===nothing || name=="libslope" ? -1 : sum(result.iterations),
        result===nothing || name=="libslope" ? -1 : result.pg,
        result===nothing || name=="libslope" ? 0 : result.sweeps,
        result===nothing || name=="libslope" ? 0 : result.fallbacks)
      println(io,join(row,'\t'));flush(io)
      for (k,m) in enumerate(checked)
        println(levels,join((c.id,round,name,k,m.dual_gap,m.residual,m.valid),'\t'))
      end
      flush(levels)
    end
  end
end
function main_optimized()
  mode=ARGS[1];out=ARGS[2]
  warmup()
  selected=cases()
  if mode=="canary"
    selected=filter(c->c.seed==1 && c.kind=="stepped" && c.depth==12 && c.sparsity==32 &&
                      (c.cohort=="original" || c.rho in (0.,.99)),selected)
  else
    worker=parse(Int,ARGS[3]);workers=parse(Int,ARGS[4])
    selected=filter(c->mod(c.id-1,workers)+1==worker,selected)
  end
  open(out*".levels.tsv","w") do levels
    println(levels,"case\tround\tmethod\tlevel\tgap\tresidual\tcertified")
    open(out,"w") do io
      println(io,"case\tcohort\tseed\trho\tstorage\tsparsity\tweights\tdepth\tround\tmethod\tseconds\tjulia_bytes\tcpp_bytes\tcpp_calls\treturned\tconverged\tcertified\tstatus\tmax_gap\tmax_residual\titerations\tpg_steps\tcd_sweeps\tfallbacks")
      for c in selected
        run_case(c,io,levels;rounds=mode=="canary" ? 1 : 3)
      end
    end
  end
  open(out*".environment.toml","w") do io
    TOML.print(io,Dict("julia"=>string(VERSION),"cpu"=>Sys.CPU_NAME,
      "threads"=>Threads.nthreads(),"blas_threads"=>BLAS.get_num_threads(),
      "blas"=>sprint(show,BLAS.get_config()),"native_tolerance"=>parse(Float64,get(ENV,"MATCH_NATIVE_TOL","1e-8")),
      "native_source"=>"a9899cbf3677ea63236d54dc18626ad3a5aeddc6",
      "native_pass_budget"=>20000,"native_soft_path_limit_seconds"=>10,
      "julia_iteration_budget"=>10000,"julia_tolerance"=>1e-8,
      "acceptance_gap"=>1e-6,"acceptance_residual"=>1e-7,
      "job"=>get(ENV,"SLURM_JOB_ID","")))
  end
end
if abspath(PROGRAM_FILE) == @__FILE__
  main_optimized()
end
