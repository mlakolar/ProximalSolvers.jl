module CoreRegressions
using Test, LinearAlgebra, Random, ProximalBase, ProximalSolvers
using Logging: with_logger, Warn
const PS = ProximalSolvers

@testset "relative units, raw scale equivalence and read-only data" begin
  for T in (Float32, Float64), order in (:cyclic, :random)
    X, y = T[1 .2; -.3 1; .5 -.4; 1 1], T[1, -.4, .8, .2]
    s, λ = one(T) / T(4), T(.1)
    originalX, originaly = copy(X), copy(y)
    x = zeros(T, 2)
    r = solve!(x, s * LeastSquaresLoss(y, X), NormL1(λ),
               CDSolver(; order, rng = Xoshiro(88)))
    @test r.converged && X == originalX && y == originaly
    for q in (T(.01), T(10))
      z = zeros(T, 2)
      if T === Float32 && order === :cyclic && q === T(.01)
        # Matched historical/core probes reproduce a native plateau without
        # coverage and valid convergence with coverage instrumentation. Keep
        # the strict stopping and warning contracts for either outcome.
        logger = Test.TestLogger()
        r2 = with_logger(logger) do
          solve!(z, s*LeastSquaresLoss(q*y, q*X), NormL1(λ*q*q),
                 CDSolver(; order, rng = Xoshiro(88)))
        end
        if r2.converged
          @test 0 < r2.passes <= 100000 && r2.maxchange < r2.tolerance
          @test isempty(logger.logs)
        else
          @test r2.passes == 100000 && r2.maxchange >= r2.tolerance
          @test length(logger.logs) == 1 && only(logger.logs).level == Warn &&
                occursin(r"coordinate descent did not converge in maxpasses = 100000", string(only(logger.logs).message))
        end
      else
        r2 = solve!(z, s*LeastSquaresLoss(q*y, q*X), NormL1(λ*q*q), CDSolver(; order, rng = Xoshiro(88)))
        @test r2.converged
      end
      # Independent stationarity on the exact rounded, scaled input data.
      # Accuracy is bounded by the configured 1e-7 change stop (or native
      # precision), not Float64 machine epsilon at that practical stopping point.
      A, b = Float64.(q*X), Float64.(q*y)
      level = Float64(λ*q*q)
      d = Float64(s)*(A'*(A*Float64.(z)-b))
      @test maximum(abs.(d .+ level .* sign.(z))) <= max(1e-7, 100eps(T)) * max(level, norm(d, Inf))
      @test z ≈ x atol = 100eps(T)
      @test r2.minimum ≈ q * q * r.minimum rtol = 100eps(T)
    end
    z = zeros(T, 2)
    solve!(z, LeastSquaresLoss(y, X), NormL1(λ / s), CDSolver(; order, rng = Xoshiro(88)))
    @test z ≈ x atol = 100eps(T)
    xs = SparseIterate(T[.4, -.3])
    m = PS.cdmodel(s * LeastSquaresLoss(y, X), xs)
    PS.initialize!(m, xs)
    solver = CDSolver(rng = Xoshiro(18))
    state = PS._CDState(T, xs, solver)
    PS._cd!(xs, m, NormL1(λ), state, solver)
    @test state.converged
    @test m.r ≈ y - X * Vector(xs) atol = 100eps(T)
    @test PS.loss_value(m, xs) ≈ s * sum(abs2, y - X * Vector(xs)) / 2 rtol = 100eps(T)
    X[1, 1] *= 2
    PS.initialize!(m, xs)
    @test all(isnan, m.a)
    PS.coordinate_step!(m, NormL1(λ), xs, 1)
    @test m.a[1] ≈ sum(abs2, X[:, 1]) rtol = 8eps(T)
  end
end

@testset "accepted wider scalars and PGD data ownership" begin
  X, y = Float32[1 0; 0 2; 1 1], Float32[1, -1, .5]
  oldX, oldy = copy(X), copy(y)
  for method in (CDSolver(rng = Xoshiro(88)), ProximalGradientDescent())
    f, g = (1 / 3) * LeastSquaresLoss(y, X), NormL1(.1)
    x = zeros(Float32, 2)
    a = solve!(x, f, g, method)
    z = zeros(Float32, 2)
    b = solve!(z, f, g, method)
    @test a.minimum isa Float32 && b.minimum isa Float32
    @test x ≈ z atol = 100eps(Float32)
    @test X == oldX && y == oldy
    if method isa ProximalGradientDescent
      @test (a.iterations, a.f_calls, a.grad_calls, a.prox_calls) ==
            (b.iterations, b.f_calls, b.grad_calls, b.prox_calls)
    end
  end
end

@testset "retained dense primitives and result accessors" begin
  for T in (Float32, Float64)
    a, b = T[3, 4], T[0, 0]
    @test PS._norm(a) == T(5)
    @test PS._norm_diff(a, b, 2.) == T(5)
    @test PS._maxabs_axpy(T(2), T[1, -2], T[-1, 3]) == T(1)
    @test PS._maxabs_residual(T[3, 5], T[1, 2], T[1, 1], T(2)) == T(1)
    x = zeros(T, 1)
    r = solve!(x, LeastSquaresLoss(T[1], ones(T, 1, 1)), NormL1(T(.1)), ProximalGradientDescent())
    @test PS.minimizer(r) === x && PS.minimum(r) === r.minimum && PS.iterations(r) == r.iterations
    @test PS.converged(r) == r.converged && PS.f_calls(r) == r.f_calls
    @test PS.grad_calls(r) == r.grad_calls && PS.prox_calls(r) == r.prox_calls
    @test occursin("Algorithm", sprint(show, r))
  end
end
function direct_kkt(X,y,x,λ,scale)
  A,b,z=Float64.(X),Float64.(y),Float64.(x)
  d=Float64(scale)*(A'*(A*z-b))
  maximum(iszero(z[j]) ? max(abs(d[j])-Float64(λ),0.) : abs(d[j]+Float64(λ)*sign(z[j])) for j in eachindex(z))
end
@testset "ported exact power-of-two units and cold curvature scale" begin
  for T in (Float64,Float32)
    rng=Xoshiro(71)
    X=T.(randn(rng,16,7));y=T.(randn(rng,16));λ=T(.1);scale=one(T)/T(16)
    results=map((one(T),T(1024))) do c
      x=zeros(T,7)
      r=solve!(x,scale*LeastSquaresLoss(c*y,c*X),NormL1(c^2*λ),CDSolver(rng=Xoshiro(1)))
      x,r.passes
    end
    @test results[1]==results[2]
    xs=SparseIterate(zeros(T,7));m=PS.cdmodel(scale*LeastSquaresLoss(y,X),xs)
    PS.initialize!(m,xs)
    @test all(isnan,m.a)
    @test PS.coordinate_scale(m,xs,3)≈sqrt(scale*sum(abs2,X[:,3]))
    @test isfinite(m.a[3]) && all(isnan,m.a[[1,2,4,5,6,7]])
  end
end
@testset "ported FASTA-only stopping and native diagnostics" begin
  rng=Xoshiro(90);X=randn(rng,40,12);y=X*vcat([1.,-.5],zeros(10))+.1randn(rng,40)
  scale=1/40;λ=.1norm(scale*X'y,Inf)
  options=ProximalOptions(maxiter=5000,ftol=1e-300,xtol=1e-300,gradtol=1e-6)
  r=solve!(zeros(12),scale*LeastSquaresLoss(y,X),NormL1(λ),ProximalGradientDescent(),options)
  @test r.grad_converged && !r.iteration_converged
  @test r.g_residual<1e-5
  @test direct_kkt(X,y,r.minimizer,λ,scale)<1e-4
  r32=solve!(zeros(Float32,12),Float32(scale)*LeastSquaresLoss(Float32.(y),Float32.(X)),
              NormL1(Float32(λ)),ProximalGradientDescent())
  @test r32.x_residual isa Float64 && r32.f_residual isa Float64 && r32.g_residual isa Float64
end
@testset "ported natural backtracking switch keeps every gradient/image current" begin
  X=[1. 1 .2;2 1 .3;-1 0 .5;.1 1 1;.4 .3 -.8;-.2 .8 .1;.6 -.1 .2]
  y=[2.,1,-1,.4,-.5,.7,.9];scale=1/7
  f,g=scale*LeastSquaresLoss(y,X),NormL1(.1);method=ProximalGradientDescent()
  state=PS.initial_state(method,ProximalOptions(),f,g,zeros(3));modes=Bool[]
  for _ in 1:100
    PS.update_state!(f,g,state,method)
    push!(modes,state.backtrack_simple)
    @test state.z_x≈X*state.x atol=8eps()
    @test state.grad_f_x≈scale*(X'*(X*state.x-y)) atol=8eps()
  end
  @test any(modes) && !all(modes)
end
@testset "ported underdetermined lasso has independent planted optimum" begin
  for T in (Float64,Float32),initial in (:zero,:nonzero),momentum in (nothing,false)
    n,p=12,24;rng=Xoshiro(84)
    X=hcat(Matrix{T}(I,n,n),T(.1).*T.(randn(rng,n,p-n)))
    X[1,n+1:end].=clamp.(X[1,n+1:end],T(-.5),T(.5))
    scale=one(T)/T(n);λ=T(.1);y=zeros(T,n);y[1]=one(T)+λ/scale
    # X[:,1]=e1 and all other first entries are strictly below1: the point
    # with beta1=y1-lambda/scale and other entries0 satisfies all lasso KKT.
    reference=zeros(Float64,p);reference[1]=Float64(y[1])-Float64(λ)/Float64(scale)
    optimum=Float64(scale)*sum(abs2,Float64.(y)-Float64.(X)*reference)/2+Float64(λ)*sum(abs,reference)
    @test direct_kkt(X,y,reference,λ,scale)<1e-14
    x=initial===:zero ? zeros(T,p) : T.(range(-.1,.1,length=p))
    r=solve!(x,scale*LeastSquaresLoss(y,X),NormL1(λ),
      CDSolver(;rng=Xoshiro(91),momentum,tol=T===Float64 ? 1e-9 : 1e-5))
    @test r.converged
    @test direct_kkt(X,y,x,λ,scale)<(T===Float64 ? 1e-7 : 1e-4)
    actual=Float64(scale)*sum(abs2,Float64.(y)-Float64.(X)*Float64.(x))/2+Float64(λ)*sum(abs,Float64.(x))
    @test actual≈optimum atol=T===Float64 ? 1e-10 : 1e-5
  end
end
@testset "ported limits stop at their first complete-iteration crossing" begin
  X=[1. 1 .2;2 1 .3;-1 0 .5;.1 1 1;.4 .3 -.8;-.2 .8 .1;.6 -.1 .2]
  y=[2.,1,-1,.4,-.5,.7,.9];f,g=(1/7)*LeastSquaresLoss(y,X),NormL1(.1)
  for (keyword,index,limit) in ((:f_calls_limit,1,7),(:grad_calls_limit,2,4),(:prox_calls_limit,3,4))
    method=ProximalGradientDescent()
    state=PS.initial_state(method,ProximalOptions(),f,g,[.3,-.7,.2]);history=NTuple{3,Int}[]
    callback=_ -> (push!(history,(state.f_calls,state.grad_calls,state.prox_calls));false)
    options=ProximalOptions(;maxiter=100,ftol=1e-30,xtol=1e-30,gradtol=0.,callback,keyword=>limit)
    r=PS._solve_gradient!(state,f,g,method,options)
    @test history==[(4,2,2),(6,3,3),(8,4,4)]
    @test history[end-1][index]<limit<=history[end][index]
    @test r.call_limit_reached && !r.converged && r.iterations==3
    @test (r.f_calls,r.grad_calls,r.prox_calls)==history[end]
  end
end
end
