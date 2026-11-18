include(joinpath(@__DIR__, "variants.jl"))
using ProximalBase, Random
rng = Xoshiro(296); X = randn(rng, 30, 12); β = zeros(12); β[1:4] .= [2.0, -1.5, 1.0, 0.5]; y = X*β + 0.3*randn(rng, 30)
X32, y32 = Float32.(X), Float32.(y)
for α in (1f0, 1f-10, 1f-19, 1f-20, 1f-25, 1f-30, 1f-35), o in ((maxiter=20_000,), (maxiter=20_000, ftol=0, allow_f_increases=true))
  x = zeros(Float32, 12); SUBNORMAL_HITS[] = 0; Ls = Float32[]
  r = try solve!(x, α*LeastSquaresLoss(y32, X32), NormL1(0f0), ProximalGradientDescent(), ProximalOptions(; o..., callback = s -> (push!(Ls, s.L); false))) catch e; sprint(showerror, e) end
  r isa String ? println("α=$α $(keys(o)) ERR $r") :
    println("α=$α ", length(o) > 1 ? "afi " : "def ", "it=", r.iterations, " conv=", r.converged, " finc=", r.f_increased, " stag=", r.stagnated, " L_end=", Ls[end], " α‖X‖²=", α*72.76f0, " relerr=", norm(x - X\y)/norm(X\y), " hits=", SUBNORMAL_HITS[])
end
