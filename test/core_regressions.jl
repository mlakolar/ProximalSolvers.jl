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

# ---- PGD backtracking: rejections checked by the computed curvature of the step ----

# Standardized Gaussian columns, five coefficients ±1, noise 0.2, loss scale 1/n and
# λ = 0.15 λ_max, in Float64.
function pgd_lasso_design(seed, n, p)
  rng = Xoshiro(seed)
  X = randn(rng, n, p)
  for j in 1:p
    @views X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
  end
  β = zeros(p)
  β[randperm(rng, p)[1:5]] .= rand(rng, (-1.0, 1.0), 5)
  y = X * β + 0.2randn(rng, n)
  s = 1 / n
  X, y, s, 0.15 * norm(s * X' * y, Inf)
end

# The relative duality gap (P - D)/|P| of the lasso s‖y - X x‖²/2 + λ‖x‖₁ in Float64, at the
# dual point s(y - X x) scaled into ‖X'θ‖∞ ≤ λ.
function pgd_relative_gap(X, y, s, λ, x)
  A, b, z = Float64.(X), Float64.(y), Float64.(x)
  r = b - A * z
  P = s * sum(abs2, r) / 2 + λ * sum(abs, z)
  θ = s .* r
  m = norm(A' * θ, Inf)
  m > λ && (θ .*= λ / m)
  max(P - (dot(b, θ) - sum(abs2, θ) / (2s)), 0.0) / abs(P)
end

# The largest accepted L over `iterations` calls of update_state! from x0
function pgd_run(f, g, x0, iterations; gradient_mode = false, method = ProximalGradientDescent())
  state = PS.initial_state(method, ProximalOptions(), f, g, copy(x0))
  gradient_mode && (state.backtrack_simple = false)
  Lmax = 0.0
  for _ in 1:iterations
    PS.update_state!(f, g, state, method)
    Lmax = max(Lmax, Float64(state.L))
  end
  state, Lmax
end

# m α ‖X d‖²/‖d‖² for the stored pair, in 512-bit BigFloat
pgd_exact_curvature(state, m) = setprecision(BigFloat, 512) do
  A = BigFloat.(state.model.X)
  d = BigFloat.(state.x) .- BigFloat.(state.x_previous)
  m * BigFloat(state.model.α) * sum(abs2, A * d) / sum(abs2, d)
end

# The first trial of an iteration from x0 at curvature L, as update_state! leaves it before
# backtrack!
function pgd_trial(f, g, x0, L; gradient_mode = false, method = ProximalGradientDescent())
  st = PS.initial_state(method, ProximalOptions(), f, g, copy(x0))
  st.backtrack_simple = !gradient_mode
  PS._copyto!(st.x_previous, st.x)
  st.f_x_previous, st.g_x_previous = st.f_x, st.g_x
  PS._copyto!(st.grad_f_x_previous, st.grad_f_x)
  st.L = L
  PS._step!(st.xhat, st.x_previous, st.grad_f_x_previous, st.L)
  st.g_x = convert(eltype(st.x), PS.value_and_prox!(st.x, g, st.xhat, one(L) / L))
  st.f_x = PS._value!(st.x, st.model, st.z_x)
  st
end

# A trial at the given point x from xprev at curvature L, with the stored values as
# update_state! leaves them before backtrack!
function pgd_pair_trial(f, g, xprev, x, L; method = ProximalGradientDescent())
  st = PS.initial_state(method, ProximalOptions(), f, g, copy(xprev))
  PS._copyto!(st.x_previous, st.x)
  st.f_x_previous, st.g_x_previous = st.f_x, st.g_x
  PS._copyto!(st.grad_f_x_previous, st.grad_f_x)
  st.L = L
  copyto!(st.x, x)
  st.g_x = convert(eltype(st.x), g(st.x))
  st.f_x = PS._value!(st.x, st.model, st.z_x)
  st
end

pgd_fixture() = ([1. 1 .2; 2 1 .3; -1 0 .5; .1 1 1; .4 .3 -.8; -.2 .8 .1; .6 -.1 .2],
                 [2., 1, -1, .4, -.5, .7, .9])

@testset "PGD Float32 function-value blowup is checked (n > p and p > n)" begin
  # Rounding of f(x) - q(x) dominates TFOCS's function-value estimate once ‖d‖ is small. Observed
  # on one machine at 782b74c: these designs reach L ≈ 4.2e6 and 1.4e6 and stall at gaps 2.6e-4
  # and 7.0e-4.
  # With the computed curvature c (at most about 2α‖X‖₂²), an accepted L stays below about
  # max(0.9, 4 α‖X‖₂²) on such data.
  T = Float32
  for (seed, n, p) in ((33, 100, 32), (37, 180, 600))
    X, y, s, λ = pgd_lasso_design(seed, n, p)
    X32, y32 = T.(X), T.(y)
    f, g = T(s) * LeastSquaresLoss(y32, X32), NormL1(T(λ))
    state, Lmax = pgd_run(f, g, zeros(T, p), 300)
    curvature = Float64(T(s)) * opnorm(Float64.(X32))^2
    @test Lmax <= max(0.9, 4.5curvature)
    @test pgd_relative_gap(X32, y32, Float64(T(s)), Float64(T(λ)), state.x) <= 1e-6
  end
end

@testset "PGD gradient-mode blowup with a residual orthogonal to range(X) is checked" begin
  # The gradient estimate subtracts two gradients whose rounding scales with |X|ᵀ|r|; with
  # gradient mode forced, 782b74c reached L up to thousands of times α‖X‖₂² on one machine.
  for T in (Float32, Float64), off in (1e2, 1e4), (n, p) in ((40, 10), (200, 50))
    rng = Xoshiro(284)
    X = randn(rng, n, p)
    β = zeros(p)
    β[1:3] .= (1, -1, 0.5)
    r0 = randn(rng, n)
    Q = Matrix(qr(X).Q)[:, 1:p]
    r0 -= Q * (Q' * r0)
    y = X * β + 0.1randn(rng, n) + off * r0 / norm(r0) * sqrt(n)
    s = 1 / n
    λ = 0.1 * norm(s * X' * y, Inf)
    f, g = T(s) * LeastSquaresLoss(T.(y), T.(X)), NormL1(T(λ))
    state, Lmax = pgd_run(f, g, zeros(T, p), 300; gradient_mode = true)
    @test Lmax <= 4.5 * Float64(T(s)) * opnorm(Float64.(T.(X)))^2
  end
end

@testset "PGD checked rejections: the computed curvature decides" begin
  X, y = pgd_fixture()
  scale = 1 / 7
  curvature = scale * opnorm(X)^2
  g = NormL1(.1)
  x0 = [.3, -.7, .2]
  method = ProximalGradientDescent()
  f = scale * LeastSquaresLoss(y, X)
  # A trial that TFOCS accepts is not checked.
  st = pgd_trial(f, g, x0, 2curvature)
  @test PS.LineSearches.backtrack!(st, method.ls, f, g) && st.verifications == 0
  # A rejection that rounding decided, simulated by lowering f(x'): L ≥ c, so the trial is
  # accepted in function-value mode, which it keeps; ∇f(x) is left to update_state!.
  st = pgd_trial(f, g, x0, 2curvature)
  st.f_x_previous -= 10
  counts = (st.f_calls, st.grad_calls, st.backtrack_steps)
  @test PS.LineSearches.backtrack!(st, method.ls, f, g)
  @test st.backtrack_simple && st.L == 2curvature && st.verifications == 1
  @test (st.f_calls, st.grad_calls, st.backtrack_steps) == counts .+ (0, 0, 1)
  # The same in gradient mode, with ∇f(x') shifted along d; c uses 2α.
  st = pgd_trial(f, g, x0, 4curvature; gradient_mode = true)
  st.grad_f_x_previous .-= 100 .* (st.x .- st.x_previous)
  counts = (st.f_calls, st.grad_calls, st.backtrack_steps)
  @test PS.LineSearches.backtrack!(st, method.ls, f, g)
  @test !st.backtrack_simple && st.L == 4curvature && st.verifications == 1
  @test (st.f_calls, st.grad_calls, st.backtrack_steps) == counts .+ (1, 1, 1)
  # A confirmed rejection with an inflated estimate sets L to c = m α ‖X d̂‖²/‖d̂‖², here
  # above L/β, against a 512-bit reference, in each mode.
  for (gradient_mode, m) in ((false, 1), (true, 2))
    st = pgd_trial(f, g, x0, curvature / 1e6; gradient_mode)
    gradient_mode ? (st.grad_f_x_previous .-= 100 .* (st.x .- st.x_previous)) : (st.f_x_previous -= 10)
    @test !PS.LineSearches.backtrack!(st, method.ls, f, g)
    c = pgd_exact_curvature(st, m)
    @test st.verifications == 1 && st.backtrack_simple == !gradient_mode
    @test abs(st.L - c) <= 1e-12 * c
  end
  # Float32: ‖X d̂‖² = (3e19)² overflows in Float32, while both values 0.5 (1.5e19)² are finite
  # and L̂ = Inf (⟨d, ∇f(x')⟩ overflows). Accumulated in Float64, c = 1e20, the curvature,
  # replaces L̂, below Lexact = 1e30.
  ls = PS.LineSearches.BackTracking(Lexact = 1e30)
  wide = ProximalGradientDescent(ls = ls)
  fb = LeastSquaresLoss(Float32[0], fill(1f10, 1, 1))
  st = pgd_trial(fb, NormL1(0f0), Float32[-1.5f9], 5f19; method = wide)
  @test isfinite(st.f_x) && !isfinite(sum(abs2, fill(1f10, 1, 1) * (st.x .- st.x_previous)))
  @test !PS.LineSearches.backtrack!(st, ls, fb, NormL1(0f0))
  @test st.L ≈ 1f20 rtol = 1e-6
  @test st.verifications == 1
  # Lexact: a trial at L ≥ Lexact is accepted unchecked; a rejection is capped by Lexact.
  ls = PS.LineSearches.BackTracking(Lexact = curvature / 1e4)
  capped = ProximalGradientDescent(ls = ls)
  st = pgd_trial(f, g, x0, curvature / 64; method = capped)
  st.f_x_previous -= 10
  @test PS.LineSearches.backtrack!(st, ls, f, g) && st.verifications == 0
  st = pgd_trial(f, g, x0, curvature / 1e6; method = capped)
  st.f_x_previous -= 10
  @test !PS.LineSearches.backtrack!(st, ls, f, g)
  @test st.L == curvature / 1e4 && st.verifications == 1
  # A zero step in each mode and a nonfinite trial are not checked.
  for gradient_mode in (false, true)
    st = pgd_trial(f, NormL1(1e3), zeros(3), curvature; gradient_mode)
    counts = (st.f_calls, st.grad_calls)
    @test PS.LineSearches.backtrack!(st, method.ls, f, NormL1(1e3))
    @test st.verifications == 0 && (st.f_calls, st.grad_calls) == counts .+ gradient_mode
  end
  st = pgd_trial(f, g, x0, curvature / 64)
  st.f_x = Inf
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g)
  @test st.L == curvature / 32 && st.verifications == 0
end

@testset "PGD Float32 computed curvature under over- and underflow" begin
  method = ProximalGradientDescent()
  g0 = NormL1(0f0)
  # ‖d̂‖² overflows Float32 although norm(d̂)² does not: in Float32 c = finite/Inf = 0 would
  # accept the trial at L = nextfloat(0f0); in Float64, c is the curvature, about 1.9e-40.
  d = Float32[-1.008728f19, -1.5444388f19]
  f = LeastSquaresLoss(Float32[0], reshape(Float32[-1f-20, -1f-20], 1, 2))
  st = pgd_pair_trial(f, g0, -d / 2, d / 2, nextfloat(0f0))
  @test isfinite(PS._norm(d)^2) && !isfinite(sum(abs2, d))
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g0)
  @test st.verifications == 1
  @test st.L ≈ pgd_exact_curvature(st, 1) rtol = 1e-4
  # ‖fl(X d̂)‖² = (1e-28)² underflows Float32: with loss scale 1e38 the curvature is about 1e18,
  # above L = 1e16, so the trial is rejected and L moves to about 1e18.
  f = 1f38 * LeastSquaresLoss(Float32[0], fill(1f-10, 1, 1))
  st = pgd_trial(f, g0, Float32[1f-20], 1f16)
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g0)
  @test st.verifications == 1
  @test st.L ≈ pgd_exact_curvature(st, 1) rtol = 1e-4
  # fl(X d̂) underflows to 0 although X d̂ = 5e-46 ≠ 0: with the underflow allowance c is
  # positive, at least the curvature 1e-22, and above L = 1e-30. TFOCS's rejection is forced by
  # lowering f(x').
  X = fill(1f-30, 1, 1)
  f = 1f38 * LeastSquaresLoss(Float32[0], X)
  st = pgd_pair_trial(f, g0, Float32[0], Float32[5f-16], 1f-30)
  st.f_x_previous -= 1
  @test X * Float32[5f-16] == Float32[0]
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g0)
  @test st.verifications == 1 && st.L >= pgd_exact_curvature(st, 1)
  # A zero-curvature direction at ordinary scales: X d̂ = 0 exactly, c is negligible, and the
  # trial is accepted with the mode unchanged.
  f = LeastSquaresLoss(Float32[1], Float32[1 1])
  st = pgd_pair_trial(f, g0, Float32[.5, .5], Float32[.75, .25], 1f0)
  st.f_x_previous -= 10
  @test Float32[1 1] * (st.x .- st.x_previous) == Float32[0]
  @test PS.LineSearches.backtrack!(st, method.ls, f, g0)
  @test st.verifications == 1 && st.backtrack_simple && st.L == 1f0
  # With subnormals flushed on this thread, BLAS can drop the subnormal operand a: fl(X d̂) is 0
  # (or 1e-30) although X d̂ ≈ 1.2e-28, and the curvature 4.7e-38 (4.8e-38) is above
  # L = floatmin(Float32). The check keeps TFOCS's estimate rather than accept on that product.
  # The rejection is forced by lowering f(x'); the mode is restored in every case.
  a = reinterpret(Float32, 0x007fffff)
  for (X, d) in ((fill(a, 1, 1), Float32[1f10]), (reshape(Float32[a, 1f-30], 1, 2), Float32[1f10, 1]))
    f = floatmax(Float32) * LeastSquaresLoss(Float32[0], X)
    st = pgd_pair_trial(f, g0, zeros(Float32, length(d)), d, floatmin(Float32))
    st.f_x_previous -= 1
    old = get_zero_subnormals()
    try
      if set_zero_subnormals(true)
        @test !PS.LineSearches.backtrack!(st, method.ls, f, g0)
        @test st.verifications == 1 && st.L > floatmin(Float32)
      else
        @info "set_zero_subnormals(true) is not available on this platform; flushed-operand check skipped"
      end
    finally
      set_zero_subnormals(old)
    end
    @test pgd_exact_curvature(st, 1) > floatmin(Float32)
  end
  # A subnormal entry of d̂ (here 1e-40), which a flushing thread could drop from the product:
  # the curvature is not used, and TFOCS's estimate sets L although L = 10 is above the
  # curvature along d̂.
  f = LeastSquaresLoss(Float32[0], Float32[1 0])
  st = pgd_pair_trial(f, g0, Float32[0, 0], Float32[1, 1f-40], 10f0)
  st.f_x_previous -= 10
  @test issubnormal(st.x[2])
  xy_sq = PS._norm(st.x .- st.x_previous)^2
  Lhat = st.L + 2. * max(st.f_x - (st.f_x_previous + 0.5 * st.L * xy_sq), 0f0) / xy_sq
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g0)
  @test st.verifications == 1 && st.L == Float32(Lhat)
  # An entry of fl(X d̂) overflows (1e30 · 1e10): c is not finite, so the check does not
  # accept the trial, and backtrack! keeps TFOCS's estimate (see the next testset). The step is
  # set directly, as backtrack! leaves it in delta_x.
  X = fill(1f30, 1, 1)
  f = LeastSquaresLoss(Float32[0], X)
  st = pgd_pair_trial(f, g0, Float32[0], Float32[0], 1f0)
  st.delta_x .= 1f10
  @test !all(isfinite, X * st.delta_x)
  accepted, c = PS.LineSearches.check_rejection!(st, false)
  @test !accepted && !isfinite(c) && c isa Float32 && st.verifications == 1
