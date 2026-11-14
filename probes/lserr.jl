# Where does PGD's line search fail when the stopping fix lets a tiny-α solve continue?
using Pkg; Pkg.instantiate()
using ProximalSolvers, ProximalBase, LinearAlgebra, Random
ENV["VARIANT"] = "F+G+R"
include(joinpath(@__DIR__, "variants.jl"))
const LS = ProximalSolvers.LineSearches
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X * β + 0.3 * randn(rng, 30)
for α in (1e-200, 1e-300)
  x = zeros(12); tr = Any[]
  cb = os -> (push!(tr, (os.iteration, os.L, os.dxx)); false)
  try
    solve!(x, α * LeastSquaresLoss(y, X), NormL1(0.0), ProximalGradientDescent(),
           ProximalOptions(maxiter = 20_000, ftol = 0, allow_f_increases = true, xtol = 1e-300, gradtol = 1e-11, callback = cb))
    println("α=$α no error; iters=", length(tr))
  catch e
    println("α=$α error: ", sprint(showerror, e)[1:min(end,80)], " after ", length(tr), " iterations")
    for t in tr[max(1,end-3):end]; println("   iter=$(t[1]) L=$(t[2]) dx/x=$(t[3]) normx=$(norm(x))"); end
  end
end
