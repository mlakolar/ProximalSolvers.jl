# Group curvature: does PB's public `lipschitz(LeastSquaresLoss(y, X_G))` (= opnorm(X_G)^2, no rounding margin) majorize λmax(X_Gᵀ X_G)
# of the stored data? BigFloat(600) Cholesky test of ℓI - G ⪰ 0 on the rounded inputs, against PS's `_gram_curvature`.
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 600)
function majorizes(ℓ, Xg)
  B = BigFloat.(Xg); G = B' * B
  A = BigFloat(ℓ) * I - G
  try cholesky(Symmetric(A)); true catch; false end
end
rng = Xoshiro(9)
for T in (Float32, Float64)
  nbad_pb = 0; nbad_ps = 0; tot = 0; ratio_ps = Float64[]; ratio_pb = Float64[]
  tps = 0.0; tpb = 0.0
  for trial in 1:400
    n = rand(rng, (50, 200, 1000)); mk = rand(rng, 2:6)
    Xg = randn(rng, T, n, mk)
    kind = rand(rng, 1:3)
    kind == 2 && (Xg[:, 2] .= Xg[:, 1] .* T(1) .+ T(1e-3) .* Xg[:, 2])      # near-collinear
    kind == 3 && (Xg = Xg * Diagonal(T.(exp2.(rand(rng, -3:3, mk)))))
    y = randn(rng, T, n); X = hcat(Xg, randn(rng, T, n, 1))
    ls = PS.LSModel(y, X, one(T)); colbuf = Matrix{Float64}(undef, n, mk); grambuf = Matrix{Float64}(undef, mk, mk)
    idx = collect(1:mk)
    tps += @elapsed ℓps = PS._gram_curvature(ls, idx, 1, colbuf, grambuf)
    f = LeastSquaresLoss(y, view(X, :, 1:mk))
    tpb += @elapsed ℓpb = lipschitz(f)
    tot += 1
    majorizes(ℓps, Xg) || (nbad_ps += 1)
    majorizes(ℓpb, Xg) || (nbad_pb += 1)
    # exact λmax by Float64 eigen on the BigFloat Gram rounded: ratio to it
    λ = maximum(eigvals(Symmetric(Float64.(BigFloat.(Xg)' * BigFloat.(Xg)))))
    push!(ratio_ps, Float64(ℓps)/λ - 1); push!(ratio_pb, Float64(ℓpb)/λ - 1)
  end
  @printf("%s: %d groups. majorization violated: PS _gram_curvature %d, PB lipschitz(LS(y, X_G)) %d.  relative excess over λmax (median): PS %.2e  PB %.2e  (PB min %.2e)\n   time per call (incl. loss construction for PB): PS %.1f us, PB %.1f us (indicative setup-path timing)\n",
          T, tot, nbad_ps, nbad_pb, sort(ratio_ps)[end÷2], sort(ratio_pb)[end÷2], minimum(ratio_pb), 1e6tps/tot, 1e6tpb/tot)
end
