# Targeted set for the one branch that changed: `_sqrt_offrange_step` recomputing the distance (ds2 < ss/16) through
# `_se_norm` (head) against `_scaled_norm` (base). Residuals r = c xk + (small perturbation), at tiny / huge scales, exactly
# parallel included, perturbations far below 2^-511 of the residual (column with zeros), n in {1,2,3,5,30,2000}, both types.
# Compares base and head per case against a BigFloat-512 reference (excess/step_bound) and by outcome class and bits.
# The number of cases that reached the recompute branch is counted by a copy of the base tree with counters (base_instr).
# args: draws seed
include("r1lib.jl")
module Instr; include(joinpath(@__DIR__, "base_instr", "src", "ProximalSolvers.jl")); end
const INS = Instr.ProximalSolvers
const OFFR = getfield(INS, :OFFR); const RECOMP = getfield(INS, :RECOMP)
const DRAWS = parse(Int, get(ARGS, 1, "12")); const SEED = parse(Int, get(ARGS, 2, "1"))

# (sx, sr): column scaled by 2^sx, residual by 2^sr (scale of the residual relative to the column is carried by c)
regimes(::Type{Float64}) = [(-495, 0), (0, -500), (-495, -495), (0, 520), (-495, 520), (-530, -530), (-510, -400), (0, -520)]
regimes(::Type{Float32}) = [(-65, 0), (0, -70), (-65, -65), (0, 70), (-65, 70), (-70, -70), (-62, -50), (0, -80)]
epss(::Type{Float64}) = [0.0, 2.0^-3, 2.0^-6, 2.0^-10, 2.0^-20, 2.0^-40, 2.0^-52, 2.0^-53, 2.0^-60, 2.0^-100]
epss(::Type{Float32}) = [0.0, 2.0^-3, 2.0^-6, 2.0^-10, 2.0^-20, 2.0^-23, 2.0^-24, 2.0^-30, 2.0^-60, 2.0^-100]
zeroeps(::Type{Float64}) = [2.0^-600, 2.0^-800, 2.0^-1000, 2.0^-1060]
zeroeps(::Type{Float32}) = [2.0^-60, 2.0^-100, 2.0^-120, 2.0^-140]

function build(rng, ::Type{T}, n, (sx, sr), ε, kind) where T
  if kind == :zeros          # column [u1, 0, ..., 0] (n ≥ 2), residual [c u1, ε w ...]: distance ≈ ε ‖w‖ far below the residual
    u = zeros(n); u[1] = 1 + rand(rng); n >= 2 || return nothing
    xk = T.(ldexp.(u, sx))
    c = (rand(rng) < 0.5 ? 1.0 : randn(rng) * 3)
    r64 = vcat(c * Float64(xk[1]), [ε * randn(rng) for _ in 2:n])
    r64[1] = ldexp(r64[1], sr - sx)
    r64[2:end] .= ldexp.(r64[2:end], sr)    # keeps the tiny entries at their own scale
  else
    u = randn(rng, n); (maximum(abs, u) > 0) || return nothing
    nz = n >= 5 && rand(rng) < 0.3
    nz && (u[rand(rng, 1:n)] = 0.0)
    xk = T.(ldexp.(u, sx))
    c = rand(rng) < 0.5 ? 1.0 : (rand(rng) < 0.5 ? 2.0^rand(rng, -3:3) : randn(rng))
    pert = ε .* maximum(abs, Float64.(xk)) .* randn(rng, n)
    r64 = ldexp.(c .* Float64.(xk) .+ pert, sr - sx)
  end
  r = T.(r64)
  (all(isfinite, r) && all(isfinite, xk) && any(!iszero, xk)) || return nothing
  xk, r
end

function main()
  println("# julia ", VERSION, " draws=", DRAWS, " seed=", SEED)
  grand = Dict(:cases => 0, :offr => 0, :recomp => 0, :over => 0, :mism => 0, :differ => 0)
  for T in (Float32, Float64), n in (1, 2, 3, 5, 30, 2000)
    rng = Xoshiro(hash((SEED, T, n)))
    cases = 0; offr = 0; recomp = 0; over = 0; mism = 0; differ = 0; maxulp = 0.0; maxrel = 0.0; ndist0 = 0
    nrecdiff = 0; worstb = 0.0; worstc = 0.0
    draws = n == 2000 ? max(1, DRAWS ÷ 4) : DRAWS
    for reg in regimes(T), (kind, eps_list) in ((:par, epss(T)), (:zeros, zeroeps(T))), ε in eps_list, _ in 1:draws
      inp = build(rng, T, n, reg, ε, kind); inp === nothing && continue
      xk, r = inp
      ra = setprecision(BigFloat, 512) do; sqrt(sum(abs2, big.(xk))); end
      ra > big(floatmax(T)) && continue
      for t in (0.5, 1 - 2.0^-12)
        λ = T(ra * t); (isfinite(λ) && λ > 0) || continue
        old = rand(rng) < 0.5 ? zero(T) : T(randn(rng))
        OFFR[] = 0; RECOMP[] = 0
        step_r(INS, xk, r, λ, old)
        cases += 1; offr += OFFR[]; recomp += RECOMP[]
        out = evaluate_r(xk, r, λ, old); b, c = out[:base], out[:cand]
        isfinite(b.ratio) && (worstb = max(worstb, b.ratio)); isfinite(c.ratio) && (worstc = max(worstc, c.ratio))
        isfinite(c.ratio) && c.ratio > 1 && (over += 1)
        if oclass(b) != oclass(c)
          mism += 1
        elseif oclass(b) === :value && !(b.z === c.z)
          differ += 1; RECOMP[] > 0 && (nrecdiff += 1)
          u, rl = zdiff(T, b.z, c.z); maxulp = max(maxulp, u); maxrel = max(maxrel, rl)
        end
      end
    end
    @printf("%-8s n=%-5d cases=%6d reached_offrange=%6d reached_recompute=%6d | cand excess/bound>1: %d (worst base %.3e cand %.3e) | outcome-class mismatches=%d | differ=%d (in recompute cases %d; max %.3g ulp, max rel %.3g)\n",
            T, n, cases, offr, recomp, over, worstb, worstc, mism, differ, nrecdiff, maxulp, maxrel)
    flush(stdout)
    for (k, v) in zip((:cases, :offr, :recomp, :over, :mism, :differ), (cases, offr, recomp, over, mism, differ)); grand[k] += v; end
  end
  println("TOTAL ", sort(collect(grand)))
end
main()