end

# A BLAS thread pool grown while subnormals were flushed, then the calling thread restored to
# gradual underflow: in a separate process (OpenBLAS starts with one thread), BLAS threads that
# flush subnormals compute rows 513:2048 of X d̂, whose operands are the subnormal
# reinterpret(Float32, 0x007fffff), and can return 0 for them; the curvature along d̂ is about
# 1.5e-31, above L = floatmin(Float32). The rejection is forced by lowering f(x').
const PGD_WORKER_SCRIPT = raw"""
using LinearAlgebra, ProximalBase, ProximalSolvers
const PS = ProximalSolvers
n = p = 2048
a = reinterpret(Float32, 0x007fffff)
X = zeros(Float32, n, p)
X[513:end, :] .= a
d = fill(1f10, p)
if !set_zero_subnormals(true)
  println("SKIP")
  exit(0)
end
BLAS.set_num_threads(4)
v = zeros(Float32, n)
mul!(v, X, d); mul!(v, X, d)
set_zero_subnormals(false)
mul!(v, X, d)
f, g = floatmax(Float32) * LeastSquaresLoss(zeros(Float32, n), X), NormL1(0f0)
method = ProximalGradientDescent()
st = PS.initial_state(method, ProximalOptions(), f, g, zeros(Float32, p))
copyto!(st.x_previous, st.x)
st.f_x_previous, st.g_x_previous = st.f_x - 1, st.g_x
copyto!(st.grad_f_x_previous, st.grad_f_x)
st.L = floatmin(Float32)
copyto!(st.x, d)
st.g_x = g(st.x)
st.f_x = PS._value!(st.x, st.model, st.z_x)
accepted = PS.LineSearches.backtrack!(st, method.ls, f, g)
println("RESULT accepted=", accepted, " verifications=", st.verifications, " lost=", all(iszero, v))
"""

