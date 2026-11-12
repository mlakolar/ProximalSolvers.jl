# Run under the root project, with one Julia/BLAS thread and clean frozen sources.
using ProximalBase, LinearAlgebra, Random, SHA, TOML
BLAS.set_num_threads(1)
const PB_REV = "c123d56ba1948e36a8fdbf183a9eea396a16e0d5"
const PB_DIGEST = "d5cfe6a35c4849ca2407f618eb1bf7359cf2eeadcc153e604a0866745b000364"
function digest(root)
  context = SHA.SHA2_256_CTX()
  paths = ["Project.toml"]
  for (dir, _, names) in walkdir(joinpath(root,"src")), name in names
    endswith(name,".jl") && push!(paths,relpath(joinpath(dir,name),root))
  end
  for path in sort!(paths)
    SHA.update!(context,codeunits(path*"\0"))
    SHA.update!(context,read(joinpath(root,path)))
    SHA.update!(context,UInt8[0])
  end
  bytes2hex(SHA.digest!(context))
end
function source_identity(root)
  isempty(readchomp(`git -C $root status --porcelain --untracked-files=no`)) || error("dirty source")
  pin=TOML.parsefile(joinpath(root,"Project.toml"))["sources"]["ProximalBase"]["rev"]
  pin==PB_REV || error("unexpected PB source pin")
  (readchomp(`git -C $root rev-parse HEAD`),digest(root))
end
function loadsource(name,root)
  wrapper=Module(name)
  Base.include(wrapper,joinpath(root,"src","ProximalSolvers.jl"))
  getfield(wrapper,:ProximalSolvers)
end
function fixture(::Type{T},n,p,occupancy) where T
  rng=Xoshiro(0x1731+n+p)
  X=T.(randn(rng,n,p))
  if p>=100000
    fill!(X,zero(T))
  end
  beta=zeros(T,p); beta[1:min(8,p)].=T.(range(1.,.2,length=min(8,p)))
  y=p>=100000 ? ones(T,n) : X*beta+T(.05).*T.(randn(rng,n))
  x=zeros(T,p)
  s=occupancy=="low" ? min(8,p) : p
  x[1:s].=T(.02)
  (;X,y,x,f=(one(T)/T(n))*LeastSquaresLoss(y,X),g=NormL1(T(.03)))
