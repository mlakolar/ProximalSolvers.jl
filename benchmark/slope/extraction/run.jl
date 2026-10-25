# Isolate the driver extraction: the old model driver and new shared engine
# intentionally use the same current inner APG and proximal implementation.
using LinearAlgebra, Random, SparseArrays, Statistics, Test
using ProximalBase, ProximalSolvers
import CoordinateDescent as CD
import StatsAPI

module Legacy
using LinearAlgebra, Statistics, ProximalBase, ProximalSolvers
import StatsAPI
import CoordinateDescent
const erfcinv = CoordinateDescent.erfcinv
include("legacy_slope_9599303.jl")
end

const process_id = parse(Int,ARGS[1])
const output = ARGS[2]
BLAS.set_num_threads(1)
mkpath(output)
const rows = open(joinpath(output,"process-$process_id.tsv"),"w")
println(rows,"process\tseed\trho\tintercept\tstandardize\tbackend\tblock\tseconds\tbytes\tlevels\tvalid_levels\tmax_residual\tcoefficient_error\tprediction_error\tmetadata_equal")

# Evaluate the full proximal equation separately from either driver's code.
function certificate(Z,v,b,lambda)
  gradient = transpose(Z)*(Z*b-v)/length(v)
  trial = similar(b)
  prox!(trial,ProximalBase.SLOPE(lambda),b-gradient,1.)
  norm(b-trial,Inf)/max(1,norm(transpose(Z)*v/length(v),Inf))
end

@testset "Extraction equivalence process $process_id" begin
  for seed in 1:3, rho in (0.,.9), prepared in (false,true)
    rng = Xoshiro(seed)
    n,p = 320,640
    X = randn(rng,n,p)
    if rho > 0
      X .= sqrt(1-rho).*X .+ sqrt(rho).*randn(rng,n)
    end
    truth=zeros(p);truth[1:12].=range(1.5,.5;length=12)
    y=X*truth+randn(rng,n)
    if prepared
      X .*= transpose(range(.5,2.;length=p)); X .+= transpose(range(-1.,1.;length=p))
      y .+= 2.
    end
    weights=CD.slope_bh(p;n,q=.1,sigma=1.)
    Z,v,xb,yb,scales = CD._slope_data(X,y,prepared,prepared)
    f=(1/n)*LeastSquaresLoss(v,Z);g=ProximalBase.SLOPE(weights)
    factors=lambda_max(f,g,zeros(p)).*exp.(range(0,log(.15);length=12))
    method=SLOPEAPG(;tol=1e-7)
    make = Dict(
      "legacy" => ()->Legacy.SLOPEPath(X,y,factors;lambda=weights,intercept=prepared,standardize_x=prepared,tol=1e-7),
      "engine" => ()->solve_path(f,g,factors,method),
      "wrapper" => ()->CD.SLOPEPath(X,y,factors;lambda=weights,intercept=prepared,standardize_x=prepared,tol=1e-7))
    reference=make["legacy"]()
    # Compilation and first-use effects are excluded for every backend.
    for backend in ("engine","wrapper");make[backend]();end
    for block in 1:3
      order=shuffle(rng,["legacy","engine","wrapper"])
      for backend in order
        measured=@timed make[backend]()
        r=measured.value
        bs=backend=="engine" ? [b./scales for b in r.solutions] : r.βpath
        residuals=[certificate(Z,v,bs[k].*scales,factors[k].*weights) for k in eachindex(factors)]
        error=maximum(norm(b-c,Inf) for (b,c) in zip(bs,reference.βpath))
        pred=maximum(norm(Z*((b-c).*scales),Inf) for (b,c) in zip(bs,reference.βpath))
        metadata=r.iterations==reference.iterations && r.converged==reference.converged &&
          r.working_sizes==reference.working_sizes && r.kkt_repairs==reference.kkt_repairs
        @test all(r.converged)
        @test maximum(residuals)<=1e-7*(1+1e-5)
        @test error<=2e-6
        @test pred<=2e-5
        @test metadata
        if backend!="engine"
          @test maximum(abs.(r.β0path-reference.β0path))<=2e-6
        end
        println(rows,join((process_id,seed,rho,prepared,prepared,backend,block,measured.time,
          measured.bytes,length(factors),count(<=(1e-7*(1+1e-5)),residuals),maximum(residuals),error,pred,metadata),'\t'))
        flush(rows)
      end
    end
  end
end
close(rows)
