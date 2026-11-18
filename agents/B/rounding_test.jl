# How rounding can fool the "objective decreased" acceptance test: along the direction/line-search steps of candidate C
# (F32 and F64 data), compare the sign of ΔF = F(new) − F(old) as judged by (a) naive arithmetic in T,
# (b) `fhat` with the rigorous margin (accept only if F̂_new + E_new < F̂_old − E_old), (c) BigFloat truth.
include(joinpath(@__DIR__, "escape.jl"))
naiveF(X::Matrix{T}, y::Vector{T}, λ, β) where T = norm(y - X * β) + T(λ) * norm(β, 1)
function run()
  cnt = Dict{String, Int}()
  bump(k) = cnt[k] = get(cnt, k, 0) + 1
  tiny = Dict{String, Int}()
  for id in ("N8p20-0.05-s1", "N8p20-0.2-s2", "N40p120-0.2-s1", "N40p120-0.05-s2", "N100p400-s1", "C95-s1", "D10-s1", "SW0.1-s2"), T in (Float64, Float32)
    prob = problem(id); o = oracle(id, T); X, y, λ = data(prob, T)
    cfg = cfgmaker("cyclic-dense")
    x, r, _, _ = ps_solve(X, y, λ, start_point(prob, :lnfit, o.β); cfg...)
    β = Vector{T}(x)
    for rep in 1:3
      for it in 1:60
        F0 = fhat(X, y, λ, β)
        d, u, ρ, ps, st = dirlasso(X, β, T(λ); maxpasses = 200, target = 2.0)
        ρ <= 1 + 1e-6 && break
        t = line_min(F0[3], Float64.(X) * Float64.(d), β, d, λ)
        (isfinite(t) && t > 0) || break
        βn = apply_step(β, d, t)
        F1 = fhat(X, y, λ, βn)
        truth = Pbig(X, y, λ, βn) - Pbig(X, y, λ, β)          # < 0: true decrease
        naive = Float64(naiveF(X, y, λ, βn)) - Float64(naiveF(X, y, λ, β))
        strict = strict_decrease(F1, F0)
        tag = string(T)
        bump("$tag steps")
        truth < 0 || bump("$tag true-increase-steps")
        (naive < 0) && !(truth < 0) && bump("$tag naive-T says decrease but truth increase (fooled)")
        !(naive < 0) && (truth < 0) && bump("$tag naive-T says no decrease but truth decrease (missed)")
        strict && !(truth < 0) && bump("$tag RIGOROUS accepts but truth increase (must be 0)")
        !strict && (truth < 0) && bump("$tag rigorous refuses a true decrease (conservative)")
        !strict && !(truth < 0) && bump("$tag rigorous refuses a true increase (correct)")
        # size of the true decrease relative to the margin
        Δ = -Float64(truth)
        Δ > 0 && Δ < F0[2] + F1[2] && bump("$tag true decreases below the margin E")
        strict || break
        β = βn
      end
      x2, _, _, _ = ps_solve(X, y, λ, β; cfg...); β = Vector{T}(x2)
    end
  end
  for k in sort(collect(keys(cnt))); println(rpad(k, 78), cnt[k]); end
end
run()
