# #307 product counts: forward (X v) and adjoint (Xᵀ v) matrix-vector products per solve, with the
# solver counters, on fixed problems. Run in each arm's environment:
#   julia --startup-file=no --project=ENV products.jl ARM
# The counting is done in this process only, by more specific 3-argument mul! methods for dense
# Float32/Float64 Matrix and Vector (and the Transpose of such a Matrix) that count and call BLAS.gemv!.
# PS and PB call the 3-argument mul! on these types for every product of the migrated paths.
using LinearAlgebra, Random
using ProximalSolvers, ProximalBase
const FWD = Ref(0); const ADJ = Ref(0)
for T in (Float32, Float64)
  @eval function LinearAlgebra.mul!(y::Vector{$T}, A::Matrix{$T}, x::Vector{$T})
    FWD[] += 1
    BLAS.gemv!('N', one($T), A, x, zero($T), y)
  end
  @eval function LinearAlgebra.mul!(y::Vector{$T}, A::Transpose{$T, Matrix{$T}}, x::Vector{$T})
    ADJ[] += 1
    BLAS.gemv!('T', one($T), parent(A), x, zero($T), y)
  end
end
BLAS.set_num_threads(1)
const ARM = isempty(ARGS) ? "?" : ARGS[1]
counters(r) = hasproperty(r, :f_calls) ?
  (iters = r.iterations, f = r.f_calls, g = r.grad_calls, p = r.prox_calls, bt = r.backtrack_steps) :
  (passes = r.passes,)
println("arm,version,problem,T,loss,solver,start,fwd,adj,counters,minimum,converged")
for (pname, n, p, ρ) in (("small", 57, 13, 0.0), ("corr", 240, 160, 0.8))
  for T in (Float64, Float32), loss in ("raw", "scaled", "scaled64")
    T === Float64 && loss == "scaled64" && continue
    rng = Xoshiro(11)
    Z = randn(rng, n, p)
    X = T.(sqrt(1 - ρ) .* Z .+ sqrt(ρ) .* randn(rng, n))
    β = zeros(p); β[1:5] .= (3.0, -2.0, 1.5, 1.0, -0.5)
    y = T.(Float64.(X) * β .+ 0.5 .* randn(rng, n))
    base = ProximalBase.LeastSquaresLoss(y, X)
    f = loss == "raw" ? base : loss == "scaled" ? (one(T) / T(n)) * base : (1 / n) * base
    s = loss == "raw" ? 1.0 : 1.0 / n
    λ = T(0.1 * s * maximum(abs, Float64.(X)' * Float64.(y)))
    g = ProximalBase.NormL1(λ)
    for (sname, mk) in (("cd", ProximalSolvers.CDSolver), ("pg", ProximalSolvers.ProximalGradientDescent),
                        ("apg", ProximalSolvers.AccProxGradDescent))
      for start in ("cold", "warm")
        x0 = zeros(T, p)
        start == "warm" && solve!(x0, f, ProximalBase.NormL1(T(1.25) * λ), mk())
        x = copy(x0)
        solve!(copy(x0), f, g, mk())                 # compile
        FWD[] = 0; ADJ[] = 0
        r = solve!(x, f, g, mk())
        println(join((ARM, VERSION, pname, T, loss, sname, start, FWD[], ADJ[],
                      replace(string(counters(r)), "," => ";"), r.minimum, r.converged), ","))
      end
    end
  end
end
