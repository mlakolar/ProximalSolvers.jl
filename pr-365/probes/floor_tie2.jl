# Base and head in one process: public square-root solves at tolerances on and off the tie of the tightening floor
# (tol/100^k == 16 eps for k = 1, 2  <=>  tol = 1600 eps, 160000 eps), relative threshold. Counts outcome changes.
using Random, Logging, Printf
module B; include("<WORK>/ProximalSolvers.jl-issue353-2-base/src/ProximalSolvers.jl"); end
module H; include("<WORK>/ProximalSolvers.jl-issue353-2/src/ProximalSolvers.jl"); end
using ProximalBase: SqrtLeastSquaresLoss, NormL1
function sol(PS, X::Matrix{T}, y, λ, tol) where T
  r = with_logger(NullLogger()) do
    PS.solve!(zeros(T, size(X, 2)), SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(order = :cyclic, momentum = false, tol = tol, maxpasses = 5000))
  end
  (r.passes, r.converged, r.tolerance, r.gap)
end
function main(nprob)
  println("Julia ", VERSION)
  for T in (Float64, Float32)
    tols = [("1600 eps (tie)", 1600eps(T)), ("160000 eps (tie)", 160000eps(T)), ("prevfloat(1600 eps)", prevfloat(1600eps(T))), ("nextfloat(1600 eps)", nextfloat(1600eps(T))),
            ("1599 eps", 1599eps(T)), ("1601 eps", 1601eps(T)), ("16000 eps", 16000eps(T)), ("1e-10 or 1e-4", T === Float64 ? T(1e-10) : T(1e-4)), ("1e-12 or 1e-5", T === Float64 ? T(1e-12) : T(1e-5)), ("default tol", nothing)]
    for (lab, tol) in tols
      rng = Xoshiro(365353); n = 0; same = 0; c2u = 0; u2c = 0; passonly = 0
      for k in 1:nprob
        X = randn(rng, 100, 8); k % 3 == 0 && (X[:, 2] = X[:, 1] + 0.01randn(rng, 100))
        y = ldexp.(X[:, 1], 27) + randn(rng, 100)
        Xt, yt, λ = T.(X), T.(y), T(ldexp(1000.0, -27))
        tl = tol === nothing ? B.ProximalSolvers.CDSolver().tol : tol
        b = sol(B.ProximalSolvers, Xt, yt, λ, tl); h = sol(H.ProximalSolvers, Xt, yt, λ, tl)
        n += 1
        if isequal(b, h); same += 1
        elseif b[2] && !h[2]; c2u += 1
        elseif !b[2] && h[2]; u2c += 1
        else; passonly += 1; end
      end
      @printf("%s tol = %-20s solves %4d identical %4d | converged -> not %3d | not -> converged %3d | same flag, other passes or tolerance %3d\n", T, lab, n, same, c2u, u2c, passonly)
    end
  end
end
main(parse(Int, get(ARGS, 1, "300")))
