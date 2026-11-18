include(joinpath(@__DIR__, "lib.jl")); include(joinpath(@__DIR__, "pts.jl"))
pts = [p for p in points() if p.set in ("M81", "OPTx")]
for μ in (1e-13, 1e-12, 1e-10, 1e-9, 1e-8, 1e-6)
  cnt = Dict("M81" => 0, "OPTx" => 0)
  for pt in pts
    TT = pt.T == "Float64" ? Float64 : Float32
    prob = problem(pt.id); X, y, λ = data(prob, TT); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
    chk(θ) = vcert(Xd, yd, λd, λd, pt.β, θ)
    ok = false
    for e in (1e-6, 1e-5, 3e-5)
      c = cand_Bc(Xd, yd, λd, pt.β; εdrop = e, μrel = μ); c.θ === nothing && continue
      chk(c.θ).ok && (ok = true; break)
    end
    ok && (cnt[pt.set] += 1)
  end
  println("μrel=", μ, " M81 ", cnt["M81"], "/81  OPTx ", cnt["OPTx"], "/119")
end
