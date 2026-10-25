using Random, Statistics, Printf, Test, TOML
include("prototype.jl")
BLAS.set_num_threads(1)

mutable struct WorkCounts
  products::Int
  full_products::Int
  entries::Int
  cluster_entries::Int
  width::Int
end
struct CountedDesign{T,M<:AbstractMatrix{T}} <: AbstractMatrix{T}
  data::M
  counts::WorkCounts
end
Base.size(X::CountedDesign) = size(X.data)
Base.getindex(X::CountedDesign,i::Int,j::Int) = X.data[i,j]
Base.getindex(X::CountedDesign,::Colon,E::AbstractVector) = CountedDesign(X.data[:,E],X.counts)
stored(X::AbstractMatrix) = length(X)
stored(X::SparseMatrixCSC) = nnz(X)
function LinearAlgebra.mul!(out::AbstractVector,X::CountedDesign,x::AbstractVector)
  X.counts.products += 1; X.counts.entries += stored(X.data)
  X.counts.full_products += size(X,2) == X.counts.width
  mul!(out,X.data,x)
end
function LinearAlgebra.mul!(out::AbstractVector,X::Transpose{<:Any,<:CountedDesign},x::AbstractVector)
  A = parent(X)
  A.counts.products += 1; A.counts.entries += stored(A.data)
  A.counts.full_products += size(A,2) == A.counts.width
  mul!(out,transpose(A.data),x)
end
Base.:*(X::CountedDesign,x::AbstractVector) = mul!(zeros(eltype(X),size(X,1)),X,x)
Base.:*(X::Transpose{<:Any,<:CountedDesign},x::AbstractVector) = mul!(zeros(eltype(X),size(X,1)),X,x)
function cluster_column!(column,X::CountedDesign,indices,signs)
  X.counts.cluster_entries += stored(X.data[:,indices])
  cluster_column!(column,X.data,indices,signs)
end

function fixture(seed,rho,storage,sparsity)
  rng = Xoshiro(95000+seed)
  n,p = 80,120
  A = randn(rng,n,p)
  for j in 2:p
    A[:,j] .= rho.*A[:,j-1]+sqrt(1-rho^2).*A[:,j]
  end
  if storage == "sparse"
    A .*= rand(rng,n,p) .< .15
  end
  beta = zeros(p)
  beta[1:sparsity] .= repeat([2.,-2.,1.,-1.],cld(sparsity,4))[1:sparsity]
  y = A*beta+.3randn(rng,n)
  X = storage == "sparse" ? sparse(A) : A
  X,y
end

# A feasible Fenchel dual certificate, independent of the fixed-point stop.
function gap(X,y,x,lambda)
  n = length(y)
  theta = (y-X*x)/n
  sorted_gradient = sort!(abs.(X'*theta);rev=true)
  dualnorm = maximum(cumsum(sorted_gradient)./cumsum(lambda))
  shrink = min(1.,inv(max(dualnorm,eps())))/(1+16eps())
  primal = n*sum(abs2,theta)/2+dot(lambda,sort(abs.(x);rev=true))
  dual = shrink*dot(y,theta)-n*shrink^2*sum(abs2,theta)/2
  raw = primal-dual
  raw < -100eps()*max(1,abs(primal)) ? Inf : max(0,raw)/max(1,abs(primal))
end

function fit(X,y,weights,grid,method;counted=false)
  counts = WorkCounts(0,0,0,0,size(X,2))
  design = counted ? CountedDesign(X,counts) : X
  f = inv(length(y))*LeastSquaresLoss(y,design)
  result = solve_path(f,SLOPE(weights),grid,method)
  gaps = [gap(X,y,x,a.*weights) for (x,a) in zip(result.solutions,grid)]
  (;result,counts,gaps)
end

function main()
  output = isempty(ARGS) ? joinpath(@__DIR__,"pilot.tsv") : ARGS[1]
  seeds = length(ARGS) > 1 ? parse.(Int,split(ARGS[2],',')) : [1,2,3]
  tolerance = length(ARGS) > 2 ? parse(Float64,ARGS[3]) : 1e-8
  # Compile both kernels and the instrumentation before measuring.
  for storage in ("dense","sparse")
    X,y = fixture(0,.9,storage,8); weights = collect(range(2.,.5;length=size(X,2)))
    top = lambda_max(inv(length(y))*LeastSquaresLoss(y,X),SLOPE(weights),zeros(size(X,2)))
    for method in (SLOPEAPG(;tol=tolerance),HybridPrototype(;tol=tolerance)), counted in (false,true)
      fit(X,y,weights,top.*[1.,.5,.1],method;counted)
    end
  end
  open(output*".levels.tsv","w") do levels
   println(levels,"seed\trho\tstorage\tsparsity\tweights\tdepth\tmethod\ttol\tlevel\talpha\titerations\tconverged\tgap\tresidual\tworking_size\trepairs\tnonzeros\tclusters")
   open(output,"w") do io
    println(io,"seed\trho\tstorage\tsparsity\tweights\tdepth\tmethod\ttol\tseconds\tbytes\titerations\tproducts\tfull_products\tentries\tcluster_entries\tlevels\tconverged\tcertified\tmax_gap\tmax_residual")
    for seed in seeds, rho in (0.,.99), storage in ("dense","sparse"), sparsity in (8,32), kind in ("linear","stepped"), depth in (6,12)
      X,y = fixture(seed,rho,storage,sparsity); p = size(X,2)
      weights = kind == "linear" ? collect(range(2.,.5;length=p)) : vcat(fill(2.,p÷3),fill(.8,p-p÷3))
      top = lambda_max(inv(length(y))*LeastSquaresLoss(y,X),SLOPE(weights),zeros(p))
      grid = top.*exp.(range(0,log(.05);length=depth))
      # Alternate paired order across fixtures. Certificates stay outside timing.
      methods = isodd(seed+depth+sparsity) ? ("apg","hybrid") : ("hybrid","apg")
      for name in methods
        method = name == "apg" ? SLOPEAPG(;tol=tolerance) : HybridPrototype(;tol=tolerance)
        measured = @timed solve_path(inv(length(y))*LeastSquaresLoss(y,X),SLOPE(weights),grid,method)
        checked = fit(X,y,weights,grid,method;counted=true)
        r,c,gaps = checked.result,checked.counts,checked.gaps
        @test all(norm(a-b,Inf)<1e-8 for (a,b) in zip(r.solutions,measured.value.solutions))
        row = (seed,rho,storage,sparsity,kind,depth,name,tolerance,measured.time,measured.bytes,
          sum(r.iterations),c.products,c.full_products,c.entries,c.cluster_entries,length(grid),
          count(r.converged),count(<=(1e-6),gaps),maximum(gaps),maximum(r.kkt_residuals))
        println(io,join(row,'\t'));flush(io)
        for k in eachindex(grid)
          x = r.solutions[k]
          row = (seed,rho,storage,sparsity,kind,depth,name,tolerance,k,grid[k],r.iterations[k],r.converged[k],gaps[k],r.kkt_residuals[k],r.working_sizes[k],r.kkt_repairs[k],count(!iszero,x),length(unique(abs.(filter(!iszero,x)))))
          println(levels,join(row,'\t'))
        end
        flush(levels)
      end
    end
  end
  end
  println("Saved ",output)
end
if abspath(PROGRAM_FILE) == @__FILE__
  main()
end
