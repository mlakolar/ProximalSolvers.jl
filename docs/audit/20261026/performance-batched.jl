using ProximalBase, ProximalSolvers, LinearAlgebra, Random, SparseArrays, InteractiveUtils
const PS=ProximalSolvers
BLAS.set_num_threads(1)
versioninfo(); @show BLAS.get_config() BLAS.get_num_threads() Threads.nthreads()
rng=Xoshiro(90210); n,p=120,40
X=randn(rng,n,p); y=X[:,1:4]*[1.,-.5,.7,.2]+.1randn(rng,n)
f=(1/n)*LeastSquaresLoss(y,X); g=NormL1(.05)
opt=ProximalOptions(maxiter=5000,ftol=1e-14,xtol=1e-14,gradtol=1e-9,gaptol=1e-8,gapevery=10)
function check(x,f,g)
 v=PS.duality_gap(f,g,x)
 grad=zeros(length(x)); gradient!(grad,f,x)
 fixed=maximum(abs.(x.-sign.(x.-grad).*max.(abs.(x.-grad).-g.λ0,0)))
 (v.primal,v.gap/max(abs(v.primal),eps()),fixed)
end
println("family\tseconds_min7\tbytes\titerations\tconverged\tobjective\trelative_gap\tfixedpoint")
for (label,ff,method) in (("PG",f,ProximalGradientDescent()),("APG",f,AccProxGradDescent()),("monotone",f,MonotoneAccProxGradDescent()),("active",f,ActiveAccProxGradDescent()),("CD",f,CDSolver(order=:cyclic,gaptol=1e-8)),("CSC-CD",(1/n)*LeastSquaresLoss(y,sparse(X)),CDSolver(order=:cyclic,gaptol=1e-8)),("ADMM",f,ADMMSolver(abstol=1e-10,reltol=1e-9)))
 runone()=method isa CDSolver ? solve!(zeros(p),ff,g,method) : solve!(zeros(p),ff,g,method,opt)
 cold=@timed runone()
 samples=[@timed(for _ in 1:100; runone(); end) for _ in 1:7]
 a=samples[argmin(getproperty.(samples,:time))]; r=runone()
 vals=check(r.minimizer,ff,g)
 println(join((label,a.time/100,a.bytes/100,(hasproperty(r,:inner_iterations) ? r.inner_iterations : PS.iterations(r)),r.converged,vals...),'\t'))
 println("COUNTS ",label," ",join((string(k)*"="*string(getproperty(r,k)) for k in (:f_calls,:grad_calls,:prox_calls,:backtrack_steps,:outer_iterations,:inner_iterations) if hasproperty(r,k))," "))
 println("first-use ",label," seconds=",cold.time," bytes=",cold.bytes)
end
println("stage\tbytes\tseconds_min7")
for method in (ProximalGradientDescent(),AccProxGradDescent(),MonotoneAccProxGradDescent())
 s=PS.initial_state(method,opt,f,g,zeros(p)); PS.update_state!(f,g,s,method)
 for (label,op) in (("construction",()->PS.initial_state(method,opt,f,g,zeros(p))),
                    ("iteration",()->PS.update_state!(f,g,s,method)),
                    ("stopping",()->PS.convergence_assessment(s,f,g,opt)),
                    ("gap",()->PS._relgap!(PS._gapevaluator(f,g,s.x),f,g,s.x)))
  op(); samples=[@timed(op()) for _ in 1:7]; a=samples[argmin(getproperty.(samples,:time))]
  println(join((nameof(typeof(method)),label,a.bytes,a.time),'\t'))
 end
end

# A regular convex GLM, without an artificial objective offset.
prob=1 ./ (1 .+ exp.(-X[:,1:3]*[1.,-.5,.7]))
yglm=Float64.(rand(Xoshiro(90212),n) .< prob)
fglm=(1/n)*LogisticLoss(yglm,X); gglm=NormL1(.03)
newton=ProxNewton(tol=1e-12,inner=CDSolver(tol=1e-10,order=:cyclic))
runnewton()=solve!(SparseIterate(p),fglm,gglm,newton)
runnewton(); samples=[@timed(for _ in 1:100;runnewton();end) for _ in 1:7]
a=samples[argmin(getproperty.(samples,:time))];r=runnewton();x=Vector(r.minimizer)
grad=X'*(1 ./ (1 .+ exp.(-X*x)) .- yglm)/n
fixed=maximum(abs.(x-sign.(x-grad).*max.(abs.(x-grad).-gglm.λ0,0)))
println("COUNTS GLM-Newton passes=",r.passes,"; evaluation counts unavailable in CDResults")
println(join(("GLM-Newton",a.time/100,a.bytes/100,(hasproperty(r,:inner_iterations) ? r.inner_iterations : PS.iterations(r)),r.converged,r.minimum,NaN,fixed),'\t'))
