# Independent LP/QP checks; run with --project=test/oracles.
using Test, LinearAlgebra, SparseArrays, Random, Printf, ProximalBase, ProximalSolvers
import JuMP, HiGHS

function quantile_lp(X,b,q,λ)
  n,p = size(X)
  m=JuMP.Model(HiGHS.Optimizer); JuMP.set_silent(m)
  JuMP.set_attribute(m,"primal_feasibility_tolerance",1e-9)
  JuMP.set_attribute(m,"dual_feasibility_tolerance",1e-9)
  JuMP.@variable(m,bp[1:p]>=0); JuMP.@variable(m,bm[1:p]>=0)
  JuMP.@variable(m,u[1:n]>=0); JuMP.@variable(m,v[1:n]>=0)
  eq=JuMP.@constraint(m,X*(bp-bm)+u-v .== b)
  JuMP.@objective(m,Min,(q*sum(u)+(1-q)*sum(v))/n+λ*(sum(bp)+sum(bm)))
  JuMP.optimize!(m)
  @test JuMP.is_solved_and_feasible(m;dual=true)
  # Our y is the subgradient with respect to the predictions, the negative
  # of the LP's residual/rank-score dual.
  JuMP.value.(bp)-JuMP.value.(bm), -JuMP.dual.(eq), JuMP.objective_value(m)
end

# The lecture examples compare different splittings. Check their shared
# lower bound and reconstructed dual against an independent QP, including
# arbitrary nonoptimal points so a formula that only works at convergence
# cannot pass unnoticed.
include(joinpath(@__DIR__, "..", "..", "examples", "support", "primal_dual_lessons.jl"))
using .PrimalDualLessons
include(joinpath(@__DIR__, "..", "..", "benchmark", "composite_lessons", "qp.jl"))

@testset "Composite lecture certificates and reference algorithms" begin
  rng = MersenneTwister(1516)
  for a in (graph_problem(5), trend_problem(40))
    reference = qp_solve(a; tol = 1e-7)
    @test reference.converged
    for _ in 1:5
      x = randn(rng, a.p)
      y = 10a.λ2 * randn(rng, size(a.D, 1))
      c = certificate(a, x, y)
      @test c.lower <= reference.cert.primal + 1e-8
      @test c.primal - reference.cert.primal <= c.gap + 1e-8
      @test norm(x - reference.x) <= c.distance_bound + reference.cert.distance_bound + 1e-8
      @test norm(c.dual, Inf) <= a.λ2
      if a.name == "trend"
        d = a.D' * c.dual
        @test c.lower ≈ dot(a.b, d) - sum(abs2, d) / 2 atol = 1e-8
      end
    end
    fits = [native_solve(a; tol = 1e-7), split_admm(a; tol = 1e-7)]
    a.name == "trend" && push!(fits, trend_admm(a; tol = 1e-7))
    for r in fits
      @test r.converged
      @test abs(r.cert.primal - reference.cert.primal) <= r.cert.gap + reference.cert.gap + 1e-8
      @test norm(r.x - reference.x) <= r.cert.distance_bound + reference.cert.distance_bound + 1e-8
    end
  end
end

function quantile_data(n,p,q=.3)
  rng=MersenneTwister(23+n+p)
  X=randn(rng,n,p); X ./= sqrt.(sum(abs2,X;dims=1)./n)
  β=zeros(p); β[1:min(5,p)] .= 1
  b=X*β+randn(rng,n)
  λ=.1*norm(X' * ifelse.(b .> 0,q,q-1),Inf)/n
  X,b,λ
end

@testset "Quantile LP primal and dual references" begin
  for q in (.25,.5,.75), sparseD in (false,true)
    X,b,λ=quantile_data(60,12,q)
    D=sparseD ? sparse(X) : X
    xlp,ylp,Flp=quantile_lp(X,b,q,λ)
    f,g,h=ZeroFunction(),NormL1(λ),Scaled(Translate(CheckLoss(1-q),b),1/length(b))
    res=solve!(zeros(12),f,g,h,D,CondatVu(abstol=1e-10,reltol=1e-9,normD=opnorm(X)),
               ProximalOptions(maxiter=500_000,gaptol=1e-9,gapevery=25,time_limit=60))
    @test res.converged
    @test abs(res.minimum-Flp) <= 2e-8
    @test norm(res.minimizer-xlp,Inf) < 1e-5
    @test norm(res.y-ylp,Inf) < 2e-6
    @test norm(X'res.y,Inf) <= λ+1e-7
    @test all(-q/60-1e-9 .<= res.y .<= (1-q)/60+1e-9)
    @printf("ORACLE q=%.2f sparse=%s iterations=%d ΔF=%.3e Δx=%.3e Δdual=%.3e gap=%.3e\n",q,sparseD,res.iterations,res.minimum-Flp,norm(res.minimizer-xlp,Inf),norm(res.y-ylp,Inf),res.gap)
  end
end
@testset "Generalized lasso: HiGHS quadratic program" begin
  rng=MersenneTwister(2323); n,p=80,25
  X=randn(rng,n,p); b=randn(rng,n)
  D=spdiagm(p-2,p,0=>ones(p-2),1=>-2ones(p-2),2=>ones(p-2))
  λ,κ=.01,.1
  m=JuMP.Model(HiGHS.Optimizer);JuMP.set_silent(m)
  JuMP.@variable(m,β[1:p]);JuMP.@variable(m,t[1:p]);JuMP.@variable(m,v[1:p-2])
  JuMP.@constraint(m,t .>= β);JuMP.@constraint(m,t .>= -β)
  JuMP.@constraint(m,v .>= D*β);JuMP.@constraint(m,v .>= -D*β)
  JuMP.@objective(m,Min,sum((X*β-b).^2)/(2n)+λ*sum(t)+κ*sum(v))
  JuMP.optimize!(m);@test JuMP.is_solved_and_feasible(m)
  res=solve!(zeros(p),Scaled(LeastSquaresLoss(b,X),1/n),NormL1(λ),NormL1(κ),D,
             CondatVu(abstol=1e-10,reltol=1e-9),ProximalOptions(maxiter=100_000))
  @test res.converged
  @test abs(res.minimum-JuMP.objective_value(m)) < 1e-8
  @test norm(res.minimizer-JuMP.value.(β),Inf) < 2e-6
  @printf("GENERALIZED_LASSO iterations=%d ΔF=%.3e Δx=%.3e\n",res.iterations,res.minimum-JuMP.objective_value(m),norm(res.minimizer-JuMP.value.(β),Inf))
end