end
function diagnostics(result,problem)
  x=Float64.(Vector(result.minimizer)); X=Float64.(problem.X); y=Float64.(problem.y)
  scale=Float64(one(eltype(problem.X))/eltype(problem.X)(length(y)))
  lambda=Float64(problem.g.λ0); r=X*x-y; grad=scale*(X'*r)
  objective=scale*sum(abs2,r)/2+lambda*sum(abs,x)
  kkt=maximum(iszero(x[i]) ? max(abs(grad[i])-lambda,0.) : abs(grad[i]+lambda*sign(x[i])) for i in eachindex(x))
  @assert isfinite(objective) && isfinite(kkt)
  @assert isapprox(result.minimum,objective;rtol=100eps(eltype(problem.X)))
  @assert result.converged "bounded measurement fixture did not converge"
  bits=bytes2hex(sha256(reinterpret(UInt8,Vector(result.minimizer))))
  join((bits,bitstring(result.minimum),result.passes,result.converged,
        result.maxchange,result.tolerance,objective,kkt),';')
end
function prepare(problem,constructor,owner,inner)
  template=owner ? SparseIterate(problem.x) : problem.x
  [(copy(template),problem.f,problem.g,constructor(rng=Xoshiro(0x246),maxpasses=2000)) for _ in 1:inner]
end
function batch!(solve,works)
  result=solve(works[1]...)
  for i in 2:length(works)
    result=solve(works[i]...)
  end
  result
end
function timedsolve(solve,constructor,problem,owner,inner)
  works=prepare(problem,constructor,owner,inner)
  GC.gc()
  t=@timed batch!(solve,works)
  @assert all(w->isequal(Vector(w[1]),Vector(t.value.minimizer)),works)
  (t.time/inner,t.bytes/inner,diagnostics(t.value,problem))
end
function solvepair!(io,label,a,b,problem,inner,ownerb)
  for _ in 1:5
    timedsolve(a.solve!,a.CDSolver,problem,false,inner)
    timedsolve(b.solve!,b.CDSolver,problem,ownerb,inner)
  end
  T=eltype(problem.X); n,p=size(problem.X)
  occupancy=count(!iszero,problem.x)==p ? "full" : "low"
  for round in 1:30
    side_results=Dict{Int,Any}()
    for side in (isodd(round) ? (0,1) : (1,0))
      m=side==0 ? a : b
      samples=[timedsolve(m.solve!,m.CDSolver,problem,side==1 && ownerb,inner) for _ in 1:3]
      @assert all(v->v[3]==samples[1][3],samples)
      @assert all(v->v[2]==samples[1][2],samples)
      side_results[side]=(minimum(v[1] for v in samples),samples[1][2],samples[1][3])
      println(io,join((label,T,n,p,occupancy,round,side,side_results[side]...), '\t'));flush(io)
    end
    @assert side_results[0][3]==side_results[1][3]
  end
end
function ownerfixture(::Type{T},p,s) where T
  x=SparseIterate(T,p)
  for k in s:-1:1
    ProximalBase.activate!(x,k)
    x[k]=iszero(k%4) ? -zero(T) : T(.1)
  end
  x
end
function state(x)
  (ncoordinates(x),collect(activecoordinates(x)),collect(activevalues(x)))
end
function copycost!(io,::Type{T},p,old_s,new_s) where T
  src=ownerfixture(T,p,new_s); entry=ownerfixture(T,p,old_s)
  expected=state(src)
  for _ in 1:5
    out=copy(src); copyto!(out,src)
  end
  for round in 1:30, operation in (isodd(round) ? ("copy","copyto") : ("copyto","copy"))
    dest=copy(entry)
    GC.gc()
    t=operation=="copy" ? (@timed copy(src)) : (@timed copyto!(dest,src))
    @assert isequal(state(t.value),expected)
    println(io,join((operation,T,p,old_s,new_s,round,t.time,t.bytes),'\t'));flush(io)
  end
end
function runmeasurements(a,b,c,out)
  open(joinpath(out,"solve.tsv"),"w") do io
    println(io,"comparison\ttype\tn\tp\toccupancy\tround\tside\tseconds\tbytes\tdiagnostics")
    for T in (Float32,Float64), (n,p,inner) in ((128,32,20),(1024,256,5),(8,100000,1)), occ in ("low","full")
      problem=fixture(T,n,p,occ)
      solvepair!(io,"dense-base-head",a,b,problem,inner,false)
      solvepair!(io,"dense-head-control",b,c,problem,inner,false)
      solvepair!(io,"dense-owner",b,b,problem,inner,true)
    end
  end
  open(joinpath(out,"copy.tsv"),"w") do io
    println(io,"operation\ttype\tp\told_active\tnew_active\tround\tseconds\tbytes")
    for T in (Float32,Float64), p in (1000,100000,1000000), (old_s,new_s) in
        ((10,10),(p,10),(p÷8-1,p÷8-1),(p÷8,p÷8),(p,p))
      copycost!(io,T,p,old_s,new_s)
    end
  end
end
function main()
  length(ARGS)==3 || error("usage: measure.jl BASE_ROOT HEAD_ROOT NEW_OUTPUT_DIRECTORY")
  base,head,out=abspath.(ARGS)
  ispath(out) && error("output exists")
  mkpath(out)
  ids=source_identity.((base,head))
  pbroot=dirname(dirname(pathof(ProximalBase)))
  digest(pbroot)==PB_DIGEST || error("loaded PB source mismatch")
  a,b,c=loadsource(:Baseline,base),loadsource(:Candidate,head),loadsource(:Control,head)
  metadata=Dict("base_commit"=>ids[1][1],"head_commit"=>ids[2][1],
    "base_digest"=>ids[1][2],"head_digest"=>ids[2][2],"pb_commit"=>PB_REV,
    "pb_digest"=>digest(pbroot),"julia"=>string(VERSION),"cpu"=>Sys.CPU_NAME,
    "julia_threads"=>Threads.nthreads(),"blas_threads"=>BLAS.get_num_threads(),
    "load_start"=>collect(Sys.loadavg()),"repetitions"=>30,"batches_per_round"=>3,
    "harness_sha256"=>bytes2hex(sha256(read(@__FILE__))))
  Base.invokelatest(runmeasurements,a,b,c,out)
  source_identity.((base,head))==ids || error("source changed during measurement")
  metadata["load_end"]=collect(Sys.loadavg())
  open(joinpath(out,"metadata.toml"),"w") do io; TOML.print(io,metadata);end
  println("MEASUREMENTS_COMPLETE")
end
main()
