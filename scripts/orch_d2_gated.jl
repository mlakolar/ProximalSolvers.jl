# Gated variant (after Codex review r1, finding 1): a changed point is returned only if P_up(new) < P_lo(x0).
# Orchestrator check of Agent B's D2 with RIGOROUS Float64 dual bounds (Agent A's outward-rounded `vcert`,
# θ̂ = r̂ at each stage point) instead of B's BigFloat stand-in. Start points: the exact replay of the baseline
# (agents/A/final_points.jls); only runs the production solver left uncertified (the trigger).
# Schedule (B's recommendation): δ_j = 0.3·0.2^j·F̂(x₀), j = 0..7, stage solves cyclic momentum=false cap 20 000,
# then one production polish solve. Bank D = max_j D_lo(β_j). Certify x₀ if (P_up(x₀) − D)/D ≤ prevfloat(1e-4),
# else the latest point. Usage: julia orch_d2_rigorous.jl <worker> <nworkers>
include("<RUN>/agents/A/lib.jl")
const W, NW = parse(Int, ARGS[1]), parse(Int, ARGS[2])

# rigorous upper bound on P(β) (steps 1–2 of `_certify!` plus λ‖β‖₁ rounded up), all in Float64
function Pup(X::Matrix{Float64}, y::Vector{Float64}, hi::Float64, β::Vector{Float64})
  n, p = size(X); ε = eps(Float64); η = nextfloat(0.0); ψ = (n + 1)*ε
  res = copy(y); mag = abs.(y); nb = 0; sb = 0.0
  for k in 1:p
    v = β[k]; iszero(v) && continue
    nb += 1; sb += abs(v)
    for i in 1:n
      t = X[i, k]*v; res[i] -= t; mag[i] += abs(t)
    end
  end
  sr = sum(abs2, res); smu = sum(abs2, mag)
  Nup = up(sqrt(up(up(sr*(1 + ψ)) + n*η)))
  Mup = up(sqrt(up(up(smu*(1 + ψ)) + n*η)))
  Eup = up(up(((nb + 1)*ε)*Mup) + up(up(Float64(nb)*Float64(n))*η))
  up(up(Nup + Eup) + up(hi*up(sb*(1 + nb*ε))))
end
residual64(X, y, β) = y .- X * β    # candidate direction only (validated by vcert)
ratio_of(P, D) = D > 0 ? up(up(P - D)/D) : Inf
# rigorous lower bound on P(β): max(0, N_lo − E_up) + lo·Σ_lo (step 6 of `_certify!`)
function Plo(X::Matrix{Float64}, y::Vector{Float64}, lo::Float64, β::Vector{Float64})
  n, p = size(X); ε = eps(Float64); η = nextfloat(0.0); ψ = (n + 1)*ε
  res = copy(y); mag = abs.(y); nb = 0; sb = 0.0
  for k in 1:p
    v = β[k]; iszero(v) && continue
    nb += 1; sb += abs(v)
    for i in 1:n
      t = X[i, k]*v; res[i] -= t; mag[i] += abs(t)
    end
  end
  sr = sum(abs2, res); smu = sum(abs2, mag)
  Nlo = sr >= ldexp(Float64(n), -969) ? dn(sqrt(dn(sr*(1 - ψ)))) : 0.0
  Mup = up(sqrt(up(up(smu*(1 + ψ)) + n*η)))
  Eup = up(up(((nb + 1)*ε)*Mup) + up(up(Float64(nb)*Float64(n))*η))
  dn(max(0.0, dn(Nlo - Eup)) + dn(lo*dn(sb*(1 - nb*ε))))
end

recs = deserialize("<RUN>/agents/A/final_points.jls")
out = open("<RUN>/out/orch_d2_gated_$W.tsv", "w")
println(out, join(["id", "T", "start", "config", "class0", "outcome", "via", "stages", "passes", "ratio", "excess_ret",
                   "lbexcess_ret", "excess0", "returned_x0", "nnz_ret", "n", "false_cert"], '\t'))
for (i, rc) in enumerate(recs)
  (i % NW == W) || continue
  rc.converged && continue
  T = rc.T == "Float64" ? Float64 : Float32
  prob = problem(rc.id); o = oracle(rc.id, T)
  X, y, λ = data(prob, T)
  X64, y64 = Float64.(X), Float64.(y)
  lo, hi = PS._level_brackets(λ)
  x0 = T.(rc.β)
  P0 = Pup(X64, y64, hi, Float64.(x0)); PL0 = Plo(X64, y64, lo, Float64.(x0))
  F0 = Float64(Pbig(X, y, λ, x0))
  β = copy(x0); D = 0.0; passes = 0; stages = 0; outcome = "uncertified"; via = "none"; ratio = NaN; ret = x0
  for j in 0:8
    if j < 8
      δ = 0.3 * 0.2^j * F0
      Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(δ))
      β, r, _, _ = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses = 20_000)
    else
      β, r, _, _ = ps_solve(X, y, λ, β; order = :cyclic, momentum = false, maxpasses = 20_000)   # polish
    end
    passes += r.passes; stages += 1
    v = vcert(X64, y64, lo, hi, Float64.(β), residual64(X64, y64, Float64.(β)))
    isfinite(v.Dlo) && (D = max(D, v.Dlo))
    r0 = ratio_of(P0, D)
    if r0 <= TARGET
      outcome, via, ratio, ret = "certified", "x0", r0, x0; break
    end
    Pb = Pup(X64, y64, hi, Float64.(β))
    rb = ratio_of(Pb, D)
    if rb <= TARGET && Pb < PL0          # a changed point only on a PROVED decrease: P_up(new) < P_lo(x0)
      outcome, via, ratio, ret = "certified", j < 8 ? "stage" : "polish", rb, β; break
    end
    if j == 8
      if Pb < PL0
        ret, ratio = β, rb
      else
        ret, ratio = x0, ratio_of(P0, D); via = "kept-x0"
      end
    end
  end
  c = classify(X, y, λ, ret, o)
  lbex = Float64((Pbig(X, y, λ, ret) - big(o.U)) / big(o.U))    # lower bound on true excess
  falsecert = outcome == "certified" && lbex > ratio
  println(out, join(Any[rc.id, rc.T, rc.start, rc.config, rc.class, outcome, via, stages, passes, ratio, c.excess, lbex,
                        classify(X, y, λ, x0, o).excess, ret === x0, c.nnz, size(X, 1), falsecert], '\t'))
  flush(out)
end
close(out)
