# Soundness/tightness: perturb the oracle optimum on its support (exact-fit optima), then certify with B.
# A certified ratio must be >= the true relative excess (P(β)-P*)/P* (bracketed by oracle U, D).
include(joinpath(@__DIR__, "lib.jl"))
out = open(joinpath(@__DIR__, "out", "perturb.tsv"), "w")
println(out, join(["id","T","eps","excess","lbexc","method","ok","ratio","bigratio","variant"], '\t'))
for T in (Float64, Float32), prob in ORACLE.probs
  o = oracle(prob.id, T); o.exactfit || continue
  X, y, λ = data(prob, T); Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  rng = Xoshiro(hash(prob.id) % 10^6)
  β0 = Float64.(T.(o.β))
  for variant in ("dirty", "clean"), ε in (1e-6, 1e-5, 1e-4, 1e-3, 1e-2)
    S = variant == "dirty" ? findall(abs.(β0) .> 1e-9*norm(β0, Inf)) : effsupport(β0, 1e-4)
    β = copy(β0); β[S] .+= ε*norm(β0, Inf)*randn(rng, length(S)); β = Float64.(T.(β))
    P = Pbig(X, y, λ, T.(β)); lb = Float64((P - big(o.U))/big(o.U)); ex = Float64((P - big(o.D))/big(o.D))
    chk(θ) = vcert(Xd, yd, λd, λd, β, θ)
    for (nm, c) in (("B", cand_B(Xd, yd, λd, β)), ("Bm", cand_Bm(Xd, yd, λd, β, chk)), ("D", cand_D(Xd, yd, λd, β, chk; maxpass = 2000)))
      c.θ === nothing && continue
      r = chk(c.θ); b = bigcert(Xd, yd, λd, β, c.θ)
      println(out, join(Any[prob.id, T, ε, ex, lb, nm, r.ok, r.ratio, b.ratio, variant], '\t'))
    end
  end
end
close(out)