@testset "PGD Float32 check with BLAS threads that flush subnormals" begin
  cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $PGD_WORKER_SCRIPT`
  out = readchomp(addenv(cmd, "OPENBLAS_NUM_THREADS" => "1", "JULIA_NUM_THREADS" => "1"))
  if out == "SKIP"
    @info "set_zero_subnormals(true) is not available on this platform; BLAS-thread check skipped"
  else
    m = match(r"RESULT accepted=(\w+) verifications=(\d+) lost=(\w+)", out)
    @test m !== nothing
    @test m[1] == "false" && m[2] == "1"
  end
end

@testset "PGD checked rejection before an unrepresentable curvature restores the accepted point" begin
  # 2α‖X d‖²/‖d‖² = 4.5e38 exceeds floatmax(Float32): the rejection at L ≈ 1.98e38 is checked,
  # c (4.5e38 in Float64) is Inf as a Float32, TFOCS's estimate is kept, and next_curvature
  # raises; the engine restores x.
  f = LeastSquaresLoss(Float32[1], fill(1.5f19, 1, 1))
  method = ProximalGradientDescent()
  state = PS.initial_state(method, ProximalOptions(), f, NormL1(0f0), Float32[0])
  state.backtrack_simple = false
  state.L = 2.2f38
  @test_throws r"curvature estimate cannot increase finitely" PS._solve_gradient!(state, f, NormL1(0f0), method, ProximalOptions())
  @test state.x == Float32[0] && state.verifications == 1
end

@testset "PGD rejections with an infinite estimate: nonfinite gradient kept, tiny step checked" begin
  # Gradient mode: at L ≈ 1e21 the trial's value 0.5(1e19 - 1)² is finite but ∇f(x) = 1e20 (1e19 - 1)
  # overflows Float32, so L̂ = Inf. The rejection is not checked and raises as before (Lexact = Inf).
  f = LeastSquaresLoss(Float32[1], fill(1f20, 1, 1))
  method = ProximalGradientDescent()
  state = PS.initial_state(method, ProximalOptions(), f, NormL1(0f0), Float32[0])
  state.backtrack_simple = false
  state.L = 1f21 / 0.9f0
  @test_throws r"nonfinite curvature estimate" PS._solve_gradient!(state, f, NormL1(0f0), method, ProximalOptions())
  @test state.x == Float32[0] && state.verifications == 0
  @test isfinite(state.f_x) && !all(isfinite, state.grad_f_x)
  # Function-value mode: a step of norm about 1e-157 has ‖d̂‖² subnormal, and a value gap of 10
  # divided by it overflows to L̂ = Inf. The rejection is checked: L ≈ 1e157 is far above c,
  # so the trial is accepted, and L stays finite.
  X, y = pgd_fixture()
  f = (1 / 7) * LeastSquaresLoss(y, X)
  st = pgd_trial(f, NormL1(0.), zeros(3), 1e157)
  st.f_x_previous -= 10
  xy_sq = PS._norm(st.x .- st.x_previous)^2
  @test 0 < xy_sq && !isfinite(st.L + 2 * 10 / xy_sq)
  @test PS.LineSearches.backtrack!(st, method.ls, f, NormL1(0.))
  @test st.verifications == 1 && st.L == 1e157 && st.backtrack_simple
end

@testset "PGD end to end under the strict ftol = 0 settings" begin
  # solve! with ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11 on the
  # Float32 design above. Float32 reaches its floating-point fixed point. At an unchanged
  # iterate the computed x and gradient tests can hold, but the exact-stall rule of ftol = 0
  # does not count them. On this design the solve ends before maxiter at the stagnation stop
  # (an unchanged iterate in an iteration whose last rejection was decided by its computed
  # curvature, #308): stagnated = true, converged = false. The independent gap checks the
  # accuracy. Float64 stops on the gradient test.
  X, y, s, λ = pgd_lasso_design(33, 100, 32)
  for (T, maxiter) in ((Float32, 300), (Float64, 2000))
    A, b = T.(X), T.(y)
    f, g = T(s) * LeastSquaresLoss(b, A), NormL1(T(λ))
    options = ProximalOptions(ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11, maxiter = maxiter)
    x = zeros(T, 32)
    r = solve!(x, f, g, ProximalGradientDescent(), options)
    gap = pgd_relative_gap(A, b, Float64(T(s)), Float64(T(λ)), x)
    if T === Float32
      @test gap <= 1e-6
      @test r.stagnated && !r.converged && r.iterations < maxiter && !r.iteration_converged
      @test !r.x_converged && !r.grad_converged && !r.f_converged && !r.f_increased
      @test r.x_residual == 0 && r.g_residual == 0
    else
      @test gap <= 1e-9
      @test r.converged && r.grad_converged && !r.x_converged && !r.f_converged
      @test r.iterations < maxiter && !r.stagnated
    end
  end
end

# ---- Float32 PGD stops at numerical stagnation under ftol = 0 (#308) --------------------------
# The stop: an unchanged accepted iterate in an iteration whose last rejection was decided by its
# computed curvature. The designs below are seeded constructions in Float64, converted to Float32.

# AR(1) Gaussian columns (correlation ρ between neighbours), each scaled to squared norm n
function pgd_ar_design(rng, n, p, ρ)
  X = randn(rng, n, p)
  for j in 2:p
    @views X[:, j] .= ρ .* X[:, j-1] .+ sqrt(1 - ρ^2) .* X[:, j]
  end
  for j in 1:p
    @views X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
  end
  X
end

# The design above with coefficients β (standard normal if not given), noise level `noise`, loss
# scale 1/n and λ = frac λ_max; returns X, y, s, λ
function pgd_ar_problem(seed, n, p, ρ, noise, frac; β = nothing)
  rng = Xoshiro(seed)
  X = pgd_ar_design(rng, n, p, ρ)
  β === nothing && (β = randn(rng, p))
  y = X * β + noise * randn(rng, n)
  s = 1 / n
  X, y, s, frac * norm(s * X' * y, Inf)
end

# Benchmark-like: n = 240, p = 160, ρ = 0.8, five coefficients ±1, noise 0.2, λ = 0.15 λ_max
function pgd_bench_problem(seed)
  rng = Xoshiro(1000 + seed)
  β = zeros(160)
  β[randperm(rng, 160)[1:5]] .= rand(rng, (-1.0, 1.0), 5)
  pgd_ar_problem(seed, 240, 160, 0.8, 0.2, 0.15; β)
end

pgd_strict(maxiter; kwargs...) =
  ProximalOptions(; ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11, maxiter, kwargs...)

# Solves in element type T from x0 under the strict settings; returns the result, the iterate and
# the independent relative gap in Float64
function pgd_strict_solve(::Type{T}, X, y, s, λ, x0, maxiter; method = ProximalGradientDescent(), kwargs...) where T
  A, b = T.(X), T.(y)
  f, g = T(s) * LeastSquaresLoss(b, A), NormL1(T(λ))
  x = T.(x0)
  r = solve!(x, f, g, method, pgd_strict(maxiter; kwargs...))
  r, x, pgd_relative_gap(A, b, Float64(T(s)), Float64(T(λ)), x)
end

# As pgd_strict_solve in Float32 with PGD, with a callback that records the first iteration at which
# the caller's x (the solver iterates in it) differs from x0 and the first at which its independent
# relative gap is at most `target` (0 if none)
function pgd_recording_solve(X, y, s, λ, x0, maxiter; target = 1e-5)
  A, b = Float32.(X), Float32.(y)
  A64, b64 = Float64.(A), Float64.(b)
  s64, λ64 = Float64(Float32(s)), Float64(Float32(λ))
  f, g = Float32(s) * LeastSquaresLoss(b, A), NormL1(Float32(λ))
  x = Float32.(x0)
  start = copy(x)
  k = first_change = first_target = 0
  callback = _ -> begin
    k += 1
    first_change == 0 && x != start && (first_change = k)
    first_target == 0 && pgd_relative_gap(A64, b64, s64, λ64, x) <= target && (first_target = k)
    false
  end
  r = solve!(x, f, g, ProximalGradientDescent(), pgd_strict(maxiter; callback))
  (; r, x, gap = pgd_relative_gap(A64, b64, s64, λ64, x), first_change, first_target)
end

# What a stagnation stop reports: no stopping test holds, and neither a limit nor an increase ended it
pgd_stagnation_signature(r) = r.stagnated && !r.converged && !r.x_converged && !r.f_converged &&
  !r.grad_converged && !r.f_increased && !r.call_limit_reached && !r.iteration_converged &&
  r.x_residual == 0 && r.g_residual == 0

@testset "PGD Float32 strict: repeated exact stalls end in a stagnation stop (#308)" begin
  problems = Any[pgd_lasso_design(seed, 100, 32) for seed in (33, 34, 35)]
  append!(problems, Any[pgd_bench_problem(seed) for seed in (1, 2)])
  for (X, y, s, λ) in problems
    r, x, gap = pgd_strict_solve(Float32, X, y, s, λ, zeros(size(X, 2)), 10_000)
    @test pgd_stagnation_signature(r)
    @test r.iterations < 1_000
    @test gap <= 1e-5
    @test PS.stagnated(r) && occursin("\n   * Stopped at numerical stagnation: true\n", sprint(show, r))
  end
end

@testset "PGD Float32 strict: an inflated initial curvature does not stop the solve during the initial stalls (#308)" begin
  # X and y scaled by c = 1e-6 (λ by c², the same minimizer up to the scale), start at ones: the
  # first L = 1 is far above the curvature of the problem, so the steps round to zero until L has
  # fallen. Those iterations are exact stalls without a rejection and must not stop the solve
  # (a rule that counts stalls stops here with a gap near 1).
  c = 1e-6
  for seed in (33, 34, 35)
    X, y, s, λ = pgd_lasso_design(seed, 100, 32)
    o = pgd_recording_solve(c .* X, c .* y, s, c^2 * λ, ones(32), 2000)
    @test o.first_change >= 40
    @test o.first_change < o.first_target
    @test 0 < o.first_target <= o.r.iterations
    @test pgd_stagnation_signature(o.r) && o.gap <= 1e-5
  end
end

@testset "PGD Float32 strict: a slowly converging correlated design stops only after meeting the target (#308)" begin
  β = zeros(100)
  β[[3, 30, 60, 90]] .= (2, -1, 1.5, -2)
  stagnated = Bool[]
  for seed in (1, 2, 3)
    X, y, s, λ = pgd_ar_problem(seed, 200, 100, 0.99, 0.1, 0.02; β)
    o = pgd_recording_solve(X, y, s, λ, zeros(100), 30_000)
    @test o.gap <= 1e-5 && !o.r.converged
    @test 0 < o.first_target < o.r.iterations
    push!(stagnated, o.r.stagnated)
    o.r.stagnated && @test pgd_stagnation_signature(o.r)
  end
  @test any(stagnated)
end

@testset "PGD Float32 strict: an exact optimum runs to maxiter without a stagnation stop (#308)" begin
  # λ = 1.5 λ_max from 0: every step is soft thresholded to 0, so nothing is ever rejected
  X, y, s, _ = pgd_lasso_design(33, 100, 32)
  r, x, gap = pgd_strict_solve(Float32, X, y, s, 1.5 * norm(s * X' * y, Inf), zeros(32), 300)
  @test r.iterations == 300 && r.iteration_converged
  @test !r.converged && !r.stagnated
  @test all(iszero, x)
end

@testset "PGD Float32 strict: a stall above the Float32 floor is never reported as convergence (#308)" begin
  # near interpolation (noise 1e-3, λ = 1e-4 λ_max) the Float32 floor of the gap is above the 1e-5
  # target; some of the draws stagnate exactly, the others keep moving by rounding error
  stagnated = 0
  for seed in 1:24
    X, y, s, λ = pgd_ar_problem(seed, 100, 32, 0.5, 1e-3, 1e-4)
    r, x, gap = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000)
    @test gap > 1e-5
    @test !r.converged
    if r.stagnated
      stagnated += 1
      @test pgd_stagnation_signature(r)
    else
      @test r.iterations == 10_000 && r.iteration_converged
    end
  end
  @test stagnated >= 2
end

@testset "PGD stagnation flag: set by a checked rejection, cleared by an unverified one and at the start of an iteration (#308)" begin
  X, y = pgd_fixture()
  scale = 1 / 7
  curvature = scale * opnorm(X)^2
  g = NormL1(.1)
  x0 = [.3, -.7, .2]
  method = ProximalGradientDescent()
  f = scale * LeastSquaresLoss(y, X)
  @test !PS.initial_state(method, ProximalOptions(), f, g, copy(x0)).verified_rejection
  # a rejection decided by a finite computed curvature sets it, in each mode
  for gradient_mode in (false, true)
    st = pgd_trial(f, g, x0, curvature / 1e6; gradient_mode)
    gradient_mode ? (st.grad_f_x_previous .-= 100 .* (st.x .- st.x_previous)) : (st.f_x_previous -= 10)
    @test !st.verified_rejection
    @test !PS.LineSearches.backtrack!(st, method.ls, f, g)
    @test st.verified_rejection && st.verifications == 1
  end
  # a nonfinite trial value clears it
  st = pgd_trial(f, g, x0, curvature / 64)
  st.f_x = Inf
  st.verified_rejection = true
  @test !PS.LineSearches.backtrack!(st, method.ls, f, g)
  @test !st.verified_rejection && st.verifications == 0
  # a rejection that is checked but whose computed curvature is not finite leaves it false: d̂ has a
  # subnormal entry, so the Float32 curvature is not used and TFOCS's estimate is kept
  f32 = Float32(scale) * LeastSquaresLoss(Float32.(y), Float32.(X))
  st = pgd_pair_trial(f32, NormL1(0f0), zeros(Float32, 3), Float32[1f-3, 1f-40, 0], 1f-3)
  st.f_x_previous -= 10f0
  st.verified_rejection = true
  @test issubnormal(st.x[2])
  @test !PS.LineSearches.backtrack!(st, method.ls, f32, NormL1(0f0))
  @test st.verifications == 1 && !st.verified_rejection && isfinite(st.L) && st.L > 1f-3
  # a zero step does not touch it, so a rejection of the same iteration is still recorded
  st = pgd_trial(f, NormL1(1e3), zeros(3), curvature)
  st.verified_rejection = true
  @test PS.LineSearches.backtrack!(st, method.ls, f, NormL1(1e3))
  @test st.verified_rejection
  # update_state! starts from false: its first trial is accepted, or is a zero step
  for (x, penalty, L) in ((x0, g, 100.0), (zeros(3), NormL1(1e3), 1.0))
    st = PS.initial_state(method, ProximalOptions(), f, penalty, copy(x))
    st.L = L
    st.verified_rejection = true
    PS.update_state!(f, penalty, st, method)
    @test !st.verified_rejection && st.verifications == 0
  end
end

@testset "PGD stagnation test: Float32 PGD with ftol = 0, an unchanged iterate and a verified rejection (#308)" begin
  X, y = pgd_fixture()
  method = ProximalGradientDescent()
  stagnation(T, options; unchanged = true, verified = true) = begin
    f = T(1 / 7) * LeastSquaresLoss(T.(y), T.(X))
    st = PS.initial_state(method, options, f, NormL1(T(.1)), T[.3, -.7, .2])
    unchanged && PS._copyto!(st.x_previous, st.x)
    unchanged || PS._copyto!(st.x_previous, st.x .+ T(.01))
    st.verified_rejection = verified
    PS._stagnated(st, options)
  end
  strict = ProximalOptions(ftol = 0)
  @test stagnation(Float32, strict)
  # each condition is needed
  @test !stagnation(Float32, strict; verified = false)
  @test !stagnation(Float32, strict; unchanged = false)
  @test !stagnation(Float32, ProximalOptions(ftol = 1e-15))
  @test !stagnation(Float32, ProximalOptions(ftol = 1e-300))
  # a single changed entry is a changed iterate
  f32 = Float32(1 / 7) * LeastSquaresLoss(Float32.(y), Float32.(X))
  st = PS.initial_state(method, strict, f32, NormL1(.1f0), Float32[.3, -.7, .2])
  PS._copyto!(st.x_previous, st.x)
  st.verified_rejection = true
  st.x[3] = nextfloat(st.x[3])
  @test !PS._stagnated(st, strict)
  # Float64 PGD and APG never stagnate
  @test !stagnation(Float64, strict)
  f = (1 / 7) * LeastSquaresLoss(y, X)
  apg = PS.initial_state(AccProxGradDescent(), strict, f, NormL1(.1), [.3, -.7, .2])
  @test !PS._stagnated(apg, strict)
end

@testset "PGD stagnation stop: Float64, APG and ftol > 0 are unchanged, callbacks and limits keep their meaning (#308)" begin
  designs = Any[pgd_lasso_design(seed, 100, 32) for seed in (33, 34, 35)]
  push!(designs, pgd_bench_problem(1))
  # Float64 strict ends on the gradient test, on the designs of the stalls and of the inflated curvature
  for (X, y, s, λ) in designs
    r, x, gap = pgd_strict_solve(Float64, X, y, s, λ, zeros(size(X, 2)), 10_000)
    @test !r.stagnated && r.converged && r.grad_converged && gap <= 1e-9
  end
  c = 1e-6
  X, y, s, λ = pgd_lasso_design(33, 100, 32)
  r, x, gap = pgd_strict_solve(Float64, c .* X, c .* y, s, c^2 * λ, ones(32), 2000)
  @test !r.stagnated && r.converged && gap <= 1e-5
  # Float32 with ftol > 0: the default options end on a stopping test, and an exact stall (the first
  # iterations of the inflated curvature) ends the solve through the x test, as before
  for (X, y, s, λ) in designs[1:3]
    A, b = Float32.(X), Float32.(y)
    f, g = Float32(s) * LeastSquaresLoss(b, A), NormL1(Float32(λ))
    r = solve!(zeros(Float32, size(X, 2)), f, g, ProximalGradientDescent())
    @test !r.stagnated && !r.iteration_converged && (r.converged || r.f_increased)
  end
  A, b = Float32.(c .* X), Float32.(c .* y)
  r = solve!(ones(Float32, 32), Float32(s) * LeastSquaresLoss(b, A), NormL1(Float32(c^2 * λ)), ProximalGradientDescent(),
             ProximalOptions(ftol = 1e-15, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11, maxiter = 2000))
  @test !r.stagnated && r.converged && r.x_converged && r.iterations < 10
  # APG under the strict settings
  X, y, s, λ = designs[1]
  r, x, gap = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 2000; method = AccProxGradDescent())
  @test !r.stagnated && gap <= 1e-5
  @test occursin("\n   * Stopped at numerical stagnation: false\n", sprint(show, r))
  # the callback sees the stopping iteration, and can still stop the solve there or earlier
  X, y, s, λ = designs[1]
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000)
  K = r.iterations
  @test r.stagnated && K > 3
  calls = 0
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000; callback = _ -> (calls += 1; false))
  @test r.stagnated && r.iterations == K && calls == K
  calls = 0
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000; callback = _ -> (calls += 1; calls == K))
  @test r.stagnated && r.iterations == K
  calls = 0
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000; callback = _ -> (calls += 1; calls == K - 3))
  @test !r.stagnated && r.iterations == K - 3
  # a call limit reached before the stagnation stop is reported as such; when both hold at the same
  # iteration, each flag reports its own condition
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000)
  fcalls = r.f_calls
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000; f_calls_limit = 10)
  @test r.call_limit_reached && !r.stagnated && r.iterations < K
  r, _ = pgd_strict_solve(Float32, X, y, s, λ, zeros(32), 10_000; f_calls_limit = fcalls)
  @test r.call_limit_reached && r.stagnated && r.iterations == K
end

alloc_pgd_stagnation_step(st, f, g, method, options) = @allocated begin
  PS.update_state!(f, g, st, method)
  PS._stagnated(st, options)
end
@testset "PGD: a warmed iteration with the stagnation test allocates nothing (#308)" begin
  X, y, s, λ = pgd_lasso_design(33, 100, 32)
  f, g = Float32(s) * LeastSquaresLoss(Float32.(y), Float32.(X)), NormL1(Float32(λ))
  method, options = ProximalGradientDescent(), pgd_strict(100)
  st = PS.initial_state(method, options, f, g, zeros(Float32, 32))
  alloc_pgd_stagnation_step(st, f, g, method, options)
  for _ in 1:3
    @test alloc_pgd_stagnation_step(st, f, g, method, options) == 0
  end
end

# ---- ftol = 0 switches off objective-change stopping (#270) ----------------------------------
# convergence_assessment of a constructed state: the solver's own initial_state, then the fields
# that the assessment reads are set. F = f_x + g_x with g_x = 0; xtol = 1e-8, gradtol = 1e-11.
function pgd_assessment(T, ftol; x, previous, F, F_previous, delta = x .- previous,
                        grad = zeros(T, length(x)), grad_previous = grad, L = one(T))
  f, g = LeastSquaresLoss(T[1, -1], T[1 0; 0 2]), NormL1(T(.1))
  options = ProximalOptions(; ftol, xtol = 1e-8, gradtol = 1e-11)
  state = PS.initial_state(ProximalGradientDescent(), options, f, g, T[.3, -.2])
  state.x .= x
  state.x_previous .= previous
  state.delta_x .= delta
  state.f_x, state.g_x = T(F), zero(T)
  state.f_x_previous, state.g_x_previous = T(F_previous), zero(T)
  state.grad_f_x .= grad
  state.grad_f_x_previous .= grad_previous
  state.L = L
  (; flags = PS.convergence_assessment(state, f, g, options), state, f, g, options)
end

@testset "PGD: ftol = 0 switches off the objective test; ftol > 0 keeps its flags (#270)" begin
  for T in (Float64, Float32)
    x, F = T[1, 2], T(3) / 2
    moved = x .+ T(.01)                      # an accepted step that changed x
    zeros2, ones2 = zeros(T, 2), ones(T, 2)  # equal gradients, or gradients far apart
    tiny = nextfloat(zero(T))
    flat = (false, false, false, false, false)
    # label, state, then the flags (x_converged, f_converged, grad_converged, converged,
    # f_increased) for ftol = 1e-15, 1e-300 and 0
    cases = [
      ("F == F'", (previous = moved, F = F, F_previous = F, grad = ones2, grad_previous = zeros2),
       (false, true, false, true, false), (false, true, false, true, false), flat),
      ("F' = nextfloat(F): one ulp", (previous = moved, F = F, F_previous = nextfloat(F), grad = ones2, grad_previous = zeros2),
       (false, true, false, true, false), (false, true, false, true, false), flat),
      # 3 ulps: the relative test holds for 1e-15 in Float64 only, and 1e-300 leaves no test
      ("F' = F + 3eps(F)", (previous = moved, F = F, F_previous = F + 3eps(F), grad = ones2, grad_previous = zeros2),
       (false, T === Float64, false, T === Float64, false), flat, flat),
      ("F = nextfloat(F'): an increase of one ulp", (previous = moved, F = F, F_previous = prevfloat(F), grad = ones2, grad_previous = zeros2),
       (false, true, false, true, true), (false, true, false, true, true), (false, false, false, false, true)),
      ("F = F' + 1/2: a large increase", (previous = moved, F = F, F_previous = F - T(1) / 2, grad = ones2, grad_previous = zeros2),
       (false, false, false, false, true), (false, false, false, false, true), (false, false, false, false, true)),
      ("x == x_previous, equal gradients", (previous = x, F = F, F_previous = F + 1, grad = zeros2),
       (true, false, true, true, false), (true, false, true, true, false), flat),
      ("x == x_previous with -0.0 against 0.0", (x = T[0, 2], previous = T[-0.0, 2], F = F, F_previous = F + 1, grad = zeros2),
       (true, false, true, true, false), (true, false, true, true, false), flat),
      ("x == x_previous, different gradients", (previous = x, F = F, F_previous = F + 1, grad = T[1, 1.5], grad_previous = T[.5, 1]),
       (true, false, false, true, false), (true, false, false, true, false), flat),
      # x != x_previous while the norm of delta_x is 0: not a stall, evaluated as with ftol > 0
      ("x != x_previous, delta_x = 0", (previous = moved, delta = zeros2, F = F, F_previous = F + 1, grad = zeros2),
       (true, false, true, true, false), (true, false, true, true, false), (true, false, true, true, false)),
      # a subnormal difference (this row assumes IEEE gradual underflow in the comparison of the iterates):
      # x != x_previous, so the flags are those of ftol > 0 whichever way the computed norm comes out
      ("x != x_previous, a subnormal difference", (x = T[1, 0], previous = T[1, tiny], F = F, F_previous = F + 1, grad = zeros2),
       (true, false, true, true, false), (true, false, true, true, false), (true, false, true, true, false)),
    ]
    for (label, state, e15, e300, e0) in cases, (ftol, expected) in ((1e-15, e15), (1e-300, e300), (0, e0))
      a = pgd_assessment(T, ftol; merge((; x), state)...)
      @test (label, T, ftol, a.flags) == (label, T, ftol, expected)
    end
    # gradient_converged! still runs on an unchanged iterate, so max_residual is updated as with ftol > 0
    for ftol in (1e-15, 1e-300, 0)
      a = pgd_assessment(T, ftol; x, previous = x, F, F_previous = F + 1, grad = T[1, 1.5], grad_previous = T[.5, 1])
      @test a.state.max_residual == T(.5)
    end
  end
end

# the function barrier gives the call concrete argument types
alloc_unchanged(a, b) = @allocated PS._unchanged(a, b)
@testset "_unchanged is value equality and allocates nothing" begin
  @test PS._unchanged([0.0, 1.0], [-0.0, 1.0])
  @test PS._unchanged(Float32[], Float32[])
  @test !PS._unchanged([0.0, 1.0], [0.0, nextfloat(1.0)])
  @test !PS._unchanged([1.0, 0.0], [1.0, floatmin(Float64)])
  for T in (Float64, Float32)
    a, b = rand(T, 100), zeros(T, 100)
    b .= a
    alloc_unchanged(a, b)
    @test alloc_unchanged(a, b) == 0
    b[end] = nextfloat(b[end])
    @test alloc_unchanged(a, b) == 0
  end
end

alloc_assessment(a) = @allocated PS.convergence_assessment(a.state, a.f, a.g, a.options)
@testset "PGD: a warmed assessment allocates nothing, with and without an unchanged iterate (#270)" begin
  for T in (Float64, Float32), ftol in (1e-15, 0)
    x = T[1, 2]
    for previous in (x .+ T(.01), x)
      a = pgd_assessment(T, ftol; x, previous, F = T(3) / 2, F_previous = T(5) / 2)
      PS.convergence_assessment(a.state, a.f, a.g, a.options)
      @test alloc_assessment(a) == 0
    end
  end
end

@testset "f_residual under ftol = 0 reports 0 for F = F' = 0, Inf for F = 0 != F' and |F - F'|/|F| otherwise (#270)" begin
  for T in (Float64, Float32)
    @test PS.f_residual(T(0), T(0), 0.0) === 0.0
    @test PS.f_residual(T(0), T(1), 0.0) === Inf
    @test PS.f_residual(T(1), T(0), 0.0) === 1.0
    @test PS.f_residual(T(-3), T(-3), 0.0) === 0.0
    @test PS.f_residual(T(2), T(1), 0.0) === 0.5
    @test PS.f_residual(T(1), T(3) / 2, 0.0) === 0.5
    # ftol > 0 keeps its formula
    @test PS.f_residual(T(0), T(0), 1e-6) === 0.0
    @test PS.f_residual(T(0), T(1), 1e-6) === 1 / 1e-6
    @test PS.f_residual(T(1), T(3) / 2, 1e-6) === 0.5 / (1 + 1e-6)
    # the result reports what the solve ended with: F = F' = 0, then F = 0 != F'
    f = LeastSquaresLoss(T[0], T[1;;])
    r = solve!(T[0], f, NormL1(T(100)), ProximalGradientDescent(), ProximalOptions(maxiter = 3, ftol = 0))
    @test r.f_tol === 0.0 && r.f_residual === 0.0 && !r.f_converged && r.minimum == 0
    x = T[1]
    r = solve!(x, f, NormL1(T(100)), ProximalGradientDescent(), ProximalOptions(ftol = 0, callback = _ -> true))
    @test r.iterations == 1 && x == T[0] && r.minimum == 0 && r.f_residual === Inf && !r.f_converged
  end
end

# A planted lasso with an interior solution (the data of the FASTA-only test above).
function fasta_fixture(T; fraction = .1)
  rng = Xoshiro(90); X = randn(rng, 40, 12); y = X * vcat([1., -.5], zeros(10)) + .1randn(rng, 40)
  scale = 1 / 40
  λ = fraction * norm(scale * X'y, Inf)
  X, y, scale, λ, T(scale) * LeastSquaresLoss(T.(y), T.(X)), NormL1(T(λ))
end

# F(b) and its Float64 duality gap relative to F(b), with the dual point s r scaled into the
# box ‖Xᵀθ‖∞ ≤ λ (a numerical check in Float64, not a certificate).
function relative_gap(X, y, scale, λ, b)
  r = y - X * b
  θ = scale * r
  θ .*= min(1, λ / norm(X' * θ, Inf))
  P = scale * sum(abs2, r) / 2 + λ * sum(abs, b)
  (P - (dot(y, θ) - sum(abs2, θ) / (2scale))) / P
end

@testset "PGD: ftol = 0 with allow_f_increases and strict tolerances ends on the gradient test (#270)" begin
  X, y, scale, λ, f, g = fasta_fixture(Float64)
  # the control allows increases, so that it does not depend on an increase stop of the rounded trajectory
  base = ProximalOptions(maxiter = 20_000, ftol = 1e-15, allow_f_increases = true, xtol = 1e-14, gradtol = 1e-11)
  strict = ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11)
  # at the base tolerances the objective test ends the solve
  r = solve!(zeros(12), f, g, ProximalGradientDescent(), base)
  @test r.f_converged
  x = zeros(12)
  r = solve!(x, f, g, ProximalGradientDescent(), strict)
  @test !r.f_converged && r.grad_converged && r.converged && !r.iteration_converged
  @test r.f_tol === 0.0 && r.g_residual < 1e-6
  # the fixture's requirement is a KKT residual below 1e-4 (the FASTA-only test); tightened tenfold,
  # and the independent relative duality gap against the target 1e-8
  @test direct_kkt(X, y, x, λ, scale) < 1e-4 / 10
  @test relative_gap(X, y, scale, λ, x) < 1e-8
end

@testset "PGD: an exactly unchanged iterate under ftol = 0 is no progress, not convergence (#270)" begin
  # λ is twice the largest |∇f(0)|, so a step from x = 0 is soft thresholded to 0: the iterate
  # stays x == x_previous. The point is the exact solution; the flags report no progress, not an error.
  for T in (Float64, Float32)
    _, _, _, _, f, g = fasta_fixture(T; fraction = 2)
    # the settings of the base: an unchanged iterate passes the x test
    r = solve!(zeros(T, 12), f, g, ProximalGradientDescent(),
               ProximalOptions(maxiter = 50, ftol = 1e-15, xtol = 1e-14, gradtol = 1e-11))
    @test r.converged && r.x_converged && !r.iteration_converged
    # ftol = 0 stops on neither the x test nor the gradient test, and runs to maxiter.
    # allow_f_increases = true keeps a rounding-level increase of the computed objective from ending it.
    x = zeros(T, 12)
    r = solve!(x, f, g, ProximalGradientDescent(),
               ProximalOptions(maxiter = 5, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11))
    @test !r.converged && r.iteration_converged && r.iterations == 5
    @test !r.x_converged && !r.f_converged && !r.grad_converged
    @test all(iszero, x) && r.x_residual == 0 && r.g_residual == 0
  end
end

@testset "PGD: ftol = 0, gradtol = 0 and a tiny xtol end at maxiter when the solve is far from its solution (#270)" begin
  for T in (Float64, Float32)
    _, _, _, _, f, g = fasta_fixture(T)
    x = zeros(T, 12)
    r = solve!(x, f, g, ProximalGradientDescent(),
               ProximalOptions(maxiter = 3, ftol = 0, gradtol = 0, xtol = 1e-300))
    @test !r.converged && r.iteration_converged && r.iterations == 3
    @test !r.x_converged && !r.f_converged && !r.grad_converged && any(!iszero, x)
  end
end

@testset "PGD: with ftol = 0 an increase or any other stop reports converged from the x and gradient tests only (#270)" begin
  for T in (Float64, Float32), fraction in (.05, .3), allow in (false, true)
    _, _, _, _, f, g = fasta_fixture(T; fraction)
    r = solve!(zeros(T, 12), f, g, ProximalGradientDescent(),
               ProximalOptions(maxiter = 2000, ftol = 0, allow_f_increases = allow, xtol = 1e-300, gradtol = 1e-11))
    @test !r.f_converged
    @test r.converged == (r.x_converged || r.grad_converged)
    # an increase of the computed objective can end the solve only when allow is false; no test requires one
    r.f_increased && !allow && @test r.converged == (r.x_converged || r.grad_converged)
    # with ftol > 0 the objective test is part of converged
    r = solve!(zeros(T, 12), f, g, ProximalGradientDescent(),
               ProximalOptions(maxiter = 2000, ftol = 1e-15, allow_f_increases = allow, xtol = 1e-14, gradtol = 1e-11))
    @test r.converged == (r.x_converged || r.f_converged || r.grad_converged)
  end
end

@testset "PGD: the result display shows a disabled objective test and a true increase line (#270)" begin
  _, _, _, _, f, g = fasta_fixture(Float64)
  r = solve!(zeros(12), f, g, ProximalGradientDescent(), ProximalOptions(maxiter = 5, ftol = 0))
  shown = sprint(show, r)
  @test occursin("\n   * objective-change test: disabled (ftol = 0)\n     |f(x) - f(x')| / |f(x)| = ", shown)
  @test !occursin("|f(x) - f(x')| / |f(x)| <", shown)
  @test occursin("\n   * objective increased at the last iteration: $(r.f_increased)\n", shown)
  @test !occursin("stopped by an increasing objective", shown)
  # the line reports the comparison, which holds in both cases of allow_f_increases
  r.f_increased = true
  @test occursin("\n   * objective increased at the last iteration: true\n", sprint(show, r))
  # the default options keep the objective test line, and show the same increase line
  r = solve!(zeros(12), f, g, ProximalGradientDescent())
  shown = sprint(show, r)
  @test occursin("\n   * |f(x) - f(x')| / |f(x)| < 1.0e-06: $(r.f_converged)\n", shown)
  @test occursin("\n   * objective increased at the last iteration: $(r.f_increased)\n", shown)
  @test !occursin("disabled", shown) && !occursin("stopped by an increasing objective", shown)
end

end
