# Is a PB spectral quantity an upper bound of lambda_max(X'X) (what PS _gram_curvature certifies)?
using ProximalBase, ProximalSolvers, LinearAlgebra, Random
const PB = ProximalBase; const PS = ProximalSolvers
println("Julia ", VERSION)
rng = MersenneTwister(5)
for T in (Float64, Float32), (n, mk) in ((50, 2), (200, 4), (500, 8))
    below_opn = 0; below_lip = 0; below_ps = 0; N = 300; ratio_ps = Float64[]
    for _ in 1:N
        X = randn(rng, T, n, mk) .* T.(exp.(randn(rng, 1, mk)))
        G = Float64.(big.(X)' * big.(X)); ref = maximum(eigvals(Symmetric(G)))   # Gram formed exactly (BigFloat), eigenvalue in Float64 (error ~1e-16 relative)
        o = PB.opnorm2(X); below_opn += Float64(o) < ref*(1-8eps(T))
        f = PB.LeastSquaresLoss(randn(rng, T, n), X); l = PB.lipschitz(f); below_lip += Float64(l) < ref*(1-8eps(T))
        ls = PS.LSModel(f.Y, X, 1.0)
        c = PS._gram_curvature(ls, collect(1:mk), 1, Matrix{Float64}(undef, n, mk), Matrix{Float64}(undef, mk, mk))
        below_ps += Float64(c) < ref*(1-8eps(T)); push!(ratio_ps, Float64(c)/ref - 1)
    end
    println("$T n=$n mk=$mk: fraction clearly BELOW (by >8 eps(T)) the true lambda_max: PB.opnorm2 ", round(below_opn/N, digits=2), "  PB.lipschitz(LS) ", round(below_lip/N, digits=2), "  PS._gram_curvature ", round(below_ps/N, digits=2), "   (PS overshoot median ", round(sort(ratio_ps)[N÷2], sigdigits=2), ")")
end
